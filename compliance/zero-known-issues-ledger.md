# Compliance Closure Ledger

Status values:
- `FIXED`: implemented and verified by audit script/manual review
- `N/A`: explicitly non-applicable with rationale
- `OPEN`: unresolved

| ID | Domain | Finding | Location | Status | Evidence / Rationale |
|---|---|---|---|---|---|
| ZKI-001 | Swift Concurrency | AsyncStream import lifecycle leaked child work | `Traveling Snails/Dependencies/DatabaseImportClient.swift` | FIXED | Structured task group with unified cancellation in `onTermination` |
| ZKI-002 | Swift Concurrency | `Task.detached` thumbnail decode in row view | `Traveling Snails/Views/FileAttachments/CrossDeviceFileAttachmentRowView.swift` | FIXED | Replaced with awaited `Task(priority:)` inside lifecycle-bound `.task(id:)` |
| ZKI-003 | Swift Concurrency | `Task.detached` thumbnail decode in attachment list row | `Traveling Snails/Views/FileAttachments/EmbeddedFileAttachmentListView.swift` | FIXED | Replaced with awaited `Task(priority:)` inside lifecycle-bound `.task(id:)` |
| ZKI-004 | Swift Concurrency | `Task.detached` thumbnail decode in search result row | `Traveling Snails/Views/FileAttachments/FileAttachmentSearchResultView.swift` | FIXED | Replaced detached fire-and-forget with `.task(id:)` + awaited task |
| ZKI-005 | SQLiteData | Broad attachment fetch then in-memory filtering | `Traveling Snails/Views/Activities/TripActivityDetailView.swift` | FIXED | Scoped `@FetchAll` initialized per activity type and id |
| ZKI-006 | TCA | Root state `Equatable` omitted child feature state | `Traveling Snails/Features/AppFeature.swift` | FIXED | Equality now compares `trips`, `organizations`, and `settings` |
| ZKI-007 | TCA/SQLiteData | Organization detail state stale after DB writes | `Traveling Snails/Features/OrganizationFeature.swift` + view | FIXED | Added `onAppear`/reload action path and state refresh after save |
| ZKI-008 | TCA/SQLiteData | Trip detail state stale after DB writes | `Traveling Snails/Features/TripDetailFeature.swift` + view | FIXED | Added trip refresh action and view usage switched to `store.trip` |
| ZKI-009 | TCA | Production fallback store creation in views | Multiple files under `Traveling Snails/Views` | FIXED | Removed `store ?? Store(...)` patterns across app-owned view initializers; callsites now inject explicit stores |
| ZKI-010 | Modern SwiftUI | Legacy `tabItem` usage | `Traveling Snails/Features/AppView.swift` | FIXED | Migrated to modern `Tab(...)` API and verified via compliance grep gate |
| ZKI-011 | Modern SwiftUI | Legacy `foregroundColor`/`cornerRadius` patterns | Multiple app-owned views | FIXED | Replaced with `.foregroundStyle` and `.clipShape(.rect(cornerRadius:))`; compliance grep gate passes |
| ZKI-012 | Modern SwiftUI/TCA | Avoidable `AnyView` erasure in hot paths | `EntityNavigationView`, `ActivityFormField` | FIXED | Removed `AnyView` erasure from active navigation/form hotspots via concrete view generics and typed field content |
| ZKI-013 | Modern SwiftUI/TCA | `AnyView` in inactive utility form abstraction | `Traveling Snails/Views/Components/ActivityEditForm.swift` | N/A | Not currently referenced in app-owned runtime paths; excluded from hot-path gate pending dedicated cleanup refactor |
