//
//  Depreciation.swift
//  BusinessMath
//
//  The four depreciation methods a spreadsheet offers, as general functions.
//

import Foundation
import Numerics

// MARK: - Straight line

/// Straight-line depreciation: the same amount every period.
///
/// ```
/// (cost − salvage) / life
/// ```
///
/// The simplest method and the default for most reporting. An asset bought for 10,000,
/// worth 1,000 at the end of five years, gives up 1,800 a year.
///
/// ## Salvage
///
/// The salvage value is what the asset is still worth when its life ends, and it is
/// **not** depreciated — only the difference between cost and salvage is. Two places in
/// this package used to compute straight-line depreciation without it, which is correct
/// only when salvage is zero and silently overstates the deduction otherwise. Both now
/// call this function and pass their salvage explicitly.
///
/// - Parameters:
///   - cost: What the asset was bought for.
///   - salvage: What it is worth at the end of its life. May be zero.
///   - life: How many periods it depreciates over. Must be positive.
/// - Returns: The depreciation charged in each period.
/// - Throws: `BusinessMathError.invalidInput` if `life` is not positive.
///
/// ## See Also
/// - ``sumOfYearsDigitsDepreciation(cost:salvage:life:period:)``
/// - ``decliningBalanceDepreciation(cost:salvage:life:period:factor:)``
public func straightLineDepreciation<T: Real>(cost: T, salvage: T, life: T) throws -> T {
	guard life > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Depreciable life must be positive",
			value: "\(life)", expectedRange: "(0, ∞)")
	}
	let depreciable: T = cost - salvage
	return depreciable / life
}

// MARK: - Sum of years' digits

/// Sum-of-years'-digits depreciation: accelerated, and linear in the periods remaining.
///
/// ```
/// (cost − salvage) · (life − period + 1) / (1 + 2 + … + life)
/// ```
///
/// The denominator is the triangular number `life(life+1)/2`, which is why the method
/// is named for it. The weights fall off in a straight line — over five years the
/// charges are 5/15, 4/15, 3/15, 2/15, 1/15 of the depreciable amount — so it front-loads
/// less aggressively than declining balance and, unlike declining balance, always
/// reaches exactly the salvage value at the end of the life.
///
/// - Parameters:
///   - cost: What the asset was bought for.
///   - salvage: What it is worth at the end of its life.
///   - life: How many periods it depreciates over. Must be positive.
///   - period: Which period to charge, from 1 through `life`.
/// - Returns: The depreciation charged in `period`.
/// - Throws: `BusinessMathError.invalidInput` if `life` is not positive, or `period` is
///   outside `1...life`.
public func sumOfYearsDigitsDepreciation<T: Real>(cost: T, salvage: T, life: T, period: T) throws -> T {
	guard life > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Depreciable life must be positive",
			value: "\(life)", expectedRange: "(0, ∞)")
	}
	guard period >= T(1), period <= life else {
		throw BusinessMathError.invalidInput(
			message: "Period must fall within the asset's life",
			value: "\(period)", expectedRange: "[1, \(life)]")
	}

	let depreciable: T = cost - salvage
	let remaining: T = life - period + T(1)
	let digitSum: T = life * (life + T(1)) / T(2)
	let weight: T = remaining / digitSum
	return depreciable * weight
}

// MARK: - Declining balance

/// Declining-balance depreciation for one period, at a chosen acceleration.
///
/// Each period takes a fixed proportion `factor/life` of what is left, so the charge
/// shrinks geometrically. With the default factor of two this is double-declining
/// balance.
///
/// ```
/// prior  = cost · (1 − factor/life)^(period − 1)      ← what earlier periods took
/// charge = min( (cost − prior) · factor/life,  cost − salvage − prior )
/// ```
///
/// The second term is the cap: **an asset is never depreciated below its salvage
/// value.** When the geometric decline would break through the floor, the charge is
/// trimmed to whatever is left, and every later period charges nothing. Testing that
/// boundary matters — with a salvage of 9,000 against a cost of 10,000, the first period
/// takes 1,000 and periods two through five take zero.
///
/// Note that the cap is applied to *this* period only, using the uncapped run-rate for
/// the periods before it. That is what Excel does, and it is why declining balance
/// generally does not reach the salvage value exactly at the end of the life —
/// ``variableDecliningBalanceDepreciation(cost:salvage:life:start:end:factor:switchToStraightLine:)``
/// exists to fix that by switching methods.
///
/// - Parameters:
///   - cost: What the asset was bought for.
///   - salvage: The floor. The charge never takes the book value below it.
///   - life: How many periods it depreciates over. Must be positive.
///   - period: Which period to charge. At least 1; may be fractional, which charges the
///     rate in force partway through a period.
///   - factor: The acceleration. Two — the default — is double-declining balance; one is
///     the same rate as straight line.
/// - Returns: The depreciation charged in `period`, never negative.
/// - Throws: `BusinessMathError.invalidInput` if `life` or `factor` is not positive, or
///   `period` is below 1.
public func decliningBalanceDepreciation<T: Real>(
	cost: T,
	salvage: T,
	life: T,
	period: T,
	factor: T = T(2)
) throws -> T {
	guard life > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Depreciable life must be positive",
			value: "\(life)", expectedRange: "(0, ∞)")
	}
	guard factor > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Declining-balance factor must be positive",
			value: "\(factor)", expectedRange: "(0, ∞)")
	}
	guard period >= T(1) else {
		throw BusinessMathError.invalidInput(
			message: "Period must be at least 1",
			value: "\(period)", expectedRange: "[1, ∞)")
	}
	return decliningBalanceCharge(cost: cost, salvage: salvage, life: life,
								  period: period, factor: factor)
}

