//
//  ContinuousShapeDistributionTests.swift
//  BusinessMath
//
//  Gamma, chi-squared and Student's t with real-valued shapes.
//
//  Three kinds of oracle, in descending order of how much they prove.
//
//  Closed forms first, because they are exact and owe nothing to a reference
//  implementation: `χ²(2)` is an exponential with mean two, so its quantile is
//  `−2·ln(1−p)`; `χ²(1)` is the square of a standard normal, so its quantile is
//  `Φ⁻¹((1+p)/2)²`; `Gamma(1, λ)` is an exponential; and `t(1)` is Cauchy, whose
//  quantile is `tan(π(p − ½))`. Each of those routes through the continuous code path
//  and lands on a number known in advance.
//
//  Then SciPy, for the fractional shapes that have no closed form — `χ²(2.5)`,
//  `t(7.3)`, `Gamma(7.3, 0.4)`. These are the cases that could not be expressed at all
//  before, so a reference from outside the library is the only check available.
//
//  Then the identities between the three families, which catch a parameterisation
//  error the individual checks would not: a rate read as a scale gives a Gamma that is
//  wrong by θ² and entirely plausible on its own.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Continuous shapes: gamma, chi-squared, Student's t")
struct ContinuousShapeDistributionTests {

	// MARK: - Closed forms

