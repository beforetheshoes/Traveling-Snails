import ComposableArchitecture
import Testing

@testable import Traveling_Snails

@Suite("OrganizationPickerFeature Tests")
@MainActor
struct OrganizationPickerFeatureTests {
    @Test("tapping organization selects and dismisses")
    func organizationTapSelectsAndDismisses() async {
        let id = Organization.ID()

        let store = TestStore(initialState: OrganizationPickerFeature.State()) {
            OrganizationPickerFeature()
        }

        await store.send(.organizationTapped(id)) {
            $0.selectedOrganizationID = id
            $0.shouldDismiss = true
        }
    }

    @Test("creating organization closes sheet and dismisses")
    func creationDismisses() async {
        let id = Organization.ID()

        let store = TestStore(initialState: OrganizationPickerFeature.State()) {
            OrganizationPickerFeature()
        }

        await store.send(.addNewTapped) {
            $0.showingAddOrganization = true
        }

        await store.send(.organizationCreated(id)) {
            $0.selectedOrganizationID = id
            $0.showingAddOrganization = false
            $0.shouldDismiss = true
        }
    }
}
