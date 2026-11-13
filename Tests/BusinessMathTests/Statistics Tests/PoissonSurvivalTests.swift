//
//  PoissonSurvivalTests.swift
//  BusinessMath
//
//  The Poisson upper tail P(X ≥ k), computed directly, against R and SciPy.
//
//  Reference values from Scripts/reference-fixtures/generate_hub_statistics.R (R 4.6.2,
//  `ppois(k - 1, lambda, lower.tail = FALSE)`), checked against generate_hub_statistics.py
//  (SciPy 1.17.1, `poisson.sf(k - 1, lambda)`). The two agree to a relative 1.1e-13 or better
//  on every case here (the largest gap is k = 1200, λ = 1000).
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Poisson survival function: reference values, deep tails, edges and refusals.
///
/// ## Tolerance
///
/// Relative to R: 1e-12 for λ ≤ 10, 1e-11 for λ = 1000 and 1e-9 for λ = 100 000. The last two
/// are wider because the leading term's logarithm is a difference of numbers near
/// `k ln k`, whose rounding is a relative error in the tail. R and SciPy themselves differ by
/// up to 1.1e-13 here. The Hub reads these against 0.001.
@Suite("Poisson survival P(X ≥ k)")
struct PoissonSurvivalTests {

    struct Reference: Sendable, CustomTestStringConvertible {
        let k: Int
        let lambda: Double
        let survival: Double
        let relativeTolerance: Double
        var testDescription: String { "k=\(k), λ=\(lambda)" }
    }

    /// R 4.6.2, `ppois(k - 1, lambda, lower.tail = FALSE)`, 17 significant digits.
    static let references: [Reference] = [
        Reference(k: 0, lambda: 3, survival: 1, relativeTolerance: 0),
        Reference(k: 0, lambda: 0, survival: 1, relativeTolerance: 0),
        Reference(k: 1, lambda: 0, survival: 0, relativeTolerance: 0),
        Reference(k: 1, lambda: 0.5, survival: 0.39346934028736658, relativeTolerance: 1e-12),
        Reference(k: 3, lambda: 1, survival: 0.080301397071394193, relativeTolerance: 1e-12),
        Reference(k: 5, lambda: 1, survival: 0.0036598468273437131, relativeTolerance: 1e-12),
        Reference(k: 5, lambda: 0.1, survival: 7.6678016861893133e-08, relativeTolerance: 1e-12),
        Reference(k: 10, lambda: 2, survival: 4.6498075017263812e-05, relativeTolerance: 1e-12),
        Reference(k: 8, lambda: 2, survival: 0.0010967189678587031, relativeTolerance: 1e-12),
        Reference(k: 12, lambda: 3, survival: 7.1386628974206605e-05, relativeTolerance: 1e-12),
        Reference(k: 15, lambda: 10, survival: 0.083458472934662853, relativeTolerance: 1e-12),
        Reference(k: 20, lambda: 10, survival: 0.0034543419758568087, relativeTolerance: 1e-12),
        Reference(k: 25, lambda: 10, survival: 4.6949381426799698e-05, relativeTolerance: 1e-12),
        Reference(k: 1, lambda: 50, survival: 1, relativeTolerance: 1e-15),
        Reference(k: 20, lambda: 1, survival: 1.5875276010732626e-19, relativeTolerance: 1e-12),
        Reference(k: 30, lambda: 2, survival: 5.8553186093785776e-25, relativeTolerance: 1e-12),
        Reference(k: 40, lambda: 5, survival: 8.5500237568428846e-23, relativeTolerance: 1e-12),
        Reference(k: 60, lambda: 10, survival: 6.5219033278183711e-27, relativeTolerance: 1e-12),
        Reference(k: 50, lambda: 0.001, survival: 3.2847275170409999e-215, relativeTolerance: 1e-12),
        Reference(k: 900, lambda: 1000, survival: 0.99937740221572491, relativeTolerance: 1e-11),
        Reference(k: 1000, lambda: 1000, survival: 0.50420524418021551, relativeTolerance: 1e-11),
        Reference(k: 1100, lambda: 1000, survival: 0.00096263040586655718, relativeTolerance: 1e-11),
        Reference(k: 1200, lambda: 1000, survival: 4.6842038558722563e-10, relativeTolerance: 1e-11),
        Reference(k: 101_000, lambda: 100_000, survival: 0.00079980104155454273, relativeTolerance: 1e-9),
    ]

    @Test("Matches R ppois(k - 1, λ, lower.tail = FALSE)", arguments: references)
    func matchesReference(_ reference: Reference) throws {
        let survival: Double = try poissonSurvival(k: reference.k, lambda: reference.lambda)
        if reference.relativeTolerance.isZero {
            #expect(survival.isEqual(to: reference.survival))
        } else {
            let error: Double = abs(survival - reference.survival) / reference.survival
            #expect(error <= reference.relativeTolerance, "relative error \(error)")
        }
    }

