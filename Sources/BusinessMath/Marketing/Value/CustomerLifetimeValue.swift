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

	/// `m·(1 + d)/(1 + d − r)`. The same perpetuity valued as an **annuity due**.
	///
	/// The difference from ``perpetuity`` is exactly one period's margin, for any
	/// retention and any discount rate, because this one counts the margin arriving *now*
	/// and the ordinary perpetuity starts a period from now.
	///
	/// This is the convention behind the formula the subscription industry actually
	/// quotes. At a zero discount rate it is `m/(1 − r)` — margin over churn — which is
	/// what every SaaS spreadsheet computes and what this library's own templates have
	/// always returned. Naming it is what lets the two live together: at 5% churn they
	/// differ by 5%, small enough to look like rounding and large enough to move a
	/// valuation.
	case perpetuityDue
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

	/// A backward-looking definition was asked for with no history to look back at.
	case definitionNeedsHistory(CLVDefinition)
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
		value = try Self_perpetuity(margin: margin, retention: rate,
									discountRate: discountRate, due: false)

	case .perpetuityDue:
		guard let rate = estimated else { throw CLVError.invalidRetention }
		value = try Self_perpetuity(margin: margin, retention: rate,
									discountRate: discountRate, due: true)
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

/// The perpetuity, in either convention.
///
/// Ordinary: `m·r/(1 + d − r)`, the first margin arriving one period from now.
/// Due: `m·(1 + d)/(1 + d − r)`, the first arriving immediately. The two differ by exactly
/// `m`, which is the identity the tests pin.
///
/// - Parameters:
///   - margin: Margin per period.
///   - retention: Per-period survival, in `[0, 1]`.
///   - discountRate: Per-period discount rate, non-negative.
///   - due: Whether the first margin arrives now.
/// - Returns: The present value.
/// - Throws: ``CLVError/invalidRetention`` or ``CLVError/divergentPerpetuity(retention:discountRate:)``.
private func Self_perpetuity<T: Real & Sendable & BinaryFloatingPoint>(
	margin: T,
	retention: T,
	discountRate: T,
	due: Bool
) throws -> T {
	guard retention >= T.zero, retention <= T(1) else { throw CLVError.invalidRetention }
	let denominator: T = 1 + discountRate - retention
	guard denominator > T.zero else {
		throw CLVError.divergentPerpetuity(retention: Double(retention),
										   discountRate: Double(discountRate))
	}
	let factor: T = due ? 1 + discountRate : retention
	let numerator: T = margin * factor
	return numerator / denominator
}

/// Lifetime value from parameters rather than from a cohort.
///
/// ```swift
/// let value = try customerLifetimeValue(marginPerPeriod: 100,
///                                       retention: 0.95,
///                                       definition: .perpetuityDue)
/// print(value.value)
/// ```
///
/// ## When there is no cohort to measure
///
/// ``customerLifetimeValue(cohort:definition:discountRate:horizon:retention:marginPerPeriod:)``
/// estimates margin and retention from customer histories. A subscription business models
/// both parametrically long before it has those histories — the plan says the margin and
/// the churn assumption, and the LTV follows. This is that entry point, and it is what the
/// model templates in `Fluent API/Templates/` delegate to.
///
/// ``CLVDefinition/historic`` and ``CLVDefinition/discountedHistoric`` are refused here.
/// They average what a cohort actually earned; with no cohort there is nothing to average,
/// and returning the forward-looking number under a backward-looking name would misreport
/// where it came from.
///
/// - Parameters:
///   - marginPerPeriod: Margin earned per period a customer stays. May be negative — a
///     loss-making product has a negative lifetime value, which is a finding.
///   - retention: Per-period survival, in `[0, 1]`. One minus churn.
///   - definition: Which quantity to compute. Defaults to
///     ``CLVDefinition/perpetuityDue``, the convention the subscription industry quotes.
///   - discountRate: Per-period discount rate, non-negative. Defaults to zero.
///   - horizon: Periods to project, used only by ``CLVDefinition/finiteHorizon``.
/// - Returns: The value, carrying the parameters it was given and a cohort size of zero.
/// - Throws: ``CLVError``.
public func customerLifetimeValue<T: Real & Sendable & BinaryFloatingPoint>(
	marginPerPeriod: T,
	retention: T,
	definition: CLVDefinition = .perpetuityDue,
	discountRate: T = T.zero,
	horizon: Int = 12
) throws -> CLVResult<T> {
	guard marginPerPeriod.isFinite else { throw CLVError.missingMargin }
	guard discountRate >= T.zero, discountRate.isFinite else {
		throw CLVError.invalidDiscountRate
	}
	guard retention >= T.zero, retention <= T(1) else { throw CLVError.invalidRetention }

	let value: T
	switch definition {
	case .historic, .discountedHistoric:
		throw CLVError.definitionNeedsHistory(definition)

	case .finiteHorizon:
		guard horizon > 0 else { throw CLVError.invalidHorizon }
		var total: T = T.zero
		for period in 1...horizon {
			let periods: T = T(period)
			let survival: T = T.pow(retention, periods)
			let discount: T = T.pow(1 + discountRate, periods)
			guard discount > T.zero else { throw CLVError.invalidDiscountRate }
			let contribution: T = marginPerPeriod * survival
			total += contribution / discount
		}
		value = total

	case .perpetuity:
		value = try Self_perpetuity(margin: marginPerPeriod, retention: retention,
									discountRate: discountRate, due: false)

	case .perpetuityDue:
		value = try Self_perpetuity(margin: marginPerPeriod, retention: retention,
									discountRate: discountRate, due: true)
	}

	return CLVResult(value: value,
					 definition: definition,
					 estimatedRetention: retention,
					 averageMargin: marginPerPeriod,
					 cohortSize: 0,
					 netOfAcquisition: nil)
}
