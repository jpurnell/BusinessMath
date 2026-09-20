//
//  DiscountCurveBootstrapOracleTests.swift
//  BusinessMath
//
//  An exact oracle for `DiscountCurve.bootstrap(parRates:asOfDate:)`.
//
//  `DiscountCurveTests` already reprices: for each input par rate it checks that
//  `c * SUM DF(i) + DF(N) - 1` is zero off the bootstrapped curve, through
//  `discountFactor(at:)` rather than the raw map, so the interpolation is exercised too.
//  That is a real assertion and it is not the weak kind. But it checks a **residual** — the
//  very equation the solver drives to zero — rather than an independently known answer, and
//  every case it runs starts at tenor 1.
//
//  ## What this adds
//
//  **An answer rather than a residual.** The curve is chosen first, the par rates are derived
//  from it in closed form, and the bootstrap has to give the curve back. For a par swap at
//  tenor `N` with an annual fixed leg,
//
//      c_N = (1 - DF(N)) / SUM_{i=1..N} DF(i)
//
//  is the exact inverse of the par condition, so a correct bootstrap recovers every discount
//  factor, at the node years *and in the gaps*, to rounding.
//
//  The constructed curve is piecewise log-linear in `DF` — equivalently, piecewise constant
//  in the forward rate — because that is the model the bootstrap itself interpolates with.
//  Recovery is therefore exact by construction rather than approximate: any other curve shape
//  would make the gaps disagree for a reason that is the fixture's fault, not the code's.
//
//  **Shapes the existing tests never take.** Every repricing case above starts at tenor 1.
//  These start at 2, at 5, and at 10, which is the path where the algorithm has no previous
//  node and has to anchor on `DF(0) = 1` while filling a gap. That branch — `lastKnownYear`
//  of zero, a non-empty gap loop below the first quoted tenor — is reached by nothing in the
//  suite today.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Bootstrap against a curve it should give back")
struct DiscountCurveBootstrapOracleTests {

	private static let asOf = Date(timeIntervalSince1970: 1_700_000_000)

	// MARK: - Building a curve the bootstrap's own model can represent

	/// A curve defined by constant forward rates between the quoted tenors.
	///
	/// `ln DF` is then linear on every segment, including the first one from `t = 0`, which
	/// is exactly the shape `bootstrap` interpolates gaps with. Anything else would put the
	/// fixture and the algorithm at odds over the gaps for reasons that say nothing about
	/// whether the algorithm is right.
	private struct Ladder {
		let name: String
		/// The tenors a par rate is quoted at.
		let nodes: [Int]
		/// The constant forward rate applying up to each node from the one before it.
		let forwards: [Double]

		/// `DF` at every integer year from 1 to the last node.
		var discountFactors: [Int: Double] {
			var out = [Int: Double]()
			var lnDF = 0.0
			var previous = 0
			for (index, node) in nodes.enumerated() {
				let f = forwards[index]
				for year in (previous + 1)...node {
					lnDF -= f
					out[year] = exp(lnDF)
				}
				previous = node
			}
			return out
		}

		/// The par swap rate at each node, from the curve rather than from a solver.
		var parRates: [(tenor: Double, rate: Double)] {
			let dfs = discountFactors
			var out = [(tenor: Double, rate: Double)]()
			for node in nodes {
				var annuity = 0.0
				for year in 1...node { annuity += dfs[year] ?? 0 }
				guard annuity > 0 else { continue }
				let terminal = dfs[node] ?? 0
				let rate = (1.0 - terminal) / annuity
				out.append((tenor: Double(node), rate: rate))
			}
			return out
		}
	}

	private static let ladders: [Ladder] = [
		// Consecutive tenors, rising forwards.
		Ladder(name: "consecutive 1-5",
			   nodes: [1, 2, 3, 4, 5],
			   forwards: [0.02, 0.025, 0.03, 0.035, 0.04]),
		// The shape the existing repricing test uses, so the two agree where they overlap.
		Ladder(name: "gapped 1,2,3,5",
			   nodes: [1, 2, 3, 5],
			   forwards: [0.04, 0.05, 0.055, 0.06]),
		// Flat forwards: every gap DF is pinned by a single rate.
		Ladder(name: "flat forwards",
			   nodes: [1, 2, 3, 5, 7, 10],
			   forwards: [0.05, 0.05, 0.05, 0.05, 0.05, 0.05]),
		// Falling forwards, so the curve is not monotone in slope.
		Ladder(name: "inverted",
			   nodes: [1, 2, 3, 5, 7],
			   forwards: [0.06, 0.055, 0.05, 0.04, 0.03]),
		// No par rate at year 1: the first segment is a gap anchored on DF(0) = 1.
		Ladder(name: "starts at 2",
			   nodes: [2, 3, 5],
			   forwards: [0.03, 0.035, 0.04]),
		// A long first gap, which is the same branch stretched.
		Ladder(name: "starts at 5",
			   nodes: [5, 10],
			   forwards: [0.045, 0.05]),
		// Nothing quoted until year 10.
		Ladder(name: "starts at 10",
			   nodes: [10],
			   forwards: [0.035])
	]

	// MARK: - Comparison

	/// Measured, not chosen.
	///
	/// The bootstrap solves each node with Newton, stopping at a step below 1e-15, so its
	/// discount factors cannot be bit-equal to the constructed ones. Measured worst relative
	/// gap across the seven ladders and every integer year: **1.58e-16**, which is about one
	/// ulp — the solver converges to the constructed curve as closely as the representation
	/// allows.
	///
	/// The bound is 1e-11, five orders above that, and still far below any structural error
	/// it has to catch — the smallest being a gap DF anchored on the wrong neighbour, which
	/// moves a factor by a part in a thousand at these rates.
	static let bound = 1e-11

