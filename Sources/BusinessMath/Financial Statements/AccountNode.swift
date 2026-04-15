//
//  AccountNode.swift
//  BusinessMath
//
//  Created by Justin Purnell on 4/15/26.
//

import Foundation
import Numerics

// MARK: - AccountNode

/// A tree node for organizing financial accounts hierarchically.
///
/// `AccountNode` enables hierarchical grouping of financial accounts where a parent
/// node's total for any period equals the sum of its children's totals. Leaf nodes
/// wrap an ``Account`` directly, while grouping nodes have a `nil` account and derive
/// their totals entirely from children.
///
/// ## Creating a Hierarchy
///
/// ```swift
/// // Leaf nodes with actual account data
/// let productRevenue = AccountNode<Double>(id: "product", account: productAccount)
/// let serviceRevenue = AccountNode<Double>(id: "service", account: serviceAccount)
///
/// // Grouping node aggregates children
/// let totalRevenue = AccountNode<Double>(
///     id: "totalRevenue",
///     account: nil,
///     children: [productRevenue, serviceRevenue]
/// )
///
/// // Query aggregated totals
/// let janTotal = totalRevenue.total(for: Period.month(year: 2025, month: 1))
/// ```
///
/// ## Searching the Tree
///
/// Use ``find(id:)`` to locate a node anywhere in the hierarchy via breadth-first search:
///
/// ```swift
/// if let node = root.find(id: "service") {
///     print(node.total(for: period))
/// }
/// ```
///
/// ## Topics
///
/// ### Creating Nodes
/// - ``init(id:account:children:)``
/// - ``addChild(_:)``
///
/// ### Querying Values
/// - ``total(for:)``
/// - ``find(id:)``
///
/// ### Properties
/// - ``id``
/// - ``account``
/// - ``children``
public struct AccountNode<T: Real & Sendable>: Sendable where T: Codable {

    /// A unique identifier for this node within the hierarchy.
    public let id: String

    /// The underlying account, or `nil` for grouping-only nodes.
    ///
    /// Leaf nodes typically have an account; grouping nodes that exist solely
    /// to aggregate children have `nil`.
    public let account: Account<T>?

    /// The child nodes in the hierarchy.
    ///
    /// A leaf node has an empty `children` array. A grouping node derives
    /// its ``total(for:)`` from the sum of its children's totals.
    public private(set) var children: [AccountNode<T>]

    // MARK: - Initialization

    /// Creates a new account node.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for this node.
    ///   - account: The underlying account, or `nil` for grouping nodes.
    ///   - children: Child nodes in the hierarchy. Defaults to an empty array.
    public init(id: String, account: Account<T>?, children: [AccountNode<T>] = []) {
        self.id = id
        self.account = account
        self.children = children
    }

    // MARK: - Mutation

    /// Adds a child node to this node's children.
    ///
    /// - Parameter child: The node to add as a child.
    public mutating func addChild(_ child: AccountNode<T>) {
        children.append(child)
    }

    // MARK: - Aggregation

    /// Returns the total value for the given period.
    ///
    /// - If this node has children, returns the sum of all children's totals (recursive).
    /// - If this node is a leaf with an account, returns the account's value for the period.
    /// - If neither children nor account exist, returns zero.
    ///
    /// - Parameter period: The time period to query.
    /// - Returns: The aggregated total for the period.
    public func total(for period: Period) -> T {
        guard children.isEmpty else {
            return children.reduce(T.zero) { sum, child in
                sum + child.total(for: period)
            }
        }

        guard let account = account else {
            return T.zero
        }

        return account.timeSeries[period] ?? T.zero
    }

    // MARK: - Search

    /// Finds a node by its identifier using breadth-first search.
    ///
    /// Searches this node and all descendants for a node matching the given ID.
    ///
    /// - Parameter id: The identifier to search for.
    /// - Returns: The matching node, or `nil` if not found.
    public func find(id: String) -> AccountNode<T>? {
        var queue: [AccountNode<T>] = [self]

        while !queue.isEmpty {
            let current = queue.removeFirst()
            if current.id == id {
                return current
            }
            queue.append(contentsOf: current.children)
        }

        return nil
    }
}
