//
//  ConsolidatedStatements.swift
//  BusinessMath
//
//  Created by Claude Code on 02/15/26.
//

import Foundation
import Numerics

// MARK: - Consolidated Statements

/// Multi-entity financial analysis for comparative valuation and portfolio analysis.
///
/// `ConsolidatedStatements` aggregates financial data across multiple entities,
/// enabling:
/// - **Peer comparisons**: Compare valuation multiples, margins, growth rates
/// - **Parent/subsidiary consolidation**: Aggregate subsidiaries into parent
/// - **Portfolio analysis**: Analyze holdings across multiple companies
/// - **Sector analysis**: Compare companies within the same industry
///
/// ## Example: Peer Comparison
///
/// ```swift
/// let apple = Entity(id: "AAPL", primaryType: .ticker, name: "Apple Inc.")
/// let microsoft = Entity(id: "MSFT", primaryType: .ticker, name: "Microsoft Corp.")
/// let google = Entity(id: "GOOGL", primaryType: .ticker, name: "Alphabet Inc.")
///
/// let q1_2025 = Period.quarter(year: 2025, quarter: 1)
///
/// var consolidated = ConsolidatedStatements<Double>()
/// consolidated.add(entity: apple, period: q1_2025, summary: appleSummary)
/// consolidated.add(entity: microsoft, period: q1_2025, summary: msftSummary)
/// consolidated.add(entity: google, period: q1_2025, summary: googleSummary)
///
/// // Compare metrics across peers
/// let peGratios = consolidated.entities.map { entity in
///     (entity.name, consolidated.summary(for: entity, period: q1_2025)?.priceToEarnings ?? 0)
/// }
/// ```
///
/// ## Example: Parent/Subsidiary Consolidation
///
/// ```swift
/// let parent = Entity(id: "PARENT", primaryType: .internal, name: "Parent Co")
/// let sub1 = Entity(id: "SUB1", primaryType: .internal, name: "Europe Division")
/// let sub2 = Entity(id: "SUB2", primaryType: .internal, name: "Asia Division")
///
/// var consolidated = ConsolidatedStatements<Double>()
/// consolidated.add(entity: parent, period: q1, summary: parentSummary)
/// consolidated.add(entity: sub1, period: q1, summary: sub1Summary)
/// consolidated.add(entity: sub2, period: q1, summary: sub2Summary)
///
/// // Calculate aggregate metrics
/// let totalRevenue = consolidated.aggregateRevenue(for: q1, entities: [parent, sub1, sub2])
/// ```
public struct ConsolidatedStatements<T: Real & Sendable>: Sendable where T: Codable {

	/// Internal storage: [Entity ID -> [Period -> Summary]]
	private var storage: [String: [Period: FinancialPeriodSummary<T>]]

	/// Entity lookup by ID
	private var entityLookup: [String: Entity]

	/// Creates an empty consolidated statements container.
	public init() {
		self.storage = [:]
		self.entityLookup = [:]
	}

	// MARK: - Adding Data

	/// Add a financial summary for an entity and period.
	///
	/// If a summary already exists for this entity/period combination, it will be replaced.
	///
	/// - Parameters:
	///   - entity: The entity this summary belongs to
	///   - period: The period this summary covers
	///   - summary: The financial summary data
	public mutating func add(
		entity: Entity,
		period: Period,
		summary: FinancialPeriodSummary<T>
	) {
		// Store entity if we haven't seen it
		entityLookup[entity.id] = entity

		// Store summary
		if storage[entity.id] == nil {
			storage[entity.id] = [:]
		}
		storage[entity.id]?[period] = summary
	}

	/// Add multiple summaries for an entity across periods.
	///
	/// - Parameters:
	///   - entity: The entity these summaries belong to
	///   - summaries: Dictionary mapping periods to summaries
	public mutating func add(
		entity: Entity,
		summaries: [Period: FinancialPeriodSummary<T>]
	) {
		entityLookup[entity.id] = entity
		storage[entity.id] = summaries
	}

	/// Add a multi-period report for an entity.
	///
	/// - Parameter report: Multi-period report containing entity and summaries
	public mutating func add(report: MultiPeriodReport<T>) {
		entityLookup[report.entity.id] = report.entity

		var periodSummaries: [Period: FinancialPeriodSummary<T>] = [:]
		for summary in report.periodSummaries {
			periodSummaries[summary.period] = summary
		}

		if let annual = report.annualSummary {
			periodSummaries[annual.period] = annual
		}

		storage[report.entity.id] = periodSummaries
	}

	// MARK: - Accessing Data

	/// Retrieve a summary for a specific entity and period.
	///
	/// - Parameters:
	///   - entity: The entity to retrieve
	///   - period: The period to retrieve
	/// - Returns: The financial summary, or nil if not found
	public func summary(
		for entity: Entity,
		period: Period
	) -> FinancialPeriodSummary<T>? {
		return storage[entity.id]?[period]
	}

	/// Retrieve all summaries for a specific entity.
	///
	/// - Parameter entity: The entity to retrieve
	/// - Returns: Dictionary mapping periods to summaries
	public func summaries(for entity: Entity) -> [Period: FinancialPeriodSummary<T>] {
		return storage[entity.id] ?? [:]
	}

