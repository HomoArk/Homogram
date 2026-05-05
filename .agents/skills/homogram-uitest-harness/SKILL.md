---
name: homogram-uitest-harness
description: Build and drive Homogram in deterministic Telegram fixture mode through hdc UITest commands. Use when an agent needs to observe, click, type, screenshot, or smoke-test Homogram UI on a connected HarmonyOS device or emulator.
---

# Homogram UITest Harness

Use this skill when working on agent self-iteration for Homogram UI.

## What It Provides

- A deterministic Telegram fixture mode that does not require Telegram auth or network state.
- A Python harness for `hdc shell uitest` observation and actions.
- Stable UI IDs for key surfaces such as chat rows, message list, composer input, send button, and login fields.

## Preferred Runner

The canonical entrypoint is the Python harness. Use `uv` when available:

```shell
uv run python .agents/skills/homogram-uitest-harness/scripts/homogram_ui_harness.py observe
```

Thin wrappers are also provided:

```shell
# macOS/Linux
sh .agents/skills/homogram-uitest-harness/scripts/homogram-ui observe

# Windows cmd.exe
.\.agents\skills\homogram-uitest-harness\scripts\homogram-ui.cmd observe
```

The wrappers use `uv run python` when `uv` is available, then fall back to `python3`/`python`.

## Common Commands

Build a fixture-mode HAP:

```shell
uv run python .agents/skills/homogram-uitest-harness/scripts/homogram_ui_harness.py build
```

If `hvigorw` is not on PATH, pass it explicitly or set `HOMOGRAM_HVIGOR`:

```shell
uv run python .agents/skills/homogram-uitest-harness/scripts/homogram_ui_harness.py build --hvigor /path/to/hvigorw
```

Install the latest built HAP:

```shell
uv run python .agents/skills/homogram-uitest-harness/scripts/homogram_ui_harness.py install
```

Launch Homogram with fixture mode enabled:

```shell
uv run python .agents/skills/homogram-uitest-harness/scripts/homogram_ui_harness.py launch
```

Capture both current layout and screenshot:

```shell
uv run python .agents/skills/homogram-uitest-harness/scripts/homogram_ui_harness.py observe
```

Observation artifacts are written under `.agents/artifacts/uitest`.

Run a short fixture smoke flow:

```shell
uv run python .agents/skills/homogram-uitest-harness/scripts/homogram_ui_harness.py smoke
```

The runner checks whether the Homogram process is still alive after launch and smoke actions. On a detected crash or failed device command, it writes `crash-*` artifacts under `.agents/artifacts/uitest`.

Collect crash evidence manually:

```shell
uv run python .agents/skills/homogram-uitest-harness/scripts/homogram_ui_harness.py crash-info
```

Click a stable UI ID after dumping layout:

```shell
uv run python .agents/skills/homogram-uitest-harness/scripts/homogram_ui_harness.py tap-id hg-chat-row-1001
```

Type into the currently focused field, or focus by ID first:

```shell
uv run python .agents/skills/homogram-uitest-harness/scripts/homogram_ui_harness.py input-id hg-composer-input "hello from harness"
```

## Notes

- Assumes `hdc` can see a connected device or emulator.
- Fixture peers live in `features/home/src/main/ets/testing/fixtures/peers.json`; message thread plans live in `features/home/src/main/ets/testing/fixtures/messages.json`.
- `launch` and `smoke` clear the device hilog buffer before starting by default so crash artifacts are scoped to the current run. Pass `--no-clear-hilog` before the subcommand to keep existing logs.
- `launch` and `smoke` also force-stop Homogram before starting so they begin from a clean fixture route. Pass `--keep-running` before the subcommand to preserve the current process.
- When a DevEco `hvigorw` path is supplied, the harness infers DevEco `NODE_HOME`, `JAVA_HOME`, and `DEVECO_SDK_HOME`. For manual Hvigor commands, `DEVECO_SDK_HOME` should point at the SDK container directory, for example `C:\Program Files\Huawei\DevEco Studio\sdk`.
- Do not run multiple UITest clients concurrently. Huawei UITest reports concurrency errors when overlapping clients are active.
- `tap-id` depends on the `dumpLayout` JSON exposing ArkUI IDs. If a selector cannot be found, inspect the dumped JSON path printed by `observe`.
- The harness builds with `buildMode=uitest` and also launches with the `homogram-uitest://fixture` URI.
- Normal DevEco Build button usage should continue to use the `debug` build mode unless `uitest` is explicitly selected.
