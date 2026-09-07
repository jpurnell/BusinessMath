//
//  MultivariateAndFitTests.swift
//  BusinessMath
//
//  PsiMVNormal, PsiMVResample, PsiMVShuffle, PsiFit and PsiMakeInput.
//
//  The oracles here are properties that hold exactly rather than approximately, which
//  is what makes them worth asserting on a sampler:
//
//  - A multivariate normal's sample covariance converges to the matrix it was built
//    from, and its margins are the univariate normals with the diagonal's variances.
//  - A shuffle over a full pass reproduces the dataset *exactly* — every row once — so
//    the column means are the data's column means to rounding, with no sampling error
//    to allow for. A resample cannot promise that and is checked on its mean instead.
//  - A compound loss with a zero deductible and an infinite limit reduces to the plain
//    sum, so Wald's identity gives the mean in closed form.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Multivariate sampling and sample fitting")
struct MultivariateAndFitTests {

	// MARK: - PsiMVNormal

	@Test("A multivariate normal reproduces the covariance it was built from")
	func mvNormalCovariance() throws {
		let means = [0.06, 0.11]
		let covariance = [[0.0004, 0.00042], [0.00042, 0.0009]]
		let mvn = try DistributionMVNormal(means: means, covarianceMatrix: covariance)
		var rng = DeterministicRNG(seed: 20260907)
		let draws = (0..<200_000).map { _ in mvn.sample(using: &rng) }
		let first = draws.map { $0[0] }
		let second = draws.map { $0[1] }
		let m0: Double = mean(first)
		let m1: Double = mean(second)
		#expect(Swift.abs(m0 - means[0]) < 0.001, "component 0 mean \(m0)")
		#expect(Swift.abs(m1 - means[1]) < 0.002, "component 1 mean \(m1)")
		let v0: Double = variance(first)
		let v1: Double = variance(second)
		#expect(Swift.abs(v0 - covariance[0][0]) < covariance[0][0] * 0.02, "variance 0 \(v0)")
		#expect(Swift.abs(v1 - covariance[1][1]) < covariance[1][1] * 0.02, "variance 1 \(v1)")
		var cross: Double = 0
		for index in 0..<draws.count {
			let a: Double = first[index] - m0
			let b: Double = second[index] - m1
			cross += a * b
		}
		let sampleCovariance: Double = cross / Double(draws.count - 1)
		let wanted: Double = covariance[0][1]
		#expect(Swift.abs(sampleCovariance - wanted) < wanted * 0.03,
				"cross covariance \(sampleCovariance), wanted \(wanted)")
	}

	@Test("The covariance and the correlation constructors describe the same distribution")
	func mvNormalConstructorsAgree() throws {
		let means = [1.0, -2.0, 0.5]
		let deviations = [2.0, 0.5, 1.5]
		let correlation = [[1.0, 0.3, -0.2], [0.3, 1.0, 0.4], [-0.2, 0.4, 1.0]]
		let byCorrelation = try DistributionMVNormal(means: means,
													standardDeviations: deviations,
													correlationMatrix: correlation)
		let byCovariance = try DistributionMVNormal(means: means,
													covarianceMatrix: byCorrelation.covarianceMatrix)
		var compared = 0
		for i in 0..<3 {
			for j in 0..<3 {
				let a = try #require(byCorrelation.correlation(i, j))
				let b = try #require(byCovariance.correlation(i, j))
				#expect(Swift.abs(a - b) < 1e-12, "ρ[\(i)][\(j)] differed: \(a) vs \(b)")
				compared += 1
			}
		}
		#expect(compared == 9, "only \(compared) of 9 correlations were compared")
	}

	@Test("A multivariate normal's margins are the univariate normals")
	func mvNormalMargins() throws {
		let mvn = try DistributionMVNormal(means: [3.0, -1.0],
										   covarianceMatrix: [[4.0, 1.0], [1.0, 9.0]])
		let first = try #require(mvn.marginal(0))
		let second = try #require(mvn.marginal(1))
		#expect(Swift.abs(first.mean - 3) < 1e-12)
		#expect(Swift.abs(first.stdDev - 2) < 1e-12, "σ₀ is \(first.stdDev)")
		#expect(Swift.abs(second.mean + 1) < 1e-12)
		#expect(Swift.abs(second.stdDev - 3) < 1e-12, "σ₁ is \(second.stdDev)")
		#expect(mvn.marginal(2) == nil)
		#expect(mvn.marginal(-1) == nil)
	}

	@Test("A multivariate normal refuses a covariance matrix that describes nothing")
	func mvNormalRejects() {
		#expect(throws: MVNormalError.dimensionMismatch) {
			_ = try DistributionMVNormal(means: [0, 0], covarianceMatrix: [[1.0]])
		}
		#expect(throws: MVNormalError.nonPositiveVariance) {
			_ = try DistributionMVNormal(means: [0, 0],
										 covarianceMatrix: [[0.0, 0.0], [0.0, 1.0]])
		}
		#expect(throws: MVNormalError.asymmetricCovariance) {
			_ = try DistributionMVNormal(means: [0, 0],
										 covarianceMatrix: [[1.0, 0.5], [0.2, 1.0]])
		}
		// ρ = 1.5 is outside [−1, 1], so there is no distribution with this covariance.
		#expect(throws: MVNormalError.notPositiveDefinite) {
			_ = try DistributionMVNormal(means: [0, 0],
										 covarianceMatrix: [[1.0, 1.5], [1.5, 1.0]])
		}
	}

	// MARK: - PsiMVShuffle

	@Test("A full pass of the shuffle returns every row exactly once")
	func shuffleIsExhaustiveAndExact() throws {
		let rows = [[1.0, 10.0], [2.0, 20.0], [3.0, 30.0], [4.0, 40.0]]
		var deck = try MultivariateShuffle(rows: rows)
		var rng = DeterministicRNG(seed: 7)
		var drawn: [[Double]] = []
		while let row = deck.next(using: &rng) { drawn.append(row) }
		#expect(deck.isExhausted)
		#expect(deck.next(using: &rng) == nil, "an exhausted shuffle handed out another row")
		#expect(drawn.count == rows.count, "a full pass produced \(drawn.count) rows")
		let sortedDrawn = drawn.sorted { $0[0] < $1[0] }
		#expect(sortedDrawn == rows, "a full pass was not a permutation of the data")
		deck.reset()
		#expect(deck.remainingCount == rows.count)
	}

	@Test("The shuffle keeps rows intact rather than shuffling within them")
	func shufflePreservesRows() throws {
		// Every row here has its second entry equal to ten times its first. If the
		// columns were permuted independently that relationship would break, and this
		// is the whole difference between preserving a joint distribution and
		// preserving two marginals.
		let rows = (1...20).map { [Double($0), Double($0) * 10] }
		var deck = try MultivariateShuffle(rows: rows)
		var rng = DeterministicRNG(seed: 99)
		var checked = 0
		while let row = deck.next(using: &rng) {
			let expected: Double = row[0] * 10
			#expect(Swift.abs(row[1] - expected) < 1e-12,
					"row \(row) broke the relationship between its columns")
			checked += 1
		}
		#expect(checked == rows.count, "only \(checked) of \(rows.count) rows were checked")
	}

	@Test("A permutation is a reordering and nothing else")
	func shufflePermutation() throws {
		let rows = [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]]
		let deck = try MultivariateShuffle(rows: rows)
		var rng = DeterministicRNG(seed: 3)
		let permuted = deck.permuted(using: &rng)
		#expect(permuted.count == rows.count)
		#expect(permuted.sorted { $0[0] < $1[0] } == rows)
	}

	// MARK: - PsiMVResample

	@Test("Resampling draws whole rows and converges on the data's column means")
	func resampleMeans() throws {
		let rows = [[1.0, 100.0], [2.0, 200.0], [3.0, 300.0], [10.0, 1000.0]]
		let resampler = try MultivariateResample(rows: rows)
		var rng = DeterministicRNG(seed: 11)
		let draws = resampler.sample(count: 100_000, using: &rng)
		let wanted = resampler.columnMeans
		var checked = 0
		for column in 0..<resampler.dimension {
			let values = draws.map { $0[column] }
			let got: Double = mean(values)
			#expect(Swift.abs(got - wanted[column]) < wanted[column] * 0.01,
					"column \(column) averaged \(got), data says \(wanted[column])")
			checked += 1
		}
		#expect(checked == 2, "only \(checked) columns were checked")
		// Every draw must be one of the four rows, not a blend of them.
		let distinct = Set(draws.map { $0[0] })
		#expect(distinct.isSubset(of: Set(rows.map { $0[0] })),
				"resampling invented a value that is not in the data")
	}

	@Test("Both multivariate samplers refuse data that has no shape")
	func multivariateRejects() {
		#expect(throws: MultivariateResample.Failure.empty) {
			_ = try MultivariateResample(rows: [])
		}
		#expect(throws: MultivariateResample.Failure.raggedRows) {
			_ = try MultivariateResample(rows: [[1.0, 2.0], [3.0]])
		}
		#expect(throws: MultivariateResample.Failure.nonFiniteValue) {
			_ = try MultivariateResample(rows: [[1.0, Double.nan]])
		}
		#expect(throws: MultivariateShuffle.Failure.raggedRows) {
			_ = try MultivariateShuffle(rows: [[1.0], [2.0, 3.0]])
		}
	}

	// MARK: - PsiFit

	@Test("Fitting a sample from a known normal recovers that normal")
	func sampleFitNormal() throws {
		let source = DistributionNormal(50, 8)
		var rng = DeterministicRNG(seed: 2026)
		let sample = (0..<40_000).map { _ -> Double in
			let u: Double = Double.random(in: 0.000001...0.999999, using: &rng)
			return source.quantile(u)
		}
		let fitted = try DistributionMomentFit(sample: sample)
		#expect(Swift.abs(fitted.mean - 50) < 0.2, "fitted mean \(fitted.mean)")
		#expect(Swift.abs(fitted.standardDeviation - 8) < 0.2, "fitted σ \(fitted.standardDeviation)")
		// The quantiles are the real test: the moments were fitted by construction.
		var compared = 0
		for p in [0.05, 0.25, 0.5, 0.75, 0.95] {
			let wanted: Double = source.quantile(p)
			let got: Double = fitted.quantile(p)
			#expect(Swift.abs(got - wanted) < 0.6, "at p=\(p): fitted \(got), true \(wanted)")
			compared += 1
		}
		#expect(compared == 5, "only \(compared) quantiles were compared")
	}

	@Test("Anderson-Darling prefers the distribution the data came from")
	func andersonDarlingRanks() throws {
		let source = DistributionNormal(0, 1)
		var rng = DeterministicRNG(seed: 4242)
		let sample = (0..<3_000).map { _ -> Double in
			let u: Double = Double.random(in: 0.000001...0.999999, using: &rng)
			return source.quantile(u)
		}
		let right = try #require(andersonDarlingStatistic(sample, against: DistributionNormal(0, 1)))
		let wrong = try #require(andersonDarlingStatistic(sample, against: DistributionNormal(1, 3)))
		#expect(right < wrong,
				"the true distribution scored \(right), a wrong one \(wrong)")
		#expect(right > 0, "A² must be non-negative, got \(right)")
	}

	@Test("Anderson-Darling reports an impossible observation as infinitely bad")
	func andersonDarlingImpossible() throws {
		// A uniform on [0, 1] assigns probability zero to 5. That is not a numerical
		// problem to be clamped away — the candidate says an observed value could not
		// have happened, and infinity is the honest score for that.
		let sample = [0.1, 0.5, 0.9, 5.0]
		let score = try #require(andersonDarlingStatistic(sample, against: DistributionUniform(0, 1)))
		#expect(score == .infinity, "an impossible observation scored \(score)")
		#expect(andersonDarlingStatistic([1.0], against: DistributionNormal(0, 1)) == nil)
	}

	@Test("Fitting refuses a sample too small to carry four moments")
	func sampleFitRefusesSmallSamples() {
		#expect(throws: MomentFitError.self) {
			_ = try DistributionMomentFit(sample: [1.0, 2.0, 3.0])
		}
		#expect(throws: MomentFitError.nonPositiveStandardDeviation) {
			_ = try DistributionMomentFit(sample: [2.0, 2.0, 2.0, 2.0])
		}
	}

	// MARK: - PsiMakeInput

	@Test("With no deductible and no limit the aggregate mean is Wald's identity")
	func compoundMatchesWald() throws {
		let lambda = 3.0
		let frequency = try #require(DistributionPoisson(lambda: lambda))
		let severity = DistributionNormal(1_000, 100)
		let model = try CompoundLossModel(frequency: frequency, severity: severity)
		var rng = DeterministicRNG(seed: 515)
		let draws = model.sample(count: 60_000, using: &rng)
		let got: Double = mean(draws)
		// E[S] = E[N]·E[X] = 3 × 1000. The severity is normal, so with a zero
		// deductible `netOccurrence` is the identity on the positive side and the
		// small negative tail is clipped — hence the tolerance rather than equality.
		let wanted: Double = lambda * 1_000
		#expect(Swift.abs(got - wanted) < wanted * 0.02, "simulated \(got), Wald says \(wanted)")
	}

	@Test("The deductible applies to each occurrence, not to the total")
	func compoundDeductibleIsPerOccurrence() throws {
		let frequency = try #require(DistributionPoisson(lambda: 4))
		let severity = DistributionNormal(100, 5)
		// Every loss is about 100 and the deductible is 150, so no single occurrence
		// clears it — even though four of them total 400. An aggregate deductible
		// would pay out here; a per-occurrence one pays nothing, and that difference is
		// the entire point of the type.
		let model = try CompoundLossModel(frequency: frequency, severity: severity,
										  deductible: 150)
		var rng = DeterministicRNG(seed: 616)
		let draws = model.sample(count: 5_000, using: &rng)
		#expect(draws.allSatisfy { $0 == 0 },
				"a per-occurrence deductible paid out on losses that never reached it")
	}

	@Test("The limit caps each occurrence")
	func compoundLimit() throws {
		let frequency = try #require(DistributionPoisson(lambda: 1))
		let severity = DistributionNormal(10_000, 1_000)
		let model = try CompoundLossModel(frequency: frequency, severity: severity,
										  deductible: 0, limit: 500)
		#expect(model.netOccurrence(10_000) == 500)
		#expect(model.netOccurrence(300) == 300)
		#expect(model.netOccurrence(-50) == 0, "a negative loss must not pay out")
		var rng = DeterministicRNG(seed: 717)
		let detail = (0..<2_000).map { _ in model.sampleDetail(using: &rng) }
		var checked = 0
		for row in detail {
			let ceiling: Double = Double(row.count) * 500
			#expect(row.net <= ceiling + 1e-9,
					"\(row.count) occurrences paid \(row.net), above the \(ceiling) cap")
			checked += 1
		}
		#expect(checked == 2_000, "only \(checked) draws were checked")
	}

	@Test("The expected aggregate agrees with simulation once terms are in the way")
	func compoundExpectedAggregate() throws {
		let lambda = 5.0
		let frequency = try #require(DistributionPoisson(lambda: lambda))
		let severity = DistributionLogNormal(7, 0.8)
		let model = try CompoundLossModel(frequency: frequency, severity: severity,
										  deductible: 200, limit: 5_000)
		let analytic = try #require(model.expectedAggregate(expectedCount: lambda))
		var rng = DeterministicRNG(seed: 818)
		let draws = model.sample(count: 80_000, using: &rng)
		let simulated: Double = mean(draws)
		#expect(Swift.abs(simulated - analytic) < analytic * 0.03,
				"quadrature says \(analytic), simulation says \(simulated)")
	}

	@Test("A compound model refuses terms that are not a policy")
	func compoundRejects() throws {
		let frequency = try #require(DistributionPoisson(lambda: 1))
		let severity = DistributionNormal(100, 10)
		#expect(throws: CompoundLossModel<DistributionPoisson, DistributionNormal>.Failure.invalidDeductible) {
			_ = try CompoundLossModel(frequency: frequency, severity: severity, deductible: -1)
		}
		#expect(throws: CompoundLossModel<DistributionPoisson, DistributionNormal>.Failure.invalidLimit) {
			_ = try CompoundLossModel(frequency: frequency, severity: severity, limit: 0)
		}
	}
}
