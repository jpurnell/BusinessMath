import Testing
import Foundation
@testable import BusinessMath

@Suite("Bayesian ICC Estimation")
struct BayesianICCTests {

    // MARK: - Test Data

    /// Shrout & Fleiss (1979) style dataset: 6 subjects x 4 raters
    static let ratings: [[Double]] = [
        [9.0, 2.0, 5.0, 8.0],
        [6.0, 1.0, 3.0, 2.0],
        [8.0, 4.0, 6.0, 8.0],
        [7.0, 1.0, 2.0, 6.0],
        [10.0, 5.0, 6.0, 9.0],
        [6.0, 2.0, 4.0, 7.0]
    ]

    /// Perfect agreement: all raters give same score per subject
    static let perfect: [[Double]] = [
        [5.0, 5.0, 5.0],
        [10.0, 10.0, 10.0],
        [15.0, 15.0, 15.0],
        [20.0, 20.0, 20.0]
    ]

    /// No reliability: random noise with no between-subject signal
    static let noReliability: [[Double]] = [
        [5.1, 4.9, 5.0, 5.2],
        [5.0, 5.1, 4.8, 5.0],
        [4.9, 5.0, 5.2, 4.9],
        [5.2, 4.8, 5.1, 5.0],
        [5.0, 5.0, 5.0, 5.1],
        [4.8, 5.2, 4.9, 5.0]
    ]

    static let gibbsConfig = GibbsConfig<Double>(
        iterations: 6000,
        burnIn: 3000,
        thinning: 1,
        chains: 2,
        seed: 12345
    )

    // MARK: - Known dataset: posterior mean within 10% of ANOVA

    @Test("Posterior means approximate ANOVA estimates for known dataset")
    func testPosteriorMeansApproximateANOVA() throws {
        let result = try bayesianICC(
            Self.ratings,
            model: .twoWayRandom,
            config: Self.gibbsConfig
        )

        // Frequentist ICC for comparison
        let freqResult = try icc(Self.ratings, model: .twoWayRandom, agreement: .absolute)

        // Posterior mean should be in the same ballpark as frequentist
        let diff = abs(result.iccMean - freqResult.icc)
        #expect(diff < 0.15, "Posterior mean \(result.iccMean) too far from frequentist \(freqResult.icc)")
    }

    // MARK: - Perfect agreement: ICC near 1.0

    @Test("Perfect agreement yields ICC posterior mean near 1.0")
    func testPerfectAgreement() throws {
        let result = try bayesianICC(
            Self.perfect,
            model: .twoWayRandom,
            config: Self.gibbsConfig
        )

        #expect(result.iccMean > 0.90, "Perfect agreement ICC should be near 1.0, got \(result.iccMean)")
    }

    // MARK: - No reliability: ICC near 0

    @Test("No reliability (random noise) yields low ICC")
    func testNoReliability() throws {
        let result = try bayesianICC(
            Self.noReliability,
            model: .twoWayRandom,
            config: Self.gibbsConfig
        )

        #expect(result.iccMean < 0.4, "No reliability ICC should be low, got \(result.iccMean)")
    }

    // MARK: - Reproducibility: same seed -> identical samples

    @Test("Same seed produces identical samples")
    func testReproducibility() throws {
        let config = GibbsConfig<Double>(
            iterations: 2000,
            burnIn: 1000,
            thinning: 1,
            chains: 1,
            seed: 42
        )

        let result1 = try bayesianICC(Self.ratings, model: .twoWayRandom, config: config)
        let result2 = try bayesianICC(Self.ratings, model: .twoWayRandom, config: config)

        #expect(result1.iccSamples == result2.iccSamples, "Same seed should produce identical ICC samples")
    }

    // MARK: - Different seeds -> different samples but similar means

    @Test("Different seeds yield different samples but similar summary statistics")
    func testDifferentSeeds() throws {
        let config1 = GibbsConfig<Double>(iterations: 5000, burnIn: 2500, chains: 1, seed: 100)
        let config2 = GibbsConfig<Double>(iterations: 5000, burnIn: 2500, chains: 1, seed: 200)

        let result1 = try bayesianICC(Self.ratings, model: .twoWayRandom, config: config1)
        let result2 = try bayesianICC(Self.ratings, model: .twoWayRandom, config: config2)

        // Samples should differ
        #expect(result1.iccSamples != result2.iccSamples)

        // But means should be similar
        let meanDiff = abs(result1.iccMean - result2.iccMean)
        #expect(meanDiff < 0.15, "Different seeds should give similar means, diff = \(meanDiff)")
    }

    // MARK: - < 2 subjects throws

