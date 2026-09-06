//
//  BayesianICCReferenceTests.swift
//  BusinessMath
//
//  An oracle for the Bayesian ICC, which is a Gibbs sampler and so needs a different kind
//  of one.
//
//  `BayesianICCTests` has 19 tests and no external check.
//
//  ## A sampler cannot be compared draw by draw
//
//  Two correct implementations of the same posterior produce entirely different sequences
//  of draws even from the same seed — the values depend on the order and parameterisation
//  of every conditional and on the underlying generator. There is nothing to compare
//  element-wise, and a fixture of recorded draws would pin an implementation detail rather
//  than a result.
//
//  What can be checked is the distribution it converges to. **With vague priors and
//  adequate data, the posterior mean of each variance component approaches the ANOVA
//  estimate** — that is not an approximation someone chose, it is what a vague prior
//  means. A sampler targeting the wrong posterior, or one with a mis-derived conditional,
//  shows up as a systematic gap from the frequentist answer that does not close as the
//  data grows.
//
//  The frequentist side is itself oracle-backed: `mean_squares` in the generator comes
//  from statsmodels' `anova_lm`, the same external implementation behind the G-study
//  fixture. So this is not one unchecked estimator vouching for another.
//
//  ## Designs are sized so the comparison means something
//
//  A posterior mean equals an ANOVA estimate only in the limit. On a small noisy design
//  the prior still has a say and the two legitimately differ, so the fixture marks which
//  cases are large enough to carry the tight comparison. The small one is kept to exercise
//  validity and reproducibility, not agreement — asserting agreement there would be
//  asserting something untrue.
//
//  Values from Tests/BusinessMathTests/Fixtures/bayesianICC.json.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Bayesian ICC against the ANOVA decomposition")
struct BayesianICCReferenceTests {

	// MARK: - Fixture

	private struct Fixture: Decodable {
		let name: String
		let reference: String
		let note: String
		let cases: [Case]
	}

	private struct Case: Decodable {
		let name: String
		let note: String
		let supportsTightComparison: Bool
		let ratings: [[Double]]
		let subjectCount: Int
		let raterCount: Int
		let meanSquares: MeanSquares
		let frequentist: Frequentist
	}

	private struct MeanSquares: Decodable {
		let subjects: Double
		let raters: Double
		let error: Double
	}

	private struct Frequentist: Decodable {
		let sigmaSubjects: Double
		let sigmaRaters: Double
		let sigmaError: Double
		let iccAbsolute: Double
		let iccConsistency: Double
	}

	private static func loadFixture() throws -> Fixture {
		guard let url = Bundle.module.url(forResource: "bayesianICC",
										  withExtension: "json",
										  subdirectory: "Fixtures")
			?? Bundle.module.url(forResource: "bayesianICC", withExtension: "json") else {
			struct Missing: Error { let name: String }
			throw Missing(name: "bayesianICC")
		}
		return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
	}

	/// Vague priors and a long, seeded chain — the conditions under which the posterior
	/// mean is expected to track the ANOVA estimate.
	private static let vaguePriors = (subjects: VariancePrior<Double>.vague,
									  raters: VariancePrior<Double>.vague,
									  error: VariancePrior<Double>.vague)

	private static func config(seed: UInt64) -> GibbsConfig<Double> {
		GibbsConfig(iterations: 20_000, burnIn: 4_000, thinning: 1, chains: 1, seed: seed)
	}

	// MARK: - The fixture itself

	@Test("The fixture spans the range of the statistic")
	func fixtureIsWellFormed() throws {
		let fixture = try Self.loadFixture()
		#expect(fixture.reference.contains("statsmodels"),
				"reference was '\(fixture.reference)'")
		#expect(fixture.cases.count >= 5, "only \(fixture.cases.count) designs")

		// An ICC lives in [0,1] and is easiest to get right in the middle. Both ends need
		// covering: near one, where the error component is nearly zero, and near zero,
		// where the subject component clamps.
		let iccs = fixture.cases.map(\.frequentist.iccAbsolute)
		#expect(iccs.contains { $0 > 0.9 }, "no high-agreement design")
		#expect(iccs.contains { $0 < 0.1 }, "no low-agreement design")
		#expect(iccs.contains { $0 > 0.3 && $0 < 0.7 }, "no mid-range design")

