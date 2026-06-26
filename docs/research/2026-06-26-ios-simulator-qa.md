# 2026-06-26 iOS Simulator QA

## Status

iOS simulator QA passed for the phase-one local capture -> runtime -> chat -> todos -> packs -> backup slice.

The iOS runner now exists under `apps/mobile/ios` and is aligned with ADR-0008:

- `dev` scheme: `app.widenote.dev`, display name `WideNote Dev`
- `prod` scheme: `app.widenote`, display name `WideNote`

## Environment

- Date: 2026-06-26
- Simulator: `iPhone 17`
- Simulator ID: `AC67CA3B-F4D5-428C-ABBB-08F5AF83DF1D`
- Runtime: iOS 26.5
- Workspace: `apps/mobile/ios/Runner.xcworkspace`
- Scheme used for UI QA: `dev`
- Build configuration: `Debug-dev`
- Bundle ID: `app.widenote.dev`

## Build Validation

Both iOS simulator flavors built successfully:

```sh
cd apps/mobile
env -u ws_proxy -u wss_proxy NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 flutter build ios --simulator --debug --flavor dev
env -u ws_proxy -u wss_proxy NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 flutter build ios --simulator --debug --flavor prod
```

Xcode scheme/configuration validation:

```sh
xcodebuild -list -project apps/mobile/ios/Runner.xcodeproj
xcodebuild -showBuildSettings -project apps/mobile/ios/Runner.xcodeproj -scheme dev -configuration Debug-dev
xcodebuild -showBuildSettings -project apps/mobile/ios/Runner.xcodeproj -scheme prod -configuration Debug-prod
```

Observed:

- Schemes: `dev`, `prod`, `Runner`
- Build configurations include `Debug-dev`, `Debug-prod`, `Profile-dev`, `Profile-prod`, `Release-dev`, `Release-prod`
- `dev`: `PRODUCT_BUNDLE_IDENTIFIER = app.widenote.dev`, `APP_DISPLAY_NAME = WideNote Dev`
- `prod`: `PRODUCT_BUNDLE_IDENTIFIER = app.widenote`, `APP_DISPLAY_NAME = WideNote`
- No remaining `app.widenote.widenoteMobile` or `Widenote Mobile` text in `apps/mobile/ios`

## XcodeBuildMCP Run

Session defaults:

```json
{
  "workspacePath": "/Users/guangmo/.codex/worktrees/efd4/widenote/apps/mobile/ios/Runner.xcworkspace",
  "scheme": "dev",
  "configuration": "Debug-dev",
  "simulatorId": "AC67CA3B-F4D5-428C-ABBB-08F5AF83DF1D",
  "simulatorPlatform": "iOS Simulator",
  "bundleId": "app.widenote.dev",
  "useLatestOS": true,
  "preferXcodebuild": true
}
```

`build_run_sim` succeeded.

Artifacts:

- App path: `/Users/guangmo/Library/Developer/XcodeBuildMCP/workspaces/widenote-f9abedaa71ac/DerivedData/Runner-bcadd0de5b48/Build/Products/Debug-dev-iphonesimulator/Runner.app`
- Build log: `/Users/guangmo/Library/Developer/XcodeBuildMCP/workspaces/widenote-f9abedaa71ac/logs/build_run_sim_2026-06-26T05-58-32-951Z_pid23409_86f23608.log`
- Runtime log: `/Users/guangmo/Library/Developer/XcodeBuildMCP/workspaces/widenote-f9abedaa71ac/logs/app.widenote.dev_2026-06-26T05-59-05-544Z_helperpid82324_ownerpid23409_ff88d6af.log`
- OS log: `/Users/guangmo/Library/Developer/XcodeBuildMCP/workspaces/widenote-f9abedaa71ac/logs/app.widenote.dev_oslog_2026-06-26T05-59-07-636Z_helperpid82589_ownerpid23409_771589aa.log`
- Screenshot: `/var/folders/y0/xpyf8lh91_b3djfpxz94znc00000gn/T/screenshot_optimized_dce30f41-e75b-426f-bb61-c5d9f67c1b1f.jpg`

Build warnings were limited to sqlite3 pod C compiler warnings from generated dependency sources.

## Paths Tested

### Home and Capture

The app launched and rendered the localized home screen.

Input:

```text
Met Lin about WideNote iOS simulator todo follow up
```

Observed after tapping Record:

- `处理 1 条已处理`
- `记忆 1 条已入库`
- `卡片 2 张卡片`
- `洞察 3 条可溯源`

### Source-Linked Todos

The Todos tab showed one source-linked todo:

- `跟进：Met Lin about WideNote iOS simulator todo follow up`
- `来源：local-...`
- `智能体建议`

This verifies the official todo Agent Pack path on iOS.

### Chat Context Packets

Question:

```text
What should I follow up about Lin?
```

Observed answer:

- Found 5 local context items
- Cited Memory, Record, Todo, and card sources
- Used the iOS-captured source text

This verifies the Chat Context Packet path on iOS.

### Packs and Trace Console

The Packs tab showed runtime observability:

- `追踪事件：15`
- `运行：2`
- `警告：0`

Trace Console opened and showed real events for:

- `pack.default / agent.capture_loop`
- `pack.todo / agent.todo_loop`

### Backup Export

Backup page opened through the Packs control list and exported safe JSON.

Observed:

- `安全导出不会包含模型提供商 API Key，恢复后需要重新填写。`
- `安全备份 JSON 已准备好。`

Manifest counts:

- `captures: 1`
- `cards: 2`
- `chat_messages: 2`
- `chat_sessions: 1`
- `context_packet_cache: 1`
- `event_log: 5`
- `insights: 3`
- `memory_candidates: 1`
- `memory_items: 1`
- `todos: 1`
- `trace_events: 15`

## Log Scan

Runtime and OS logs were scanned with:

```sh
rg -n "FATAL|fatal|Unhandled|Exception|SQLiteException|CapturePipelineException|ContextPacket|E/flutter|crash|Crash|abort|Assertion" \
  /Users/guangmo/Library/Developer/XcodeBuildMCP/workspaces/widenote-f9abedaa71ac/logs/app.widenote.dev_2026-06-26T05-59-05-544Z_helperpid82324_ownerpid23409_ff88d6af.log \
  /Users/guangmo/Library/Developer/XcodeBuildMCP/workspaces/widenote-f9abedaa71ac/logs/app.widenote.dev_oslog_2026-06-26T05-59-07-636Z_helperpid82589_ownerpid23409_771589aa.log
```

No app-level Flutter, SQLite, capture pipeline, or Context Packet errors were found.

One iOS 26.5 simulator accessibility duplicate-class warning appeared in runtime logs. It is from simulator WebCore/WebKit accessibility bundles, not from WideNote application code.

## Cleanup

The dev app was stopped with XcodeBuildMCP, and the simulator was shut down:

```sh
xcrun simctl shutdown AC67CA3B-F4D5-428C-ABBB-08F5AF83DF1D
```

Final simulator state: `Shutdown`.

## Follow-Ups

- Add real media permission strings and iOS QA when camera, microphone, or photo library capture is implemented beyond placeholder controls.
- Add co-installed dev/prod simulator launcher verification before TestFlight or store distribution.
- Keep `ios/Podfile`, shared schemes, and Xcode build configurations in sync when Flutter template repair is rerun.
