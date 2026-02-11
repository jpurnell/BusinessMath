	//
	//  CalculationCache.swift
	//  BusinessMath
	//
	//  Created on November 1, 2025.
	//

import Foundation

// MARK: - Calculation Cache

/// Cache for frequently-accessed financial calculations.
///
/// Provides thread-safe caching of calculation results to avoid
/// redundant expensive operations when inputs haven't changed.
///
/// Example:
/// ```swift
/// let cache = CalculationCache()
/// let profit = cache.getOrCalculate(key: "model_profit_\(modelId)") {
///     model.calculateProfit()
/// }
/// ```

//public final class CalculationCache: @unchecked Sendable {
//	private struct CachedValue {
//		var value: Any
//		var createdAt: Date      // For TTL
//		var lastAccessId: UInt64 // For LRU ordering
//	}
//
//	private var cache: [String: CachedValue] = [:]
//	private var seenKeys: Set<String> = []     // Track keys we've admitted before
//	private let lock = NSLock()
//	private let maxSize: Int
//	private let ttl: TimeInterval
//	private var nextAccessId: UInt64 = 0
//
//	public init(maxSize: Int = 1000, ttl: TimeInterval = 300) {
//		self.maxSize = maxSize
//		self.ttl = ttl
//	}
//
//	private func bumpAccessId() -> UInt64 {
//		nextAccessId &+= 1
//		return nextAccessId
//	}
//
//	public func getOrCalculate<T>(key: String, calculation: () -> T) -> T {
//			lock.lock()
//			defer { lock.unlock() }
//
//			let now = Date()
//
//			if var entry = cache[key] {
//				// Hit
//				let age = now.timeIntervalSince(entry.createdAt)
//				if age < ttl, let value = entry.value as? T {
//					entry.lastAccessId = bumpAccessId() // update recency
//					cache[key] = entry
//					return value
//				} else {
//					// Expired/type mismatch -> recompute and refresh in place
//					let newValue = calculation()
//					cache[key] = CachedValue(
//						value: newValue,
//						createdAt: now,
//						lastAccessId: bumpAccessId()
//					)
//					seenKeys.insert(key)
//					if cache.count > maxSize { evictOldest() }
//					return newValue
//				}
//			}
//
//			// Miss
//			let newValue = calculation()
//
//			if cache.count >= maxSize {
//				// Cache full: decide admission
//				if seenKeys.contains(key) {
//					// Bypass caching of previously seen key to avoid disturbing current working set
//					return newValue
//				} else {
//					// Admit new key: evict LRU, then insert
//					evictOldest()
//				}
//			}
//
//			// Insert (either there was room or we just evicted)
//			cache[key] = CachedValue(
//				value: newValue,
//				createdAt: now,
//				lastAccessId: bumpAccessId()
//			)
//			seenKeys.insert(key)
//			return newValue
//		}
//
//	public func clear() {
//			lock.lock()
//			defer { lock.unlock() }
//			cache.removeAll()
//			seenKeys.removeAll()
//		}
//
//		public func remove(key: String) {
//			lock.lock()
//			defer { lock.unlock() }
//			cache.removeValue(forKey: key)
//			seenKeys.remove(key) // explicit removal forgets the key
//		}
//
//		public var count: Int {
//			lock.lock()
//			defer { lock.unlock() }
//			return cache.count
//		}
//
//	private func evictOldest() {
//			let overflow = cache.count - maxSize
//			let entriesToRemove = max(1, overflow)
//
//			let keysToRemove = cache
//				.sorted { $0.value.lastAccessId < $1.value.lastAccessId }
//				.prefix(entriesToRemove)
//				.map { $0.key }
//
//			for k in keysToRemove {
//				cache.removeValue(forKey: k)
//				// Note: do not remove from seenKeys on eviction so we can bypass immediate re-admission
//			}
//		}
//}

/// Thread-safe LRU cache with TTL and single-flight pattern for expensive calculations.
///
/// Provides automatic caching of computation results to avoid redundant expensive operations.
/// Features:
/// - **LRU eviction**: Least-recently-used entries are evicted when cache is full
/// - **TTL expiration**: Entries expire after a configurable time-to-live
/// - **Single-flight**: Multiple concurrent requests for the same key share one computation
/// - **Admission control**: Prevents cache thrashing by tracking previously-seen keys
///
/// ## Usage
///
/// ```swift
/// let cache = CalculationCache(maxSize: 1000, ttl: 300)
///
/// let result = cache.getOrCalculate(key: "expensive_calc_\(params)") {
///     // This closure runs only if not cached or expired
///     performExpensiveCalculation(params)
/// }
/// ```
///
/// - Note: Uses `@unchecked Sendable` with internal locking for thread safety
public final class CalculationCache: @unchecked Sendable {
	private struct CachedValue {
		var value: Any
		var createdAt: Date      // For TTL
		var lastAccessId: UInt64 // For LRU ordering
	}
	
