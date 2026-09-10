//
//  ParametricCLVTests.swift
//  BusinessMath
//
//  Lifetime value computed from parameters rather than from a cohort, and the convention
//  the enum was missing.
//
//  A subscription business models LTV parametrically — margin per period and a retention
//  rate — long before it has cohort histories to measure. The cohort entry point cannot
//  express that, and the industry's own formula, `margin / churn`, is not
//  ``CLVDefinition/perpetuity``: it differs by exactly one period's margin, because it
//  counts the margin arriving now and the discounted perpetuity does not.
//
//  That is not a discrepancy to split the difference on. It is the distinction between an
//  ordinary annuity and an **annuity due**, it has a name in finance, and shipping it as a
//  named case is what lets a caller say which one they meant. The alternative — picking
//  one and quietly renumbering everybody's LTV — is precisely what the explicit
//  ``CLVDefinition`` parameter exists to prevent.
//
//  Three ways this goes wrong quietly:
//
//  - **Reading `margin / churn` as the discounted perpetuity.** At 5% churn they differ by
//    5%, which is small enough to look like rounding and large enough to change a
//    valuation.
//  - **A parametric call asking for a historic definition.** `.historic` averages what a
//    cohort actually earned. With no cohort there is nothing to average, and returning the
//    forward-looking number under a backward-looking name would be a lie about provenance.
//  - **Retention of exactly one at a zero discount rate.** Nobody ever leaves, the
//    denominator is zero, and the honest answer is that the series does not converge.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Parametric lifetime value")
struct ParametricCLVTests {

	// MARK: - The identity that names the new case

