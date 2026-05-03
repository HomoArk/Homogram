# arkts-skill release

This directory is the distributable ArkTS retrieval skill package.

It contains:

- `SKILL.md`: skill instructions for grounded ArkTS retrieval
- `scripts/search_docs.py`: local retrieval entry point
- `references/*.json`: generated retrieval indexes
- `docs/ArkTS-Language-Guide/`: cited source markdown used for follow-up reading
- `docs/ArkTS-API-Reference/`: cited OpenHarmony ArkTS API reference markdown
- `docs/linter/`: linter-derived ArkTS restriction summary and minimal `.ets` examples

It intentionally does not contain repository-only development assets such as `temp/`, `reference/`, or the source-side index builder.

## Usage

```bash
python3 scripts/search_docs.py --query "how do I validate a pure non-UI ArkTS class example?"
```

## Updating this release

Regenerate this directory from the source repository root with:

```bash
python3 tools/release_arkts_skill.py
```

This release currently includes 171 indexed source files across `docs/ArkTS-Language-Guide/`, `docs/ArkTS-API-Reference/`, and `docs/linter/`.
