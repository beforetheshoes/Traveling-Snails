import Foundation
import Testing

@testable import Traveling_Snails

@Suite("Trip Route Mapper Tests")
struct TripRouteMapperTests {
    @Test("Maps Activity to TripRoute.activity", .tags(.unit, .fast, .parallel, .navigation))
    func mapsActivityToRoute() {
        let activityID = UUID()
        let activity = Activity(id: activityID, name: "Museum")
        #expect(TripRouteMapper.route(from: activity) == .activity(activityID))
    }

    @Test("Maps Lodging to TripRoute.lodging", .tags(.unit, .fast, .parallel, .navigation))
    func mapsLodgingToRoute() {
        let lodgingID = UUID()
        let lodging = Lodging(id: lodgingID, name: "Hotel")
        #expect(TripRouteMapper.route(from: lodging) == .lodging(lodgingID))
    }

    @Test("Maps Transportation to TripRoute.transportation", .tags(.unit, .fast, .parallel, .navigation))
    func mapsTransportationToRoute() {
        let transportationID = UUID()
        let transportation = Transportation(id: transportationID, name: "Flight")
        #expect(TripRouteMapper.route(from: transportation) == .transportation(transportationID))
    }
}
