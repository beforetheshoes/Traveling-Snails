# Zero-Known-Issues Compliance Rubric

This rubric is frozen for app-owned code under `Traveling Snails/` and tests under `Traveling Snails Tests/`.

## Domains

1. TCA
- No production fallback `Store(initialState:)` construction inside views.
- Feature state should avoid stale snapshot ownership where reactive query-backed state is expected.
- Root/state `Equatable` must include meaningful child state evolution.

2. SQLiteData
- No broad `@FetchAll` + in-memory filtering for hot-path/detail views when scoped query is possible.
- Writes should not rely on stale snapshot state with no refresh path.

3. Swift Concurrency
- No `Task.detached` in UI/view lifecycle paths.
- AsyncStream/task lifecycle must cancel all spawned work on termination.

4. Modern SwiftUI
- Migrate legacy APIs in app-owned code (`foregroundColor`, `cornerRadius`, legacy `.tabItem` usage where modern API is available for target OS).
- Avoid unnecessary `AnyView` erasure in hot paths.

## Pass/Fail

A run is PASS only when all app-owned checks return zero open findings.
