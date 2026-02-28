//
//  arithmeticHarmonicMean.swift
//  
//
//  Created by Justin Purnell on 5/17/23.
//

import Foundation
import Numerics

/// Computes the Arithmetic-Harmonic Mean (AHM) of a dataset.
///
/// The arithmetic-harmonic mean (AHM) is defined as the common limit of two sequences, one arithmetic and one harmonic,
/// that start from a common pair of positive numbers. This mean captures properties of both the arithmetic mean and harmonic mean.
///
/// - Parameters:
///   - values: An array of values for which to compute the arithmetic-harmonic mean.
///   - tolerance: The number of iterations for achieving the desired precision. Defaults to `10000`.
/// - Returns: The arithmetic-harmonic mean of the dataset.
///
/// - Note: The function uses an iterative algorithm to compute the AHM with specific tolerance:
///   1. Initialize `tempX` with the arithmetic mean of the dataset and `tempY` with the harmonic mean of the dataset.
///   2. Iterate by updating `tempX` and `tempY` until the absolute difference between `tempX` and `tempY` is less than the specified tolerance.
///   3. Return the final value of `tempX` or `tempY` (they should be very close).
///
/// - Example:
///   ```swift
///   let values: [Double] = [1.0, 3.0, 5.0, 7.0, 9.0]
///   let result = arithmeticHarmonicMean(values)
///   // result should be the arithmetic-harmonic mean of the dataset `values`

public func arithmeticHarmonicMean<T: Real>(_ values: [T], _ tolerance: Int = 10000) -> T {
	guard !values.isEmpty else { return T(0) }
	var tempX = mean(values)
	var tempY = harmonicMean(values)
	while abs(tempX - tempY) > (T(1) / T(tolerance)) {
		let newTempX = mean([tempX, tempY])
		tempY = harmonicMean([tempX, tempY])
		tempX = newTempX
	}
	return tempX
}
