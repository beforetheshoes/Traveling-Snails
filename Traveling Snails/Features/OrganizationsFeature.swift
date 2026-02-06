//
//  OrganizationsFeature.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct OrganizationsFeature {
    @ObservableState
    struct State {
        @FetchAll(Organization.order { $0.name })
        var organizations: [Organization] = []
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
