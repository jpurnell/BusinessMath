//
//  CampaignLeftoverOptimizationTests.swift
//  BusinessMathTests
//
//  The last located items of the contaminated-input campaign, in `DriverOptimizer`.
//
//  `optimize(drivers:targets:model:objective:)` did no finiteness screening of what the caller
//  handed it. Nothing crashed, and that is what made it worth fixing rather than what made it
//  safe: every fulfilment test in `buildResult` (`<`, `>=`, `<=`) is false for a NaN, so a
//  contaminated run already reported `feasible == false` — the unfavourable end, the safe
//  direction to fall. What the caller could not tell is "these targets are out of reach" from
//  "one of the numbers I gave you was not a number", and those call for opposite responses:
//  loosen the targets, or go and find the bad field.
//
//  `normalisationScale(for:)` had one guard answering two questions:
//
//      guard largest.isFinite, largest > 0 else { return 1.0 }
//
//  A driver pinned at zero has no magnitude to normalise by, and `1` is the documented and
//  correct answer there. A driver whose magnitude is NaN is a different thing, and `1` is a
//  measured scale reported for a driver nobody could measure — after which every normalised
//  coordinate derived from it reads as an ordinary number in the driver's own units. The two
//  are now separated, and the NaN branch is unreachable from the public API precisely because
//  the door above refuses it first, naming the driver. That is what the first tests here pin.
//
//  `DriverOptimizer` is deterministic — augmented Lagrangian from a fixed starting point, no
//  sampling — so its configuration carries no `seed:` to set.
//

import Foundation
import Testing
@testable import BusinessMath

/// Revenue is price times a fixed volume, so every expected value below is derived from that
/// one relationship rather than recalled.
private let unitsSold = 1_000.0

/// A missing driver surfaces as `NaN` rather than a substituted zero, so a model wired up
/// wrongly fails the numeric assertions instead of quietly passing them.
private func revenueModel(_ values: [String: Double]) -> [String: Double] {
	let price = values["price"] ?? Double.nan
	return ["revenue": price * unitsSold]
}

/// The non-finite refusal an `optimize` call produced, or `nil` if it produced none.
///
/// - Parameter body: The call to run.
/// - Returns: The message carried by ``OptimizationError/nonFiniteValue(message:)``, or `nil`
///   if the call returned, or threw something else.
private func nonFiniteRefusal(_ body: () throws -> DriverOptimization) -> String? {
	do {
		_ = try body()
		return nil
	} catch let error as OptimizationError {
		guard case .nonFiniteValue(let message) = error else { return nil }
		return message
	} catch {
		return nil
	}
}

@Suite("Driver optimization on contaminated input")
struct CampaignLeftoverOptimizationTests {

	// MARK: - Fixtures

	/// The revenue target used throughout: reachable from the clean fixture, so a refusal in
	/// these tests is about the screening and never about an impossible problem.
	private static let revenueTarget = 120_000.0

	private static var cleanTargets: [FinancialTarget] {
		[FinancialTarget(metric: "revenue", target: .minimum(revenueTarget), weight: 1.0)]
	}

	private static var cleanDrivers: [OptimizableDriver] {
		[OptimizableDriver(name: "price", currentValue: 100, range: 50...150)]
	}

	// MARK: - The door

	/// A driver whose current value is not a number is named, not normalised to `1`.
	@Test("Optimize_WithANaNDriverValue_RefusesAndNamesTheDriver")
	func optimizeWithANaNDriverValueRefusesAndNamesTheDriver() throws {
		let drivers = [
			OptimizableDriver(name: "price", currentValue: Double.nan, range: 50...150)
		]
		let message = nonFiniteRefusal {
			try DriverOptimizer().optimize(
				drivers: drivers,
				targets: Self.cleanTargets,
				model: revenueModel
			)
		}
		let detail = try #require(message, "optimize accepted a driver whose current value is not a number")
		#expect(detail.contains("price"), "the caller cannot act on a refusal that does not name the driver: \(detail)")
		#expect(detail.contains("currentValue"), "message was: \(detail)")
	}

	/// An infinite current value is unusable for the same reason and by the same route: the
	/// reported change would be `inf − inf`.
	@Test("Optimize_WithAnInfiniteDriverValue_Refuses")
	func optimizeWithAnInfiniteDriverValueRefuses() throws {
		let drivers = [
			OptimizableDriver(name: "price", currentValue: Double.infinity, range: 50...150)
		]
		let message = nonFiniteRefusal {
			try DriverOptimizer().optimize(
				drivers: drivers,
				targets: Self.cleanTargets,
				model: revenueModel
			)
		}
		let detail = try #require(message, "optimize accepted an infinite current value")
		#expect(detail.contains("price"), "message was: \(detail)")
	}

