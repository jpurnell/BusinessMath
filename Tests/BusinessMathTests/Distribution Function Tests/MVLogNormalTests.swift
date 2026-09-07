//
//  MVLogNormalTests.swift
//  BusinessMath
//
//  The multivariate lognormal against its own closed forms.
//
//  Every moment of this family has an exact expression in the log-scale parameters:
//
//      E[Xᵢ]        = exp(μᵢ + σᵢ²/2)
//      Var[Xᵢ]      = (exp(σᵢ²) − 1)·exp(2μᵢ + σᵢ²)
//      Cov[Xᵢ, Xⱼ]  = exp(μᵢ + μⱼ + (σᵢ² + σⱼ²)/2)·(exp(ρᵢⱼσᵢσⱼ) − 1)
//
//  So there are two things to check and they are different: that the *reported*
//  moments match those formulas, and that a large *sample* matches them too. The
//  first catches an algebra error, the second catches a sampler wired to the wrong
//  parameters — and a sampler that exponentiates the wrong normal passes the first
//  cleanly.
//
//  The marginals are separately checkable against the package's univariate lognormal,
//  which is itself already tested, so a correlation applied in the wrong place shows
//  up as a broken margin rather than only as a broken covariance.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Multivariate lognormal")
struct MVLogNormalTests {

	private static let logMeans: [Double] = [0.0, 0.5, -0.25]
	private static let logScales: [Double] = [0.30, 0.40, 0.20]
	private static let correlation: [[Double]] = [
		[1.00, 0.60, -0.30],
		[0.60, 1.00, 0.10],
		[-0.30, 0.10, 1.00],
	]

	private static func build() throws -> DistributionMVLogNormal {
		try DistributionMVLogNormal(logMeans: logMeans,
									logStandardDeviations: logScales,
									correlationMatrix: correlation)
	}

	// MARK: - The reported moments against the formulas

	@Test("Reported means and variances match the closed forms")
	func reportedMomentsMatchTheFormulas() throws {
		let distribution = try Self.build()
		for index in 0..<Self.logMeans.count {
			let mu = Self.logMeans[index], sigma = Self.logScales[index]
			let expectedMean: Double = Foundation.exp(mu + sigma * sigma / 2)
			#expect(abs(distribution.expectedValues[index] - expectedMean) < 1e-12,
					"component \(index): mean \(distribution.expectedValues[index]), formula \(expectedMean)")

			let growth: Double = Foundation.exp(sigma * sigma) - 1
			let scale: Double = Foundation.exp(2 * mu + sigma * sigma)
			let expectedVariance: Double = growth * scale
			#expect(abs(distribution.variances[index] - expectedVariance) < 1e-12,
					"component \(index): variance \(distribution.variances[index]), formula \(expectedVariance)")