	private final class InflightEntry {
		let group = DispatchGroup()
		var result: Any?
		var didCache: Bool = false
	}
	
	private var cache: [String: CachedValue] = [:]
	private var inflight: [String: InflightEntry] = [:]
	
	// Admission memory: bounds and order
	private var seenKeys: Set<String> = []
	private var seenOrder: [String] = []
	private let seenKeysCap: Int
	
	private let lock = NSLock()
	private let maxSize: Int
	private let ttl: TimeInterval
	private var nextAccessId: UInt64 = 0
	
	/// Creates a calculation cache with specified size and TTL limits.
	///
	/// - Parameters:
	///   - maxSize: Maximum number of cached entries (default: 1000)
	///   - ttl: Time-to-live for cached values in seconds (default: 300 = 5 minutes)
	///   - seenKeysCapacity: Maximum size of admission history (default: max(maxSize, maxSize * 10))
	public init(maxSize: Int = 1000, ttl: TimeInterval = 300, seenKeysCapacity: Int? = nil) {
		self.maxSize = maxSize
		self.ttl = ttl
		self.seenKeysCap = seenKeysCapacity ?? max(maxSize, maxSize * 10)
	}
	
	private func bumpAccessId() -> UInt64 {
		nextAccessId &+= 1
		return nextAccessId
	}
	
	private func recordSeenIfNew(_ key: String) {
		if seenKeys.insert(key).inserted {
			seenOrder.append(key)
			trimSeenIfNeeded()
		}
	}
	
	private func trimSeenIfNeeded() {
		while seenKeys.count > seenKeysCap {
			guard let oldest = seenOrder.first else { break }
			seenOrder.removeFirst()
			// May already be gone if removed explicitly
			seenKeys.remove(oldest)
		}
	}
	
	/// Gets a cached value or computes and caches it if not present.
	///
	/// Implements an LRU cache with TTL expiration and single-flight pattern to avoid
	/// redundant computation when multiple threads request the same key simultaneously.
	///
	/// **Admission Policy:**
	/// - If cache is full and key was seen before: bypass caching (return computed value without storing)
	/// - If cache is full and key is new: evict LRU entry and insert
	///
	/// - Parameters:
	///   - key: Unique identifier for this calculation
	///   - calculation: Closure that computes the value if not cached
	/// - Returns: The cached or newly computed value
	///
	/// ## Example
	/// ```swift
	/// let cache = CalculationCache()
	/// let profit = cache.getOrCalculate(key: "model_profit_Q1") {
	///     expensiveCalculation()
	/// }
	/// ```
	public func getOrCalculate<T: Sendable>(key: String, calculation: () -> T) -> T {
		lock.lock()
		let now = Date()

		// 1) Cache hit path
		if var entry = cache[key] {
			let age = now.timeIntervalSince(entry.createdAt)
			if age < ttl, let value = entry.value as? T {
				// Update LRU recency
				entry.lastAccessId = bumpAccessId()
				cache[key] = entry
				lock.unlock()
				return value
			}
			// else: expired or type mismatch, treat as miss and possibly single-flight
		}
		
		// 2) Single-flight: if someone else is computing this key, wait and reuse
		if let inFlight = inflight[key] {
			// Take a strong ref while we unlock
			lock.unlock()
			inFlight.group.wait()
			
			// After wait, try to get from cache first
			lock.lock()
			if var cached = cache[key] {
				let age = now.timeIntervalSince(cached.createdAt)
				if age < ttl, let value = cached.value as? T {
					cached.lastAccessId = bumpAccessId()
					cache[key] = cached
					lock.unlock()
					return value
				}
			}
			// If not cached (bypass) or type mismatch, fall back to the computed result if available
			if let result = inFlight.result as? T {
				lock.unlock()
				return result
			}
			
			// If no result we must compute ourselves (rare). Fall through to compute path.
		} else {
			// No in-flight, proceed to compute
		}
		
		// 3) Compute path with single-flight
		let entry = InflightEntry()
		entry.group.enter()
		inflight[key] = entry
		lock.unlock()
		
		let computed = calculation()
		
		lock.lock()
		// Admission policy (preserves probe behavior when full and key was seen before)
		if cache.count >= maxSize {
			if seenKeys.contains(key) {
				// Bypass caching to avoid evicting current working set
				entry.result = computed
				entry.didCache = false
			} else {
				// Admit new key: evict LRU then insert
				evictOldest()
				cache[key] = CachedValue(
				value: computed,
				createdAt: now,
				lastAccessId: bumpAccessId()
				)
				recordSeenIfNew(key)
				entry.result = computed
				entry.didCache = true
			}
		} else {
			// Room available: insert
			cache[key] = CachedValue(
			value: computed,
			createdAt: now,
			lastAccessId: bumpAccessId()
			)
			recordSeenIfNew(key)
			entry.result = computed
			entry.didCache = true
		}
		
		entry.group.leave()
		inflight.removeValue(forKey: key)
		lock.unlock()
		return computed
	}
	
