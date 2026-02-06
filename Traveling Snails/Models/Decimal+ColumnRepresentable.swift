//
//  Decimal+ColumnRepresentable.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

private struct MissingDecimalValue: Error {}

struct DecimalStringRepresentation: QueryBindable, QueryDecodable, QueryRepresentable {
    typealias QueryOutput = Decimal

    let queryOutput: Decimal

    init(queryOutput: Decimal) {
        self.queryOutput = queryOutput
    }

    init?(queryBinding: QueryBinding) {
        switch queryBinding {
        case .text(let value):
            self.queryOutput = Decimal(string: value) ?? 0
        case .double(let value):
            self.queryOutput = Decimal(value)
        case .int(let value):
            self.queryOutput = Decimal(Int(value))
        case .null:
            return nil
        default:
            return nil
        }
    }

    var queryBinding: QueryBinding {
        QueryBinding.text(NSDecimalNumber(decimal: queryOutput).stringValue)
    }

    init(decoder: inout some QueryDecoder) throws {
        if let text = try decoder.decode(String.self) {
            self.queryOutput = Decimal(string: text) ?? 0
            return
        }

        if let doubleValue = try decoder.decode(Double.self) {
            self.queryOutput = Decimal(doubleValue)
            return
        }

        if let intValue = try decoder.decode(Int64.self) {
            self.queryOutput = Decimal(Int(intValue))
            return
        }

        throw MissingDecimalValue()
    }
}
