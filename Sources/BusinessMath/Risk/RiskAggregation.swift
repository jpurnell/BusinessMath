//
//  RiskAggregation.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

public struct RiskAggregator<T: Real & Sendable> {

	// MARK: - Aggregate VaR

	/// Aggregate VaR across entities using the variance-covariance approach.
	///
	/// Interprets `individualVaRs` as the exposure vector v (already in VaR units),
	/// and computes:
	/// VaR(v) = sqrt(vᵀ C v)
	public static func aggregateVaR(
		individualVaRs: [T],
		correlations: [[T]]
	) -> T {
		let n = individualVaRs.count
		precondition(correlations.count == n, "Correlation matrix must be n x n")
		precondition(correlations.allSatisfy { $0.count == n }, "Correlation matrix must be square")

		var totalVariance: T = 0
		// Compute vᵀ C v
		for i in 0..<n {
			for j in 0..<n {
				totalVariance += individualVaRs[i] * correlations[i][j] * individualVaRs[j]
			}
		}

		// Guard against tiny negative due to rounding (valid C should be PSD)
		if totalVariance < 0 && totalVariance > -T.ulpOfOne {
			totalVariance = 0
		}

		return T.sqrt(totalVariance)
	}

	// MARK: - Marginal VaR

	/// Marginal VaR with respect to the provided exposure vector `individualVaRs`.
	///
	/// Given v = `individualVaRs`, VaR = sqrt(vᵀ C v), the marginal contribution is:
	/// dVaR/dv_i = (C v)_i / VaR
	///
	/// This is a true marginal (derivative). The Euler component is v_i * marginal_i.
	public static func marginalVaR(
		entity: Int,
		individualVaRs: [T],
		correlations: [[T]]
	) -> T {
		let n = individualVaRs.count
		precondition(entity >= 0 && entity < n, "Entity index out of bounds")
		precondition(correlations.count == n && correlations.allSatisfy { $0.count == n }, "Correlation matrix must be n x n")

		let portfolioVaR = aggregateVaR(individualVaRs: individualVaRs, correlations: correlations)
		// If portfolioVaR is zero, derivative is undefined; return 0 to avoid NaN.
		if portfolioVaR == 0 { return 0 }

		// Compute (C v)_i
		var Cv_i: T = 0
		for j in 0..<n {
			Cv_i += correlations[entity][j] * individualVaRs[j]
		}

		return Cv_i / portfolioVaR
	}

	// MARK: - Component VaR

	/// Component VaR for each entity using Euler allocation.
	///
	/// Forms exposure vector v = weights .* individualVaRs, computes:
	/// component_i = v_i × (C v)_i / VaR
	/// and returns the vector of components. Sum of components equals portfolio VaR.
	public static func componentVaR(
		individualVaRs: [T],
		weights: [T],
		correlations: [[T]]
	) -> [T] {
		let n = individualVaRs.count
		precondition(weights.count == n, "Weights must match number of entities")
		precondition(correlations.count == n && correlations.allSatisfy { $0.count == n }, "Correlation matrix must be n x n")

		// v = weights .* individualVaRs
		var v = [T](repeating: 0, count: n)
		for i in 0..<n {
			v[i] = weights[i] * individualVaRs[i]
		}

		let portfolioVaR = aggregateVaR(individualVaRs: v, correlations: correlations)
		if portfolioVaR == 0 {
			// All components are zero if portfolio VaR is zero
			return [T](repeating: 0, count: n)
		}

		// Compute C v
		var Cv = [T](repeating: 0, count: n)
		for i in 0..<n {
			var sum: T = 0
			for j in 0..<n {
				sum += correlations[i][j] * v[j]
			}
			Cv[i] = sum
		}

		// Euler components: v_i * (C v)_i / VaR
		var components = [T](repeating: 0, count: n)
		for i in 0..<n {
			components[i] = (v[i] * Cv[i]) / portfolioVaR
		}

		return components
	}
}