	/// Retrieve all summaries for a specific period across all entities.
	///
	/// - Parameter period: The period to retrieve
	/// - Returns: Dictionary mapping entities to summaries
	public func summaries(for period: Period) -> [Entity: FinancialPeriodSummary<T>] {
		var result: [Entity: FinancialPeriodSummary<T>] = [:]

		for (entityId, periods) in storage {
			if let summary = periods[period],
			   let entity = entityLookup[entityId] {
				result[entity] = summary
			}
		}

		return result
	}

	/// All entities in this consolidated view.
	public var entities: [Entity] {
		return Array(entityLookup.values).sorted { $0.id < $1.id }
	}

	/// All periods represented across all entities.
	public var periods: [Period] {
		let allPeriods = storage.values.flatMap { $0.keys }
		return Array(Set(allPeriods)).sorted { $0.startDate < $1.startDate }
	}

	/// Number of entities in this consolidated view.
	public var entityCount: Int {
		return entityLookup.count
	}

	/// Check if data exists for an entity and period.
	///
	/// - Parameters:
	///   - entity: The entity to check
	///   - period: The period to check
	/// - Returns: `true` if summary exists
	public func contains(entity: Entity, period: Period) -> Bool {
		return storage[entity.id]?[period] != nil
	}

	// MARK: - Aggregation

	/// Aggregate revenue across multiple entities for a specific period.
	///
	/// Useful for consolidating subsidiaries or calculating portfolio totals.
	///
	/// - Parameters:
	///   - period: The period to aggregate
	///   - entities: Optional array of entities to include (defaults to all)
	/// - Returns: Sum of revenue, or zero if no data
	public func aggregateRevenue(
		for period: Period,
		entities: [Entity]? = nil
	) -> T {
		let targetEntities = entities ?? self.entities

		return targetEntities.reduce(T.zero) { sum, entity in
			guard let summary = storage[entity.id]?[period] else { return sum }
			return sum + summary.revenue
		}
	}

	/// Aggregate net income across multiple entities for a specific period.
	///
	/// - Parameters:
	///   - period: The period to aggregate
	///   - entities: Optional array of entities to include (defaults to all)
	/// - Returns: Sum of net income, or zero if no data
	public func aggregateNetIncome(
		for period: Period,
		entities: [Entity]? = nil
	) -> T {
		let targetEntities = entities ?? self.entities

		return targetEntities.reduce(T.zero) { sum, entity in
			guard let summary = storage[entity.id]?[period] else { return sum }
			return sum + summary.netIncome
		}
	}

	/// Aggregate total assets across multiple entities for a specific period.
	///
	/// - Parameters:
	///   - period: The period to aggregate
	///   - entities: Optional array of entities to include (defaults to all)
	/// - Returns: Sum of total assets, or zero if no data
	public func aggregateTotalAssets(
		for period: Period,
		entities: [Entity]? = nil
	) -> T {
		let targetEntities = entities ?? self.entities

		return targetEntities.reduce(T.zero) { sum, entity in
			guard let summary = storage[entity.id]?[period] else { return sum }
			return sum + summary.totalAssets
		}
	}

	/// Aggregate total equity across multiple entities for a specific period.
	///
	/// - Parameters:
	///   - period: The period to aggregate
	///   - entities: Optional array of entities to include (defaults to all)
	/// - Returns: Sum of total equity, or zero if no data
	public func aggregateTotalEquity(
		for period: Period,
		entities: [Entity]? = nil
	) -> T {
		let targetEntities = entities ?? self.entities

		return targetEntities.reduce(T.zero) { sum, entity in
			guard let summary = storage[entity.id]?[period] else { return sum }
			return sum + summary.totalEquity
		}
	}

	// MARK: - Comparative Analysis

	/// Calculate median metric value across entities for a period.
	///
	/// Useful for peer benchmarking and identifying outliers.
	///
	/// - Parameters:
	///   - period: The period to analyze
	///   - keyPath: Key path to the metric (e.g., \.grossMargin)
	///   - entities: Optional array of entities to include (defaults to all)
	/// - Returns: Median value, or nil if insufficient data
	public func median(
		for period: Period,
		_ keyPath: KeyPath<FinancialPeriodSummary<T>, T>,
		entities: [Entity]? = nil
	) -> T? {
		let targetEntities = entities ?? self.entities

		let values = targetEntities.compactMap { entity -> T? in
			storage[entity.id]?[period]?[keyPath: keyPath]
		}

		guard !values.isEmpty else { return nil }

		let sorted = values.sorted()
		let mid = sorted.count / 2

		if sorted.count % 2 == 0 {
			return (sorted[mid - 1] + sorted[mid]) / T(2)
		} else {
			return sorted[mid]
		}
	}

