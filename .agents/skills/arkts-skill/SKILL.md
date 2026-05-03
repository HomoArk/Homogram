---
name: arkts-skill
description: Retrieve grounded ArkTS references for pure non-UI ArkTS work and ArkTS API usage. Use this skill whenever the user is writing, reviewing, testing, validating, running, or debugging ArkTS code and the answer should be backed by repository sources such as `docs/ArkTS-Language-Guide/`, `docs/ArkTS-API-Reference/`, and the linter-derived `docs/linter/ArkTS_Syntax_Knowledge_From_Linter.md` instead of model memory. This skill is especially useful for syntax rules, ArkTS-specific restrictions, API/module/member lookup, common-library usage, runnable example lookup, snippet validation context, and figuring out which repository section to trust before suggesting code or fixes.
---

# ArkTS Retrieval Skill

Use this skill to find real ArkTS documentation quickly and return traceable references.

This skill is for retrieval. It does not default to running external validation or execution tools. In this copied package, do not suggest commands that depend on files outside the package.

In the source repository, this skill lives under `skills/arkts-skill/`. This copied package is self-contained. Open cited markdown files under `docs/ArkTS-Language-Guide/`, `docs/ArkTS-API-Reference/`, or `docs/linter/` when you need the original context.

## What this skill covers

- Pure non-UI ArkTS syntax and language rules from `docs/ArkTS-Language-Guide/02-Basic-Syntax`
- ArkTS-specific syntax constraints and boundary cases summarized from `docs/linter/ArkTS_Syntax_Knowledge_From_Linter.md`
- Common-library usage from `docs/ArkTS-Language-Guide/03-Common-Library`
- OpenHarmony ArkTS API reference material from `docs/ArkTS-API-Reference/`, including imports, parameters, return values, API versions, system capabilities, and error codes
- Concurrency, runtime, toolchain, migration, and related language-guide sections when the query clearly points there
- Snippet-level validation metadata derived from the repository's snippet framework
- Grounded references for pure non-UI `.ets` topics inside this copied package, without assuming external validation tools are present

## Required behavior

1. Ground the answer in local repository sources, not in vague prior knowledge.
2. Treat `docs/ArkTS-Language-Guide/` as the primary source for normative language explanations, `docs/ArkTS-API-Reference/` as the primary source for API/module/member details, and `docs/linter/ArkTS_Syntax_Knowledge_From_Linter.md` as implementation-derived evidence for ArkTS-specific restrictions and edge cases.
3. Prefer pure non-UI and validation-backed references when multiple sections could fit.
4. When a result comes from the linter summary, say that clearly instead of presenting it as official spec text. When a result comes from the API reference, do not treat its examples as pure non-UI snippet validation evidence.
5. If the task mentions testing, validation, running, or debugging, add command hints as optional next steps rather than automatically executing them.
6. If the first retrieval pass is weak, broaden to neighboring sections or adjacent categories before answering.
7. If you still cannot find a grounded reference, say that clearly and name the searches you attempted.
8. Return concise, useful citations by default:
   - file path
   - section path
   - source kind
   - short summary
   - why the section matched

## Retrieval workflow

1. Run:

```bash
python3 scripts/search_docs.py --query "<user request>"
```

2. Read the top results.
3. Open the cited markdown file under `docs/ArkTS-Language-Guide/`, `docs/ArkTS-API-Reference/`, or `docs/linter/` if you need exact wording or more context.
4. Answer using the result structure below.

Prefer `grouped_results` when it is present. Treat `results` as the raw flat candidate list kept for compatibility and debugging.

## Result structure

Use this format unless the user wants something else:

```markdown
- Topic: <topic label>
- Reference: <path>
- Section: <section path>
- Source: <official-guide | openharmony-arkts-api | linter-summary>
- Why it matches: <one sentence>
- Guidance: <one or two sentences grounded in the doc>
- Next step: <optional command hint>
```

## When to expand past the top result

Expand further when:

- the top result is from `04-Concurrency`, `05-Runtime`, or `07-Compilation-Toolchain` but the user question is still ambiguous
- the top result is from `docs/ArkTS-API-Reference/` but the user is asking about ArkTS syntax restrictions rather than API signatures or module behavior
- the top result is from `docs/linter/ArkTS_Syntax_Knowledge_From_Linter.md` and you still need an official guide section for broader context
- `grouped_results` mixes only one source kind and the question looks restriction-heavy or diagnostic
- the result has `verification_level = doc_only`
- the user needs runnable or compile-checkable examples
- multiple syntax rules interact, such as classes plus generics, or enums plus control flow

## Validation follow-ups

This copied package does not include `arkts-cli` or `tools/snippets_cli.py`.
Do not suggest those commands from the release package. If the user needs execution or snippet validation, tell them to switch to the source repository.

## Index assets

This skill relies on:

- `references/doc_index.json`
- `references/snippet_index.json`
- `references/cli_index.json`
- `references/topic_aliases.json`

The indexed repository sources are:

- `docs/ArkTS-Language-Guide/**/*.md`
- `docs/ArkTS-API-Reference/**/*.md`
- `docs/linter/ArkTS_Syntax_Knowledge_From_Linter.md`

This package is generated from the source repository. Rebuild it there with:

```bash
python3 tools/release_arkts_skill.py
```

