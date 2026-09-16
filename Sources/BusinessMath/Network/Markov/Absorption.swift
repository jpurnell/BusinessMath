//
//  Absorption.swift
//  BusinessMath
//

import Foundation
import Numerics

public extension TransitionMatrix {

	/// The probability of eventually being absorbed in `target`, starting from `origin`.
	///
	/// Solved as a linear system rather than by simulating the chain: absorption
	/// probabilities satisfy `h(s) = Σ P(s → t) h(t)` with `h = 1` at the target and
	/// `h = 0` at every other absorbing state, which is `(I − Q)h = R` over the transient
	/// states. Iterating the chain converges to the same answer and takes an unbounded
	/// number of steps to get there when a state is nearly absorbing.
	///
	/// - Parameters:
	///   - target: An absorbing state.
	///   - origin: Any state.
	/// - Returns: The probability, or `nil` if either name is unknown or `target` is not
	///   absorbing — a question about eventual absorption in a state the chain can leave
	///   again has no answer of this shape.
	func absorptionProbability(to target: String, from origin: String) -> T? {
		guard position[target] != nil, position[origin] != nil else { return nil }
		guard absorbingStates.contains(target) else { return nil }

		let absorbing = Set(absorbingStates)
		let transient = states.filter { !absorbing.contains($0) }
		if absorbing.contains(origin) { return origin == target ? T(1) : T.zero }
		guard !transient.isEmpty else { return T.zero }

		var slot: [String: Int] = [:]
		for (index, name) in transient.enumerated() { slot[name] = index }

		// (I − Q) h = R, where R is the one-step chance of landing on the target.
		let size = transient.count
		var matrix = [[T]](repeating: [T](repeating: T.zero, count: size), count: size)
		var rhs = [T](repeating: T.zero, count: size)
		for (row, name) in transient.enumerated() {
			matrix[row][row] = T(1)
			for (column, other) in transient.enumerated() {
				let step = probability(from: name, to: other)
				matrix[row][column] -= step
			}
			rhs[row] = probability(from: name, to: target)
		}

		guard let solution = Self.solve(matrix, rhs) else { return nil }
		guard let index = slot[origin] else { return nil }
		return solution[index]
	}

	/// The expected number of steps before absorption, starting from `origin`.
	///
	/// `(I − Q)k = 1`. Undefined — `nil` — when the chain can avoid absorption forever,
	/// which the singular system reports rather than a large number.
	///
	/// - Parameter origin: Any transient state.
	/// - Returns: The expected step count, or `nil` for an unknown state, an absorbing
	///   one (zero steps, reported as zero), or a chain that need never absorb.
	func expectedStepsToAbsorption(from origin: String) -> T? {
		guard position[origin] != nil else { return nil }
		let absorbing = Set(absorbingStates)
		if absorbing.contains(origin) { return T.zero }
		let transient = states.filter { !absorbing.contains($0) }
		guard !transient.isEmpty else { return nil }

		var slot: [String: Int] = [:]
		for (index, name) in transient.enumerated() { slot[name] = index }
		let size = transient.count
		var matrix = [[T]](repeating: [T](repeating: T.zero, count: size), count: size)
		let rhs = [T](repeating: T(1), count: size)
		for (row, name) in transient.enumerated() {
			matrix[row][row] = T(1)
			for (column, other) in transient.enumerated() {
				matrix[row][column] -= probability(from: name, to: other)
			}
		}
		guard let solution = Self.solve(matrix, rhs), let index = slot[origin] else {
			return nil
		}
		return solution[index]
	}

	/// The stationary distribution: the `π` with `πP = π` and `Σπ = 1`.
	///
	/// Solved directly, by replacing one column of `Pᵀ − I` with the normalisation row.
	/// The system is singular without it — `πP = π` has a one-dimensional solution space
	/// and every scalar multiple satisfies it — so the constraint is not a convenience,
	/// it is what makes the answer unique.
	///
	/// Meaningful for an **ergodic** chain, where every state reaches every other. An
	/// absorbing chain has a stationary distribution too, and it is entirely concentrated
	/// on the absorbing states, which is true and uninformative — for those,
	/// ``absorptionProbability(to:from:)`` is the question worth asking.
	///
	/// - Returns: The distribution, or `nil` if the system is singular.
	func steadyState() -> [String: T]? {
		let size = states.count
		guard size > 0 else { return nil }
		var matrix = [[T]](repeating: [T](repeating: T.zero, count: size), count: size)
		var rhs = [T](repeating: T.zero, count: size)
		// Pᵀ − I for all but the last equation.
		for row in 0..<(size - 1) {
			for column in 0..<size {
				matrix[row][column] = rows[column][row]
			}
			matrix[row][row] -= 1
		}
		// The last equation is Σπ = 1, which is what pins the scale.
		for column in 0..<size { matrix[size - 1][column] = T(1) }
		rhs[size - 1] = T(1)

		guard let solution = Self.solve(matrix, rhs) else { return nil }
		guard solution.allSatisfy({ $0.isFinite }) else { return nil }
		var distribution: [String: T] = [:]
		for (index, name) in states.enumerated() { distribution[name] = solution[index] }
		return distribution
	}

	/// Gaussian elimination with partial pivoting.
	///
	/// The implementation lives in `gaussianSolve(_:_:)`, which is internal and so cannot be
	/// linked from here. It used to live here as well,
	/// character for character, because `LogisticRegression` needed the same routine and
	/// took a copy — two solvers that could have drifted apart and would have done so
	/// silently, since nothing compared them.
	///
	/// - Returns: The solution, or `nil` when the matrix is singular to working precision.
	static func solve(_ matrix: [[T]], _ rhs: [T]) -> [T]? {
		gaussianSolve(matrix, rhs)
	}
}
