//
//  Population.swift
//  BusinessMath
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation

/// Specifies whether statistical calculations use population or sample formulas.
///
/// Many statistical measures (e.g., variance, standard deviation) have different
/// formulas depending on whether you're working with:
/// - **Population**: Complete dataset (divide by N)
/// - **Sample**: Subset of population (divide by N-1 for Bessel's correction)
///
/// ## Example
/// ```swift
/// let data = [12.0, 15.0, 11.0, 18.0, 14.0]
/// let populationVariance = variance(data, .population)
/// let sampleVariance = variance(data, .sample)  // More common
/// ```
///
/// - Note: Default to `.sample` in most cases, as complete populations are rare in practice
public enum Population: String {
    /// Use population formulas (complete dataset)
    case population

    /// Use sample formulas with Bessel's correction (recommended default)
    case sample
}