		// And one where absolute and consistency genuinely differ, so a binding that
		// confused them could not pass. They coincide whenever raters agree.
		#expect(fixture.cases.contains {
			abs($0.frequentist.iccAbsolute - $0.frequentist.iccConsistency) > 0.3
		}, "no design separates ICC(2,1) from ICC(3,1)")

		#expect(fixture.cases.contains { $0.supportsTightComparison })
		#expect(fixture.cases.contains { !$0.supportsTightComparison })
	}

	// MARK: - The posterior against the ANOVA decomposition

	@Test("Posterior means approach the ANOVA variance components")
	func posteriorMeansMatchANOVA() throws {
		let fixture = try Self.loadFixture()
		var compared = 0

		for entry in fixture.cases where entry.supportsTightComparison {
			let result = try bayesianICC(entry.ratings,
										 model: .twoWayRandom,
										 priors: Self.vaguePriors,
										 config: Self.config(seed: 90_001))

			// A 10% band. Wide, and deliberately so: the posterior mean of a variance
			// component is not the ANOVA estimate, it approaches it, and on fifty to
			// sixty subjects the remaining gap is real rather than noise. The band is
			// still far narrower than the gap a mis-derived conditional would open —
			// the REML projection bug found earlier in this package was 12-24%.
			//
			// The subject component is exempted where the ICC is near zero, because
			// neither estimator is well determined there and the disagreement is a
			// property of both rather than a fault in either. A variance posterior is
			// bounded below at zero and right-skewed, so its mean sits above a near-zero
			// moment estimate — and the moment estimate is itself barely distinguishable
			// from its own clamp. Measured on a fixed low-ICC design, the gap closes as
			// information accumulates: 15.55 at 60 subjects, 0.37 at 200, 0.15 at 600.
			// Shrinkage that diminishes with data, not bias. The ICC comparison below
			// still covers these designs, and it holds.
			var comparisons: [(String, Double, Double)] = [
				("sigmaError", result.sigmaErrorMean, entry.frequentist.sigmaError)
			]
			if entry.frequentist.iccAbsolute >= 0.1 {
				comparisons.append(("sigmaSubjects", result.sigmaSubjectsMean,
									entry.frequentist.sigmaSubjects))
			}
			for (label, actual, reference) in comparisons {
				let scale = Swift.max(abs(reference), 1e-3)
				let deviation = abs(actual - reference) / scale
				#expect(deviation < 0.10,
						"\(entry.name) \(label): posterior mean \(actual), ANOVA \(reference), relative \(deviation)")
				compared += 1
			}
		}
		#expect(compared >= 7, "only \(compared) components compared")
	}

	@Test("The posterior ICC approaches the frequentist ICC")
	func posteriorICCMatchesFrequentist() throws {
		let fixture = try Self.loadFixture()
		var compared = 0

		for entry in fixture.cases where entry.supportsTightComparison {
			let result = try bayesianICC(entry.ratings,
										 model: .twoWayRandom,
										 priors: Self.vaguePriors,
										 config: Self.config(seed: 90_002))

			// Absolute on the ICC itself, since it is a proportion: 0.05 is a twentieth
			// of the whole range, and a systematically wrong posterior would miss by far
			// more than that.
			#expect(abs(result.iccMean - entry.frequentist.iccAbsolute) < 0.05,
					"\(entry.name): posterior ICC \(result.iccMean), frequentist \(entry.frequentist.iccAbsolute)")
			compared += 1
		}
		#expect(compared >= 4, "only \(compared) ICCs compared")
	}

	@Test("The Bayesian and frequentist estimators agree with each other")
	func agreesWithTheFrequentistImplementation() throws {
		// The same claim routed through this package's own `icc`, rather than the
		// fixture. Both are now oracle-backed — `icc` through the G-study fixture's
		// ANOVA, this through the comparison above — so a disagreement would mean one of
		// them had drifted from a reference they both previously matched.
		let fixture = try Self.loadFixture()

		for entry in fixture.cases where entry.supportsTightComparison {
			let frequentist = try icc(entry.ratings, model: .twoWayRandom, agreement: .absolute)
			let bayesian = try bayesianICC(entry.ratings,
										   model: .twoWayRandom,
										   priors: Self.vaguePriors,
										   config: Self.config(seed: 90_003))
			#expect(abs(bayesian.iccMean - frequentist.icc) < 0.05,
					"\(entry.name): bayesian \(bayesian.iccMean), frequentist \(frequentist.icc)")
		}
	}

	// MARK: - Properties a sampler must satisfy regardless

	@Test("A seeded chain reproduces exactly")
	func seededChainsAreReproducible() throws {
		// Not a statistical claim — a determinism one. Without it none of the comparisons
		// above mean anything, because a rerun could give a different answer and the
		// tolerance would be absorbing the difference.
		let fixture = try Self.loadFixture()
		guard let entry = fixture.cases.first else { return }

		let first = try bayesianICC(entry.ratings, model: .twoWayRandom,
									priors: Self.vaguePriors, config: Self.config(seed: 4242))
		let second = try bayesianICC(entry.ratings, model: .twoWayRandom,
									 priors: Self.vaguePriors, config: Self.config(seed: 4242))

		#expect(first.iccSamples.count == second.iccSamples.count)
		#expect(first.iccMean.isEqual(to: second.iccMean),
				"same seed gave \(first.iccMean) then \(second.iccMean)")
		for (a, b) in zip(first.iccSamples, second.iccSamples) {
			#expect(a.isEqual(to: b), "a draw differed between runs at the same seed")
		}

		// And a different seed must actually move it, or the seed is not being used.
		let other = try bayesianICC(entry.ratings, model: .twoWayRandom,
									priors: Self.vaguePriors, config: Self.config(seed: 9999))
		#expect(!other.iccMean.isEqual(to: first.iccMean),
				"two seeds produced an identical mean, so the seed is not reaching the chain")
	}

	@Test("Every draw is a valid ICC and the summaries are consistent with them")
	func drawsAndSummariesAreValid() throws {
		let fixture = try Self.loadFixture()

		for entry in fixture.cases {
			let result = try bayesianICC(entry.ratings, model: .twoWayRandom,
										 priors: Self.vaguePriors,
										 config: Self.config(seed: 90_004))

			#expect(!result.iccSamples.isEmpty, "\(entry.name): no draws retained")
			for sample in result.iccSamples {
				#expect(sample >= 0 && sample <= 1,
						"\(entry.name): a draw of \(sample) is not an ICC")
				#expect(sample.isFinite)
			}
			for sample in result.sigmaSubjectsSamples + result.sigmaErrorSamples {
				#expect(sample >= 0, "\(entry.name): a negative variance draw of \(sample)")
			}

			// The summaries must be summaries *of these draws*, not of something else.
			let mean = result.iccSamples.reduce(0, +) / Double(result.iccSamples.count)
			#expect(abs(result.iccMean - mean) < 1e-9,
					"\(entry.name): reported mean \(result.iccMean), computed \(mean)")

			let sorted = result.iccSamples.sorted()
			let median = sorted[sorted.count / 2]
			#expect(abs(result.iccMedian - median) < 0.02,
					"\(entry.name): reported median \(result.iccMedian), computed \(median)")

			let interval = result.iccCredibleInterval
			#expect(interval.lower <= interval.upper,
					"\(entry.name): interval [\(interval.lower), \(interval.upper)] is inverted")
			#expect(interval.lower <= result.iccMedian && result.iccMedian <= interval.upper,
					"\(entry.name): the median sits outside its own credible interval")
		}
	}

	@Test("The posterior concentrates as the design grows")
	func posteriorConcentrates() throws {
		// More data must buy more certainty. A sampler that ignored part of its data — or
		// whose conditional used the wrong sample size — would still produce a plausible
		// point estimate while the interval failed to shrink.
		func design(_ subjects: Int) -> [[Double]] {
			var generator = DeterministicRNG(seed: 555)
			return (0..<subjects).map { _ in
				let subjectEffect = Double.random(in: -5...5, using: &generator)
				return (0..<4).map { _ in
					50 + subjectEffect + Double.random(in: -1...1, using: &generator)
				}
			}
		}

		var previousWidth = Double.infinity
		for subjects in [10, 30, 90] {
			let result = try bayesianICC(design(subjects), model: .twoWayRandom,
										 priors: Self.vaguePriors,
										 config: Self.config(seed: 90_005))
			let width = result.iccCredibleInterval.upper - result.iccCredibleInterval.lower
			#expect(width < previousWidth,
					"at \(subjects) subjects the interval is \(width), no narrower than \(previousWidth)")
			previousWidth = width
		}
	}

	@Test("Absolute and consistency differ where rater variance is real")
	func absoluteAndConsistencyDiffer() throws {
		// ICC(2,1) counts rater variance against agreement and ICC(3,1) does not, so on a
		// design with a strong rater effect they must part company. They coincide
		// whenever raters agree, which is most test data — so a binding that returned one
		// for the other would pass nearly everywhere.
		let fixture = try Self.loadFixture()
		guard let entry = fixture.cases.first(where: { $0.name == "raterEffect_large" }) else {
			Issue.record("the rater-effect design is missing from the fixture"); return
		}
		#expect(entry.frequentist.iccConsistency > entry.frequentist.iccAbsolute + 0.3,
				"the fixture case no longer separates the two")

		let absolute = try bayesianICC(entry.ratings, model: .twoWayRandom,
									   priors: Self.vaguePriors,
									   config: Self.config(seed: 90_006))
		#expect(abs(absolute.iccMean - entry.frequentist.iccAbsolute) < 0.05,
				"twoWayRandom gave \(absolute.iccMean), ANOVA absolute is \(entry.frequentist.iccAbsolute)")
		#expect(abs(absolute.iccMean - entry.frequentist.iccConsistency) > 0.2,
				"twoWayRandom returned the consistency value, not the absolute one")
	}

	// MARK: - Rejection

	@Test("Designs too small to decompose are refused")
	func rejectsDegenerateDesigns() {
		#expect(throws: (any Error).self) {
			_ = try bayesianICC([[1.0, 2.0, 3.0]], model: .twoWayRandom)
		}
		#expect(throws: (any Error).self) {
			_ = try bayesianICC([[1.0], [2.0], [3.0]], model: .twoWayRandom)
		}
	}
}