	/// Calculate average (mean) metric value across entities for a period.
	///
	/// - Parameters:
	///   - period: The period to analyze
	///   - keyPath: Key path to the metric (e.g., \.netMargin)
	///   - entities: Optional array of entities to include (defaults to all)
	/// - Returns: Average value, or nil if no data
	public func average(
		for period: Period,
		_ keyPath: KeyPath<FinancialPeriodSummary<T>, T>,
		entities: [Entity]? = nil
	) -> T? {
		let targetEntities = entities ?? self.entities

		let values = targetEntities.compactMap { entity -> T? in
			storage[entity.id]?[period]?[keyPath: keyPath]
		}

		guard !values.isEmpty else { return nil }

		let sum = values.reduce(T.zero, +)
		return sum / T(values.count)
	}

	/// Rank entities by a specific metric for a period.
	///
	/// Returns entities sorted by the metric in descending order (highest first).
	///
	/// - Parameters:
	///   - period: The period to analyze
	///   - keyPath: Key path to the metric for ranking
	///   - entities: Optional array of entities to include (defaults to all)
	/// - Returns: Array of (Entity, value) tuples sorted by value descending
	public func ranked(
		for period: Period,
		by keyPath: KeyPath<FinancialPeriodSummary<T>, T>,
		entities: [Entity]? = nil
	) -> [(Entity, T)] {
		let targetEntities = entities ?? self.entities

		let pairs: [(Entity, T)] = targetEntities.compactMap { entity in
			guard let summary = storage[entity.id]?[period] else { return nil }
			return (entity, summary[keyPath: keyPath])
		}

		return pairs.sorted { $0.1 > $1.1 }
	}

	// MARK: - Filtering

	/// Filter entities by metadata criteria.
	///
	/// - Parameter predicate: Closure that returns true for entities to include
	/// - Returns: Array of entities matching the predicate
	///
	/// ## Example
	/// ```swift
	/// // Get all technology sector companies
	/// let techCompanies = consolidated.filterEntities { entity in
	///     entity.metadata["sector"] == "Technology"
	/// }
	///
	/// // Get all US-based companies
	/// let usCompanies = consolidated.filterEntities { entity in
	///     entity.metadata["country"] == "US"
	/// }
	/// ```
	public func filterEntities(
		_ predicate: (Entity) -> Bool
	) -> [Entity] {
		return entities.filter(predicate)
	}

	/// Create a new consolidated view containing only specified entities.
	///
	/// - Parameter entities: Entities to include in the subset
	/// - Returns: New ConsolidatedStatements with subset of data
	public func subset(entities: [Entity]) -> ConsolidatedStatements<T> {
		var result = ConsolidatedStatements<T>()

		for entity in entities {
			if let summaries = storage[entity.id] {
				result.entityLookup[entity.id] = entity
				result.storage[entity.id] = summaries
			}
		}

		return result
	}

	// MARK: - Removal

	/// Remove all data for a specific entity.
	///
	/// - Parameter entity: The entity to remove
	/// - Returns: `true` if entity was removed, `false` if not found
	@discardableResult
	public mutating func remove(entity: Entity) -> Bool {
		let hadEntity = storage.removeValue(forKey: entity.id) != nil
		entityLookup.removeValue(forKey: entity.id)
		return hadEntity
	}

	/// Remove data for a specific entity and period.
	///
	/// - Parameters:
	///   - entity: The entity
	///   - period: The period to remove
	/// - Returns: `true` if summary was removed, `false` if not found
	@discardableResult
	public mutating func remove(entity: Entity, period: Period) -> Bool {
		return storage[entity.id]?.removeValue(forKey: period) != nil
	}

	/// Remove all data.
	public mutating func removeAll() {
		storage.removeAll()
		entityLookup.removeAll()
	}
}

// MARK: - Codable Conformance

extension ConsolidatedStatements: Codable where T: Codable {

	private enum CodingKeys: String, CodingKey {
		case entities
		case summaries
	}

	private struct EntitySummaries: Codable {
		let entity: Entity
		let summaries: [Period: FinancialPeriodSummary<T>]
	}

	/// Restores a consolidated statements collection from an encoded representation.
	///
	/// Decodes an array of entity/summaries pairs and reconstructs the internal
	/// storage dictionary and entity lookup table.
	///
	/// - Parameter decoder: The decoder to read data from.
	/// - Throws: `DecodingError` if the encoded data is malformed or type-mismatched.
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let entitySummariesArray = try container.decode([EntitySummaries].self, forKey: .summaries)

		self.storage = [:]
		self.entityLookup = [:]

		for item in entitySummariesArray {
			entityLookup[item.entity.id] = item.entity
			storage[item.entity.id] = item.summaries
		}
	}

	/// Encodes the consolidated statements collection into an external representation.
	///
	/// Serialises all entity/period/summary combinations as an ordered array,
	/// preserving entity metadata alongside its financial summaries.
	///
	/// - Parameter encoder: The encoder to write data to.
	/// - Throws: `EncodingError` if a value cannot be encoded in the requested format.
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		let entitySummariesArray = storage.compactMap { (entityId, summaries) -> EntitySummaries? in
			guard let entity = entityLookup[entityId] else { return nil }
			return EntitySummaries(entity: entity, summaries: summaries)
		}

		try container.encode(entitySummariesArray, forKey: .summaries)
	}
}
