import Foundation
import Numerics

/// Result of a nested (hierarchical) analysis of variance.
///
/// In a nested design, factor B is nested within factor A. Each level of B
/// appears in only one level of A. The model is:
///
/// ```
/// X_ijk = μ + α_i + β_j(i) + e_ijk
/// ```
///
/// where `α_i` is the effect of group `i`, `β_j(i)` is the effect of subgroup
/// `j` nested within group `i`, and `e_ijk` is the residual error.
///
/// The total variation decomposes as:
/// ```
/// SS_total = SS_between + SS_subgroups(within) + SS_within
/// ```
public struct NestedANOVAResult<T: Real & Sendable>: Sendable, Equatable {
	/// Sum of squares between groups (factor A).
	public let ssBetweenGroups: T
	/// Sum of squares among subgroups nested within groups (factor B within A).
	public let ssSubgroupsWithin: T
	/// Sum of squares within subgroups (residual error).
	public let ssWithinSubgroups: T
	/// Total sum of squares.
	public let ssTotal: T
	/// Mean square between groups.
	public let msBetweenGroups: T
	/// Mean square among subgroups within groups.
	public let msSubgroupsWithin: T
	/// Mean square within subgroups (residual/error).
	public let msWithinSubgroups: T
	/// F-statistic for testing the group effect (MS_between / MS_subgroups).
	public let fBetweenGroups: T
	/// p-value for the group effect F-test.
	public let pBetweenGroups: T
	/// F-statistic for testing the subgroup effect (MS_subgroups / MS_within).
	public let fSubgroupsWithin: T
	/// p-value for the subgroup effect F-test.
	public let pSubgroupsWithin: T
	/// Degrees of freedom between groups (a − 1).
	public let dfBetweenGroups: Int
	/// Degrees of freedom among subgroups within groups (Σ(b_i − 1)).
	public let dfSubgroupsWithin: Int
	/// Degrees of freedom within subgroups (N − Σb_i).
	public let dfWithinSubgroups: Int
	/// Number of groups (factor A levels).
	public let groupCount: Int
	/// Total number of observations.
	public let totalCount: Int
	/// Estimated variance component for between-group variation (σ²_α).
	///
	/// Truncated to zero if the estimate is negative.
	public let varianceBetweenGroups: T
	/// Estimated variance component for subgroup-within-group variation (σ²_β).
	///
	/// Truncated to zero if the estimate is negative.
	public let varianceSubgroupsWithin: T
	/// Estimated variance component for within-subgroup variation (σ²_e = MS_within).
	public let varianceWithinSubgroups: T
}

