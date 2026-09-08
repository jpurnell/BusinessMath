//
//  ClassifierEvaluationTests.swift
//  BusinessMath
//
//  Model evaluation: ROC/AUC, KS, confusion matrix, calibration, gains.
//
//  The load-bearing oracle is an identity rather than a fixture. **AUC equals the
//  Mann–Whitney U statistic divided by the number of positive-negative pairs** — the
//  probability that a randomly chosen positive outscores a randomly chosen negative.
//  The implementation integrates the ROC curve; the test counts pairs. Those are
//  different computations over different intermediate structures, so agreement is
//  evidence rather than a tautology, and it is exact rather than approximate.
//
//  Ties are where AUC implementations go wrong, and where the identity earns its keep.
//  A tied pair contributes one half to the U statistic, and on the ROC that same tie is
//  a diagonal segment whose trapezoidal area is also one half. Both must handle it, and
//  case B exists to make them prove it: eight observations, three distinct scores, AUC
//  0.875 rather than the 0.8125 or 0.9375 that dropping or full-crediting ties gives.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Classifier evaluation")
struct ClassifierEvaluationTests {

	private static let noTies: (scores: [Double], outcomes: [Bool]) = (
		[0.1, 0.4, 0.35, 0.8, 0.7, 0.2, 0.9, 0.05, 0.6, 0.3],
		[false, false, true, true, true, false, true, false, true, false]
	)
	private static let withTies: (scores: [Double], outcomes: [Bool]) = (
		[0.5, 0.5, 0.5, 0.2, 0.8, 0.8, 0.2, 0.5],
		[false, true, false, false, true, true, false, true]
	)
	private static let perfect: (scores: [Double], outcomes: [Bool]) = (
		[0.1, 0.2, 0.3, 0.7, 0.8, 0.9],
		[false, false, false, true, true, true]
	)
	private static let inverted: (scores: [Double], outcomes: [Bool]) = (
		[0.9, 0.8, 0.7, 0.3, 0.2, 0.1],
		[false, false, false, true, true, true]
	)

	/// The Mann–Whitney U statistic over all positive-negative pairs, counted directly.
	///
	/// Deliberately the naive `O(n²)` double loop rather than anything clever: this is
	/// the definition, and a test that reimplements the implementation's optimisation
	/// checks nothing.
	private static func mannWhitneyAUC(_ scores: [Double], _ outcomes: [Bool]) -> Double {
		let positives = zip(scores, outcomes).filter { $0.1 }.map { $0.0 }
		let negatives = zip(scores, outcomes).filter { !$0.1 }.map { $0.0 }
		var total: Double = 0
		for p in positives {
			for n in negatives {
				if p > n { total += 1 } else if p == n { total += 0.5 }
			}
		}
		let pairs: Double = Double(positives.count * negatives.count)
		return total / pairs
	}

	// MARK: - The identity

