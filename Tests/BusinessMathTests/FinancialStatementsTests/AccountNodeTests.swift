//
//  AccountNodeTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 4/15/26.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("AccountNode Tests")
struct AccountNodeTests {

    // MARK: - Test Helpers

    private func makeEntity() -> Entity {
        Entity(id: "TEST", primaryType: .internal, name: "Test Company")
    }

    private func makeAccount(name: String, values: [Double]) throws -> Account<Double> {
        let periods = [
            Period.month(year: 2025, month: 1),
            Period.month(year: 2025, month: 2),
            Period.month(year: 2025, month: 3)
        ]
        return try Account(
            entity: makeEntity(),
            name: name,
            incomeStatementRole: .revenue,
            timeSeries: TimeSeries(periods: periods, values: values)
        )
    }

    private var jan2025: Period { Period.month(year: 2025, month: 1) }
    private var feb2025: Period { Period.month(year: 2025, month: 2) }
    private var mar2025: Period { Period.month(year: 2025, month: 3) }

    // MARK: - 1. Single Node Total

    @Test("Single leaf node total equals its account value for a period")
    func singleNodeTotal() throws {
        let account = try makeAccount(name: "Revenue", values: [100.0, 200.0, 300.0])
        let node = AccountNode<Double>(id: "rev", account: account)

        #expect(node.total(for: jan2025) == 100.0)
        #expect(node.total(for: feb2025) == 200.0)
        #expect(node.total(for: mar2025) == 300.0)
    }

    // MARK: - 2. Parent + Children Rollup

    @Test("Parent total equals sum of children totals")
    func parentChildrenRollup() throws {
        let productRevenue = try makeAccount(name: "Product Revenue", values: [100.0, 200.0, 300.0])
        let serviceRevenue = try makeAccount(name: "Service Revenue", values: [50.0, 60.0, 70.0])

        let child1 = AccountNode<Double>(id: "product", account: productRevenue)
        let child2 = AccountNode<Double>(id: "service", account: serviceRevenue)
        let parent = AccountNode<Double>(id: "totalRevenue", account: nil, children: [child1, child2])

        #expect(parent.total(for: jan2025) == 150.0)
        #expect(parent.total(for: feb2025) == 260.0)
        #expect(parent.total(for: mar2025) == 370.0)
    }

    // MARK: - 3. Three-Level Hierarchy

    @Test("Three-level hierarchy rolls up correctly")
    func threeLevelHierarchy() throws {
        let a = try makeAccount(name: "A", values: [10.0, 20.0, 30.0])
        let b = try makeAccount(name: "B", values: [5.0, 10.0, 15.0])
        let c = try makeAccount(name: "C", values: [3.0, 6.0, 9.0])

        let leafA = AccountNode<Double>(id: "a", account: a)
        let leafB = AccountNode<Double>(id: "b", account: b)
        let leafC = AccountNode<Double>(id: "c", account: c)

        let mid = AccountNode<Double>(id: "mid", account: nil, children: [leafA, leafB])
        let root = AccountNode<Double>(id: "root", account: nil, children: [mid, leafC])

        // root = mid(a + b) + c = (10+5) + 3 = 18 for jan
        #expect(root.total(for: jan2025) == 18.0)
        #expect(root.total(for: feb2025) == 36.0)
        #expect(root.total(for: mar2025) == 54.0)
    }

    // MARK: - 4. Grouping Node (nil account)

    @Test("Grouping node with nil account computes total from children only")
    func groupingNode() throws {
        let account = try makeAccount(name: "Revenue", values: [100.0, 200.0, 300.0])
        let child = AccountNode<Double>(id: "rev", account: account)
        let grouping = AccountNode<Double>(id: "group", account: nil, children: [child])

        #expect(grouping.account == nil)
        #expect(grouping.total(for: jan2025) == 100.0)
    }

    // MARK: - 5. Find by ID (BFS)

    @Test("Find by ID locates a deeply nested node")
    func findByID() throws {
        let account = try makeAccount(name: "Target", values: [1.0, 2.0, 3.0])
        let target = AccountNode<Double>(id: "target", account: account)
        let mid = AccountNode<Double>(id: "mid", account: nil, children: [target])
        let root = AccountNode<Double>(id: "root", account: nil, children: [mid])

        let found = root.find(id: "target")
        #expect(found != nil)
        #expect(found?.id == "target")
        #expect(found?.total(for: jan2025) == 1.0)
    }

    // MARK: - 6. Find Missing ID

    @Test("Find returns nil for nonexistent ID")
    func findMissing() throws {
        let account = try makeAccount(name: "Revenue", values: [100.0, 200.0, 300.0])
        let node = AccountNode<Double>(id: "rev", account: account)

        #expect(node.find(id: "nonexistent") == nil)
    }

    // MARK: - 7. Empty Children (Leaf Node)

    @Test("Leaf node has empty children array")
    func emptyChildren() throws {
        let account = try makeAccount(name: "Revenue", values: [100.0, 200.0, 300.0])
        let node = AccountNode<Double>(id: "rev", account: account)

        #expect(node.children.isEmpty)
    }

    // MARK: - 8. Add Child

    @Test("addChild mutates children array")
    func addChild() throws {
        let account = try makeAccount(name: "Revenue", values: [100.0, 200.0, 300.0])
        let child = AccountNode<Double>(id: "child", account: account)
        var parent = AccountNode<Double>(id: "parent", account: nil)

        #expect(parent.children.isEmpty)
        parent.addChild(child)
        #expect(parent.children.count == 1)
        #expect(parent.total(for: jan2025) == 100.0)
    }

    // MARK: - 9. Sendable Compliance

    @Test("AccountNode conforms to Sendable")
    func sendableCompliance() throws {
        let account = try makeAccount(name: "Revenue", values: [100.0, 200.0, 300.0])
        let node = AccountNode<Double>(id: "rev", account: account)

        // Verify Sendable by passing across isolation boundary
        let sendableCheck: @Sendable () -> String = { node.id }
        #expect(sendableCheck() == "rev")
    }

    // MARK: - 10. Total for Missing Period

    @Test("Total returns zero for a period not in any account")
    func totalMissingPeriod() throws {
        let account = try makeAccount(name: "Revenue", values: [100.0, 200.0, 300.0])
        let node = AccountNode<Double>(id: "rev", account: account)
        let missingPeriod = Period.month(year: 2099, month: 12)

        #expect(node.total(for: missingPeriod) == 0.0)
    }
}
