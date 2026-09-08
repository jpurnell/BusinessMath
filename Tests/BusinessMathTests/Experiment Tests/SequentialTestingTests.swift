//
//  SequentialTestingTests.swift
//  BusinessMath
//
//  Group-sequential boundaries and alpha spending.
//
//  ## The fact this file exists for
//
//  Checking an A/B test five times at the nominal 1.96 and stopping at the first
//  significant look does not give a 5% false-positive rate. It gives **14.2%**. Nothing
//  about the practice looks wrong from inside it — each individual test is correctly
//  computed, the p-value is a real p-value, and the experimenter is doing arithmetic
//  they can check. The error is in the stopping rule, which no single test can see.
//
//  `uncorrectedPeeking` pins that number, because it is the argument for the whole file.
//
//  ## The oracle is published boundaries
//
//  Pocock's constant 2.413 and O'Brien–Fleming's 4.562 / 3.226 / 2.634 / 2.281 / 2.040
//  for five equally spaced looks at two-sided 0.05 are tabulated in the literature and
//  were not computed here. Feeding them to `typeOneErrorRate` must return 0.05, which
//  checks the recursion against numbers derived independently of it — and then solving
//  the other way must return the boundaries, which checks the solver against the
//  recursion.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Sequential testing")
struct SequentialTestingTests {

	private static let fiveLooks: [Double] = [0.2, 0.4, 0.6, 0.8, 1.0]

	// MARK: - The motivating fact

