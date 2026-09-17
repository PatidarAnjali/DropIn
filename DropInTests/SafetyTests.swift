//
//  SafetyTests.swift
//  DropInTests
//
//  Blocking hides people in both directions; reports clean up details.
//

import Foundation
import Testing
@testable import DropIn

@MainActor
@Suite("Blocking and reporting")
struct SafetyTests {

    @Test("Block documents are named blocker_blocked")
    func documentId() {
        #expect(SafetyRules.blockDocumentId(blocker: "anjali", blocked: "bob") == "anjali_bob")
        #expect(SafetyRules.blockDocumentId(blocker: "bob", blocked: "anjali") == "bob_anjali")
    }

    @Test("Blocking hides people both ways")
    func hiddenBothWays() {
        let blocks = [
            Block(blockerId: "anjali", blockedId: "bob"),
            Block(blockerId: "justin", blockedId: "anjali"),
            Block(blockerId: "mara", blockedId: "jordan"), // not about anjali
        ]
        #expect(SafetyRules.hiddenUserIds(for: "anjali", in: blocks) == ["bob", "justin"])
        #expect(SafetyRules.hiddenUserIds(for: "bob", in: blocks) == ["anjali"])
        #expect(SafetyRules.hiddenUserIds(for: "sam", in: blocks).isEmpty)
    }

    @Test("Knows who blocked whom")
    func direction() {
        let blocks = [Block(blockerId: "anjali", blockedId: "bob")]
        #expect(SafetyRules.didBlock("anjali", "bob", in: blocks))
        #expect(!SafetyRules.didBlock("bob", "anjali", in: blocks))
        #expect(SafetyRules.isBlocked(by: "anjali", me: "bob", in: blocks))
        #expect(!SafetyRules.isBlocked(by: "bob", me: "anjali", in: blocks))
    }

    @Test("Report details are trimmed, capped, and optional")
    func details() {
        #expect(SafetyRules.cleanDetails("   ") == nil)
        #expect(SafetyRules.cleanDetails("  rude messages  ") == "rude messages")
        let long = String(repeating: "a", count: 900)
        #expect(SafetyRules.cleanDetails(long)?.count == SafetyRules.maxDetailsLength)
    }
}
