//
//  DestinationType.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/31/25.
//

import Foundation

enum DestinationType: Hashable {
    case lodging(Lodging)
    case transportation(Transportation)
    case activity(Activity)
    
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
}
