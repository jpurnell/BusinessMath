//
//  CustomerValueTests.swift
//  BusinessMath
//
//  Customer lifetime value, and the acquisition metrics read against it.
//
//  ## Why the definition is a parameter
//
//  §12.5 of the marketing proposal records a criticism that changed the design: if there
//  are four definitions of CLV in common use, then verifying that the code matches its
//  documentation proves internal consistency and not correctness. A user who wants
//  definition three gets a library rigorously computing definition one.
//
//  The answer is that the variant is named at the call site. The library's claim is not
//  "we compute CLV" — which is not a claim anyone can check — but "we compute exactly the
//  definition you asked for", which is. These tests check each named definition against a
//  value computed outside the library, and check the definitions against **each other**
//  where they are related.
//
//  ## The identity between two of them
//
//  A finite-horizon CLV converges on the perpetuity formula as the horizon grows: both
//  are the same geometric series, one truncated. At T = 200 they agree exactly. That
//  relationship needs no reference at all, and it fails if either formula is wrong.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Customer value")
struct CustomerValueTests {

	/// A cohort of ten, thinning to four, with a constant margin of 100 while active.
	private static var cohort: [CustomerHistory<Double>] {
		// Active counts by period: 10, 8, 6, 5, 4 — so six churn across four transitions.
		let lifetimes = [5, 5, 5, 5, 4, 3, 2, 2, 1, 1]
		return lifetimes.map { periods in
			CustomerHistory(margins: [Double](repeating: 100, count: periods),
							isActive: periods == 5,
							acquisitionCost: 150)
		}
	}

	// MARK: - Each named definition

	@Test("A finite-horizon CLV is the truncated discounted series")
	func finiteHorizon() throws {
		let result = try customerLifetimeValue(cohort: Self.cohort,
											   definition: .finiteHorizon,
											   discountRate: 0.10,
											   horizon: 5,
											   retention: 0.8,
											   marginPerPeriod: 100)
		// Σ 100·0.8ᵗ/1.1ᵗ for t = 1...5, computed outside the library.
		#expect(Swift.abs(result.value - 212.4097335627) < 1e-8, "got \(result.value)")
		#expect(result.definition == .finiteHorizon)
	}

	@Test("A perpetuity CLV is the closed form")
	func perpetuity() throws {
		let result = try customerLifetimeValue(cohort: Self.cohort,
											   definition: .perpetuity,
											   discountRate: 0.10,
											   horizon: 5,
											   retention: 0.8,
											   marginPerPeriod: 100)
		// m·r/(1 + d − r) = 100 × 0.8 / 0.3
		#expect(Swift.abs(result.value - 266.6666666667) < 1e-9, "got \(result.value)")
		// The horizon is ignored by this definition, and saying so is the point of
		// naming the definition rather than inferring it.
		let longer = try customerLifetimeValue(cohort: Self.cohort, definition: .perpetuity,
											   discountRate: 0.10, horizon: 500,
											   retention: 0.8, marginPerPeriod: 100)
		#expect(Swift.abs(result.value - longer.value) < 1e-12)
	}

	@Test("A historic CLV projects nothing")
	func historic() throws {
		let cohort = [CustomerHistory<Double>(margins: [120, 95, 0, 60],
											  isActive: false, acquisitionCost: nil)]
		let plain = try customerLifetimeValue(cohort: cohort, definition: .historic,
											  discountRate: 0.10, horizon: 4)
		#expect(Swift.abs(plain.value - 275) < 1e-12, "got \(plain.value)")
		let discounted = try customerLifetimeValue(cohort: cohort,
												   definition: .discountedHistoric,
												   discountRate: 0.10, horizon: 4)
		#expect(Swift.abs(discounted.value - 228.5841131070) < 1e-8, "got \(discounted.value)")
		#expect(discounted.value < plain.value, "discounting must reduce it")
	}

	// MARK: - The identity between definitions

