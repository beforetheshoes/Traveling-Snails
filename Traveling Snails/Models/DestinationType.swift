//
//  DestinationType.swift
//  Traveling Snails
//
//

import Foundation

enum DestinationType: Hashable {
    case lodging(Lodging)
    case transportation(Transportation)
    case activity(Activity)

    // Computed property to get the activity ID
    var activityId: UUID {
        switch self {
        case .lodging(let l): return l.id
        case .transportation(let t): return t.id
        case .activity(let a): return a.id
        }
    }

    static func == (lhs: DestinationType, rhs: DestinationType) -> Bool {
        switch (lhs, rhs) {
        case (.lodging(let l1), .lodging(let l2)):
            return l1.id == l2.id
        case (.transportation(let t1), .transportation(let t2)):
            return t1.id == t2.id
        case (.activity(let a1), .activity(let a2)):
            return a1.id == a2.id
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .lodging(let l):
            hasher.combine("lodging")
            hasher.combine(l.id)
        case .transportation(let t):
            hasher.combine("transportation")
            hasher.combine(t.id)
        case .activity(let a):
            hasher.combine("activity")
            hasher.combine(a.id)
        }
    }

    // Helper method to create DestinationType from any TripActivityProtocol
    static func from(_ activity: any TripActivityProtocol) -> DestinationType {
        switch activity.activityType {
        case .lodging:
            return .lodging(activity as! Lodging)
        case .transportation:
            return .transportation(activity as! Transportation)
        case .activity:
            return .activity(activity as! Activity)
        }
    }
}

// MARK: - Navigation Restoration Support

struct ActivityNavigationReference: Codable {
    let activityId: UUID
    let activityType: ActivityTypeKey
    let tripId: UUID

    enum ActivityTypeKey: String, Codable {
        case lodging, transportation, activity
    }

    init(from destination: DestinationType, tripId: UUID) {
        self.tripId = tripId
        switch destination {
        case .lodging(let l):
            self.activityId = l.id
            self.activityType = .lodging
        case .transportation(let t):
            self.activityId = t.id
            self.activityType = .transportation
        case .activity(let a):
            self.activityId = a.id
            self.activityType = .activity
        }
    }

    func createDestination(from trip: Trip) -> DestinationType? {
        switch activityType {
        case .lodging:
            if let lodging = trip.lodging.first(where: { $0.id == activityId }) {
                return .lodging(lodging)
            }
        case .transportation:
            if let transportation = trip.transportation.first(where: { $0.id == activityId }) {
                return .transportation(transportation)
            }
        case .activity:
            if let activity = trip.activity.first(where: { $0.id == activityId }) {
                return .activity(activity)
            }
        }
        return nil
    }
}
