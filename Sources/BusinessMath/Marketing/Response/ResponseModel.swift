//
//  ResponseModel.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Who is likely to respond, and whether contacting them pays.
///
/// ```swift
/// let spend: [[Double]] = [[10], [20], [30], [40], [50], [60],
///                          [70], [80], [90], [100], [110], [120]]
/// let responded: [Bool] = [false, true, false, false, true, false,
///                          true, true, false, true, true, true]
/// let model = try ResponseModel(predictors: spend, responded: responded)
/// print(model.propensity([95]), model.lift([95]))
/// print(model.shouldContact([95], contactCost: 2, marginPerResponse: 50))
/// ```
///
/// ## What this adds to the regression underneath
///
/// The fit is a plain binomial GLM and lives in ``LogisticRegression``; a response model
/// is that fit plus the three things a campaign needs and a regression has no opinion
/// about.
///
/// **A baseline.** A propensity of 0.31 is good news or bad depending on the cohort it
/// came from. ``lift(_:)`` divides by the observed response rate, so 1.0 means "no better
/// than mailing at random" — the only reading of a propensity that survives being quoted
/// out of context.
///
/// **A threshold.** ``breakEvenPropensity(contactCost:marginPerResponse:)`` is
/// `cost / margin`: below it a contact loses money in expectation, above it a contact
/// makes money. This is the individual-level decision, and it is the dual of the
/// bucket-level one that ``optimalCampaignDepth(gains:contactCost:marginPerResponse:population:)``
/// answers. Both need the two numbers no model contains — what a response is worth and
/// what a contact costs.
///
/// **A refusal on scoring.** ``LogisticFit/probability(_:)`` returns one half when handed
/// a row of the wrong width, because a probability is its return type and it has nowhere
/// to put an error. Scoring a mis-shaped population that way yields a column of
/// well-formed numbers that ranks nobody. ``score(_:)`` returns `nil`.
///
/// ## In-sample evaluation is optimistic, and says so
///
/// ``inSampleEvaluation`` and ``inSampleGains(buckets:)`` score the data the model was
/// fitted on. Their AUC is biased upward — the model has seen every one of these
/// outcomes — and the bias grows with the number of predictors. They are here because
/// checking a model against its own training data catches the gross failures cheaply,
/// not because the number is an estimate of field performance. For that, fit on one part
/// of the cohort and build a ``ClassifierEvaluation`` on the other.
public struct ResponseModel<T: Real & Sendable & Codable & BinaryFloatingPoint>: Sendable {

	/// The fitted regression.
	public let fit: LogisticFit<T>

	/// The cohort's observed response rate, strictly inside (0, 1).
	public let baselineRate: T

	/// The predictor rows the model was fitted on.
	public let predictors: [[T]]

	/// The responses those rows produced.
	public let responded: [Bool]

	/// How many predictors a row must carry, excluding any intercept.
	public var predictorCount: Int {
		let offset = fit.hasIntercept ? 1 : 0
		return fit.coefficients.count - offset
	}

	/// Fits a response model.
	///
	/// - Parameters:
	///   - predictors: One row per prospect, all rows the same width. An empty row per
	///     prospect fits an intercept alone, whose propensity is the response rate.
	///   - responded: Whether each prospect responded.
	///   - intercept: Whether to fit an intercept. Defaults to `true`, and leaving it on
	///     is what makes ``baselineRate`` the average of the fitted propensities.
	///   - maxIterations: Newton steps allowed.
	///   - tolerance: Convergence threshold on the largest coefficient change.
	/// - Throws: ``LogisticRegressionError``. Separation is the one to expect: a
	///   predictor that splits responders from non-responders perfectly has no finite
	///   coefficient, and the enormous one an unguarded optimizer returns comes with a
	///   perfect in-sample AUC and no predictive validity at all.
	public init(predictors: [[T]],
				responded: [Bool],
				intercept: Bool = true,
				maxIterations: Int = 25,
				tolerance: T = T(1) / T(100_000_000)) throws {
		let regression = LogisticRegression(predictors: predictors,
											outcomes: responded,
											intercept: intercept)
		let fitted = try regression.fit(maxIterations: maxIterations, tolerance: tolerance)
		let positives: T = T(responded.filter { $0 }.count)
		let rate: T = positives / T(responded.count)
		// The regression refuses a constant outcome as separation, so a rate of exactly
		// zero or one cannot reach here. Establishing it anyway is what lets `lift(_:)`
		// divide without a guard of its own.
		guard rate > T.zero, rate < T(1) else {
			throw LogisticRegressionError.separation(variables: [])
		}
		self.fit = fitted
		self.baselineRate = rate
		self.predictors = predictors
		self.responded = responded
	}

