//
//  BranchAndBoundCutting.swift
//  BusinessMath
//
//  The cutting-plane round, taken out of `solveRelaxation` one stage at a time.
//

import Foundation
import Numerics

/// The stages of one cutting round.
///
/// ## Why these are here rather than inline
///
/// `solveRelaxation` was 529 lines with a cognitive complexity of 291 — the highest score in
/// the package by a factor of nearly two — and all but eighty of those lines were the body of a
/// single `for _ in 0..<maxCuttingRounds` loop. The loop is a pipeline: find a fractional
/// variable, take cuts off the tableau, normalise them, drop the duplicates, drop the dominated,
/// trim to the pool budget, retire the stale, add what survives, re-solve, and decide whether to
/// go round again. Each stage is small and has a name. Only the nesting made it look otherwise.
///
/// Splitting it is not cosmetic here. Three of the defects found in this file during the Tier 2
/// sweep were *scope* errors — a `break` bound to an inner scan rather than the round loop, a
/// bound read from the wrong collection, a `Set` iterated where order decided the answer — and
/// all three are mistakes that a two-hundred-line loop body makes easy and a twenty-line
/// function makes hard.
///
/// Every method below is a lift, not a rewrite. The behaviour is the behaviour the audit and
/// determinism suites were written against.
extension BranchAndBoundSolver {

	// MARK: - Deciding whether to cut at all

	/// Whether any variable the specification requires to be integral is fractional here.
	///
	/// A cut exists to remove a fractional vertex, so an integral solution ends the round loop:
	/// there is nothing to separate. The comparison is two-sided against
	/// ``integralityTolerance`` because a value a hair *below* an integer is as integral as one
	/// a hair above, and `value - floor(value)` puts those at opposite ends of the unit
	/// interval.
	///
	/// - Parameters:
	///   - solution: The relaxation's solution, as components.
	///   - integerSpec: Which variables must be integral.
	///   - dimension: The structural variable count; tableau columns past it are slacks.
	/// - Returns: `true` if at least one integer-constrained variable is fractional.
	func hasFractionalIntegerVariable(
		_ solution: [Double],
		integerSpec: IntegerProgramSpecification,
		dimension: Int
	) -> Bool {
		for i in 0..<Swift.min(dimension, solution.count) {
			let shouldBeInteger = integerSpec.integerVariables.contains(i)
				|| integerSpec.binaryVariables.contains(i)
			guard shouldBeInteger else { continue }

			let value = solution[i]
			let fractionalPart = value - floor(value)
			if fractionalPart > integralityTolerance && fractionalPart < 1.0 - integralityTolerance {
				return true
			}
		}
		return false
	}

	// MARK: - Taking cuts off the tableau

	/// The tableau rows a Gomory cut can be taken from.
	///
	/// One row per basic variable that is both required to be integral and currently fractional.
	/// Each is rewritten in terms of the non-basic variables, which is the form
	/// ``CuttingPlaneGenerator`` reads: the basic variable's own column is the identity, so it
	/// carries no information, and the row's right-hand side is the variable's value.
	///
	/// - Parameters:
	///   - tableau: The final simplex tableau.
	///   - basis: Basic variable index per row.
	///   - solution: The relaxation's solution, indexed by variable.
	///   - integerSpec: Which variables must be integral.
	///   - totalVariableCount: Structural variables plus slacks — the tableau's columns less the
	///     right-hand side.
	///   - nonBasicIndices: The complement of `basis`, in ascending order.
	/// - Returns: A row per fractional integer-constrained basic variable, possibly empty.
	func fractionalSimplexRows(
		tableau: SimplexTableau,
		basis: [Int],
		solution: [Double],
		integerSpec: IntegerProgramSpecification,
		totalVariableCount: Int,
		nonBasicIndices: [Int]
	) -> [SimplexRow] {
		var rows: [SimplexRow] = []

		for (rowIndex, basicVarIndex) in basis.enumerated() {
			guard basicVarIndex < solution.count else { continue }

			let value = solution[basicVarIndex]
			let fractionalPart = value - floor(value)
			let shouldBeInteger = integerSpec.integerVariables.contains(basicVarIndex)
				|| integerSpec.binaryVariables.contains(basicVarIndex)

			guard shouldBeInteger,
				  fractionalPart > integralityTolerance,
				  fractionalPart < 1.0 - integralityTolerance else { continue }

			let fullTableauRow = tableau.getRow(rowIndex)
			let allCoefficients = Array(fullTableauRow.prefix(totalVariableCount))
			let nonBasicCoefficients = nonBasicIndices.map { allCoefficients[$0] }

			rows.append(
				SimplexRow(
					rhs: value,
					coefficients: nonBasicCoefficients,
					nonBasicVariableIndices: nonBasicIndices,
					basicVariableIndex: basicVarIndex
				)
			)
		}

		return rows
	}

