//
//  weightedAverage.swift
//  BusinessMath
//
//  Weighted average calculation
//

import Foundation
import Numerics

/// Calculates the weighted average (weighted mean) of a dataset.
///
/// The weighted average is calculated by multiplying each value by its weight,
/// summing these products, and dividing by the sum of all weights.
///
/// - Parameters:
///   - values: An array of values to average.
///   - weights: An array of weights corresponding to each value.
///
/// - Returns: The weighted average of the dataset.
///
/// - Note: The function follows the formula:
///   \[ \bar{x}_w = \frac{\sum_{i=1}^{n} w_i x_i}{\sum_{i=1}^{n} w_i} \]
///   where \(x_i\) are the values, \(w_i\) are the weights, and \(n\) is the number of values.
///
/// - Precondition: `values` and `weights` must have the same length and weights should sum to a non-zero value.
///
/// - Example:
///   ```swift
///   let grades = [85.0, 90.0, 78.0]
///   let weights = [0.3, 0.5, 0.2]  // Exam 1: 30%, Exam 2: 50%, Exam 3: 20%
///   let finalGrade = weightedAverage(values: grades, weights: weights)
///   // finalGrade ≈ 86.1
///   ```
///
public func weightedAverage<T: Real>(_ values: [T], weights: [T]) -> T {
    guard values.count == weights.count else {
        fatalError("Values and weights arrays must have the same length")
    }
    guard !weights.isEmpty else {
        return T(0)
    }

    let weightedSum = zip(values, weights).map(*).reduce(T(0), +)
    let totalWeight = weights.reduce(T(0), +)

    guard totalWeight != 0 else {
        fatalError("Sum of weights must be non-zero")
    }

    return weightedSum / totalWeight
}