	@Test("Finite horizon converges on the perpetuity as the horizon grows")
	func finiteConvergesToPerpetuity() throws {
		let perpetual = try customerLifetimeValue(cohort: Self.cohort, definition: .perpetuity,
												  discountRate: 0.10, horizon: 1,
												  retention: 0.8, marginPerPeriod: 100)
		var previousGap = Double.infinity
		var checked = 0
		for horizon in [10, 25, 50, 100, 200] {
			let finite = try customerLifetimeValue(cohort: Self.cohort,
												   definition: .finiteHorizon,
												   discountRate: 0.10, horizon: horizon,
												   retention: 0.8, marginPerPeriod: 100)
			let gap = Swift.abs(finite.value - perpetual.value)
			#expect(gap <= previousGap, "gap grew at T=\(horizon): \(gap) after \(previousGap)")
			// Mathematically the truncated series is *strictly* below its limit at every
			// finite horizon, but by T = 200 the remaining tail is under an ulp and the
			// two are equal in floating point. Asserting strict inequality would be
			// asserting something true that a Double cannot represent.
			#expect(finite.value <= perpetual.value,
					"a truncated series cannot exceed its limit: \(finite.value)")
			previousGap = gap
			checked += 1
		}
		#expect(checked == 5)
		#expect(previousGap < 1e-9, "at T=200 the two should agree, gap was \(previousGap)")
	}

	// MARK: - Retention estimated from the cohort

	@Test("Retention is estimated from the cohort when it is not supplied")
	func retentionFromCohort() throws {
		// Active counts 10, 8, 6, 5, 4 give period retentions 0.8, 0.75, 0.8333, 0.8.
		let result = try customerLifetimeValue(cohort: Self.cohort, definition: .perpetuity,
											   discountRate: 0.10, horizon: 5)
		let retention = try #require(result.estimatedRetention)
		#expect(Swift.abs(retention - 0.7958333333) < 1e-8, "got \(retention)")
		// And the value follows from it rather than from a default.
		let expected: Double = 100 * retention / (1 + 0.10 - retention)
		#expect(Swift.abs(result.value - expected) < 1e-6, "got \(result.value)")
	}

	// MARK: - The refusal that matters

	@Test("A perpetuity that does not converge is refused, not returned negative")
	func divergentPerpetuityIsRefused() {
		// Retention of one with no discounting is a customer who never leaves and whose
		// future is never discounted, so the series diverges. The closed form divides by
		// 1 + d − r = 0, and for r above 1 + d it returns a *negative* number — a
		// plausible-looking CLV for an infinitely valuable customer.
		let cohort = [CustomerHistory<Double>(margins: [100], isActive: true,
											  acquisitionCost: nil)]
		#expect(throws: CLVError.self) {
			_ = try customerLifetimeValue(cohort: cohort, definition: .perpetuity,
										  discountRate: 0, horizon: 5,
										  retention: 1.0, marginPerPeriod: 100)
		}
	}

	@Test("Malformed inputs are refused")
	func refusals() {
		let cohort = [CustomerHistory<Double>(margins: [100], isActive: false,
											  acquisitionCost: nil)]
		#expect(throws: CLVError.self) {
			_ = try customerLifetimeValue(cohort: [], definition: .historic,
										  discountRate: 0.1, horizon: 5)
		}
		#expect(throws: CLVError.self) {
			_ = try customerLifetimeValue(cohort: cohort, definition: .finiteHorizon,
										  discountRate: -0.5, horizon: 5,
										  retention: 0.8, marginPerPeriod: 100)
		}
		#expect(throws: CLVError.self) {
			_ = try customerLifetimeValue(cohort: cohort, definition: .finiteHorizon,
										  discountRate: 0.1, horizon: 0,
										  retention: 0.8, marginPerPeriod: 100)
		}
		#expect(throws: CLVError.self) {
			_ = try customerLifetimeValue(cohort: cohort, definition: .perpetuity,
										  discountRate: 0.1, horizon: 5,
										  retention: 1.5, marginPerPeriod: 100)
		}
	}

	// MARK: - Acquisition

	@Test("Acquisition metrics read against the value")
	func acquisitionMetrics() throws {
		let result = try customerLifetimeValue(cohort: Self.cohort, definition: .perpetuity,
											   discountRate: 0.10, horizon: 5,
											   retention: 0.8, marginPerPeriod: 100)
		let net = try #require(result.netOfAcquisition)
		// Every customer cost 150 to acquire.
		#expect(Swift.abs(net - (266.6666666667 - 150)) < 1e-8, "got \(net)")

		let metrics = try #require(AcquisitionMetrics(lifetimeValue: result.value,
													  acquisitionCost: 150,
													  marginPerPeriod: 100))
		#expect(Swift.abs(metrics.ratio - 266.6666666667 / 150) < 1e-9, "ratio \(metrics.ratio)")
		// Payback is how many periods of margin it takes to recover the cost: 1.5.
		#expect(Swift.abs(metrics.paybackPeriods - 1.5) < 1e-12,
				"payback \(metrics.paybackPeriods)")
		#expect(metrics.isProfitable, "266 against 150 should be profitable")
	}

	@Test("Acquisition metrics refuse a zero cost rather than reporting infinite return")
	func acquisitionRefusals() {
		// A ratio against zero cost is not a very good ratio, it is an undefined one.
		#expect(AcquisitionMetrics(lifetimeValue: 100, acquisitionCost: 0,
								   marginPerPeriod: 10) == nil)
		#expect(AcquisitionMetrics(lifetimeValue: 100, acquisitionCost: -5,
								   marginPerPeriod: 10) == nil)
		#expect(AcquisitionMetrics(lifetimeValue: 100, acquisitionCost: 50,
								   marginPerPeriod: 0) == nil)
	}
}