	@Test("Chi-squared with two degrees of freedom is an exponential with mean two")
	func chiSquaredTwoIsExponential() throws {
		let d = try #require(DistributionChiSquared(degreesOfFreedom: 2.0))
		var checked = 0
		for p in [0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99] {
			let got: Double = d.quantile(p)
			let complement: Double = 1 - p
			let wanted: Double = -2 * Double.log(complement)
			#expect(Swift.abs(got - wanted) < wanted * 1e-9,
					"at p=\(p): got \(got), exponential says \(wanted)")
			checked += 1
		}
		#expect(checked == 7, "only \(checked) probabilities were checked")
	}

	@Test("Chi-squared with one degree of freedom is a squared standard normal")
	func chiSquaredOneIsSquaredNormal() throws {
		let d = try #require(DistributionChiSquared(degreesOfFreedom: 1.0))
		var checked = 0
		for p in [0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99] {
			let got: Double = d.quantile(p)
			let upper: Double = (1 + p) / 2
			let z: Double = inverseNormalCDF(p: upper, mean: 0, stdDev: 1)
			let wanted: Double = z * z
			#expect(Swift.abs(got - wanted) < wanted * 1e-8,
					"at p=\(p): got \(got), Z² says \(wanted)")
			checked += 1
		}
		#expect(checked == 7, "only \(checked) probabilities were checked")
	}

	@Test("A gamma with unit shape is an exponential, in both parameterisations")
	func gammaWithUnitShapeIsExponential() throws {
		var checked = 0
		for rate in [0.5, 1.0, 4.0] {
			let byRate = try #require(DistributionGamma(shape: 1, rate: rate))
			let scale: Double = 1 / rate
			let byScale = try #require(DistributionGamma(shape: 1, scale: scale))
			for p in [0.1, 0.5, 0.9, 0.99] {
				let complement: Double = 1 - p
				let logTerm: Double = -Double.log(complement)
				let wanted: Double = logTerm / rate
				let got: Double = byRate.quantile(p)
				#expect(Swift.abs(got - wanted) < wanted * 1e-9,
						"rate \(rate) at p=\(p): got \(got), exponential says \(wanted)")
				// The two spellings must agree, which is what catches a rate read as a
				// scale — an error that is invisible in either one alone.
				let mirrored: Double = byScale.quantile(p)
				#expect(Swift.abs(mirrored - got) < Swift.max(got, 1) * 1e-12,
						"rate and scale spellings disagree: \(got) versus \(mirrored)")
				checked += 1
			}
		}
		#expect(checked == 12, "only \(checked) comparisons ran")
	}

	@Test("Student's t with one degree of freedom is Cauchy")
	func studentTOneIsCauchy() throws {
		let d = try #require(DistributionStudentT(degreesOfFreedom: 1.0))
		var checked = 0
		for p in [0.05, 0.1, 0.25, 0.4, 0.6, 0.75, 0.9, 0.95] {
			let got: Double = d.quantile(p)
			let shifted: Double = p - 0.5
			let angle: Double = Double.pi * shifted
			let wanted: Double = Double.tan(angle)
			let scale: Double = Swift.max(Swift.abs(wanted), 1)
			#expect(Swift.abs(got - wanted) < scale * 1e-8,
					"at p=\(p): got \(got), Cauchy says \(wanted)")
			checked += 1
		}
		#expect(checked == 8, "only \(checked) probabilities were checked")
		// The quartile of a standard Cauchy is exactly one.
		#expect(Swift.abs(d.quantile(0.75) - 1) < 1e-9, "the Cauchy quartile is \(d.quantile(0.75))")
		// And its density at zero is 1/π.
		let atZero: Double = d.pdf(0)
		let wantedDensity: Double = 1 / Double.pi
		#expect(Swift.abs(atZero - wantedDensity) < 1e-12, "the Cauchy peak is \(atZero)")
	}

	// MARK: - Against SciPy, where no closed form exists

	@Test("Fractional degrees of freedom match an external reference")
	func fractionalShapesAgainstReference() throws {
		// scipy.stats, computed outside this library.
		let chiSquared: [(df: Double, p: Double, value: Double)] = [
			(0.5, 0.95, 2.4202322749), (0.5, 0.5, 0.0873476047),
			(2.5, 0.95, 6.9280761135), (2.5, 0.5, 1.8738477678),
			(7.5, 0.95, 14.7911623535), (7.5, 0.5, 6.8449054696),
		]
		var checked = 0
		for row in chiSquared {
			let d = try #require(DistributionChiSquared(degreesOfFreedom: row.df))
			let got: Double = d.quantile(row.p)
			#expect(Swift.abs(got - row.value) < row.value * 1e-7,
					"χ²(\(row.df)) at p=\(row.p): got \(got), scipy \(row.value)")
			checked += 1
		}

		let gamma: [(shape: Double, scale: Double, p: Double, value: Double)] = [
			(0.5, 2.0, 0.9, 2.7055434541),
			(2.5, 1.5, 0.9, 6.9272676748),
			(7.3, 0.4, 0.9, 4.3621957650),
		]
		for row in gamma {
			let d = try #require(DistributionGamma(shape: row.shape, scale: row.scale))
			let got: Double = d.quantile(row.p)
			#expect(Swift.abs(got - row.value) < row.value * 1e-7,
					"Gamma(\(row.shape), \(row.scale)) at p=\(row.p): got \(got), scipy \(row.value)")
			checked += 1
		}

		let student: [(df: Double, p: Double, value: Double)] = [
			(1, 0.975, 12.7062047362), (2, 0.975, 4.3026527297),
			(3, 0.975, 3.1824463053), (5, 0.975, 2.5705818356),
			(10, 0.975, 2.2281388520), (30, 0.975, 2.0422724563),
			(100, 0.975, 1.9839715185), (2.5, 0.99, 5.3531111730),
			(7.3, 0.05, -1.8829300180),
		]
		for row in student {
			let d = try #require(DistributionStudentT(degreesOfFreedom: row.df))
			let got: Double = d.quantile(row.p)
			let scale: Double = Swift.abs(row.value)
			#expect(Swift.abs(got - row.value) < scale * 1e-7,
					"t(\(row.df)) at p=\(row.p): got \(got), scipy \(row.value)")
			checked += 1
		}
		#expect(checked == 18, "only \(checked) of 18 reference values were checked")
	}

	// MARK: - Identities between the families

	@Test("Chi-squared is the gamma it claims to be")
	func chiSquaredIsAGamma() throws {
		var checked = 0
		for df in [0.5, 1.0, 2.0, 2.5, 7.5, 30.0] {
			let chi = try #require(DistributionChiSquared(degreesOfFreedom: df))
			let half: Double = df / 2
			let gamma = try #require(DistributionGamma(shape: half, scale: 2))
			for p in [0.05, 0.5, 0.95] {
				let a: Double = chi.quantile(p)
				let b: Double = gamma.quantile(p)
				let scale: Double = Swift.max(Swift.abs(a), 1)
				#expect(Swift.abs(a - b) < scale * 1e-10,
						"ν=\(df) at p=\(p): χ² \(a), Gamma \(b)")
				checked += 1
			}
		}
		#expect(checked == 18, "only \(checked) comparisons ran")
	}

	@Test("A t with many degrees of freedom converges on the normal")
	func studentTApproachesNormal() throws {
		let d = try #require(DistributionStudentT(degreesOfFreedom: 100_000))
		let normal = DistributionNormal(0, 1)
		var checked = 0
		for p in [0.05, 0.25, 0.5, 0.75, 0.95, 0.99] {
			let got: Double = d.quantile(p)
			let wanted: Double = normal.quantile(p)
			let scale: Double = Swift.max(Swift.abs(wanted), 1)
			#expect(Swift.abs(got - wanted) < scale * 1e-4,
					"at p=\(p): t \(got), normal \(wanted)")
			checked += 1
		}
		#expect(checked == 6, "only \(checked) probabilities were checked")
	}

	// MARK: - The contract

	@Test("Every quantile round-trips through the CDF")
	func quantileRoundTrips() throws {
		let gamma = try #require(DistributionGamma(shape: 3.7, rate: 0.8))
		let chi = try #require(DistributionChiSquared(degreesOfFreedom: 4.2))
		let student = try #require(DistributionStudentT(degreesOfFreedom: 6.5))
		var checked = 0
		for p in [0.02, 0.15, 0.4, 0.5, 0.6, 0.85, 0.98] {
			let g: Double = gamma.cdf(gamma.quantile(p))
			let c: Double = chi.cdf(chi.quantile(p))
			let t: Double = student.cdf(student.quantile(p))
			#expect(Swift.abs(g - p) < 1e-8, "gamma round-trip at \(p) gave \(g)")
			#expect(Swift.abs(c - p) < 1e-8, "chi-squared round-trip at \(p) gave \(c)")
			#expect(Swift.abs(t - p) < 1e-8, "t round-trip at \(p) gave \(t)")
			checked += 3
		}
		#expect(checked == 21, "only \(checked) round-trips ran")
	}

	@Test("The t is symmetric and its moments stop where they should")
	func studentTMoments() throws {
		let d = try #require(DistributionStudentT(degreesOfFreedom: 8))
		for p in [0.05, 0.2, 0.45] {
			let low: Double = d.quantile(p)
			let high: Double = d.quantile(1 - p)
			#expect(Swift.abs(low + high) < 1e-9, "Q(\(p)) and Q(\(1 - p)) are not mirrored")
		}
		// ν/(ν−2) = 8/6
		let variance = try #require(d.variance)
		let wanted: Double = 8.0 / 6.0
		#expect(Swift.abs(variance - wanted) < 1e-12, "variance is \(variance)")
		// 6/(ν−4) = 6/4
		let kurtosis = try #require(d.excessKurtosis)
		#expect(Swift.abs(kurtosis - 1.5) < 1e-12, "excess kurtosis is \(kurtosis)")

		// A Cauchy has no mean, and saying zero because the density is symmetric would
		// be the plausible wrong answer.
		let cauchy = try #require(DistributionStudentT(degreesOfFreedom: 1))
		#expect(cauchy.mean == nil)
		#expect(cauchy.variance == nil)
		let noVariance = try #require(DistributionStudentT(degreesOfFreedom: 2))
		#expect(noVariance.mean == 0)
		#expect(noVariance.variance == nil, "ν = 2 has no finite variance")
		let noKurtosis = try #require(DistributionStudentT(degreesOfFreedom: 4))
		#expect(noKurtosis.excessKurtosis == nil, "ν = 4 has no finite kurtosis")
	}

	@Test("The three refuse parameters outside their support")
	func refusals() {
		#expect(DistributionGamma(shape: 0, rate: 1) == nil)
		#expect(DistributionGamma(shape: 1, rate: 0) == nil)
		#expect(DistributionGamma(shape: -1, rate: 1) == nil)
		#expect(DistributionGamma(shape: 1, scale: 0) == nil)
		#expect(DistributionChiSquared(degreesOfFreedom: 0.0) == nil)
		#expect(DistributionChiSquared(degreesOfFreedom: -2.5) == nil)
		#expect(DistributionStudentT(degreesOfFreedom: 0.0) == nil)
		#expect(DistributionStudentT(degreesOfFreedom: -1.0) == nil)
		#expect(DistributionStudentT(degreesOfFreedom: 0) == nil)
	}

	// MARK: - The Alt rows these unblock

	@Test("PsiGammaAlt, PsiChiSquareAlt and PsiStudentAlt fit from percentiles")
	func theUnblockedAltRows() throws {
		var fitted = 0
		for (shape, rate) in [(2.0, 1.0), (3.7, 0.8), (0.6, 2.5)] {
			let original = try #require(DistributionGamma(shape: shape, rate: rate))
			let compared = PercentileFittingTests.roundTrip(original, at: [0.25, 0.75],
															tolerance: 1e-5,
															"gamma(\(shape), \(rate))")
			if compared > 0 { fitted += 1 }
		}
		for df in [1.0, 4.2, 12.0] {
			let original = try #require(DistributionChiSquared(degreesOfFreedom: df))
			let compared = PercentileFittingTests.roundTrip(original, at: [0.5],
															tolerance: 1e-5, "chiSquared(\(df))")
			if compared > 0 { fitted += 1 }
		}
		for df in [3.0, 6.5, 25.0] {
			let original = try #require(DistributionStudentT(degreesOfFreedom: df))
			let compared = PercentileFittingTests.roundTrip(original, at: [0.9],
															tolerance: 1e-5, "studentT(\(df))")
			if compared > 0 { fitted += 1 }
		}
		#expect(fitted == 9, "only \(fitted) of 9 Alt fits round-tripped")
	}
}
