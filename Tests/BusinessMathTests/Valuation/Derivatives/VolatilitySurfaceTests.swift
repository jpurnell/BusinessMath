//
//  VolatilitySurfaceTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 4/15/26.
//

import Testing
@testable import BusinessMath

@Suite("Volatility Surface Tests")
struct VolatilitySurfaceTests {

    // MARK: - Test Data

    /// A standard test surface with known values.
    private func makeTestSurface() -> VolatilitySurface {
        VolatilitySurface(
            underlier: "SPX",
            strikes: [90.0, 95.0, 100.0, 105.0, 110.0],
            expiries: [0.25, 0.5, 1.0],
            vols: [
                [0.25, 0.22, 0.20, 0.21, 0.24],  // 3-month
                [0.24, 0.21, 0.19, 0.20, 0.23],  // 6-month
                [0.23, 0.20, 0.18, 0.19, 0.22],  // 1-year
            ]
        )
    }

    // MARK: - 1. Bilinear interpolation at grid points = exact match

    @Test func interpolationAtGridPointsExactMatch() {
        let surface = makeTestSurface()

        // Check every grid point
        for (ei, expiry) in surface.expiries.enumerated() {
            for (si, strike) in surface.strikes.enumerated() {
                let vol = surface.impliedVol(strike: strike, expiry: expiry)
                #expect(
                    abs((vol) - (surface.vols[ei][si])) <= (1e-12),
                    "Grid point (\(strike), \(expiry)) should match exactly"
                )
            }
        }
    }

    // MARK: - 2. Interpolation between grid points

    @Test func interpolationBetweenGridPoints() {
        let surface = makeTestSurface()

        // Midpoint between strikes 95 and 100 at expiry 0.25
        let vol = surface.impliedVol(strike: 97.5, expiry: 0.25)
        let expected = (0.22 + 0.20) / 2.0  // linear midpoint
        #expect(abs((vol) - (expected)) <= (1e-12))

        // Midpoint between expiries 0.25 and 0.5 at strike 100
        let vol2 = surface.impliedVol(strike: 100.0, expiry: 0.375)
        let expected2 = (0.20 + 0.19) / 2.0
        #expect(abs((vol2) - (expected2)) <= (1e-12))

        // Interior point: strike=97.5, expiry=0.375 (bilinear)
        let vol3 = surface.impliedVol(strike: 97.5, expiry: 0.375)
        // Strike midpoint at expiry 0.25: (0.22+0.20)/2 = 0.21
        // Strike midpoint at expiry 0.50: (0.21+0.19)/2 = 0.20
        // Expiry midpoint: (0.21+0.20)/2 = 0.205
        #expect(abs((vol3) - (0.205)) <= (1e-12))
    }

    // MARK: - 3. Flat vol surface: same vol everywhere

    @Test func flatVolSurface() {
        let flatVol = 0.20
        let surface = VolatilitySurface(
            underlier: "FLAT",
            strikes: [80.0, 90.0, 100.0, 110.0, 120.0],
            expiries: [0.1, 0.5, 1.0, 2.0],
            vols: Array(repeating: Array(repeating: flatVol, count: 5), count: 4)
        )

        // Test at grid points
        #expect(abs((surface.impliedVol(strike: 100.0, expiry: 0.5)) - (flatVol)) <= (1e-12))

        // Test at interpolated points
        #expect(abs((surface.impliedVol(strike: 95.0, expiry: 0.3)) - (flatVol)) <= (1e-12))
        #expect(abs((surface.impliedVol(strike: 115.0, expiry: 1.5)) - (flatVol)) <= (1e-12))
    }

    // MARK: - 4. No-arbitrage: call price decreasing in strike

    @Test func callPriceDecreasingInStrike() {
        let surface = makeTestSurface()
        let spot = 100.0
        let rate = 0.05
        let expiry = 0.5

        var previousPrice = Double.infinity
        let testStrikes = stride(from: 85.0, through: 115.0, by: 1.0)

        for strike in testStrikes {
            let vol = surface.impliedVol(strike: strike, expiry: expiry)
            let price = BlackScholesModel<Double>.price(
                optionType: .call,
                spotPrice: spot,
                strikePrice: strike,
                timeToExpiry: expiry,
                riskFreeRate: rate,
                volatility: vol
            )
            #expect(
                price <= previousPrice + 1e-10,
                "Call price should decrease as strike increases (strike=\(strike))"
            )
            previousPrice = price
        }
    }

    // MARK: - 5. SABR: beta=1 (lognormal), ATM vol approx alpha

    @Test func sabrLognormalATMVol() {
        let alpha = 0.25
        let params = SABRParameters(alpha: alpha, beta: 1.0, rho: 0.0, nu: 0.0)

        // With nu=0 and rho=0, ATM vol should be very close to alpha
        let vol = params.impliedVol(forward: 100.0, strike: 100.0, timeToExpiry: 1.0)
        #expect(abs((vol) - (alpha)) <= (0.005),
                "For beta=1, nu=0, rho=0, ATM vol should approximately equal alpha")
    }

    // MARK: - 6. SABR: rho < 0 produces skew

    @Test func sabrNegativeRhoProducesSkew() {
        let params = SABRParameters(alpha: 0.3, beta: 0.5, rho: -0.5, nu: 0.4)
        let forward = 100.0
        let t = 1.0

        let volLowStrike = params.impliedVol(forward: forward, strike: 80.0, timeToExpiry: t)
        let volATM = params.impliedVol(forward: forward, strike: forward, timeToExpiry: t)
        let volHighStrike = params.impliedVol(forward: forward, strike: 120.0, timeToExpiry: t)

        // Negative rho: low-strike vols > high-strike vols (downward skew direction)
        #expect(volLowStrike > volATM,
                "Negative rho should produce higher vol for low strikes")
        #expect(volLowStrike > volHighStrike,
                "Negative rho should skew: low-strike vol > high-strike vol")
    }

    // MARK: - 7. SABR: nu > 0 produces smile (wings above ATM)

    @Test func sabrPositiveNuProducesSmile() {
        let params = SABRParameters(alpha: 0.3, beta: 0.5, rho: 0.0, nu: 0.8)
        let forward = 100.0
        let t = 1.0

        let volLowStrike = params.impliedVol(forward: forward, strike: 80.0, timeToExpiry: t)
        let volATM = params.impliedVol(forward: forward, strike: forward, timeToExpiry: t)
        let volHighStrike = params.impliedVol(forward: forward, strike: 120.0, timeToExpiry: t)

        // With rho=0 and nu>0, both wings should be above ATM (smile shape)
        #expect(volLowStrike > volATM,
                "Low-strike vol should exceed ATM vol for nu > 0")
        #expect(volHighStrike > volATM,
                "High-strike vol should exceed ATM vol for nu > 0")
    }

    // MARK: - 8. SABR calibration: fit to 5-point market data

    @Test func sabrCalibrationFitsMarketData() {
        // Generate "market" data from known SABR params
        let trueParams = SABRParameters(alpha: 0.35, beta: 0.5, rho: -0.3, nu: 0.5)
        let forward = 100.0
        let t = 1.0
        let strikes = [85.0, 92.0, 100.0, 108.0, 115.0]
        let marketVols = strikes.map { trueParams.impliedVol(forward: forward, strike: $0, timeToExpiry: t) }

        // Calibrate
        let calibrated = VolatilitySurface.calibrateSABR(
            forward: forward,
            strikes: strikes,
            marketVols: marketVols,
            timeToExpiry: t,
            beta: 0.5
        )

        // Check fit quality: error < 1 vol point (0.01) for each strike
        for i in 0..<strikes.count {
            let fittedVol = calibrated.impliedVol(
                forward: forward, strike: strikes[i], timeToExpiry: t)
            #expect(abs((fittedVol) - (marketVols[i])) <= (0.01),
                    "Calibrated vol at strike \(strikes[i]) should match within 1 vol point")
        }
    }

    // MARK: - 9. Edge cases: strike and expiry at boundary

    @Test func edgeCasesAtBoundary() {
        let surface = makeTestSurface()

        // Strike below minimum: should clamp to boundary
        let volLowStrike = surface.impliedVol(strike: 50.0, expiry: 0.5)
        let volMinStrike = surface.impliedVol(strike: 90.0, expiry: 0.5)
        #expect(abs((volLowStrike) - (volMinStrike)) <= (1e-12),
                "Below-minimum strike should clamp to boundary")

        // Strike above maximum: should clamp to boundary
        let volHighStrike = surface.impliedVol(strike: 200.0, expiry: 0.5)
        let volMaxStrike = surface.impliedVol(strike: 110.0, expiry: 0.5)
        #expect(abs((volHighStrike) - (volMaxStrike)) <= (1e-12),
                "Above-maximum strike should clamp to boundary")

        // Expiry below minimum: should clamp to boundary
        let volLowExpiry = surface.impliedVol(strike: 100.0, expiry: 0.01)
        let volMinExpiry = surface.impliedVol(strike: 100.0, expiry: 0.25)
        #expect(abs((volLowExpiry) - (volMinExpiry)) <= (1e-12),
                "Below-minimum expiry should clamp to boundary")

        // Expiry above maximum: should clamp to boundary
        let volHighExpiry = surface.impliedVol(strike: 100.0, expiry: 5.0)
        let volMaxExpiry = surface.impliedVol(strike: 100.0, expiry: 1.0)
        #expect(abs((volHighExpiry) - (volMaxExpiry)) <= (1e-12),
                "Above-maximum expiry should clamp to boundary")
    }

    // MARK: - 10. Single-expiry surface

    @Test func singleExpirySurface() {
        let surface = VolatilitySurface(
            underlier: "AAPL",
            strikes: [90.0, 100.0, 110.0],
            expiries: [0.25],
            vols: [
                [0.30, 0.25, 0.28]
            ]
        )

        // Grid points
        #expect(abs((surface.impliedVol(strike: 90.0, expiry: 0.25)) - (0.30)) <= (1e-12))
        #expect(abs((surface.impliedVol(strike: 100.0, expiry: 0.25)) - (0.25)) <= (1e-12))
        #expect(abs((surface.impliedVol(strike: 110.0, expiry: 0.25)) - (0.28)) <= (1e-12))

        // Interpolated strike
        let vol = surface.impliedVol(strike: 95.0, expiry: 0.25)
        #expect(abs((vol) - ((0.30 + 0.25) / 2.0)) <= (1e-12))

        // Different expiry should clamp (only one expiry)
        let volOtherExpiry = surface.impliedVol(strike: 100.0, expiry: 1.0)
        #expect(abs((volOtherExpiry) - (0.25)) <= (1e-12))
    }
}
