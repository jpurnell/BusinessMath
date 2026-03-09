//
//  contraharmonicMean.swift
//  
//
//  Created by Justin Purnell on 1/6/24.
//

import Foundation
import Numerics

///Provides the contraharmonic mean, i.e. the ratio of the sum of squares to the sum: https://www.johndcook.com/blog/2023/05/20/contraharmonic-mean/
	/// Computes the contraharmonic mean of a two numbers.
	///
	/// The contraharmonic mean is a type of average, computed as the ratio of the sum of the squares of the values to the sum of the values.
	///
	/// - Parameters:
	///   - x: An array of values for which to compute the contraharmonic mean.
	///   - y: Second number
	/// - Returns: The contraharmonic mean of the dataset.
	///
	/// - Note: The function computes the contraharmonic mean using the formula:
	///   \[ C = \frac{\sum_{i=1}^{n} x_i^2}{\sum_{i=1}^{n} x_i} \]
	///   where \( x_i \) are the values in the dataset and \( n \) is the number of values.
	///
	/// - Example:
	///   ```swift
	///   let x = 2.0
	///   let y = 6.0
	///   let result = contraharmonicMean(values)
	///   // result should be the contraharmonic mean of the dataset `values`

/// - Throws: `BusinessMathError.divisionByZero` if x + y = 0 (when x = -y).
public func contraharmonicMean<T: Real>(_ x: T, _ y: T) throws -> T {
	let denominator = x + y
	guard denominator.magnitude > T.ulpOfOne else {
		throw BusinessMathError.divisionByZero(
			context: "Contraharmonic mean: sum of values is zero (x = -y)"
		)
	}
	return (T.pow(x, T(2)) + T.pow(y, T(2))) / denominator
}

/// Computes the contraharmonic mean of a dataset.
///
/// The contraharmonic mean is a type of average, computed as the ratio of the sum of the squares of the values to the sum of the values.
///
/// - Parameters:
///   - values: An array of values for which to compute the contraharmonic mean.
/// - Returns: The contraharmonic mean of the dataset.
///
/// - Note: The function computes the contraharmonic mean using the formula:
///   \[ C = \frac{\sum_{i=1}^{n} x_i^2}{\sum_{i=1}^{n} x_i} \]
///   where \( x_i \) are the values in the dataset and \( n \) is the number of values.
///
/// - Example:
///   ```swift
///   let values: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
///   let result = contraharmonicMean(values)
///   // result should be the contraharmonic mean of the dataset `values`

/// - Throws: `BusinessMathError.divisionByZero` if the sum of values is zero.
/// - Throws: `ArrayError.emptyArray` if the array is empty.
public func contraharmonicMean<T: Real>(_ values: [T]) throws -> T {
	guard !values.isEmpty else {
		throw ArrayError.emptyArray
	}
	let denominator = values.reduce(T(0), +)
	guard denominator.magnitude > T.ulpOfOne else {
		throw BusinessMathError.divisionByZero(
			context: "Contraharmonic mean: sum of values is zero"
		)
	}
	return values.map({T.pow($0, T(2))}).reduce(T(0), +) / denominator
}