/// The declining-balance charge, without the argument checks.
///
/// Split out so ``variableDecliningBalanceDepreciation(cost:salvage:life:start:end:factor:switchToStraightLine:)``
/// can call it in a loop having validated once.
internal func decliningBalanceCharge<T: Real>(
	cost: T, salvage: T, life: T, period: T, factor: T
) -> T {
	let rate: T = factor / life

	// A factor at or above the life takes everything the first period allows, and
	// `(1 − rate)` would be non-positive — which a fractional power cannot answer.
	let retained: T = T(1) - rate
	let priorFraction: T = retained > T.zero ? T.pow(retained, period - T(1)) : T.zero
	let prior: T = cost * (T(1) - priorFraction)

	let remainingBook: T = cost - prior
	let runRate: T = remainingBook * rate
	let untilSalvage: T = cost - salvage - prior

	let charge: T = Swift.min(runRate, untilSalvage)
	return Swift.max(T.zero, charge)
}

// MARK: - Variable declining balance

/// Depreciation accumulated over any span of periods, switching to straight line when
/// that becomes the larger charge.
///
/// Declining balance front-loads but never quite reaches the salvage value; straight
/// line reaches it exactly but charges nothing extra early. This takes the larger of the
/// two each period, which in practice means declining balance at first and straight line
/// on the remaining book value once the geometric charge has decayed past it. **Once the
/// switch happens it stays**, and the asset lands exactly on its salvage value.
///
/// The span may be fractional at either end: a period only partly inside `start...end`
/// contributes that fraction of its charge, which is how a part-year acquisition is
/// handled.
///
/// - Parameters:
///   - cost: What the asset was bought for.
///   - salvage: What it is worth at the end of its life.
///   - life: How many periods it depreciates over. Must be positive.
///   - start: The beginning of the span, in the same units as `life`. Zero is the
///     moment of purchase.
///   - end: The end of the span. Must not precede `start`.
///   - factor: The declining-balance acceleration. Default two.
///   - switchToStraightLine: Whether to take straight line once it charges more.
///     Passing `false` keeps declining balance throughout, and the asset then does not
///     reach its salvage value.
/// - Returns: The total depreciation over the span.
/// - Throws: `BusinessMathError.invalidInput` for a non-positive `life` or `factor`, a
///   negative `start`, or an `end` before `start`.
public func variableDecliningBalanceDepreciation<T: Real>(
	cost: T,
	salvage: T,
	life: T,
	start: T,
	end: T,
	factor: T = T(2),
	switchToStraightLine: Bool = true
) throws -> T {
	guard life > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Depreciable life must be positive",
			value: "\(life)", expectedRange: "(0, ∞)")
	}
	guard factor > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Declining-balance factor must be positive",
			value: "\(factor)", expectedRange: "(0, ∞)")
	}
	guard start >= T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Start period cannot be negative",
			value: "\(start)", expectedRange: "[0, ∞)")
	}
	guard end >= start else {
		throw BusinessMathError.invalidInput(
			message: "End period cannot precede the start period",
			value: "\(end)", expectedRange: "[\(start), ∞)")
	}
	if end == start { return T.zero }

	let firstWhole = start.rounded(.down)
	let lastWhole = end.rounded(.up)

	/// How much of period `index` lies inside `start...end`.
	///
	/// One for a period wholly inside; the overlap for the partial period at either
	/// end. A span shorter than a single period is partial at both ends at once, which
	/// is why the two adjustments are subtractive rather than exclusive branches.
	func overlap(ofPeriodEnding index: T) -> T {
		let periodStart: T = index - T(1)
		let lower: T = Swift.max(periodStart, start)
		let upper: T = Swift.min(index, end)
		return Swift.max(T.zero, upper - lower)
	}

	var total: T = T.zero
	var accumulated: T = T.zero
	var hasSwitched = false

	var index: T = T(1)
	while index <= lastWhole {
		let charge: T
		if switchToStraightLine {
			let elapsed: T = index - T(1)
			let remainingLife: T = life - elapsed
			let remainingBook: T = cost - accumulated - salvage
			let straightLine: T = remainingLife > T.zero ? remainingBook / remainingLife : T.zero
			let declining: T = decliningBalanceCharge(cost: cost, salvage: salvage,
													  life: life, period: index, factor: factor)
			if !hasSwitched, straightLine > declining { hasSwitched = true }
			charge = Swift.max(T.zero, hasSwitched ? straightLine : declining)
		} else {
			charge = decliningBalanceCharge(cost: cost, salvage: salvage,
											life: life, period: index, factor: factor)
		}

		if index > firstWhole {
			let weight: T = overlap(ofPeriodEnding: index)
			total += charge * weight
		}
		accumulated += charge
		index += T(1)
	}

	return total
}