/// Nested (hierarchical) analysis of variance.
///
/// Tests whether the means of groups and subgroups nested within groups differ
/// significantly. Factor B is nested within factor A: each subgroup belongs to
/// exactly one group.
///
/// The critical distinction from crossed designs: `F_between` uses
/// `MS_subgroups` (not `MS_within`) as its denominator, because the correct
/// error term for the group effect is the subgroup-within-group variation.
///
/// Supports unbalanced designs (unequal subgroup sizes and unequal numbers
/// of subgroups per group).
///
/// - Parameter data: Three-dimensional array `data[group][subgroup][observation]`.
///   Groups may have different numbers of subgroups, and subgroups may have
///   different numbers of observations.
/// - Returns: A ``NestedANOVAResult`` with decomposed sums of squares,
///   F-statistics, p-values, and variance components.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 groups,
///   any group has fewer than 2 subgroups, or any subgroup is empty.
public func nestedANOVA<T: Real>(_ data: [[[T]]]) throws -> NestedANOVAResult<T> {
	let a = data.count

	guard a >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: a,
			context: "Nested ANOVA requires at least 2 groups")
	}

	// Validate subgroups
	for (i, group) in data.enumerated() {
		guard group.count >= 2 else {
			throw BusinessMathError.insufficientData(
				required: 2, actual: group.count,
				context: "Group \(i) requires at least 2 subgroups for nested ANOVA")
		}
		for (j, subgroup) in group.enumerated() {
			guard !subgroup.isEmpty else {
				throw BusinessMathError.insufficientData(
					required: 1, actual: 0,
					context: "Subgroup \(j) in group \(i) is empty")
			}
		}
	}

	// Subgroup sizes: n_ij
	let subgroupSizes: [[Int]] = data.map { group in group.map { $0.count } }
	// Total observations per group: n_i.
	let groupSizes: [Int] = subgroupSizes.map { $0.reduce(0, +) }
	// Total observations
	let totalN = groupSizes.reduce(0, +)
	// Number of subgroups per group: b_i
	let subgroupCounts: [Int] = data.map { $0.count }
	// Total subgroups
	let totalSubgroups = subgroupCounts.reduce(0, +)

	// Subgroup means: X_bar_ij.
	let subgroupMeans: [[T]] = data.map { group in
		group.map { subgroup in
			subgroup.reduce(T.zero, +) / T(subgroup.count)
		}
	}

	// Group means: X_bar_i.. (weighted by subgroup observation counts)
	let groupMeans: [T] = data.enumerated().map { (i, group) in
		var sum = T.zero
		for subgroup in group {
			sum += subgroup.reduce(T.zero, +)
		}
		return sum / T(groupSizes[i])
	}

	// Grand mean: X_bar_... (weighted by observation counts)
	let grandTotal = data.flatMap { $0.flatMap { $0 } }.reduce(T.zero, +)
	let grandMean = grandTotal / T(totalN)

	// SS_within (residual): sum_i sum_j sum_k (X_ijk - X_bar_ij.)^2
	var ssWithin = T.zero
	for i in 0..<a {
		for j in 0..<data[i].count {
			let mean = subgroupMeans[i][j]
			for x in data[i][j] {
				let diff = x - mean
				ssWithin += diff * diff
			}
		}
	}

	// SS_subgroups_within: sum_i sum_j n_ij * (X_bar_ij. - X_bar_i..)^2
	var ssSubgroups = T.zero
	for i in 0..<a {
		for j in 0..<data[i].count {
			let diff = subgroupMeans[i][j] - groupMeans[i]
			ssSubgroups += T(subgroupSizes[i][j]) * diff * diff
		}
	}

	// SS_between: sum_i n_i. * (X_bar_i.. - X_bar_...)^2
	var ssBetween = T.zero
	for i in 0..<a {
		let diff = groupMeans[i] - grandMean
		ssBetween += T(groupSizes[i]) * diff * diff
	}

	let ssTotal = ssBetween + ssSubgroups + ssWithin

	// Degrees of freedom
	let dfBetween = a - 1
	let dfSubgroups = subgroupCounts.reduce(0) { $0 + ($1 - 1) }
	let dfWithin = totalN - totalSubgroups

	// Mean squares (guard against zero df)
	let msBetween: T
	if dfBetween > 0 {
		msBetween = ssBetween / T(dfBetween)
	} else {
		msBetween = T.zero
	}

	let msSubgroups: T
	if dfSubgroups > 0 {
		msSubgroups = ssSubgroups / T(dfSubgroups)
	} else {
		msSubgroups = T.zero
	}

	let msWithin: T
	if dfWithin > 0 {
		msWithin = ssWithin / T(dfWithin)
	} else {
		msWithin = T.zero
	}

	// F-statistics and p-values
	// F_between = MS_between / MS_subgroups (subgroups is the error term for groups)
	let fBetween: T
	let pBetween: T
	if msSubgroups == T.zero {
		fBetween = T.zero
		pBetween = T(1)
	} else {
		fBetween = msBetween / msSubgroups
		if dfBetween > 0, dfSubgroups > 0 {
			pBetween = T(1) - (try fCDF(f: fBetween, df1: dfBetween, df2: dfSubgroups))
		} else {
			pBetween = T(1)
		}
	}

	// F_subgroups = MS_subgroups / MS_within
	let fSub: T
	let pSub: T
	if msWithin == T.zero {
		fSub = T.zero
		pSub = T(1)
	} else {
		fSub = msSubgroups / msWithin
		if dfSubgroups > 0, dfWithin > 0 {
			pSub = T(1) - (try fCDF(f: fSub, df1: dfSubgroups, df2: dfWithin))
		} else {
			pSub = T(1)
		}
	}

	// Variance components
	// sigma_e^2 = MS_within
	let varWithin = msWithin

	// sigma_beta^2 = (MS_subgroups - MS_within) / n_0
	// n_0 = harmonic-mean-like coefficient for unbalanced designs
	let n0: T = computeN0(subgroupSizes: subgroupSizes, groupSizes: groupSizes, totalN: totalN, totalSubgroups: totalSubgroups)

	let varSubgroupsRaw: T
	if n0 > T.zero {
		varSubgroupsRaw = (msSubgroups - msWithin) / n0
	} else {
		varSubgroupsRaw = T.zero
	}
	let varSubgroups = varSubgroupsRaw < T.zero ? T.zero : varSubgroupsRaw

	// sigma_alpha^2 = (MS_between - MS_subgroups) / n0_alpha
	// where n0_alpha = (N - sum(n_i.^2 / N)) / (a - 1)
	let n0Alpha: T = computeN0Alpha(groupSizes: groupSizes, totalN: totalN, a: a)
	let varBetweenRaw: T
	if n0Alpha > T.zero {
		varBetweenRaw = (msBetween - msSubgroups) / n0Alpha
	} else {
		varBetweenRaw = T.zero
	}
	let varBetween = varBetweenRaw < T.zero ? T.zero : varBetweenRaw

	return NestedANOVAResult(
		ssBetweenGroups: ssBetween,
		ssSubgroupsWithin: ssSubgroups,
		ssWithinSubgroups: ssWithin,
		ssTotal: ssTotal,
		msBetweenGroups: msBetween,
		msSubgroupsWithin: msSubgroups,
		msWithinSubgroups: msWithin,
		fBetweenGroups: fBetween,
		pBetweenGroups: pBetween,
		fSubgroupsWithin: fSub,
		pSubgroupsWithin: pSub,
		dfBetweenGroups: dfBetween,
		dfSubgroupsWithin: dfSubgroups,
		dfWithinSubgroups: dfWithin,
		groupCount: a,
		totalCount: totalN,
		varianceBetweenGroups: varBetween,
		varianceSubgroupsWithin: varSubgroups,
		varianceWithinSubgroups: varWithin
	)
}

