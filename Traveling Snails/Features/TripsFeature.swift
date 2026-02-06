//
//  TripsFeature.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct TripsFeature {
    @ObservableState
    struct State {
        @FetchAll(Trip.order { $0.createdDate.desc() })
        var trips: [Trip] = []
    }

    enum Action {
        case noop
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .noop:
                return .none
            }
        }
    }
}