	@Test("Peeking five times at the nominal cutoff nearly triples the error rate")
	func uncorrectedPeeking() throws {
		let naive = [Double](repeating: 1.959963985, count: 5)
		let rate = try #require(sequentialTypeOneError(boundaries: naive,
													   informationTimes: Self.fiveLooks))
		#expect(Swift.abs(rate - 0.1417) < 0.002, "peeking rate \(rate), expected about 0.1417")
		#expect(rate > 0.13, "the whole point is that this is far above 0.05, got \(rate)")

		// And a single look at the same cutoff is exactly the nominal rate, which is what
		// makes the comparison fair: nothing about the cutoff changed, only the stopping
		// rule around it.
		let once = try #require(sequentialTypeOneError(boundaries: [1.959963985],
													   informationTimes: [1.0]))
		#expect(Swift.abs(once - 0.05) < 1e-4, "one look gives \(once)")
	}

	// MARK: - Against published boundaries

	@Test("Published Pocock boundaries spend exactly the alpha they claim")
	func pocockBoundariesAreExact() throws {
		let pocock = [Double](repeating: 2.413, count: 5)
		let rate = try #require(sequentialTypeOneError(boundaries: pocock,
													   informationTimes: Self.fiveLooks))
		#expect(Swift.abs(rate - 0.05) < 1e-3, "Pocock spends \(rate)")
	}

	@Test("Published O'Brien-Fleming boundaries spend exactly the alpha they claim")
	func obrienFlemingBoundariesAreExact() throws {
		let boundaries: [Double] = [4.562, 3.226, 2.634, 2.281, 2.040]
		let rate = try #require(sequentialTypeOneError(boundaries: boundaries,
													   informationTimes: Self.fiveLooks))
		#expect(Swift.abs(rate - 0.05) < 1e-3, "O'Brien-Fleming spends \(rate)")
	}

	// MARK: - Solving the other way

	@Test("A Pocock design recovers boundaries clustered on the published 2.413")
	func pocockDesign() throws {
		// Classical Pocock has a genuinely constant boundary by construction. The
		// Lan–DeMets spending-function analogue used here only approximates it: it
		// reproduces the same total alpha, but distributes it slightly differently, so
		// the boundaries drift downward across the looks instead of repeating exactly.
		//
		// Measured at five equally spaced looks: 2.438, 2.427, 2.410, 2.397, 2.386 —
		// a spread of 0.052, centred on 2.412 against the published 2.413. That is the
		// method behaving correctly, and asserting an exactly constant boundary would be
		// asserting a property this design does not have.
		let design = try #require(GroupSequentialDesign(looks: 5, alpha: 0.05,
														spending: .pocock))
		#expect(design.boundaries.count == 5)
		for boundary in design.boundaries {
			#expect(Swift.abs(boundary - 2.413) < 0.04,
					"expected the cluster around 2.413, got \(design.boundaries)")
		}
		let highest = try #require(design.boundaries.max())
		let lowest = try #require(design.boundaries.min())
		let spread: Double = highest - lowest
		#expect(spread < 0.08, "the boundaries should stay tight, spread was \(spread)")
		// Tight, but not flat — and the drift is downward, as the spending function
		// releases proportionally more of what is left at each later look.
		#expect(spread > 0.01, "an exactly flat result would mean the wrong design")
		let first = try #require(design.boundaries.first)
		let last = try #require(design.boundaries.last)
		#expect(first > last, "Pocock-like boundaries drift down, got \(design.boundaries)")
	}

	@Test("An O'Brien-Fleming design starts conservative and relaxes")
	func obrienFlemingDesign() throws {
		let design = try #require(GroupSequentialDesign(looks: 5, alpha: 0.05,
														spending: .obrienFleming))
		let boundaries = design.boundaries
		#expect(boundaries.count == 5)
		// Strictly decreasing: hard to stop early, close to nominal at the end. That
		// shape is the reason the design is popular — an early stop means something.
		for index in 1..<boundaries.count {
			#expect(boundaries[index] < boundaries[index - 1],
					"boundary rose at look \(index): \(boundaries)")
		}
		let first = try #require(boundaries.first)
		let last = try #require(boundaries.last)
		#expect(first > 4, "the first look should be very conservative, got \(first)")
		#expect(last < 2.2 && last > 1.9, "the last should be near nominal, got \(last)")
	}

	@Test("Any design spends the alpha it was given")
	func designsSpendTheirAlpha() throws {
		var checked = 0
		for spending in [AlphaSpendingFunction.pocock, .obrienFleming, .linear] {
			for looks in [2, 3, 5] {
				for alpha in [0.05, 0.01] {
					let design = try #require(GroupSequentialDesign(looks: looks, alpha: alpha,
																	spending: spending))
					let spent = try #require(sequentialTypeOneError(
						boundaries: design.boundaries,
						informationTimes: design.informationTimes))
					#expect(Swift.abs(spent - alpha) < alpha * 0.05,
							"\(spending) at \(looks) looks spent \(spent), wanted \(alpha)")
					checked += 1
				}
			}
		}
		#expect(checked == 18, "only \(checked) of 18 designs were checked")
	}

	@Test("A single look is the ordinary fixed-sample test")
	func singleLookIsOrdinary() throws {
		let design = try #require(GroupSequentialDesign(looks: 1, alpha: 0.05,
														spending: .obrienFleming))
		let only = try #require(design.boundaries.first)
		#expect(Swift.abs(only - 1.959963985) < 1e-3,
				"one look should be the ordinary 1.96, got \(only)")
	}

	// MARK: - The spending functions themselves

	@Test("A spending function starts at nothing and ends at everything")
	func spendingFunctionEndpoints() {
		var checked = 0
		for spending in [AlphaSpendingFunction.pocock, .obrienFleming, .linear] {
			let atStart: Double = spending.spent(by: 0, alpha: 0.05)
			let atEnd: Double = spending.spent(by: 1, alpha: 0.05)
			#expect(Swift.abs(atStart) < 1e-12, "\(spending) spends \(atStart) at t = 0")
			#expect(Swift.abs(atEnd - 0.05) < 1e-9, "\(spending) spends \(atEnd) at t = 1")
			checked += 1
		}
		#expect(checked == 3, "only \(checked) spending functions were checked")
	}

	@Test("Spending is monotone: alpha already spent cannot be recovered")
	func spendingIsMonotone() {
		var checked = 0
		for spending in [AlphaSpendingFunction.pocock, .obrienFleming, .linear] {
			var previous: Double = -1
			for step in 0...20 {
				let t: Double = Double(step) / 20
				let spent: Double = spending.spent(by: t, alpha: 0.05)
				#expect(spent >= previous, "\(spending) fell at t=\(t): \(spent) after \(previous)")
				previous = spent
			}
			checked += 1
		}
		#expect(checked == 3)
	}

	@Test("O'Brien-Fleming spends almost nothing early and Pocock spends steadily")
	func spendingShapes() {
		// At the first of five looks: O'Brien-Fleming has spent well under a tenth of the
		// budget, Pocock a good deal more. That difference is the entire design choice.
		let early: Double = 0.2
		let obf: Double = AlphaSpendingFunction.obrienFleming.spent(by: early, alpha: 0.05)
		let poc: Double = AlphaSpendingFunction.pocock.spent(by: early, alpha: 0.05)
		#expect(obf < 0.005, "O'Brien-Fleming spent \(obf) by t = 0.2")
		#expect(poc > obf * 3, "Pocock should spend far more early: \(poc) against \(obf)")
		#expect(poc < 0.05, "and still not all of it: \(poc)")
	}

	// MARK: - Refusals

	@Test("Designs and error rates refuse what they cannot compute")
	func refusals() {
		#expect(GroupSequentialDesign<Double>(looks: 0, alpha: 0.05, spending: .pocock) == nil)
		#expect(GroupSequentialDesign<Double>(looks: 3, alpha: 0, spending: .pocock) == nil)
		#expect(GroupSequentialDesign<Double>(looks: 3, alpha: 1, spending: .pocock) == nil)
		// Information times must increase and end at one.
		#expect(sequentialTypeOneError(boundaries: [2.0, 2.0],
									   informationTimes: [0.5, 0.4]) == nil)
		#expect(sequentialTypeOneError(boundaries: [2.0], informationTimes: [0.5, 1.0]) == nil)
		let noBoundaries: [Double] = []
		#expect(sequentialTypeOneError(boundaries: noBoundaries, informationTimes: noBoundaries) == nil)
		#expect(sequentialTypeOneError(boundaries: [-1.0], informationTimes: [1.0]) == nil)
	}
}