	/// A target bound that is not a number reaches the slack denominator, which divides by it.
	@Test("Optimize_WithANaNTargetBound_RefusesAndNamesTheMetric")
	func optimizeWithANaNTargetBoundRefusesAndNamesTheMetric() throws {
		let targets = [
			FinancialTarget(metric: "revenue", target: .minimum(Double.nan), weight: 1.0)
		]
		let message = nonFiniteRefusal {
			try DriverOptimizer().optimize(
				drivers: Self.cleanDrivers,
				targets: targets,
				model: revenueModel
			)
		}
		let detail = try #require(message, "optimize accepted a target bound that is not a number")
		#expect(detail.contains("revenue"), "message was: \(detail)")
		#expect(detail.contains("bound"), "message was: \(detail)")
	}

	/// Both ends of a `.range` target are screened, not only the first.
	@Test("Optimize_WithANaNUpperRangeBound_Refuses")
	func optimizeWithANaNUpperRangeBoundRefuses() throws {
		let targets = [
			FinancialTarget(metric: "revenue", target: .range(Self.revenueTarget, Double.nan), weight: 1.0)
		]
		let message = nonFiniteRefusal {
			try DriverOptimizer().optimize(
				drivers: Self.cleanDrivers,
				targets: targets,
				model: revenueModel
			)
		}
		let detail = try #require(message, "only the lower end of a .range target was being screened")
		#expect(detail.contains("revenue"), "message was: \(detail)")
	}

	/// A weight multiplies the whole penalty, so a NaN weight switches that target off.
	@Test("Optimize_WithANaNTargetWeight_Refuses")
	func optimizeWithANaNTargetWeightRefuses() throws {
		let targets = [
			FinancialTarget(metric: "revenue", target: .minimum(Self.revenueTarget), weight: Double.nan)
		]
		let message = nonFiniteRefusal {
			try DriverOptimizer().optimize(
				drivers: Self.cleanDrivers,
				targets: targets,
				model: revenueModel
			)
		}
		let detail = try #require(message, "optimize accepted a target weight that is not a number")
		#expect(detail.contains("weight"), "message was: \(detail)")
	}

	/// An unbounded percentage change is not the no-op it reads as: `centre · (1 + .infinity)`
	/// is `nan` for a driver centred at zero, and both bound constraints go with it.
	@Test("Optimize_WithAnInfinitePercentageChangeLimit_Refuses")
	func optimizeWithAnInfinitePercentageChangeLimitRefuses() throws {
		let drivers = [
			OptimizableDriver(
				name: "price",
				currentValue: 100,
				range: 50...150,
				changeConstraint: .percentageChange(max: Double.infinity)
			)
		]
		let message = nonFiniteRefusal {
			try DriverOptimizer().optimize(
				drivers: drivers,
				targets: Self.cleanTargets,
				model: revenueModel
			)
		}
		let detail = try #require(message, "optimize accepted an unbounded percentage change limit")
		#expect(detail.contains("percentageChange"), "message was: \(detail)")
	}

