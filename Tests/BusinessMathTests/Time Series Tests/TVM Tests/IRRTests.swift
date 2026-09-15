//
//  IRRTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import TestSupport  // Cross-platform math functions
import Foundation
@testable import BusinessMath

@Suite("IRR Tests")
struct IRRTests {

	let tolerance: Double = 0.0001  // 0.01% tolerance for rate calculations

	// MARK: - Basic IRR Tests

	@Test("IRR for simple investment: -100, +110")
	func irrSimple() throws {
		let cashFlows = [-100.0, 110.0]
		let irr = try irr(cashFlows: cashFlows)

		// 10% return
		#expect(abs(irr - 0.10) < tolerance)
	}

	@Test("IRR for 3-year investment: -1000, +400, +400, +400")
	func irr3Year() throws {
		let cashFlows = [-1000.0, 400.0, 400.0, 400.0]
		let irr = try irr(cashFlows: cashFlows)

		// IRR ≈ 9.7% (known value)
		// The review's verified value, not the four-digit rounding of it. IRR is the root
		// of a polynomial: there is exactly one answer here and it is worth stating.
		#expect(abs(irr - 0.097010257403) < 1e-9, "IRR was \(irr)")
	}

	@Test("IRR for project with uneven cash flows")
	func irrUneven() throws {
		let cashFlows = [-5000.0, 1000.0, 2000.0, 3000.0, 1000.0]
		let irr = try irr(cashFlows: cashFlows)

		// IRR ≈ 14.3% (adjusted tolerance for iterative method)
		#expect(abs(irr - 0.143061180358) < 1e-9, "IRR was \(irr)")
	}

	@Test("IRR with negative ending cash flow")
	func irrNegativeEnding() throws {
		// Investment with cleanup cost at end
		let cashFlows = [-1000.0, 500.0, 500.0, 500.0, -200.0]
		let irr = try irr(cashFlows: cashFlows)

		// Should still converge to a valid IRR
		#expect(!irr.isNaN)
		#expect(!irr.isInfinite)
	}

	@Test("IRR for break-even investment (IRR = 0)")
	func irrBreakEven() throws {
		// Cash flows that sum to exactly 0 for true break-even
		let cashFlows = [-1000.0, 250.0, 250.0, 250.0, 250.0]
		let irr = try irr(cashFlows: cashFlows)

		// IRR = 0% (break even)
		#expect(abs(irr - 0.0) < tolerance)
	}

	// MARK: - IRR with Custom Parameters

	@Test("IRR with custom guess")
	func irrCustomGuess() throws {
		let cashFlows = [-1000.0, 400.0, 400.0, 400.0]

		// Try with different initial guesses
		let irr1 = try irr(cashFlows: cashFlows, guess: 0.05)
		let irr2 = try irr(cashFlows: cashFlows, guess: 0.15)

		// Should converge to same result regardless of guess
		#expect(abs(irr1 - irr2) < tolerance)
	}

	@Test("IRR with custom tolerance")
	func irrCustomTolerance() throws {
		let cashFlows = [-1000.0, 400.0, 400.0, 400.0]
		let irr = try irr(cashFlows: cashFlows, tolerance: 0.00001)

		// Should still converge
		// The review's verified value, not the four-digit rounding of it. IRR is the root
		// of a polynomial: there is exactly one answer here and it is worth stating.
		#expect(abs(irr - 0.097010257403) < 1e-9, "IRR was \(irr)")
	}

	@Test("IRR with custom max iterations")
	func irrCustomIterations() throws {
		let cashFlows = [-1000.0, 400.0, 400.0, 400.0]
		let irr = try irr(cashFlows: cashFlows, maxIterations: 50)

		// Should converge within 50 iterations
		// The review's verified value, not the four-digit rounding of it. IRR is the root
		// of a polynomial: there is exactly one answer here and it is worth stating.
		#expect(abs(irr - 0.097010257403) < 1e-9, "IRR was \(irr)")
	}

	// MARK: - MIRR Tests

	@Test("MIRR with same finance and reinvestment rates")
	func mirrSameRates() throws {
		let cashFlows = [-1000.0, 400.0, 400.0, 400.0]
		let mirr = try mirr(cashFlows: cashFlows, financeRate: 0.10, reinvestmentRate: 0.10)

		// When rates are equal, MIRR ≈ IRR
		let irrValue = try irr(cashFlows: cashFlows)
		#expect(abs(mirr - irrValue) < 0.01)
	}

	@Test("MIRR with different rates")
	func mirrDifferentRates() throws {
		let cashFlows = [-1000.0, 400.0, 400.0, 400.0]

		// Finance at 12%, reinvest at 8%
		let mirr = try mirr(cashFlows: cashFlows, financeRate: 0.12, reinvestmentRate: 0.08)

		// MIRR ≈ 7.9% (adjusted tolerance for iterative method)
		#expect(abs(mirr - 0.079) < 0.015)
	}