	/// Clears all cached entries and admission history.
	///
	/// Removes all cached values and resets the seen keys tracking.
	/// In-flight computations are not interrupted.
	public func clear() {
		lock.lock()
		cache.removeAll()
		// Do not manipulate in-flight entries during clear
		seenKeys.removeAll()
		seenOrder.removeAll()
		lock.unlock()
	}
	
	/// Removes a specific entry from the cache.
	///
	/// Explicitly deletes the cached value for the given key and "forgets" it
	/// for admission purposes (next computation will be treated as a new key).
	///
	/// - Parameter key: The key to remove from the cache
	public func remove(key: String) {
		lock.lock()
		cache.removeValue(forKey: key)
		// Explicit removal should "forget" the key for admission purposes
		seenKeys.remove(key)
		lock.unlock()
	}
	
	/// The current number of entries in the cache.
	///
	/// Returns the count of cached values, excluding evicted or expired entries.
	/// Thread-safe via internal locking.
	///
	/// - Returns: Number of cached entries
	public var count: Int {
		lock.lock(); defer { lock.unlock() }
		return cache.count
	}
	
	private func evictOldest() {
		let overflow = cache.count - maxSize
		let entriesToRemove = max(1, overflow)
		if entriesToRemove <= 0 { return }
		
		let keysToRemove = cache
		.sorted { $0.value.lastAccessId < $1.value.lastAccessId }
		.prefix(entriesToRemove)
		.map { $0.key }
		
		for k in keysToRemove {
			cache.removeValue(forKey: k)
			// Keep seenKeys entry to preserve probe semantics; bounded by seenKeysCap
		}
	}
}
	// MARK: - Model Hash Extension

