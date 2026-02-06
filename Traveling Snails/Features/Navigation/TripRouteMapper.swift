import SQLiteData

enum TripRouteMapper {
    static func route(from activity: any TripActivityProtocol) -> TripRoute? {
        switch activity {
        case let lodging as Lodging:
            return .lodging(lodging.id)
        case let transportation as Transportation:
            return .transportation(transportation.id)
        case let activity as Activity:
            return .activity(activity.id)
        default:
            return nil
        }
    }

    static func destination(from route: TripRoute, in trip: Trip) -> DestinationType? {
        switch route {
        case .lodging(let id):
            guard let lodging = trip.lodging.first(where: { $0.id == id }) else { return nil }
            return .lodging(lodging)
        case .transportation(let id):
            guard let transportation = trip.transportation.first(where: { $0.id == id }) else { return nil }
            return .transportation(transportation)
        case .activity(let id):
            guard let activity = trip.activity.first(where: { $0.id == id }) else { return nil }
            return .activity(activity)
        }
    }
}
