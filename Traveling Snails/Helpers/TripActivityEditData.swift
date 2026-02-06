//
//  TripActivityEditData.swift
//  Traveling Snails
//
//

import Foundation

struct TripActivityEditData {
    var name: String
    var start: Date
    var end: Date
    var startTZId: String
    var endTZId: String
    var cost: Decimal
    var paid: PaidStatus
    var confirmationField: String
    var notes: String
    var organization: Organization?
    var customLocationName: String
    var customAddress: Address?
    var hideLocation: Bool
    var transportationType: TransportationType?

    init(from activity: any TripActivityProtocol) {
        self.name = activity.name
        self.start = activity.start
        self.end = activity.end
        self.startTZId = activity.startTZId
        self.endTZId = activity.endTZId
        self.cost = activity.cost
        self.paid = activity.paid
        self.confirmationField = activity.confirmationField
        self.notes = activity.notes
        self.organization = activity.organization
        self.customLocationName = activity.customLocationName
        self.customAddress = activity.customAddress
        self.hideLocation = activity.hideLocation
        self.transportationType = activity.transportationType
    }
}

extension TripActivityEditData: Equatable {
    static func == (lhs: TripActivityEditData, rhs: TripActivityEditData) -> Bool {
        lhs.name == rhs.name &&
        lhs.start == rhs.start &&
        lhs.end == rhs.end &&
        lhs.startTZId == rhs.startTZId &&
        lhs.endTZId == rhs.endTZId &&
        lhs.cost == rhs.cost &&
        lhs.paid == rhs.paid &&
        lhs.confirmationField == rhs.confirmationField &&
        lhs.notes == rhs.notes &&
        lhs.organization?.id == rhs.organization?.id &&
        lhs.customLocationName == rhs.customLocationName &&
        lhs.customAddress?.id == rhs.customAddress?.id &&
        lhs.hideLocation == rhs.hideLocation &&
        lhs.transportationType == rhs.transportationType
    }
}