	@Test("An annuity due is the ordinary perpetuity plus one period's margin")
	func dueIsOrdinaryPlusOneMargin() throws {
		let cases: [(margin: Double, retention: Double, discount: Double)] = [
			(100, 0.95, 0),
			(100, 0.95, 0.02),
			(45.5, 0.80, 0.10),
			(7, 0.5, 0.25)
		]
		for setup in cases {
			let ordinary = try customerLifetimeValue(marginPerPeriod: setup.margin,
													 retention: setup.retention,
													 definition: .perpetuity,
													 discountRate: setup.discount)
			let due = try customerLifetimeValue(marginPerPeriod: setup.margin,
												retention: setup.retention,
												definition: .perpetuityDue,
												discountRate: setup.discount)
			let gap: Double = due.value - ordinary.value
			#expect(Swift.abs(gap - setup.margin) < 1e-9,
					"at \(setup): gap \(gap), margin \(setup.margin)")
		}
	}

	@Test("At a zero discount rate the annuity due is exactly margin over churn")
	func dueReproducesTheIndustryFormula() throws {
		// The formula every SaaS template in this library has always used.
		let margin: Double = 100
		let churn: Double = 0.05
		let retention: Double = 1 - churn
		let due = try customerLifetimeValue(marginPerPeriod: margin,
											retention: retention,
											definition: .perpetuityDue)
		let industry: Double = margin / churn
		#expect(Swift.abs(due.value - industry) < 1e-9, "\(due.value) against \(industry)")
		#expect(Swift.abs(industry - 2000) < 1e-9, "the worked number is \(industry)")
	}

	// MARK: - The two entry points agree

	@Test("Parametric and cohort agree when the cohort's parameters are supplied")
	func parametricMatchesCohort() throws {
		let cohort = [
			CustomerHistory(margins: [10, 10, 10], isActive: false),
			CustomerHistory(margins: [10, 10], isActive: true)
		]
		let margin: Double = 25
		let retention: Double = 0.9
		for definition in [CLVDefinition.perpetuity, .perpetuityDue, .finiteHorizon] {
			let fromCohort = try customerLifetimeValue(cohort: cohort,
													   definition: definition,
													   discountRate: 0.05,
													   horizon: 24,
													   retention: retention,
													   marginPerPeriod: margin)
			let fromParameters = try customerLifetimeValue(marginPerPeriod: margin,
														   retention: retention,
														   definition: definition,
														   discountRate: 0.05,
														   horizon: 24)
			#expect(Swift.abs(fromCohort.value - fromParameters.value) < 1e-12,
					"\(definition): \(fromCohort.value) against \(fromParameters.value)")
		}
	}

	@Test("A long finite horizon converges on the ordinary perpetuity")
	func finiteHorizonConvergesOnPerpetuity() throws {
		let margin: Double = 60
		let retention: Double = 0.85
		let discount: Double = 0.01
		let finite = try customerLifetimeValue(marginPerPeriod: margin,
											   retention: retention,
											   definition: .finiteHorizon,
											   discountRate: discount,
											   horizon: 400)
		let forever = try customerLifetimeValue(marginPerPeriod: margin,
												retention: retention,
												definition: .perpetuity,
												discountRate: discount)
		#expect(Swift.abs(finite.value - forever.value) < 1e-9,
				"\(finite.value) against \(forever.value)")
		// The finite sum starts at period one, which is why it approaches the ordinary
		// perpetuity and not the annuity due.
		let due = try customerLifetimeValue(marginPerPeriod: margin,
											retention: retention,
											definition: .perpetuityDue,
											discountRate: discount)
		let gap: Double = due.value - finite.value
		#expect(Swift.abs(gap - margin) < 1e-9, "gap \(gap)")
	}

	// MARK: - What the result carries

	@Test("A parametric result reports the parameters it was given and no cohort")
	func resultDescribesItsOwnProvenance() throws {
		let result = try customerLifetimeValue(marginPerPeriod: 40,
											   retention: 0.9,
											   definition: .perpetuityDue)
		#expect(result.definition == .perpetuityDue)
		#expect(result.cohortSize == 0, "there was no cohort — \(result.cohortSize)")
		#expect(result.netOfAcquisition == nil, "no cost was supplied")
		let retention = try #require(result.estimatedRetention)
		#expect(Swift.abs(retention - 0.9) < 1e-12)
		#expect(Swift.abs(result.averageMargin - 40) < 1e-12)
	}

	@Test("A loss-making product has a negative lifetime value, not a refusal")
	func negativeMarginIsAllowed() throws {
		let result = try customerLifetimeValue(marginPerPeriod: -3,
											   retention: 0.8,
											   definition: .perpetuityDue)
		#expect(result.value < 0, "\(result.value)")
		// −3 / 0.2 = −15: every period costs three and they stay five periods.
		#expect(Swift.abs(result.value - (-15)) < 1e-9, "\(result.value)")
	}

	// MARK: - Refusals

	@Test("A historic definition needs history, and says so")
	func historicDefinitionsAreRefused() {
		#expect(throws: CLVError.definitionNeedsHistory(.historic)) {
			_ = try customerLifetimeValue(marginPerPeriod: 10, retention: 0.9,
										  definition: .historic)
		}
		#expect(throws: CLVError.definitionNeedsHistory(.discountedHistoric)) {
			_ = try customerLifetimeValue(marginPerPeriod: 10, retention: 0.9,
										  definition: .discountedHistoric)
		}
	}

	@Test("A perpetuity that does not converge is refused under both conventions")
	func divergenceIsRefused() {
		for definition in [CLVDefinition.perpetuity, .perpetuityDue] {
			#expect(throws: CLVError.self) {
				_ = try customerLifetimeValue(marginPerPeriod: 10, retention: 1,
											  definition: definition, discountRate: 0)
			}
		}
		// A positive discount rate rescues it: money later is worth less, so the series
		// converges even though nobody ever churns.
		#expect(throws: Never.self) {
			_ = try customerLifetimeValue(marginPerPeriod: 10, retention: 1,
										  definition: .perpetuityDue, discountRate: 0.05)
		}
	}

	@Test("Parameters that are not rates are refused")
	func invalidParametersAreRefused() {
		#expect(throws: CLVError.invalidRetention) {
			_ = try customerLifetimeValue(marginPerPeriod: 10, retention: 1.2,
										  definition: .perpetuityDue)
		}
		#expect(throws: CLVError.invalidRetention) {
			_ = try customerLifetimeValue(marginPerPeriod: 10, retention: -0.1,
										  definition: .perpetuityDue)
		}
		#expect(throws: CLVError.invalidDiscountRate) {
			_ = try customerLifetimeValue(marginPerPeriod: 10, retention: 0.9,
										  definition: .perpetuityDue, discountRate: -0.1)
		}
		#expect(throws: CLVError.missingMargin) {
			_ = try customerLifetimeValue(marginPerPeriod: Double.infinity, retention: 0.9,
										  definition: .perpetuityDue)
		}
		#expect(throws: CLVError.invalidHorizon) {
			_ = try customerLifetimeValue(marginPerPeriod: 10, retention: 0.9,
										  definition: .finiteHorizon, horizon: 0)
		}
	}
}