/// Computes the harmonic-mean-like coefficient n₀ for variance component estimation.
///
/// For balanced designs, n₀ equals the common subgroup size n.
/// For unbalanced designs, n₀ is computed as:
/// ```
/// n₀ = (1 / df_subgroups) × (N − Σ(Σn²_ij / n_i.))
/// ```
///
/// - Parameters:
///   - subgroupSizes: Array of arrays of subgroup sizes `n_ij`.
///   - groupSizes: Array of total observations per group `n_i.`.
///   - totalN: Total number of observations.
///   - totalSubgroups: Total number of subgroups.
/// - Returns: The n₀ coefficient.
private func computeN0<T: Real>(
	subgroupSizes: [[Int]],
	groupSizes: [Int],
	totalN: Int,
	totalSubgroups: Int
) -> T {
	let a = subgroupSizes.count
	let dfSubgroups = subgroupSizes.reduce(0) { $0 + ($1.count - 1) }

	guard dfSubgroups > 0 else { return T.zero }

	// n0 = (1/df_sub) * (N - sum_i (sum_j n_ij^2) / n_i.)
	var sumQuotients = T.zero
	for i in 0..<a {
		guard groupSizes[i] > 0 else { continue }
		var sumSqSizes = T.zero
		for nij in subgroupSizes[i] {
			sumSqSizes += T(nij) * T(nij)
		}
		sumQuotients += sumSqSizes / T(groupSizes[i])
	}

	let n0 = (T(totalN) - sumQuotients) / T(dfSubgroups)
	return n0
}

