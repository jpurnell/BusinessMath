//
//  DiagnosedScores.swift
//  BusinessMath
//

import Foundation

/// Scores plus how the iteration that produced them ended.
///
/// Encodes as `{"scores": {...}, "convergence": {...}}`; the `convergence` key is omitted when
/// it is `nil`, so a result stored before convergence was recorded decodes with `nil`.
/// Conforms to ``MetricValue`` (kind `"scores"`) when `Node` is `Codable`.
///
/// ```swift
/// let diagnosed = DiagnosedScores(scores: NodeScores(["a": 1.0]), convergence: nil)
/// print(diagnosed.scores["a"] ?? 0)   // 1.0
/// ```
public struct DiagnosedScores<Node: Hashable & Comparable & Sendable>: Sendable, Hashable {
	/// The scores.
	public let scores: NodeScores<Node>
	/// How the iteration ended; `nil` when unknown.
	public let convergence: ConvergenceReport?

	/// Creates a value.
	public init(scores: NodeScores<Node>, convergence: ConvergenceReport?) {
		self.scores = scores
		self.convergence = convergence
	}
}

extension DiagnosedScores: Codable where Node: Codable {
	private enum Keys: String, CodingKey { case scores, convergence }

	/// Decodes.
	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: Keys.self)
		self.scores = NodeScores(try container.decode([Node: Double].self, forKey: .scores))
		self.convergence = try container.decodeIfPresent(ConvergenceReport.self, forKey: .convergence)
	}

	/// Encodes.
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: Keys.self)
		try container.encode(scores.scores, forKey: .scores)
		try container.encodeIfPresent(convergence, forKey: .convergence)
	}
}

extension DiagnosedScores: MetricValue where Node: Codable {
	/// `"scores"`.
	public static var kind: String { "scores" }
}
