//
//  PenalisedLogisticRegressionTests.swift
//  BusinessMath
//
//  The penalised fit: `NLL(β) + (λ/2)·Σ_slopes (β_k − c_k)²`, intercept unpenalised.
//
//  Where the expected values come from (see development-guidelines/rules/correct_answers.md):
//
//  * The reference coefficients were computed outside this library with a BFGS run on the
//    penalised objective (a quasi-Newton route, not the exact-Newton route the
//    implementation takes), to a gradient below 1e-10. The objective is strictly convex for
//    λ > 0, so the optimum is unique and any correct route reaches it.
//  * The stationarity tests do not use a reference at all. The optimum is characterised by
//    its gradient: for every slope `Σ x_ik (y_i − p_i) = λ (β_k − c_k)`, and for the
//    intercept `Σ (y_i − p_i) = 0`. The test computes both sides from the data and the
//    returned coefficients.
//  * The duplicated-column identity is derived on paper: two identical columns with equal
//    coefficients `b` give the same predictor as one column with coefficient `2b`, and cost
//    `λ·b² = (λ/2)/2 · (2b)²` of penalty, so the duplicated fit at λ must predict like the
//    single-column fit at λ/2.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Penalised logistic regression")
struct PenalisedLogisticRegressionTests {

	// MARK: - Fixtures

	/// Not separated: the same ten rows the unpenalised suite fits.
	static let overlapX: [[Double]] = (1...10).map { [Double($0)] }
	static let overlapY: [Bool] = [false, false, false, false, true, false, true, true, true, true]

	/// Six positives in ten, so the base rate is 0.6 and its logit is not zero.
	static let skewedY: [Bool] = [false, false, true, false, true, true, true, true, false, true]

	/// Completely separated by a threshold on the one predictor.
	static let separatedX: [[Double]] = (1...8).map { [Double($0)] }
	static let separatedY: [Bool] = [false, false, false, false, true, true, true, true]

	/// Both sides of the stationarity condition, as the largest absolute difference.
	///
	/// - Returns: the largest absolute value, over every coefficient, of the gradient of the
	///   penalised log-likelihood at `coefficients`.
	static func largestGradient(x: [[Double]], y: [Bool], coefficients: [Double],
								lambda: Double, centre: [Double], intercept: Bool) -> Double {
		let offset: Int = intercept ? 1 : 0
		var gradient = [Double](repeating: 0, count: coefficients.count)
		for row in 0..<x.count {
			var linear: Double = intercept ? coefficients[0] : 0
			for k in 0..<x[row].count {
				let term: Double = coefficients[k + offset] * x[row][k]
				linear += term
			}
			let p: Double = 1 / (1 + Double.exp(-linear))
			let observed: Double = y[row] ? 1 : 0
			let residual: Double = observed - p
			if intercept { gradient[0] += residual }
			for k in 0..<x[row].count {
				let contribution: Double = x[row][k] * residual
				gradient[k + offset] += contribution
			}
		}
		for k in 0..<centre.count {
			let shift: Double = coefficients[k + offset] - centre[k]
			let pull: Double = lambda * shift
			gradient[k + offset] -= pull
		}
		return gradient.map { Swift.abs($0) }.max() ?? .infinity
	}

	// MARK: - Against an independent optimizer