	/// Cover cuts from whichever of the caller's rows are binary knapsacks.
	///
	/// A cover cut is valid only when every variable with a non-zero coefficient in the row is
	/// binary, so a row mentioning a general integer or a continuous variable is skipped rather
	/// than cut. `≤` rows only: a cover argument is about exceeding a capacity.
	///
	/// - Parameters:
	///   - constraints: The caller's constraints, before any cut was added.
	///   - solution: The relaxation's solution, as components.
	///   - integerSpec: Which variables are binary.
	///   - dimension: The structural variable count.
	///   - generator: The generator to ask, configured with this solver's tolerances.
	/// - Returns: Zero or more cover cuts.
	/// - Throws: Whatever ``CuttingPlaneGenerator/generateCoverCut(weights:capacity:solution:)``
	///   throws for a malformed row.
	func coverCuts(
		from constraints: [MultivariateConstraint<V>],
		solution: [Double],
		integerSpec: IntegerProgramSpecification,
		dimension: Int,
		generator: CuttingPlaneGenerator
	) throws -> [CuttingPlane] {
		var cuts: [CuttingPlane] = []

		for constraint in constraints {
			guard case .linearInequality(let coefficients, let rhs, let sense) = constraint,
				  sense == .lessOrEqual else { continue }

			var isBinaryKnapsack = true
			for i in 0..<Swift.min(coefficients.count, dimension) where coefficients[i] != 0.0 {
				if !integerSpec.binaryVariables.contains(i) {
					isBinaryKnapsack = false
					break
				}
			}

			guard isBinaryKnapsack, coefficients.count <= dimension else { continue }
			if let coverCut = try generator.generateCoverCut(
				weights: coefficients,
				capacity: rhs,
				solution: solution
			) {
				cuts.append(coverCut)
			}
		}

		return cuts
	}

	// MARK: - Choosing which cuts to keep

	/// Scales cuts to unit norm and drops the ones already seen at this node.
	///
	/// Normalisation exists so that two cuts expressing the same halfspace compare equal — a cut
	/// and twice the same cut are the same constraint, and without scaling the signature below
	/// would treat them as two. A cut whose norm is at or below ``cutCoefficientThreshold`` is
	/// discarded instead of scaled: dividing by it would inflate rounding error into the
	/// coefficients, and a cut that close to `0 ≤ b` separates nothing worth the row.
	///
	/// - Parameters:
	///   - cuts: The generated cuts, unnormalised.
	///   - seen: Signatures already added at this node; updated in place.
	/// - Returns: The kept cuts, in generation order.
	func normalisedAndDeduplicated(
		_ cuts: [CuttingPlane],
		seen: inout Set<String>
	) -> [CuttingPlane] {
		var kept: [CuttingPlane] = []

		for var cut in cuts {
			if normalizeCuts {
				let norm: Double
				switch cutScalingNorm {
				case .euclidean:
					norm = sqrt(cut.coefficients.reduce(0.0) { $0 + $1 * $1 })
				case .infinity:
					norm = cut.coefficients.map { abs($0) }.max() ?? 0.0
				}

				guard norm > cutCoefficientThreshold else { continue }

				let normalizedCoeffs = cut.coefficients.map { $0 / norm } // fp-safety:disable — norm > cutCoefficientThreshold per guard above
				let normalizedRHS = cut.rhs / norm // fp-safety:disable — norm > cutCoefficientThreshold per guard above

				cut = CuttingPlane(
					coefficients: normalizedCoeffs,
					rhs: normalizedRHS,
					type: cut.type,
					sourceIndex: cut.sourceIndex
				)
			}

			let signature = "\(cut.coefficients.map { $0.number(6) }.joined(separator: ",")):\(cut.rhs.number(6))"
			if !seen.contains(signature) {
				kept.append(cut)
				seen.insert(signature)
			}
		}

		return kept
	}

