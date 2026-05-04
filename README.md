<p align="center">
  <img src="./assets/logo.png" width="20%" style="border-radius:25%"/>
</p>

<h1 align="center">Homogram</h1>

Homogram is a third-party Telegram client for [HarmonyOS 5](https://developer.huawei.com/consumer/cn/), driven by
ArkTS/ArkUI for the app UI and Rust for the native Telegram runtime.

_This project is a hobby project and is not affiliated with either Telegram or Huawei._

**Note:** If you only need the official Telegram Android app on HarmonyOS, Android container solutions may be a better
fit. Homogram is for building a native HarmonyOS Telegram client experience.

## Branches

- The `main` branch contains the latest stable version of Homogram. It may not be the most feature-rich branch, but it
  should compile and run with as few known bugs as possible.
- The `dev` branch may contain bugs, incomplete features, and other issues. It is not guaranteed to compile or run.

## Current Status

Homogram is now past the original proof-of-concept stage. The app has a Harmony-native UI shell, a typed ArkTS bridge,
and a Rust/Grammers Telegram runtime with its own native SQLite cache.

| Area | Status | Notes |
| --- | --- | --- |
| Authentication | Working | Phone login, verification code, 2FA password, session restore, foreground reconnect, and sign out. |
| Native Telegram runtime | Working | `homogrape` owns Telegram session/runtime, cache-first dialogs/messages, event replay, and update processing. |
| Dialog list | Working | Cache-first load, pinned ordering, last-message previews, unread badges, read state, profile photos, and context actions for pin/mute/archive/mark-read. |
| Chat history | Working | Latest-message load, older-history pagination, stable ordering, replies, jump-to-reply, and live sent/incoming message updates. |
| Message display | Working | Text, formatted entities, photos, videos, documents, stickers, profile photos, and media download. |
| Message sending | Partial | Text, reply sends, and media send plumbing exist; the UI picker is still limited and broader file workflows need polish. |
| Message actions | Partial | Copy, delete, forward to Saved Messages, and mark-read are wired; edit/forward-to-picker/save UX is not complete. |
| Contacts and profiles | Partial | Contacts list, open chat, self/peer profile, profile photos, and group/channel participant list are present. |
| Search | Partial | Native/bridge APIs exist for peer and message search; the full Telegram-grade search UI is still incomplete. |
| Push/settings | Partial | Push registration/settings scaffolding exists, but production push depends on external/server-side constraints. |
| Android Telegram parity | In progress | Message/dialog cache strategy now mirrors Android Telegram's cache-first, top-message, ordered-update model. |

## Native Runtime

The native Telegram layer lives in `features/home/src/main/native/homogrape` and uses
[grammers](https://github.com/Lonami/grammers) directly. It does not use TDLib.

The current runtime design is:

- Rust owns Telegram protocol state and the Telegram cache.
- Grammers session is stored at `/data/storage/el2/base/session`.
- Homogram's native cache is stored separately at `/data/storage/el2/base/homogrape_cache.db`.
- ArkTS treats chat/message data as an in-memory UI projection of native snapshots and events.
- Native events are persisted, sequenced, and replayable through `getEventsSince`.
- Live updates currently handle new messages, edits, deletes, read state, dialog changes, and unknown-update logging.

## Roadmap

Near-term work is focused on daily-driver Telegram basics rather than every advanced Telegram feature:

- Complete user-facing peer/message search.
- Finish edit, forward-to-chat picker, and Saved Messages actions.
- Broaden media/file sending beyond the current picker path.
- Improve media viewer/gallery behavior.
- Add drafts, optimistic send/retry states, and better upload/download progress UI.
- Continue mirroring Android Telegram's dialog/message behavior from `C:\code\Telegram`.

Out of scope for the current MVP: calls, stories, secret chats, payments, premium, bots/webapps, advanced admin tools,
full chat folders, polls creation, reactions, scheduled messages, and a full theme editor.

A detailed roadmap can be found in the [Homogram Project](https://github.com/orgs/HomoArk/projects/2) page.

## Building

### Prerequisites

- A Windows or macOS device that supports [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/).
- HarmonyOS SDK / OpenHarmony SDK installed through DevEco Studio.
- Rust toolchain installed.
- `OHOS_NDK_HOME` set to the HarmonyOS NDK root.
- `ohrs` available on `PATH`.

The current project build profile targets HarmonyOS 6.0.1 / API 21. The app has also been manually tested on
HarmonyOS 6.1.0 / API 23.

### Setup

1. Clone the repository:

   ```shell
   git clone https://github.com/HomoArk/Homogram.git --recursive
   ```

2. [Obtain your own Telegram `api_id`](https://core.telegram.org/api/obtaining_api_id) and API hash.

3. Fill out the native Telegram config:

   ```text
   features/home/src/main/native/homogrape/src/tg/config.rs
   ```

   A template is available at:

   ```text
   features/home/src/main/native/homogrape/src/tg/config.rs.template
   ```

4. Build and copy the native library:

   ```shell
   cd features/home/src/main/native/homogrape
   cargo xtask dist ../../../../libs/arm64-v8a/
   ```

5. Configure signing in DevEco Studio or through the root `build-profile.json5`.

6. Build the phone HAP:

   ```shell
   hvigorw --mode module -p module=phone@default -p product=default -p requiredDeviceType=phone -p buildMode=debug assembleHap
   ```

   Expected output directory:

   ```text
   products/phone/build/default/outputs/default/
   ```

### Native Checks

From `features/home/src/main/native/homogrape`:

```shell
cargo check
cargo test
cargo xtask dist ../../../../libs/arm64-v8a/
```

`cargo test` uses a host logger, while device builds use the HarmonyOS logging backend.

## Credits

- [grammers](https://github.com/Lonami/grammers), a set of Rust libraries to interact with Telegram's API.
- [ohos-rs](https://github.com/ohos-rs/ohos-rs), a `napi-rs` adaptation for OpenHarmony SDK.
- [Gramony](https://github.com/Gramony/Gramony) by [OverflowCat](https://github.com/OverflowCat), a great fork of
  Homogram.
- [MultiDeviceCommunication](https://gitee.com/harmonyos_codelabs/MultiDeviceCommunication), a sample project for
  developing IM apps on HarmonyOS NEXT.

These projects are the backbone of Homogram and without them, this project would not be possible. Tremendous thanks to
all contributors.

## License

This project is licensed under the Apache License, Version 2.0.
