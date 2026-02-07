import SwiftUI

struct TripDetailView: View {
    enum ViewMode: String, CaseIterable {
        case list = "List"
        case calendar = "Calendar"

        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .calendar: return "calendar"
            }
        }
    }

    let trip: Trip

    @State private var path: [TripRoute] = []
    @State private var resetToken = 0

    var body: some View {
        NavigationStack(path: $path) {
            IsolatedTripDetailView(
                trip: trip,
                path: $path,
                resetToken: resetToken
            )
            .navigationDestination(for: TripRoute.self) { route in
                if let destination = TripRouteMapper.destination(from: route, in: trip) {
                    tripDestinationView(destination)
                } else {
                    ContentUnavailableView(
                        "Activity Not Found",
                        systemImage: "exclamationmark.triangle"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func tripDestinationView(_ destination: DestinationType) -> some View {
        switch destination {
        case .lodging(let lodging):
            TripActivityDetailView<Lodging>(activity: lodging)
        case .transportation(let transportation):
            TripActivityDetailView<Transportation>(activity: transportation)
        case .activity(let activity):
            TripActivityDetailView<Activity>(activity: activity)
        }
    }
}

#Preview {
    NavigationStack {
        TripDetailView(trip: .init(name: "Test Trip"))
    }
}
