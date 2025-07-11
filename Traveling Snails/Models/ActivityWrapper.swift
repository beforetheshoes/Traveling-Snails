//
//  ActivityWrapper.swift
//  Traveling Snails
//
//

import SwiftUI

struct ActivityWrapper: Identifiable, Equatable {
    let id = UUID()
    let tripActivity: any TripActivityProtocol
    let type: ActivityType

    enum ActivityType: String {
        case lodging = "Lodging"
        case transportation = "Transportation"
        case activity = "Activity"

        var icon: String {
            switch self {
            case .lodging: return "bed.double.fill"
            case .transportation: return "car.fill"
            case .activity: return "ticket.fill"
            }
        }

        var color: Color {
            switch self {
            case .lodging: return .indigo
            case .transportation: return .blue
            case .activity: return .purple
            }
        }
    }

    init(_ tripActivity: any TripActivityProtocol) {
        self.tripActivity = tripActivity

        switch tripActivity {
        case is Lodging:
            self.type = .lodging
        case is Transportation:
            self.type = .transportation
        case is Activity:
            self.type = .activity
        default:
            self.type = .activity
        }
    }

    static func == (lhs: ActivityWrapper, rhs: ActivityWrapper) -> Bool {
        // Use the underlying trip activity ID for equality comparison
        lhs.tripActivity.id == rhs.tripActivity.id
    }
}
