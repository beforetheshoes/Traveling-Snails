//
//  MinimalTest.swift
//  Traveling Snails Tests
//
//

import Testing

@Suite("Minimal Test")
struct MinimalTest {
    
    @Test("Basic test that should never hang")
    func testMinimal() {
        #expect(true)
    }
}