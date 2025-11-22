import Testing
import Foundation
@testable import BusinessMath

@Suite("Data Cache Tests")
struct DataCacheTests {

	@Test("Cache and retrieve value")
	func cacheAndRetrieve() throws {
		let cache = MarketDataCache()

		cache.cache("Test Value", for: "test_key")

		let retrieved: String? = cache.retrieve(for: "test_key")
		#expect(retrieved == "Test Value")
	}

	@Test("Cache with custom TTL")
	func customTTL() throws {
		let cache = MarketDataCache()

		cache.cache("Short-lived", for: "short", ttl: 0.1)  // 0.1 seconds

		// Should exist immediately
		let immediate: String? = cache.retrieve(for: "short")
		#expect(immediate == "Short-lived")

		// Wait for expiration
		Thread.sleep(forTimeInterval: 0.2)

		// Should be expired
		let expired: String? = cache.retrieve(for: "short")
		#expect(expired == nil)
	}

	@Test("Retrieve non-existent key returns nil")
	func retrieveNonExistent() throws {
		let cache = MarketDataCache()

		let result: String? = cache.retrieve(for: "does_not_exist")
		#expect(result == nil)
	}

	@Test("Type safety - wrong type returns nil")
	func typeSafety() throws {
		let cache = MarketDataCache()

		cache.cache("String Value", for: "test")

		// Try to retrieve as Int - should return nil
		let wrongType: Int? = cache.retrieve(for: "test")
		#expect(wrongType == nil)

		// Retrieve as String - should work
		let correctType: String? = cache.retrieve(for: "test")
		#expect(correctType == "String Value")
	}

	@Test("Evict expired entries")
	func evictExpired() throws {
		let cache = MarketDataCache(maxSize: 10)

		// Add entries with short TTL
		for i in 0..<5 {
			cache.cache("Value \(i)", for: "key_\(i)", ttl: 0.1)
		}

		// Add entries with long TTL
		for i in 5..<10 {
			cache.cache("Value \(i)", for: "key_\(i)", ttl: 3600)
		}

		// Wait for first batch to expire
		Thread.sleep(forTimeInterval: 0.2)

		// Trigger eviction by accessing cache
		let _ : String? = cache.retrieve(for: "key_0")

		// Long-lived entries should still exist
		let longLived: String? = cache.retrieve(for: "key_5")
		#expect(longLived == "Value 5")

		// Short-lived entries should be gone
		let shortLived: String? = cache.retrieve(for: "key_0")
		#expect(shortLived == nil)
	}

	@Test("Cache eviction when full")
	func cacheEviction() throws {
		let cache = MarketDataCache(maxSize: 3)

		// Fill cache
		cache.cache("Value 1", for: "key_1", ttl: 0.1)
		cache.cache("Value 2", for: "key_2", ttl: 3600)
		cache.cache("Value 3", for: "key_3", ttl: 3600)

		// Wait for first entry to expire
		Thread.sleep(forTimeInterval: 0.2)

		// Add 4th entry - should trigger eviction
		cache.cache("Value 4", for: "key_4", ttl: 3600)

		// Expired entry should be gone
		let expired: String? = cache.retrieve(for: "key_1")
		#expect(expired == nil)

		// Other entries should still exist
		let existing: String? = cache.retrieve(for: "key_2")
		#expect(existing == "Value 2")
	}

	@Test("Clear cache")
	func clearCache() throws {
		let cache = MarketDataCache()

		cache.cache("Value 1", for: "key_1")
		cache.cache("Value 2", for: "key_2")

		cache.clear()

		let result1: String? = cache.retrieve(for: "key_1")
		let result2: String? = cache.retrieve(for: "key_2")

		#expect(result1 == nil)
		#expect(result2 == nil)
	}

	@Test("Cache TimeSeries object")
	func cacheTimeSeries() throws {
		let cache = MarketDataCache()

		let periods = [Period.quarter(year: 2024, quarter: 1)]
		let values = [100_000.0]
		let timeSeries = TimeSeries(periods: periods, values: values)

		cache.cache(timeSeries, for: "stock_prices")

		let retrieved: TimeSeries<Double>? = cache.retrieve(for: "stock_prices")
		#expect(retrieved != nil)
		#expect(retrieved?.periods.count == 1)
		#expect(retrieved?.valuesArray[0] == 100_000.0)
	}
	
	@Test("Overwriting same key refreshes TTL")
			func overwriteRefreshesTTL() throws {
					let cache = MarketDataCache()
					cache.cache("A", for: "k", ttl: 0.1)

					// Overwrite with longer TTL before first expires
					Thread.sleep(forTimeInterval: 0.05)
					cache.cache("B", for: "k", ttl: 1.0)

					// Wait long enough that first TTL would have expired, but second should still be valid
					Thread.sleep(forTimeInterval: 0.2)

					let v: String? = cache.retrieve(for: "k")
					#expect(v == "B")
			}

			@Test("Overwriting with different type replaces value")
			func overwriteWithDifferentType() throws {
					let cache = MarketDataCache()
					cache.cache("str", for: "key")
					#expect(cache.retrieve(for: "key") as String? == "str")

					cache.cache(123, for: "key")
					#expect(cache.retrieve(for: "key") as String? == nil)
					#expect(cache.retrieve(for: "key") as Int? == 123)
			}
}