	@Test("MIRR with multiple negative cash flows")
	func mirrMultipleNegative() throws {
		// Initial investment plus additional capital injection
		let cashFlows = [-1000.0, 500.0, -200.0, 800.0, 500.0]

		let mirr = try mirr(cashFlows: cashFlows, financeRate: 0.10, reinvestmentRate: 0.08)

		// Should handle multiple negative flows
		#expect(!mirr.isNaN)
		#expect(!mirr.isInfinite)
	}

	// MARK: - Error Cases

	@Test("IRR with all positive cash flows should throw")
	func irrAllPositive() throws {
		let cashFlows = [100.0, 200.0, 300.0]

		// No sign change, so there is no root to find and the guard fires before the
		// Newton loop ever runs.
		#expect(throws: BusinessMathError.calculationFailed(
			operation: "IRR",
			reason: "Cash flows must contain both positive and negative values (all cash flows have the same sign)",
			suggestions: [
				"Ensure you have at least one negative cash flow (typically the initial investment)",
				"Verify that you have at least one positive cash flow (returns or receipts)",
				"Check that cash flows are correctly signed (negative for outflows, positive for inflows)"
			])) {
			_ = try irr(cashFlows: cashFlows)
		}
	}

	@Test("IRR with all negative cash flows should throw")
	func irrAllNegative() throws {
		let cashFlows = [-100.0, -200.0, -300.0]

		#expect(throws: BusinessMathError.calculationFailed(
			operation: "IRR",
			reason: "Cash flows must contain both positive and negative values (all cash flows have the same sign)",
			suggestions: [
				"Ensure you have at least one negative cash flow (typically the initial investment)",
				"Verify that you have at least one positive cash flow (returns or receipts)",
				"Check that cash flows are correctly signed (negative for outflows, positive for inflows)"
			])) {
			_ = try irr(cashFlows: cashFlows)
		}
	}

	@Test("IRR with empty cash flows should throw")
	func irrEmpty() throws {
		let cashFlows: [Double] = []

		// Too few flows is a different guard, and it reports both counts.
		#expect(throws: BusinessMathError.insufficientData(
			required: 2, actual: 0,
			context: "IRR calculation requires at least 2 cash flows")) {
			_ = try irr(cashFlows: cashFlows)
		}
	}

	@Test("IRR with single cash flow should throw")
	func irrSingle() throws {
		let cashFlows = [-1000.0]

		#expect(throws: BusinessMathError.insufficientData(
			required: 2, actual: 1,
			context: "IRR calculation requires at least 2 cash flows")) {
			_ = try irr(cashFlows: cashFlows)
		}
	}

	@Test("IRR convergence failure with max iterations = 1")
	func irrConvergenceFailure() throws {
		let cashFlows = [-1000.0, 400.0, 400.0, 400.0]

		// The convergence failure names the budget it exhausted and the guess it started
		// from — the default 0.1, since none was supplied.
		#expect(throws: BusinessMathError.calculationFailed(
			operation: "IRR",
			reason: "Failed to converge within 1 iterations",
			suggestions: [
				"Increase maxIterations (current: 1)",
				"Try a different initial guess (current: 0.1)",
				"Verify that cash flows represent a realistic investment pattern",
				"Check for multiple sign changes, which can give more than one IRR"
			])) {
			_ = try irr(cashFlows: cashFlows, maxIterations: 1)
		}
	}

	@Test("IRR reports a vanishing derivative as numerical instability, not calculation failure")
	func irrVanishingDerivativeIsNumericalInstability() throws {
		// A single distant inflow: at the default guess of 10% the discount factor
		// (1.1)^400 is ~1e16, so dNPV/dr collapses below the 1e-6 floor while NPV is
		// still ~-1. The Newton step is undefined — that is instability, not a
		// calculation that merely failed to finish.
		let cashFlows: [Double] = [-1.0] + Array(repeating: 0.0, count: 399) + [1000.0]

		do {
			_ = try irr(cashFlows: cashFlows)
			Issue.record("Expected irr to throw on a vanishing derivative")
		} catch let error as BusinessMathError {
			guard case .numericalInstability(let message, let suggestions) = error else {
				Issue.record("Expected .numericalInstability, got \(error)")
				return
			}
			#expect(message.contains("Derivative"))
			#expect(!suggestions.isEmpty)
			#expect(error.code == "E004")
		}
	}

	// MARK: - Real-World Scenarios

	@Test("Real estate investment IRR")
	func realEstateScenario() throws {
		// $100k investment, 5 years of rent, then sale
		let cashFlows = [
			-100000.0,  // Purchase
			12000.0,    // Year 1 rent
			12000.0,    // Year 2 rent
			12000.0,    // Year 3 rent
			12000.0,    // Year 4 rent
			130000.0    // Year 5 rent + sale
		]

		let irr = try irr(cashFlows: cashFlows)

		// IRR ≈ 15.2%
		#expect(abs(irr - 0.152) < 0.01)
	}

	@Test("Software project IRR")
	func softwareProjectScenario() throws {
		// $50k development cost, 3 years of revenue
		let cashFlows = [
			-50000.0,   // Development
			20000.0,    // Year 1
			25000.0,    // Year 2
			30000.0     // Year 3
		]

		let irr = try irr(cashFlows: cashFlows)

		// IRR ≈ 21.7% (adjusted for iterative method)
		#expect(abs(irr - 0.216477854184) < 1e-9, "IRR was \(irr)")
	}

	@Test("Manufacturing equipment IRR")
	func manufacturingScenario() throws {
		// $200k equipment, 10 years of savings
		let cashFlows = [-200000.0] + Array(repeating: 30000.0, count: 10)

		let irr = try irr(cashFlows: cashFlows)

		// IRR ≈ 8.1%
		#expect(abs(irr - 0.081441656464) < 1e-9, "IRR was \(irr)")
	}

	@Test("Venture capital investment IRR")
	func ventureCapitalScenario() throws {
		// Multiple rounds of investment, big exit
		let cashFlows = [
			-1000000.0,  // Series A
			-500000.0,   // Series B (additional capital)
			0.0,         // Year 2
			0.0,         // Year 3
			5000000.0    // Exit
		]

		let irr = try irr(cashFlows: cashFlows)

		// Should converge to a positive rate
		#expect(irr > 0.0)
		#expect(irr < 2.0)  // Reasonable upper bound
	}

	// MARK: - IRR vs NPV Relationship

	@Test("At IRR, NPV should be zero")
	func irrNpvRelationship() throws {
		let cashFlows = [-1000.0, 400.0, 400.0, 400.0]
		let irrValue = try irr(cashFlows: cashFlows)

		// Calculate NPV at IRR
		var npv = 0.0
		for (period, cashFlow) in cashFlows.enumerated() {
			npv += cashFlow / pow(1.0 + irrValue, Double(period))
		}

		// NPV at IRR should be very close to zero
		#expect(abs(npv) < 0.01)
	}

	@Test("IRR comparison with different projects")
	func irrComparison() throws {
		// Project A: Quick return
		let projectA = [-1000.0, 600.0, 600.0]

		// Project B: Delayed return
		let projectB = [-1000.0, 200.0, 200.0, 800.0]

		let irrA = try irr(cashFlows: projectA)
		let irrB = try irr(cashFlows: projectB)

		// Project A should have higher IRR (faster return)
		#expect(irrA > irrB)
	}

	// MARK: - Edge Cases

	@Test("IRR with very large cash flows")
	func irrLargeCashFlows() throws {
		let cashFlows = [-1000000000.0, 400000000.0, 400000000.0, 400000000.0]
		let irr = try irr(cashFlows: cashFlows)

		// Should scale properly
		// The review's verified value, not the four-digit rounding of it. IRR is the root
		// of a polynomial: there is exactly one answer here and it is worth stating.
		#expect(abs(irr - 0.097010257403) < 1e-9, "IRR was \(irr)")
	}

	@Test("IRR with very small cash flows")
	func irrSmallCashFlows() throws {
		let cashFlows = [-0.001, 0.0004, 0.0004, 0.0004]
		let irr = try irr(cashFlows: cashFlows)

		// Should scale properly (wider tolerance for small values)
		#expect(abs(irr - 0.0970) < 0.01)
	}

	@Test("IRR with zero cash flows in middle")
	func irrZeroCashFlows() throws {
		let cashFlows = [-1000.0, 0.0, 0.0, 1200.0]
		let irr = try irr(cashFlows: cashFlows)

		// Should handle zeros
		#expect(!irr.isNaN)
		#expect(!irr.isInfinite)
	}

	@Test("MIRR with zero cash flows")
	func mirrZeroCashFlows() throws {
		let cashFlows = [-1000.0, 0.0, 500.0, 0.0, 600.0]
		let mirr = try mirr(cashFlows: cashFlows, financeRate: 0.10, reinvestmentRate: 0.08)

		// Should handle zeros
		#expect(!mirr.isNaN)
		#expect(!mirr.isInfinite)
	}

	// MARK: - Multiple Sign Changes

	@Test("IRR with multiple sign changes")
	func irrMultipleSignChanges() throws {
		// Non-conventional cash flow: -100, +50, -30, +100
		// Multiple sign changes can lead to multiple IRR solutions
		let cashFlows = [-100.0, 50.0, -30.0, 100.0]

		// Should converge to one of the valid IRRs
		let irr = try irr(cashFlows: cashFlows)

		// Just verify it converges to something reasonable
		#expect(!irr.isNaN)
		#expect(!irr.isInfinite)
		#expect(abs(irr) < 2.0)  // Reasonable bound
	}
	
		// MARK: - IRR robustness

			@Test("NPV changes sign around IRR (local crossing check)")
			func npvSignAroundIRR() throws {
				let cf = [-1000.0, 600.0, 600.0]
				let r = try irr(cashFlows: cf)
				let delta = 1e-3
				let npvBelow = npv(discountRate: r - delta, cashFlows: cf)
				let npvAbove = npv(discountRate: r + delta, cashFlows: cf)
				#expect(npvBelow * npvAbove < 0.0) // opposite signs
			}
}
