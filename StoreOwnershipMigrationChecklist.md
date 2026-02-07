# Store Ownership Migration Checklist

Purpose: track remaining views that still create fallback `Store(...)` instances in view initializers.

## Status
- [x] `IsolatedTripDetailView` (`/Users/ryan/Developer/Swift/Traveling Snails/Traveling Snails/Views/Trips/IsolatedTripDetailView.swift`)
- [x] `EditTripView` (`/Users/ryan/Developer/Swift/Traveling Snails/Traveling Snails/Views/Trips/EditTripView.swift`)
- [x] `TripSharingView` (`/Users/ryan/Developer/Swift/Traveling Snails/Traveling Snails/Views/Trips/TripSharingView.swift`)
- [x] `AddTrip` (`/Users/ryan/Developer/Swift/Traveling Snails/Traveling Snails/Views/Trips/AddTrip.swift`)
- [x] `ShareInvitationView` (`/Users/ryan/Developer/Swift/Traveling Snails/Traveling Snails/Views/Trips/ShareInvitationView.swift`)
- [x] `UnifiedTripActivityDetailView` (`/Users/ryan/Developer/Swift/Traveling Snails/Traveling Snails/Views/UnifiedTripActivities/UnifiedTripActivityDetailView.swift`)
- [x] `OrganizationDetailView` (`/Users/ryan/Developer/Swift/Traveling Snails/Traveling Snails/Views/Organizations/OrganizationDetailView.swift`)
- [x] `OrganizationPicker` (`/Users/ryan/Developer/Swift/Traveling Snails/Traveling Snails/Views/Organizations/OrganizationPicker.swift`)
- [x] `PrefilledAddActivityView` (`/Users/ryan/Developer/Swift/Traveling Snails/Traveling Snails/Views/Calendar/PrefilledAddActivityView.swift`)
- [x] `EmbeddedFileAttachmentListView` (`/Users/ryan/Developer/Swift/Traveling Snails/Traveling Snails/Views/FileAttachments/EmbeddedFileAttachmentListView.swift`)
- [x] `CrossDeviceEditFileAttachmentView` (`/Users/ryan/Developer/Swift/Traveling Snails/Traveling Snails/Views/FileAttachments/CrossDeviceEditFileAttachmentView.swift`)
- [x] `DebugDataView` (`/Users/ryan/Developer/Swift/Traveling Snails/Traveling Snails/Views/Settings/DebugDataView.swift`)
- [x] `ToolsTab` (`/Users/ryan/Developer/Swift/Traveling Snails/Traveling Snails/Views/Settings/ToolsTab.swift`)

## Migration rule
- Replace init-time fallback `self.store = store ?? Store(...)` with stable store lifetime (`@State` with `State(initialValue:)` or parent-provided store ownership) so view re-initialization does not reset navigation/presentation/edit state.
