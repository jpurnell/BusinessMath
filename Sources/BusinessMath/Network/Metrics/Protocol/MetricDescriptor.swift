//
//  MetricDescriptor.swift
//  BusinessMath
//

import Foundation

/// What a metric answers, and what it must not be read as answering.
///
/// ```swift
/// import BusinessMath
///
/// let descriptor = MetricDescriptor(
///     identifier: "degree", version: 1, title: "Degree",
///     interpretation: "How connected this node is.",
///     highMeans: "Many or strong ties.", lowMeans: "Few recorded ties.")
/// print(descriptor.identifier)   // degree
/// ```
public struct MetricDescriptor: Sendable, Hashable, Codable {

	/// Stable identifier, e.g. `"eigenvector-centrality"`.
	public let identifier: String

	/// Bumped when the mathematics changes, so old results stay interpretable.
	public let version: Int

	/// A short name for the app.
	public let title: String

	/// The question this answers, in one sentence.
	public let interpretation: String

	/// What a *high* score means.
	public let highMeans: String

	/// What a *low* score means — stated separately because this is where the
	/// misreadings happen.
	public let lowMeans: String

	/// Creates a descriptor.
	public init(
		identifier: String, version: Int, title: String,
		interpretation: String, highMeans: String, lowMeans: String
	) {
		self.identifier = identifier
		self.version = version
		self.title = title
		self.interpretation = interpretation
		self.highMeans = highMeans
		self.lowMeans = lowMeans
	}
}
