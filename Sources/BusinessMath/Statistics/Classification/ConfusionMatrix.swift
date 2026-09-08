//
//  ConfusionMatrix.swift
//  BusinessMath
//

import Foundation
import Numerics

/// The four counts a threshold produces, and the rates read off them.
///
/// Counts rather than rates are the stored form, because every rate here divides by a
/// margin that can be zero — a threshold above every score has no predicted positives
/// and therefore no precision — and a type that stores rates has already lost the
/// information needed to say so.
public struct ConfusionMatrix: Sendable, Equatable, Codable {

	/// Predicted positive, actually positive.
	public let truePositives: Int

	/// Predicted positive, actually negative.
	public let falsePositives: Int

	/// Predicted negative, actually positive.
	public let falseNegatives: Int

	/// Predicted negative, actually negative.
	public let trueNegatives: Int

	/// Creates a matrix from its four counts.
	///
	/// - Parameters:
	///   - truePositives: Predicted positive and positive.
	///   - falsePositives: Predicted positive and negative.
	///   - falseNegatives: Predicted negative and positive.
	///   - trueNegatives: Predicted negative and negative.
	public init(truePositives: Int, falsePositives: Int,
				falseNegatives: Int, trueNegatives: Int) {
		self.truePositives = truePositives
		self.falsePositives = falsePositives
		self.falseNegatives = falseNegatives
		self.trueNegatives = trueNegatives
	}

	/// Every observation. The four counts partition the data, so this is the sample size.
	public var total: Int {
		let positives = truePositives + falsePositives
		let negatives = falseNegatives + trueNegatives
		return positives + negatives
	}

	/// True positive rate, `TP / (TP + FN)` — recall. Zero when there are no positives.
	public var sensitivity: Double {
		Self.rate(truePositives, over: truePositives + falseNegatives)
	}

	/// True negative rate, `TN / (TN + FP)`. Zero when there are no negatives.
	public var specificity: Double {
		Self.rate(trueNegatives, over: trueNegatives + falsePositives)
	}

	/// `FP / (FP + TN)`, the complement of ``specificity``.
	public var falsePositiveRate: Double {
		Self.rate(falsePositives, over: falsePositives + trueNegatives)
	}

	/// `TP / (TP + FP)`. Zero when nothing was predicted positive.
	public var precision: Double {
		Self.rate(truePositives, over: truePositives + falsePositives)
	}

	/// `(TP + TN) / total`.
	public var accuracy: Double {
		let correct = truePositives + trueNegatives
		return Self.rate(correct, over: total)
	}

	/// The harmonic mean of ``precision`` and ``sensitivity``. Zero when either is.
	public var f1: Double {
		let p: Double = precision
		let r: Double = sensitivity
		let sum: Double = p + r
		guard sum > 0 else { return 0 }
		let product: Double = p * r
		return 2 * product / sum
	}

	/// A count over a margin, answering zero rather than dividing by nothing.
	///
	/// Zero is the right answer rather than a fudge: a rate over an empty margin is a
	/// statement about no observations, and the honest report of "none of nothing" in a
	/// type that must return a `Double` is zero. ``total`` is available to a caller who
	/// needs to distinguish that from a genuine zero rate.
	private static func rate(_ count: Int, over margin: Int) -> Double {
		guard margin > 0 else { return 0 }
		return Double(count) / Double(margin)
	}
}
