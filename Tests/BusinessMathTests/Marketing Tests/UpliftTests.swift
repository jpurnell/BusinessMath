//
//  UpliftTests.swift
//  BusinessMath
//
//  Two-model and class-transformation uplift, and the three ways an incremental-effect
//  number is quietly not one.
//
//  - **A response model presented as uplift.** Fit on the treated arm alone and you get a
//    valid, well-calibrated ranking of who responds under treatment. It is not a ranking
//    of who is *moved* by treatment, and the two can be nearly opposite: the customers
//    who would have bought anyway score highest on response and zero on uplift. A
//    response model cannot even represent the negative case, because it never sees the
//    counterfactual.
//  - **Class transformation on an unbalanced design.** The `2p − 1` identity holds only
//    where treatment is allocated at one half. At seventy-thirty the transform still
//    returns numbers in [−1, 1] that read as uplifts, biased toward the treated arm's
//    response rate, and nothing in the output records the design.
//  - **A bucket with no controls.** Its control rate is 0/0. Score that as zero and the
//    bucket's uplift becomes the full treated response rate — the largest number in the
//    table, sitting in the bucket you were about to target.
//
//  The anchor needs no reference implementation. With one binary predictor, a saturated
//  model, and treatment allocated at exactly one half within each level, the two methods
//  are algebraically the same number: the two-model estimate is `r_T − r_C`, and the
//  transformed rate is `(r_T + 1 − r_C)/2`, so `2p − 1` returns `r_T − r_C` exactly.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Uplift")
struct UpliftTests {

	struct Row: Sendable {
		let x: Double
		let treated: Bool
		let responded: Bool
	}

	/// One cell of a two-by-two design: `responders` of `size` subjects respond.
	static func cell(_ x: Double, treated: Bool, responders: Int, size: Int) -> [Row] {
		(0..<size).map { Row(x: x, treated: treated, responded: $0 < responders) }
	}

	/// Balanced: eight treated and eight control at each level of `x`.
	///
	/// | x | treated | control | uplift |
	/// |---|---|---|---|
	/// | 0 | 3/8 | 2/8 | 1/8 |
	/// | 1 | 6/8 | 3/8 | 3/8 |
	static let balanced: [Row] = {
		var all: [Row] = []
		all += cell(0, treated: true, responders: 3, size: 8)
		all += cell(0, treated: false, responders: 2, size: 8)
		all += cell(1, treated: true, responders: 6, size: 8)
		all += cell(1, treated: false, responders: 3, size: 8)
		return all
	}()

	/// Twenty-two treated against ten control — a design class transformation refuses.
	static let unbalanced: [Row] = {
		var all: [Row] = []
		all += cell(0, treated: true, responders: 4, size: 11)
		all += cell(0, treated: false, responders: 1, size: 5)
		all += cell(1, treated: true, responders: 8, size: 11)
		all += cell(1, treated: false, responders: 2, size: 5)
		return all
	}()

	static func model(_ rows: [Row], _ method: UpliftMethod) throws -> UpliftModel<Double> {
		try UpliftModel(predictors: rows.map { [$0.x] },
						treated: rows.map { $0.treated },
						responded: rows.map { $0.responded },
						method: method)
	}

	// MARK: - The identity

	@Test("Two-model and class transformation agree exactly on a balanced saturated design")
	func methodsAgree() throws {
		let twoModel = try Self.model(Self.balanced, .twoModel)
		let transformed = try Self.model(Self.balanced, .classTransformation)
		for level: Double in [0, 1] {
			let a = try #require(twoModel.uplift([level]))
			let b = try #require(transformed.uplift([level]))
			#expect(Swift.abs(a - b) < 1e-9, "at x = \(level): \(a) against \(b)")
		}
	}

	@Test("A saturated fit returns the cell's own rate difference")
	func saturatedFitIsTheCellDifference() throws {
		let twoModel = try Self.model(Self.balanced, .twoModel)
		let low = try #require(twoModel.uplift([0]))
		let high = try #require(twoModel.uplift([1]))
		// 3/8 − 2/8 and 6/8 − 3/8, with two parameters covering two cells.
		#expect(Swift.abs(low - 0.125) < 1e-9, "low cell \(low)")
		#expect(Swift.abs(high - 0.375) < 1e-9, "high cell \(high)")
	}

	@Test("Average predicted uplift equals the observed treatment effect")
	func averagePredictionMatchesTheObservedEffect() throws {
		let twoModel = try Self.model(Self.balanced, .twoModel)
		let scores = try #require(twoModel.upliftScores(Self.balanced.map { [$0.x] }))
		let total: Double = scores.reduce(0, +)
		let mean: Double = total / Double(scores.count)
		let observed: Double = twoModel.averageTreatmentEffect
		#expect(Swift.abs(observed - 0.25) < 1e-12, "observed effect \(observed)")
		#expect(Swift.abs(mean - observed) < 1e-9, "mean \(mean) against \(observed)")
	}

