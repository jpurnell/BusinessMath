//
//  OptionZeroDiffusionTests.swift
//  BusinessMath
//
//  Both option-pricing models returned NaN for ordinary inputs, and one returned a
//  confidently wrong number.
//
//  Neither `BlackScholesModel` nor `BinomialTreeModel` contained a single `guard`,
//  `precondition` or `throws`. Three divisors go to zero on inputs a caller has every
//  reason to supply:
//
//  * `calculateD1` divides by `volatility * sqrt(timeToExpiry)` — zero at expiry, and zero
//    on an asset with no volatility.
//  * `gamma` divides by `spotPrice * volatility * sqrt(timeToExpiry)` — zero for all of
//    those, and also for a spot of zero.
//  * the tree's risk-neutral probability divides by `u - d`, which is zero exactly when
//    `volatility * sqrt(dt)` is.
//
//  Measured before and after, same fixtures both sides:
//
//  | case | before | after |
//  |---|---|---|
//  | sound call and put, all five Greeks | — | **bit-identical** |
//  | at expiry, at the money | **every value NaN** | price 0, delta 0, gamma inf, theta 0 |
//  | at expiry, in the money | price 20, delta 1, **gamma NaN, theta NaN** | gamma 0, theta -5 |
//  | zero volatility | price/delta/theta/rho right, **gamma NaN** | gamma 0 |
//  | spot of zero | **gamma NaN** | gamma 0 |
//  | tree, every degenerate case | **NaN** | the deterministic value |
//  | **tree with `steps: 0`** | **0.0** | traps |
//
//  That last row is the one worth reading twice. A call worth 10.43 came back as 0.0 — no
//  NaN, no error, just a wrong number — from a parameter that is public and has a default.
//

import Testing
@testable import BusinessMath

@Suite("Options price their zero-diffusion limits instead of returning NaN")
struct OptionZeroDiffusionTests {

	private typealias BS = BlackScholesModel<Double>
	private typealias Tree = BinomialTreeModel<Double>

	private static let rate = 0.05
	private static let strike = 100.0

	/// `100 * exp(-0.05)` — the forward strike a one-year zero-volatility option is measured
	/// against, and the point where its payoff has its kink.
	private static let discountedStrike = 95.1229424500714

	private static func price(_ type: OptionType, t: Double, vol: Double, spot: Double) -> Double {
		BS.price(optionType: type, spotPrice: spot, strikePrice: strike,
				 timeToExpiry: t, riskFreeRate: rate, volatility: vol)
	}

	private static func greeks(_ type: OptionType, t: Double, vol: Double, spot: Double) -> Greeks<Double> {
		BS.greeks(optionType: type, spotPrice: spot, strikePrice: strike,
				  timeToExpiry: t, riskFreeRate: rate, volatility: vol)
	}

	// MARK: - Nothing that worked before has moved

	/// Every Greek of a healthy option, to the bit. These are the numbers the unguarded code
	/// produced, so the new branch is provably not reaching any of them.
	@Test("SoundCall_BitIdentical") func soundCallBitIdentical() {
		let p = Self.price(.call, t: 1.0, vol: 0.2, spot: 100)
		let g = Self.greeks(.call, t: 1.0, vol: 0.2, spot: 100)
		#expect(p.isEqual(to: 10.450583572185565))
		#expect(g.delta.isEqual(to: 0.6368306511756191))
		#expect(g.gamma.isEqual(to: 0.018762017345846895))
		#expect(g.vega.isEqual(to: 37.52403469169379))
		#expect(g.theta.isEqual(to: -6.414027546438197))
		#expect(g.rho.isEqual(to: 53.232481545376345))
	}

	@Test("SoundPut_BitIdentical") func soundPutBitIdentical() {
		let p = Self.price(.put, t: 1.0, vol: 0.2, spot: 100)
		let g = Self.greeks(.put, t: 1.0, vol: 0.2, spot: 100)
		#expect(p.isEqual(to: 5.573526022256971))
		#expect(g.delta.isEqual(to: -0.3631693488243809))
		#expect(g.gamma.isEqual(to: 0.018762017345846895))
		#expect(g.vega.isEqual(to: 37.52403469169379))
		#expect(g.theta.isEqual(to: -1.657880423934626))
		#expect(g.rho.isEqual(to: -41.89046090469506))
	}

	@Test("SoundTree_BitIdentical") func soundTreeBitIdentical() {
		let v = Tree.price(optionType: .call, americanStyle: false, spotPrice: 100,
						   strikePrice: Self.strike, timeToExpiry: 1.0,
						   riskFreeRate: Self.rate, volatility: 0.2, steps: 100)
		#expect(v.isEqual(to: 10.430611662249113))
	}

