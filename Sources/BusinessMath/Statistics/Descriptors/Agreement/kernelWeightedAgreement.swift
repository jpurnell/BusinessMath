import Foundation
import Numerics

/// Kernel-weighted concordance correlation coefficient at a target value.
///
/// Computes CCC with observations weighted by their proximity to a target
/// measurement level. This reveals how agreement varies across the
/// measurement range.
///
/// - Parameters:
///   - x: First measurement series.
///   - y: Second measurement series (same length as x).
///   - target: The measurement level to weight toward.
///   - bandwidth: Smoothing bandwidth for the kernel.
///   - kernel: Kernel function (default: Gaussian).
///   - confidence: Confidence level for the interval (default: 0.95).
///
/// - Returns: `CCCResult` with kernel-weighted CCC and confidence interval.
///
/// - Throws: `BusinessMathError.mismatchedDimensions` if arrays differ in length.
/// - Throws: `BusinessMathError.insufficientData` if effective sample size is too small.
/// - Throws: `BusinessMathError.invalidInput` if bandwidth is not positive.
public func kernelWeightedCCC<T: Real>(
	_ x: [T], _ y: [T],
	target: T, bandwidth: T,
	kernel: KernelFunction = .gaussian,
	confidence: T = T(95) / T(100)
) throws -> CCCResult<T> where T: BinaryFloatingPoint {
	let weights = try kernelWeights(x, y, target: target, bandwidth: bandwidth, kernel: kernel)

	// Check that total weight is sufficient for meaningful estimation
	let totalWeight = weights.reduce(T.zero, +)
	guard totalWeight > T.zero else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: 0,
			context: "Kernel weights sum to zero at target \(target) — no observations are effectively weighted")
	}

	// Effective sample size: n_eff = (sum(w))^2 / sum(w^2)
	let sumWSq = weights.reduce(T.zero) { acc, w in acc + w * w }
	guard sumWSq > T.zero else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: 0,
			context: "Kernel-weighted effective sample size is zero")
	}
	let nEff = (totalWeight * totalWeight) / sumWSq
	guard nEff >= T(2) else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: Int(nEff),
			context: "Kernel-weighted effective sample size (\(nEff)) is too small for CCC estimation")
	}

	return try concordanceCorrelationCoefficient(x, y, weights: weights, confidence: confidence)
}

/// CCC profile: kernel-weighted CCC evaluated at multiple target values.
///
/// Produces a profile showing how agreement varies across the measurement
/// range. Targets where the effective sample size is too small (e.g., extreme
/// values) are silently skipped.
///
/// - Parameters:
///   - x: First measurement series.
///   - y: Second measurement series (same length as x).
///   - targets: Array of target values to evaluate.
///   - bandwidth: Smoothing bandwidth for the kernel.
///   - kernel: Kernel function (default: Gaussian).
///
/// - Returns: Array of (target, CCCResult) tuples for each successfully evaluated target.
///
/// - Throws: `BusinessMathError.mismatchedDimensions` if arrays differ in length.
/// - Throws: `BusinessMathError.insufficientData` if x or y have fewer than 2 elements.
public func cccProfile<T: Real>(
	_ x: [T], _ y: [T],
	targets: [T], bandwidth: T,
	kernel: KernelFunction = .gaussian
) throws -> [(target: T, ccc: CCCResult<T>)] where T: BinaryFloatingPoint {
	guard x.count == y.count else {
		throw BusinessMathError.mismatchedDimensions(
			message: "Arrays must have equal length",
			expected: "\(x.count)", actual: "\(y.count)")
	}
	guard x.count >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: x.count,
			context: "CCC profile requires at least 2 paired observations")
	}

	var results: [(target: T, ccc: CCCResult<T>)] = []

	for t in targets {
		do {
			let result = try kernelWeightedCCC(
				x, y, target: t, bandwidth: bandwidth, kernel: kernel)
			results.append((target: t, ccc: result))
		} catch is BusinessMathError {
			// silent: skip targets where effective sample size is insufficient
			continue
		}
	}

	return results
}
