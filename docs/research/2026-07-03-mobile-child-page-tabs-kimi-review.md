# Mobile Child Page Bottom Tabs Kimi Review

Date: 2026-07-03

Scope: external review of the mobile navigation shell change that hides bottom
tabs on all non-root child pages.

Input hygiene:

- Sent the current user request, implementation summary, relevant navigation
  contracts, ADR-0015/ADR-0019 context, router/test/docs diff, and local
  validation commands.
- Did not send local databases, user records, backup artifacts, provider keys,
  credentials, raw private prompts, or secret-bearing files.
- Kimi was asked to review design fit, code risk, route coverage, documentation
  placement, and test gaps.

## Review Result

Kimi's conclusion: approve.

No P0 or P1 issues were reported. Kimi agreed that showing the bottom
navigation bar only on `/`, `/chat`, `/todos`, and `/plugins` matches the
product expectation that child pages are independent pages without bottom tabs.
The review also found the route whitelist complete for the currently declared
mobile routes and considered the ADR-0019 partial supersession of ADR-0015
consistent with existing ADR-0016 / ADR-0012 precedent.

## Findings

| Priority | Finding | Disposition |
| --- | --- | --- |
| P0 | No blocker found. | No action needed. |
| P1 | No required fix found. | No action needed. |
| P2 | `_selectedIndex` used prefix matching while bottom-tab visibility used exact root matching. | Adopted: `_selectedIndex` now uses exact route matching. |
| P2 | Cross-tab child-link tests could explicitly assert that destination child pages hide the bottom navigation bar. | Adopted: `navigation_hierarchy_test.dart` now asserts hidden bottom tabs for chat-to-trace and todo-source detail flows. |
| P3 | ADR title capitalization could be normalized. | Deferred; does not affect the decision. |

## Final Sanity Review

After the P2 suggestions were adopted and the i18n widget test was updated for
the new child-page shell behavior, Kimi performed a second read-only sanity
review of the final diff. The final conclusion was also approve, with no P0,
P1, or new P2 findings.

## Local Validation Recorded For Review

- `dart format apps/mobile/lib/app/app_router.dart apps/mobile/test/navigation_hierarchy_test.dart apps/mobile/test/model_provider_settings_test.dart`
- `env -u ws_proxy -u wss_proxy NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 flutter test test/navigation_hierarchy_test.dart test/model_provider_settings_test.dart`
- `env -u ws_proxy -u wss_proxy NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 flutter test test/i18n_widget_test.dart test/navigation_hierarchy_test.dart test/model_provider_settings_test.dart`
- `env -u ws_proxy -u wss_proxy NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 flutter test`
- `env -u ws_proxy -u wss_proxy NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 flutter analyze`
- `git diff --check`

## Follow-Up

If a future mobile page needs persistent bottom-tab access while visible, treat
it as a new peer root and record that as a separate navigation decision instead
of adding a child-page exception.
