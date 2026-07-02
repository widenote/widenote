# Mobile Navigation Hierarchy Kimi Review

Date: 2026-07-02

Scope: external review of the mobile navigation hierarchy change for ADR-0015.

Input hygiene:

- Sent the page hierarchy, intended `go_router` structure, changed files,
  complete sanitized diff for the navigation/docs/tests change, and local test
  plan.
- Did not send local databases, user records, backup artifacts, provider keys,
  credentials, or secret-bearing files.
- Kimi was asked to review only design risk, code risk, and test gaps.

## Review Result

Kimi's conclusion: the nested route approach is acceptable and matches the user
requirement that non-tab pages return to their parent or source route before
platform exit. No P0 issues were reported.

Kimi reported these checks from its review run:

- `flutter test --no-pub test/navigation_hierarchy_test.dart`
- `flutter test --no-pub test/settings_page_test.dart test/plugins_page_test.dart test/timeline_widget_test.dart test/chat_page_test.dart test/trace_console_page_test.dart test/todos_page_test.dart test/memory_page_test.dart`
- `flutter analyze`
- `git diff --check`

Local validation still needs to be run and recorded by the implementation
owner; Kimi review is advisory and does not replace local verification.

## Findings

| Priority | Finding | Disposition |
| --- | --- | --- |
| P0 | No blocker found. | No action needed. |
| P1 | Cross-tab `push` can make the destination page's durable tab selected while system back returns to the source tab. | Accepted as current behavior for contextual links; covered by production-router widget tests. |
| P1 | Tab switches need a regression test proving replacement navigation clears child stacks. | Added a navigation widget test. |
| P1 | Some existing feature tests use local flat routers and do not prove production route behavior. | Added production-router coverage in `navigation_hierarchy_test.dart`; existing feature tests remain useful for local page behavior. |
| P2 | Future child-page entries may accidentally use replacement navigation. | ADR-0015 and current contracts now state the push/go boundary; route tests should be updated with new pages. |
| P2 | Record tab's non-route slot should be clear in code. | Added a short router comment. |

Post-review device QA found one additional hierarchy gap: the Home search
shortcut opened `/timeline/search` without first exposing Timeline as the parent
on Android Back. The shortcut now constructs the declared Timeline parent stack,
and `navigation_hierarchy_test.dart` covers Search -> Timeline -> Home for that
entry.

## Adopted Test Coverage

The navigation test suite now covers:

- Home -> Timeline -> Search back chain: Search -> Timeline -> Home.
- Home search shortcut back chain: Search -> Timeline -> Home.
- Home -> Settings -> Model Providers back chain: Model Providers -> Settings -> Home.
- Chat contextual Trace Console link returns to Chat instead of exiting.
- Todos source link opens Timeline item detail through the production router and
  returns to Todos.
- Bottom-tab switches replace child stacks.
- Record action from a child page returns to Home and opens the capture sheet.
- Bottom navigation selected indices for Home-owned, Chat, Todos, and
  Plugins-owned routes.
- Deep links to Home-owned child routes construct parent stacks.
- Deep links to Plugins child routes return to Plugins root before platform
  exit.

## Remaining Product Note

Contextual source links may preserve their source page even when the durable
route owner is a different tab. That keeps "back" useful for source inspection,
while direct links still follow the declared parent hierarchy. If this feels
confusing in real device QA, revisit with a follow-up UX decision before
changing the push/go contract.

## Android Device Note

`./gradlew :app:installDevDebug --console=plain` installed successfully on a
connected Android 16 device (`b03ecb30`, package `app.widenote.dev`). The first
manual Back pass exposed the Home search shortcut issue above. After the fix was
installed, the device disconnected from adb before the post-fix manual Back pass
could be completed, so the final proof for that flow is the widget/system-back
coverage plus the successful Android dev build/install.
