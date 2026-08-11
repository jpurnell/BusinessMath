//
//  t Distribution Functions.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import Testing
import Numerics
import TestSupport
@testable import BusinessMath

@Suite("t Distribution Tests")
struct TDistributionTests {

	@Test("tStatistic computes (x - mean) / stdErr")
	func tStatistic_basic() throws {
		let x = 5.0
		let mean = 3.0
		let stdErr = 1.0
		let tStat = tStatistic(x: x, mean: mean, stdErr: stdErr)
		#expect(abs(tStat - 2.0) < 1e-6)
	}

	@Test("tStatistic with default parameters")
	func tStatistic_default() throws {
		let tStatDefault = tStatistic(x: 1.0)
		#expect(abs(tStatDefault - 1.0) < 1e-6) // (1 - 0) / 1
	}

	// These three pinned real properties of the t density and were only ever named
	// after a p-value, so they moved to `studentTPDF` rather than being deleted with
	// `pValueStudent`. Note the density is bounded above by its own peak, not by 1 —
	// "within (0,1)" was true here by accident of ν, not by definition.

	@Test("studentTPDF is a positive density bounded by its peak")
	func density_bounds() throws {
		let value: Double = try studentTPDF(t: 2.0, df: 10)
		let peak: Double = try studentTPDF(t: 0.0, df: 10)
		#expect(value > 0.0)
		#expect(value < peak)
	}

	@Test("studentTPDF at t=0 is higher than at t=2 (density peaks at centre)")
	func density_center_higher() throws {
		let atZero: Double = try studentTPDF(t: 0.0, df: 10)
		let atTwo: Double = try studentTPDF(t: 2.0, df: 10)
		#expect(atZero > atTwo)
	}

	@Test("studentTPDF with large df approaches the standard normal density")
	func density_large_df() throws {
		// As ν → ∞ the t density tends to the standard normal, which is the property
		// worth asserting at df = 100 — the old test only checked the value was
		// inside (0,1), which every df satisfies and so tested nothing about df.
		let atTwo: Double = try studentTPDF(t: 2.0, df: 100)
		let normalAtTwo = Double.exp(-2.0) / Double.sqrt(2.0 * Double.pi)
		#expect(atTwo > 0.0)
		#expect(approximatelyEqual(atTwo, normalAtTwo, tolerance: 2e-3))
	}
}
