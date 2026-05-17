import Testing
import Foundation
@testable import BusinessMath

@Suite("Convergence Diagnostics")
struct ConvergenceDiagnosticsTests {

    // MARK: - R-hat: Convergent chains < 1.05

    @Test("R-hat near 1.0 for convergent chains")
    func testRHatConvergentChains() throws {
        // Two chains sampling from the same distribution (overlapping ranges)
        let chain1: [Double] = (0..<500).map { Double($0 % 100) / 100.0 + 0.5 }
        let chain2: [Double] = (0..<500).map { Double(($0 + 50) % 100) / 100.0 + 0.5 }

        let rHat = rHatStatistic([chain1, chain2])
        #expect(rHat != nil) // TEST-QUALITY: existence check

        if let rHat = rHat {
            #expect(rHat < 1.05, "Convergent chains should have R-hat < 1.05, got \(rHat)")
        }
    }

    // MARK: - R-hat: Dispersed starts with few iterations > 1.1

    @Test("R-hat > 1.1 for non-convergent chains")
    func testRHatNonConvergent() throws {
        // Two chains with very different stationary distributions (short, no mixing)
        let chain1: [Double] = (0..<10).map { _ in 1.0 }
        let chain2: [Double] = (0..<10).map { _ in 100.0 }

        let rHat = rHatStatistic([chain1, chain2])
        #expect(rHat != nil) // TEST-QUALITY: existence check

        if let rHat = rHat {
            #expect(rHat > 1.1, "Non-convergent chains should have R-hat > 1.1, got \(rHat)")
        }
    }

    // MARK: - R-hat: Single chain returns nil

    @Test("R-hat returns nil for single chain")
    func testRHatSingleChain() {
        let chain: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let rHat = rHatStatistic([chain])
        #expect(rHat == nil, "Single chain should return nil R-hat")
    }

    // MARK: - R-hat: Identical chains near 1.0

    @Test("R-hat near 1.0 for identical chains")
    func testRHatIdenticalChains() throws {
        // With identical chains, B=0, so R-hat = sqrt((n-1)/n).
        // For n=1000, that is sqrt(0.999) ≈ 0.9995 — well within 0.06 of 1.0.
        let chain: [Double] = (0..<1000).map { Double($0) }
        let rHat = rHatStatistic([chain, chain])
        #expect(rHat != nil) // TEST-QUALITY: existence check

        if let rHat = rHat {
            #expect(abs(rHat - 1.0) < 0.06, "Identical chains should have R-hat ~1.0, got \(rHat)")
        }
    }

    // MARK: - R-hat: Three chains

    @Test("R-hat works with three convergent chains")
    func testRHatThreeChains() throws {
        let n = 200
        let chain1: [Double] = (0..<n).map { Double($0 % 50) / 50.0 }
        let chain2: [Double] = (0..<n).map { Double(($0 + 17) % 50) / 50.0 }
        let chain3: [Double] = (0..<n).map { Double(($0 + 33) % 50) / 50.0 }

        let rHat = rHatStatistic([chain1, chain2, chain3])
        #expect(rHat != nil) // TEST-QUALITY: existence check

        if let rHat = rHat {
            #expect(rHat < 1.1, "Three convergent chains should have reasonable R-hat, got \(rHat)")
        }
    }

    // MARK: - ESS: Alternating (low autocorrelation) sequence

    @Test("ESS is reasonably large for alternating-sign sequence")
    func testESSAlternating() {
        // Alternating values have negative lag-1 autocorrelation,
        // so ESS truncates early and returns ~ n
        let n = 200
        let samples: [Double] = (0..<n).map { Double($0 % 2 == 0 ? 1 : -1) * 1.0 }

        let ess = effectiveSampleSize(samples)
        // With negative autocorrelation at lag 1, summation truncates immediately, ESS ~ n
        #expect(ess >= n / 2, "Alternating pattern should have high ESS, got \(ess)")
    }

    // MARK: - ESS: Highly autocorrelated << n

    @Test("ESS much less than n for highly autocorrelated sequence")
    func testESSHighlyAutocorrelated() {
        // Monotonically increasing sequence has very high positive autocorrelation
        let n = 200
        let samples: [Double] = (0..<n).map { Double($0) }

        let ess = effectiveSampleSize(samples)
        #expect(ess < n / 3, "Monotonic series ESS should be << n=\(n), got \(ess)")
    }

    // MARK: - ESS: Slow random walk

    @Test("ESS less than n for positively autocorrelated random walk")
    func testESSRandomWalk() {
        // Cumulative sum creates strong positive autocorrelation
        let n = 300
        var samples: [Double] = [0.0]
        samples.reserveCapacity(n)
        for i in 1..<n {
            // Each value is close to the previous (high persistence)
            samples.append(samples[i - 1] + 0.1)
        }

        let ess = effectiveSampleSize(samples)
        #expect(ess < n, "Random walk ESS should be < n=\(n), got \(ess)")
        #expect(ess >= 1, "ESS should be at least 1")
    }

    // MARK: - ESS bounded: [1, n]

    @Test("ESS is bounded between 1 and n")
    func testESSBounds() {
        let samples: [Double] = [1.0, 2.0, 1.5, 2.5, 1.0, 2.0, 1.5, 2.5, 1.0, 2.0]
        let n = samples.count
        let ess = effectiveSampleSize(samples)

        #expect(ess >= 1, "ESS should be at least 1, got \(ess)")
        #expect(ess <= n, "ESS should be at most n=\(n), got \(ess)")
    }

    // MARK: - ESS: Constant sequence

    @Test("ESS equals n for constant sequence")
    func testESSConstantSequence() {
        let samples: [Double] = [5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0]
        let ess = effectiveSampleSize(samples)
        #expect(ess == samples.count, "Constant sequence ESS should be n, got \(ess)")
    }

    // MARK: - ESS: Single sample

    @Test("ESS returns 1 for single sample")
    func testESSSingleSample() {
        let samples: [Double] = [3.14]
        let ess = effectiveSampleSize(samples)
        #expect(ess == 1, "Single sample ESS should be 1, got \(ess)")
    }

    // MARK: - ESS: Empty array

    @Test("ESS returns 0 for empty array")
    func testESSEmptyArray() {
        let samples: [Double] = []
        let ess = effectiveSampleSize(samples)
        #expect(ess == 0, "Empty array ESS should be 0, got \(ess)")
    }

    // MARK: - R-hat: Empty chains

    @Test("R-hat returns nil for empty chains")
    func testRHatEmptyChains() {
        let rHat: Double? = rHatStatistic([[], []])
        #expect(rHat == nil)
    }

    // MARK: - R-hat: Very short chains

    @Test("R-hat returns nil for single-element chains")
    func testRHatSingleElementChains() {
        let rHat: Double? = rHatStatistic([[1.0], [2.0]])
        #expect(rHat == nil)
    }
}
