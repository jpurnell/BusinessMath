//
//  BranchAndBoundFeasibilityTests.swift
//  BusinessMath
//
//  `IntegerProgramSpecification.isIntegerFeasible` reports infeasibility by letting a
//  comparison become true, and every comparison against a NaN is false — so an unevaluable
//  variable passed all three of its tests. It is not a wrong number on a report: branch and
//  bound calls this *first*, so the relaxation was accepted as an integer solution and adopted
//  as the incumbent, and `mostFractionalVariable` — which would have caught it — is never
//  reached.
//
//  `BranchAndBound.improves` completed the path: its `guard let incumbent else { return true }`
//  adopts the first candidate unconditionally, so a NaN objective became the incumbent and
//  every later comparison against it was false, leaving it there for the rest of the search.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Integer feasibility refuses what it cannot evaluate")
struct BranchAndBoundFeasibilityTests {

	// MARK: - The three tests that a NaN used to pass

	@Test("A NaN is not an integer")
	func nonFiniteIsNotIntegerFeasible() {
		let spec = IntegerProgramSpecification(integerVariables: [0, 1])
		let contaminated = VectorN([3.0, Double.nan])
		#expect(spec.isIntegerFeasible(contaminated) == false)
	}

	@Test("A NaN is not a binary")
	func nonFiniteIsNotBinaryFeasible() {
		let spec = IntegerProgramSpecification(binaryVariables: [0, 1])
		let contaminated = VectorN([1.0, Double.nan])
		#expect(spec.isIntegerFeasible(contaminated) == false)
	}

	@Test("A NaN is not a zero, so it cannot be excused from an SOS1 set")
	func nonFiniteIsNotAZeroInAnSOS1Set() {
		// The set permits at most one nonzero. The NaN was counted as zero — `abs(nan) > tol`
		// is false — so it sat alongside the genuine nonzero and the set looked satisfied.
		let spec = IntegerProgramSpecification(sosType1: [[0, 1]])
		let contaminated = VectorN([5.0, Double.nan])
		#expect(spec.isIntegerFeasible(contaminated) == false)
	}

	// MARK: - Controls: what must NOT have changed

	@Test("A genuinely integral solution is still feasible")
	func integralSolutionStillPasses() {
		let spec = IntegerProgramSpecification(integerVariables: [0, 1])
		#expect(spec.isIntegerFeasible(VectorN([3.0, 7.0])))
	}

	@Test("A fractional value is still infeasible, for its own reason")
	func fractionalIsStillInfeasible() {
		let spec = IntegerProgramSpecification(integerVariables: [0])
		#expect(spec.isIntegerFeasible(VectorN([3.5])) == false)
	}

	@Test("Binary and SOS1 controls still behave")
	func binaryAndSOS1ControlsStillPass() {
		let binary = IntegerProgramSpecification(binaryVariables: [0, 1])
		#expect(binary.isIntegerFeasible(VectorN([0.0, 1.0])))
		#expect(binary.isIntegerFeasible(VectorN([0.0, 0.5])) == false)

		let sos = IntegerProgramSpecification(sosType1: [[0, 1]])
		#expect(sos.isIntegerFeasible(VectorN([5.0, 0.0])))
		#expect(sos.isIntegerFeasible(VectorN([5.0, 2.0])) == false)
	}

	// `BranchAndBound.improves` carries the matching guard — a NaN objective does not improve on
	// anything, including on nothing, so it can no longer be adopted as the first incumbent.
	// It is `private`, which `@testable` does not reach, and widening a declaration purely to
	// assert it directly is not worth the source change: the guard above closes the path that
	// reaches it, and `improves` is exercised through the solver by the existing
	// `BranchAndBound` suites. Recorded here so the absence reads as a decision.
}