actor CalculationCacheAsync {
	private struct CachedValue {
		var value: Any
		var createdAt: Date
		var lastAccessId: UInt64
	}
	
	private struct InflightEntry {
		var waiters: [CheckedContinuation<Void, Never>] = []
		var result: Any? = nil
		var remainingConsumers: Int = 0
	}
	
		// Storage
	private var cache: [String: CachedValue] = [:]
	private var inflight: [String: InflightEntry] = [:]
	
		// Admission memory (bounded)
	private var seenKeys: Set<String> = []
	private var seenOrder: [String] = []
	private let seenKeysCap: Int
	
		// Config
	private let maxSize: Int
	private let ttl: TimeInterval
	
		// LRU counter
	private var nextAccessId: UInt64 = 0
	private func bumpAccessId() -> UInt64 {
		nextAccessId &+= 1
		return nextAccessId
	}
	
	init(maxSize: Int = 1000, ttl: TimeInterval = 300, seenKeysCapacity: Int? = nil) {
		self.maxSize = maxSize
		self.ttl = ttl
		self.seenKeysCap = seenKeysCapacity ?? max(maxSize, maxSize * 10)
	}
	
		// MARK: - Public API
	
	func getOrCalculate<T: Sendable>(key: String, calculation: @Sendable () async -> T) async -> T {
		let k = augmentedKey(key, T.self)
		let now = Date()
		
			// 1) Fast hit path
		if var entry = cache[k], now.timeIntervalSince(entry.createdAt) < ttl, let value = entry.value as? T {
			entry.lastAccessId = bumpAccessId()
			cache[k] = entry
			return value
		}
		
			// 2) Join an in-flight computation if present
		if inflight[k] != nil {
			await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
				inflight[k]!.waiters.append(cont)
			}
				// After leader signals, prefer cached value
			if var entry = cache[k], Date().timeIntervalSince(entry.createdAt) < ttl, let value = entry.value as? T {
				entry.lastAccessId = bumpAccessId()
				cache[k] = entry
				return value
			}
				// Otherwise consume leader's result (bypass case)
			if var entry = inflight[k], let any = entry.result as? T {
				entry.remainingConsumers -= 1
				if entry.remainingConsumers <= 0 {
					inflight.removeValue(forKey: k)
				} else {
					inflight[k] = entry
				}
				return any
			}
			
				// Extremely unlikely fallback: compute ourselves
			return await leaderCompute(key: k, valueType: T.self, calc: calculation)
		}
		
			// 3) Become the leader: create in-flight, compute, admit/bypass, notify waiters
		inflight[k] = InflightEntry()
		let value = await calculation()
		
		await admitIfNeeded(key: k, value: value, now: Date())
		
			// Publish result to waiters
		if var entry = inflight[k] {
			entry.result = value
			entry.remainingConsumers = entry.waiters.count
			let waiters = entry.waiters
			inflight[k] = entry
			for cont in waiters { cont.resume() }
			if entry.remainingConsumers == 0 {
				inflight.removeValue(forKey: k)
			}
		}
		return value
	}
	
		// Sync convenience
	func getOrCalculate<T: Sendable>(key: String, calculation: @Sendable () -> T) async -> T {
		let asyncOverload: (String, @Sendable () async -> T) async -> T = self.getOrCalculate
		return await asyncOverload(key, { () async -> T in
			calculation()
		})
	}
	
	func clear() {
		cache.removeAll()
		inflight.removeAll()
		seenKeys.removeAll()
		seenOrder.removeAll()
	}
	
	func remove(key: String) {
		let prefix = key + "|"
		let toRemove = cache.keys.filter { $0.hasPrefix(prefix) }
		for k in toRemove {
			cache.removeValue(forKey: k)
			seenKeys.remove(k)
			if let idx = seenOrder.firstIndex(of: k) {
				seenOrder.remove(at: idx)
			}
		}
	}
	
	var count: Int { cache.count }
	
		// MARK: - Internals
	
	private func augmentedKey<T: Sendable>(_ key: String, _ type: T.Type) -> String {
		key + "|" + String(reflecting: T.self)
	}
	
	private func recordSeenIfNew(_ key: String) {
		if seenKeys.insert(key).inserted {
			seenOrder.append(key)
			trimSeenIfNeeded()
		}
	}
	
	private func trimSeenIfNeeded() {
		while seenKeys.count > seenKeysCap {
			guard let oldest = seenOrder.first else { break }
			seenOrder.removeFirst()
			seenKeys.remove(oldest)
		}
	}
	
	private func evictOldest() {
		let overflow = cache.count - maxSize
		let toRemove = max(1, overflow)
		if toRemove <= 0 { return }
		
		let keys = cache
			.sorted { $0.value.lastAccessId < $1.value.lastAccessId }
			.prefix(toRemove)
			.map { $0.key }
		
		for k in keys {
			cache.removeValue(forKey: k)
				// Keep seenKeys to preserve probe semantics (bounded by seenKeysCap)
		}
	}
	
	private func admitIfNeeded<T: Sendable>(key: String, value: T, now: Date) async {
		if cache.count < maxSize {
			cache[key] = CachedValue(value: value, createdAt: now, lastAccessId: bumpAccessId())
			recordSeenIfNew(key)
			return
		}
		
		if seenKeys.contains(key) {
				// Probe: do not admit previously seen key when full
			return
		}
		
		evictOldest()
		cache[key] = CachedValue(value: value, createdAt: now, lastAccessId: bumpAccessId())
		recordSeenIfNew(key)
	}
	
	private func leaderCompute<T: Sendable>(key: String, valueType: T.Type, calc: @Sendable () async -> T) async -> T {
			// If there is no leader at this instant, become one
		if inflight[key] == nil {
			inflight[key] = InflightEntry()
			let value = await calc()
			await admitIfNeeded(key: key, value: value, now: Date())
			
			if var entry = inflight[key] {
				entry.result = value
				entry.remainingConsumers = entry.waiters.count
				let waiters = entry.waiters
				inflight[key] = entry
				for cont in waiters { cont.resume() }
				if entry.remainingConsumers == 0 {
					inflight.removeValue(forKey: key)
				}
			}
			return value
		}
		
			// Otherwise, re-join the current leader
		await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
			inflight[key]!.waiters.append(cont)
		}
		
		if var entry = cache[key], Date().timeIntervalSince(entry.createdAt) < ttl, let value = entry.value as? T {
			entry.lastAccessId = bumpAccessId()
			cache[key] = entry
			return value
		}
		if var entry = inflight[key], let any = entry.result as? T {
			entry.remainingConsumers -= 1
			if entry.remainingConsumers == 0 {
				inflight.removeValue(forKey: key)
			} else {
				inflight[key] = entry
			}
			return any
		}
		
			// Final fallback
		let value = await calc()
		await admitIfNeeded(key: key, value: value, now: Date())
		return value
	}
}

