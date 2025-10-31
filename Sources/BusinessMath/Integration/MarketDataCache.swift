//
//  MarketDataCache.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation

// MARK: - MarketDataCache

/// An in-memory cache for market data with TTL and size limits.
///
/// `MarketDataCache` provides a thread-safe, type-safe caching mechanism
/// for market data requests. It supports automatic expiration via time-to-live (TTL)
/// and implements eviction when the cache reaches its size limit.
///
/// ## Basic Usage
///
/// ```swift
/// let cache = MarketDataCache(maxSize: 100)
///
/// // Cache data with default TTL
/// cache.cache(stockPrices, for: "AAPL_prices")
///
/// // Retrieve cached data
/// if let prices: TimeSeries<Double> = cache.retrieve(for: "AAPL_prices") {
///     print("Found cached prices")
/// }
///
/// // Cache with custom TTL (in seconds)
/// cache.cache(financials, for: "AAPL_financials", ttl: 3600)  // 1 hour
/// ```
///
/// ## Thread Safety
///
/// All cache operations are thread-safe and can be called from multiple
/// threads concurrently without explicit synchronization.
///
/// ## Topics
///
/// ### Creating Caches
/// - ``init(maxSize:defaultTTL:)``
///
/// ### Caching Operations
/// - ``cache(_:for:ttl:)``
/// - ``retrieve(for:)``
/// - ``clear()``
public final class MarketDataCache: @unchecked Sendable {

	// MARK: - Private Types

	/// A wrapper for cached values with expiration metadata.
	private struct CachedValue {
		let value: Any
		let expiresAt: Date
		let insertedAt: Date
	}

	// MARK: - Properties

	/// The maximum number of entries allowed in the cache.
	private let maxSize: Int

	/// The default time-to-live in seconds.
	private let defaultTTL: TimeInterval

	/// Internal storage for cached values.
	private var storage: [String: CachedValue] = [:]

	/// Lock for thread-safe access.
	private let lock = NSLock()

	// MARK: - Initialization

	/// Creates a new market data cache.
	///
	/// - Parameters:
	///   - maxSize: The maximum number of entries. Defaults to 100.
	///   - defaultTTL: The default time-to-live in seconds. Defaults to 300 (5 minutes).
	public init(maxSize: Int = 100, defaultTTL: TimeInterval = 300) {
		self.maxSize = maxSize
		self.defaultTTL = defaultTTL
	}

	// MARK: - Public Methods

	/// Caches a value with the specified key and TTL.
	///
	/// If the cache is full, expired entries will be evicted first.
	/// If still full after eviction, the oldest entry will be removed.
	///
	/// - Parameters:
	///   - value: The value to cache.
	///   - key: The cache key.
	///   - ttl: The time-to-live in seconds. Uses default if not specified.
	///
	/// ## Example
	/// ```swift
	/// let cache = MarketDataCache()
	/// cache.cache(stockPrices, for: "AAPL", ttl: 3600)
	/// ```
	public func cache<T>(_ value: T, for key: String, ttl: TimeInterval? = nil) {
		lock.lock()
		defer { lock.unlock() }

		let ttlToUse = ttl ?? defaultTTL
		let expiresAt = Date().addingTimeInterval(ttlToUse)

		// Evict if necessary before adding
		if storage.count >= maxSize {
			evictIfNeeded()
		}

		storage[key] = CachedValue(
			value: value,
			expiresAt: expiresAt,
			insertedAt: Date()
		)
	}

	/// Retrieves a cached value for the specified key.
	///
	/// Returns `nil` if:
	/// - The key doesn't exist
	/// - The entry has expired
	/// - The cached type doesn't match `T`
	///
	/// - Parameter key: The cache key.
	///
	/// - Returns: The cached value, or `nil` if not found or expired.
	///
	/// ## Example
	/// ```swift
	/// if let prices: TimeSeries<Double> = cache.retrieve(for: "AAPL") {
	///     print("Found \(prices.periods.count) periods")
	/// }
	/// ```
	public func retrieve<T>(for key: String) -> T? {
		lock.lock()
		defer { lock.unlock() }

		guard let cached = storage[key] else {
			return nil
		}

		// Check expiration
		if Date() > cached.expiresAt {
			storage.removeValue(forKey: key)
			return nil
		}

		// Type safety check
		return cached.value as? T
	}

	/// Clears all cached entries.
	///
	/// ## Example
	/// ```swift
	/// cache.clear()
	/// ```
	public func clear() {
		lock.lock()
		defer { lock.unlock() }

		storage.removeAll()
	}

	// MARK: - Private Methods

	/// Evicts expired entries, and if needed, the oldest entry.
	///
	/// **Note**: This method must be called while holding the lock.
	private func evictIfNeeded() {
		let now = Date()

		// First pass: Remove expired entries
		let expiredKeys = storage.filter { now > $0.value.expiresAt }.map { $0.key }
		for key in expiredKeys {
			storage.removeValue(forKey: key)
		}

		// If still at capacity, remove oldest entry
		if storage.count >= maxSize {
			if let oldestKey = storage.min(by: { $0.value.insertedAt < $1.value.insertedAt })?.key {
				storage.removeValue(forKey: oldestKey)
			}
		}
	}
}
