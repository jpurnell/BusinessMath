//
//  Uplift.swift
//  BusinessMath
//

import Foundation
import Numerics

/// How an incremental effect is estimated.
public enum UpliftMethod: Sendable, Equatable, CaseIterable {

	/// Fit the treated and the control arm separately; uplift is the difference in
	/// fitted probability. Works under any allocation, and costs two fits.
	case twoModel

	/// Fit one model to the transformed outcome `z = (treated == responded)`; uplift is
	/// `2p − 1`. One fit, and it estimates the difference directly rather than as a
	/// residue of two larger numbers — but the identity holds only where treatment is
	/// allocated at one half.
	case classTransformation
}

/// Which arm of an experiment.
public enum UpliftArm: Sendable, Equatable, CaseIterable {
	case treatment
	case control
}

/// Why an uplift model could not be built.
public enum UpliftError: Error, Sendable, Equatable {

	/// The inputs do not describe an experiment.
	case malformedInput(reason: String)

	/// One arm has nobody in it, so there is no counterfactual to difference against.
	case emptyArm(treated: Int, control: Int)

	/// Class transformation was asked for on a design that is not near one-half treated.
	case unbalancedAllocation(treatedShare: Double)

	/// An arm's regression refused. The arm is named so the other one is not blamed.
	case arm(UpliftArm, LogisticRegressionError)

	/// The transformed-outcome regression refused.
	case transformation(LogisticRegressionError)
}

/// One bucket of a ranked uplift table: what was predicted, and what each arm did.
public struct UpliftBucket<T: Real & Sendable>: Sendable {

	/// Which bucket, counting from one, best predicted uplift first.
	public let bucket: Int

	/// Subjects in the bucket.
	public let count: Int

	/// How many of them were treated.
	public let treatedCount: Int

	/// How many were control.
	public let controlCount: Int

	/// Response rate among the treated here.
	public let treatedRate: T

	/// Response rate among the control here.
	public let controlRate: T

	/// What the arms actually differed by — the number the model is judged against.
	public let observedUplift: T

	/// Mean predicted uplift in the bucket.
	public let predictedUplift: T

	/// Creates a bucket.
	///
	/// - Parameters:
	///   - bucket: Which bucket, counting from one.
	///   - count: Subjects in it.
	///   - treatedCount: How many were treated.
	///   - controlCount: How many were control.
	///   - treatedRate: Response rate among the treated.
	///   - controlRate: Response rate among the control.
	///   - observedUplift: The difference between those rates.
	///   - predictedUplift: Mean predicted uplift.
	public init(bucket: Int, count: Int, treatedCount: Int, controlCount: Int,
				treatedRate: T, controlRate: T, observedUplift: T, predictedUplift: T) {
		self.bucket = bucket
		self.count = count
		self.treatedCount = treatedCount
		self.controlCount = controlCount
		self.treatedRate = treatedRate
		self.controlRate = controlRate
		self.observedUplift = observedUplift
		self.predictedUplift = predictedUplift
	}
}

/// Who is *moved* by a treatment, as distinct from who responds to it.
///
/// ```swift
/// let x: [[Double]] = [[0], [0], [0], [0], [0], [0], [1], [1], [1], [1], [1], [1]]
/// let treated: [Bool] = [true, true, true, false, false, false,
///                        true, true, true, false, false, false]
/// let responded: [Bool] = [true, false, false, true, false, false,
///                          true, true, false, true, false, false]
/// let model = try UpliftModel(predictors: x, treated: treated, responded: responded,
///                             method: .twoModel)
/// if let effect = model.uplift([1]) { print(effect) }
/// ```
///
/// ## Why a response model is not this
///
/// A response model ranks who will respond under treatment. An uplift model ranks who
/// responds **because of** it, and the two rankings can be nearly opposite. The customers
/// who would have bought anyway score highest on response and zero on uplift; contacting
/// them spends money to change nothing. And uplift can be *negative* — a contact that
/// annoys someone out of a purchase they would otherwise have made. A response model
/// cannot represent that case at all, because it never sees the counterfactual.
///
/// This is the clearest place in the marketing surface where a well-behaved,
/// well-calibrated model answers a question nobody asked. Both methods here need a
/// control arm, and both refuse without one.
///
/// ## Choosing a method
///
/// ``UpliftMethod/twoModel`` fits each arm and differences the fitted probabilities. It
/// works under any allocation. Its weakness is structural: uplift is usually small
/// relative to the response rates, so it is a difference of two larger numbers, and each
/// arm's model is fitted to predict response rather than to predict the difference.
///
/// ``UpliftMethod/classTransformation`` — Lai's transform — fits one model to
/// `z = (treated == responded)`, which is `1` for a treated responder or an untreated
/// non-responder. Where treatment is allocated at one half,
/// `P(z = 1 | x) = (r_T(x) + 1 − r_C(x)) / 2`, so `2p − 1` recovers `r_T(x) − r_C(x)`
/// directly. Away from one half that identity is simply false: the transform still
/// returns numbers in [−1, 1] that read as uplifts, biased toward the treated arm's
/// response rate, with nothing in the output recording the design. This refuses rather
/// than returns them; the remedy is inverse-propensity reweighting, which is not
/// implemented here.
///
/// On a balanced design with a saturated model the two methods are algebraically the same
/// number, which is the identity the tests are built on.
public struct UpliftModel<T: Real & Sendable & Codable & BinaryFloatingPoint>: Sendable {