/// Computes the n₀_α coefficient for between-group variance component estimation.
///
/// For balanced designs with equal group sizes n_i. = b*n, this simplifies to b*n.
/// For unbalanced designs:
/// ```
/// n₀_α = (N − Σ(n²_i. / N)) / (a − 1)
/// ```
///
/// - Parameters:
///   - groupSizes: Array of total observations per group `n_i.`.
///   - totalN: Total number of observations.
///   - a: Number of groups.
/// - Returns: The n₀_α coefficient.
private func computeN0Alpha<T: Real>(
	groupSizes: [Int],
	totalN: Int,
	a: Int
) -> T {
	guard a > 1, totalN > 0 else { return T.zero }

	var sumNiSq = T.zero
	for ni in groupSizes {
		sumNiSq += T(ni) * T(ni)
	}

	return (T(totalN) - sumNiSq / T(totalN)) / T(a - 1)
}

// MARK: - Multi-Level Nested ANOVA

/// A recursive data structure representing nested hierarchical observations.
///
/// Used with ``multiLevelNestedANOVA(_:)`` for hierarchies with more than two
/// nesting levels (e.g., regions → clinics → patients → measurements).
///
/// - `observations([T])`: Leaf node containing raw measurements.
/// - `group([NestedData<T>])`: Internal node whose children are subgroups
///   at the next lower level.
public indirect enum NestedData<T: Real & Sendable>: Sendable, Equatable {
	/// Leaf node: raw observation values.
	case observations([T])
	/// Internal node: a group of nested sub-elements.
	case group([NestedData<T>])
}

/// Result of a multi-level nested analysis of variance.
///
/// Generalises ``NestedANOVAResult`` to an arbitrary number of hierarchy levels.
/// Level 0 is the top (between groups), and the last level is within-subgroups
/// (residual error).
public struct MultiLevelNestedANOVAResult<T: Real & Sendable>: Sendable, Equatable {
	/// Sum of squares at each level (from top to residual).
	public let ssLevels: [T]
	/// Mean squares at each level.
	public let msLevels: [T]
	/// Degrees of freedom at each level.
	public let dfLevels: [Int]
	/// F-statistics for each level (count = levels − 1; each uses the next level's MS as denominator).
	public let fStatistics: [T]
	/// p-values corresponding to each F-statistic.
	public let pValues: [T]
	/// Estimated variance components at each level (truncated to zero if negative).
	public let varianceComponents: [T]
	/// Number of hierarchy levels (including residual).
	public let levels: Int
}

