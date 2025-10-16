//
//  Entity.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation

// MARK: - EntityIdentifierType

/// Types of entity identifiers used across different domains.
///
/// Supports various identification schemes to accommodate different use cases:
/// securities analysis, regulatory reporting, internal systems, and tax compliance.
///
/// ## Example
/// ```swift
/// let tickerType = EntityIdentifierType.ticker
/// let cusipType = EntityIdentifierType.cusip
/// let customType = EntityIdentifierType.custom("SEDOL")
/// ```
public enum EntityIdentifierType: Hashable, Codable, Sendable {
	/// Stock ticker symbol (e.g., "AAPL", "GOOGL")
	case ticker

	/// CUSIP number (Committee on Uniform Securities Identification Procedures)
	case cusip

	/// ISIN (International Securities Identification Number)
	case isin

	/// LEI (Legal Entity Identifier) - ISO 17442
	case lei

	/// Internal company/system identifier
	case `internal`

	/// Tax identification number (EIN, VAT, etc.)
	case taxId

	/// Custom identifier type with a string label
	case custom(String)
}

// MARK: - Entity

/// Represents a business entity (company, division, subsidiary, or business unit).
///
/// `Entity` provides flexible identification and metadata for financial statement ownership.
/// Multiple entities can be analyzed in parallel using ``ConsolidatedStatements``.
///
/// ## Creating Entities
///
/// ```swift
/// // Using ticker as primary identifier
/// let apple = Entity(
///     id: "AAPL",
///     primaryType: .ticker,
///     name: "Apple Inc."
/// )
///
/// // Using CUSIP as primary identifier
/// let microsoft = Entity(
///     id: "594918104",
///     primaryType: .cusip,
///     name: "Microsoft Corporation"
/// )
/// microsoft.identifiers[.ticker] = "MSFT"
/// microsoft.identifiers[.isin] = "US5949181045"
///
/// // Internal identifier for private companies
/// let subsidiary = Entity(
///     id: "SUB-001",
///     primaryType: .internal,
///     name: "EMEA Division"
/// )
/// subsidiary.metadata["region"] = "Europe"
/// ```
///
/// ## Multiple Identifiers
///
/// Entities can store multiple identifier types:
///
/// ```swift
/// var entity = Entity(id: "AAPL", primaryType: .ticker, name: "Apple Inc.")
/// entity.identifiers[.cusip] = "037833100"
/// entity.identifiers[.isin] = "US0378331005"
/// entity.identifiers[.lei] = "HWUPKR0MPOU8FGXBT394"
///
/// // Retrieve any identifier type
/// let cusip = entity.identifier(for: .cusip)  // "037833100"
/// ```
///
/// ## Equality and Hashing
///
/// Entities are equal if their primary `id` values match. This allows efficient
/// dictionary-based lookups in ``ConsolidatedStatements``.
///
/// ## Topics
///
/// ### Creating Entities
/// - ``init(id:primaryType:name:identifiers:currency:fiscalYearEnd:metadata:)``
///
/// ### Properties
/// - ``id``
/// - ``primaryIdentifierType``
/// - ``name``
/// - ``identifiers``
/// - ``currency``
/// - ``fiscalYearEnd``
/// - ``metadata``
///
/// ### Accessing Identifiers
/// - ``identifier(for:)``
public struct Entity: Hashable, Codable, Sendable {

	/// Primary identifier used for equality and hashing.
	///
	/// This is the canonical ID for this entity. Choose the most stable
	/// identifier for your use case:
	/// - LEI for regulatory work
	/// - CUSIP for securities analysis
	/// - Internal ID for corporate systems
	/// - Ticker for market analysis
	public let id: String

	/// The type of the primary identifier.
	public let primaryIdentifierType: EntityIdentifierType

	/// Human-readable name of the entity.
	public let name: String

