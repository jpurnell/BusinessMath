//
//  ETSFit.swift
//  BusinessMath
//
//  Step 4 of PROPOSAL_ets_fitting.md — assembling the searched parameters and the accuracy
//  of the fit they produced.
//

import Foundation
import Numerics

// MARK: - ETSConvergence

/// What the parameter search did before it stopped.
///
/// `converged == false` is not a failure — a run that exhausted its evaluation budget still
/// returns the best feasible point it found — but it is a fact the caller should be able to
/// see rather than infer.
public struct ETSConvergence: Sendable, Equatable {

	/// Whether the simplex met its tolerance before the evaluation budget ran out.
	public let converged: Bool

	/// How many times the objective was evaluated.
	public let evaluations: Int

	/// The final objective value: the in-sample sum of squared one-step residuals.
	public let objective: Double

	/// Creates a convergence report.
	///
	/// - Parameters:
	///   - converged: Whether the search met its tolerance.
	///   - evaluations: Objective evaluations spent.
	///   - objective: The in-sample residual sum of squares at the reported parameters.
	public init(converged: Bool, evaluations: Int, objective: Double) {
		self.converged = converged
		self.evaluations = evaluations
		self.objective = objective
	}
}

// MARK: - ETSFitErrors

/// In-sample accuracy of a fitted model.
///
/// Every value is a ratio rather than a percentage, matching ``mae(_:_:)``, ``rmse(_:_:)``,
/// ``mape(_:_:)`` and ``smape(_:_:)``, which is where they come from.
public struct ETSFitErrors<T: Real & Sendable & Codable & BinaryFloatingPoint>: Sendable, Codable {

	/// Mean absolute error of the one-step-ahead fitted values.
	public let mae: T

	/// Root mean squared error of the one-step-ahead fitted values.
	public let rmse: T

	/// Mean absolute percentage error, as a ratio.
	public let mape: T

	/// Symmetric mean absolute percentage error, as a ratio in `[0, 2]`.
	public let smape: T

	/// Mean absolute scaled error, or `nil` when the naive scale is degenerate — a
	/// constant series has no MASE, because the benchmark it is scaled against is zero.
	public let mase: T?

	/// Creates a set of in-sample error metrics.
	///
	/// - Parameters:
	///   - mae: Mean absolute error.
	///   - rmse: Root mean squared error.
	///   - mape: Mean absolute percentage error, as a ratio.
	///   - smape: Symmetric mean absolute percentage error, as a ratio.
	///   - mase: Mean absolute scaled error, or `nil` for a degenerate scale.
	public init(mae: T, rmse: T, mape: T, smape: T, mase: T?) {
		self.mae = mae
		self.rmse = rmse
		self.mape = mape
		self.smape = smape
		self.mase = mase
	}
}

// MARK: - ETSFit

/// A Holt-Winters model whose smoothing parameters were searched for, with the accuracy of
/// that fit measured on the data it was fitted to.
///
/// ```swift
/// let shape: [Double] = [0, 8, 15, 19, 20, 18, 12, 4, -6, -14, -19, -20]
/// let months = (0..<24).map { Period.month(year: 2024 + $0 / 12, month: $0 % 12 + 1) }
/// let sales: [Double] = (0..<24).map { index in
///     let trend: Double = 100.0 + 2.0 * Double(index)
///     return trend + shape[index % 12]
/// }
/// let series = TimeSeries(periods: months, values: sales)
/// let fit = try series.fitETS(seasonality: .detect, config: .default)
/// print(fit.alpha, fit.seasonLength, fit.errors.smape)
/// ```
public struct ETSFit<T: Real & Sendable & Codable & BinaryFloatingPoint>: Sendable {

	/// The fitted model, trained and ready to forecast. Already a ``Forecaster``.
	public let model: HoltWintersModel<T>

	/// Level smoothing, in `[0, 1]`.
	public let alpha: T

	/// Trend smoothing, in `[0, 1]`.
	public let beta: T

	/// Seasonal smoothing, in `[0, 1]`. Unused, and reported as zero, when non-seasonal.
	public let gamma: T

	/// The cycle length used: `1` when non-seasonal.
	public let seasonLength: Int

	/// Whether ``seasonLength`` came from detection rather than from the caller.
	public let seasonalityWasDetected: Bool

	/// In-sample accuracy of the fitted model.
	public let errors: ETSFitErrors<T>

	/// Whether the parameter search converged, and in how many objective evaluations.
	public let convergence: ETSConvergence