/// Multi-level nested analysis of variance.
///
/// Decomposes variation across an arbitrary number of hierarchy levels.
/// At each level, the F-statistic uses the mean square of the level
/// immediately below as its denominator (the correct error term for
/// a fully nested random-effects model).
///
/// - Parameter data: A ``NestedData`` tree. The depth of the tree determines
///   the number of levels. All branches must reach the same depth.
/// - Returns: A ``MultiLevelNestedANOVAResult`` with SS, MS, df, F, p,
///   and variance components for every level.
/// - Throws: `BusinessMathError.insufficientData` if any group has fewer
///   than 2 children, or any observations array is empty.
///   `BusinessMathError.invalidInput` if branches have different depths.
public func multiLevelNestedANOVA<T: Real>(_ data: NestedData<T>) throws -> MultiLevelNestedANOVAResult<T> {
	// Determine tree depth and validate uniform depth
	let depth = try treeDepth(data)

	guard depth >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: depth,
			context: "Multi-level nested ANOVA requires at least 2 levels (one grouping + observations)")
	}

	// Collect all observations for grand mean
	let allObs = collectObservations(data)
	let totalN = allObs.count

	guard totalN > 0 else {
		throw BusinessMathError.insufficientData(
			required: 1, actual: 0,
			context: "No observations in nested data")
	}

	let grandTotal = allObs.reduce(T.zero, +)
	let grandMean = grandTotal / T(totalN)

	// Compute total SS
	var ssTotal = T.zero
	for x in allObs {
		let diff = x - grandMean
		ssTotal += diff * diff
	}

	// Compute SS at each level from top down
	// We need: for each level L, sum over all nodes at level L of
	// n_node * (mean_node - mean_parent)^2
	// The residual (innermost) level is within-subgroup SS.

	var ssLevels: [T] = []
	var dfLevels: [Int] = []

	// Recursively compute level SS and df
	try computeLevelSS(data, depth: depth, ssLevels: &ssLevels, dfLevels: &dfLevels)

	// Mean squares
	let msLevels: [T] = zip(ssLevels, dfLevels).map { ss, df in
		df > 0 ? ss / T(df) : T.zero
	}

	// F-statistics: F[level] = MS[level] / MS[level+1]
	var fStats: [T] = []
	var pVals: [T] = []
	for level in 0..<(depth - 1) {
		if msLevels[level + 1] == T.zero {
			fStats.append(T.zero)
			pVals.append(T(1))
		} else {
			let f = msLevels[level] / msLevels[level + 1]
			fStats.append(f)
			if dfLevels[level] > 0, dfLevels[level + 1] > 0 {
				let p = T(1) - (try fCDF(f: f, df1: dfLevels[level], df2: dfLevels[level + 1]))
				pVals.append(p)
			} else {
				pVals.append(T(1))
			}
		}
	}

	// Variance components (from bottom up)
	// The lowest level (residual): sigma^2_L = MS_L
	// Each higher level: sigma^2_k = (MS_k - MS_{k+1}) / n0_k
	// For simplicity, use harmonic mean coefficient at each level
	var varComponents = Array(repeating: T.zero, count: depth)
	varComponents[depth - 1] = msLevels[depth - 1]

	let n0s = try computeN0PerLevel(data, depth: depth)

	for level in stride(from: depth - 2, through: 0, by: -1) {
		let n0 = n0s[level]
		if n0 > T.zero {
			let raw = (msLevels[level] - msLevels[level + 1]) / n0
			varComponents[level] = raw < T.zero ? T.zero : raw
		}
	}

	return MultiLevelNestedANOVAResult(
		ssLevels: ssLevels,
		msLevels: msLevels,
		dfLevels: dfLevels,
		fStatistics: fStats,
		pValues: pVals,
		varianceComponents: varComponents,
		levels: depth
	)
}

// MARK: - Private Helpers for Multi-Level

/// Determines the depth of a ``NestedData`` tree and validates uniform depth.
private func treeDepth<T: Real>(_ node: NestedData<T>) throws -> Int {
	switch node {
	case .observations(let values):
		guard !values.isEmpty else {
			throw BusinessMathError.insufficientData(
				required: 1, actual: 0,
				context: "Empty observations in nested data")
		}
		return 1
	case .group(let children):
		guard children.count >= 2 else {
			throw BusinessMathError.insufficientData(
				required: 2, actual: children.count,
				context: "Each group in nested ANOVA requires at least 2 children")
		}
		let childDepths = try children.map { try treeDepth($0) }
		let first = childDepths[0]
		for d in childDepths {
			guard d == first else {
				throw BusinessMathError.invalidInput(
					message: "All branches must have the same depth in nested ANOVA",
					value: "\(d)", expectedRange: "\(first)")
			}
		}
		return 1 + first
	}
}

/// Collects all leaf observations from a ``NestedData`` tree.
private func collectObservations<T: Real>(_ node: NestedData<T>) -> [T] {
	switch node {
	case .observations(let values):
		return values
	case .group(let children):
		return children.flatMap { collectObservations($0) }
	}
}

