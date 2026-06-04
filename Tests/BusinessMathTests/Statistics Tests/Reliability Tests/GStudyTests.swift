import Testing
import Foundation
@testable import BusinessMath

@Suite("G-Study — Generalizability Study")
struct GStudyTests {

	// MARK: - One-Facet G-Study (p × r)

	@Test("Known two-way ANOVA data: variance components match manual EMS extraction")
	func testOneFacetKnownData() throws {
		// 4 subjects × 3 raters
		// Manually compute:
		// Grand mean = (4+5+6 + 2+3+4 + 8+9+10 + 6+7+8)/12 = 72/12 = 6
		// Row means: [5, 3, 9, 7]
		// Col means: [5, 6, 7]
		// ssSubjects = 3*[(5-6)^2 + (3-6)^2 + (9-6)^2 + (7-6)^2] = 3*(1+9+9+1) = 60
		// ssRaters   = 4*[(5-6)^2 + (6-6)^2 + (7-6)^2] = 4*(1+0+1) = 8
		// ssTotal    = sum of (x-6)^2 = 4+1+0+16+9+4+4+9+16+0+1+4 = 68
		// ssError    = 68 - 60 - 8 = 0
		// dfSubjects = 3, dfRaters = 2, dfError = 6
		// msSubjects = 60/3 = 20, msRaters = 8/2 = 4, msError = 0/6 = 0
		// sigma_e^2 = msError = 0
		// sigma_p^2 = (msSubjects - msError) / n_r = (20 - 0) / 3 = 6.6667
		// sigma_r^2 = (msRaters - msError) / n_p = (4 - 0) / 4 = 1.0
		let data: [[Double]] = [
			[4.0, 5.0, 6.0],
			[2.0, 3.0, 4.0],
			[8.0, 9.0, 10.0],
			[6.0, 7.0, 8.0]
		]

		let result = try gStudy(data, facetLabel: "raters")

		#expect(result.facets.count == 1)
		#expect(result.facets[0].label == "raters")
		#expect(result.facets[0].levels == 3)
		#expect(result.personCount == 4)
		#expect(result.components.count == 3) // p, raters, residual

		// Find components by source label
		let pComp = try #require(result.components.first { $0.source == "p" })
		let rComp = try #require(result.components.first { $0.source == "raters" })
		let eComp = try #require(result.components.first { $0.source == "p x raters" })

		#expect(abs(pComp.variance - 20.0 / 3.0) < 1e-10)
		#expect(abs(rComp.variance - 1.0) < 1e-10)
		#expect(abs(eComp.variance - 0.0) < 1e-10)

		#expect(abs(result.variancePersons - 20.0 / 3.0) < 1e-10)
	}

	@Test("All raters agree perfectly: sigma_r and sigma_e near zero")
	func testAllRatersAgree() throws {
		let data: [[Double]] = [
			[5.0, 5.0, 5.0],
			[3.0, 3.0, 3.0],
			[8.0, 8.0, 8.0],
			[1.0, 1.0, 1.0]
		]

		let result = try gStudy(data)

		let rComp = try #require(result.components.first { $0.source == "raters" })
		let eComp = try #require(result.components.first { $0.source == "p x raters" })

		#expect(abs(rComp.variance) < 1e-10)
		#expect(abs(eComp.variance) < 1e-10)
	}

	@Test("No subject differentiation: sigma_p near zero")
	func testNoSubjectDifferentiation() throws {
		let data: [[Double]] = [
			[4.0, 6.0, 8.0],
			[4.0, 6.0, 8.0],
			[4.0, 6.0, 8.0]
		]

		let result = try gStudy(data)

		let pComp = try #require(result.components.first { $0.source == "p" })

		#expect(abs(pComp.variance) < 1e-10)
	}

	@Test("Variance component percentages sum to 100%")
	func testPercentagesSumToHundred() throws {
		let data: [[Double]] = [
			[3.0, 5.0, 7.0, 2.0],
			[8.0, 6.0, 4.0, 9.0],
			[1.0, 2.0, 3.0, 5.0],
			[6.0, 7.0, 8.0, 4.0],
			[2.0, 3.0, 5.0, 1.0]
		]

		let result = try gStudy(data)

		let totalPercent = result.components.reduce(0.0) { $0 + $1.percentOfTotal }
		#expect(abs(totalPercent - 100.0) < 1e-10)
	}

	@Test("Negative raw estimate truncated to zero")
	func testNegativeTruncatedToZero() throws {
		// Construct data where rater MS < error MS so raw sigma_r^2 < 0.
		// All raters give very similar means but subjects × rater interaction is large.
		// Use data where column means are nearly identical but residual is large.
		let data: [[Double]] = [
			[10.0, 1.0],
			[1.0, 10.0],
			[10.0, 1.0]
		]

		// Here rater column means are [7, 4] but error is large.
		// Grand mean = 33/6 = 5.5
		// Row means: [5.5, 5.5, 5.5] → ssSubjects = 0
		// Col means: [7, 4] → ssRaters = 3*[(7-5.5)^2+(4-5.5)^2] = 3*(2.25+2.25) = 13.5
		// ssTotal = (10-5.5)^2+(1-5.5)^2+(1-5.5)^2+(10-5.5)^2+(10-5.5)^2+(1-5.5)^2
		//         = 20.25+20.25+20.25+20.25+20.25+20.25 = 121.5
		// ssError = 121.5 - 0 - 13.5 = 108
		// dfSubjects = 2, dfRaters = 1, dfError = 2
		// msSubjects = 0/2 = 0, msRaters = 13.5/1 = 13.5, msError = 108/2 = 54
		// sigma_p^2 = (0 - 54)/2 = -27 → truncate to 0
		let result = try gStudy(data)

		let pComp = try #require(result.components.first { $0.source == "p" })
		#expect(pComp.variance >= 0.0)
		#expect(abs(pComp.variance) < 1e-10)
	}

