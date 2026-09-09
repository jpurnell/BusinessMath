//
//  CohortRetention.swift
//  BusinessMath
//

import Foundation
import Numerics

/// How long one customer lasted, and whether that is the whole story.
public struct CustomerTenure: Sendable, Equatable {

	/// Which acquisition period they arrived in, counting from zero.
	public let cohort: Int

	/// How many periods they were active, counting the acquisition period as one.
	public let lifetime: Int

	/// Whether they were still active when observation stopped.
	///
	/// `true` means right-censored: ``lifetime`` is a lower bound on how long they
	/// lasted, not the length of their life.
	public let isActive: Bool

	/// Creates a tenure.
	///
	/// - Parameters:
	///   - cohort: Acquisition period, from zero.
	///   - lifetime: Periods active, at least one.
	///   - isActive: Whether they were still active when observation stopped.
	public init(cohort: Int, lifetime: Int, isActive: Bool) {
		self.cohort = cohort
		self.lifetime = lifetime
		self.isActive = isActive
	}
}

/// One acquisition cohort's row of the retention triangle.
public struct CohortRow<T: Real & Sendable>: Sendable {

	/// Which acquisition period.
	public let cohort: Int

	/// How many customers it started with.
	public let size: Int

	/// How many offsets this cohort has been observed for. Later cohorts have fewer.
	public let observedPeriods: Int

	/// Customers still active at each offset, starting at offset zero.
	public let active: [Int]

	/// ``active`` over ``size``. The first entry is one by construction.
	public let retention: [T]

	/// Creates a row.
	///
	/// - Parameters:
	///   - cohort: Which acquisition period.
	///   - size: How many customers it started with.
	///   - observedPeriods: How many offsets it has been observed for.
	///   - active: Customers active at each offset.
	///   - retention: Those counts as shares of `size`.
	public init(cohort: Int, size: Int, observedPeriods: Int, active: [Int], retention: [T]) {
		self.cohort = cohort
		self.size = size
		self.observedPeriods = observedPeriods
		self.active = active
		self.retention = retention
	}
}

/// A retention triangle, and the pooled curve that can be read out of it honestly.
///
/// ```swift
/// let tenures: [CustomerTenure] = [
///     CustomerTenure(cohort: 0, lifetime: 1, isActive: false),
///     CustomerTenure(cohort: 0, lifetime: 2, isActive: false),
///     CustomerTenure(cohort: 0, lifetime: 3, isActive: true),
///     CustomerTenure(cohort: 1, lifetime: 1, isActive: false),
///     CustomerTenure(cohort: 1, lifetime: 2, isActive: true)
/// ]
/// if let table = CohortRetention<Double>(tenures: tenures),
///    let pooled = table.pooledRetention(offset: 1) {
///     print(table.rows.count, pooled)
/// }
/// ```
///
/// ## The triangle is ragged, and that is the whole problem
///
/// Cohorts are acquired at different times and observed until the same day, so the
/// oldest cohort has data at every offset and the youngest has data only at offset zero.
/// The table is a triangle, not a rectangle.
///
/// Averaging down a column is where this goes wrong. A cohort that has not yet reached
/// offset three has no value there — not a zero. Put it in the denominator anyway and
/// the pooled curve comes out systematically low, monotone, smooth, and entirely
/// plausible. On the triangle in the tests it reads 0.17 where the answer is 0.50.
///
/// ``pooledRetention(offset:)`` includes a cohort at an offset only if that cohort was
/// observed that long, and returns `nil` rather than zero past the point where no cohort
/// was.
///
/// ## Period-over-period retention needs the same cohorts at both ends
///
/// The number ``customerLifetimeValue(cohort:definition:discountRate:horizon:retention:marginPerPeriod:)``
/// wants is a per-period retention rate. Dividing one pooled value by the one before it
/// does not give it: those two values are computed over *different sets of cohorts*, so
/// the ratio compares one population against another. ``periodRetention(offset:)``
/// restricts to the cohorts observed at both offsets before dividing.
///
/// ## This is not the Kaplan-Meier estimate, and should not be
///
/// ``kaplanMeier`` builds a survival estimate from the same tenures, and it will
/// generally disagree with ``pooledCurve``. They answer different questions. The cohort
/// table drops a cohort from a column the moment it runs out of window — all or nothing.
/// Kaplan-Meier keeps that cohort in the risk set for as long as it *was* observed and
/// removes it afterwards, so it uses the partial information the table discards.
///
/// The table describes what was seen. The estimator infers what would have been seen.
/// Where every cohort has the same window and nobody is censored the two coincide
/// exactly, which is the identity the tests are built on.
public struct CohortRetention<T: Real & Sendable & BinaryFloatingPoint>: Sendable {

	/// The tenures the table was built from.
	public let tenures: [CustomerTenure]

	/// One row per acquisition cohort, in cohort order.
	public let rows: [CohortRow<T>]

	/// The last period anyone was observed in — where the study stops.
	public let observationEnd: Int

	/// The longest window any cohort has.
	public var maximumObservedPeriods: Int {
		rows.map { $0.observedPeriods }.max() ?? 0
	}

