//
//  MinimalTest.swift
//  Traveling Snails Tests
//
//

import Testing

@Suite("Minimal Test")
struct MinimalTest {
    @Test("Basic test that should never hang", .tags(.unit, .fast, .parallel, .utility, .smoke, .critical))
    func testMinimal() {
        #expect(Bool(true))
    }
}
