//
//  kurtosis.swift
//  BusinessMath
//
//  Created by Claude on 2026-02-20.
//

import Foundation
import Numerics

/// Computes the kurtosis of a dataset.
///
/// Kurtosis is a measure of the "tailedness" of a probability distribution. It describes whether the distribution has heavier or lighter tails compared to a normal distribution.
/// Excess kurtosis (kurtosis - 3) is commonly reported, where a normal distribution has an excess kurtosis of 0.
///
/// - Parameters:
///   - values: An array of values representing the dataset.
///   - pop: An enum to determine if you are using a sample or the total population.
/// - Returns: The excess kurtosis of the dataset. Positive values indicate heavy tails (leptokurtic), negative values indicate light tails (platykurtic), and zero indicates normal distribution tails (mesokurtic).
///
/// - Example:
///   ```swift
///   let values: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
///   let result = kurtosis(values, .population)
///   /// result should be the excess kurtosis of the dataset `values`
///   ```
public func kurtosis<T: Real>(_ values: [T], _ pop: Population = .sample) -> T {
	switch pop {
	case .population:
		return kurtosisP(values)
	default:
		return kurtosisS(values)
	}
}

/// Computes the sample excess kurtosis for a given set of values.
///
/// Sample kurtosis is a measure of the tailedness of a probability distribution for sample data.
/// This function computes excess kurtosis (kurtosis - 3), where a normal distribution has excess kurtosis of 0.
///
/// - Parameters:
///	- values: An array of values for which the sample excess kurtosis is to be calculated.
///
/// - Returns: The sample excess kurtosis of the given dataset.
///
/// - Note:
///   - This function uses the sample standard deviation.
///   - Ensure the dataset has at least four values as the formula for sample kurtosis is undefined for fewer values.
///   - Uses the bias-corrected formula with (n-1)(n-2)(n-3) in the denominator.
///
/// - Requires:
///   - Implementation of the `average(_:)` function to compute the mean of an array of values.
///   - Implementation of the `stdDev(_:)` function to compute the sample standard deviation of an array of values.
///
/// - Example:
///   ```swift
///   let data: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0, 10.0]
///   let kurt = kurtosisS(data)
///   print("Sample excess kurtosis of the data: \(kurt)")
///   ```
///
/// - Important:
///   - Ensure that the `values` array contains at least four elements to perform the sample kurtosis calculation.
///   - This is the Excel-compatible formula (KURT function).
public func kurtosisS<T: Real>(_ values: [T]) -> T {
	guard values.count >= 4 else { return T(0) }

	let n = T(values.count)
	let mean = average(values)
	let s = stdDev(values)

	guard s > T(0) else { return T(0) }

	// Calculate fourth moment
	let m4 = values.map { T.pow((($0 - mean) / s), 4) }.reduce(T(0), +)

	// Sample kurtosis with bias correction
	// Break complex expressions into steps to help type checker
	let nPlus1 = n + T(1)
	let nMinus1 = n - T(1)
	let nMinus2 = n - T(2)
	let nMinus3 = n - T(3)

	let numerator1 = n * nPlus1
	let denominator1 = nMinus1 * nMinus2 * nMinus3
	let term1 = numerator1 / denominator1

	let numerator2 = T(3) * nMinus1 * nMinus1
	let denominator2 = nMinus2 * nMinus3
	let term2 = numerator2 / denominator2

	return term1 * m4 - term2
}

/// Computes the population excess kurtosis for a given set of values.
///
/// Population kurtosis is a measure of the tailedness of a probability distribution.
/// This function computes excess kurtosis (kurtosis - 3), where a normal distribution has excess kurtosis of 0.
///
/// - Parameters:
///	- values: An array of values for which the population excess kurtosis is to be calculated.
///
/// - Returns: The population excess kurtosis of the given dataset.
///
/// - Note:
///   - This function uses the population standard deviation.
///   - The formula computes the fourth standardized moment minus 3.
///
/// - Requires:
///   - Implementation of the `average(_:)` function to compute the mean of an array of values.
///   - Implementation of the `stdDevP(_:)` function to compute the population standard deviation of an array of values.
///
/// - Example:
///   ```swift
///   let data: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0, 10.0]
///   let kurt = kurtosisP(data)
///   print("Population excess kurtosis of the data: \(kurt)")
///   ```
///
/// - Important:
///   - Ensure that the `values` array is not empty and has sufficient values for meaningful calculation.
///   - Excel does not have a built-in formula for population kurtosis.
public func kurtosisP<T: Real>(_ values: [T]) -> T {
	guard !values.isEmpty else { return T(0) }

	let n = T(values.count)
	let mean = average(values)
	let s = stdDevP(values)

	guard s > T(0) else { return T(0) }

	// Calculate fourth standardized moment
	let m4 = values.map { T.pow((($0 - mean) / s), 4) }.reduce(T(0), +)

	// Population excess kurtosis
	return (m4 / n) - T(3)
}