	/// Drops each cut that an already-kept cut makes redundant.
	///
	/// Two relations count as redundancy: outright domination, and being parallel to a kept cut
	/// with a right-hand side no tighter. Both are checked against the cuts *kept so far* rather
	/// than against the whole batch, so the first of a redundant pair survives and order is what
	/// breaks the tie — which is why the caller must hand these over in a deterministic order.
	///
	/// - Parameter cuts: Candidate cuts for this round.
	/// - Returns: The cuts with no kept predecessor that subsumes them. Returns the input
	///   unchanged when ``filterDominatedCuts`` is off.
	func withoutDominatedCuts(_ cuts: [CuttingPlane]) -> [CuttingPlane] {
		guard filterDominatedCuts else { return cuts }

		var kept: [CuttingPlane] = []
		for cut in cuts {
			var isDominated = kept.contains { isCutDominated(cut, by: $0, tolerance: 1e-8) }

			if !isDominated {
				// Parallel and no stronger is the same redundancy wearing a different face: the
				// halfspaces have the same normal, so the looser right-hand side cuts nothing
				// the tighter one has not already cut.
				isDominated = kept.contains {
					areCutsParallel(cut, $0, tolerance: 1e-8) && cut.rhs >= $0.rhs
				}
			}

			if !isDominated { kept.append(cut) }
		}
		return kept
	}

	/// Trims a round's cuts to what the pool has room for.
	///
	/// - Parameters:
	///   - cuts: The cuts that survived filtering.
	///   - alreadyGenerated: How many cuts this solve has added so far.
	/// - Returns: The cuts to add, or `nil` when the pool is already full and the round loop
	///   should stop. `nil` is the full-pool signal rather than an empty array, because an empty
	///   round and an exhausted budget are different reasons to stop and the caller treats them
	///   differently.
	func withinPoolBudget(_ cuts: [CuttingPlane], alreadyGenerated: Int) -> [CuttingPlane]? {
		guard maxCutPoolSize > 0 else { return cuts }
		guard alreadyGenerated < maxCutPoolSize else { return nil }

		let remaining = maxCutPoolSize - alreadyGenerated
		return cuts.count > remaining ? Array(cuts.prefix(remaining)) : cuts
	}

	// MARK: - The constraint set

	/// Retires cuts that have gone too long without being active.
	///
	/// A cut that no longer binds is a row the LP carries and never uses, and the simplex method
	/// pays for it on every pivot. Removal renumbers the constraint array, so every surviving
	/// record's index is shifted by the removals below it — that bookkeeping is the whole reason
	/// this is fiddly, and the reason it is one function rather than four blocks inside a loop.
	///
	/// - Parameters:
	///   - constraints: The node's constraint set, cuts included; mutated.
	///   - ages: Per-cut age records; mutated to match.
	///   - round: The current round number, against which age is measured.
	///   - stats: Statistics to credit removals to.
	func removeAgedCuts(
		from constraints: inout [MultivariateConstraint<V>],
		ages: inout [(constraintIndex: Int, roundAdded: Int, lastActiveRound: Int)],
		round: Int,
		stats: CutStatisticsTracker
	) {
		var indicesToRemove: Set<Int> = []
		for cutAge in ages where round - cutAge.lastActiveRound >= cutAgingLimit {
			indicesToRemove.insert(cutAge.constraintIndex)
		}
		guard !indicesToRemove.isEmpty else { return }

		// Descending, so each removal cannot disturb the position of one not yet made.
		let sortedIndices = indicesToRemove.sorted(by: >)
		for index in sortedIndices where index < constraints.count {
			constraints.remove(at: index)
			// Counted here rather than from `indicesToRemove.count`: an index past the end of
			// the constraint set removes nothing, and reporting it as removed would overstate
			// the work done.
			stats.cutsRemoved += 1
		}

		ages.removeAll { indicesToRemove.contains($0.constraintIndex) }
		for removedIndex in sortedIndices {
			for i in 0..<ages.count where ages[i].constraintIndex > removedIndex {
				ages[i].constraintIndex -= 1
			}
		}
	}

