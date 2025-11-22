//
//  ForecastTypes.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - ForecastError

/// Errors that can occur during forecasting.
public enum ForecastError: Error {
	/// Insufficient data for the requested operation.
	case insufficientData(required: Int, got: Int)

	/// Model has not been trained yet.
	case modelNotTrained

	/// Invalid parameter value.
	case invalidParameter(String)
	
	case invalidConfidenceLevel
}

// MARK: - ForecastWithConfidence

/// A forecast with confidence intervals.
///
/// `ForecastWithConfidence` contains point forecasts along with upper and
/// lower bounds representing the confidence interval.
public struct ForecastWithConfidence<T: Real & Sendable & Codable> {
	/// The point forecast (expected values).
	public let forecast: TimeSeries<T>

	/// The lower bound of the confidence interval.
	public let lowerBound: TimeSeries<T>

	/// The upper bound of the confidence interval.
	public let upperBound: TimeSeries<T>

	/// The confidence level (e.g., 0.95 for 95% confidence).
	public let confidenceLevel: T

	/// Creates a forecast with confidence intervals.
	///
	/// - Parameters:
	///   - forecast: The point forecast.
	///   - lowerBound: The lower bound.
	///   - upperBound: The upper bound.
	///   - confidenceLevel: The confidence level.
	public init(
		forecast: TimeSeries<T>,
		lowerBound: TimeSeries<T>,
		upperBound: TimeSeries<T>,
		confidenceLevel: T
	) {
		self.forecast = forecast
		self.lowerBound = lowerBound
		self.upperBound = upperBound
		self.confidenceLevel = confidenceLevel
	}
}
