//
//  RankSumReferenceTests.swift
//  BusinessMath
//
//  The exact rank-sum distribution and its critical values against references computed
//  outside the package, and against the published Kramer (1963) table.
//
//  Values from Tests/BusinessMathTests/Fixtures/rankSumDistribution.json, written by
//  Scripts/reference-fixtures/generate_rank_sum.py (which also runs generate_rank_sum.R).
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Rank-sum distribution and critical values against exact rational arithmetic, R, Monte
/// Carlo, and Kramer (1963).
///
/// ## The references
///
/// - **Exact rational arithmetic** in Python: integer counts over `n^m` outcomes, so the
///   recorded probabilities carry one rounding and the critical values were chosen by exact
///   comparison with α/2.
/// - **R 4.6.2**, base R: a second convolution and a second implementation of the
///   critical-value rule, in another language. Its pmf and its critical values are both
///   checked here.
/// - **Monte Carlo by permutation** (NumPy, 400 000 draws, seed 20261112) on a 24 × 12 panel
///   of integer scores 1–6: each draw shuffles every judge's whole row, which is the null
///   hypothesis itself rather than the model this package derives from it.
/// - **Kramer (1963)**, as WineTaster carries it, for every untied panel it covers.
///
/// ## Tolerance
///
/// Probabilities: absolute 1e-15. Measured: NumPy and R differ from the exact values by at
/// most 2.8e-17 on these cases, and so does this package. Moments and tail probabilities:
/// relative 1e-12. Normal-approximation bounds: relative 1e-12 against SciPy's `norm.ppf`.
@Suite("Rank-sum critical values match exact arithmetic, R, Monte Carlo")
struct RankSumReferenceTests {

    // MARK: - Fixture

    struct Fixture: Decodable, Sendable {
        let generator: [String: String]
        let cases: [Case]
        let kramer1963: Kramer
    }

    struct Case: Decodable, Sendable {
        let name: String
        let judgeRanks: [[Double]]
        let minimumDoubledSum: Int
        let mean: Double
        let variance: Double
        let probabilities: [Double]?
        let rProbabilities: [Double]?
        let critical: [Critical]
        let rCritical: [Bounds]?
        let monteCarlo: MonteCarlo?
    }

    struct Critical: Decodable, Sendable {
        let alpha: Double
        let lower: Int?
        let upper: Int?
        let lowerTail: Double?
        let upperTail: Double?
        let lowerTailIsExactlyHalfAlpha: Bool
        let normalLower: Double
        let normalUpper: Double
    }

    struct Bounds: Decodable, Sendable {
        let alpha: Double
        let lower: Int?
        let upper: Int?
    }

    struct MonteCarlo: Decodable, Sendable {
        let alpha: Double
        let draws: Int
        let lowerTailFrequency: Double
        let upperTailFrequency: Double
        let lowerTailStandardError: Double
        let upperTailStandardError: Double
        let anyWineSignificantFrequency: Double
    }

    struct Kramer: Decodable, Sendable {
        let source: String
        let cells: [KramerCell]
        let agreement: [String: Agreement]
        let asymmetricCells: [[Int]]
    }

    struct KramerCell: Decodable, Sendable {
        let wines: Int
        let judges: Int
        let tableLow: Int
        let tableHigh: Int
        let exact: [String: SumBounds]
    }

    struct SumBounds: Decodable, Sendable {
        let lower: Int?
        let upper: Int?
    }

    struct Agreement: Decodable, Sendable {
        let matches: Int
        let cells: Int
        let mismatches: Int
    }

    static func loadFixture() throws -> Fixture {
        guard let url = Bundle.module.url(forResource: "rankSumDistribution",
                                          withExtension: "json",
                                          subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "rankSumDistribution", withExtension: "json") else {
            struct Missing: Error { let name: String }
            throw Missing(name: "rankSumDistribution")
        }
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    /// The fixture and every case's distribution, built once for the whole suite: the large
    /// panels are the expensive part of these tests, and every test reads them.
    struct Loaded: Sendable {
        let fixture: Fixture
        let distributions: [String: RankSumDistribution<Double>]
    }

    static let shared: Loaded? = {
        guard let fixture = try? loadFixture() else { return nil }
        var distributions: [String: RankSumDistribution<Double>] = [:]
        for testCase in fixture.cases {
            distributions[testCase.name] = try? rankSumDistribution(judgeRanks: testCase.judgeRanks)
        }
        return Loaded(fixture: fixture, distributions: distributions)
    }()

    static func loaded() throws -> Loaded {
        struct NotLoaded: Error {}
        guard let shared else { throw NotLoaded() }
        return shared
    }

    static func distribution(_ testCase: Case) throws -> RankSumDistribution<Double> {
        struct NotBuilt: Error { let name: String }
        guard let built = try loaded().distributions[testCase.name] else { throw NotBuilt(name: testCase.name) }
        return built
    }

    private static func relativeGap(_ actual: Double, _ expected: Double) -> Double {
        let gap: Double = abs(actual - expected)
        let scale: Double = abs(expected)
        return scale > 0 ? gap / scale : gap
    }

    /// Two optional bounds are the same sum, or both absent.
    ///
    /// Exact comparison is the claim: a bound is an attainable rank sum, a multiple of ½ held
    /// exactly in a `Double`, and the reference computed it exactly. Off by a half-step is the
    /// failure this exists to catch, and no tolerance would make sense.
    static func sameSum(_ a: Double?, _ b: Double?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return x.isEqual(to: y)
        default: return false
        }
    }

