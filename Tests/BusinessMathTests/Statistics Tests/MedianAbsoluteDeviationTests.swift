//
//  MedianAbsoluteDeviationTests.swift
//  BusinessMath
//
//  The median absolute deviation against R and SciPy, raw and normal-consistent.
//
//  Reference values from Scripts/reference-fixtures/generate_hub_statistics.R (R 4.6.2,
//  `mad(x, constant = 1)`, `mad(x)` and `mad(x, constant = 1 / qnorm(3/4))`), checked against
//  generate_hub_statistics.py (SciPy 1.17.1, `median_abs_deviation(x)` and `scale="normal"`).
//  The two agree exactly on every case here.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Median absolute deviation: reference values, the two scales, robustness and refusals.
///
/// ## Tolerance
///
/// Raw: exact (`isEqual(to:)`); it is a median of exact differences. Normal-consistent: relative 1e-15
/// against `1/qnorm(3/4)`. Against R's default `mad(x)`, which rounds that constant to
/// 1.4826, relative 2e-6: the gap is the rounding, 1.5e-6, and is stated rather than hidden.
@Suite("Median absolute deviation")
struct MedianAbsoluteDeviationTests {

    struct Reference: Sendable, CustomTestStringConvertible {
        let name: String
        let values: [Double]
        let raw: Double
        let rDefault: Double
        let normalConsistent: Double
        var testDescription: String { name }
    }

    /// R 4.6.2, 17 significant digits.
    static let references: [Reference] = [
        Reference(name: "outlier", values: [1, 2, 3, 4, 100],
                  raw: 1, rDefault: 1.4825999999999999, normalConsistent: 1.482602218505602),
        Reference(name: "even", values: [1, 2, 3, 4],
                  raw: 1, rDefault: 1.4825999999999999, normalConsistent: 1.482602218505602),
        Reference(name: "single", values: [7], raw: 0, rDefault: 0, normalConsistent: 0),
        Reference(name: "constant", values: [5, 5, 5], raw: 0, rDefault: 0, normalConsistent: 0),
        Reference(name: "signed", values: [-3.5, 2.25, 0, 10, -1, 4.75],
                  raw: 2.875, rDefault: 4.2624749999999993, normalConsistent: 4.2624813782036055),
        Reference(name: "lowCounts", values: [0, 0, 1, 0, 2, 0, 0, 1, 0, 0, 0, 3, 0, 1],
                  raw: 0, rDefault: 0, normalConsistent: 0),
        Reference(name: "overdispersed", values: [3, 8, 1, 12, 4, 0, 6, 15, 2, 5, 9, 1, 7, 3],
                  raw: 3, rDefault: 4.4478, normalConsistent: 4.4478066555168061),
    ]

    @Test("Raw MAD matches R's mad(x, constant = 1) exactly", arguments: references)
    func rawMatchesReference(_ reference: Reference) throws {
        #expect(try medianAbsoluteDeviation(reference.values).isEqual(to: reference.raw))
        #expect(try medianAbsoluteDeviation(reference.values, scale: .raw).isEqual(to: reference.raw))
    }

    @Test("Normal-consistent MAD matches 1/qnorm(3/4) × raw", arguments: references)
    func normalConsistentMatchesReference(_ reference: Reference) throws {
        let mad: Double = try medianAbsoluteDeviation(reference.values, scale: .normalConsistent)
        #expect(abs(mad - reference.normalConsistent) <= 1e-15 * max(1, reference.normalConsistent))
    }

    @Test("Normal-consistent MAD is within R's rounding of mad(x)", arguments: references)
    func normalConsistentNearRDefault(_ reference: Reference) throws {
        let mad: Double = try medianAbsoluteDeviation(reference.values, scale: .normalConsistent)
        #expect(abs(mad - reference.rDefault) <= 2e-6 * max(1, reference.rDefault))
    }

    @Test("The normal-consistency factor is 1/Φ⁻¹(3/4)")
    func normalConsistencyFactor() {
        let factor: Double = MedianAbsoluteDeviationScale.normalConsistent.factor()
        #expect(abs(factor - 1.482602218505602) < 1e-15)
        let rawFactor: Double = MedianAbsoluteDeviationScale.raw.factor()
        #expect(rawFactor.isEqual(to: 1))
    }

    @Test("Order does not matter; a shift does not move it; a scale multiplies it")
    func invariances() throws {
        let values: [Double] = [3, 8, 1, 12, 4, 0, 6, 15, 2, 5, 9, 1, 7, 3]
        let base: Double = try medianAbsoluteDeviation(values)
        #expect(try medianAbsoluteDeviation(values.reversed()).isEqual(to: base))
        #expect(try medianAbsoluteDeviation(values.sorted()).isEqual(to: base))
        #expect(try medianAbsoluteDeviation(values.map { $0 + 1000 }).isEqual(to: base))
        #expect(try medianAbsoluteDeviation(values.map { $0 * 4 }).isEqual(to: base * 4))
        #expect(try medianAbsoluteDeviation(values.map { -$0 }).isEqual(to: base))
    }

    @Test("One outlier cannot move it, however large")
    func robustToOneOutlier() throws {
        let flat: [Double] = [4, 5, 3, 4, 6, 5, 4, 3, 5, 4, 6, 4, 5]
        let base: Double = try medianAbsoluteDeviation(flat + [5])
        for outlier in [50.0, 5_000, 5e12] {
            #expect(try medianAbsoluteDeviation(flat + [outlier]).isEqual(to: base))
        }
    }

    @Test("Generic over Real")
    func float() throws {
        let values: [Float] = [1, 2, 3, 4, 100]
        #expect(try medianAbsoluteDeviation(values).isEqual(to: Float(1)))
    }

    // MARK: - Refusals

    @Test("An empty sample is insufficient data")
    func refusesEmpty() {
        #expect(throws: BusinessMathError.insufficientData(
            required: 1, actual: 0, context: "medianAbsoluteDeviation needs at least one value")) {
            _ = try medianAbsoluteDeviation([Double]())
        }
    }

    @Test("A NaN or an infinity is refused rather than propagated",
          arguments: [Double.nan, Double.infinity, -Double.infinity])
    func refusesNonFinite(bad: Double) {
        var kind: String = "accepted"
        do {
            _ = try medianAbsoluteDeviation([1, 2, bad, 4])
        } catch let error as BusinessMathError {
            if case .invalidInput = error { kind = "invalidInput" } else { kind = "\(error)" }
        } catch {
            kind = "\(error)"
        }
        #expect(kind == "invalidInput", "\(bad)")
    }
}
