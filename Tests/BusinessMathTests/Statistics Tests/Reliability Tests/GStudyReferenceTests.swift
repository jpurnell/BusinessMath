//
//  GStudyReferenceTests.swift
//  BusinessMath
//
//  An external oracle for the one-facet generalizability study.
//
//  `GStudyTests` has 12 tests and checked none of them against anything outside the
//  package. `gStudy` has two independent things that can be wrong — the two-way ANOVA
//  that produces the mean squares, and the expected-mean-square algebra that turns them
//  into variance components — so the fixture checks both, by different means.
//
//  The **mean squares** come from `statsmodels.formula.api.ols` run through `anova_lm`.
//  That is a genuine external implementation and it does not know what a G-study is.
//
//  The **variance components** are then the EMS arithmetic on those three numbers,
//  written out in the generator:
//
//      sigma_e^2 = MS_error
//      sigma_p^2 = (MS_persons - MS_error) / n_r
//      sigma_r^2 = (MS_facet   - MS_error) / n_p
//
//  Checking both separately means a failure says which half is wrong, rather than only
//  that something is.
//
//  Values from Tests/BusinessMathTests/Fixtures/gStudy.json.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("G-study against statsmodels ANOVA")
struct GStudyReferenceTests {

	// MARK: - Fixture

	private struct Fixture: Decodable {
		let name: String
		let reference: String
		let note: String
		let cases: [Case]
	}

	private struct Case: Decodable {
		let name: String
		let note: String
		let data: [[Double]]
		let personCount: Int
		let raterCount: Int
		let meanSquares: MeanSquares
		let rawComponents: RawComponents
		let components: Components
		let totalVariance: Double
		let facetWasTruncated: Bool
		let personWasTruncated: Bool
	}

	private struct MeanSquares: Decodable {
		let persons: Double
		let facet: Double
		let error: Double
	}

	private struct RawComponents: Decodable {
		let persons: Double
		let facet: Double
	}

	private struct Components: Decodable {
		let persons: Double
		let facet: Double
		let residual: Double
	}

	private static func loadFixture() throws -> Fixture {
		guard let url = Bundle.module.url(forResource: "gStudy",
										  withExtension: "json",
										  subdirectory: "Fixtures")
			?? Bundle.module.url(forResource: "gStudy", withExtension: "json") else {
			struct Missing: Error { let name: String }
			throw Missing(name: "gStudy")
		}
		return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
	}

	/// Absolute where the reference is near zero, relative otherwise.
	private static func agrees(_ actual: Double, _ reference: Double,
							   relative: Double = 1e-9, absolute: Double = 1e-9) -> Bool {
		let gap = abs(actual - reference)
		if gap <= absolute { return true }
		return gap / Swift.max(abs(reference), Double.leastNormalMagnitude) <= relative
	}

	// MARK: - The fixture itself

	@Test("The fixture is present and exercises the truncation")
	func fixtureIsWellFormed() throws {
		let fixture = try Self.loadFixture()
		#expect(fixture.reference.contains("statsmodels"),
				"reference was '\(fixture.reference)'")
		#expect(fixture.cases.count >= 6, "only \(fixture.cases.count) designs")

