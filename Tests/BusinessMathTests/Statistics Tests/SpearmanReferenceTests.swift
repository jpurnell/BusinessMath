//
//  SpearmanReferenceTests.swift
//  BusinessMath
//
//  Spearman's rho distribution, p-values and critical values against references computed
//  outside the package, and against Zar's published table.
//
//  Values from Tests/BusinessMathTests/Fixtures/spearmanDistribution.json, written by
//  Scripts/reference-fixtures/generate_spearman.py (which also runs generate_spearman.R).
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Spearman's rho against brute force, an independent exact recursion, R, SciPy, Monte
/// Carlo, and Zar (1984) Table B.19.
///
/// ## The references
///
/// - **Brute force** in Python over all `n!` permutations (n ≤ 10), and an **independent
///   exact dynamic programme** in Python integers, which agree wherever both run. Counts are
///   recorded as exact integers.
/// - **R 4.6.2** `cor.test(method = "spearman")`. With `exact = TRUE` R enumerates for
///   n ≤ 9 and uses the AS 89 Edgeworth series for n ≥ 10; with ties it uses t. So R checks
///   the exact method at n ≤ 9, ``SpearmanSignificanceMethod/edgeworth`` at n ≥ 10, and
///   ``SpearmanSignificanceMethod/tDistribution`` everywhere.
/// - **SciPy 1.18.1** `spearmanr` (t) and the exact `permutation_test` (n ≤ 8, tied too).
/// - **Monte Carlo**, 10⁶ permutations, on tied panels the exact method refuses.
/// - **Zar (1984) Table B.19**, every cell the exact method reaches.
@Suite("Spearman's rho matches brute force, R, SciPy, Monte Carlo and Zar")
struct SpearmanReferenceTests {

    // MARK: - Fixture

    struct Fixture: Decodable, Sendable {
        let generator: [String: String]
        let cases: [Case]
        let degenerate: [Degenerate]
        let monteCarlo: [MonteCarlo]
        let zar1984: Zar
    }

    struct Case: Decodable, Sendable {
        let name: String
        let x: [Double]
        let y: [Double]
        let n: Int
        let total: String
        let fourS: [Int]?
        let counts: [String]?
        let supportSize: Int
        let critical: [Critical]
        let observations: [Observation]
    }

    struct Critical: Decodable, Sendable {
        let alpha: Double
        let lowerRho: Double?
        let upperRho: Double?
        let lowerFourS: Int?
        let upperFourS: Int?
        let lowerTail: Double?
        let upperTail: Double?
        let tCritical: Double?
    }

    struct Observation: Decodable, Sendable {
        let x: [Double]
        let y: [Double]
        let rho: Double
        let fourS: Int
        let exactP: Double
        let scipyT: Double?
        let scipyPermutation: Double?
        let rRho: Double?
        let rExactArgument: Double?
        let rT: Double?
        let edgeworth: Double?
    }

    struct Degenerate: Decodable, Sendable {
        let name: String
        let x: [Double]
        let y: [Double]
    }

    struct MonteCarlo: Decodable, Sendable {
        let name: String
        let x: [Double]
        let y: [Double]
        let draws: Int
        let grid: [GridPoint]
    }

    struct GridPoint: Decodable, Sendable {
        let rho: Double
        let monteCarloP: Double
        let standardError: Double
        let tP: Double
    }

    struct Zar: Decodable, Sendable {
        let source: String
        let alphas: [Double]
        let rows: [ZarRow]
        let exactThrough: Int
        let swiftTestThrough: Int
        let agreement: ZarAgreement
        let agreementSwiftTested: ZarAgreement
    }

    struct ZarRow: Decodable, Sendable {
        let n: Int
        let printed: [Double?]
        let exact: [Double?]?
    }

    struct ZarAgreement: Decodable, Sendable {
        let cells: Int
        let matches: Int
        let mismatches: [[Double]]
    }

    static let shared: Fixture? = {
        guard let url = Bundle.module.url(forResource: "spearmanDistribution", withExtension: "json",
                                          subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "spearmanDistribution", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Fixture.self, from: data)
    }()

    static func fixture() throws -> Fixture {
        struct NotLoaded: Error {}
        guard let shared else { throw NotLoaded() }
        return shared
    }

