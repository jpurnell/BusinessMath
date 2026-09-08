//
//  CustomerLifetimeValue.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Which lifetime value is being computed.
///
/// **The variant is a parameter because there is no single CLV.** At least four
/// definitions are in common use and they disagree by large factors on the same data.
/// A library that computes one of them and calls it "CLV" is not wrong so much as
/// unfalsifiable: a reader cannot tell whether the number answers their question.
///
/// Naming the definition at the call site changes the claim from *"we compute CLV"* —
/// which nobody can check — to *"we compute exactly the definition you named"*, which
/// anybody can.
public enum CLVDefinition: Sendable, Equatable, CaseIterable {

	/// The realised margin already earned, summed. No projection and no discounting.
	///
	/// Backward-looking and the only variant that is a measurement rather than a
	/// forecast. Useful for ranking customers you already have; useless for valuing an
	/// acquisition, since it assigns a brand-new customer a value of zero.
	case historic

	/// Realised margin, discounted to the start of the observation window.
	case discountedHistoric

	/// `Σ m·rᵗ/(1+d)ᵗ` for `t = 1...T`. Forward-looking over a stated horizon.
	///
	/// The variant to prefer when a horizon is meaningful — a contract length, a planning
	/// period, or simply the point past which a forecast is not credible.
	case finiteHorizon

	/// `m·r/(1 + d − r)`. The same series with no horizon at all.
	///
	/// Standard in the subscription literature and convenient, at the cost of asserting
	/// that the retention rate observed over a few periods holds forever. It is the
	/// limit of ``finiteHorizon`` as the horizon grows, which is checked in the tests.
	case perpetuity
}

/// What can go wrong computing a lifetime value.
public enum CLVError: Error, Sendable, Equatable {

	/// No customers.
	case emptyCohort

	/// A discount rate below zero, or not finite.
	case invalidDiscountRate

	/// A retention outside `[0, 1]`.
	case invalidRetention

	/// A horizon of zero or fewer periods, where the definition needs one.
	case invalidHorizon

	/// `r ≥ 1 + d`, so the perpetuity does not converge.
	///
	/// The closed form still returns a number there — a negative one — and nothing about
	/// its shape says it is the wrong side of a division by zero.
	case divergentPerpetuity(retention: Double, discountRate: Double)

	/// A projecting definition was asked for without the margin it projects.
	case missingMargin
}

/// One customer's observed history.
public struct CustomerHistory<T: Real & Sendable>: Sendable {

	/// Margin earned in each observed period, in order.
	public let margins: [T]

	/// Whether the customer was still active at the end of observation. A customer who
	/// is still active is **censored**, not churned, and the retention estimate depends
	/// on the difference.
	public let isActive: Bool

	/// What it cost to acquire them, if known.
	public let acquisitionCost: T?

	/// Creates a history.
	///
	/// - Parameters:
	///   - margins: Margin per observed period.
	///   - isActive: Still a customer at the end of observation.
	///   - acquisitionCost: Acquisition cost, if known.
	public init(margins: [T], isActive: Bool, acquisitionCost: T? = nil) {
		self.margins = margins
		self.isActive = isActive
		self.acquisitionCost = acquisitionCost
	}
}

/// A lifetime value, and what it was computed from.
public struct CLVResult<T: Real & Sendable>: Sendable {

	/// The value per customer.
	public let value: T

	/// Which definition produced it. Carried on the result so a number that travels can
	/// still say what it is.
	public let definition: CLVDefinition

	/// The retention rate used — supplied, or estimated from the cohort.
	public let estimatedRetention: T?

	/// The mean margin per active period across the cohort.
	public let averageMargin: T

	/// How many customers it was computed from.
	public let cohortSize: Int

	/// ``value`` less the mean acquisition cost, when every customer carried one.
	public let netOfAcquisition: T?
}

