//
//  GroupedChoiceFit.swift
//  BusinessMath
//

import Foundation
import Numerics

/// The result of fitting a ``GroupedChoiceModel``.
///
/// A candidate's score under the fit is `scale × (offset + Σ multipliers[k] × reference[k] × feature[k])`.
public struct GroupedChoiceFit<T: Real & Sendable & BinaryFloatingPoint>: Sendable, Equatable {

	/// How much each feature's reference weight was multiplied; `1` leaves the reference value.
	public let multipliers: [T]

	/// Log-odds per reference point: the scale at which the reference weights best explain the choices.
	public let scale: T

	/// How many steps the search took (zero for a scale-only fit).
	public let iterations: Int

	/// Whether the search stopped because it stopped moving.
	public let converged: Bool

	/// Creates a fit.
	public init(multipliers: [T], scale: T, iterations: Int, converged: Bool) {
		self.multipliers = multipliers
		self.scale = scale
		self.iterations = iterations
		self.converged = converged
	}
}

extension GroupedChoiceFit: Codable where T: Codable {}

extension GroupedChoiceModel {

	/// The negative log-likelihood of the observed choices under `fit`; see ``negativeLogLikelihood(multipliers:scale:groupWeights:)``.
	@_specialize(exported: true, where T == Double)
	public func negativeLogLikelihood(_ fit: GroupedChoiceFit<T>, groupWeights: [T]) -> (total: T, chosen: T)? {
		negativeLogLikelihood(multipliers: fit.multipliers, scale: fit.scale, groupWeights: groupWeights)
	}

	/// Each candidate's score under `fit`, one per row of the data, for ranking.
	@_specialize(exported: true, where T == Double)
	public func scores(for fit: GroupedChoiceFit<T>) -> [T]? {
		guard fit.multipliers.count == data.featureCount, fit.scale.isFinite, fit.multipliers.allSatisfy({ $0.isFinite }) else { return nil }
		return rowScores(multipliers: fit.multipliers, scale: fit.scale)
	}

	/// The scale that best turns the reference weights into log-odds: the single number the multipliers are then fitted around.
	///
	/// The log-likelihood is concave in the scale, so its derivative is bracketed and the root found by regula falsi with the
	/// Illinois correction. A derivative that is not positive even at a tiny scale (the reference weights explain nothing)
	/// gives the floor, `1e-6`.
	///
	/// - Parameter groupWeights: How much each group counts; see ``negativeLogLikelihood(multipliers:scale:groupWeights:)``.
	/// - Throws: ``GroupedChoiceError/malformedInput(reason:)`` for weights of the wrong length or not finite and non-negative,
	///   ``GroupedChoiceError/noInformativeGroups`` when no group with positive weight has anything to compare.
	@_specialize(exported: true, where T == Double)
	public func fitScale(groupWeights: [T]) throws -> T {
		try validate(groupWeights: groupWeights)
		let ones = [T](repeating: T(1), count: data.featureCount)
		let unscaled = rowScores(multipliers: ones, scale: T(1))
		var work = Work()

		func derivative(_ scale: T) -> T {
			let scores = unscaled.map { $0 * scale }
			var total: T = T.zero
			for group in 0..<data.groupCount {
				let weight: T = groupWeights[group]
				guard weight > T.zero,
					  groupLikelihood(group: group, scores: scores, work: &work, wantInclusion: true) != nil
				else { continue }
				var taken: T = T.zero
				var expected: T = T.zero
				for (position, row) in data.rows(ofGroup: group).enumerated() {
					let value: T = unscaled[row]
					if work.taken[position] { taken += value }
					let share: T = work.inclusion[position] * value
					expected += share
				}
				let gap: T = taken - expected
				total += weight * gap
			}
			return total
		}

		let floor: T = T(1) / T(1_000_000)
		var low: T = floor
		var high: T = T(1)
		var lowValue: T = derivative(low)
		guard lowValue > T.zero else { return floor }
		var highValue: T = derivative(high)
		var growth = 0
		while highValue > T.zero, growth < 40 {
			low = high
			lowValue = highValue
			high *= T(2)
			highValue = derivative(high)
			growth += 1
		}
		var retained = 0
		var estimate: T = (low + high) / T(2)
		let tolerance: T = T(1) / T(10_000_000)
		let flat: T = T(1) / T(1_000_000_000)
		for _ in 0..<60 {
			guard lowValue > highValue else { break }
			let span: T = high - low
			let next: T = low + span * lowValue / (lowValue - highValue)
			guard next > low, next < high else { break }
			let value: T = derivative(next)
			estimate = next
			if value > T.zero {
				low = next
				lowValue = value
				if retained > 0 { highValue /= T(2) }
				retained = 1
			} else {
				high = next
				highValue = value
				if retained < 0 { lowValue /= T(2) }
				retained = -1
			}
			let width: T = high - low
			let bound: T = tolerance * (T(1) + low)
			if width <= bound || Swift.abs(value) < flat { break }
		}
		return Swift.max(estimate, floor)
	}

