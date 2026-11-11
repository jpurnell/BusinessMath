import Testing
import Foundation
@testable import BusinessMath

/// The at-the-money SABR branch divides by `fBeta²`, where `fBeta = forward^(1 − β)`.
///
/// The domain guard admits any positive forward, and a positive `fBeta` can still square to
/// zero: at `forward = 1e-200`, `β = 0`, `fBeta = 1e-200` and `fBeta² = 0` in Double. The
/// correction term was then `α²/24 / 0 = +∞` and the implied volatility came back infinite,
/// a number that prices every option at the forward. An implied volatility that cannot be
/// computed is `nan`, as the function's documentation already promises for unusable input.
@Suite("SABR ATM implied vol at an underflowing forward")
struct SABRModelUnderflowTests {

    @Test("A forward whose (1 − β) power squares to zero is undefined, not infinite")
    func underflowingForwardIsUndefined() {
        let model = SABRParameters(alpha: 0.2, beta: 0, rho: 0, nu: 0.3)
        let vol: Double = model.impliedVol(forward: 1e-200, strike: 1e-200, timeToExpiry: 1)
        #expect(vol.isNaN, "got \(vol)")
    }

    /// Control: an ordinary ATM call is finite and positive, and unchanged by the guard.
    @Test("An ordinary at-the-money implied vol is finite")
    func ordinaryForwardIsFinite() {
        let model = SABRParameters(alpha: 0.2, beta: 0.5, rho: -0.3, nu: 0.4)
        let vol: Double = model.impliedVol(forward: 100, strike: 100, timeToExpiry: 1)
        #expect(vol.isFinite)
        #expect(vol > 0)
    }
}
