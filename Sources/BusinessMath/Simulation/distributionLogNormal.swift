//
//  distributionLogNormal.swift
//  
//
//  Created by Justin Purnell on 3/28/22.
//

import Foundation
import Numerics

// https://en.wikipedia.org/wiki/Log-normal_distribution#Related_distributions

/// Returns a log normal distribution of values with mean µ and standard deviation σ
/// - Parameters:
///   - mean: The mean of the distribution
///   - stdDev: The standard deviation of the distribution
/// - Returns: A Log Normal distributed value, x, centered on the mean µ with a standard deviation of σ. Running this function many times will generate an array of values that is distributed log normally around µ with std dev of σ
public func distributionLogNormal<T: Real>(mean: T = T(0), stdDev: T = T(1)) -> T {
    return T.exp(distributionNormal(mean: mean, stdDev: stdDev))
}

	/// Returns a log normal distribution of values with mean µ and variance σ^s
	/// - Parameters:
	///   - mean: The mean of the distribution
	///   - variance: The standard deviation of the distribution
	/// - Returns: A Log Normal distributed value, x, centered on the mean µ with a variance of σ^2. Running this function many times will generate an array of values that is distributed log normally around µ with variance of σ^2
public func distributionLogNormal<T: Real>(mean: T = T(0), variance: T = T(1)) -> T {
    return T.exp(distributionNormal(mean: mean, variance: variance))
}