	/// How uplift was estimated.
	public let method: UpliftMethod

	/// The predictor rows.
	public let predictors: [[T]]

	/// Whether each subject was treated.
	public let treated: [Bool]

	/// Whether each subject responded.
	public let responded: [Bool]

	/// How wide a row must be, excluding any intercept.
	public let predictorCount: Int

	/// Share of subjects in the treatment arm.
	public let treatedShare: T

	/// The observed difference in response rates, model-free.
	///
	/// Under randomisation this is the average treatment effect, and it is the number a
	/// model's average prediction should reproduce.
	public let averageTreatmentEffect: T

	/// The treated arm's fit, for ``UpliftMethod/twoModel``.
	public let treatmentFit: LogisticFit<T>?

	/// The control arm's fit, for ``UpliftMethod/twoModel``.
	public let controlFit: LogisticFit<T>?

	/// The transformed-outcome fit, for ``UpliftMethod/classTransformation``.
	public let transformedFit: LogisticFit<T>?

	/// Fits an uplift model.
	///
	/// - Parameters:
	///   - predictors: One row per subject, all rows the same width.
	///   - treated: Whether each subject was in the treatment arm.
	///   - responded: Whether each subject responded.
	///   - method: How to estimate the effect.
	///   - intercept: Whether to fit an intercept. Defaults to `true`.
	///   - balanceTolerance: How far from one half the treated share may sit before
	///     ``UpliftMethod/classTransformation`` refuses. Defaults to five points. Ignored
	///     by ``UpliftMethod/twoModel``, which has no balance requirement.
	///   - maxIterations: Newton steps allowed per fit.
	///   - tolerance: Convergence threshold on the largest coefficient change.
	/// - Throws: ``UpliftError``.
	public init(predictors: [[T]],
				treated: [Bool],
				responded: [Bool],
				method: UpliftMethod,
				intercept: Bool = true,
				balanceTolerance: T = T(5) / T(100),
				maxIterations: Int = 25,
				tolerance: T = T(1) / T(100_000_000)) throws {
		guard !predictors.isEmpty else {
			throw UpliftError.malformedInput(reason: "no observations")
		}
		guard predictors.count == treated.count, predictors.count == responded.count else {
			throw UpliftError.malformedInput(
				reason: "\(predictors.count) rows, \(treated.count) arms, \(responded.count) outcomes")
		}
		let width = predictors[0].count
		guard predictors.allSatisfy({ $0.count == width }) else {
			throw UpliftError.malformedInput(reason: "rows are not all \(width) wide")
		}
		let treatedCount = treated.filter { $0 }.count
		let controlCount = treated.count - treatedCount
		guard treatedCount > 0, controlCount > 0 else {
			throw UpliftError.emptyArm(treated: treatedCount, control: controlCount)
		}

		var treatmentRows: [[T]] = []
		var treatmentOutcomes: [Bool] = []
		var controlRows: [[T]] = []
		var controlOutcomes: [Bool] = []
		var treatmentResponses = 0
		var controlResponses = 0
		for index in 0..<predictors.count {
			if treated[index] {
				treatmentRows.append(predictors[index])
				treatmentOutcomes.append(responded[index])
				if responded[index] { treatmentResponses += 1 }
			} else {
				controlRows.append(predictors[index])
				controlOutcomes.append(responded[index])
				if responded[index] { controlResponses += 1 }
			}
		}

		let share: T = T(treatedCount) / T(treated.count)
		let treatmentRate: T = T(treatmentResponses) / T(treatedCount)
		let controlRate: T = T(controlResponses) / T(controlCount)

		switch method {
		case .twoModel:
			self.treatmentFit = try Self.fit(.treatment, rows: treatmentRows,
											 outcomes: treatmentOutcomes, intercept: intercept,
											 maxIterations: maxIterations, tolerance: tolerance)
			self.controlFit = try Self.fit(.control, rows: controlRows,
										   outcomes: controlOutcomes, intercept: intercept,
										   maxIterations: maxIterations, tolerance: tolerance)
			self.transformedFit = nil
		case .classTransformation:
			let half: T = T(1) / T(2)
			let deviation: T = share > half ? share - half : half - share
			guard deviation <= balanceTolerance else {
				throw UpliftError.unbalancedAllocation(treatedShare: Double(share))
			}
			// z is one for a treated responder and for an untreated non-responder, which
			// is exactly "the arm and the outcome agree".
			var transformed: [Bool] = []
			for index in 0..<responded.count {
				transformed.append(treated[index] == responded[index])
			}
			let regression = LogisticRegression(predictors: predictors,
												outcomes: transformed,
												intercept: intercept)
			do {
				self.transformedFit = try regression.fit(maxIterations: maxIterations,
														 tolerance: tolerance)
			} catch let error as LogisticRegressionError {
				throw UpliftError.transformation(error)
			}
			self.treatmentFit = nil
			self.controlFit = nil
		}

		self.method = method
		self.predictors = predictors
		self.treated = treated
		self.responded = responded
		self.predictorCount = width
		self.treatedShare = share
		self.averageTreatmentEffect = treatmentRate - controlRate
	}