	/// Creates a fit result.
	///
	/// - Parameters:
	///   - model: The trained model.
	///   - alpha: Fitted level smoothing.
	///   - beta: Fitted trend smoothing.
	///   - gamma: Fitted seasonal smoothing, zero when non-seasonal.
	///   - seasonLength: The cycle length used.
	///   - seasonalityWasDetected: Whether the cycle length came from detection.
	///   - errors: In-sample accuracy.
	///   - convergence: What the search did before it stopped.
	public init(
		model: HoltWintersModel<T>,
		alpha: T,
		beta: T,
		gamma: T,
		seasonLength: Int,
		seasonalityWasDetected: Bool,
		errors: ETSFitErrors<T>,
		convergence: ETSConvergence
	) {
		self.model = model
		self.alpha = alpha
		self.beta = beta
		self.gamma = gamma
		self.seasonLength = seasonLength
		self.seasonalityWasDetected = seasonalityWasDetected
		self.errors = errors
		self.convergence = convergence
	}
}

// MARK: - Fitting

public extension TimeSeries where T: BinaryFloatingPoint & Codable {

	/// Searches for the smoothing parameters that best fit this series, and reports how
	/// well they did.
	///
	/// Today a caller of ``HoltWintersModel`` must *supply* `alpha: 0.2` and has no way to
	/// know whether `0.2` is any good for their series. This answers that: the parameters
	/// are searched for by minimising the in-sample sum of squared one-step-ahead
	/// residuals, and the returned model is trained and ready to forecast — it is already a
	/// ``Forecaster``, so ``backtest(_:config:)`` accepts it directly.
	///
	/// ```swift
	/// let shape: [Double] = [0, 8, 15, 19, 20, 18, 12, 4, -6, -14, -19, -20]
	/// let months = (0..<24).map { Period.month(year: 2024 + $0 / 12, month: $0 % 12 + 1) }
	/// let sales: [Double] = (0..<24).map { index in
	///     let trend: Double = 100.0 + 2.0 * Double(index)
	///     return trend + shape[index % 12]
	/// }
	/// let series = TimeSeries(periods: months, values: sales)
	/// let fit = try series.fitETS(seasonality: .detect, config: .default)
	/// let forecast = try fit.model.trainedForecast(from: series, horizon: 6)
	/// print(forecast.valuesArray.count)
	/// ```
	///
	/// - Parameters:
	///   - seasonality: How to decide the cycle length. Defaults to ``ETSSeasonality/detect``.
	///   - config: Search bounds and budget. Defaults to ``ETSFitConfig/default``.
	/// - Returns: The fitted model, its parameters, and the accuracy of the fit.
	/// - Throws: ``ForecastError/insufficientData(required:got:)`` when the series is
	///   shorter than two seasonal cycles, which is what training requires.
	/// - Throws: ``ForecastError/invalidParameter(_:)`` for a non-positive
	///   ``ETSSeasonality/periods(_:)``.
	func fitETS(
		seasonality: ETSSeasonality = .detect,
		config: ETSFitConfig = .default
	) throws -> ETSFit<T> {

		let resolution = try resolvedSeasonality(seasonality)
		let cycle = resolution.length
		let observations = valuesArray
		let required = cycle * 2
		guard observations.count >= required else {
			throw ForecastError.insufficientData(required: required, got: observations.count)
		}

		let search = searchETSParameters(
			values: observations, seasonLength: cycle, config: config)
		let alpha: T = T(search.alpha)
		let beta: T = T(search.beta)
		let gamma: T = T(search.gamma)

		var model = HoltWintersModel<T>(
			alpha: alpha, beta: beta, gamma: gamma, seasonalPeriods: cycle)
		try model.train(on: self)

		// The one-step-ahead fitted values are the observations less the residuals the
		// training pass recorded, which is the same quantity the objective was built on.
		let fitted: [T] = Swift.zip(observations, model.residuals).map { $0 - $1 }
		let fittedSeries = TimeSeries(periods: periods, values: fitted)
		let errors = ETSFitErrors(
			mae: mae(observations, fitted),
			rmse: rmse(observations, fitted),
			mape: mape(observations, fitted),
			smape: smape(observations, fitted),
			mase: mase(against: fittedSeries, training: self, seasonLength: cycle))

		let convergence = ETSConvergence(
			converged: search.converged,
			evaluations: search.evaluations,
			objective: search.objective)

		return ETSFit(
			model: model,
			alpha: alpha,
			beta: beta,
			gamma: gamma,
			seasonLength: cycle,
			seasonalityWasDetected: resolution.wasDetected,
			errors: errors,
			convergence: convergence)
	}
}
