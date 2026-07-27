//
//  StationarityTests.swift
//  BusinessMath
//
//  RED phase — Step 6 (part 2) of the Forecast Evaluation & Diagnostics tier.
//  ADF and KPSS unit-root / stationarity tests (R1).
//
//  Reference truth: Dickey & Fuller (1979), Kwiatkowski et al. (1992). Deterministic
//  fixtures: a bounded mean-reverting sine (stationary) and an integrated chaotic
//  series (a deterministic random-walk stand-in — non-stationary). ADF and KPSS have
//  opposite null hypotheses, so they should AGREE on these clear cases.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Stationarity: ADF & KPSS")
struct StationarityTests {

    private func series(_ values: [Double]) -> TimeSeries<Double> {
        let start = Period.month(year: 2020, month: 1)
        return TimeSeries(periods: (0..<values.count).map { start.advanced(by: $0) }, values: values)
    }

    /// Bounded, mean-reverting → stationary.
    private func stationary(n: Int) -> TimeSeries<Double> {
        series((0..<n).map { 10.0 * sin(2.0 * .pi * Double($0) / 12.0) })
    }

    /// Integrated centered-chaotic increments → deterministic random-walk (non-stationary).
    private func nonStationary(n: Int) -> TimeSeries<Double> {
        var x = 0.4, acc = 0.0, out: [Double] = []
        for _ in 0..<n {
            x = 3.99 * x * (1.0 - x)
            acc += (x - 0.5)            // zero-mean, non-constant increments
            out.append(acc)
        }
        return series(out)
    }

    // MARK: - ADF

    @Test("ADF: mean-reverting series is stationary (rejects unit root)")
    func adfStationary() throws {
        let result = try stationary(n: 60).augmentedDickeyFuller(lag: 1)
        #expect(result.isStationary)
    }

    @Test("ADF: random-walk series is non-stationary (fails to reject unit root)")
    func adfNonStationary() throws {
        let result = try nonStationary(n: 60).augmentedDickeyFuller(lag: 1)
        #expect(!result.isStationary)
        #expect(result.recommendation.lowercased().contains("difference"))
    }

    // MARK: - KPSS

    @Test("KPSS: mean-reverting series is stationary (fails to reject H0)")
    func kpssStationary() throws {
        let result = try stationary(n: 60).kpss(regression: .level)
        #expect(result.isStationary)
    }

    @Test("KPSS: random-walk series is non-stationary (rejects H0)")
    func kpssNonStationary() throws {
        let result = try nonStationary(n: 60).kpss(regression: .level)
        #expect(!result.isStationary)
    }

    // MARK: - Complementarity (opposite nulls should agree on clear cases)

    @Test("ADF and KPSS agree that the stationary series is stationary")
    func agreementStationary() throws {
        let s = stationary(n: 60)
        #expect(try s.augmentedDickeyFuller(lag: 1).isStationary)
        #expect(try s.kpss(regression: .level).isStationary)
    }

    @Test("ADF and KPSS agree that the random-walk series is non-stationary")
    func agreementNonStationary() throws {
        let s = nonStationary(n: 60)
        #expect(try !s.augmentedDickeyFuller(lag: 1).isStationary)
        #expect(try !s.kpss(regression: .level).isStationary)
    }
}
