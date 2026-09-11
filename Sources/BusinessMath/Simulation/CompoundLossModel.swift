//
//  CompoundLossModel.swift
//  BusinessMath
//

import Foundation
import Numerics

/// An aggregate loss: a random number of events, each of a random size, each passed
/// through a per-occurrence deductible and limit.
///
/// ```
/// S = Σᵢ₌₁ᴺ  min( max(Xᵢ − deductible, 0), limit )
/// ```
///
/// Binds Risk Solver's `PsiMakeInput(freq, expr, deduct, limit)`.
///
/// ```swift
/// if let frequency = DistributionPoisson(lambda: 3) {
///     let model = try CompoundLossModel(
///         frequency: frequency,
///         severity: DistributionLogNormal(9, 1.2),
///         deductible: 5_000,
///         limit: 250_000)
///     var rng = DeterministicRNG(seed: 42)
///     let yearOne = model.sample(using: &rng)
/// }
/// ```
///
/// ## The deductible applies per occurrence, not to the total
///
/// This is the distinction that decides the answer, and it is easy to get backwards.
/// Each loss is reduced by the deductible and capped at the limit *before* the sum, so
/// a year of many small losses beneath the deductible aggregates to zero, while the
/// same total arriving as one large loss does not. Applying the deductible to the
/// aggregate instead — an aggregate deductible, a different contract — would price
/// those two years identically. Both structures exist in practice; this one is the one
/// `PsiMakeInput` describes, and the type will not silently substitute the other.
///
/// ## Why there is no closed form here
///
/// The distribution of `S` is a compound distribution, and it has no elementary form
/// for any interesting choice of frequency and severity — that is precisely why Monte
/// Carlo is the standard tool for it. ``expectedAggregate(expectedCount:quadratureSteps:)`` gives the
/// mean, which *does* factor by Wald's identity, and nothing further is offered:
/// a variance or a quantile presented as analytic here would be an approximation
/// wearing a closed form's clothes.
public struct CompoundLossModel<Frequency: DiscreteDistribution & Sendable,
								Severity: ContinuousDistribution & Sendable>: Sendable
