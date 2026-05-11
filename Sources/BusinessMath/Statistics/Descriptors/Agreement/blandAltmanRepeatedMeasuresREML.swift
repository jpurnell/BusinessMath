import Foundation
import Numerics

/// Bland-Altman analysis with repeated measures using a specified variance
/// estimation method.
///
/// Accounts for within-subject correlation when each subject contributes
/// multiple paired measurements. Supports either method-of-moments (ANOVA)
/// or REML for estimating variance components. REML is preferred for
/// unbalanced designs or when method-of-moments produces boundary estimates.
///
/// - Parameters:
///   - pairs: Array of subjects, where each subject is an array of
///     `(x, y)` tuples representing paired measurements.
///   - method: The variance estimation method to use. Defaults to
///     ``VarianceEstimationMethod/methodOfMoments``.
/// - Returns: Repeated-measures Bland-Altman result with variance decomposition.
/// - Throws: ``BusinessMathError/insufficientData(required:actual:context:)``
///   if fewer than 2 subjects, any subject has fewer than 1 pair, or total
///   observations do not exceed the number of subjects.
public func blandAltmanRepeatedMeasures<T: Real>(
	_ pairs: [[(x: T, y: T)]],
	method: VarianceEstimationMethod
) throws -> RepeatedMeasuresBlandAltmanResult<T> {

	switch method {
	case .methodOfMoments:
		return try blandAltmanRepeatedMeasures(pairs)

	case .reml:
		return try blandAltmanRepeatedMeasuresREML(pairs)
	}
}

// MARK: - REML-based implementation

/// Internal implementation of repeated-measures Bland-Altman using REML.
private func blandAltmanRepeatedMeasuresREML<T: Real>(
	_ pairs: [[(x: T, y: T)]]
) throws -> RepeatedMeasuresBlandAltmanResult<T> {

	// --- Validation (same as original) ---
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

	let n = pairs.count
	let totalN = allDifferences.count

	// --- REML variance decomposition ---
	let reml = try remlVarianceComponents(groups)

	let varianceBetween = reml.varianceBetween
	let varianceWithin = reml.varianceWithin
	let varianceTotal = varianceBetween + varianceWithin

	// Use the REML fixed intercept as the bias (GLS estimate of mu)
	let bias = reml.fixedIntercept

	// --- Modified limits of agreement ---
	let z95 = T(196) / T(100) // 1.96
	let loaHalf = z95 * T.sqrt(varianceTotal)
	let loaLower = bias - loaHalf
	let loaUpper = bias + loaHalf

	// --- Proportional bias: regress all differences on all means ---
	let meanOfMeans = allMeans.reduce(T.zero, +) / T(totalN)
	let meanOfDiffs = allDifferences.reduce(T.zero, +) / T(totalN)

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
