# AGENTS.md

## Scope

This file applies to the `E:\code\Homogram` workspace.

## Project Summary

- `Homogram` is a HarmonyOS NEXT Telegram client.
- UI and app packaging are ArkTS/ArkUI + Hvigor.
- Native Telegram integration lives in the Rust submodule `features/home/src/main/native/homogrape`.
- The app bundle name is `com.xymeng16.homogram` (`AppScope/app.json5`).

## Repository Layout

- `products/phone`: entry HAP module.
- `features/home`: feature module that owns most app UI and the native library integration.
- `common/base`: shared ArkTS utilities/components.
- `features/home/src/main/native/homogrape`: Rust submodule that builds `libhomogrape.so`.
- `signing`: local signing assets referenced by `build-profile.json5`.

## Working Rules

- Prefer narrow changes. Do not refactor unrelated ArkTS, Rust, or Hvigor files.
- Treat `features/home/src/main/native/homogrape` as an external submodule with its own history. Keep changes there scoped and intentional.
- Do not remove or rotate signing material unless explicitly asked.
- Before building the HAP, rebuild the Rust library if native code or its ArkTS bindings changed.
- Do not introduce too much defensive logic. Instead, think in-depth and design carefully to ensure the code quality and correctness in a structural way.
- Correctness and readability take priority over preserving unused compatibility wrappers.
- For ArkTS/ArkUI UI edits, use HDS controls from `@kit.UIDesignKit` instead of legacy ArkUI widgets whenever the current SDK exposes an HDS equivalent. Do not add new legacy widgets or leave touched legacy widgets in place when an HDS counterpart exists.
- For tabs specifically, use `HdsTabs` and `HdsTabsController` instead of `Tabs` and `TabsController`.
- If an HDS API exists only in a newer HarmonyOS SDK than this checkout targets, document the version mismatch and avoid adding uncompilable calls.

## Native Build Flow

When working on the Rust layer, build from the submodule and copy the resulting `.so` into the feature module's libs directory.

Prerequisites:

- `OHOS_NDK_HOME` must already be set in the shell environment and point at the HarmonyOS NDK root.
- `ohrs` must be available on `PATH`.
- Rust toolchain must be installed.

Command from `E:\code\Homogram\features\home\src\main\native\homogrape`:

```powershell
cargo xtask dist ../../../../libs/arm64-v8a/
```

Notes:

- This is the canonical local command already documented in `README.md`.
- `xtask dist` runs `ohrs build --arch=aarch` and copies files from `dist/arm64-v8a` into `features/home/libs/arm64-v8a`.
- On a clean checkout, `features/home/libs/arm64-v8a` may not exist yet; the xtask creates the target directory.

Example invocation without overriding the existing NDK environment:

```powershell
$env:RUSTFLAGS='-Awarnings'
Set-Location E:\code\Homogram\features\home\src\main\native\homogrape
cargo xtask dist ../../../../libs/arm64-v8a/
Set-Location E:\code\Homogram
```

## HAP Build And Signing

The app-level build configuration is in `build-profile.json5`.

Current local setup:

- product: `default`
- build modes: `debug`, `release`
- signing config name: `default`
- signing material:
  - `./signing/Homogram_Debug.cer`
  - `./signing/homogram_debug.p7b`
  - `./signing/keystore.p12`

The HAP entry module is `phone` (`products/phone`).

Use the HarmonyOS Hvigor tooling after the native `.so` has been copied into `features/home/src/main/libs/arm64-v8a`.

Preferred command shape for this repo, matching the recorded local Hvigor invocation in `.hvigor/report`:

```powershell
hvigorw --mode module -p module=phone@default -p product=default -p requiredDeviceType=phone assembleHap
```

If `hvigorw` is not present in the repo, run the equivalent Hvigor command from a DevEco Studio terminal or via the HarmonyOS SDK-installed Hvigor executable.

If you run the SDK-provided `hvigorw` outside DevEco Studio, make sure a Node runtime is available. In this environment the working wrapper was:

```powershell
$env:NODE_HOME='E:\Program Files\Huawei\DevEco Studio\tools\node'
$env:Path="$env:NODE_HOME;$env:Path"
& 'E:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p module=phone@default -p product=default -p requiredDeviceType=phone -p buildMode=debug assembleHap
```

Useful variants:

```powershell
hvigorw --mode module -p module=phone@default -p product=default -p requiredDeviceType=phone -p buildMode=debug assembleHap
hvigorw --mode module -p module=phone@default -p product=default -p requiredDeviceType=phone -p buildMode=release assembleHap
```

Expected output directory:

```text
products/phone/build/default/outputs/default/
```

## Signing Expectations

- Signing is controlled by the root `build-profile.json5`, not by ad hoc Hvigor flags in this repo.
- If signing fails, verify the certificate, profile, keystore path, alias, and encrypted passwords under `app.signingConfigs[0].material`.
- Do not check replacement signing assets into the repo unless explicitly asked.

## References

- Root build/sign docs: [HarmonyOS build guide](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/ide-build-V5)
- Root signing docs: [HarmonyOS signing guide](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/ide-signing-V5)
- Local project build notes: [README.md](E:\code\Homogram\README.md)