	/// A fit that keeps every multiplier at `1` and fits only the scale: the reference weights, calibrated.
	///
	/// - Throws: As for ``fitScale(groupWeights:)``.
	@_specialize(exported: true, where T == Double)
	public func referenceFit(groupWeights: [T]) throws -> GroupedChoiceFit<T> {
		let scale = try fitScale(groupWeights: groupWeights)
		return GroupedChoiceFit(
			multipliers: [T](repeating: T(1), count: data.featureCount), scale: scale, iterations: 0, converged: true)
	}

	/// Fits the scale, then the multipliers around the reference.
	///
	/// With the scale held, the multipliers `m` (each at least zero) minimise
	/// `negativeLogLikelihood / chosen + (penalty / 2) × Σ (m[k] − 1)²`. The penalty pulls each weight toward its reference
	/// value, on the **relative** change, so a data set has to argue for any move: a very large penalty returns the reference
	/// and a very small one approaches the unpenalised optimum. The objective is convex, so the optimum is unique. It is solved
	/// by projected accelerated gradient descent with a backtracking line search and a restart whenever the objective rises.
	///
	/// A feature whose reference is `0` cannot move (its multiplier is not identified) and stays at `1`.
	///
	/// - Parameters:
	///   - groupWeights: How much each group counts: `0` leaves it out, `2` counts it twice, as in a resample.
	///   - penalty: The pull toward the reference; finite and not negative.
	///   - frozen: Feature columns that keep a multiplier of `1`.
	///   - start: Where to begin, one value per feature (negative values are raised to zero); `nil` starts at the reference.
	///   - maxIterations: The most steps to take.
	/// - Throws: ``GroupedChoiceError/malformedInput(reason:)``, ``GroupedChoiceError/noInformativeGroups``, or
	///   ``GroupedChoiceError/didNotConverge(iterations:gradientNorm:)`` when the steps run out or the line search fails
	///   while the projected gradient is still large. A result that did not settle is never returned as if it had.
	@_specialize(exported: true, where T == Double)
	public func fit(
		groupWeights: [T], penalty: T, frozen: Set<Int> = [], start: [T]? = nil, maxIterations: Int = 300
	) throws -> GroupedChoiceFit<T> {
		try validate(groupWeights: groupWeights)
		guard penalty.isFinite, penalty >= T.zero else { throw GroupedChoiceError.malformedInput(reason: "penalty must be finite and not negative") }
		guard maxIterations > 0 else { throw GroupedChoiceError.malformedInput(reason: "maxIterations must be positive") }
		if let start {
			guard start.count == data.featureCount, start.allSatisfy({ $0.isFinite }) else {
				throw GroupedChoiceError.malformedInput(reason: "start must have one finite value per feature")
			}
		}
		let scale = try fitScale(groupWeights: groupWeights)
		let ones = [T](repeating: T(1), count: data.featureCount)
		let free = (0..<data.featureCount).filter { !frozen.contains($0) && reference[$0] > T.zero }
		guard !free.isEmpty else { return GroupedChoiceFit(multipliers: ones, scale: scale, iterations: 0, converged: true) }
		var totalChosen: T = T.zero
		for group in data.informativeGroups {
			let weighted: T = groupWeights[group] * T(data.stepCount(group: group))
			totalChosen += weighted
		}
		guard totalChosen > T.zero else { throw GroupedChoiceError.noInformativeGroups }
		let half: T = T(1) / T(2)

		func objective(_ multipliers: [T], gradient wantGradient: Bool) -> (value: T, gradient: [T])? {
			guard let evaluated = evaluate(multipliers: multipliers, scale: scale, groupWeights: groupWeights, gradient: wantGradient) else {
				return nil
			}
			var value: T = evaluated.negativeLogLikelihood / totalChosen
			var gradient = [T](repeating: T.zero, count: data.featureCount)
			for k in free {
				let distance: T = multipliers[k] - T(1)
				let square: T = distance * distance
				value += half * penalty * square
				let likelihoodPart: T = evaluated.gradient[k] / totalChosen
				gradient[k] = likelihoodPart + penalty * distance
			}
			return (value, gradient)
		}

		var current = ones
		if let start { for k in free { current[k] = Swift.max(start[k], T.zero) } }
		var extrapolated = current
		var momentum: T = T(1)
		var step: T = half
		guard var currentValue = objective(current, gradient: false)?.value else {
			throw GroupedChoiceError.malformedInput(reason: "the objective is not finite at the starting point")
		}
		var iterations = 0
		var converged = false
		var stalled = false
		let settle: T = T(1) / T(1_000_000)
		let rounding: T = T(1) / T(100_000_000_000_000)
		while iterations < maxIterations {
			iterations += 1
			guard let here = objective(extrapolated, gradient: true) else { break }
			var candidate = extrapolated
			var candidateValue: T = T.zero
			var accepted = false
			var attempts = 0
			while attempts < 40 {
				attempts += 1
				guard step > T.zero else { break }
				for k in free {
					let moved: T = extrapolated[k] - step * here.gradient[k]
					candidate[k] = Swift.max(moved, T.zero)
				}
				guard let tried = objective(candidate, gradient: false) else { step *= half; continue }
				candidateValue = tried.value
				var directional: T = T.zero
				var squared: T = T.zero
				for k in free {
					let move: T = candidate[k] - extrapolated[k]
					directional += here.gradient[k] * move
					squared += move * move
				}
				let quadratic: T = squared / (T(2) * step)
				let bound: T = here.value + directional + quadratic
				if candidateValue <= bound + rounding { accepted = true; break }
				step *= half
			}
			guard accepted else { stalled = true; break }
			var largest: T = T.zero
			for k in free { let moved: T = Swift.abs(candidate[k] - current[k]); largest = Swift.max(largest, moved) }
			let restart: Bool = candidateValue > currentValue
			let inside: T = T(1) + T(4) * momentum * momentum
			let root: T = inside.squareRoot()
			let nextMomentum: T = restart ? T(1) : (T(1) + root) / T(2)
			let blend: T = restart ? T.zero : (momentum - T(1)) / nextMomentum
			for k in free {
				let pushed: T = candidate[k] + blend * (candidate[k] - current[k])
				extrapolated[k] = Swift.max(pushed, T.zero)
			}
			current = candidate
			currentValue = candidateValue
			momentum = nextMomentum
			step *= T(3) / T(2)
			if largest < settle { converged = true; break }
		}
		if !converged {
			let norm = projectedGradientNorm(at: current, free: free, objective: { objective($0, gradient: true) })
			let accepted: T = T(1) / T(100_000)
			guard stalled, norm <= accepted else {
				throw GroupedChoiceError.didNotConverge(iterations: iterations, gradientNorm: Double(norm))
			}
			converged = true
		}
		return GroupedChoiceFit(multipliers: current, scale: scale, iterations: iterations, converged: converged)
	}

	/// The size of the gradient that the non-negativity constraint leaves free to act: a component pushing a multiplier that
	/// sits at zero further below zero does not count.
	private func projectedGradientNorm(
		at multipliers: [T], free: [Int], objective: ([T]) -> (value: T, gradient: [T])?
	) -> T {
		guard let here = objective(multipliers) else { return T.infinity }
		var sum: T = T.zero
		for k in free {
			let component: T = here.gradient[k]
			let pinned: Bool = multipliers[k] <= T.zero && component > T.zero
			guard !pinned else { continue }
			sum += component * component
		}
		return sum.squareRoot()
	}

	private func validate(groupWeights: [T]) throws {
		guard groupWeights.count == data.groupCount else {
			throw GroupedChoiceError.malformedInput(reason: "groupWeights must have one entry per group")
		}
		guard groupWeights.allSatisfy({ $0.isFinite && $0 >= T.zero }) else {
			throw GroupedChoiceError.malformedInput(reason: "groupWeights must be finite and not negative")
		}
		var informative = false
		for group in data.informativeGroups where groupWeights[group] > T.zero { informative = true; break }
		guard informative else { throw GroupedChoiceError.noInformativeGroups }
	}
}
