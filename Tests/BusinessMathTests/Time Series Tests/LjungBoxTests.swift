//
//  LjungBoxTests.swift
//  BusinessMath
//
//  RED phase — Step 6 (part 1) of the Forecast Evaluation & Diagnostics tier.
//  Ljung–Box portmanteau test for residual autocorrelation ("is there structure left?").
//
//  Reference truth: Ljung & Box (1978), Q = n(n+2) Σ ρ_k²/(n−k). Exact hand-computed
//  value for [1,2,3,4] at lags=2 (ACF = [0.25, −0.30]).
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Ljung–Box test")
struct LjungBoxTests {

    private func series(_ values: [Double]) -> TimeSeries<Double> {
        let start = Period.month(year: 2020, month: 1)
        return TimeSeries(periods: (0..<values.count).map { start.advanced(by: $0) }, values: values)
    }

    @Test("Q matches the hand-computed value for [1,2,3,4] at lags=2")
    func exactStatistic() throws {
        // ACF = [0.25, -0.30]; Q = 4·6·(0.25²/3 + 0.30²/2) = 24·0.0658333 = 1.58
        let result = try series([1, 2, 3, 4]).ljungBox(lags: 2)
        #expect(abs(result.statistic - 1.58) < 1e-6)
        #expect(result.degreesOfFreedom == 2)
    }

    @Test("Strongly autocorrelated series rejects white noise")
    func rampRejects() throws {
        let ramp = series((1...20).map(Double.init))
        let result = try ramp.ljungBox(lags: 5)
        #expect(result.rejectsWhiteNoise(alpha: 0.05))
        #expect(result.pValue < 0.05)
    }

    @Test("Constant series has Q=0 and fails to reject white noise")
    func constantFailsToReject() throws {
        let result = try series(Array(repeating: 5.0, count: 10)).ljungBox(lags: 3)
        #expect(result.statistic == 0)
        #expect(!result.rejectsWhiteNoise(alpha: 0.05))
    }

    @Test("dof ≤ 0 (lags ≤ fittedParameters) throws")
    func invalidDof() throws {
        #expect(throws: (any Error).self) {
            _ = try self.series((1...10).map(Double.init)).ljungBox(lags: 2, fittedParameters: 2)
        }
    }
}