/// Computes the count and mean of all observations under a node.
private func nodeStats<T: Real>(_ node: NestedData<T>) -> (count: Int, sum: T) {
	switch node {
	case .observations(let values):
		return (values.count, values.reduce(T.zero, +))
	case .group(let children):
		var totalCount = 0
		var totalSum = T.zero
		for child in children {
			let (c, s) = nodeStats(child)
			totalCount += c
			totalSum += s
		}
		return (totalCount, totalSum)
	}
}

/// Recursively computes sum of squares and degrees of freedom for each level.
///
/// Level 0 = between-group SS at the topmost grouping.
/// Last level = within-subgroup (residual) SS.
private func computeLevelSS<T: Real>(
	_ node: NestedData<T>,
	depth: Int,
	ssLevels: inout [T],
	dfLevels: inout [Int]
) throws {
	// Initialise arrays if empty
	if ssLevels.isEmpty {
		ssLevels = Array(repeating: T.zero, count: depth)
		dfLevels = Array(repeating: 0, count: depth)
	}

	// Recursive traversal that accumulates SS at each level
	try accumulateSS(node, level: 0, depth: depth, ssLevels: &ssLevels, dfLevels: &dfLevels)
}

/// Accumulates SS contributions at a given level of the hierarchy.
///
/// For a `.group` node at the current level:
/// - Computes SS_between for its children (child means vs this node's mean)
/// - Adds to ssLevels[level]
/// - Adds (children.count - 1) to dfLevels[level]
/// - Recurses into each child at level+1
///
/// For an `.observations` node (leaf, level == depth-1):
/// - Computes within-subgroup SS
/// - Adds to ssLevels[depth-1]
/// - Adds (count - 1) to dfLevels[depth-1]
private func accumulateSS<T: Real>(
	_ node: NestedData<T>,
	level: Int,
	depth: Int,
	ssLevels: inout [T],
	dfLevels: inout [Int]
) throws {
	switch node {
	case .observations(let values):
		// This is the residual (lowest) level
		let n = values.count
		guard n > 0 else { return }
		let mean = values.reduce(T.zero, +) / T(n)
		var ss = T.zero
		for x in values {
			let diff = x - mean
			ss += diff * diff
		}
		ssLevels[depth - 1] += ss
		dfLevels[depth - 1] += n - 1

	case .group(let children):
		// Compute this node's mean
		let (parentCount, parentSum) = nodeStats(node)
		guard parentCount > 0 else { return }
		let parentMean = parentSum / T(parentCount)

		// SS at this level: sum over children of n_child * (mean_child - parentMean)^2
		var ssBetween = T.zero
		for child in children {
			let (childCount, childSum) = nodeStats(child)
			guard childCount > 0 else { continue }
			let childMean = childSum / T(childCount)
			let diff = childMean - parentMean
			ssBetween += T(childCount) * diff * diff
		}
		ssLevels[level] += ssBetween
		dfLevels[level] += children.count - 1

		// Recurse into children
		for child in children {
			try accumulateSS(child, level: level + 1, depth: depth, ssLevels: &ssLevels, dfLevels: &dfLevels)
		}
	}
}