	@Test("AUC from the ROC curve equals the Mann-Whitney statistic")
	func aucMatchesMannWhitney() throws {
		var checked = 0
		for (name, data) in [("no ties", Self.noTies), ("with ties", Self.withTies),
							 ("perfect", Self.perfect), ("inverted", Self.inverted)] {
			let evaluation = try #require(ClassifierEvaluation(scores: data.scores,
															   outcomes: data.outcomes))
			let counted: Double = Self.mannWhitneyAUC(data.scores, data.outcomes)
			#expect(Swift.abs(evaluation.auc - counted) < 1e-12,
					"\(name): ROC gives \(evaluation.auc), pair counting gives \(counted)")
			checked += 1
		}
		#expect(checked == 4, "only \(checked) of 4 datasets were compared")
	}

	@Test("The AUC values are the ones an external count produces")
	func aucAgainstReference() throws {
		// Computed outside the library by the pair-counting definition.
		let cases: [(scores: [Double], outcomes: [Bool], auc: Double)] = [
			(Self.noTies.scores, Self.noTies.outcomes, 0.96),
			(Self.withTies.scores, Self.withTies.outcomes, 0.875),
			(Self.perfect.scores, Self.perfect.outcomes, 1.0),
			(Self.inverted.scores, Self.inverted.outcomes, 0.0),
		]
		var checked = 0
		for row in cases {
			let evaluation = try #require(ClassifierEvaluation(scores: row.scores,
															   outcomes: row.outcomes))
			#expect(Swift.abs(evaluation.auc - row.auc) < 1e-12,
					"AUC \(evaluation.auc), expected \(row.auc)")
			checked += 1
		}
		#expect(checked == 4, "only \(checked) of 4 AUC values were checked")
	}

	@Test("Ties are worth half a pair, not none and not one")
	func tiesAreHalfCredit() throws {
		// The whole tied dataset at one score: every pair is tied, so AUC is exactly a
		// half — a coin flip, which is the truthful reading of a model that gave every
		// case the same score.
		let flat = try #require(ClassifierEvaluation(scores: [0.5, 0.5, 0.5, 0.5],
													 outcomes: [true, false, true, false]))
		#expect(Swift.abs(flat.auc - 0.5) < 1e-12, "a constant score scored \(flat.auc)")
	}

	// MARK: - KS

	@Test("The KS statistic is the widest gap between the two rates")
	func kolmogorovSmirnov() throws {
		let cases: [(scores: [Double], outcomes: [Bool], ks: Double)] = [
			(Self.noTies.scores, Self.noTies.outcomes, 0.8),
			(Self.withTies.scores, Self.withTies.outcomes, 0.5),
			(Self.perfect.scores, Self.perfect.outcomes, 1.0),
		]
		var checked = 0
		for row in cases {
			let evaluation = try #require(ClassifierEvaluation(scores: row.scores,
															   outcomes: row.outcomes))
			#expect(Swift.abs(evaluation.ks - row.ks) < 1e-12,
					"KS \(evaluation.ks), expected \(row.ks)")
			#expect(evaluation.ks >= 0 && evaluation.ks <= 1, "KS out of range: \(evaluation.ks)")
			checked += 1
		}
		#expect(checked == 3, "only \(checked) of 3 KS values were checked")
	}

	// MARK: - Confusion matrix

	@Test("The confusion matrix counts what the threshold separates")
	func confusionMatrix() throws {
		let evaluation = try #require(ClassifierEvaluation(scores: Self.noTies.scores,
														   outcomes: Self.noTies.outcomes))
		// At 0.5 the positives are 0.8, 0.7, 0.9 and 0.6 — all genuine — and 0.35 is a
		// positive scored below the threshold.
		let matrix = evaluation.confusionMatrix(threshold: 0.5)
		#expect(matrix.truePositives == 4, "TP \(matrix.truePositives)")
		#expect(matrix.falsePositives == 0, "FP \(matrix.falsePositives)")
		#expect(matrix.falseNegatives == 1, "FN \(matrix.falseNegatives)")
		#expect(matrix.trueNegatives == 5, "TN \(matrix.trueNegatives)")
		#expect(matrix.total == 10, "the counts must partition the data, got \(matrix.total)")

		let recall: Double = matrix.sensitivity
		#expect(Swift.abs(recall - 0.8) < 1e-12, "sensitivity \(recall)")
		#expect(Swift.abs(matrix.specificity - 1.0) < 1e-12, "specificity \(matrix.specificity)")
		#expect(Swift.abs(matrix.precision - 1.0) < 1e-12, "precision \(matrix.precision)")
	}

	@Test("A threshold below every score predicts everything positive")
	func degenerateThresholds() throws {
		let evaluation = try #require(ClassifierEvaluation(scores: Self.noTies.scores,
														   outcomes: Self.noTies.outcomes))
		let all = evaluation.confusionMatrix(threshold: 0)
		#expect(all.truePositives + all.falsePositives == 10, "everything should be positive")
		#expect(all.falseNegatives == 0 && all.trueNegatives == 0)
		let none = evaluation.confusionMatrix(threshold: 2)
		#expect(none.truePositives + none.falsePositives == 0, "nothing should be positive")
	}

	// MARK: - Calibration

	@Test("The Brier score is the mean squared error of the probabilities")
	func brierScore() throws {
		var checked = 0
		for (name, data, wanted) in [("no ties", Self.noTies, 0.1025),
									 ("with ties", Self.withTies, 0.145),
									 ("perfect", Self.perfect, 0.0466666667)] {
			let evaluation = try #require(ClassifierEvaluation(scores: data.scores,
															   outcomes: data.outcomes))
			let curve = evaluation.calibration(buckets: 4)
			#expect(Swift.abs(curve.brierScore - wanted) < 1e-8,
					"\(name): Brier \(curve.brierScore), expected \(wanted)")
			checked += 1
		}
		#expect(checked == 3, "only \(checked) Brier scores were checked")
	}

	@Test("A perfectly calibrated model has a reliability curve on the diagonal")
	func calibrationOnTheDiagonal() throws {
		// Scores that are literally the observed frequency: ten cases at 0.1 of which
		// one is positive, ten at 0.9 of which nine are. A reliability curve is the
		// observed rate against the predicted rate, so this must sit on y = x.
		var scores: [Double] = []
		var outcomes: [Bool] = []
		for index in 0..<10 {
			scores.append(0.1)
			outcomes.append(index < 1)
		}
		for index in 0..<10 {
			scores.append(0.9)
			outcomes.append(index < 9)
		}
		let evaluation = try #require(ClassifierEvaluation(scores: scores, outcomes: outcomes))
		let curve = evaluation.calibration(buckets: 2)
		#expect(curve.points.count == 2, "expected two occupied buckets, got \(curve.points.count)")
		var compared = 0
		for point in curve.points {
			#expect(Swift.abs(point.observedRate - point.predictedRate) < 1e-9,
					"bucket at \(point.predictedRate) observed \(point.observedRate)")
			compared += 1
		}
		#expect(compared == 2, "only \(compared) buckets were compared")
	}

	@Test("Empty buckets are omitted rather than reported as zero")
	func emptyBucketsAreOmitted() throws {
		// Every score sits in the top decile; the other nine buckets have no data, and
		// a reliability point at an observed rate of zero would be a claim about cases
		// that do not exist.
		let evaluation = try #require(ClassifierEvaluation(
			scores: [0.95, 0.96, 0.97, 0.98], outcomes: [true, false, true, true]))
		let curve = evaluation.calibration(buckets: 10)
		#expect(curve.points.count == 1, "got \(curve.points.count) points from one occupied bucket")
	}

	// MARK: - Gains

	@Test("The gains table accumulates to everything, and lift starts above one")
	func gainsTable() throws {
		let evaluation = try #require(ClassifierEvaluation(scores: Self.noTies.scores,
														   outcomes: Self.noTies.outcomes))
		let table = evaluation.gains(buckets: 5)
		#expect(table.rows.count == 5, "got \(table.rows.count) rows")
		let last = try #require(table.rows.last)
		#expect(Swift.abs(last.cumulativeGain - 1.0) < 1e-12,
				"the final bucket must hold every positive, got \(last.cumulativeGain)")
		let first = try #require(table.rows.first)
		#expect(first.lift > 1, "a model better than chance lifts the top bucket, got \(first.lift)")
		// Cumulative gain is non-decreasing by construction.
		var previous: Double = -1
		for row in table.rows {
			#expect(row.cumulativeGain >= previous, "gain fell to \(row.cumulativeGain)")
			previous = row.cumulativeGain
		}
	}

	// MARK: - Refusals

	@Test("Evaluation refuses data it cannot evaluate")
	func refusals() {
		// Mismatched lengths.
		#expect(ClassifierEvaluation(scores: [0.1, 0.2], outcomes: [true]) == nil)
		// Empty.
		#expect(ClassifierEvaluation<Double>(scores: [], outcomes: []) == nil)
		// One class only: AUC is the probability a positive outscores a negative, and
		// with no negatives there are no pairs. Zero pairs is not an AUC of zero.
		#expect(ClassifierEvaluation(scores: [0.1, 0.2, 0.3],
									 outcomes: [true, true, true]) == nil)
		#expect(ClassifierEvaluation(scores: [0.1, 0.2, 0.3],
									 outcomes: [false, false, false]) == nil)
		// A non-finite score has no position in the ordering.
		#expect(ClassifierEvaluation(scores: [0.1, Double.nan, 0.3],
									 outcomes: [true, false, true]) == nil)
	}
}