	@Test("Uplift is bounded by plus and minus one")
	func upliftIsBounded() throws {
		for method in UpliftMethod.allCases {
			let fitted = try Self.model(Self.balanced, method)
			for level: Double in [0, 1] {
				let value = try #require(fitted.uplift([level]))
				#expect(value >= -1, "\(method) at \(level): \(value)")
				#expect(value <= 1, "\(method) at \(level): \(value)")
			}
		}
	}

	// MARK: - The bucket table

	@Test("Buckets rank by predicted uplift and report what each arm actually did")
	func bucketTableReportsBothArms() throws {
		let twoModel = try Self.model(Self.balanced, .twoModel)
		let table = try #require(twoModel.upliftByBucket(buckets: 2))
		#expect(table.count == 2)
		let best = table[0]
		#expect(best.treatedCount == 8, "treated in the best bucket \(best.treatedCount)")
		#expect(best.controlCount == 8, "control in the best bucket \(best.controlCount)")
		#expect(Swift.abs(best.observedUplift - 0.375) < 1e-9, "observed \(best.observedUplift)")
		#expect(Swift.abs(best.predictedUplift - 0.375) < 1e-9, "predicted \(best.predictedUplift)")
		let worst = table[1]
		#expect(Swift.abs(worst.observedUplift - 0.125) < 1e-9, "observed \(worst.observedUplift)")
		#expect(best.observedUplift > worst.observedUplift, "the ranking should mean something")
	}

	@Test("A bucket missing an arm is refused rather than scored against nothing")
	func bucketMissingAnArmIsRefused() throws {
		let twoModel = try Self.model(Self.balanced, .twoModel)
		// Thirty-two rows into thirty-two buckets puts one subject in each, so every
		// bucket is missing one arm entirely.
		#expect(twoModel.upliftByBucket(buckets: 32) == nil)
		#expect(twoModel.upliftByBucket(buckets: 0) == nil)
	}

	// MARK: - Refusals

	@Test("Class transformation refuses an unbalanced allocation that two-model accepts")
	func classTransformationRefusesImbalance() throws {
		let twoModel = try Self.model(Self.unbalanced, .twoModel)
		let low = try #require(twoModel.uplift([0]))
		#expect(low.isFinite, "two-model has no balance requirement, got \(low)")
		#expect(throws: UpliftError.unbalancedAllocation(treatedShare: 0.6875)) {
			_ = try Self.model(Self.unbalanced, .classTransformation)
		}
	}

	@Test("An arm with nobody in it is refused")
	func emptyArmIsRefused() {
		let treatedOnly = Self.cell(0, treated: true, responders: 3, size: 8)
		#expect(throws: UpliftError.emptyArm(treated: 8, control: 0)) {
			_ = try Self.model(treatedOnly, .twoModel)
		}
	}

	@Test("Mismatched inputs are refused before anything is fitted")
	func mismatchedInputIsRefused() {
		#expect(throws: UpliftError.self) {
			_ = try UpliftModel<Double>(predictors: [[1], [2], [3]],
										treated: [true, false],
										responded: [true, false, true],
										method: .twoModel)
		}
		#expect(throws: UpliftError.self) {
			_ = try UpliftModel<Double>(predictors: [],
										treated: [],
										responded: [],
										method: .twoModel)
		}
	}

	@Test("A separated arm is named, and the other arm is not blamed for it")
	func separatedArmIsNamed() {
		var rows: [Row] = []
		for (index, value) in [1.0, 2.0, 3.0, 4.0].enumerated() {
			rows.append(Row(x: value, treated: true, responded: index >= 2))
		}
		for (index, value) in [1.0, 2.0, 3.0, 4.0].enumerated() {
			rows.append(Row(x: value, treated: false, responded: index % 2 == 1))
		}
		let expected = UpliftError.arm(.treatment, .separation(variables: [0]))
		#expect(throws: expected) {
			_ = try Self.model(rows, .twoModel)
		}
	}

	@Test("Scoring a population of the wrong width is refused")
	func scoringRefusesTheWrongWidth() throws {
		let twoModel = try Self.model(Self.balanced, .twoModel)
		#expect(twoModel.uplift([0, 1]) == nil)
		#expect(twoModel.upliftScores([[0, 1], [1, 2]]) == nil)
		#expect(twoModel.upliftScores([]) == nil)
	}
}
