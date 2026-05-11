import Foundation
import Numerics

/// Kernel function for weighting observations by distance.
///
/// Used with kernel-weighted agreement statistics to emphasize observations
/// near a target value while down-weighting distant observations.
public enum KernelFunction: Sendable {
	/// Gaussian kernel: K(u) = exp(-u^2/2) / sqrt(2*pi).
	case gaussian
	/// Epanechnikov kernel: K(u) = (3/4)(1-u^2) for |u| <= 1, else 0.
	case epanechnikov
	/// Uniform kernel: K(u) = 1/2 for |u| <= 1, else 0.
	case uniform
	/// Triangular kernel: K(u) = 1-|u| for |u| <= 1, else 0.
	case triangular
}

/// Bandwidth selection method for kernel-weighted statistics.
///
/// Controls how the smoothing bandwidth is chosen for kernel density estimation
/// and kernel-weighted agreement statistics.
public enum BandwidthMethod: Sendable {
	/// Silverman's rule of thumb: h = 0.9 * min(sigma, IQR/1.34) * n^(-1/5).
	case silverman
	/// Leave-one-out cross-validation: minimizes LOO prediction error over a grid.
	case crossValidation
}

/// Evaluates a kernel function at a given standardized distance.
///
/// - Parameters:
///   - u: Standardized distance (x - target) / bandwidth.
///   - kernel: The kernel function to use.
/// - Returns: Kernel density value at u.
private func evaluateKernel<T: Real>(_ u: T, kernel: KernelFunction) -> T {
	switch kernel {
	case .gaussian:
		let twoPi = T(2) * T.pi
		return T.exp(-u * u / T(2)) / T.sqrt(twoPi)
	case .epanechnikov:
		guard abs(u) <= T(1) else { return T.zero }
		return T(3) / T(4) * (T(1) - u * u)
	case .uniform:
		guard abs(u) <= T(1) else { return T.zero }
		return T(1) / T(2)
	case .triangular:
		guard abs(u) <= T(1) else { return T.zero }
		return T(1) - abs(u)
	}
}

/// Computes kernel weights for paired observations.
///
/// Weights each pair by the distance of its mean from a target value.
/// `w_i = K((m_i - target) / bandwidth)` where `m_i = (x_i + y_i) / 2`.
///
/// - Parameters:
///   - x: First measurement series.
///   - y: Second measurement series (same length as x).
///   - target: The value around which to center the weighting.
///   - bandwidth: Smoothing bandwidth (must be positive).
///   - kernel: The kernel function to use (default: Gaussian).
///
/// - Returns: Array of non-negative weights, one per observation pair.
///
/// - Throws: `BusinessMathError.mismatchedDimensions` if arrays differ in length.
/// - Throws: `BusinessMathError.invalidInput` if bandwidth is not positive.
/// - Throws: `BusinessMathError.insufficientData` if arrays are empty.
public func kernelWeights<T: Real>(
	_ x: [T], _ y: [T],
	target: T, bandwidth: T,
	kernel: KernelFunction = .gaussian
) throws -> [T] {
	guard x.count == y.count else {
		throw BusinessMathError.mismatchedDimensions(
			message: "Arrays must have equal length",
			expected: "\(x.count)", actual: "\(y.count)")
	}
	guard !x.isEmpty else {
		throw BusinessMathError.insufficientData(
			required: 1, actual: 0,
			context: "Kernel weights require at least 1 observation pair")
	}
	guard bandwidth > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Bandwidth must be positive",
			value: "\(bandwidth)", expectedRange: "(0, +inf)")
	}

	return zip(x, y).map { xi, yi in
		let pairMean = (xi + yi) / T(2)
		let u = (pairMean - target) / bandwidth
		return evaluateKernel(u, kernel: kernel)
	}
}

/// Selects an optimal bandwidth for kernel-weighted agreement.
///
/// - Silverman's rule: `h = 0.9 * min(sigma, IQR/1.34) * n^(-1/5)`
/// - Cross-validation: minimizes leave-one-out kernel density estimate error
///   over a grid of candidate bandwidths.
///
/// - Parameters:
///   - values: Sample values to estimate bandwidth for.
///   - method: Bandwidth selection method (default: Silverman).
///
/// - Returns: Optimal bandwidth (positive value).
///
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 values.
public func selectBandwidth<T: Real>(
	_ values: [T], method: BandwidthMethod = .silverman
) throws -> T where T: BinaryFloatingPoint {
	guard values.count >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: values.count,
			context: "Bandwidth selection requires at least 2 values")
	}

	let n = T(values.count)
	let sigma = stdDev(values, .sample)

	let sorted = values.sorted()

	// Compute IQR using simple index-based percentile
	let q25 = sortedPercentile(sorted, p: T(25) / T(100))
	let q75 = sortedPercentile(sorted, p: T(75) / T(100))
	let iqr = q75 - q25

	// Silverman bandwidth
	let spread = iqr / T(134) * T(100) // IQR / 1.34
	let minSpread: T
	if spread > T.zero {
		minSpread = min(sigma, spread)
	} else {
		minSpread = sigma
	}
	let silverman = T(9) / T(10) * minSpread * T.pow(n, T(-1) / T(5))

	guard silverman > T.zero else {
		// Data has no spread; return a small positive value
		return T(1) / T(10)
	}

	switch method {
	case .silverman:
		return silverman

	case .crossValidation:
		return crossValidationBandwidth(sorted, silverman: silverman)
	}
}

/// Computes a percentile from a pre-sorted array using linear interpolation.
///
/// - Parameters:
///   - sorted: A sorted array of values.
///   - p: Percentile in [0, 1].
/// - Returns: The interpolated percentile value.
private func sortedPercentile<T: Real>(_ sorted: [T], p: T) -> T where T: BinaryFloatingPoint {
	let n = sorted.count
	guard n > 1 else { return sorted[0] }

	let index = p * T(n - 1)
	let lower = Int(Double(index)) // truncates toward zero, same as floor for non-negative
	let upper = min(lower + 1, n - 1)
	let fraction = index - T(lower)

	return sorted[lower] + fraction * (sorted[upper] - sorted[lower])
}

/// Cross-validation bandwidth selection using leave-one-out density estimation.
///
/// Searches a grid of 20 candidates from 0.1*silverman to 3*silverman and
/// picks the bandwidth that minimizes the integrated squared error proxy.
private func crossValidationBandwidth<T: Real>(
	_ sorted: [T], silverman: T
) -> T where T: BinaryFloatingPoint {
	let n = sorted.count
	let gridSize = 20
	let hMin = silverman / T(10)
	let hMax = silverman * T(3)
	let step = (hMax - hMin) / T(gridSize - 1)

	var bestH = silverman
	var bestScore = T.infinity

	for g in 0..<gridSize {
		let h = hMin + T(g) * step
		guard h > T.zero else { continue }

		// LOO cross-validation score: sum of -log f_{-i}(x_i)
		// f_{-i}(x_i) = 1/((n-1)*h) * sum_{j != i} K((x_i - x_j)/h)
		var score = T.zero

		for i in 0..<n {
			var density = T.zero
			for j in 0..<n where j != i {
				let u = (sorted[i] - sorted[j]) / h
				let twoPi = T(2) * T.pi
				density += T.exp(-u * u / T(2)) / T.sqrt(twoPi)
			}
			density /= (T(n - 1) * h)

			if density > T.zero {
				score -= T.log(density)
			} else {
				score += T(1000) // penalty for zero density
			}
		}

		if score < bestScore {
			bestScore = score
			bestH = h
		}
	}

	return bestH
}