/// Computes the harmonic-mean-like n₀ coefficient at each level for variance component estimation.
///
/// For each level, n₀ is approximated using the harmonic mean of the effective
/// sample sizes at that level.
private func computeN0PerLevel<T: Real>(_ data: NestedData<T>, depth: Int) throws -> [T] {
	guard depth >= 2 else { return [] }

	// For each level, we need an n0 that adjusts for unbalance.
	// Level L (0-indexed): n0_L is the effective coefficient for the MS at that level.
	//
	// For the deepest non-residual level (depth-2), n0 is the harmonic mean of
	// leaf sizes within each group at that level.
	//
	// For higher levels, n0 is a product-like coefficient.
	//
	// General approach: at each level, collect the sizes of children under each
	// parent, compute harmonic mean of child sizes, and multiply up.

	var n0s = Array(repeating: T(1), count: depth)

	// Collect child-size info at each level
	let levelInfo = gatherLevelInfo(data, depth: depth)

	// n0 for the deepest grouping level (the one just above observations):
	// harmonic mean of observation counts per leaf group
	// For each internal node at level (depth-2), its children are observations nodes
	// n0 at this level = harmonic mean of leaf sizes

	// Build from bottom up
	// Level depth-1 is residual — no n0 needed (variance = MS directly)
	// Level depth-2: n0 = harmonic mean of sizes of observations arrays
	// Level depth-3: n0 = n0(depth-2) * harmonic mean of # children at level depth-2
	// etc.

	// levelInfo[L] contains arrays of child-counts for each parent node at level L
	// e.g. levelInfo[0] = [[child1_count, child2_count, ...]] for the root
	// levelInfo[depth-2] = [[obs_count1, obs_count2, ...], ...] for each parent

	// We need to compute n0 for variance components.
	// The standard approach for arbitrary depth:
	// At each level L (from bottom), n0_L = harmonic mean of effective sizes.
	// effective size at leaf level = observation counts
	// effective size at level L = (sum of obs under child) for each child of each parent at L

	// Simpler: compute cumulative n0 from the bottom
	// n0 for level (depth-2) = harmonicMean of all leaf node sizes
	var cumulativeN0 = T(1)

	for level in stride(from: depth - 2, through: 0, by: -1) {
		// At this level, for each parent node, we have child sizes (# of observations under each child)
		let allChildSizes = levelInfo[level]
		// Flatten to get all effective child sizes
		let flatSizes: [Int] = allChildSizes.flatMap { $0 }

		guard !flatSizes.isEmpty else {
			n0s[level] = T.zero
			continue
		}

		if level == depth - 2 {
			// Deepest grouping level: n0 = harmonic mean of leaf sizes
			let hm = harmonicMeanOfInts(flatSizes, as: T.self)
			cumulativeN0 = hm
			n0s[level] = cumulativeN0
		} else {
			// Higher level: effective n0 = cumulativeN0 * harmonicMean of # children per parent
			// "# children per parent" = count of children for each parent at next level
			let childCounts = levelInfo[level].map { $0.count }
			let hmChildren = harmonicMeanOfInts(childCounts, as: T.self)
			cumulativeN0 = cumulativeN0 * hmChildren
			n0s[level] = cumulativeN0
		}
	}

	return n0s
}

/// For each level, returns an array of arrays of child observation counts.
///
/// `result[level]` contains one array per parent node at that level.
/// Each inner array lists the total observation count under each child.
private func gatherLevelInfo<T: Real>(_ data: NestedData<T>, depth: Int) -> [[[Int]]] {
	var info: [[[Int]]] = Array(repeating: [], count: depth)
	gatherLevelInfoHelper(data, level: 0, depth: depth, info: &info)
	return info
}

private func gatherLevelInfoHelper<T: Real>(
	_ node: NestedData<T>,
	level: Int,
	depth: Int,
	info: inout [[[Int]]]
) {
	switch node {
	case .observations:
		// Leaf — no children to record
		break
	case .group(let children):
		// Record child sizes for this parent
		let childSizes: [Int] = children.map { nodeStats($0).count }
		info[level].append(childSizes)
		// Recurse
		for child in children {
			gatherLevelInfoHelper(child, level: level + 1, depth: depth, info: &info)
		}
	}
}

/// Computes the harmonic mean of an array of positive integers.
private func harmonicMeanOfInts<T: Real>(_ values: [Int], as type: T.Type) -> T {
	guard !values.isEmpty else { return T.zero }
	let n = T(values.count)
	var reciprocalSum = T.zero
	for v in values {
		guard v > 0 else { continue }
		reciprocalSum += T(1) / T(v)
	}
	guard reciprocalSum > T.zero else { return T.zero }
	return n / reciprocalSum
}