	private static func recover(_ ladder: Ladder) -> DiscountCurve {
		DiscountCurve.bootstrap(parRates: ladder.parRates, asOfDate: asOf)
	}

	// MARK: - The tests

	@Test("Every discount factor comes back, at the nodes and in the gaps")
	func discountFactorsAreRecovered() throws {
		var worst = 0.0
		var compared = 0

		for ladder in Self.ladders {
			let wanted = ladder.discountFactors
			let curve = Self.recover(ladder)
			for (year, df) in wanted.sorted(by: { $0.key < $1.key }) {
				let got = curve.discountFactor(at: Double(year))
				let gap = abs(got - df) / Swift.max(abs(df), 1e-300)
				if gap > worst { worst = gap }
				#expect(gap < Self.bound,
						"\(ladder.name) year \(year): DF \(got), constructed \(df)")
				compared += 1
			}
		}
		#expect(compared >= 40, "only \(compared) discount factors compared")
		#expect(worst < Self.bound, "worst relative gap was \(worst)")
	}

	@Test("The gaps are recovered, not just the quoted tenors")
	func gapYearsAreRecovered() throws {
		// Separated out because the node years are where the solver puts its residual to
		// zero; the gap years are where it has only its interpolation model to go on, and a
		// curve can satisfy every par condition while getting them wrong.
		var gapsChecked = 0
		for ladder in Self.ladders {
			let quoted = Set(ladder.nodes)
			let wanted = ladder.discountFactors
			let curve = Self.recover(ladder)
			for (year, df) in wanted where !quoted.contains(year) {
				let got = curve.discountFactor(at: Double(year))
				let gap = abs(got - df) / Swift.max(abs(df), 1e-300)
				#expect(gap < Self.bound,
						"\(ladder.name) gap year \(year): DF \(got), constructed \(df)")
				gapsChecked += 1
			}
		}
		#expect(gapsChecked >= 15,
				"only \(gapsChecked) gap years checked; the ladders no longer have gaps")
	}

	@Test("A curve quoted only from year 2 out still anchors on DF(0) = 1")
	func firstSegmentIsAGapAnchoredAtZero() throws {
		// The branch nothing else in the suite reaches. With no par rate at year 1 the
		// algorithm has no previous node, so it has to treat `DF(0) = 1` as the left anchor
		// and fill years 1..N-1 against it. If it instead skipped those years, or defaulted
		// them to 1.0, the annuity would be too large and every factor after it too small.
		for name in ["starts at 2", "starts at 5", "starts at 10"] {
			guard let ladder = Self.ladders.first(where: { $0.name == name }) else {
				Issue.record("ladder '\(name)' is missing"); continue
			}
			let curve = Self.recover(ladder)
			let wanted = ladder.discountFactors

			// Year 1 is never quoted in these ladders, and is the one a default of 1.0
			// would corrupt most visibly.
			let firstYear = try #require(wanted[1], "\(name): no constructed DF at year 1")
			let got = curve.discountFactor(at: 1.0)
			#expect(abs(got - firstYear) / firstYear < Self.bound,
					"\(name) year 1: DF \(got), constructed \(firstYear)")
			#expect(got < 1.0, "\(name): DF(1) = \(got) is not a discount factor")
		}
	}

	@Test("The ladders actually contain the gaps and anchors they claim")
	func laddersExerciseWhatTheyClaim() throws {
		// The fixture's own guard. A ladder list quietly edited into all-consecutive nodes
		// would leave the two tests above asserting nothing about interpolation, and they
		// would still pass.
		let withGaps = Self.ladders.filter { ladder in
			guard let last = ladder.nodes.last else { return false }
			return ladder.nodes.count < last
		}
		#expect(withGaps.count >= 4, "only \(withGaps.count) ladders have gap years")

		let notStartingAtOne = Self.ladders.filter { $0.nodes.first != 1 }
		#expect(notStartingAtOne.count >= 3,
				"only \(notStartingAtOne.count) ladders skip year 1")

		// And every constructed curve must be a curve: strictly decreasing, all positive.
		for ladder in Self.ladders {
			let dfs = ladder.discountFactors
			let years = dfs.keys.sorted()
			var previous = 1.0
			for year in years {
				let df = try #require(dfs[year])
				#expect(df > 0, "\(ladder.name) year \(year): DF \(df) is not positive")
				#expect(df < previous,
						"\(ladder.name) year \(year): DF \(df) is not below \(previous)")
				previous = df
			}
		}
	}

	@Test("Par rates derived from the curve reprice on it")
	func derivedParRatesArePar() throws {
		// Cross-checks the oracle itself: if the par-rate formula here were wrong, the
		// recovery tests would be comparing the bootstrap against the wrong target and could
		// fail for a reason that is this file's fault. This asserts the derived rates really
		// are par on the constructed curve, using the constructed factors only.
		for ladder in Self.ladders {
			let dfs = ladder.discountFactors
			for entry in ladder.parRates {
				let n = Int(entry.tenor)
				var annuity = 0.0
				for year in 1...n { annuity += dfs[year] ?? 0 }
				let terminal = dfs[n] ?? 0
				let npv: Double = entry.rate * annuity + terminal - 1.0
				#expect(abs(npv) < 1e-14,
						"\(ladder.name) tenor \(n): derived rate is not par, NPV \(npv)")
			}
		}
	}
}