extension FinancialModel {
		/// Generate a hash key for caching based on model contents
	public func cacheKey() -> String {
		var hasher = Hasher()
		
			// Hash revenue components
		for component in revenueComponents {
			hasher.combine(component.name)
			hasher.combine(component.amount)
		}
		
			// Hash cost components
		for component in costComponents {
			hasher.combine(component.name)
			switch component.type {
				case .fixed(let amount):
					hasher.combine("fixed")
					hasher.combine(amount)
				case .variable(let percentage):
					hasher.combine("variable")
					hasher.combine(percentage)
			}
		}
		
		return "model_\(hasher.finalize())"
	}
}

	// MARK: - Cached Financial Model Extension

extension FinancialModel {
		/// Shared cache for all financial models
	private static let sharedCache = CalculationCache()
	
		/// Calculate revenue with caching
	public func calculateRevenueCached() -> Double {
		let key = "\(cacheKey())_revenue"
		return Self.sharedCache.getOrCalculate(key: key) {
			calculateRevenue()
		}
	}
	
		/// Calculate costs with caching
	public func calculateCostsCached(revenue: Double? = nil) -> Double {
		let revenueKey = revenue.map { String($0) } ?? "nil"
		let key = "\(cacheKey())_costs_\(revenueKey)"
		return Self.sharedCache.getOrCalculate(key: key) {
			calculateCosts(revenue: revenue)
		}
	}
	
		/// Calculate profit with caching
	public func calculateProfitCached() -> Double {
		let key = "\(cacheKey())_profit"
		return Self.sharedCache.getOrCalculate(key: key) {
			calculateProfit()
		}
	}
	
		/// Clear calculation cache for all models
	public static func clearCalculationCache() {
		sharedCache.clear()
	}
}

	// MARK: - String Builder Optimization

	/// Efficient string builder for export operations
final class StringBuilder {
	private var parts: [String] = []
	private var estimatedLength: Int = 0
	
	func append(_ string: String) {
		parts.append(string)
		estimatedLength += string.count
	}
	
	func append(_ strings: [String]) {
		parts.append(contentsOf: strings)
		estimatedLength += strings.reduce(0) { $0 + $1.count }
	}
	
	func build() -> String {
		parts.joined()
	}
	
	func clear() {
		parts.removeAll(keepingCapacity: true)
		estimatedLength = 0
	}
	
	var count: Int {
		estimatedLength
	}
}

	// MARK: - Optimized Export Functions

extension DataExporter {
		/// Export model to CSV using optimized string building
	public func exportToCSVOptimized() -> String {
		let builder = StringBuilder()
		
			// Header row
		builder.append("Component,Type,Category,Amount,Percentage\n")
		
			// Revenue components
		for component in model.revenueComponents {
			builder.append("\(escapeCsv(component.name)),Revenue,Fixed,\(component.amount),\n")
		}
		
			// Cost components
		for component in model.costComponents {
			switch component.type {
				case .fixed(let amount):
					builder.append("\(escapeCsv(component.name)),Cost,Fixed,\(amount),\n")
				case .variable(let percentage):
					let percentageStr = String(format: "%.2f%%", percentage * 100)
					builder.append("\(escapeCsv(component.name)),Cost,Variable,,\(percentageStr)\n")
			}
		}
		
		if model.revenueComponents.isEmpty && model.costComponents.isEmpty {
			builder.append("(empty model)\n")
		}
		
		return builder.build()
	}
	
	private func escapeCsv(_ string: String) -> String {
		if string.contains(",") || string.contains("\"") || string.contains("\n") {
			return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
		}
		return string
	}
}

extension TimeSeriesExporter {
		/// Export time series to CSV using optimized string building
	public func exportToCSVOptimized() -> String {
		let builder = StringBuilder()
		
			// Header row
		builder.append("Period,Value\n")
		
		if series.count == 0 {
			builder.append("(empty series)\n")
			return builder.build()
		}
		
			// Data rows - pre-allocate array for efficiency
		let rows = zip(series.periods, series.valuesArray).map { period, value in
			"\(period.label),\(value)\n"
		}
		builder.append(rows)
		
		return builder.build()
	}
}
