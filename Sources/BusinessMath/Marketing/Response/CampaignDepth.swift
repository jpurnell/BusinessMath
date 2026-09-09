//
//  CampaignDepth.swift
//  BusinessMath
//

import Foundation
import Numerics

/// How far down a ranked list it pays to contact.
public struct CampaignDepth<T: Real & Sendable>: Sendable {

	/// How many buckets to contact. **Zero means contact nobody**, which is a real
	/// answer and the right one when no depth covers its own cost.
	public let bucket: Int

	/// How many prospects that reaches.
	public let contacted: T

	/// Expected responses from them.
	public let responses: T

	/// Expected profit: responses times margin, less contacts times cost.
	public let profit: T

	/// Creates a depth.
	///
	/// - Parameters:
	///   - bucket: Buckets to contact, zero for none.
	///   - contacted: Prospects reached.
	///   - responses: Expected responses.
	///   - profit: Expected profit.
	public init(bucket: Int, contacted: T, responses: T, profit: T) {
		self.bucket = bucket
		self.contacted = contacted
		self.responses = responses
		self.profit = profit
	}
}

/// The profit-maximising contact depth over a ranked gains table.
///
/// ```swift
/// let scores: [Double] = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.05]
/// let responded: [Bool] = [true, true, false, true, false, false, true, false, false, false]
///
/// if let evaluation = ClassifierEvaluation(scores: scores, outcomes: responded) {
///     let table = evaluation.gains(buckets: 5)
///     if let depth = optimalCampaignDepth(gains: table, contactCost: 2,
///                                         marginPerResponse: 50, population: 10) {
///         print(depth.bucket, depth.contacted, depth.profit)
///     }
/// }
/// ```
///
/// ## Where a classifier becomes a decision
///
/// A ``GainsTable`` says what share of responders each decile holds. It does not say how
/// many to contact — that needs the two numbers no model contains: what a response is
/// worth and what a contact costs. This is the join, and it is why the classification
/// work in `Statistics/` stops at a diagnostic and the decision lives here.
///
/// The optimum is generally **interior**. Early buckets pay because they are dense with
/// responders; later ones stop paying because the contact cost is flat while the response
/// rate falls. A campaign run to the bottom of the list is not thorough, it is
/// subsidising the deciles that no longer convert.
///
/// - Parameters:
///   - gains: The ranked buckets, best first.
///   - contactCost: Cost of contacting one prospect, non-negative.
///   - marginPerResponse: Margin from one response, non-negative.
///   - population: How many prospects the table describes.
/// - Returns: The best depth, or `nil` for an empty table or a non-positive population.
///   A campaign that never pays returns depth zero rather than `nil` — "contact nobody"
///   is the answer, not the absence of one.
public func optimalCampaignDepth<T: Real & Sendable & BinaryFloatingPoint>(
	gains: GainsTable<T>,
	contactCost: T,
	marginPerResponse: T,
	population: Int
) -> CampaignDepth<T>? {
	guard !gains.rows.isEmpty, population > 0 else { return nil }
	guard contactCost >= T.zero, contactCost.isFinite else { return nil }
	guard marginPerResponse >= T.zero, marginPerResponse.isFinite else { return nil }

	let total = T(population)
	var responderCount: T = T.zero
	for row in gains.rows { responderCount += T(row.positives) }

	// Contacting nobody is the baseline, and it is a legitimate winner.
	var best = CampaignDepth<T>(bucket: 0, contacted: T.zero,
								responses: T.zero, profit: T.zero)
	for row in gains.rows {
		let reached: T = row.cumulativePopulation * total
		let responses: T = row.cumulativeGain * responderCount
		let revenue: T = responses * marginPerResponse
		let spend: T = reached * contactCost
		let profit: T = revenue - spend
		if profit > best.profit {
			best = CampaignDepth(bucket: row.bucket, contacted: reached,
								 responses: responses, profit: profit)
		}
	}
	return best
}
