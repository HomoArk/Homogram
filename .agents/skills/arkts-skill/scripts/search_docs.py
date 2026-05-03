#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SKILL_ROOT = Path(__file__).resolve().parents[1]
REFERENCE_ROOT = SKILL_ROOT / "references"
ALLOW_EXTERNAL_COMMAND_HINTS = False

TOKEN_RE = re.compile(r"[a-z][a-z0-9_-]{1,}")
STOPWORDS = {
    "a", "an", "and", "arkts", "could", "difference", "differences", "do", "docs", "example", "examples",
    "find", "for", "help", "how", "i", "in", "me", "need", "of", "reference", "show", "syntax", "the",
    "them", "to", "validate", "validation", "what", "with",
}

INTENT_HINTS = {
    "authoring": ["implement", "write", "create", "build", "author"],
    "review": ["review", "inspect", "check", "audit"],
    "testing": ["test", "case", "assert"],
    "validation": ["validate", "verify", "compile", "syntax", "typecheck"],
    "run": ["run", "execute"],
    "debugging": ["debug", "fix", "error", "diagnostic", "crash"],
    "migration": ["migrate", "port"],
    "api-usage": ["api", "library", "json", "xml", "buffer", "container"],
}

API_REFERENCE_HINTS = (
    "@kit.arkts",
    "@ohos",
    "api version",
    "constructor",
    "collections",
    "json.parse",
    "json.stringify",
    "worker.",
    "taskpool",
    "buffer",
    "fastbuffer",
    "arraybuffer",
    "uint8array",
    "导入模块",
    "参数",
    "返回值",
    "错误码",
    "系统能力",
    "原子化服务api",
)

DIAGNOSTIC_HINTS = (
    "error",
    "errors",
    "diagnose",
    "diagnostic",
    "debug",
    "fix",
    "报错",
    "错误",
    "失败",
    "field type",
)

RESTRICTION_HINTS = (
    "forbid",
    "forbidden",
    "restriction",
    "restrictions",
    "warning",
    "warn",
    "rule",
    "rules",
    "linter",
    "constraint",
    "constraints",
    "cannot",
    "can't",
    "not support",
    "not allowed",
    "禁止",
    "约束",
    "限制",
    "规则",
    "不能",
    "不允许",
    "为什么不能",
)

PRIORITY_BUCKET = {
    "high": 15,
    "medium": 8,
    "low": 0,
}

SOURCE_KIND_BONUS = {
    "language-guide": 8,
    "linter": 4,
    "api-reference": 6,
}

VERIFICATION_BONUS = {
    "snippet_validated": 14,
    "snippet_present": 8,
    "doc_only": 2,
    "not_for_arkts_cli": -4,
}