			// The trap the doc comment names: the mean is not exp(μ). Asserting the
			// gap keeps anyone from "simplifying" the formula into the median.
			#expect(distribution.expectedValues[index] > Foundation.exp(mu),
					"component \(index): the mean does not exceed the median, so the σ²/2 term is missing")
		}
	}

	@Test("Reported covariances match the closed form, including the sign")
	func reportedCovariancesMatchTheFormula() throws {
		let distribution = try Self.build()
		for i in 0..<Self.logMeans.count {
			for j in 0..<Self.logMeans.count {
				let rho = Self.correlation[i][j]
				let si = Self.logScales[i], sj = Self.logScales[j]
				let base: Double = Foundation.exp(Self.logMeans[i] + Self.logMeans[j] + (si * si + sj * sj) / 2)
				let expected: Double = base * (Foundation.exp(rho * si * sj) - 1)
				let got = try #require(distribution.covariance(i, j))
				#expect(abs(got - expected) < 1e-12,
						"cov(\(i),\(j)) = \(got), formula \(expected)")
				// A negative log-correlation must stay negative through the
				// exponential — `exp(ρσσ) − 1` is negative exactly when ρ is.
				#expect((got < 0) == (rho < 0),
						"cov(\(i),\(j)) = \(got) but ρ = \(rho): the sign did not survive")
			}
		}
		// The diagonal of the covariance is the variance, by construction rather than
		// by a separate code path.
		for i in 0..<Self.logMeans.count {
			let diagonal = try #require(distribution.covariance(i, i))
			#expect(abs(diagonal - distribution.variances[i]) < 1e-12,
					"cov(\(i),\(i)) = \(diagonal) but variance is \(distribution.variances[i])")
		}
	}

	@Test("Value correlation is weaker than log correlation, and reported as such")
	func valueCorrelationIsAttenuated() throws {
		let distribution = try Self.build()
		for i in 0..<Self.logMeans.count {
			for j in 0..<Self.logMeans.count where i != j {
				let implied = try #require(distribution.impliedValueCorrelation(i, j))
				let supplied = Self.correlation[i][j]
				// Always strictly closer to zero: the exponential compresses
				// dependence. Anyone reading a correlation off historical *values*
				// and passing it here gets less than they intended, and this is the
				// method that makes that visible.
				#expect(abs(implied) < abs(supplied) + 1e-12,
						"implied \(implied) is not attenuated relative to \(supplied)")
				#expect(abs(implied) > 0, "implied correlation vanished for ρ = \(supplied)")
				#expect((implied < 0) == (supplied < 0), "the sign changed")
			}
			// Perfect self-correlation survives exactly.
			let ownCorrelation = try #require(distribution.impliedValueCorrelation(i, i))
			#expect(abs(ownCorrelation - 1) < 1e-12, "self-correlation is \(ownCorrelation)")
		}
	}

	// MARK: - The sample against the same formulas

	@Test("A large sample reproduces the closed-form moments")
	func sampleMatchesTheClosedForms() throws {
		let distribution = try Self.build()
		var generator = DeterministicRNG(seed: 46_201)
		let count = 400_000
		var columns = [[Double]](repeating: [], count: distribution.dimension)
		for index in 0..<distribution.dimension { columns[index].reserveCapacity(count) }

		for _ in 0..<count {
			let draw = distribution.sample(using: &generator)
			for index in 0..<draw.count { columns[index].append(draw[index]) }
		}

		// Every draw positive — the defining property, and the reason to use this
		// rather than correlated normals for a cost or a duration.
		for (index, column) in columns.enumerated() {
			#expect(column.allSatisfy { $0 > 0 }, "component \(index) produced a non-positive value")
		}

		let means = columns.map { $0.reduce(0, +) / Double($0.count) }
		for index in 0..<distribution.dimension {
			let exact = distribution.expectedValues[index]
			// 1.5% relative. A lognormal mean converges slowly because the estimator
			// is dominated by the upper tail; at 400,000 draws this is the honest
			// bound, and tightening it would be asserting about the seed.
			#expect(abs(means[index] - exact) / exact < 0.015,
					"component \(index): sampled mean \(means[index]), exact \(exact)")
		}

		for i in 0..<distribution.dimension {
			for j in 0..<distribution.dimension {
				var total = 0.0
				for k in 0..<count {
					let a: Double = columns[i][k] - means[i]
					let b: Double = columns[j][k] - means[j]
					total += a * b
				}
				let sampled: Double = total / Double(count - 1)
				let exact = try #require(distribution.covariance(i, j))
				let scale = Swift.max(abs(exact), 1e-3)
				#expect(abs(sampled - exact) / scale < 0.06,
						"cov(\(i),\(j)): sampled \(sampled), exact \(exact)")
			}
		}
	}

	@Test("Each margin is the univariate lognormal it claims to be")
	func marginsMatchTheUnivariateLogNormal() throws {
		let distribution = try Self.build()
		var generator = DeterministicRNG(seed: 46_202)
		let count = 200_000
		var columns = [[Double]](repeating: [], count: distribution.dimension)
		for _ in 0..<count {
			let draw = distribution.sample(using: &generator)
			for index in 0..<draw.count { columns[index].append(draw[index]) }
		}

		for index in 0..<distribution.dimension {
			let margin = try #require(distribution.marginal(index))
			var sorted = columns[index]
			sorted.sort()
			// Comparing quantiles rather than moments: a correlation applied to the
			// wrong axis leaves the moments plausible and bends the shape.
			for p in [0.05, 0.25, 0.5, 0.75, 0.95] {
				let empirical = quantile(sorted: sorted, p: p)
				let exact = margin.quantile(p)
				#expect(abs(empirical - exact) / exact < 0.02,
						"component \(index) at p=\(p): sampled \(empirical), margin \(exact)")
			}
		}
	}

	@Test("A seed reproduces the stream exactly, and a different seed moves it")
	func samplingIsReproducible() throws {
		let distribution = try Self.build()
		var first = DeterministicRNG(seed: 46_203)
		var second = DeterministicRNG(seed: 46_203)
		var third = DeterministicRNG(seed: 46_204)

		var matched = 0
		var differed = false
		for _ in 0..<500 {
			let a = distribution.sample(using: &first)
			let b = distribution.sample(using: &second)
			let c = distribution.sample(using: &third)
			#expect(a == b, "the same seed produced \(a) and \(b)")
			matched += 1
			if a != c { differed = true }
		}
		#expect(matched == 500)
		// Otherwise the seed is being ignored and reproducibility is vacuous.
		#expect(differed, "a different seed produced an identical stream")
	}

	// MARK: - Refusals

	@Test("Arguments that do not describe a distribution are refused by name")
	func invalidArgumentsAreRefused() {
		let identity: [[Double]] = [[1, 0], [0, 1]]
		#expect(throws: MVLogNormalError.dimensionMismatch) {
			_ = try DistributionMVLogNormal(logMeans: [0, 0, 0],
											logStandardDeviations: [1, 1],
											correlationMatrix: identity)
		}
		// A zero scale makes that margin a constant, which silently changes what
		// every covariance involving it means.
		#expect(throws: MVLogNormalError.nonPositiveScale) {
			_ = try DistributionMVLogNormal(logMeans: [0, 0],
											logStandardDeviations: [1, 0],
											correlationMatrix: identity)
		}
		#expect(throws: MVLogNormalError.nonFiniteLocation) {
			_ = try DistributionMVLogNormal(logMeans: [0, .nan],
											logStandardDeviations: [1, 1],
											correlationMatrix: identity)
		}
		// Not positive semi-definite: no set of correlated normals has this matrix.
		#expect(throws: MVLogNormalError.invalidCorrelationMatrix) {
			_ = try DistributionMVLogNormal(logMeans: [0, 0, 0],
											logStandardDeviations: [1, 1, 1],
											correlationMatrix: [[1, 0.9, -0.9], [0.9, 1, 0.9], [-0.9, 0.9, 1]])
		}
	}
}