	/// Projects each cut into the structural variables and appends it to the node.
	///
	/// A cut comes off a tableau row, so its support is whatever was non-basic there —
	/// structural variables *and* slacks. Imposing it over the structural variables alone drops
	/// the slack terms while keeping a right-hand side that was never theirs, which is how this
	/// used to emit `0 ≤ −0.7071`: false at every point, so the LP went infeasible on the first
	/// cut and the whole round was discarded. Project first, and skip any cut that will not
	/// project.
	///
	/// - Parameters:
	///   - cuts: The cuts to add.
	///   - constraints: The node's constraint set; appended to.
	///   - ages: Age records; appended to when ``enableCutAging`` is on.
	///   - tableau: The tableau the cuts came from, which owns the projection.
	///   - dimension: The structural variable count.
	///   - round: The round to record as this cut's birth.
	///   - stats: Statistics to credit the cuts to, by type.
	func appendCuts(
		_ cuts: [CuttingPlane],
		to constraints: inout [MultivariateConstraint<V>],
		ages: inout [(constraintIndex: Int, roundAdded: Int, lastActiveRound: Int)],
		tableau: SimplexTableau,
		dimension: Int,
		round: Int,
		stats: CutStatisticsTracker
	) {
		for cut in cuts {
			guard let projected = tableau.projectToStructuralSpace(
				coefficients: cut.coefficients,
				rhs: cut.rhs
			) else { continue }

			let structuralCoefficients = Array(projected.coefficients.prefix(dimension))
			constraints.append(
				.linearInequality(
					coefficients: structuralCoefficients,
					rhs: projected.rhs,
					sense: .lessOrEqual
				)
			)

			if enableCutAging {
				ages.append(
					(constraintIndex: constraints.count - 1, roundAdded: round, lastActiveRound: round)
				)
			}

			stats.totalCutsGenerated += 1
			switch cut.type {
			case .gomory:               stats.gomoryCuts += 1
			case .mixedIntegerRounding: stats.mirCuts += 1
			case .cover:                stats.coverCuts += 1
			case .clique:               break
			}
		}
	}

	// MARK: - Deciding whether to go round again

	/// Whether the round loop should stop, having re-solved.
	///
	/// Two reasons, both optional and both about wasted rounds rather than about correctness:
	/// the bound has stopped improving, or the LP has returned to a vertex it already visited.
	///
	/// The cycling test is written as one predicate rather than as a loop with a `break` inside
	/// it. The loop form is what this used to be, and its `break` bound to the scan rather than
	/// to the cutting-round loop it was meant to stop — so a cycle was detected and the next
	/// round started anyway. Measured before the change: 32 rounds with detection on and 32 with
	/// it off, identical to the integer.
	///
	/// - Parameters:
	///   - bound: The objective value just returned.
	///   - solution: The solution just returned, as components.
	///   - bounds: Bounds seen so far at this node; appended to.
	///   - solutions: Solutions seen so far at this node; appended to.
	/// - Returns: `true` when the loop should stop.
	func cuttingShouldStop(
		bound: Double,
		solution: [Double],
		bounds: inout [Double],
		solutions: inout [[Double]]
	) -> Bool {
		if detectStagnation {
			bounds.append(bound)
			if bounds.count >= 2 {
				let previous = bounds[bounds.count - 2]
				let current = bounds[bounds.count - 1]
				if abs(current - previous) < stagnationTolerance { return true }
			}
		}

		if detectCycling {
			solutions.append(solution)
			if solutions.count > cyclingWindowSize {
				let recent = Array(solutions.suffix(cyclingWindowSize))
				let repeatsAnEarlierVertex = recent.dropLast().contains {
					Self.solutionsAgree(solution, $0, tolerance: stagnationTolerance)
				}
				if repeatsAnEarlierVertex { return true }
			}
		}

		return false
	}

	/// Componentwise agreement, used to recognise a vertex the search has already stood on.
	///
	/// - Parameters:
	///   - a: One solution.
	///   - b: Another.
	///   - tolerance: Per-component absolute tolerance.
	/// - Returns: `true` when the two have the same length and agree everywhere.
	static func solutionsAgree(_ a: [Double], _ b: [Double], tolerance: Double) -> Bool {
		guard a.count == b.count else { return false }
		return zip(a, b).allSatisfy { abs($0 - $1) < tolerance }
	}
}