	/// Fits one arm, naming it if the regression refuses.
	static func fit(_ arm: UpliftArm, rows: [[T]], outcomes: [Bool], intercept: Bool,
					maxIterations: Int, tolerance: T) throws -> LogisticFit<T> {
		let regression = LogisticRegression(predictors: rows, outcomes: outcomes,
											intercept: intercept)
		do {
			return try regression.fit(maxIterations: maxIterations, tolerance: tolerance)
		} catch let error as LogisticRegressionError {
			throw UpliftError.arm(arm, error)
		}
	}

	/// The estimated effect of treating this subject.
	///
	/// - Parameter predictors: One value per predictor, of width ``predictorCount``.
	/// - Returns: A number in [−1, 1], negative where the treatment costs responses. `nil`
	///   for a row of the wrong width — the layer below answers a mis-shaped row with one
	///   half, which differences to an uplift of exactly zero and reads as "the treatment
	///   does nothing", a substantive claim the data never made.
	public func uplift(_ predictors: [T]) -> T? {
		guard predictors.count == predictorCount else { return nil }
		switch method {
		case .twoModel:
			guard let treatment = treatmentFit, let control = controlFit else { return nil }
			let treatedProbability: T = treatment.probability(predictors)
			let controlProbability: T = control.probability(predictors)
			return treatedProbability - controlProbability
		case .classTransformation:
			guard let transformed = transformedFit else { return nil }
			let p: T = transformed.probability(predictors)
			let doubled: T = p * 2
			return doubled - 1
		}
	}

	/// Uplift for a population, or `nil` if the population is not scoreable.
	///
	/// - Parameter population: One row per subject, each of width ``predictorCount``.
	/// - Returns: One estimate per row, in order, or `nil` for an empty population or any
	///   row of the wrong width.
	public func upliftScores(_ population: [[T]]) -> [T]? {
		guard !population.isEmpty else { return nil }
		var scores: [T] = []
		for row in population {
			guard let value = uplift(row) else { return nil }
			scores.append(value)
		}
		return scores
	}

	/// The training cohort ranked by predicted uplift and split into buckets.
	///
	/// This is how an uplift model is validated and how it is used. Each bucket reports
	/// what was predicted and what the two arms actually did, and a model that ranks
	/// correctly produces observed uplift that falls across the table.
	///
	/// Ties are broken by original position, so the table is deterministic.
	///
	/// - Parameter buckets: How many buckets. Must be positive and no more than the
	///   cohort size.
	/// - Returns: The buckets, best predicted uplift first, or `nil` when any bucket ends
	///   up with an empty arm. A bucket with no controls has a control rate of zero over
	///   zero; score that as zero and its uplift becomes the full treated response rate —
	///   the largest number in the table, sitting in the bucket you were about to target.
	///   Ask for fewer buckets.
	public func upliftByBucket(buckets: Int) -> [UpliftBucket<T>]? {
		guard buckets > 0, buckets <= predictors.count else { return nil }
		guard let scores = upliftScores(predictors) else { return nil }
		let order = (0..<scores.count).sorted { left, right in
			if scores[left] == scores[right] { return left < right }
			return scores[left] > scores[right]
		}

		var table: [UpliftBucket<T>] = []
		var start = 0
		for slot in 0..<buckets {
			let reach = (slot + 1) * scores.count
			let end = reach / buckets
			guard end > start else { return nil }

			var treatedCount = 0
			var controlCount = 0
			var treatedResponses = 0
			var controlResponses = 0
			var predictedTotal: T = T.zero
			for position in start..<end {
				let index = order[position]
				predictedTotal += scores[index]
				if treated[index] {
					treatedCount += 1
					if responded[index] { treatedResponses += 1 }
				} else {
					controlCount += 1
					if responded[index] { controlResponses += 1 }
				}
			}
			guard treatedCount > 0, controlCount > 0 else { return nil }

			let treatedRate: T = T(treatedResponses) / T(treatedCount)
			let controlRate: T = T(controlResponses) / T(controlCount)
			let observed: T = treatedRate - controlRate
			let size = end - start
			let predicted: T = predictedTotal / T(size)
			table.append(UpliftBucket(bucket: slot + 1, count: size,
									  treatedCount: treatedCount, controlCount: controlCount,
									  treatedRate: treatedRate, controlRate: controlRate,
									  observedUplift: observed, predictedUplift: predicted))
			start = end
		}
		return table
	}
}
