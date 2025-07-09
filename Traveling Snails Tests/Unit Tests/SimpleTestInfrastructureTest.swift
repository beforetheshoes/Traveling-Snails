//
//  SimpleTestInfrastructureTest.swift
//  Traveling Snails Tests
//
//

import Foundation
import Testing

@Suite("Simple Test Infrastructure")
struct SimpleTestInfrastructureTest {
    @Test("Basic arithmetic works", .tags(.unit, .fast, .parallel, .utility, .smoke, .validation))
    func testBasicArithmetic() {
        let result = 2 + 2
        #expect(result == 4)
    }

    @Test("String manipulation works", .tags(.unit, .fast, .parallel, .utility, .smoke, .validation))
    func testStringManipulation() {
        let str = "Hello, World!"
        #expect(str.contains("World"))
        #expect(str.count == 13)
    }

    @Test("Date creation works", .tags(.unit, .fast, .parallel, .utility, .smoke, .validation))
    func testDateCreation() {
        let date = Date()
        let now = Date()
        #expect(date.timeIntervalSince1970 > 0)
        #expect(now.timeIntervalSince(date) >= 0)
    }

    @Test("Array operations work", .tags(.unit, .fast, .parallel, .utility, .smoke, .validation))
    func testArrayOperations() {
        let numbers = [1, 2, 3, 4, 5]
        #expect(numbers.count == 5)
        #expect(numbers.first == 1)
        #expect(numbers.last == 5)
        #expect(numbers.contains(3))
    }
}