	/// One run names every offender. Sending the caller round the loop once per bad field is
	/// how a two-field data problem becomes a two-hour one.
	@Test("Optimize_NamesEveryOffender_InOneRefusal")
	func optimizeNamesEveryOffenderInOneRefusal() throws {
		// Three faults, each planted alone in its own field and each on a distinguishable
		// name, so a refusal that names only one of them cannot pass by coincidence.
		let drivers = [
			OptimizableDriver(name: "price", currentValue: Double.nan, range: 50...150),
			OptimizableDriver(name: "volume", currentValue: Double.infinity, range: 800...1500)
		]
		let targets = [
			FinancialTarget(metric: "revenue", target: .minimum(Double.nan), weight: 1.0)
		]
		let message = nonFiniteRefusal {
			try DriverOptimizer().optimize(
				drivers: drivers,
				targets: targets,
				model: revenueModel
			)
		}
		let detail = try #require(message, "optimize accepted three unusable inputs")
		let plantedFaults = 3
		#expect(detail.contains("\(plantedFaults) unusable"),
				"the count is what tells a caller whether they have seen all of them: \(detail)")
		#expect(detail.contains("price"), "message was: \(detail)")
		#expect(detail.contains("volume"), "message was: \(detail)")
		#expect(detail.contains("revenue"), "message was: \(detail)")
	}

	// MARK: - Controls

	/// The clean case, unchanged. The fixture is the one `DriverOptimizationTests`
	/// already pins, so this control passed before the screening existed and must after.
	@Test("Optimize_CleanProblem_Unchanged")
	func optimizeCleanProblemUnchanged() throws {
		let result = try DriverOptimizer().optimize(
			drivers: Self.cleanDrivers,
			targets: Self.cleanTargets,
			model: revenueModel
		)
		#expect(result.converged, "a clean problem still converges")
		#expect(result.feasible, "and is still reported feasible")

		// The target is a revenue floor, and revenue is price × unitsSold, so the price that
		// just meets it is the target divided by the volume. Derived here rather than quoted.
		let priceMeetingTheTarget = Self.revenueTarget / unitsSold
		let achieved = try #require(result.achievedMetrics["revenue"])
		let tolerance = Self.revenueTarget / 100.0
		#expect(achieved > Self.revenueTarget - tolerance,
				"achieved \(achieved) against a floor of \(Self.revenueTarget)")
		let optimizedPrice = try #require(result.optimizedDrivers["price"])
		#expect(optimizedPrice > priceMeetingTheTarget - tolerance / unitsSold,
				"price settled at \(optimizedPrice)")
	}

	/// The screen is narrow on purpose: an unbounded range is a caller saying "this driver has
	/// no ceiling", not contamination, and ``normalisationScale(for:)`` documents the `1.0` it
	/// answers for one. **The entry screen does not refuse it** — which is what this pins.
	///
	/// What it does *not* claim, because it was measured and is false: that the optimizer then
	/// succeeds. It does not. An unbounded range produces a non-finite during the solve and the
	/// optimizer refuses it there, with `"Function returned non-finite value at point"`. So an
	/// unbounded range does not work today either way; the difference the screen makes is only
	/// *which* refusal the caller gets, and that difference is the whole point — the screen's
	/// message names the offending field, the solver's does not.
	@Test("Optimize_WithAnUnboundedDriverRange_IsNotRefusedByTheEntryScreen")
	func optimizeWithAnUnboundedDriverRangeIsNotRefusedByTheEntryScreen() {
		let drivers = [
			OptimizableDriver(name: "price", currentValue: 100, range: 50...Double.infinity)
		]
		let message = nonFiniteRefusal {
			try DriverOptimizer().optimize(
				drivers: drivers,
				targets: Self.cleanTargets,
				model: revenueModel
			)
		}
		// The entry screen is the only thing that says "unusable" and names the field.
		let refusedByTheScreen: Bool = message?.contains("unusable") ?? false
		#expect(!refusedByTheScreen,
				"the entry screen refused an unbounded range as contamination: \(message ?? "")")
	}

	/// And the other half of the guard that was split: a driver pinned at zero keeps its
	/// documented `1.0` normalisation and its run, rather than being swept up with the NaN it
	/// used to share a guard with.
	@Test("Optimize_WithADriverPinnedAtZero_IsNotRefusedAsContaminated")
	func optimizeWithADriverPinnedAtZeroIsNotRefusedAsContaminated() {
		let drivers = [
			OptimizableDriver(name: "price", currentValue: 0, range: 0...0)
		]
		let message = nonFiniteRefusal {
			try DriverOptimizer().optimize(
				drivers: drivers,
				targets: Self.cleanTargets,
				model: revenueModel
			)
		}
		let refusedAsContaminated = message != nil
		#expect(!refusedAsContaminated,
				"a driver pinned at zero was refused as contamination: \(message ?? "")")
	}

	/// And a `.stepSize` constraint, which this continuous formulation ignores entirely, is
	/// not screened — refusing it would reject input that works today.
	@Test("Optimize_WithAStepSizeConstraint_IsNotRefused")
	func optimizeWithAStepSizeConstraintIsNotRefused() {
		let drivers = [
			OptimizableDriver(
				name: "price",
				currentValue: 100,
				range: 50...150,
				changeConstraint: .stepSize(0.5)
			)
		]
		let message = nonFiniteRefusal {
			try DriverOptimizer().optimize(
				drivers: drivers,
				targets: Self.cleanTargets,
				model: revenueModel
			)
		}
		let refusedAsContaminated = message != nil
		#expect(!refusedAsContaminated, "a step-size constraint was refused: \(message ?? "")")
	}
}
