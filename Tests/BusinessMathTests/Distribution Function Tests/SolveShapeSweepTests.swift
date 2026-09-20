//
//  SolveShapeSweepTests.swift
//  BusinessMath
//
//  A sweep for `DistributionMomentFit.solveShape`, which was checked at eight points.
//
//  `MomentFitTests` is not the weak kind of coverage: it computes the fitted distribution's
//  moments by its own Simpson quadrature and compares those against what was asked for, so
//  it checks an answer rather than the solver's own residual. What it cannot do is cover a
//  *region*. It carries eight hand-written moment sets, the largest of which is `|skewness|`
//  1.2 and kurtosis 6.
//
//  The solver those eight points exercise tries **thirty-five starting positions** — seven
//  for `gamma` crossed with five for `delta` — and its own comment says why:
//
//      Several starting points rather than one clever one. The residual surface is smooth
//      but not globally convex, and a fixed start fails on perfectly ordinary moment sets.
//
//  A multi-start strategy is a claim about a region: *somewhere* in these thirty-five is a
//  basin for every moment set a caller can ask about. Eight points cannot test that claim,
//  and no number of hand-written points can, because the sets that break it are the ones
//  nobody would think to type.
//
//  ## How the moment sets are generated
//
//  Backwards. Rather than inventing `(skewness, kurtosis)` pairs and hoping they are
//  attainable, this picks `(gamma, delta)` on a grid, asks `standardisedMoments` what
//  moments that member *has*, and then requires `solveShape` to find its way back. Every
//  target is reachable by construction, so a failure is the solver failing to find a
//  solution that certainly exists — never a caller asking for the impossible.
//
//  The lognormal member is checked differently, against its closed form: for shape `omega`,
//  `beta1 = (omega + 2)^2 (omega - 1)` and `delta = 1 / sqrt(ln omega)`. Both are written out
//  here rather than taken from the source, so that branch — a bisection, not the Newton
//  solve — has an oracle that shares nothing with it.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("solveShape across the region, not at eight points")
struct SolveShapeSweepTests {

	// MARK: - The grids

	private static let unboundedGammas: [Double] = [-2, -1, -0.5, 0, 0.5, 1, 2]
	private static let unboundedDeltas: [Double] = [0.8, 1.2, 2.0, 3.0]

	private static let boundedGammas: [Double] = [-1.5, -0.5, 0, 0.5, 1.5]
	private static let boundedDeltas: [Double] = [0.7, 1.0, 1.5, 2.5]

	/// Measured, not chosen.
	///
	/// `solveShape` stops when both residuals are below 1e-10, and the bounded member's
	/// moments come from Simpson quadrature, which adds a little on top. Measured worst
	/// round-trip across the whole sweep:
	///
	/// | member | skewness | kurtosis |
	/// |---|---|---|
	/// | unbounded | 1.66e-12 | 1.30e-11 |
	/// | bounded | 4.67e-11 | 6.27e-11 |
	///
	/// The bound is 1e-6, about four orders above the worst of those and far below any
	/// failure it has to catch — a solve that lands in the wrong basin misses by a whole
	/// number, not by a rounding.
	private static let bound = 1e-6

	private struct Point {
		let family: JohnsonFamily
		let gamma: Double
		let delta: Double
		let skewness: Double
		let kurtosis: Double
	}

	/// Every grid position whose moments are finite, with the moments they have.
	private static func reachablePoints(
		family: JohnsonFamily, gammas: [Double], deltas: [Double]
	) -> [Point] {
		var out: [Point] = []
		for gamma in gammas {
			for delta in deltas {
				let moments = DistributionMomentFit.standardisedMoments(
					family: family, gamma: gamma, delta: delta)
				guard moments.skewness.isFinite, moments.kurtosis.isFinite else { continue }
				guard moments.variance > 0 else { continue }
				out.append(Point(family: family, gamma: gamma, delta: delta,
								 skewness: moments.skewness, kurtosis: moments.kurtosis))
			}
		}
		return out
	}

	// MARK: - The sweep

	@Test("Every unbounded member is found again from its own moments")
	func unboundedMembersAreRecovered() throws {
		let points = Self.reachablePoints(family: .unbounded,
										  gammas: Self.unboundedGammas,
										  deltas: Self.unboundedDeltas)
		#expect(points.count >= 20, "only \(points.count) unbounded grid points were usable")
		try Self.assertRoundTrips(points)
	}

	@Test("Every bounded member is found again from its own moments")
	func boundedMembersAreRecovered() throws {
		let points = Self.reachablePoints(family: .bounded,
										  gammas: Self.boundedGammas,
										  deltas: Self.boundedDeltas)
		#expect(points.count >= 15, "only \(points.count) bounded grid points were usable")
		try Self.assertRoundTrips(points)
	}