	// MARK: - At expiry

	/// Valuing an option on the day it expires. The answer is the intrinsic value; it used to
	/// be NaN for every field.
	@Test("AtExpiry_AtTheMoney") func atExpiryAtTheMoney() {
		#expect(Self.price(.call, t: 0.0, vol: 0.2, spot: 100).isEqual(to: 0.0),
				"an at-the-money option expires worthless")
		let g = Self.greeks(.call, t: 0.0, vol: 0.2, spot: 100)
		#expect(g.delta.isEqual(to: 0.0))
		#expect(g.vega.isEqual(to: 0.0))
		#expect(g.theta.isEqual(to: 0.0))
		#expect(g.rho.isEqual(to: 0.0))
		// Gamma at the kink is a Dirac delta, reported as infinity rather than as a missing
		// number — the value is unbounded, not unknown.
		#expect(g.gamma.isInfinite && g.gamma > 0, "gamma is unbounded at the strike")
	}

	@Test("AtExpiry_InTheMoney") func atExpiryInTheMoney() {
		#expect(Self.price(.call, t: 0.0, vol: 0.2, spot: 120).isEqual(to: 20.0),
				"a call 20 in the money is worth 20 at expiry")
		#expect(Self.price(.put, t: 0.0, vol: 0.2, spot: 80).isEqual(to: 20.0),
				"and so is a put 20 in the money")

		// The price and delta were already right here — `d1` saturated the normal CDF — but
		// gamma and theta were NaN.
		let call = Self.greeks(.call, t: 0.0, vol: 0.2, spot: 120)
		#expect(call.delta.isEqual(to: 1.0))
		#expect(call.gamma.isEqual(to: 0.0), "no curvature away from the kink")
		#expect(call.theta.isEqual(to: -5.0), "the carry on the strike, previously NaN")

		let put = Self.greeks(.put, t: 0.0, vol: 0.2, spot: 80)
		#expect(put.delta.isEqual(to: -1.0))
		#expect(put.gamma.isEqual(to: 0.0))
		#expect(put.theta.isEqual(to: 5.0))
	}

	/// Out of the money at expiry was **already correct** and this test does not pretend to
	/// catch anything: run against the unguarded source it passes, because `d1` went to
	/// negative infinity and the normal CDF saturated cleanly to zero. It is here to pin the
	/// side of the kink that always worked, so a later edit cannot quietly take it with it.
	@Test("AtExpiry_OutOfTheMoney") func atExpiryOutOfTheMoney() {
		#expect(Self.price(.call, t: 0.0, vol: 0.2, spot: 80).isEqual(to: 0.0))
		#expect(Self.price(.put, t: 0.0, vol: 0.2, spot: 120).isEqual(to: 0.0))
	}

	// MARK: - No volatility

	/// A non-volatile asset arrives at its forward with certainty, so the option is the
	/// discounted payoff on that forward. The *price* was already right; gamma was NaN.
	@Test("ZeroVolatility_IsTheDiscountedForward") func zeroVolatilityIsTheDiscountedForward() {
		let p = Self.price(.call, t: 1.0, vol: 0.0, spot: 100)
		#expect(p.isEqual(to: 4.877057549928594), "100 - 100 * exp(-0.05), unchanged")
		let g = Self.greeks(.call, t: 1.0, vol: 0.0, spot: 100)
		#expect(g.delta.isEqual(to: 1.0), "unchanged")
		#expect(g.theta.isEqual(to: -4.75614712250357), "unchanged")
		#expect(g.rho.isEqual(to: 95.1229424500714), "unchanged")
		#expect(g.vega.isEqual(to: 0.0), "no diffusion to be sensitive to")
		#expect(g.gamma.isEqual(to: 0.0), "previously NaN")

		// The matching put finishes out of the money against that same forward.
		#expect(Self.price(.put, t: 1.0, vol: 0.0, spot: 100).isEqual(to: 0.0))
	}

	/// **This case changed by more than NaN to a number, and that is deliberate.**
	///
	/// At exactly the forward strike the old code returned a price of 0.0 *and* a delta of
	/// 1.0 — a worthless option with full delta. It reached that because
	/// `log(95.1229424500714 / 100) + 0.05` lands a hair above zero in binary, so the
	/// division was `0+ / 0`, `d1` went to `+infinity`, and the normal CDF saturated to 1.
	///
	/// Delta is genuinely undefined at the kink: the left limit is 0 and the right limit is 1.
	/// The new code takes the branch that agrees with the price it is returning.
	@Test("ZeroVolatility_ExactlyAtTheForwardStrike") func zeroVolatilityAtTheForwardStrike() {
		let spot = Self.discountedStrike
		#expect(Self.price(.call, t: 1.0, vol: 0.0, spot: spot).isEqual(to: 0.0),
				"worth nothing, as it was before")
		let g = Self.greeks(.call, t: 1.0, vol: 0.0, spot: spot)
		#expect(g.delta.isEqual(to: 0.0), "was 1.0, which disagreed with a price of zero")
		#expect(g.theta.isEqual(to: 0.0), "was -4.756")
		#expect(g.rho.isEqual(to: 0.0), "was 95.123")
		#expect(g.gamma.isInfinite && g.gamma > 0, "the kink is here")
	}

	// MARK: - A worthless underlying

	/// Zero is absorbing under geometric Brownian motion, so the option is worth nothing and
	/// has no curvature. Every Greek but gamma was already right.
	@Test("ZeroSpot_HasNoCurvature") func zeroSpotHasNoCurvature() {
		#expect(Self.price(.call, t: 1.0, vol: 0.2, spot: 0.0).isEqual(to: 0.0))
		let g = Self.greeks(.call, t: 1.0, vol: 0.2, spot: 0.0)
		#expect(g.delta.isEqual(to: 0.0))
		#expect(g.gamma.isEqual(to: 0.0), "previously NaN")
		#expect(g.vega.isEqual(to: 0.0))
	}

	// MARK: - The tree

	@Test("Tree_ZeroVolatility_MatchesBlackScholes") func treeZeroVolatilityMatchesBlackScholes() {
		let euro = Tree.price(optionType: .call, americanStyle: false, spotPrice: 100,
							  strikePrice: Self.strike, timeToExpiry: 1.0,
							  riskFreeRate: Self.rate, volatility: 0.0, steps: 100)
		#expect(euro.isEqual(to: 4.877057549928594), "the tree converges to the same forward")
		#expect(euro.isEqual(to: Self.price(.call, t: 1.0, vol: 0.0, spot: 100)),
				"and agrees with the closed form exactly")
	}

	/// The one place the two models part company. Exercising a put at time `t` is worth
	/// `K * exp(-rt) - S`, largest at `t = 0`, so an American put on a non-volatile asset is
	/// worth exercising immediately. Both used to be NaN.
	@Test("Tree_ZeroVolatility_AmericanPutBeatsEuropean") func treeAmericanPutBeatsEuropean() {
		let euro = Tree.price(optionType: .put, americanStyle: false, spotPrice: 90,
							  strikePrice: Self.strike, timeToExpiry: 1.0,
							  riskFreeRate: Self.rate, volatility: 0.0, steps: 100)
		let american = Tree.price(optionType: .put, americanStyle: true, spotPrice: 90,
								  strikePrice: Self.strike, timeToExpiry: 1.0,
								  riskFreeRate: Self.rate, volatility: 0.0, steps: 100)
		#expect(euro.isEqual(to: 5.122942450071406), "100 * exp(-0.05) - 90")
		#expect(american.isEqual(to: 10.0), "exercise now: 100 - 90")
		#expect(american > euro, "early exercise is worth something here")
	}

	@Test("Tree_AtExpiry_IsIntrinsic") func treeAtExpiryIsIntrinsic() {
		let v = Tree.price(optionType: .call, americanStyle: false, spotPrice: 120,
						   strikePrice: Self.strike, timeToExpiry: 0.0,
						   riskFreeRate: Self.rate, volatility: 0.2, steps: 100)
		#expect(v.isEqual(to: 20.0), "previously NaN")
	}

	/// A tree with no steps has no nodes to induct over. It used to return 0.0 — a call worth
	/// 10.43 reported as worthless, with nothing to distinguish it from a genuinely worthless
	/// option. There is no limit to compute: a zero-step tree is not a model.
	@Test("Tree_ZeroSteps_Traps", .requiresUnsanitizedRuntime)
	func treeZeroStepsTraps() async {
		await #expect(processExitsWith: .failure) {
			_ = BinomialTreeModel<Double>.price(
				optionType: .call, americanStyle: false, spotPrice: 100, strikePrice: 100,
				timeToExpiry: 1.0, riskFreeRate: 0.05, volatility: 0.2, steps: 0
			)
		}
		await #expect(processExitsWith: .failure) {
			_ = BinomialTreeModel<Double>.price(
				optionType: .call, americanStyle: false, spotPrice: 100, strikePrice: 100,
				timeToExpiry: 1.0, riskFreeRate: 0.05, volatility: 0.2, steps: -5
			)
		}
	}
}
