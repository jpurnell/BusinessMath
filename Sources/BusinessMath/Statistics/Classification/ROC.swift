//
//  ROC.swift
//  BusinessMath
//

import Foundation
import Numerics

/// One vertex of a ROC curve.
public struct ROCPoint<T: Real & Sendable>: Sendable {

	/// False positive rate, the x axis.
	public let falsePositiveRate: T

	/// True positive rate, the y axis.
	public let truePositiveRate: T

	/// The score threshold this vertex corresponds to.
	public let threshold: T

	/// Creates a point.
	///
	/// - Parameters:
	///   - falsePositiveRate: The x coordinate.
	///   - truePositiveRate: The y coordinate.
	///   - threshold: The score at or above which a case is called positive.
	public init(falsePositiveRate: T, truePositiveRate: T, threshold: T) {
		self.falsePositiveRate = falsePositiveRate
		self.truePositiveRate = truePositiveRate
		self.threshold = threshold
	}
}

/// A ROC curve and the area under it.
///
/// ## Ties are the whole difficulty
///
/// The curve is built by walking the scores from highest to lowest, and **all
/// observations sharing a score must be consumed in one step**. Taking them one at a
/// time draws a staircase whose corners depend on the order the data happened to arrive
/// in, and the area under that staircase is not the AUC — it is somewhere between the
/// optimistic and pessimistic orderings, chosen arbitrarily.
///
/// Consuming a tied group at once produces a single diagonal segment, and the
/// trapezoidal area under a diagonal is exactly the half-credit that the Mann–Whitney
/// definition gives a tied pair. That is why the two agree exactly rather than
/// approximately, and it is what
/// `ClassifierEvaluationTests.aucMatchesMannWhitney` checks.
public struct ROCCurve<T: Real & Sendable>: Sendable {

	/// The vertices, from `(0, 0)` to `(1, 1)`.
	public let points: [ROCPoint<T>]

	/// The area under the curve, by the trapezoidal rule.
	public let area: T

	/// Creates a curve.
	///
	/// - Parameters:
	///   - points: The vertices.
	///   - area: The area beneath them.
	public init(points: [ROCPoint<T>], area: T) {
		self.points = points
		self.area = area
	}
}
