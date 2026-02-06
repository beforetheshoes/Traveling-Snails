//
//  LegacyInitializers.swift
//  Traveling Snails
//

import Foundation

extension Activity {
    init(
        name: String = "",
        start: Date = Date(),
        startTZ: TimeZone? = nil,
        end: Date = Date(),
        endTZ: TimeZone? = nil,
        cost: Decimal = 0,
        paid: PaidStatus = PaidStatus.none,
        reservation: String = "",
        notes: String = "",
        trip: Trip? = nil,
        organization: Organization? = nil,
        customLocationName: String = "",
        customAddress: Address? = nil,
        hideLocation: Bool = false
    ) {
        self.init(
            id: UUID(),
            name: name,
            start: start,
            startTZId: startTZ?.identifier ?? TimeZone.current.identifier,
            end: end,
            endTZId: endTZ?.identifier ?? TimeZone.current.identifier,
            cost: cost,
            paid: paid,
            reservation: reservation,
            notes: notes,
            tripID: trip?.id,
            organizationID: organization?.id,
            addressID: customAddress?.id,
            customLocationName: customLocationName,
            hideLocation: hideLocation
        )
    }
}

extension Lodging {
    init(
        name: String = "",
        start: Date = Date(),
        checkInTZ: TimeZone? = nil,
        end: Date = Date(),
        checkOutTZ: TimeZone? = nil,
        cost: Decimal = 0,
        paid: PaidStatus = PaidStatus.none,
        reservation: String = "",
        notes: String = "",
        trip: Trip? = nil,
        organization: Organization? = nil,
        customLocationName: String = "",
        customAddress: Address? = nil,
        hideLocation: Bool = false
    ) {
        self.init(
            id: UUID(),
            name: name,
            start: start,
            checkInTZId: checkInTZ?.identifier ?? TimeZone.current.identifier,
            end: end,
            checkOutTZId: checkOutTZ?.identifier ?? TimeZone.current.identifier,
            cost: cost,
            paid: paid,
            reservation: reservation,
            notes: notes,
            tripID: trip?.id,
            organizationID: organization?.id,
            addressID: customAddress?.id,
            customLocationName: customLocationName,
            hideLocation: hideLocation
        )
    }
}

extension Transportation {
    init(
        name: String = "",
        type: TransportationType = TransportationType.plane,
        start: Date = Date(),
        startTZ: TimeZone? = nil,
        end: Date = Date(),
        endTZ: TimeZone? = nil,
        cost: Decimal = 0,
        paid: PaidStatus = PaidStatus.none,
        confirmation: String = "",
        notes: String = "",
        trip: Trip? = nil,
        organization: Organization? = nil
    ) {
        self.init(
            id: UUID(),
            name: name,
            type: type,
            start: start,
            startTZId: startTZ?.identifier ?? TimeZone.current.identifier,
            end: end,
            endTZId: endTZ?.identifier ?? TimeZone.current.identifier,
            cost: cost,
            paid: paid,
            confirmation: confirmation,
            notes: notes,
            tripID: trip?.id,
            organizationID: organization?.id
        )
    }
}
