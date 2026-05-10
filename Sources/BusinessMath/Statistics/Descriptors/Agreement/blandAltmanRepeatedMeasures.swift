import Foundation
import Numerics

/// Result of a repeated-measures Bland-Altman analysis.
///
/// Extends the standard Bland-Altman framework to handle designs where each
/// subject contributes multiple paired measurements. Uses variance-component
/// decomposition (via one-way ANOVA on per-subject differences) to produce
/// modified limits of agreement that properly account for within-subject
/// correlation.
public struct RepeatedMeasuresBlandAltmanResult<T: Real>: Sendable, Equatable {
	/// Overall mean difference (bias).
	public let bias: T

	/// Between-subject variance component of differences.
	public let varianceBetween: T

	/// Within-subject variance component of differences.
	public let varianceWithin: T

	/// Total variance (between + within).
	public let varianceTotal: T

	/// Lower modified limit of agreement.
	public let loaLower: T

	/// Upper modified limit of agreement.
	public let loaUpper: T

	/// Number of subjects.
	public let subjects: Int

	/// Total number of paired observations.
	public let totalObservations: Int

	/// Slope of differences regressed on means (proportional bias).
	public let proportionalBiasSlope: T

	/// Coefficient of individual agreement (CIA).
	///
	/// Proportion of total variability due to within-subject differences.
	/// CIA near 0 means good within-subject agreement; CIA near 1 means poor.
	public let coefficientOfIndividualAgreement: T
}

/// Bland-Altman analysis with repeated measures.
///
/// Accounts for within-subject correlation when each subject contributes
/// multiple paired measurements. Uses variance components (method of moments
/// via one-way ANOVA) to compute modified limits of agreement.
///
/// - Parameter pairs: Array of subjects, where each subject is an array
///   of `(x, y)` tuples representing paired measurements.
/// - Returns: Repeated-measures Bland-Altman result with variance decomposition.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 subjects,
///           any subject has fewer than 1 pair, or total observations do not
///           exceed the number of subjects (required for within-subject df).
public func blandAltmanRepeatedMeasures<T: Real>(
	_ pairs: [[(x: T, y: T)]]
) throws -> RepeatedMeasuresBlandAltmanResult<T> {

	// --- Validation ---
	guard pairs.count >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: pairs.count,
			context: "Repeated-measures Bland-Altman requires at least 2 subjects")
	}

	for (i, subject) in pairs.enumerated() {
		guard !subject.isEmpty else {
			throw BusinessMathError.insufficientData(
				required: 1, actual: 0,
				context: "Subject \(i) has no paired observations")
		}
	}

	// --- Compute differences and means per observation ---
	let groups: [[T]] = pairs.map { subject in
		subject.map { $0.x - $0.y }
	}

	let allDifferences = groups.flatMap { $0 }
	let allMeans: [T] = pairs.flatMap { subject in
		subject.map { ($0.x + $0.y) / T(2) }
	}

	let n = pairs.count           // number of subjects
	let totalN = allDifferences.count

	// --- Overall bias ---
	let bias = allDifferences.reduce(T.zero, +) / T(totalN)

	// --- Variance decomposition via one-way ANOVA ---
	let anova = try oneWayANOVA(groups)

	let msWithin = anova.msWithin
	let msBetween = anova.msBetween

	// Compute average group size k (for unbalanced designs)
	let groupSizes = groups.map { $0.count }
	let k: T
	let isBalanced = Set(groupSizes).count == 1
	if isBalanced {
		k = T(groupSizes[0])
	} else {
		// Unbalanced: k = (1/(n-1)) * (N - sum(m_i^2) / N)
		let sumMiSquared = groupSizes.reduce(0) { $0 + $1 * $1 }
		k = T(1) / T(n - 1) * (T(totalN) - T(sumMiSquared) / T(totalN))
	}

	// Between-subject variance, truncated to 0 if negative
	let varianceBetween: T
	if msBetween > msWithin, k > T.zero {
		varianceBetween = (msBetween - msWithin) / k
	} else {
		varianceBetween = T.zero
	}

	let varianceWithin = msWithin
	let varianceTotal = varianceBetween + varianceWithin

	// --- Modified limits of agreement ---
	let z95 = T(196) / T(100) // 1.96
	let loaHalf = z95 * T.sqrt(varianceTotal)
	let loaLower = bias - loaHalf
	let loaUpper = bias + loaHalf

	// --- Proportional bias: regress all differences on all means ---
	let meanOfMeans = allMeans.reduce(T.zero, +) / T(totalN)
	let meanOfDiffs = bias

	var sumXY = T.zero
	var sumXX = T.zero

	for i in 0..<totalN {
		let dx = allMeans[i] - meanOfMeans
		let dy = allDifferences[i] - meanOfDiffs
		sumXY += dx * dy
		sumXX += dx * dx
	}

	let proportionalBiasSlope: T
	if sumXX > T.zero {
		proportionalBiasSlope = sumXY / sumXX
	} else {
		proportionalBiasSlope = T.zero
	}

	// --- Coefficient of individual agreement ---
	let cia: T
	if varianceTotal > T.zero {
		cia = varianceWithin / varianceTotal
	} else {
		cia = T.zero
	}

	return RepeatedMeasuresBlandAltmanResult(
		bias: bias,
		varianceBetween: varianceBetween,
		varianceWithin: varianceWithin,
		varianceTotal: varianceTotal,
		loaLower: loaLower,
		loaUpper: loaUpper,
		subjects: n,
		totalObservations: totalN,
		proportionalBiasSlope: proportionalBiasSlope,
		coefficientOfIndividualAgreement: cia
	)
}
