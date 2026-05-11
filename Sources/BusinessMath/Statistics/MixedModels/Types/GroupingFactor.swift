import Foundation
import Numerics

/// A grouping factor that assigns each observation to a group.
///
/// Observations within the same group share a random effect.
/// For example, in a repeated-measures study, all measurements from
/// patient i share a random intercept u_i.
///
/// Example:
/// ```swift
/// // 3 patients, 2 measurements each
/// let groups = try GroupingFactor([0, 0, 1, 1, 2, 2])
/// // groups.groupCount == 3
/// // groups.groupSizes == [2, 2, 2]
/// ```
public struct GroupingFactor: Sendable, Equatable {
	/// Group assignments for each observation (0-indexed).
	public let groups: [Int]

	/// Number of distinct groups.
	public let groupCount: Int

	/// Number of observations in each group.
	public let groupSizes: [Int]

	/// Observation indices for each group.
	public let groupIndices: [[Int]]

	/// Creates a grouping factor from group assignments.
	///
	/// - Parameter groups: Array mapping each observation to its group (0-indexed).
	///   Group IDs need not be contiguous — they will be remapped to 0..<groupCount.
	/// - Throws: `BusinessMathError.invalidInput` if groups is empty
	///   or contains negative values.
	public init(_ groups: [Int]) throws {
		guard !groups.isEmpty else {
			throw BusinessMathError.invalidInput(
				message: "GroupingFactor requires at least one observation",
				value: "empty", expectedRange: ">= 1 observation")
		}
		guard groups.allSatisfy({ $0 >= 0 }) else {
			throw BusinessMathError.invalidInput(
				message: "Group IDs must be non-negative",
				value: "contains negative", expectedRange: ">= 0")
		}

		let uniqueGroups = Array(Set(groups)).sorted()
		let remapping = Dictionary(uniqueKeysWithValues: uniqueGroups.enumerated().map { ($1, $0) })
		let remapped = groups.map { remapping[$0] ?? $0 }

		let count = uniqueGroups.count
		var indices = Array(repeating: [Int](), count: count)
		for (obsIdx, gID) in remapped.enumerated() {
			indices[gID].append(obsIdx)
		}

		self.groups = remapped
		self.groupCount = count
		self.groupSizes = indices.map { $0.count }
		self.groupIndices = indices
	}
}