	/// How many customers the table covers.
	public var totalCustomers: Int { tenures.count }

	/// Builds a retention triangle.
	///
	/// The end of observation is taken to be the last period anyone was seen in, so each
	/// cohort's window follows from when it was acquired. That is what makes the triangle
	/// ragged, and it is derived rather than asked for because the data already says it.
	///
	/// - Parameter tenures: One per customer.
	/// - Returns: `nil` for no customers, a negative cohort index, or a lifetime below
	///   one — a customer active for no periods was never acquired.
	public init?(tenures: [CustomerTenure]) {
		guard !tenures.isEmpty else { return nil }
		guard tenures.allSatisfy({ $0.cohort >= 0 && $0.lifetime >= 1 }) else { return nil }
		let lastSeen = tenures.map { $0.cohort + $0.lifetime - 1 }
		guard let end = lastSeen.max() else { return nil }

		var grouped: [Int: [CustomerTenure]] = [:]
		for tenure in tenures { grouped[tenure.cohort, default: []].append(tenure) }

		var built: [CohortRow<T>] = []
		for cohort in grouped.keys.sorted() {
			guard let members = grouped[cohort] else { continue }
			let window = end - cohort + 1
			let size = members.count
			var active: [Int] = []
			var retention: [T] = []
			for offset in 0..<window {
				let survivors = members.filter { $0.lifetime > offset }.count
				active.append(survivors)
				let share: T = T(survivors) / T(size)
				retention.append(share)
			}
			built.append(CohortRow(cohort: cohort, size: size, observedPeriods: window,
								   active: active, retention: retention))
		}

		self.tenures = tenures
		self.rows = built
		self.observationEnd = end
	}

	/// One cell of the triangle.
	///
	/// - Parameters:
	///   - cohort: Which acquisition period.
	///   - offset: How many periods after acquisition.
	/// - Returns: The share still active, or `nil` for an unknown cohort or an offset
	///   this cohort has not reached.
	public func retention(cohort: Int, offset: Int) -> T? {
		guard let row = rows.first(where: { $0.cohort == cohort }) else { return nil }
		guard offset >= 0, offset < row.retention.count else { return nil }
		return row.retention[offset]
	}

	/// Retention at an offset, pooled across the cohorts that reached it.
	///
	/// - Parameter offset: How many periods after acquisition.
	/// - Returns: Active customers over cohort size, summed only across cohorts whose
	///   window extends this far. `nil` past the longest window — no cohort has reached
	///   that offset, which is not the same as nobody surviving to it.
	public func pooledRetention(offset: Int) -> T? {
		guard offset >= 0 else { return nil }
		var survivors = 0
		var population = 0
		for row in rows where row.observedPeriods > offset {
			survivors += row.active[offset]
			population += row.size
		}
		guard population > 0 else { return nil }
		return T(survivors) / T(population)
	}

	/// The pooled curve, from offset zero out to the longest window.
	public var pooledCurve: [T] {
		var curve: [T] = []
		for offset in 0..<maximumObservedPeriods {
			guard let value = pooledRetention(offset: offset) else { break }
			curve.append(value)
		}
		return curve
	}

	/// The share of customers active at `offset` who are still active at `offset + 1`.
	///
	/// Computed over the cohorts observed at **both** offsets, which is what makes it a
	/// rate rather than a ratio of two different populations.
	///
	/// - Parameter offset: The earlier of the two offsets.
	/// - Returns: The per-period retention rate, or `nil` when no cohort spans both
	///   offsets or nobody was active at the earlier one.
	public func periodRetention(offset: Int) -> T? {
		guard offset >= 0 else { return nil }
		let next = offset + 1
		var before = 0
		var after = 0
		for row in rows where row.observedPeriods > next {
			before += row.active[offset]
			after += row.active[next]
		}
		guard before > 0 else { return nil }
		return T(after) / T(before)
	}

	/// Expected periods active within a window, as the area under the pooled curve.
	///
	/// With unit-width periods the integral is just the sum of the retention values, and
	/// it is the summary to prefer when half the customers are still active and there is
	/// no median lifetime to quote.
	///
	/// - Parameter horizon: How many periods to count, positive.
	/// - Returns: The sum of pooled retention over `0..<horizon`, or `nil` when the
	///   horizon runs past what any cohort has been observed for.
	public func averageLifetime(horizon: Int) -> T? {
		guard horizon > 0 else { return nil }
		var total: T = T.zero
		for offset in 0..<horizon {
			guard let value = pooledRetention(offset: offset) else { return nil }
			total += value
		}
		return total
	}

	/// The same tenures as a survival estimate, censoring the customers still active.
	///
	/// - Returns: The estimator, or `nil` when nobody has churned — a cohort with no
	///   observed churn has follow-up too short to estimate anything, which is not the
	///   same as a retention curve that stays at one.
	public var kaplanMeier: KaplanMeier<T>? {
		let times: [T] = tenures.map { T($0.lifetime) }
		let events: [Bool] = tenures.map { !$0.isActive }
		return KaplanMeier(times: times, events: events)
	}
}