	/// The probability this prospect responds.
	///
	/// - Parameter predictors: One value per predictor, of width ``predictorCount``.
	/// - Returns: A probability strictly inside (0, 1).
	public func propensity(_ predictors: [T]) -> T {
		fit.probability(predictors)
	}

	/// Propensity relative to the cohort's response rate.
	///
	/// - Parameter predictors: One value per predictor.
	/// - Returns: One when this prospect is no better than average, two when they are
	///   twice as likely to respond. The average of this over the training cohort is
	///   exactly one whenever the fit has an intercept.
	public func lift(_ predictors: [T]) -> T {
		let p: T = propensity(predictors)
		return p / baselineRate
	}

	/// Propensities for a population, or `nil` if the population is not scoreable.
	///
	/// - Parameter population: One row per prospect, each of width ``predictorCount``.
	/// - Returns: One propensity per row, in order. `nil` for an empty population or any
	///   row of the wrong width — a mis-shaped table scored row by row comes back as a
	///   column of one halves, which ranks nobody while looking entirely normal.
	public func score(_ population: [[T]]) -> [T]? {
		guard !population.isEmpty else { return nil }
		let width = predictorCount
		guard population.allSatisfy({ $0.count == width }) else { return nil }
		return population.map { propensity($0) }
	}

	/// The propensity at which one contact exactly pays for itself.
	///
	/// - Parameters:
	///   - contactCost: What reaching one prospect costs. Non-negative and finite.
	///   - marginPerResponse: What one response is worth. Positive and finite.
	/// - Returns: `cost / margin`, or `nil` when that is not a propensity anyone could
	///   have. A ratio above one means no contact pays for itself at any response rate —
	///   which is a finding about the campaign, not a threshold to compare against, and
	///   returning it as one invites a test that can never pass.
	public func breakEvenPropensity(contactCost: T, marginPerResponse: T) -> T? {
		guard contactCost >= T.zero, contactCost.isFinite else { return nil }
		guard marginPerResponse > T.zero, marginPerResponse.isFinite else { return nil }
		let threshold: T = contactCost / marginPerResponse
		guard threshold <= T(1) else { return nil }
		return threshold
	}

	/// Whether contacting this prospect is worth it.
	///
	/// - Parameters:
	///   - predictors: One value per predictor.
	///   - contactCost: What reaching one prospect costs.
	///   - marginPerResponse: What one response is worth.
	/// - Returns: `true` when expected margin exceeds the cost. `false` when there is no
	///   reachable break-even propensity at all.
	public func shouldContact(_ predictors: [T], contactCost: T, marginPerResponse: T) -> Bool {
		guard let threshold = breakEvenPropensity(contactCost: contactCost,
												  marginPerResponse: marginPerResponse) else {
			return false
		}
		return propensity(predictors) > threshold
	}

	/// The model scored against the data it was fitted on.
	///
	/// Optimistic — see the note on this type. `nil` cannot occur for a model that fitted,
	/// since a constant outcome is refused before it gets here.
	public var inSampleEvaluation: ClassifierEvaluation<T>? {
		let scores: [T] = predictors.map { propensity($0) }
		return ClassifierEvaluation(scores: scores, outcomes: responded)
	}

	/// In-sample gains by bucket, ready for ``optimalCampaignDepth(gains:contactCost:marginPerResponse:population:)``.
	///
	/// - Parameter buckets: How many buckets to split the ranked cohort into.
	/// - Returns: The table, or `nil` on the same condition as ``inSampleEvaluation``.
	public func inSampleGains(buckets: Int) -> GainsTable<T>? {
		inSampleEvaluation?.gains(buckets: buckets)
	}
}