	/// Solve each point's moments and require the answer to have those moments.
	private static func assertRoundTrips(_ points: [Point]) throws {
		var worstSkew = 0.0
		var worstKurt = 0.0

		for point in points {
			let label = "\(point.family) gamma \(point.gamma) delta \(point.delta)"

			let solved = try solveOrRecord(point, label: label)
			guard let solved else { continue }

			let back = DistributionMomentFit.standardisedMoments(
				family: point.family, gamma: solved.gamma, delta: solved.delta)

			let skewGap: Double = abs(back.skewness - point.skewness)
			let kurtGap: Double = abs(back.kurtosis - point.kurtosis)
			if skewGap > worstSkew { worstSkew = skewGap }
			if kurtGap > worstKurt { worstKurt = kurtGap }

			#expect(skewGap < bound,
					"\(label): solved to skewness \(back.skewness), asked for \(point.skewness)")
			#expect(kurtGap < bound,
					"\(label): solved to kurtosis \(back.kurtosis), asked for \(point.kurtosis)")
			#expect(solved.delta > 0, "\(label): delta came back \(solved.delta)")
		}

		#expect(worstSkew < bound, "worst skewness round-trip was \(worstSkew)")
		#expect(worstKurt < bound, "worst kurtosis round-trip was \(worstKurt)")
	}

	/// Solves, turning a throw into a named failure rather than an aborted sweep.
	private static func solveOrRecord(
		_ point: Point, label: String
	) throws -> (gamma: Double, delta: Double)? {
		do {
			return try DistributionMomentFit.solveShape(
				family: point.family, skewness: point.skewness, kurtosis: point.kurtosis)
		} catch {
			// The point came *from* this family, so a solution exists by construction and
			// this is the multi-start strategy failing to find it.
			Issue.record("""
				\(label) did not converge, on moments generated from that member itself: \
				skewness \(point.skewness), kurtosis \(point.kurtosis). Error: \(error)
				""")
			return nil
		}
	}

	// MARK: - The lognormal branch, against its closed form

	@Test("The lognormal shape matches the closed form, not just itself")
	func lognormalMatchesClosedForm() throws {
		// beta1 = (omega + 2)^2 (omega - 1) and delta = 1 / sqrt(ln omega), both written out
		// here rather than taken from the source. That branch is a bisection, not the Newton
		// solve, and shares no code with the sweep above.
		let omegas: [Double] = [1.05, 1.2, 1.5, 2.0, 3.0]
		for omega in omegas {
			let offset: Double = omega + 2
			let beta1: Double = offset * offset * (omega - 1)
			let skewness: Double = beta1.squareRoot()

			let solved = try DistributionMomentFit.solveShape(
				family: .lognormal, skewness: skewness, kurtosis: 0)

			let expectedDelta: Double = 1 / Foundation.log(omega).squareRoot()
			let gap: Double = abs(solved.delta - expectedDelta)
			let scale: Double = Swift.max(1.0, abs(expectedDelta))
			let relative: Double = gap / scale
			#expect(relative < 1e-8,
					"omega \(omega): delta \(solved.delta), closed form \(expectedDelta)")
			#expect(solved.gamma == 0, "omega \(omega): gamma \(solved.gamma), expected 0")
		}
	}

	// MARK: - Guards on the sweep itself

	@Test("The grids reach further than the eight fixtures do")
	func gridsExceedTheExistingFixtures() throws {
		// `MomentFitTests` tops out at |skewness| 1.2 and kurtosis 6. A sweep that stayed
		// inside that would add nothing, and would still pass.
		// Every binding annotated and every intermediate bound: CI runs Swift 6.2.1 and
		// this suite's sibling in `GStudyTwoFacetOracleTests` shipped with untyped nested
		// expressions that build instantly on the local 6.4 and time out the 6.2.1 solver.
		let unbounded: [Point] = Self.reachablePoints(family: .unbounded,
													  gammas: Self.unboundedGammas,
													  deltas: Self.unboundedDeltas)
		let bounded: [Point] = Self.reachablePoints(family: .bounded,
													gammas: Self.boundedGammas,
													deltas: Self.boundedDeltas)
		let all: [Point] = unbounded + bounded

		let skewMagnitudes: [Double] = all.map { abs($0.skewness) }
		let kurtoses: [Double] = all.map { $0.kurtosis }
		let maxSkew: Double = skewMagnitudes.max() ?? 0
		let maxKurt: Double = kurtoses.max() ?? 0
		let minKurt: Double = kurtoses.min() ?? 0

		#expect(maxSkew > 1.2, "the sweep's largest |skewness| is \(maxSkew)")
		#expect(maxKurt > 6.0, "the sweep's largest kurtosis is \(maxKurt)")
		#expect(minKurt < 2.2, "the sweep's smallest kurtosis is \(minKurt)")
		#expect(all.count >= 35, "only \(all.count) points in the sweep")
	}
}