    @Test("k = 0 is certain for every rate, including zero")
    func zeroIsCertain() throws {
        for lambda in [0.0, 1e-300, 0.5, 3, 1000, 1e6] {
            #expect(try poissonSurvival(k: 0, lambda: lambda).isEqual(to: 1))
        }
    }

    @Test("A zero rate never reaches k ≥ 1")
    func zeroRate() throws {
        for k in [1, 2, 10, 1000] {
            #expect(try poissonSurvival(k: k, lambda: 0.0).isEqual(to: 0))
        }
    }

    @Test("Agrees with 1 − poissonCDF where that subtraction is accurate")
    func agreesWithComplementInTheBody() throws {
        for lambda in [0.5, 1, 2.5, 7, 14] {
            for k in 1...30 {
                let survival: Double = try poissonSurvival(k: k, lambda: lambda)
                guard survival > 1e-3 else { continue }
                let complement: Double = 1 - poissonCDF(Double(k - 1), µ: lambda)
                #expect(abs(survival - complement) < 1e-14, "k=\(k), λ=\(lambda)")
            }
        }
    }

    @Test("Keeps the deep tail where 1 − poissonCDF has nothing left")
    func keepsTheTailTheComplementLoses() throws {
        // P(X ≥ 20 | λ = 1) = 1.59e-19. The CDF below it is 1 to within a rounding of the
        // sum, so the complement is that rounding, of order 1e-16: not one correct digit, and
        // about a thousand times too large (or zero, "impossible"). Either way the size is lost.
        // Which one is the platform's rounding: macOS leaves noise, Linux (CI) leaves exactly 0,
        // a relative error of 1. "Not one correct digit" is a relative error of at least 0.5.
        let truth: Double = 1.5875276010732626e-19
        let complement: Double = 1 - poissonCDF(19.0, µ: 1.0)
        #expect(abs(complement - truth) / truth >= 0.5, "complement \(complement)")
        let survival: Double = try poissonSurvival(k: 20, lambda: 1.0)
        #expect(abs(survival - truth) / truth < 1e-12)
    }

    @Test("Successive differences are the pmf")
    func differencesAreThePMF() throws {
        for lambda in [0.3, 2.0, 9.5] {
            for k in 0...25 {
                let here: Double = try poissonSurvival(k: k, lambda: lambda)
                let next: Double = try poissonSurvival(k: k + 1, lambda: lambda)
                let pmf: Double = poisson(k, µ: lambda)
                #expect(abs((here - next) - pmf) <= 1e-14 + 1e-12 * pmf, "k=\(k), λ=\(lambda)")
            }
        }
    }

    @Test("Falls with k and rises with λ")
    func monotone() throws {
        var previous: Double = 1
        for k in 0...40 {
            let value: Double = try poissonSurvival(k: k, lambda: 6)
            #expect(value <= previous)
            previous = value
        }
        var lower: Double = 0
        for lambda in stride(from: 0.0, through: 20, by: 0.25) {
            let value: Double = try poissonSurvival(k: 8, lambda: lambda)
            #expect(value >= lower)
            lower = value
        }
    }

    @Test("Generic over Real")
    func float() throws {
        let value: Float = try poissonSurvival(k: 5, lambda: Float(1))
        #expect(abs(Double(value) - 0.0036598468273437131) / 0.0036598468273437131 < 1e-5)
    }

    // MARK: - Refusals

    @Test("A negative k is refused")
    func refusesNegativeK() {
        #expect(throwsSurvivalRefusal("k = -1") { _ = try poissonSurvival(k: -1, lambda: 2.0) })
    }

    @Test("A rate that is negative or not finite is refused",
          arguments: [-1.0, -1e-300, Double.nan, Double.infinity, -Double.infinity])
    func refusesInvalidRate(lambda: Double) {
        #expect(throwsSurvivalRefusal("λ = \(lambda)") { _ = try poissonSurvival(k: 3, lambda: lambda) })
    }
}

/// Whether `body` throws `BusinessMathError.invalidInput`; any other outcome is recorded.
fileprivate func throwsSurvivalRefusal(_ label: String, _ body: () throws -> Void) -> Bool {
    do {
        try body()
        Issue.record("\(label) was accepted")
        return false
    } catch let error as BusinessMathError {
        guard case .invalidInput = error else {
            Issue.record("\(label): expected invalidInput, got \(error)")
            return false
        }
        return true
    } catch {
        Issue.record("\(label): expected BusinessMathError, got \(error)")
        return false
    }
}