	/// Alternative identifiers for this entity.
	///
	/// Store multiple ways to identify the same entity across different domains.
	///
	/// ## Example
	/// ```swift
	/// var entity = Entity(
	///     id: "AAPL",
	///     primaryType: .ticker,
	///     name: "Apple Inc."
	/// )
	/// entity.identifiers[.cusip] = "037833100"
	/// entity.identifiers[.isin] = "US0378331005"
	/// entity.identifiers[.lei] = "HWUPKR0MPOU8FGXBT394"
	/// ```
	public var identifiers: [EntityIdentifierType: String]

	/// Currency code for this entity's financial statements (e.g., "USD", "EUR", "GBP").
	///
	/// Uses ISO 4217 currency codes.
	public var currency: String?

	/// Fiscal year end for this entity.
	///
	/// Defaults to calendar year end (December 31) if not specified.
	/// Common alternatives include June 30 for many technology companies.
	public var fiscalYearEnd: MonthDay?

	/// Custom metadata for entity classification and grouping.
	///
	/// Use metadata to store:
	/// - Industry classifications
	/// - Geographic regions
	/// - Parent/subsidiary relationships
	/// - External system identifiers
	///
	/// ## Example
	/// ```swift
	/// var entity = Entity(id: "SUB01", primaryType: .internal, name: "Europe Division")
	/// entity.metadata["region"] = "EMEA"
	/// entity.metadata["parent"] = "PARENT_CO"
	/// entity.metadata["industry"] = "Technology"
	/// ```
	public var metadata: [String: String]

	/// Creates a new entity with the specified identifier.
	///
	/// - Parameters:
	///   - id: Primary identifier value
	///   - primaryType: Type of the primary identifier (defaults to `.internal`)
	///   - name: Human-readable name
	///   - identifiers: Optional dictionary of alternative identifiers
	///   - currency: Optional ISO 4217 currency code (e.g., "USD")
	///   - fiscalYearEnd: Optional fiscal year end (defaults to December 31)
	///   - metadata: Optional custom metadata dictionary
	public init(
		id: String,
		primaryType: EntityIdentifierType = .internal,
		name: String,
		identifiers: [EntityIdentifierType: String] = [:],
		currency: String? = nil,
		fiscalYearEnd: MonthDay? = nil,
		metadata: [String: String] = [:]
	) {
		self.id = id
		self.primaryIdentifierType = primaryType
		self.name = name
		self.identifiers = identifiers
		self.currency = currency
		self.fiscalYearEnd = fiscalYearEnd
		self.metadata = metadata
	}

	/// Retrieves an identifier of a specific type.
	///
	/// Returns the requested identifier if available. If not found in the
	/// alternative identifiers dictionary, returns the primary identifier
	/// if its type matches the requested type.
	///
	/// - Parameter type: The type of identifier to retrieve
	/// - Returns: The identifier value, or nil if not found
	///
	/// ## Example
	/// ```swift
	/// let entity = Entity(id: "AAPL", primaryType: .ticker, name: "Apple Inc.")
	/// entity.identifiers[.cusip] = "037833100"
	///
	/// let ticker = entity.identifier(for: .ticker)  // "AAPL" (from primary)
	/// let cusip = entity.identifier(for: .cusip)    // "037833100" (from identifiers)
	/// let isin = entity.identifier(for: .isin)      // nil (not found)
	/// ```
	public func identifier(for type: EntityIdentifierType) -> String? {
		// Check alternative identifiers first
		if let value = identifiers[type] {
			return value
		}

		// Fall back to primary ID if type matches
		if primaryIdentifierType == type {
			return id
		}

		return nil
	}

	// MARK: - Hashable

	/// Entities hash based on their primary `id` only.
	///
	/// This allows efficient dictionary lookups while ignoring metadata changes.
	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	/// Entities are equal if their primary `id` values match.
	///
	/// - Returns: `true` if both entities have the same `id`
	public static func == (lhs: Entity, rhs: Entity) -> Bool {
		return lhs.id == rhs.id
	}
}
