//
//  TripActivity.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/24/25.
//

import Foundation

protocol TripActivity: Identifiable {
    var name: String { get }
    var start: Date { get }
    var end: Date { get }
}
