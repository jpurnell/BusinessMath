//
//  ETSSeasonality.swift
//  BusinessMath
//
//  Step 2 of PROPOSAL_ets_fitting.md — naming the three seasonality cases, and putting a
//  named entry point over the detection that already existed.
//

import Foundation
import Numerics

// MARK: - ETSSeasonality

/// How a fit decides its seasonal cycle length.
///
/// A spreadsheet encodes these three cases in one optional numeric argument — `0` for
/// non-seasonal, `1` for auto-detect, any other positive integer for an explicit cycle
/// length. That is a sum type wearing a number, so it arrives here as a sum type and the
/// numeric convention stays in the binding layer where it belongs.
///
/// ```swift
/// let shape: [Double] = [0, 8, 15, 19, 20, 18, 12, 4, -6, -14, -19, -20]
/// let months = (0..<24).map { Period.month(year: 2024 + $0 / 12, month: $0 % 12 + 1) }
/// let sales: [Double] = (0..<24).map { index in
///     let trend: Double = 100.0 + 2.0 * Double(index)
///     return trend + shape[index % 12]
/// }
/// let series = TimeSeries(periods: months, values: sales)
/// let resolution = try series.resolvedSeasonality(.detect)
/// print(resolution.length)
/// ```
public enum ETSSeasonality: Sendable, Equatable {

	/// Non-seasonal: level and trend only, gamma unused.
	case none

	/// Suggest a cycle from the autocorrelation, falling back to ``none`` when no lag
	/// clears the white-noise band.
	case detect

	/// An explicit cycle length, in periods. Must be `≥ 1`.
	case periods(Int)

	/// The cycle length a seasonality choice resolved to for a particular series, and
	/// whether it was detected rather than supplied.
	///
	/// Detection is advisory, so a caller needs to be able to tell an answer that came
	/// from the data apart from one they gave themselves. ``ETSFit`` carries the same two
	/// facts for exactly that reason.
	public struct Resolution: Sendable, Equatable {

		/// The cycle length to fit with. `1` means non-seasonal.
		public let length: Int

		/// Whether ``length`` came from detection rather than from the caller.
		public let wasDetected: Bool

		/// Creates a resolved seasonality.
		///
		/// - Parameters:
		///   - length: The cycle length, `1` for non-seasonal.
		///   - wasDetected: Whether the length came from detection.
		public init(length: Int, wasDetected: Bool) {
			self.length = length
			self.wasDetected = wasDetected
		}
	}
}

// MARK: - Detection and resolution

public extension TimeSeries where T: BinaryFloatingPoint {

	/// The dominant seasonal cycle length this series shows, or `nil` when it shows none.
	///
	/// This is the named entry point over ``dominantSeasonLength(maxLag:)``: the lag
	/// `h ≥ 2` whose autocorrelation is strongest *and* exceeds the approximate 95%
	/// white-noise band `1.96/√n`. It answers a spreadsheet's "length of the repetitive
	/// pattern detected in this series", including that function's no-pattern answer.
	///
	/// - Parameter maxLag: The largest candidate cycle to consider. Defaults to half the
	///   series length, which is the longest cycle that could repeat at all.
	/// - Returns: The detected cycle length, or `nil` if no lag clears the band.
	///
	/// ```swift
	/// let shape: [Double] = [0, 8, 15, 19, 20, 18, 12, 4, -6, -14, -19, -20]
	/// let months = (0..<24).map { Period.month(year: 2024 + $0 / 12, month: $0 % 12 + 1) }
	/// let sales: [Double] = (0..<24).map { index in
	///     let trend: Double = 100.0 + 2.0 * Double(index)
	///     return trend + shape[index % 12]
	/// }
	/// let series = TimeSeries(periods: months, values: sales)
	/// let cycle = series.detectedSeasonLength()
	/// print(cycle ?? 1)
	/// ```
	func detectedSeasonLength(maxLag: Int? = nil) -> Int? {
		let n = valuesArray.count
		guard n >= 2 else { return nil }
		let ceiling = Swift.min(Swift.max(n / 2, 2), n - 1)
		let lag = maxLag ?? ceiling
		guard lag >= 1 else { return nil }
		return dominantSeasonLength(maxLag: lag)
	}

	/// Resolves a seasonality choice into the concrete cycle length a fit will use.
	///
	/// - ``ETSSeasonality/none`` resolves to `1`.
	/// - ``ETSSeasonality/detect`` delegates to ``detectedSeasonLength(maxLag:)`` and
	///   falls back to `1` when nothing is detectable.
	/// - ``ETSSeasonality/periods(_:)`` is honoured exactly. Detection never overrides an
	///   explicit length.
	///
	/// - Parameter seasonality: The caller's choice.
	/// - Returns: The cycle length, and whether it came from detection.
	/// - Throws: ``ForecastError/invalidParameter(_:)`` when
	///   ``ETSSeasonality/periods(_:)`` carries a non-positive length. The enum can
	///   express a cycle length of zero and a fit cannot.
	func resolvedSeasonality(_ seasonality: ETSSeasonality) throws -> ETSSeasonality.Resolution {
		switch seasonality {
		case .none:
			return ETSSeasonality.Resolution(length: 1, wasDetected: false)
		case .periods(let length):
			guard length >= 1 else {
				throw ForecastError.invalidParameter(
					"seasonality: cycle length must be at least 1, got \(length)")
			}
			return ETSSeasonality.Resolution(length: length, wasDetected: false)
		case .detect:
			guard let detected = detectedSeasonLength() else {
				return ETSSeasonality.Resolution(length: 1, wasDetected: false)
			}
			return ETSSeasonality.Resolution(length: detected, wasDetected: true)
		}
	}
}