DOMAIN_PREFERENCE = {
    "basic-syntax": 12,
    "common-library": 10,
    "api-reference": 8,
    "api-usage": 8,
    "concurrency": 3,
    "runtime": 1,
    "toolchain": 2,
    "migration": 1,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--query", required=True)
    parser.add_argument("--limit", type=int, default=5)
    args = parser.parse_args()

    doc_index = load_json(REFERENCE_ROOT / "doc_index.json")
    snippet_index = load_json(REFERENCE_ROOT / "snippet_index.json")
    cli_index = load_json(REFERENCE_ROOT / "cli_index.json")
    topic_aliases = load_json(REFERENCE_ROOT / "topic_aliases.json")

    intent = classify_intent(args.query)
    terms = expand_terms(args.query, topic_aliases)
    canonical_hits = canonical_matches(args.query.lower(), topic_aliases)
    query_profile = build_query_profile(args.query, canonical_hits, topic_aliases)
    scored_sections = score_sections(args.query, terms, canonical_hits, intent, doc_index, snippet_index, topic_aliases)
    results = build_flat_results(scored_sections, args.limit)
    grouped_results = build_grouped_results(scored_sections, args.limit, query_profile)
    suggested_next_steps = suggest_next_steps(intent, cli_index)

    payload = {
        "query": args.query,
        "intent": intent,
        "results": results,
        "grouped_results": grouped_results,
        "suggested_next_steps": suggested_next_steps,
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


def classify_intent(query: str) -> list[str]:
    lowered = query.lower()
    matched = [intent for intent, hints in INTENT_HINTS.items() if any(hint in lowered for hint in hints)]
    if not matched:
        matched = ["authoring", "review"]
    return matched


def expand_terms(query: str, topic_aliases: dict[str, list[str]]) -> set[str]:
    terms = set(tokens_from_text(query))
    lowered = query.lower()
    for canonical, aliases in topic_aliases.items():
        if canonical in lowered or any(alias in lowered for alias in aliases):
            terms.add(canonical)
            terms.update(tokens_from_text(" ".join(aliases)))
    return terms


def score_sections(
    query: str,
    terms: set[str],
    canonical_hits: set[str],
    intent: list[str],
    doc_index: list[dict[str, Any]],
    snippet_index: list[dict[str, Any]],
    topic_aliases: dict[str, list[str]],
) -> list[dict[str, Any]]:
    snippets_by_file: dict[str, list[dict[str, Any]]] = {}
    for item in snippet_index:
        snippets_by_file.setdefault(item["sourceFile"], []).append(item)

    scored: list[dict[str, Any]] = []
    lowered = query.lower()
    query_profile = build_query_profile(query, canonical_hits, topic_aliases)
    for item in doc_index:
        score = 0
        reasons: list[str] = []
        title_text = " ".join(item["section_path"]).lower()
        keyword_terms = set(item.get("keywords", []))
        path_text = f"{item['path']} {' '.join(item['section_path'])}".lower()
        searchable_parts = [title_text, path_text]

        exact_matches = sorted(term for term in terms if has_term_match(title_text, term))
        if exact_matches:
            score += 30 + len(exact_matches) * 3
            reasons.append(f"section heading matches {', '.join(exact_matches[:4])}")

        keyword_matches = sorted(term for term in terms if term in keyword_terms)
        if keyword_matches:
            score += 18 + len(keyword_matches) * 2
            reasons.append(f"keywords match {', '.join(keyword_matches[:4])}")

        path_matches = sorted(term for term in terms if any(has_term_match(part, term) for part in searchable_parts))
        if path_matches:
            score += 22 + len(path_matches) * 2
            reasons.append(f"path matches {', '.join(path_matches[:4])}")

        if any(tag in item.get("domain_tags", []) for tag in ("pure-non-ui", "basic-syntax", "common-library")):
            score += 6

        for name in intent:
            if name in item.get("capabilities", []):
                score += 7
        score += SOURCE_KIND_BONUS.get(item.get("source_kind", "language-guide"), 0)
        score += direct_topic_boost(item, canonical_hits)
        score += source_kind_boost(item, query_profile)
        score += api_reference_boost(item, lowered, terms, query_profile)
        if any(name in lowered for name in ("worker", "taskpool", "sendable", "runtime", "bytecode", "es2abc")):
            for tag in item.get("domain_tags", []):
                score += DOMAIN_PREFERENCE.get(tag, 0)
        else:
            for tag in item.get("domain_tags", []):
                if tag in ("basic-syntax", "common-library"):
                    score += DOMAIN_PREFERENCE.get(tag, 0)

        score += PRIORITY_BUCKET.get(item.get("non_ui_relevance", "low"), 0)
        score += VERIFICATION_BONUS.get(item.get("verification_level", "doc_only"), 0)
        score += section_kind_boost(item, query_profile)
        if item.get("source_kind") == "linter" and item.get("related_examples"):
            score += 10
        if item.get("source_kind") == "linter" and not is_appendix_section(item):
            score += 8
        if is_appendix_section(item):
            score -= 20
        score -= max(len(item.get("section_path", [])) - 2, 0)
        if not item.get("summary") and not item.get("content_summary"):
            score -= 6
        if "arkts restrictions" in title_text and "restriction" not in lowered and "error" not in lowered:
            score -= 8
        if any(word in lowered for word in ("difference", "differences", "compare", "comparison", "vs")):
            if "comparison" in title_text or "vs" in path_text:
                score += 24
                reasons.append("comparison-oriented query matches this section")

        file_snippets = snippets_by_file.get(item["path"], [])
        related_cases = find_related_cases(item, file_snippets, terms)
        if related_cases:
            score += min(len(related_cases), 3) * 5
            reasons.append("related validated snippets exist")

        if score <= 0:
            continue

        if not reasons:
            reasons.append("matched by category and capability ranking")

        scored.append(
            {
                "score": score,
                "path": item["path"],
                "section_path": item["section_path"],
                "summary": item["content_summary"],
                "match_reasons": reasons,
                "verification_level": item["verification_level"],
                "source_kind": item.get("source_kind", "language-guide"),
                "source_label": item.get("source_label", "official-guide"),
                "evidence_strength": item.get("evidence_strength", "primary"),
                "related_examples": item.get("related_examples", []),
                "related_snippet_case_ids": [case["caseId"] for case in related_cases[:3]],
                "next_command_hint": None
                if item.get("source_kind") == "api-reference"
                else command_hint(intent, item["verification_level"]),
                "topic_key": item.get("topic_key", "general"),
                "topic_label": item.get("topic_label", "General"),
                "rule_tags": item.get("rule_tags", []),
                "section_kind": item.get("section_kind", "guide-concept"),
                "heading_level": item.get("heading_level", 1),
            }
        )

    scored.sort(key=lambda item: (-item["score"], item["path"], item["section_path"]))
    return scored


def build_flat_results(scored_sections: list[dict[str, Any]], limit: int) -> list[dict[str, Any]]:
    filtered_sections = filter_scored_sections(scored_sections)
    selected: list[dict[str, Any]] = []
    seen: set[tuple[str, tuple[str, ...]]] = set()
    per_topic_count: dict[str, int] = {}
    for item in filtered_sections:
        key = (item["path"], tuple(item["section_path"]))
        if key in seen:
            continue
        topic_key = item.get("topic_key", "general")
        if per_topic_count.get(topic_key, 0) >= 2:
            continue
        seen.add(key)
        per_topic_count[topic_key] = per_topic_count.get(topic_key, 0) + 1
        selected.append(strip_internal_fields(item))
        if len(selected) >= limit:
            break
    return selected


def build_grouped_results(
    scored_sections: list[dict[str, Any]],
    limit: int,
    query_profile: dict[str, Any],
) -> list[dict[str, Any]]:
    filtered_sections = filter_scored_sections(scored_sections)
    groups: dict[str, list[dict[str, Any]]] = {}
    for item in filtered_sections[:40]:
        groups.setdefault(item.get("topic_key", "general"), []).append(item)

    grouped: list[dict[str, Any]] = []
    for topic_key, items in groups.items():
        ranked_items = sorted(items, key=lambda item: (-item["score"], item["path"], item["section_path"]))
        primary = choose_primary_reference(ranked_items)
        support = choose_supporting_references(ranked_items, primary)
        if query_profile["needs_multi_source_evidence"]:
            support = supplement_supporting_references(primary, support, scored_sections)
        source_mix = unique(item.get("source_label", item.get("source_kind", "unknown")) for item in [primary] + support)
        group_score = primary["score"]
        if len(source_mix) > 1:
            group_score += 18
        if any(item["verification_level"] == "snippet_validated" for item in ranked_items):
            group_score += 10
        if any(item["source_kind"] == "linter" and item.get("related_examples") for item in ranked_items):
            group_score += 6

        grouped.append(
            {
                "topic_key": topic_key,
                "topic_label": primary.get("topic_label", topic_key),
                "group_score": group_score,
                "source_mix": source_mix,
                "rule_tags": unique(tag for item in ranked_items for tag in item.get("rule_tags", [])),
                "primary_reference": strip_internal_fields(primary),
                "supporting_references": [strip_internal_fields(item) for item in support],
                "related_examples": unique(example for item in ranked_items for example in item.get("related_examples", []))[:6],
                "related_snippet_case_ids": unique(case_id for item in ranked_items for case_id in item.get("related_snippet_case_ids", []))[:6],
                "next_command_hint": first_non_null(item.get("next_command_hint") for item in ranked_items),
            }
        )

    grouped.sort(key=lambda item: (-item["group_score"], item["topic_key"]))
    for item in grouped:
        item.pop("group_score", None)
    return grouped[:limit]


def find_related_cases(
    doc_item: dict[str, Any],
    cases: list[dict[str, Any]],
    terms: set[str],
) -> list[dict[str, Any]]:
    related: list[tuple[int, dict[str, Any]]] = []
    leaf = doc_item["section_path"][-1].lower() if doc_item["section_path"] else ""
    for case in cases:
        score = 0
        joined = " ".join(part.lower() for part in case.get("sectionPath", []))
        if leaf and leaf in joined:
            score += 4
        score += len([term for term in terms if term in case.get("keywords", [])])
        score += case.get("runnable_score", 0)
        if score > 0:
            related.append((score, case))
    related.sort(key=lambda pair: (-pair[0], pair[1]["caseId"]))
    return [case for _, case in related]


def suggest_next_steps(intent: list[str], cli_index: list[dict[str, Any]]) -> list[str]:
    if not ALLOW_EXTERNAL_COMMAND_HINTS:
        return []
    wanted = set(intent)
    hints: list[str] = []
    for item in cli_index:
        if wanted.intersection(item.get("usage_intent", [])):
            hints.append(item["command_template"])
    return hints[:3]


def command_hint(intent: list[str], verification_level: str) -> str | None:
    if not ALLOW_EXTERNAL_COMMAND_HINTS:
        return None
    wanted = set(intent)
    if wanted.intersection({"run", "debugging"}):
        return "cd arkts-cli && node ./bin/arkts-cli.js --input /abs/path/main.ets --input-dir /abs/path/src --out-dir /abs/path/out --run"
    if wanted.intersection({"testing", "validation"}) and verification_level in {"snippet_validated", "snippet_present"}:
        return "python3 ./tools/snippets_cli.py test --scope 02-Basic-Syntax --file <markdown-file>"
    if wanted.intersection({"testing", "validation", "api-usage"}):
        return "cd arkts-cli && node ./bin/arkts-cli.js --input /abs/path/file.ets --out-dir /abs/path/out"
    if wanted.intersection({"authoring", "review"}):
        return "cd arkts-cli && node ./bin/arkts-cli.js --input /abs/path/file.ets --out-dir /abs/path/out"
    return None


def tokens_from_text(text: str) -> list[str]:
    lowered = text.lower().replace("/", " ").replace(".", " ")
    return [token for token in TOKEN_RE.findall(lowered) if token not in STOPWORDS]


def canonical_matches(query: str, topic_aliases: dict[str, list[str]]) -> set[str]:
    matched: set[str] = set()
    for canonical, aliases in topic_aliases.items():
        if canonical in query or any(alias in query for alias in aliases):
            matched.add(canonical)
    return matched


def build_query_profile(
    query: str,
    canonical_hits: set[str],
    topic_aliases: dict[str, list[str]],
) -> dict[str, Any]:
    lowered = query.lower()
    restriction_like = any(hint in lowered for hint in RESTRICTION_HINTS)
    diagnostic_like = any(hint in lowered for hint in DIAGNOSTIC_HINTS)
    comparison_like = any(hint in lowered for hint in ("difference", "differences", "compare", "comparison", "vs"))
    api_reference_like = bool(
        any(hint in lowered for hint in API_REFERENCE_HINTS)
        or re.search(r"\b\d{6,8}\b", lowered)
        or any(hit in canonical_hits for hit in ("json", "xml", "worker", "taskpool", "collections", "buffer"))
    )
    syntax_like = bool(
        restriction_like
        or canonical_hits.intersection({"var", "destructuring", "object-literal", "sendable-rule", "typeof", "delete", "in-operator"})
        or any(alias in lowered for alias in topic_aliases.get("linter", []))
    )
    specific_rule_hits = len(
        canonical_hits.intersection({"var", "destructuring", "object-literal", "sendable-rule", "typeof", "delete", "in-operator"})
    )
    return {
        "restriction_like": restriction_like,
        "diagnostic_like": diagnostic_like,
        "comparison_like": comparison_like,
        "api_reference_like": api_reference_like,
        "syntax_restriction_like": syntax_like,
        "specific_rule_hits": specific_rule_hits,
        "needs_multi_source_evidence": restriction_like or diagnostic_like,
    }


def direct_topic_boost(item: dict[str, Any], canonical_hits: set[str]) -> int:
    if not canonical_hits:
        return 0

    path_text = f"{item['path']} {' '.join(item['section_path'])}".lower()
    score = 0
    for canonical in canonical_hits:
        if canonical in path_text:
            score += 35
        if canonical in item.get("keywords", []):
            score += 10

    if "json" in canonical_hits and "/03-Common-Library/arkts-json.md" in item["path"]:
        score += 60
    if "json" in canonical_hits and item.get("source_kind") == "api-reference" and "json" in path_text:
        score += 70
    if "xml" in canonical_hits and "/03-Common-Library/xml" in item["path"]:
        score += 45
    if "xml" in canonical_hits and item.get("source_kind") == "api-reference" and "xml" in path_text:
        score += 60
    if "taskpool" in canonical_hits and "taskpool" in path_text:
        score += 60
    if "worker" in canonical_hits and "worker" in path_text:
        score += 60
    if "sendable" in canonical_hits and "sendable" in path_text:
        score += 60
    if "class" in canonical_hits and "/02-Basic-Syntax/classes.md" in item["path"]:
        score += 40
    if "interface" in canonical_hits and "/02-Basic-Syntax/interfaces.md" in item["path"]:
        score += 40
    if "enum" in canonical_hits and "/02-Basic-Syntax/enumerations.md" in item["path"]:
        score += 40
    if "var" in canonical_hits and ("use let instead of var" in path_text or item.get("source_kind") == "linter"):
        score += 45
    if "destructuring" in canonical_hits and ("destructuring" in path_text or item.get("source_kind") == "linter"):
        score += 45
    if "object-literal" in canonical_hits and ("object literal" in path_text or item.get("source_kind") == "linter"):
        score += 45
    if "sendable-rule" in canonical_hits and ("sendable" in path_text or item.get("source_kind") == "linter"):
        score += 40
    if "typeof" in canonical_hits and ("typeof" in path_text or item.get("source_kind") == "linter"):
        score += 35
    if "delete" in canonical_hits and ("delete" in path_text or item.get("source_kind") == "linter"):
        score += 35
    if "in-operator" in canonical_hits and (" in " in f" {path_text} " or item.get("source_kind") == "linter"):
        score += 35
    return score


def source_kind_boost(item: dict[str, Any], query_profile: dict[str, Any]) -> int:
    source_kind = item.get("source_kind", "language-guide")
    if query_profile["api_reference_like"]:
        if source_kind == "api-reference":
            return 42
        if source_kind == "language-guide":
            return 4
    if query_profile["syntax_restriction_like"]:
        if source_kind == "linter":
            return 55 + query_profile["specific_rule_hits"] * 8
        if source_kind == "language-guide" and any(tag in item.get("domain_tags", []) for tag in ("basic-syntax", "migration")):
            return 14
    if query_profile["restriction_like"] and source_kind == "linter":
        return 28
    if source_kind == "language-guide":
        return 6
    return 0


def api_reference_boost(
    item: dict[str, Any],
    lowered_query: str,
    terms: set[str],
    query_profile: dict[str, Any],
) -> int:
    if item.get("source_kind") != "api-reference":
        return 0

    path_text = f"{item['path']} {' '.join(item['section_path'])}".lower()
    score = 0
    if query_profile["api_reference_like"]:
        score += 28
    api_terms = {
        "json",
        "xml",
        "worker",
        "taskpool",
        "collections",
        "map",
        "set",
        "array",
        "buffer",
        "util",
        "process",
        "uri",
        "url",
        "stream",
        "decimal",
        "locks",
        "ason",
    }
    matches = [term for term in terms.intersection(api_terms) if term in path_text]
    if matches:
        score += 18 + len(matches) * 5
    if re.search(r"\b\d{6,8}\b", lowered_query) and (
        "errorcode" in path_text or "错误码" in " ".join(item.get("section_path", []))
    ):
        score += 35
    if any(hint in lowered_query for hint in ("参数", "返回值", "导入模块", "系统能力", "api version")):
        score += 16
    if "collections.map" in lowered_query and "collections-map.md" in path_text:
        score += 90
    if "collections.set" in lowered_query and "collections-set.md" in path_text:
        score += 90
    if "threadworker" in lowered_query and "threadworker" in path_text:
        score += 40
    if "onallerrors" in lowered_query and "onallerrors" in item.get("keywords", []):
        score += 80
    leaf = item.get("section_path", [""])[-1].lower()
    for term in terms:
        if term and has_term_match(leaf, term):
            score += 45 if term in lowered_query else 5
    return score


def section_kind_boost(item: dict[str, Any], query_profile: dict[str, Any]) -> int:
    section_kind = item.get("section_kind", "guide-concept")
    boost = 0
    if section_kind in {"guide-rule", "migration-recipe", "linter-rule"}:
        boost += 8
    if section_kind in {"api-reference", "api-member", "api-error-code"} and query_profile["api_reference_like"]:
        boost += 16
    if section_kind == "linter-appendix":
        boost -= 18
    if query_profile["diagnostic_like"]:
        if section_kind == "linter-rule":
            boost += 14
        if item.get("topic_key") == "sendable":
            boost -= 10
        if item.get("topic_key") in {"sendable-class-fields", "sendable-class"}:
            boost += 18
    if query_profile["needs_multi_source_evidence"] and item.get("source_kind") == "language-guide":
        boost += 4
    return boost


def has_term_match(text: str, term: str) -> bool:
    if not term:
        return False
    lowered_text = text.lower()
    lowered_term = term.lower()
    if contains_cjk(lowered_term):
        return lowered_term in lowered_text
    if len(lowered_term) <= 3:
        return re.search(rf"(?<![a-z0-9_]){re.escape(lowered_term)}(?![a-z0-9_])", lowered_text) is not None
    return re.search(rf"(?<![a-z0-9_]){re.escape(lowered_term)}(?![a-z0-9_])", lowered_text) is not None


def contains_cjk(text: str) -> bool:
    return any("\u4e00" <= char <= "\u9fff" for char in text)


def is_appendix_section(item: dict[str, Any]) -> bool:
    joined = " ".join(item.get("section_path", [])).lower()
    return "附录" in joined or "appendix" in joined or "索引" in joined or "速查" in joined


def choose_primary_reference(items: list[dict[str, Any]]) -> dict[str, Any]:
    api_items = [item for item in items if item.get("source_kind") == "api-reference"]
    if api_items:
        top_api = api_items[0]
        if top_api["score"] + 10 >= items[0]["score"]:
            return top_api
    guide_items = [item for item in items if item.get("source_kind") == "language-guide"]
    if guide_items:
        top_guide = guide_items[0]
        if top_guide["score"] + 15 >= items[0]["score"]:
            return top_guide
    return items[0]


def choose_supporting_references(items: list[dict[str, Any]], primary: dict[str, Any]) -> list[dict[str, Any]]:
    support: list[dict[str, Any]] = []
    seen_sources = {primary.get("source_kind")}
    seen_paths = {(primary["path"], tuple(primary["section_path"]))}
    for item in items:
        key = (item["path"], tuple(item["section_path"]))
        if key in seen_paths:
            continue
        if item.get("source_kind") not in seen_sources:
            support.append(item)
            seen_sources.add(item.get("source_kind"))
            seen_paths.add(key)
            continue
        if item.get("source_kind") == "linter" and item.get("related_examples"):
            support.append(item)
            seen_paths.add(key)
        if len(support) >= 3:
            break

    if len(support) < 2:
        for item in items:
            key = (item["path"], tuple(item["section_path"]))
            if key in seen_paths:
                continue
            support.append(item)
            seen_paths.add(key)
            if len(support) >= 3:
                break
    return support


def supplement_supporting_references(
    primary: dict[str, Any],
    support: list[dict[str, Any]],
    scored_sections: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    seen_sources = {primary.get("source_kind")}
    seen_keys = {(primary["path"], tuple(primary["section_path"]))}
    for item in support:
        seen_sources.add(item.get("source_kind"))
        seen_keys.add((item["path"], tuple(item["section_path"])))

    if len(seen_sources) > 1:
        return support

    for item in scored_sections:
        key = (item["path"], tuple(item["section_path"]))
        if key in seen_keys:
            continue
        if item.get("source_kind") == primary.get("source_kind"):
            continue
        if not shares_topic_family(primary, item):
            continue
        support.append(item)
        break
    return support


def shares_topic_family(left: dict[str, Any], right: dict[str, Any]) -> bool:
    if left.get("topic_key") == right.get("topic_key"):
        return True
    if set(left.get("rule_tags", [])).intersection(right.get("rule_tags", [])):
        return True
    left_family = topic_family(left.get("topic_key", "general"))
    right_family = topic_family(right.get("topic_key", "general"))
    return left_family == right_family and left_family != "general"


def topic_family(topic_key: str) -> str:
    if topic_key.startswith("sendable"):
        return "sendable"
    if topic_key.startswith("object-literal"):
        return "object-literal"
    if topic_key.startswith("destructuring"):
        return "destructuring"
    if topic_key == "var":
        return "var"
    return topic_key.split("-", 1)[0] if topic_key else "general"


def strip_internal_fields(item: dict[str, Any]) -> dict[str, Any]:
    result = dict(item)
    result.pop("score", None)
    result.pop("heading_level", None)
    return result


def first_non_null(items: Any) -> Any:
    for item in items:
        if item:
            return item
    return None


def unique(items: Any) -> list[Any]:
    ordered: list[Any] = []
    seen: set[Any] = set()
    for item in items:
        if item in seen:
            continue
        seen.add(item)
        ordered.append(item)
    return ordered


def filter_scored_sections(scored_sections: list[dict[str, Any]]) -> list[dict[str, Any]]:
    if not scored_sections:
        return []
    top_score = scored_sections[0]["score"]
    cutoff = max(top_score - 30, int(top_score * 0.72))
    return [item for item in scored_sections if item["score"] >= cutoff]


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    raise SystemExit(main())