/// The lifetime value of a cohort, under a named definition.
///
/// ```swift
/// let customers: [CustomerHistory<Double>] = [
///     CustomerHistory(margins: [100, 100, 100], isActive: true, acquisitionCost: 150),
///     CustomerHistory(margins: [100, 100], isActive: false, acquisitionCost: 150),
///     CustomerHistory(margins: [100], isActive: false, acquisitionCost: 150),
/// ]
///
/// let result = try customerLifetimeValue(cohort: customers,
///                                        definition: .perpetuity,
///                                        discountRate: 0.10,
///                                        horizon: 12)
/// print(result.value, result.estimatedRetention ?? 0, result.netOfAcquisition ?? 0)
/// ```
///
/// - Parameters:
///   - cohort: The customers.
///   - definition: Which lifetime value. See ``CLVDefinition`` for why this is required.
///   - discountRate: Per-period discount rate, non-negative.
///   - horizon: Periods to project, for the definitions that project.
///   - retention: Per-period retention. Estimated from the cohort when omitted.
///   - marginPerPeriod: Margin to project. The cohort's mean when omitted.
/// - Returns: The value and what produced it.
/// - Throws: ``CLVError``.
public func customerLifetimeValue<T: Real & Sendable & BinaryFloatingPoint>(
	cohort: [CustomerHistory<T>],
	definition: CLVDefinition,
	discountRate: T,
	horizon: Int,
	retention: T? = nil,
	marginPerPeriod: T? = nil
) throws -> CLVResult<T> {
	guard !cohort.isEmpty else { throw CLVError.emptyCohort }
	guard discountRate >= T.zero, discountRate.isFinite else {
		throw CLVError.invalidDiscountRate
	}

	let observedMargin = Self_meanMargin(cohort)
	let margin = marginPerPeriod ?? observedMargin
	let estimated = retention ?? Self_estimatedRetention(cohort)
	let costs = cohort.compactMap { $0.acquisitionCost }
	let meanCost: T? = costs.count == cohort.count && !costs.isEmpty
		? costs.reduce(T.zero, +) / T(costs.count)
		: nil

	let value: T
	switch definition {
	case .historic:
		var total: T = T.zero
		for customer in cohort { total += customer.margins.reduce(T.zero, +) }
		value = total / T(cohort.count)

	case .discountedHistoric:
		var total: T = T.zero
		for customer in cohort {
			for (index, amount) in customer.margins.enumerated() {
				let periods: T = T(index + 1)
				let factor: T = T.pow(1 + discountRate, periods)
				guard factor > T.zero else { throw CLVError.invalidDiscountRate }
				total += amount / factor
			}
		}
		value = total / T(cohort.count)

	case .finiteHorizon:
		guard horizon > 0 else { throw CLVError.invalidHorizon }
		guard let rate = estimated else { throw CLVError.invalidRetention }
		guard rate >= T.zero, rate <= T(1) else { throw CLVError.invalidRetention }
		var total: T = T.zero
		for period in 1...horizon {
			let periods: T = T(period)
			let survival: T = T.pow(rate, periods)
			let discount: T = T.pow(1 + discountRate, periods)
			guard discount > T.zero else { throw CLVError.invalidDiscountRate }
			let contribution: T = margin * survival
			total += contribution / discount
		}
		value = total

	case .perpetuity:
		guard let rate = estimated else { throw CLVError.invalidRetention }
		guard rate >= T.zero, rate <= T(1) else { throw CLVError.invalidRetention }
		let denominator: T = 1 + discountRate - rate
		guard denominator > T.zero else {
			throw CLVError.divergentPerpetuity(retention: Double(rate),
											   discountRate: Double(discountRate))
		}
		let numerator: T = margin * rate
		value = numerator / denominator
	}

	let net: T? = meanCost.map { value - $0 }
	return CLVResult(value: value,
					 definition: definition,
					 estimatedRetention: estimated,
					 averageMargin: observedMargin,
					 cohortSize: cohort.count,
					 netOfAcquisition: net)
}

/// The mean margin per active period across a cohort.
private func Self_meanMargin<T: Real & Sendable & BinaryFloatingPoint>(
	_ cohort: [CustomerHistory<T>]
) -> T {
	var total: T = T.zero
	var periods = 0
	for customer in cohort {
		total += customer.margins.reduce(T.zero, +)
		periods += customer.margins.count
	}
	guard periods > 0 else { return T.zero }
	return total / T(periods)
}

/// Per-period retention estimated from how the cohort thins.
///
/// The number active in each period is counted, and the retention rate is the mean of the
/// period-to-period survival ratios. Averaging the ratios rather than taking the overall
/// survival to the last period is deliberate: the two differ whenever churn is not
/// constant, and the ratio mean is the quantity the geometric CLV formulas assume.
private func Self_estimatedRetention<T: Real & Sendable & BinaryFloatingPoint>(
	_ cohort: [CustomerHistory<T>]
) -> T? {
	let longest = cohort.map { $0.margins.count }.max() ?? 0
	guard longest > 1 else { return nil }
	var active = [Int](repeating: 0, count: longest)
	for customer in cohort {
		for period in 0..<customer.margins.count { active[period] += 1 }
	}
	var ratios: [T] = []
	for period in 1..<longest where active[period - 1] > 0 {
		let before: T = T(active[period - 1])
		let after: T = T(active[period])
		guard before > T.zero else { continue }
		ratios.append(after / before)
	}
	guard !ratios.isEmpty else { return nil }
	return ratios.reduce(T.zero, +) / T(ratios.count)
}