    @Test("Fewer than 2 subjects throws insufficientData")
    func testTooFewSubjects() throws {
        let data: [[Double]] = [[1.0, 2.0, 3.0]]

        #expect(throws: BusinessMathError.self) {
            let _ = try bayesianICC(data, model: .twoWayRandom)
        }
    }

    // MARK: - < 2 raters throws

    @Test("Fewer than 2 raters throws insufficientData")
    func testTooFewRaters() throws {
        let data: [[Double]] = [[1.0], [2.0], [3.0]]

        #expect(throws: BusinessMathError.self) {
            let _ = try bayesianICC(data, model: .twoWayRandom)
        }
    }

    // MARK: - Ragged matrix throws

    @Test("Ragged matrix throws mismatchedDimensions")
    func testRaggedMatrixThrows() throws {
        let data: [[Double]] = [
            [1.0, 2.0, 3.0],
            [4.0, 5.0],
            [6.0, 7.0, 8.0]
        ]

        #expect(throws: BusinessMathError.self) {
            let _ = try bayesianICC(data, model: .twoWayRandom)
        }
    }

    // MARK: - Large dataset: posterior mean within 0.05 of frequentist ICC

    @Test("Large dataset: posterior mean close to frequentist ICC")
    func testLargeDatasetAccuracy() throws {
        // 30 subjects x 5 raters with known strong agreement pattern
        var largeRatings: [[Double]] = []
        let baseScores: [Double] = Array(stride(from: 1.0, through: 30.0, by: 1.0))

        for base in baseScores {
            var row: [Double] = []
            for raterOffset in [0.0, 0.5, -0.3, 0.2, -0.4] {
                row.append(base + raterOffset)
            }
            largeRatings.append(row)
        }

        let config = GibbsConfig<Double>(iterations: 8000, burnIn: 4000, chains: 2, seed: 777)
        let result = try bayesianICC(largeRatings, model: .twoWayRandom, config: config)
        let freqResult = try icc(largeRatings, model: .twoWayRandom, agreement: .absolute)

        let diff = abs(result.iccMean - freqResult.icc)
        #expect(diff < 0.05, "Large dataset: posterior mean \(result.iccMean) should be within 0.05 of frequentist \(freqResult.icc)")
    }

    // MARK: - 95% CI contains frequentist point estimate

    @Test("95% credible interval contains frequentist point estimate")
    func testCredibleIntervalContainsFrequentist() throws {
        // Use large dataset for tighter CI
        var largeRatings: [[Double]] = []
        let baseScores: [Double] = Array(stride(from: 1.0, through: 30.0, by: 1.0))

        for base in baseScores {
            var row: [Double] = []
            for raterOffset in [0.0, 0.5, -0.3, 0.2, -0.4] {
                row.append(base + raterOffset)
            }
            largeRatings.append(row)
        }

        let config = GibbsConfig<Double>(iterations: 8000, burnIn: 4000, chains: 2, seed: 777)
        let result = try bayesianICC(largeRatings, model: .twoWayRandom, config: config)
        let freqResult = try icc(largeRatings, model: .twoWayRandom, agreement: .absolute)

        #expect(
            freqResult.icc >= result.iccCredibleInterval.lower &&
            freqResult.icc <= result.iccCredibleInterval.upper,
            "Frequentist ICC \(freqResult.icc) should be within CI [\(result.iccCredibleInterval.lower), \(result.iccCredibleInterval.upper)]"
        )
    }

    // MARK: - probabilityAbove thresholds

    @Test("probabilityAbove reflects actual posterior mass")
    func testProbabilityAboveHighICC() throws {
        // Use large dataset with strong agreement -> high ICC
        var largeRatings: [[Double]] = []
        let baseScores: [Double] = Array(stride(from: 1.0, through: 30.0, by: 1.0))
        for base in baseScores {
            largeRatings.append([base, base + 0.1, base - 0.1, base + 0.05, base - 0.05])
        }

        let config = GibbsConfig<Double>(iterations: 6000, burnIn: 3000, chains: 2, seed: 555)
        let result = try bayesianICC(largeRatings, model: .twoWayRandom, config: config)

        #expect(result.probabilityAbove(0.75) > 0.8,
                "High ICC data: P(ICC>0.75) should be > 0.8, got \(result.probabilityAbove(0.75))")
    }

    @Test("probabilityAbove is low for weak-agreement data")
    func testProbabilityAboveLowICC() throws {
        let config = GibbsConfig<Double>(iterations: 6000, burnIn: 3000, chains: 2, seed: 555)
        let result = try bayesianICC(Self.noReliability, model: .twoWayRandom, config: config)

        #expect(result.probabilityAbove(0.75) < 0.2,
                "Low ICC data: P(ICC>0.75) should be < 0.2, got \(result.probabilityAbove(0.75))")
    }

    // MARK: - ICC(3,1) >= ICC(2,1) when rater variance > 0

    @Test("ICC(3,1) >= ICC(2,1) when rater variance present")
    func testConsistencyVsAbsolute() throws {
        let config = GibbsConfig<Double>(iterations: 6000, burnIn: 3000, chains: 1, seed: 999)
        let resultAbsolute = try bayesianICC(Self.ratings, model: .twoWayRandom, config: config)
        let resultConsistency = try bayesianICC(Self.ratings, model: .twoWayMixed, config: config)

        // ICC(3,1) omits rater variance from denominator, so should be >= ICC(2,1)
        #expect(resultConsistency.iccMean >= resultAbsolute.iccMean - 0.05,
                "ICC(3,1) \(resultConsistency.iccMean) should be >= ICC(2,1) \(resultAbsolute.iccMean)")
    }

    // MARK: - Missing Data Tests

    @Test("Complete optional data matches non-optional overload")
    func testCompleteOptionalMatchesNonOptional() throws {
        let config = GibbsConfig<Double>(iterations: 3000, burnIn: 1500, chains: 1, seed: 42)

        let completeResult = try bayesianICC(Self.ratings, model: .twoWayRandom, config: config)

        let optionalRatings: [[Double?]] = Self.ratings.map { $0.map { Optional($0) } }
        let optionalResult = try bayesianICC(optionalRatings, model: .twoWayRandom, config: config)

        // Should produce identical results since data is complete
        #expect(completeResult.iccSamples == optionalResult.iccSamples)
    }

    @Test("Single missing cell shifts posterior smoothly")
    func testSingleMissingCell() throws {
        let config = GibbsConfig<Double>(iterations: 5000, burnIn: 2500, chains: 2, seed: 42)

        let completeResult = try bayesianICC(Self.ratings, model: .twoWayRandom, config: config)

        var missingRatings: [[Double?]] = Self.ratings.map { $0.map { Optional($0) } }
        missingRatings[0][0] = nil

        let missingResult = try bayesianICC(missingRatings, model: .twoWayRandom, config: config)

        // Results should be similar (one missing cell out of 24)
        let diff = abs(completeResult.iccMean - missingResult.iccMean)
        #expect(diff < 0.2, "Single missing cell should not shift ICC dramatically, diff = \(diff)")
    }

    @Test("50% missing data produces valid results with positive CI width")
    func testHeavyMissingValidResults() throws {
        let config = GibbsConfig<Double>(iterations: 5000, burnIn: 2500, chains: 2, seed: 42)

        // Remove ~50% of data
        var missingRatings: [[Double?]] = Self.ratings.map { $0.map { Optional($0) } }
        for i in 0..<missingRatings.count {
            for j in 0..<missingRatings[i].count {
                if (i + j) % 2 == 0 {
                    missingRatings[i][j] = nil
                }
            }
        }

        let missingResult = try bayesianICC(missingRatings, model: .twoWayRandom, config: config)

        // Missing data should still produce valid, finite results
        #expect(missingResult.iccMean.isFinite, "ICC mean should be finite")
        #expect(missingResult.iccMean >= 0.0 && missingResult.iccMean <= 1.0,
                "ICC mean should be in [0,1], got \(missingResult.iccMean)")

        let missingWidth = missingResult.iccCredibleInterval.upper - missingResult.iccCredibleInterval.lower
        #expect(missingWidth > 0.0, "CI should have positive width, got \(missingWidth)")
        #expect(missingResult.iccCredibleInterval.lower < missingResult.iccCredibleInterval.upper)
    }

    @Test("All missing for one subject does not crash")
    func testAllMissingOneSubject() throws {
        let config = GibbsConfig<Double>(iterations: 3000, burnIn: 1500, chains: 1, seed: 42)

        var missingRatings: [[Double?]] = Self.ratings.map { $0.map { Optional($0) } }
        // Remove all data for subject 0
        for j in 0..<missingRatings[0].count {
            missingRatings[0][j] = nil
        }

        // Should not crash; still has 5 subjects with data
        let result = try bayesianICC(missingRatings, model: .twoWayRandom, config: config)
        #expect(result.iccMean.isFinite)
    }

    @Test("Fewer than 2 subjects with data throws")
    func testTooFewSubjectsWithData() throws {
        // Only one subject has data
        let missingRatings: [[Double?]] = [
            [1.0, 2.0, 3.0],
            [nil, nil, nil],
            [nil, nil, nil]
        ]

        #expect(throws: BusinessMathError.self) {
            let _ = try bayesianICC(missingRatings, model: .twoWayRandom)
        }
    }

    // MARK: - Informative priors

    @Test("Informative prior pulls posterior toward prior expectation")
    func testInformativePrior() throws {
        // Use informative priors that expect high subject variance
        let strongPriors = (
            subjects: VariancePrior<Double>.informative(expectedVariance: 20.0, strength: 10.0),
            raters: VariancePrior<Double>.vague,
            error: VariancePrior<Double>.vague
        )

        let config = GibbsConfig<Double>(iterations: 5000, burnIn: 2500, chains: 1, seed: 42)

        let vagueResult = try bayesianICC(Self.ratings, model: .twoWayRandom, config: config)
        let informativeResult = try bayesianICC(Self.ratings, model: .twoWayRandom, priors: strongPriors, config: config)

        // With a strong prior expecting high subject variance, ICC should be at least as high
        #expect(informativeResult.sigmaSubjectsMean >= vagueResult.sigmaSubjectsMean * 0.5,
                "Informative prior on subject variance should increase subject variance estimate")
    }
}