    /// A doubled sum from the fixture as a rank sum.
    private static func sum(_ doubled: Int?) -> Double? {
        guard let doubled else { return nil }
        return Double(doubled) / 2
    }

    // MARK: - The fixture itself

    @Test("The fixture covers ties, a point mass, an exact α/2 boundary, and Monte Carlo")
    func fixtureIsWellFormed() throws {
        let fixture = try Self.loaded().fixture
        #expect(fixture.cases.count >= 16)
        #expect(fixture.cases.contains { $0.judgeRanks.count >= 200 }, "a panel of 200 judges")
        #expect(fixture.cases.contains { $0.judgeRanks.count >= 100 && $0.judgeRanks[0].count >= 50 },
                "a 100 x 50 panel")
        #expect(fixture.generator["scipy"] == "1.18.1")
        #expect(fixture.generator["r"]?.contains("4.6.2") == true)
        let tied: Int = fixture.cases.filter { c in
            c.judgeRanks.contains { row in Set(row).count < row.count }
        }.count
        #expect(tied >= 8)
        #expect(fixture.cases.contains { $0.variance == 0 }, "a panel that ties everything")
        #expect(fixture.cases.contains { c in c.critical.contains { $0.lowerTailIsExactlyHalfAlpha } },
                "a tail exactly equal to α/2")
        #expect(fixture.cases.contains { $0.monteCarlo != nil })
        #expect(fixture.kramer1963.cells.count == 165)
    }

    // MARK: - Distribution

    @Test("The pmf matches exact arithmetic and R")
    func probabilities() throws {
        for testCase in try Self.loaded().fixture.cases {
            guard let exact = testCase.probabilities else { continue }
            let distribution = try Self.distribution(testCase)
            #expect(distribution.minimumDoubledSum == testCase.minimumDoubledSum, "\(testCase.name)")
            #expect(distribution.doubledSumProbabilities.count == exact.count, "\(testCase.name)")
            let r: [Double] = testCase.rProbabilities ?? []
            #expect(r.count == exact.count, "\(testCase.name): R pmf recorded")
            for (index, p) in distribution.doubledSumProbabilities.enumerated() where index < exact.count {
                let exactGap: Double = abs(p - exact[index])
                #expect(exactGap < 1e-15, "\(testCase.name) [\(index)]: exact \(exact[index]), this \(p)")
                if index < r.count {
                    let rGap: Double = abs(p - r[index])
                    #expect(rGap < 1e-15, "\(testCase.name) [\(index)]: R \(r[index]), this \(p)")
                }
            }
        }
    }

    @Test("Mean and tie-corrected variance match exact arithmetic")
    func moments() throws {
        for testCase in try Self.loaded().fixture.cases {
            let distribution = try Self.distribution(testCase)
            let meanGap: Double = Self.relativeGap(distribution.mean, testCase.mean)
            let varianceGap: Double = Self.relativeGap(distribution.variance, testCase.variance)
            #expect(meanGap < 1e-12, "\(testCase.name)")
            #expect(varianceGap < 1e-12, "\(testCase.name)")
        }
    }

    // MARK: - Exact critical values

    @Test("Critical values match exact arithmetic and R at α = 0.05, 0.10, 0.01")
    func criticalValues() throws {
        for testCase in try Self.loaded().fixture.cases {
            let rBounds: [Bounds] = testCase.rCritical ?? []
            #expect(rBounds.count == testCase.critical.count, "\(testCase.name): R recorded")
            let distribution = try Self.distribution(testCase)
            for (index, expected) in testCase.critical.enumerated() {
                let values = try distribution.criticalValues(alpha: expected.alpha)
                let label: String = "\(testCase.name), α = \(expected.alpha)"
                #expect(values.method == .exact)
                #expect(values.lower == Self.sum(expected.lower), "\(label): lower")
                #expect(values.upper == Self.sum(expected.upper), "\(label): upper")
                if index < rBounds.count {
                    #expect(values.lower == Self.sum(rBounds[index].lower), "\(label): R lower")
                    #expect(values.upper == Self.sum(rBounds[index].upper), "\(label): R upper")
                }
                if let tail = expected.lowerTail, let actual = values.lowerTailProbability {
                    #expect(Self.relativeGap(actual, tail) < 1e-12, "\(label): lower tail")
                } else {
                    #expect(values.lowerTailProbability == nil && expected.lowerTail == nil, "\(label)")
                }
                if let tail = expected.upperTail, let actual = values.upperTailProbability {
                    #expect(Self.relativeGap(actual, tail) < 1e-12, "\(label): upper tail")
                } else {
                    #expect(values.upperTailProbability == nil && expected.upperTail == nil, "\(label)")
                }
            }
        }
    }

    /// The critical values are the *extreme* attainable sums that keep each tail within α/2:
    /// one attainable step further in, the tail exceeds it.
    @Test("Each bound is the last attainable sum within α/2")
    func boundsAreMaximal() throws {
        for testCase in try Self.loaded().fixture.cases {
            let distribution = try Self.distribution(testCase)
            for alpha in [0.05, 0.10, 0.01] {
                let values = try distribution.criticalValues(alpha: alpha)
                let half: Double = alpha / 2
                guard let range = values.nonSignificantRange else {
                    Issue.record("\(testCase.name): no non-significant range")
                    continue
                }
                let firstIn: Double = distribution.probability(atMost: range.lowerBound)
                let lastIn: Double = distribution.probability(atLeast: range.upperBound)
                #expect(firstIn > half, "\(testCase.name), α = \(alpha): lowest non-significant sum")
                #expect(lastIn > half, "\(testCase.name), α = \(alpha): highest non-significant sum")
                if let lower = values.lower {
                    #expect(distribution.probability(atMost: lower) <= half * (1 + 1e-12))
                    #expect(distribution.probability(ofSum: lower) > 0, "lower is attainable")
                }
                if let upper = values.upper {
                    #expect(distribution.probability(atLeast: upper) <= half * (1 + 1e-12))
                    #expect(distribution.probability(ofSum: upper) > 0, "upper is attainable")
                }
            }
        }
    }

    /// 2 judges × 20 wines: P(S ≤ 5) = (1 + 2 + 3 + 4)/400 = 0.025 exactly. The rounded sum
    /// can land an ulp above the rounded α/2, so a bare `<=` would wrongly exclude 5.
    @Test("A tail exactly equal to α/2 is admitted")
    func exactBoundary() throws {
        let fixture = try Self.loaded().fixture
        let cases = fixture.cases.filter { c in c.critical.contains { $0.lowerTailIsExactlyHalfAlpha } }
        #expect(!cases.isEmpty)
        for testCase in cases {
            for expected in testCase.critical where expected.lowerTailIsExactlyHalfAlpha {
                let values = try rankSumCriticalValues(judgeRanks: testCase.judgeRanks,
                                                       alpha: expected.alpha)
                #expect(values.lower == Self.sum(expected.lower), "\(testCase.name)")
                #expect(values.lower == 5)
            }
        }
    }

    // MARK: - Monte Carlo

    /// The exact tail probabilities at the 5% critical values against 400 000 permutations of
    /// whole rows. Four standard errors: a false failure about once in 16 000 runs, and the
    /// fixture is fixed, so it either passes or it does not.
    @Test("Exact tails agree with Monte Carlo permutation within 4 standard errors")
    func monteCarlo() throws {
        for testCase in try Self.loaded().fixture.cases {
            guard let mc = testCase.monteCarlo else { continue }
            let values = try Self.distribution(testCase).criticalValues(alpha: mc.alpha)
            let lowerTail: Double = values.lowerTailProbability ?? -1
            let upperTail: Double = values.upperTailProbability ?? -1
            let lowerGap: Double = abs(lowerTail - mc.lowerTailFrequency)
            let upperGap: Double = abs(upperTail - mc.upperTailFrequency)
            #expect(lowerGap < 4 * mc.lowerTailStandardError,
                    "\(testCase.name): exact \(lowerTail), Monte Carlo \(mc.lowerTailFrequency)")
            #expect(upperGap < 4 * mc.upperTailStandardError,
                    "\(testCase.name): exact \(upperTail), Monte Carlo \(mc.upperTailFrequency)")
            // The multiple-comparison caveat, measured: with 12 wines each tested at 5%, far
            // more than 5% of null panels have *some* significant wine.
            #expect(mc.anyWineSignificantFrequency > 0.3)
        }
    }

    // MARK: - Normal approximation

    @Test("The normal approximation matches SciPy's norm.ppf on the tie-corrected variance")
    func normalApproximation() throws {
        for testCase in try Self.loaded().fixture.cases where testCase.variance > 0 {
            for expected in testCase.critical {
                let values = try rankSumCriticalValues(judgeRanks: testCase.judgeRanks,
                                                       alpha: expected.alpha,
                                                       method: .normalApproximation)
                #expect(values.method == .normalApproximation)
                let lower: Double = values.lower ?? .nan
                let upper: Double = values.upper ?? .nan
                #expect(Self.relativeGap(lower, expected.normalLower) < 1e-12, "\(testCase.name)")
                #expect(Self.relativeGap(upper, expected.normalUpper) < 1e-12, "\(testCase.name)")
            }
        }
    }

    // MARK: - Kramer (1963)

    @Test("Untied critical values match exact arithmetic for every Kramer panel")
    func kramerPanelsExact() throws {
        let kramer = try Self.loaded().fixture.kramer1963
        for cell in kramer.cells {
            let row: [Double] = (1...cell.wines).map(Double.init)
            let distribution = try rankSumDistribution(judgeRanks: Array(repeating: row, count: cell.judges))
            for (key, alpha) in [("0.05", 0.05), ("0.1", 0.10)] {
                let values = try distribution.criticalValues(alpha: alpha)
                let expected = cell.exact[key]
                let lower: Double? = expected?.lower.map(Double.init)
                let upper: Double? = expected?.upper.map(Double.init)
                #expect(Self.sameSum(values.lower, lower), "\(cell.judges) judges x \(cell.wines) wines, α = \(alpha)")
                #expect(Self.sameSum(values.upper, upper), "\(cell.judges) judges x \(cell.wines) wines, α = \(alpha)")
            }
        }
    }

    /// Kramer's 1963 table is **not** the exact per-wine test at any single level.
    ///
    /// Read as the non-significant range (a sum strictly outside `low … high` is significant),
    /// it agrees with the exact two-sided 5% test in 54 of 165 cells and with the exact 10%
    /// test in 82. Read as the significant bounds themselves it agrees in 13 and 43. Ten cells
    /// are not even symmetric about the mean (`low + high ≠ m(n + 1)`), so they are
    /// transcription slips in WineTaster's copy or in the source. In most of the rest the
    /// table's non-significant range is one or two narrower on each side than the exact 5%
    /// one: the table calls more wines significant than a 5% test should.
    ///
    /// This test pins that finding so it cannot drift: it recomputes the agreement from this
    /// package's own critical values and requires the counts the generator reported.
    @Test("Kramer (1963) agreement is what the generator reported")
    func kramerAgreement() throws {
        let kramer = try Self.loaded().fixture.kramer1963
        for (key, alpha) in [("0.05", 0.05), ("0.1", 0.10)] {
            var significantBounds: Int = 0
            var nonSignificantRange: Int = 0
            for cell in kramer.cells {
                let row: [Double] = (1...cell.wines).map(Double.init)
                let values = try rankSumCriticalValues(
                    judgeRanks: Array(repeating: row, count: cell.judges), alpha: alpha)
                let table: [Double] = [Double(cell.tableLow), Double(cell.tableHigh)]
                if let lower = values.lower, let upper = values.upper, let range = values.nonSignificantRange {
                    if table == [lower, upper] { significantBounds += 1 }
                    if table == [range.lowerBound, range.upperBound] { nonSignificantRange += 1 }
                } else if table == [0, 0] {
                    significantBounds += 1
                    nonSignificantRange += 1
                }
            }
            let bounds: Int = kramer.agreement["alpha \(key), significantBounds"]?.matches ?? -1
            let range: Int = kramer.agreement["alpha \(key), nonSignificantRange"]?.matches ?? -1
            #expect(significantBounds == bounds, "α = \(alpha), read as significant bounds")
            #expect(nonSignificantRange == range, "α = \(alpha), read as non-significant range")
        }
        #expect(kramer.agreement["alpha 0.05, nonSignificantRange"]?.matches == 54)
        #expect(kramer.agreement["alpha 0.1, nonSignificantRange"]?.matches == 82)
        #expect(kramer.asymmetricCells.count == 10)
    }
}