		// A negative variance estimate clamped to zero is standard and is what makes the
		// result usable — but it is also where an implementation can differ invisibly.
		// If the fixture ever loses its negative case, the clamp stops being tested.
		#expect(fixture.cases.contains { $0.facetWasTruncated },
				"no design produces a negative facet component, so the clamp is untested")

		// And a design where each component in turn dominates, so a transposition of
		// persons and facet could not pass.
		#expect(fixture.cases.contains { $0.components.persons > 5 * $0.components.facet })
		#expect(fixture.cases.contains { $0.components.facet > 5 * $0.components.persons })

		for entry in fixture.cases {
			#expect(entry.data.count == entry.personCount)
			#expect(entry.data.allSatisfy { $0.count == entry.raterCount })
		}
	}

	// MARK: - The mean squares, against statsmodels

	@Test("Mean squares match statsmodels' two-way ANOVA")
	func meanSquaresMatchStatsmodels() throws {
		// The first of the two halves. `gStudy` delegates to `twoWayANOVA`, so this also
		// puts an oracle behind that.
		let fixture = try Self.loadFixture()
		var compared = 0

		for entry in fixture.cases {
			let anova = try twoWayANOVA(entry.data)
			let expected: [(String, Double, Double)] = [
				("MS_persons", anova.msSubjects, entry.meanSquares.persons),
				("MS_facet", anova.msRaters, entry.meanSquares.facet),
				("MS_error", anova.msError, entry.meanSquares.error)
			]
			for (label, actual, reference) in expected {
				#expect(Self.agrees(actual, reference, relative: 1e-9, absolute: 1e-9),
						"\(entry.name) \(label): got \(actual), statsmodels \(reference)")
				compared += 1
			}
		}
		#expect(compared >= 18, "only \(compared) mean squares compared")
	}

	// MARK: - The variance components

	@Test("Variance components match the expected-mean-square algebra")
	func componentsMatchEMS() throws {
		let fixture = try Self.loadFixture()
		var compared = 0

		for entry in fixture.cases {
			let result = try gStudy(entry.data)

			// `source` is "p" for persons, the facet label for the facet, and
			// "p x <facet>" for the residual.
			func component(_ source: String) -> Double? {
				result.components.first { $0.source == source }?.variance
			}
			guard let persons = component("p"),
				  let facet = component("raters"),
				  let residual = component("p x raters") else {
				let found = result.components.map(\.source).joined(separator: ", ")
				Issue.record("\(entry.name): expected sources p, raters, p x raters — got \(found)")
				continue
			}

			let expected: [(String, Double, Double)] = [
				("persons", persons, entry.components.persons),
				("facet", facet, entry.components.facet),
				("residual", residual, entry.components.residual)
			]
			for (label, actual, reference) in expected {
				#expect(Self.agrees(actual, reference, relative: 1e-9, absolute: 1e-9),
						"\(entry.name) \(label): got \(actual), reference \(reference)")
				compared += 1
			}

			#expect(Self.agrees(result.totalVariance, entry.totalVariance,
								relative: 1e-9, absolute: 1e-9),
					"\(entry.name) total: got \(result.totalVariance), reference \(entry.totalVariance)")
			#expect(Self.agrees(result.variancePersons, entry.components.persons,
								relative: 1e-9, absolute: 1e-9),
					"\(entry.name) variancePersons: got \(result.variancePersons)")
		}
		#expect(compared >= 18, "only \(compared) components compared")
	}

	@Test("A negative variance estimate is clamped to zero, not passed through")
	func negativeComponentsAreTruncated() throws {
		// The clamp, isolated. Where the fixture records that the raw estimate was
		// negative, the reported component must be exactly zero — not a small negative
		// number, and not the raw value. A proportion computed from a negative variance
		// is nonsense, and it would be nonsense that still summed and still compared.
		let fixture = try Self.loadFixture()
		var exercised = 0

		for entry in fixture.cases where entry.facetWasTruncated || entry.personWasTruncated {
			let result = try gStudy(entry.data)
			for component in result.components {
				#expect(component.variance >= 0,
						"\(entry.name): \(component.source) is \(component.variance)")
			}
			if entry.facetWasTruncated {
				let facet = result.components.first { $0.source == "raters" }?.variance
				#expect(facet?.isEqual(to: 0.0) == true,
						"\(entry.name): the facet raw estimate was \(entry.rawComponents.facet) and should clamp to exactly zero, got \(String(describing: facet))")
				exercised += 1
			}
		}
		#expect(exercised >= 1, "no truncating design was exercised")
	}

	@Test("Percentages are shares of the reported total")
	func percentagesAreConsistent() throws {
		// Independent of the reference. The components and their percentages are two
		// views of the same numbers, and they must agree — a percentage computed against
		// a total that excluded a clamped component would still look plausible.
		let fixture = try Self.loadFixture()

		for entry in fixture.cases {
			let result = try gStudy(entry.data)
			let total = result.totalVariance
			guard total > 0 else { continue }

			var summed = 0.0
			for component in result.components {
				let share = 100 * component.variance / total
				#expect(abs(component.percentOfTotal - share) < 1e-9,
						"\(entry.name) \(component.source): reported \(component.percentOfTotal)%, computed \(share)%")
				summed += component.percentOfTotal
			}
			#expect(abs(summed - 100) < 1e-9,
					"\(entry.name): percentages sum to \(summed)")
		}
	}

	// MARK: - Rejection

	@Test("Designs too small to decompose are refused")
	func rejectsDegenerateDesigns() {
		// One person or one rater leaves a degree of freedom at zero, and the mean
		// square would be a division by it.
		#expect(throws: (any Error).self) { _ = try gStudy([[1.0, 2.0, 3.0]]) }
		#expect(throws: (any Error).self) { _ = try gStudy([[1.0], [2.0], [3.0]]) }
		#expect(throws: (any Error).self) { _ = try gStudy([[Double]]()) }
		// Ragged input is not a design at all.
		#expect(throws: (any Error).self) { _ = try gStudy([[1.0, 2.0], [3.0]]) }
	}
}