where Frequency.T == Double, Severity.T == Double {

	/// What can go wrong constructing a compound loss model.
	public enum Failure: Error, Sendable, Equatable {

		/// The deductible was negative or not finite. A negative deductible would add
		/// money to every loss, which is not a retention.
		case invalidDeductible

		/// The limit was not strictly positive, or not finite. A zero limit makes every
		/// occurrence contribute nothing, which is a model with no losses in it rather
		/// than a model of a policy.
		case invalidLimit
	}

	/// How many events occur.
	public let frequency: Frequency

	/// How large each event is, gross of the deductible.
	public let severity: Severity

	/// Retained on each occurrence before anything is paid. Non-negative.
	public let deductible: Double

	/// The most any single occurrence can contribute. Strictly positive.
	public let limit: Double

	/// Creates a compound loss model.
	///
	/// - Parameters:
	///   - frequency: The count distribution — Poisson and negative binomial are the
	///     usual choices.
	///   - severity: The size distribution, gross.
	///   - deductible: Retained per occurrence. Non-negative; defaults to none.
	///   - limit: The cap per occurrence. Strictly positive; defaults to unlimited.
	/// - Throws: ``Failure`` naming which term was rejected.
	public init(frequency: Frequency,
				severity: Severity,
				deductible: Double = 0,
				limit: Double = .infinity) throws {
		guard deductible >= 0, !deductible.isNaN else { throw Failure.invalidDeductible }
		guard deductible.isFinite else { throw Failure.invalidDeductible }
		guard limit > 0, !limit.isNaN else { throw Failure.invalidLimit }
		self.frequency = frequency
		self.severity = severity
		self.deductible = deductible
		self.limit = limit
	}

	/// What one gross loss contributes after the deductible and the limit.
	///
	/// - Parameter gross: The loss before either term.
	/// - Returns: `min(max(gross − deductible, 0), limit)`, never negative.
	public func netOccurrence(_ gross: Double) -> Double {
		let excess: Double = gross - deductible
		let retained: Double = Swift.max(0, excess)
		return Swift.min(retained, limit)
	}

	/// Draws one aggregate loss.
	///
	/// - Parameter generator: The random source; seed it for a reproducible stream.
	/// - Returns: The total net loss over one period. Zero is an ordinary outcome, and
	///   the most common one for a low frequency and a high deductible.
	public func sample<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		let count = sampleCount(using: &generator)
		guard count > 0 else { return 0 }
		var total: Double = 0
		for _ in 0..<count {
			let gross: Double = sampleSeverity(using: &generator)
			total += netOccurrence(gross)
		}
		return total
	}

	/// Draws one aggregate loss and reports how it was made up.
	///
	/// - Parameter generator: The random source.
	/// - Returns: The event count, the gross total and the net total. The gross is
	///   returned because the ratio of the two is what a deductible and a limit are
	///   bought on, and recomputing it from the net is not possible.
	public func sampleDetail<G: RandomNumberGenerator>(
		using generator: inout G
	) -> (count: Int, gross: Double, net: Double) {
		let count = sampleCount(using: &generator)
		guard count > 0 else { return (0, 0, 0) }
		var gross: Double = 0
		var net: Double = 0
		for _ in 0..<count {
			let loss: Double = sampleSeverity(using: &generator)
			gross += loss
			net += netOccurrence(loss)
		}
		return (count, gross, net)
	}

	/// Draws `count` aggregate losses.
	///
	/// - Parameters:
	///   - count: How many periods to simulate. Non-positive yields nothing.
	///   - generator: The random source.
	/// - Returns: One aggregate loss per period.
	public func sample<G: RandomNumberGenerator>(count: Int, using generator: inout G) -> [Double] {
		guard count > 0 else { return [] }
		return (0..<count).map { _ in sample(using: &generator) }
	}

	// MARK: - Analytical

	/// `E[S] = E[N] · E[net severity]`, by Wald's identity.
	///
	/// Wald applies because the event count is independent of the individual sizes,
	/// which is the standing assumption of this model and the reason the mean factors
	/// when nothing else about the distribution does.
	///
	/// The expected net severity has no closed form once a deductible and a limit are
	/// in the way — the transform has a kink at each — so it is integrated over the
	/// quantile function, `E[net] = ∫₀¹ net(Q(u)) du`. Integrating in `u` rather than
	/// in `x` is what makes that safe: the range is always the unit interval, so an
	/// unbounded severity needs no truncation and no judgement about where its tail
	/// stops mattering.
	///
	/// - Parameters:
	///   - expectedCount: `E[N]`. Taken as an argument because ``DiscreteDistribution``
	///     does not require a mean, and computing one by summing a pmf would put a
	///     silent truncation inside an otherwise exact identity.
	///   - quadratureSteps: Simpson intervals over `u`. Even; the default is fine for
	///     a severity whose quantile is smooth away from the two kinks.
	/// - Returns: The expected aggregate loss, or `nil` for an unusable step count.
	public func expectedAggregate(expectedCount: Double,
								  quadratureSteps: Int = 2000) -> Double? {
		guard expectedCount >= 0, expectedCount.isFinite else { return nil }
		guard let perOccurrence = expectedNetSeverity(quadratureSteps: quadratureSteps) else {
			return nil
		}
		return expectedCount * perOccurrence
	}

	/// `E[net severity] = ∫₀¹ net(Q(u)) du`, by Simpson's rule.
	///
	/// - Parameter quadratureSteps: Simpson intervals over `[0, 1]`. Even.
	/// - Returns: The mean net loss per occurrence, or `nil` for an unusable step count
	///   or a quantile that is not finite in the interior.
	public func expectedNetSeverity(quadratureSteps: Int = 2000) -> Double? {
		guard quadratureSteps >= 2 else { return nil }
		let steps: Int = quadratureSteps.isMultiple(of: 2) ? quadratureSteps : quadratureSteps + 1
		let intervals: Double = Double(steps)
		guard intervals > 0 else { return nil }
		let h: Double = 1 / intervals
		var total: Double = 0
		for index in 0...steps {
			// The endpoints are nudged inward: `Q(0)` and `Q(1)` are infinite for any
			// unbounded severity, and Simpson gives them weight one, so evaluating them
			// literally would make every answer infinite. The nudge is half a step, so
			// it shrinks with the grid rather than being a fixed fudge.
			let raw: Double = Double(index) * h
			let half: Double = h / 2
			let u: Double = Swift.min(Swift.max(raw, half), 1 - half)
			let gross: Double = severity.quantile(u)
			guard gross.isFinite else { return nil }
			let net: Double = netOccurrence(gross)
			let weight: Double
			if index == 0 || index == steps {
				weight = 1
			} else {
				weight = index.isMultiple(of: 2) ? 2 : 4
			}
			total += weight * net
		}
		let scaled: Double = total * h
		return scaled / 3
	}

	// MARK: - Private

	/// Draws an event count by inverse transform.
	private func sampleCount<G: RandomNumberGenerator>(using generator: inout G) -> Int {
		let u: Double = Self.uniform(using: &generator)
		let count = frequency.quantile(u)
		return Swift.max(0, count)
	}

	/// Draws one gross loss by inverse transform.
	private func sampleSeverity<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		let u: Double = Self.uniform(using: &generator)
		return severity.quantile(u)
	}

	/// A uniform draw strictly inside `(0, 1)`.
	///
	/// Both endpoints are excluded because a quantile function is entitled to be
	/// infinite at either, and one infinity in a sum makes the whole aggregate
	/// infinite for the rest of the run.
	private static func uniform<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		// The standard library's own uniform, rather than scaling a raw word by
		// `UInt64.max`: it is the same draw with none of the arithmetic, and dividing
		// by a constant no reader can see a guard for is not worth reintroducing here.
		let u: Double = openUnitUniform(Double.self, using: &generator)
		let smallest: Double = Double.ulpOfOne
		let largest: Double = 1 - smallest
		return Swift.min(Swift.max(u, smallest), largest)
	}
}