	@Test("A non-separated fit at lambda 1 matches the reference")
	func matchesReferenceOverlap() throws {
		let model = LogisticRegression(predictors: Self.overlapX, outcomes: Self.overlapY)
		let fit = try model.fit(penalty: LogisticPenalty(lambda: 1.0))
		let wanted: [Double] = [-4.980759255586137, 0.9055925919247506]
		#expect(fit.coefficients.count == 2)
		var compared = 0
		for (got, want) in zip(fit.coefficients, wanted) {
			#expect(Swift.abs(got - want) < 1e-7, "coefficient \(got), wanted \(want)")
			compared += 1
		}
		#expect(compared == 2, "only \(compared) of 2 values were compared")
		#expect(Swift.abs(fit.logLikelihood - (-2.661271544762715)) < 1e-7,
				"log-likelihood \(fit.logLikelihood)")
	}

	@Test("A weaker penalty moves toward the unpenalised fit")
	func matchesReferenceWeaker() throws {
		let model = LogisticRegression(predictors: Self.overlapX, outcomes: Self.overlapY)
		let fit = try model.fit(penalty: LogisticPenalty(lambda: 0.1))
		let wanted: [Double] = [-6.723508269055221, 1.2224560489165686]
		for (got, want) in zip(fit.coefficients, wanted) {
			#expect(Swift.abs(got - want) < 1e-6, "coefficient \(got), wanted \(want)")
		}
		let unpenalised = try model.fit()
		let slopeGap: Double = Swift.abs(fit.coefficients[1] - unpenalised.coefficients[1])
		let strongerGap: Double = Swift.abs(
			(try model.fit(penalty: LogisticPenalty(lambda: 1.0))).coefficients[1]
				- unpenalised.coefficients[1])
		#expect(slopeGap < strongerGap, "the weaker penalty must sit closer to the unpenalised slope")
	}

	@Test("A non-zero centre pulls the slope toward the centre, matching the reference")
	func matchesReferenceCentre() throws {
		let model = LogisticRegression(predictors: Self.overlapX, outcomes: Self.overlapY)
		let fit = try model.fit(penalty: LogisticPenalty(lambda: 1.0, centre: [1.0]))
		let wanted: [Double] = [-6.523010026464477, 1.1860018229935176]
		for (got, want) in zip(fit.coefficients, wanted) {
			#expect(Swift.abs(got - want) < 1e-6, "coefficient \(got), wanted \(want)")
		}
		let centred = fit.coefficients[1]
		let zeroCentred = try model.fit(penalty: LogisticPenalty(lambda: 1.0)).coefficients[1]
		#expect(centred > zeroCentred, "a centre above the fit must raise the slope")
	}

	// MARK: - The characterisation of the optimum

	@Test("The returned coefficients satisfy the penalised score equations")
	func stationarity() throws {
		let x: [[Double]] = [[1, 5], [2, 3], [3, 8], [4, 2], [5, 7], [6, 4],
							 [7, 9], [8, 1], [9, 6], [10, 10], [2, 9], [7, 2]]
		let y: [Bool] = [false, false, false, false, true, false,
						 true, false, true, true, false, true]
		let model = LogisticRegression(predictors: x, outcomes: y)
		var checked = 0
		for lambda in [0.01, 0.5, 3.0, 40.0] {
			for centre in [[0.0, 0.0], [0.7, -0.3]] {
				let fit = try model.fit(penalty: LogisticPenalty(lambda: lambda, centre: centre))
				let residual = Self.largestGradient(x: x, y: y, coefficients: fit.coefficients,
													lambda: lambda, centre: centre, intercept: true)
				#expect(residual < 1e-6, "lambda \(lambda), centre \(centre): gradient \(residual)")
				checked += 1
			}
		}
		#expect(checked == 8)
	}

	@Test("The intercept is not penalised: fitted probabilities average to the observed rate")
	func interceptUnpenalised() throws {
		let model = LogisticRegression(predictors: Self.overlapX, outcomes: Self.skewedY)
		for lambda in [0.1, 5.0, 1000.0] {
			let fit = try model.fit(penalty: LogisticPenalty(lambda: lambda))
			var total: Double = 0
			for row in Self.overlapX { total += fit.probability(row) }
			let mean: Double = total / Double(Self.overlapX.count)
			#expect(Swift.abs(mean - 0.6) < 1e-8, "lambda \(lambda): mean fitted probability \(mean)")
		}
	}

	@Test("An enormous penalty leaves the slopes at the centre and the intercept at the base-rate logit")
	func enormousPenalty() throws {
		let model = LogisticRegression(predictors: Self.overlapX, outcomes: Self.skewedY)
		let fit = try model.fit(penalty: LogisticPenalty(lambda: 1e9, centre: [0.25]))
		#expect(Swift.abs(fit.coefficients[1] - 0.25) < 1e-6, "slope \(fit.coefficients[1])")

		let flat = try model.fit(penalty: LogisticPenalty(lambda: 1e9))
		let baseRateLogit: Double = Double.log(0.6 / 0.4)
		#expect(Swift.abs(flat.coefficients[1]) < 1e-6, "slope \(flat.coefficients[1])")
		#expect(Swift.abs(flat.coefficients[0] - baseRateLogit) < 1e-6,
				"intercept \(flat.coefficients[0]), wanted \(baseRateLogit)")
	}

	@Test("The reported objective is the log-likelihood minus the penalty, and the optimum beats its neighbours")
	func objectiveIsConsistent() throws {
		let model = LogisticRegression(predictors: Self.overlapX, outcomes: Self.overlapY)
		let lambda = 2.0
		let centre = [0.5]
		let fit = try model.fit(penalty: LogisticPenalty(lambda: lambda, centre: centre))
		let shift: Double = fit.coefficients[1] - 0.5
		let penalty: Double = 0.5 * lambda * shift * shift
		let wanted: Double = fit.logLikelihood - penalty
		#expect(Swift.abs(fit.penalisedObjective - wanted) < 1e-10,
				"objective \(fit.penalisedObjective), wanted \(wanted)")

		// Concavity: no nearby point does better, which is what makes this the maximum.
		func objective(_ b0: Double, _ b1: Double) -> Double {
			var total: Double = 0
			for (row, outcome) in zip(Self.overlapX, Self.overlapY) {
				let linear: Double = b0 + b1 * row[0]
				let observed: Double = outcome ? 1 : 0
				total += observed * linear - Double.log(1 + Double.exp(linear))
			}
			let moved: Double = b1 - 0.5
			let cost: Double = 0.5 * lambda * moved * moved
			return total - cost
		}
		let here = objective(fit.coefficients[0], fit.coefficients[1])
		var worse = 0
		for (d0, d1) in [(0.01, 0.0), (-0.01, 0.0), (0.0, 0.01), (0.0, -0.01), (0.01, 0.01), (-0.01, -0.01)] {
			if objective(fit.coefficients[0] + d0, fit.coefficients[1] + d1) < here { worse += 1 }
		}
		#expect(worse == 6, "only \(worse) of 6 neighbours were worse")
	}

	// MARK: - Separation: the case the unpenalised fit refuses

	@Test("Separated data is refused by the unpenalised fit and fitted, finitely, by the penalised one")
	func separationFitted() throws {
		let model = LogisticRegression(predictors: Self.separatedX, outcomes: Self.separatedY)
		#expect(throws: LogisticRegressionError.self) { try model.fit() }

		let fit = try model.fit(penalty: LogisticPenalty(lambda: 1.0))
		let wanted: [Double] = [-5.263947796974564, 1.1697661771053738]
		for (got, want) in zip(fit.coefficients, wanted) {
			#expect(got.isFinite)
			#expect(Swift.abs(got - want) < 1e-6, "coefficient \(got), wanted \(want)")
		}
		let weaker = try model.fit(penalty: LogisticPenalty(lambda: 0.1))
		let weakerWanted: [Double] = [-12.046345095863714, 2.67696557685767]
		for (got, want) in zip(weaker.coefficients, weakerWanted) {
			#expect(Swift.abs(got - want) < 1e-5, "coefficient \(got), wanted \(want)")
		}
		#expect(weaker.coefficients[1] > fit.coefficients[1],
				"a weaker penalty must allow a larger slope on separated data")
	}

	@Test("On separated data the penalised slope is finite and ordered across a wide range of lambda")
	func separationMonotone() throws {
		let model = LogisticRegression(predictors: Self.separatedX, outcomes: Self.separatedY)
		var previous: Double = .infinity
		var steps = 0
		for lambda in [1e-3, 1e-2, 1e-1, 1.0, 10.0, 100.0] {
			let slope = try model.fit(penalty: LogisticPenalty(lambda: lambda, centre: [0.0])).coefficients[1]
			#expect(slope.isFinite && slope > 0, "lambda \(lambda): slope \(slope)")
			#expect(slope < previous, "slope must shrink as lambda grows; lambda \(lambda): \(slope) after \(previous)")
			previous = slope
			steps += 1
		}
		#expect(steps == 6)
	}

	@Test("A constant outcome with an intercept still has no maximum, because the intercept is unpenalised")
	func constantOutcomeWithIntercept() {
		let model = LogisticRegression(predictors: [[1], [2], [3], [4]],
									   outcomes: [true, true, true, true])
		#expect(throws: LogisticRegressionError.separation(variables: [])) {
			try model.fit(penalty: LogisticPenalty(lambda: 1.0))
		}
	}

	@Test("A constant outcome without an intercept has a finite penalised fit")
	func constantOutcomeWithoutIntercept() throws {
		let model = LogisticRegression(predictors: [[1], [2], [3], [4]],
									   outcomes: [true, true, true, true], intercept: false)
		let fit = try model.fit(penalty: LogisticPenalty(lambda: 1.0))
		#expect(fit.coefficients.count == 1)
		#expect(fit.coefficients[0].isFinite && fit.coefficients[0] > 0)
		let residual = Self.largestGradient(x: [[1], [2], [3], [4]], y: [true, true, true, true],
											coefficients: fit.coefficients, lambda: 1.0,
											centre: [0], intercept: false)
		#expect(residual < 1e-6, "gradient \(residual)")
	}

	// MARK: - Rank deficiency

	@Test("A duplicated column is fitted, and predicts like the single column at half the penalty")
	func duplicatedColumn() throws {
		let single = Self.overlapX
		let doubled: [[Double]] = Self.overlapX.map { [$0[0], $0[0]] }
		let unpenalisedDoubled = LogisticRegression(predictors: doubled, outcomes: Self.overlapY)
		#expect(throws: LogisticRegressionError.self) { try unpenalisedDoubled.fit() }

		let lambda = 2.0
		let both = try unpenalisedDoubled.fit(penalty: LogisticPenalty(lambda: lambda))
		let one = try LogisticRegression(predictors: single, outcomes: Self.overlapY)
			.fit(penalty: LogisticPenalty(lambda: lambda / 2))
		#expect(Swift.abs(both.coefficients[1] - both.coefficients[2]) < 1e-8,
				"the ridge must split the effect equally between identical columns")
		var compared = 0
		for row in single {
			let a: Double = both.probability([row[0], row[0]])
			let b: Double = one.probability(row)
			#expect(Swift.abs(a - b) < 1e-8, "doubled \(a), single at half the penalty \(b)")
			compared += 1
		}
		#expect(compared == 10)
	}

	@Test("More predictors than observations is identified by the penalty")
	func wide() throws {
		let x: [[Double]] = [[1, 0, 2, 1, 0], [0, 1, 1, 0, 3], [2, 2, 0, 1, 1], [1, 3, 1, 2, 0]]
		let y: [Bool] = [true, false, true, false]
		let model = LogisticRegression(predictors: x, outcomes: y)
		#expect(throws: LogisticRegressionError.self) { try model.fit() }
		let fit = try model.fit(penalty: LogisticPenalty(lambda: 1.0))
		#expect(fit.coefficients.count == 6)
		let residual = Self.largestGradient(x: x, y: y, coefficients: fit.coefficients, lambda: 1.0,
											centre: [0, 0, 0, 0, 0], intercept: true)
		#expect(residual < 1e-6, "gradient \(residual)")
	}

	// MARK: - Validation

	@Test("A penalty that is not positive and finite is refused")
	func badLambda() {
		let model = LogisticRegression(predictors: Self.overlapX, outcomes: Self.overlapY)
		var refused = 0
		for lambda in [0.0, -1.0, Double.nan, Double.infinity] {
			do {
				_ = try model.fit(penalty: LogisticPenalty(lambda: lambda))
			} catch LogisticRegressionError.malformedInput {
				refused += 1
			} catch {
				Issue.record("lambda \(lambda): wrong error \(error)")
			}
		}
		#expect(refused == 4, "only \(refused) of 4 bad penalties were refused")
	}

	@Test("A centre of the wrong width, or not finite, is refused")
	func badCentre() {
		let model = LogisticRegression(predictors: Self.overlapX, outcomes: Self.overlapY)
		var refused = 0
		for centre in [[0.0, 0.0], [], [Double.nan]] {
			do {
				_ = try model.fit(penalty: LogisticPenalty(lambda: 1.0, centre: centre))
			} catch LogisticRegressionError.malformedInput {
				refused += 1
			} catch {
				Issue.record("centre \(centre): wrong error \(error)")
			}
		}
		#expect(refused == 3, "only \(refused) of 3 bad centres were refused")
	}

	@Test("Malformed data is refused as the unpenalised fit refuses it")
	func malformedData() {
		let penalty = LogisticPenalty<Double>(lambda: 1.0)
		var refused = 0
		let models: [LogisticRegression<Double>] = [
			LogisticRegression(predictors: [], outcomes: []),
			LogisticRegression(predictors: [[1], [2]], outcomes: [true]),
			LogisticRegression(predictors: [[1], [2, 3], [4]], outcomes: [true, false, true]),
			LogisticRegression(predictors: [[1], [Double.nan], [3]], outcomes: [true, false, true]),
			LogisticRegression(predictors: [[], [], []], outcomes: [true, false, true], intercept: false)
		]
		for model in models {
			do {
				_ = try model.fit(penalty: penalty)
			} catch LogisticRegressionError.malformedInput {
				refused += 1
			} catch {
				Issue.record("wrong error \(error)")
			}
		}
		#expect(refused == 5, "only \(refused) of 5 malformed inputs were refused")
	}

	@Test("An exhausted iteration budget is reported, not returned as a fit")
	func didNotConverge() {
		let model = LogisticRegression(predictors: Self.separatedX, outcomes: Self.separatedY)
		#expect(throws: LogisticRegressionError.self) {
			try model.fit(penalty: LogisticPenalty(lambda: 1e-9), maxIterations: 2)
		}
	}

	// MARK: - Behaviour of the result

	@Test("Probabilities are inside (0, 1), and a wrong-width argument returns one half")
	func probabilityBehaviour() throws {
		let fit = try LogisticRegression(predictors: Self.overlapX, outcomes: Self.overlapY)
			.fit(penalty: LogisticPenalty(lambda: 1.0))
		for value in [-100.0, 0.0, 5.0, 100.0] {
			let p = fit.probability([value])
			#expect(p >= 0 && p <= 1, "p \(p)")
			#expect(p.isFinite)
		}
		let wrongWidth: Double = fit.probability([1.0, 2.0])
		#expect(Swift.abs(wrongWidth - 0.5) < 1e-12, "a wrong-width argument returned \(wrongWidth)")
		#expect(fit.hasIntercept)
		let low = fit.probability([1.0])
		let high = fit.probability([10.0])
		#expect(high > low, "a positive slope must raise the probability")
	}

	@Test("Fitting twice gives identical results")
	func deterministic() throws {
		let model = LogisticRegression(predictors: Self.overlapX, outcomes: Self.overlapY)
		let first = try model.fit(penalty: LogisticPenalty(lambda: 0.7, centre: [0.2]))
		let second = try model.fit(penalty: LogisticPenalty(lambda: 0.7, centre: [0.2]))
		#expect(first.coefficients == second.coefficients)
		#expect(first.iterations == second.iterations)
	}

	@Test("The same fit in single precision agrees with double precision")
	func floatAgrees() throws {
		let doubleFit = try LogisticRegression(predictors: Self.overlapX, outcomes: Self.overlapY)
			.fit(penalty: LogisticPenalty(lambda: 1.0))
		let floatX: [[Float]] = Self.overlapX.map { $0.map { Float($0) } }
		let floatFit = try LogisticRegression(predictors: floatX, outcomes: Self.overlapY)
			.fit(penalty: LogisticPenalty<Float>(lambda: 1.0), tolerance: 1e-5)
		for (single, double) in zip(floatFit.coefficients, doubleFit.coefficients) {
			let gap: Double = Swift.abs(Double(single) - double)
			#expect(gap < 1e-3, "Float \(single), Double \(double)")
		}
	}

	@Test("The result and the penalty round-trip through JSON")
	func codable() throws {
		let fit = try LogisticRegression(predictors: Self.overlapX, outcomes: Self.overlapY)
			.fit(penalty: LogisticPenalty(lambda: 1.0, centre: [0.1]))
		let data = try JSONEncoder().encode(fit)
		let back = try JSONDecoder().decode(PenalisedLogisticFit<Double>.self, from: data)
		#expect(back.coefficients == fit.coefficients)
		#expect(back.penalty == fit.penalty)
		#expect(Swift.abs(back.penalty.lambda - 1.0) < 1e-12)
		let centre: [Double] = back.penalty.centre ?? []
		#expect(centre.count == 1 && Swift.abs(centre[0] - 0.1) < 1e-12, "centre \(centre)")
	}

	@Test("Without an intercept every coefficient is penalised and probability reads the whole row")
	func noIntercept() throws {
		let x: [[Double]] = [[1, 2], [2, 1], [3, 5], [4, 3], [5, 6], [6, 2]]
		let y: [Bool] = [false, false, true, false, true, true]
		let fit = try LogisticRegression(predictors: x, outcomes: y, intercept: false)
			.fit(penalty: LogisticPenalty(lambda: 1.0, centre: [0.1, -0.1]))
		#expect(fit.coefficients.count == 2)
		#expect(!fit.hasIntercept)
		let residual = Self.largestGradient(x: x, y: y, coefficients: fit.coefficients, lambda: 1.0,
											centre: [0.1, -0.1], intercept: false)
		#expect(residual < 1e-6, "gradient \(residual)")
	}

	// MARK: - The existing fit is untouched

	@Test("The unpenalised fit still returns its documented reference values")
	func existingFitUnchanged() throws {
		let fit = try LogisticRegression(predictors: Self.overlapX, outcomes: Self.overlapY).fit()
		#expect(Swift.abs(fit.coefficients[0] - (-7.1590107413)) < 1e-6)
		#expect(Swift.abs(fit.coefficients[1] - 1.3016383086) < 1e-6)
		#expect(fit.standardErrors.count == 2)
	}
}
