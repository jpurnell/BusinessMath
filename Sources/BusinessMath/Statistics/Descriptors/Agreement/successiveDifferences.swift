import Foundation
import Numerics

/// Compute the absolute successive differences of a series.
///
/// Returns an array of `|values[i] - values[i-1]|` for i in 1..<count.
/// The result has length `values.count - 1`.
///
/// Useful for N-N interval analysis (HRV), rate-of-change studies, and
/// composing with other metrics: e.g., `mape(successiveDifferences(a), successiveDifferences(b))`
/// gives N-N MAPE directly.
///
/// - Parameter values: Input series.
/// - Returns: Absolute successive differences.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 values.
public func successiveDifferences<T: Real>(_ values: [T]) throws -> [T] {
	guard values.count >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: values.count,
			context: "Successive differences requires at least 2 values")
	}

	return zip(values.dropFirst(), values).map { later, earlier in
		abs(later - earlier)
	}
}