    /// Every case's distribution, and the untied ones Zar's table needs, built once for the
    /// whole suite: building them is the expensive part, and several tests read each.
    static let distributions: [String: SpearmanDistribution<Double>] = {
        var built: [String: SpearmanDistribution<Double>] = [:]
        guard let shared else { return built }
        for testCase in shared.cases {
            built[testCase.name] = try? spearmanDistribution(testCase.x, vs: testCase.y)
        }
        for n in 4...shared.zar1984.swiftTestThrough {
            built["untied \(n)"] = try? spearmanDistribution(items: n)
        }
        return built
    }()

    static func distribution(_ name: String) throws -> SpearmanDistribution<Double> {
        struct NotBuilt: Error { let name: String }
        guard let built = distributions[name] else { throw NotBuilt(name: name) }
        return built
    }

    /// Two optional values are the same number, or both absent.
    ///
    /// Exact comparison is the claim: these are integers (4S) or exact rationals rounded once,
    /// and the reference computed them exactly. IEEE equality, named.
    static func same(_ a: Double?, _ b: Double?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return x.isEqual(to: y)
        default: return false
        }
    }

    private static func relativeGap(_ actual: Double, _ expected: Double) -> Double {
        let gap: Double = abs(actual - expected)
        let scale: Double = abs(expected)
        return scale > 0 ? gap / scale : gap
    }

    // MARK: - The fixture itself

    @Test("The fixture covers ties, brute force, R, SciPy, Monte Carlo and Zar")
    func fixtureIsWellFormed() throws {
        let fixture = try Self.fixture()
        #expect(fixture.generator["scipy"] == "1.18.1")
        #expect(fixture.generator["r"]?.contains("4.6.2") == true)
        #expect(fixture.cases.count >= 25)
        let tied: Int = fixture.cases.filter { Set($0.x).count < $0.n || Set($0.y).count < $0.n }.count
        #expect(tied >= 10)
        #expect(!fixture.degenerate.isEmpty)
        #expect(!fixture.monteCarlo.isEmpty)
        #expect(fixture.zar1984.rows.count == 97)
    }

    // MARK: - Distribution

    @Test("The pmf over Σd² matches exact integer counts, tied and untied")
    func probabilities() throws {
        for testCase in try Self.fixture().cases {
            guard let fourS = testCase.fourS, let counts = testCase.counts,
                  let total = Double(testCase.total) else { continue }
            let d: SpearmanDistribution<Double> = try Self.distribution(testCase.name)
            #expect(d.rhoValues.count == testCase.supportSize, "\(testCase.name)")
            // The fixture is in ascending K, so descending S; the distribution is ascending rho.
            for (index, s) in d.sumsOfSquaredDifferences.enumerated() where index < fourS.count {
                #expect((4 * s).isEqual(to: Double(fourS[index])), "\(testCase.name) [\(index)]")
                let count: Double = try #require(Double(counts[index]))
                let expected: Double = count / total
                #expect(Self.relativeGap(d.probabilities[index], expected) < 1e-14,
                        "\(testCase.name) [\(index)]: \(expected) vs \(d.probabilities[index])")
            }
        }
    }

    // MARK: - Exact critical values

    @Test("Critical values match exact rational arithmetic at α = 0.05, 0.10, 0.01")
    func criticalValues() throws {
        for testCase in try Self.fixture().cases {
            let d: SpearmanDistribution<Double> = try Self.distribution(testCase.name)
            for expected in testCase.critical {
                let values = try d.criticalValues(alpha: expected.alpha)
                let label: String = "\(testCase.name), α = \(expected.alpha)"
                #expect((values.upper == nil) == (expected.upperRho == nil), "\(label): upper exists")
                #expect((values.lower == nil) == (expected.lowerRho == nil), "\(label): lower exists")
                if let upper = values.upper, let want = expected.upperRho {
                    #expect(abs(upper - want) < 1e-15, "\(label): upper \(upper) vs \(want)")
                }
                if let lower = values.lower, let want = expected.lowerRho {
                    #expect(abs(lower - want) < 1e-15, "\(label): lower \(lower) vs \(want)")
                }
                #expect(Self.same(values.sumOfSquaredDifferencesAtUpper.map { 4 * $0 }, expected.upperFourS.map(Double.init)),
                        "\(label): S at upper")
                #expect(Self.same(values.sumOfSquaredDifferencesAtLower.map { 4 * $0 }, expected.lowerFourS.map(Double.init)),
                        "\(label): S at lower")
                if let tail = expected.upperTail {
                    let actual: Double = try #require(values.upperTailProbability, "\(label)")
                    #expect(Self.relativeGap(actual, tail) < 1e-12, "\(label)")
                }
                if let tail = expected.lowerTail {
                    let actual: Double = try #require(values.lowerTailProbability, "\(label)")
                    #expect(Self.relativeGap(actual, tail) < 1e-12, "\(label)")
                }
            }
        }
    }

    // MARK: - p-values

    /// Through `spearmanTest`, which decides on the integer statistic, for n ≤ 10; above that
    /// through the case's distribution and `pValue(rho:)`, which takes rho as a number (the
    /// distribution is the same, because the observations share the case's tie patterns).
    @Test("Exact p-values match exact arithmetic, R where R is exact, and SciPy's exact permutation test")
    func exactPValues() throws {
        for testCase in try Self.fixture().cases {
            let d: SpearmanDistribution<Double> = try Self.distribution(testCase.name)
            for (index, obs) in testCase.observations.enumerated() {
                let label: String = "\(testCase.name) #\(index)"
                let rho: Double
                let p: Double
                if testCase.n <= 10 {
                    let result = try spearmanTest(obs.x, vs: obs.y)
                    rho = try #require(result.rho)
                    p = try #require(result.pValue)
                    #expect(Self.same(result.sumOfSquaredDifferences.map { 4 * $0 }, Double(obs.fourS)), "\(label): S")
                    #expect(Self.same(d.pValue(rho: rho), p), "\(label): pValue(rho:) agrees with the integer path")
                } else {
                    rho = try spearmansRho(obs.x, vs: obs.y)
                    p = try #require(d.pValue(rho: rho))
                }
                #expect(abs(rho - obs.rho) < 1e-14, "\(label): rho")
                #expect(Self.relativeGap(p, obs.exactP) < 1e-14, "\(label): exact \(obs.exactP), this \(p)")
                if let permutation = obs.scipyPermutation {
                    #expect(abs(p - permutation) < 1e-12, "\(label): SciPy permutation \(permutation)")
                }
                let untied: Bool = Set(obs.x).count == testCase.n && Set(obs.y).count == testCase.n
                if let r = obs.rExactArgument, untied, testCase.n <= 9 {
                    #expect(abs(p - r) < 1e-12, "\(label): R exact \(r), this \(p)")
                }
                if let rRho = obs.rRho {
                    #expect(abs(rho - rRho) < 1e-14, "\(label): R's rho")
                }
            }
        }
    }

    /// R's `cor.test(exact = TRUE)` is the AS 89 Edgeworth series from n = 10. Ported line for
    /// line from `prho.c`, it reproduces R to rounding.
    @Test("The Edgeworth method reproduces R's cor.test(exact = TRUE) for n ≥ 10, untied")
    func edgeworthMatchesR() throws {
        var compared: Int = 0
        for testCase in try Self.fixture().cases where testCase.n >= 10 {
            for (index, obs) in testCase.observations.enumerated() {
                guard Set(obs.x).count == testCase.n, Set(obs.y).count == testCase.n,
                      let r = obs.rExactArgument else { continue }
                let result = try spearmanTest(obs.x, vs: obs.y, method: .edgeworth)
                let p = try #require(result.pValue)
                #expect(Self.relativeGap(p, r) < 1e-12, "\(testCase.name) #\(index): R \(r), this \(p)")
                compared += 1
            }
        }
        #expect(compared >= 20)
    }

    @Test("The t method matches R's cor.test(exact = FALSE) and SciPy's spearmanr, tied and untied")
    func tMatchesRAndSciPy() throws {
        var compared: Int = 0
        for testCase in try Self.fixture().cases where testCase.n >= 3 {
            for (index, obs) in testCase.observations.enumerated() {
                let result = try spearmanTest(obs.x, vs: obs.y, method: .tDistribution)
                let p = try #require(result.pValue)
                let label: String = "\(testCase.name) #\(index)"
                if let r = obs.rT {
                    #expect(abs(p - r) < 1e-12 || Self.relativeGap(p, r) < 1e-10, "\(label): R \(r), this \(p)")
                    compared += 1
                }
                if let s = obs.scipyT {
                    #expect(abs(p - s) < 1e-12 || Self.relativeGap(p, s) < 1e-10, "\(label): SciPy \(s), this \(p)")
                }
            }
            for expected in testCase.critical {
                guard let want = expected.tCritical else { continue }
                let values = try spearmanCriticalValues(testCase.x, vs: testCase.y,
                                                        alpha: expected.alpha, method: .tDistribution)
                let upper: Double = try #require(values.upper, "\(testCase.name)")
                #expect(Self.relativeGap(upper, want) < 1e-12, "\(testCase.name)")
            }
        }
        #expect(compared >= 100)
    }

    // MARK: - Degenerate

    @Test("A judge who tied everything is not computable under every method that accepts ties")
    func degenerate() throws {
        for testCase in try Self.fixture().degenerate {
            for method in [SpearmanSignificanceMethod.exact, .tDistribution] {
                let result = try spearmanTest(testCase.x, vs: testCase.y, method: method)
                #expect(result.rho == nil && result.pValue == nil && !result.isSignificant, "\(testCase.name)")
            }
            // spearmansRho itself answers nan, not zero.
            #expect(try spearmansRho(testCase.x, vs: testCase.y).isNaN)
        }
    }

    // MARK: - Monte Carlo

    /// Beyond the exact method, with ties, the t approximation is what is offered. Against 10⁶
    /// permutations it is within 0.01 of the permutation p-value at these sizes; recorded so
    /// the claim in the documentation cannot drift.
    @Test("t approximation within 0.01 of Monte Carlo on large tied panels the exact method refuses")
    func monteCarlo() throws {
        for panel in try Self.fixture().monteCarlo {
            #expect(throws: BusinessMathError.self, "\(panel.name): exact refuses") {
                _ = try spearmanDistribution(panel.x, vs: panel.y) as SpearmanDistribution<Double>
            }
            let n: Int = panel.x.count
            for point in panel.grid {
                let p: Double = try tTwoSided(rho: point.rho, items: n)
                #expect(abs(p - point.tP) < 1e-12, "\(panel.name): t at \(point.rho)")
                #expect(abs(p - point.monteCarloP) < 0.01 + 4 * point.standardError,
                        "\(panel.name), rho \(point.rho): t \(p), MC \(point.monteCarloP)")
            }
        }
    }

    // MARK: - Zar (1984)

    /// Zar's Table B.19, read as "reject if rho ≥ the tabled value", against the exact upper
    /// bound rounded to the table's three decimals. The generator compares every cell through
    /// n = 18 in exact Python arithmetic; this test recomputes the n ≤ 17 cells here (18 is
    /// beyond the exact method's budget) and requires the same agreement.
    @Test("Zar (1984) Table B.19 agreement is what the generator reported")
    func zarAgreement() throws {
        let zar = try Self.fixture().zar1984
        var cells: Int = 0
        var matches: Int = 0
        for row in zar.rows where row.n <= zar.swiftTestThrough {
            let d: SpearmanDistribution<Double> = try Self.distribution("untied \(row.n)")
            for (column, alpha) in zar.alphas.enumerated() {
                let values = try d.criticalValues(alpha: alpha)
                let printed: Double? = row.printed[column]
                let rounded: Double? = values.upper.map { ($0 * 1000).rounded() / 1000 }
                if let exact = row.exact?[column] {
                    #expect(values.upper.map { abs($0 - exact) < 1e-15 } == true, "n = \(row.n), α = \(alpha)")
                }
                cells += 1
                if Self.same(rounded, printed) { matches += 1 }
            }
        }
        #expect(cells == zar.agreementSwiftTested.cells)
        #expect(matches == zar.agreementSwiftTested.matches)
        #expect(zar.exactThrough >= zar.swiftTestThrough)
    }
}