	@Test("Fewer than 2 persons throws insufficientData")
	func testFewerThan2PersonsThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try gStudy([[1.0, 2.0, 3.0]])
		}
	}

	@Test("Ragged matrix throws mismatchedDimensions")
	func testRaggedMatrixThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try gStudy([[1.0, 2.0, 3.0], [4.0, 5.0]])
		}
	}

	// MARK: - Two-Facet G-Study (p × r × i)

	@Test("Known three-way data with verifiable variance components")
	func testTwoFacetKnownData() throws {
		// 3 persons × 2 raters × 2 items
		// data[person][rater][item]
		let data: [[[Double]]] = [
			// Person 0
			[[4.0, 5.0], [6.0, 7.0]],
			// Person 1
			[[2.0, 3.0], [4.0, 5.0]],
			// Person 2
			[[8.0, 9.0], [10.0, 11.0]]
		]

		// n_p=3, n_r=2, n_i=2, N=12
		// Grand mean = (4+5+6+7+2+3+4+5+8+9+10+11)/12 = 74/12 = 37/6 ≈ 6.1667
		// Person means: p0 = 22/4 = 5.5, p1 = 14/4 = 3.5, p2 = 38/4 = 9.5
		// Rater means: r0 = (4+5+2+3+8+9)/6 = 31/6, r1 = (6+7+4+5+10+11)/6 = 43/6
		// Item means: i0 = (4+6+2+4+8+10)/6 = 34/6, i1 = (5+7+3+5+9+11)/6 = 40/6

		let result = try gStudy(data, facetLabels: ("raters", "items"))

		#expect(result.facets.count == 2)
		#expect(result.components.count == 7)
		#expect(result.personCount == 3)

		// All variance components should be non-negative
		for comp in result.components {
			#expect(comp.variance >= 0.0, "Component \(comp.source) should be >= 0")
		}

		// totalVariance = sum of all component variances
		let sumVariances = result.components.reduce(0.0) { $0 + $1.variance }
		#expect(abs(result.totalVariance - sumVariances) < 1e-10)
	}

	@Test("Seven components extracted, all non-negative")
	func testSevenComponents() throws {
		let data: [[[Double]]] = [
			[[3.0, 4.0, 5.0], [6.0, 7.0, 8.0]],
			[[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]],
			[[7.0, 8.0, 9.0], [2.0, 3.0, 4.0]],
			[[5.0, 6.0, 7.0], [8.0, 9.0, 1.0]]
		]

		let result = try gStudy(data, facetLabels: ("raters", "items"))

		#expect(result.components.count == 7)

		let expectedSources: Set<String> = [
			"p", "raters", "items",
			"p x raters", "p x items", "raters x items",
			"p x raters x items"
		]
		let actualSources = Set(result.components.map { $0.source })
		#expect(actualSources == expectedSources)

		for comp in result.components {
			#expect(comp.variance >= 0.0, "Component \(comp.source) should be >= 0")
		}
	}

	@Test("Two-facet percentages sum to 100%")
	func testTwoFacetPercentagesSumToHundred() throws {
		let data: [[[Double]]] = [
			[[3.0, 4.0, 5.0], [6.0, 7.0, 8.0]],
			[[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]],
			[[7.0, 8.0, 9.0], [2.0, 3.0, 4.0]],
			[[5.0, 6.0, 7.0], [8.0, 9.0, 1.0]]
		]

		let result = try gStudy(data, facetLabels: ("raters", "items"))

		let totalPercent = result.components.reduce(0.0) { $0 + $1.percentOfTotal }
		#expect(abs(totalPercent - 100.0) < 1e-10)
	}

	@Test("Uniform data: all variances near zero")
	func testUniformData() throws {
		let data: [[[Double]]] = [
			[[5.0, 5.0], [5.0, 5.0]],
			[[5.0, 5.0], [5.0, 5.0]],
			[[5.0, 5.0], [5.0, 5.0]]
		]

		let result = try gStudy(data, facetLabels: ("raters", "items"))

		for comp in result.components {
			#expect(abs(comp.variance) < 1e-10,
					"Component \(comp.source) should be zero for uniform data")
		}
	}

	@Test("Non-rectangular 3D array throws mismatchedDimensions")
	func testNonRectangular3DThrows() throws {
		// Different number of items per rater
		let data: [[[Double]]] = [
			[[1.0, 2.0], [3.0]],
			[[4.0, 5.0], [6.0, 7.0]]
		]

		#expect(throws: BusinessMathError.self) {
			let _ = try gStudy(data, facetLabels: ("raters", "items"))
		}
	}
}
