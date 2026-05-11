import Testing
import Foundation
@testable import BusinessMath

@Suite("Nested ANOVA")
struct NestedANOVATests {

	// MARK: - Test 1: Balanced Design with Known Values

	@Test("Balanced design (a=3, b=4, n=5) with known textbook SS values")
	func testBalancedDesign() throws {
		// 3 groups, 4 subgroups each, 5 observations each
		// Group 1 subgroups centered around 10, Group 2 around 20, Group 3 around 30
		// Subgroup offsets: 0, 1, 2, 3 within each group
		let data: [[[Double]]] = [
			// Group 1 (base ~10)
			[[10, 11, 9, 10, 10],   // subgroup 0, mean=10
			 [11, 12, 10, 11, 11],  // subgroup 1, mean=11
			 [12, 13, 11, 12, 12],  // subgroup 2, mean=12
			 [13, 14, 12, 13, 13]], // subgroup 3, mean=13
			// Group 2 (base ~20)
			[[20, 21, 19, 20, 20],  // subgroup 0, mean=20
			 [21, 22, 20, 21, 21],  // subgroup 1, mean=21
			 [22, 23, 21, 22, 22],  // subgroup 2, mean=22
			 [23, 24, 22, 23, 23]], // subgroup 3, mean=23
			// Group 3 (base ~30)
			[[30, 31, 29, 30, 30],  // subgroup 0, mean=30
			 [31, 32, 30, 31, 31],  // subgroup 1, mean=31
			 [32, 33, 31, 32, 32],  // subgroup 2, mean=32
			 [33, 34, 32, 33, 33]]  // subgroup 3, mean=33
		]

		let result = try nestedANOVA(data)

		// a=3, b=4, n=5, N=60
		#expect(result.groupCount == 3)
		#expect(result.totalCount == 60)
		#expect(result.dfBetweenGroups == 2)      // a-1 = 2
		#expect(result.dfSubgroupsWithin == 9)     // a*(b-1) = 3*3 = 9
		#expect(result.dfWithinSubgroups == 48)    // a*b*(n-1) = 3*4*4 = 48

		// Grand mean = (10+11+12+13 + 20+21+22+23 + 30+31+32+33)/12 = 258/12 = 21.5
		// Group means: G1=11.5, G2=21.5, G3=31.5
		// SS_between = b*n * sum (groupMean - grandMean)^2
		//            = 4*5 * [(11.5-21.5)^2 + (21.5-21.5)^2 + (31.5-21.5)^2]
		//            = 20 * [100 + 0 + 100] = 4000
		#expect(abs(result.ssBetweenGroups - 4000.0) < 1e-8)

		// SS_subgroups_within = n * sum_i sum_j (subgroupMean_ij - groupMean_i)^2
		// Each group has subgroup means at -1.5, -0.5, 0.5, 1.5 from group mean
		// Per group: 5 * [(-1.5)^2 + (-0.5)^2 + (0.5)^2 + (1.5)^2] = 5 * [2.25+0.25+0.25+2.25] = 5*5 = 25
		// Total: 3 * 25 = 75
		#expect(abs(result.ssSubgroupsWithin - 75.0) < 1e-8)

		// SS_within = sum of within-subgroup SS
		// Each subgroup like [10,11,9,10,10] has SS = 1+0+1+0+0 = 2
		// 12 subgroups * 2 = 24
		#expect(abs(result.ssWithinSubgroups - 24.0) < 1e-8)
	}

	// MARK: - Test 2: SS Decomposition

	@Test("SS_total = SS_between + SS_subgroups_within + SS_within")
	func testSSDecomposition() throws {
		let data: [[[Double]]] = [
			[[2.3, 4.1, 3.5], [5.2, 6.0, 4.8]],
			[[8.1, 7.5, 9.0], [10.2, 11.0, 9.8]],
			[[1.0, 2.0, 1.5], [3.0, 4.0, 3.5]]
		]

		let result = try nestedANOVA(data)
		let ssSum = result.ssBetweenGroups + result.ssSubgroupsWithin + result.ssWithinSubgroups
		#expect(abs(result.ssTotal - ssSum) < 1e-8)
	}

	// MARK: - Test 3: df Decomposition

	@Test("df_total = df_between + df_subgroups + df_within = N - 1")
	func testDfDecomposition() throws {
		let data: [[[Double]]] = [
			[[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]],
			[[13, 14, 15], [16, 17, 18], [19, 20, 21], [22, 23, 24]],
			[[25, 26, 27], [28, 29, 30], [31, 32, 33], [34, 35, 36]]
		]

		let result = try nestedANOVA(data)
		// a=3, b=4, n=3: N=36
		let dfTotal = result.dfBetweenGroups + result.dfSubgroupsWithin + result.dfWithinSubgroups
		#expect(dfTotal == result.totalCount - 1)
	}

	// MARK: - Test 4: All Groups Identical Means

	@Test("All groups identical means → SS_between ≈ 0")
	func testIdenticalGroupMeans() throws {
		let data: [[[Double]]] = [
			[[5, 5, 5], [5, 5, 5]],
			[[5, 5, 5], [5, 5, 5]],
			[[5, 5, 5], [5, 5, 5]]
		]

		let result = try nestedANOVA(data)
		#expect(abs(result.ssBetweenGroups) < 1e-10)
		#expect(abs(result.ssSubgroupsWithin) < 1e-10)
		#expect(abs(result.ssWithinSubgroups) < 1e-10)
	}

	// MARK: - Test 5: All Subgroups Within Each Group Identical

	@Test("All subgroups within each group identical → SS_subgroups_within ≈ 0")
	func testIdenticalSubgroupMeans() throws {
		// Different group means, but identical subgroup means within each group
		let data: [[[Double]]] = [
			[[10, 10, 10], [10, 10, 10]],
			[[20, 20, 20], [20, 20, 20]],
			[[30, 30, 30], [30, 30, 30]]
		]

		let result = try nestedANOVA(data)
		#expect(abs(result.ssSubgroupsWithin) < 1e-10)
		#expect(abs(result.ssWithinSubgroups) < 1e-10)
		// SS_between should be large
		#expect(result.ssBetweenGroups > 100)
	}

	// MARK: - Test 6: All Observations Identical

	@Test("All observations identical → all SS = 0")
	func testAllIdentical() throws {
		let data: [[[Double]]] = [
			[[7, 7, 7], [7, 7, 7]],
			[[7, 7, 7], [7, 7, 7]]
		]

		let result = try nestedANOVA(data)
		#expect(abs(result.ssBetweenGroups) < 1e-10)
		#expect(abs(result.ssSubgroupsWithin) < 1e-10)
		#expect(abs(result.ssWithinSubgroups) < 1e-10)
		#expect(abs(result.ssTotal) < 1e-10)
	}

	// MARK: - Test 7: Variance Components

	@Test("Variance components correct: sigma_e = MS_within")
	func testVarianceComponents() throws {
		let data: [[[Double]]] = [
			[[2, 4, 3], [5, 6, 4]],
			[[8, 7, 9], [10, 11, 9]],
			[[1, 2, 1], [3, 4, 3]]
		]

		let result = try nestedANOVA(data)
		// sigma_e^2 = MS_within
		#expect(abs(result.varianceWithinSubgroups - result.msWithinSubgroups) < 1e-10)
	}

	// MARK: - Test 8: F_between Uses MS_subgroups as Denominator

	@Test("F_between uses MS_subgroups as denominator, not MS_within")
	func testFBetweenDenominator() throws {
		let data: [[[Double]]] = [
			[[1, 2, 3], [4, 5, 6]],
			[[10, 11, 12], [13, 14, 15]],
			[[20, 21, 22], [23, 24, 25]]
		]

		let result = try nestedANOVA(data)

		// F_between = MS_between / MS_subgroups (NOT MS_within)
		guard result.msSubgroupsWithin > 0 else { return }
		let expectedF = result.msBetweenGroups / result.msSubgroupsWithin
		#expect(abs(result.fBetweenGroups - expectedF) < 1e-10)

		// F_subgroups = MS_subgroups / MS_within
		guard result.msWithinSubgroups > 0 else { return }
		let expectedFSub = result.msSubgroupsWithin / result.msWithinSubgroups
		#expect(abs(result.fSubgroupsWithin - expectedFSub) < 1e-10)
	}

	// MARK: - Test 9: Unbalanced — Different n Per Subgroup

	@Test("Unbalanced: different n per subgroup")
	func testUnbalancedSubgroupSizes() throws {
		let data: [[[Double]]] = [
			[[1, 2, 3, 4], [5, 6]],       // group 0: subgroups of size 4, 2
			[[10, 11, 12], [13, 14, 15]]   // group 1: subgroups of size 3, 3
		]

		let result = try nestedANOVA(data)

		// SS decomposition must still hold
		let ssSum = result.ssBetweenGroups + result.ssSubgroupsWithin + result.ssWithinSubgroups
		#expect(abs(result.ssTotal - ssSum) < 1e-8)

		// df decomposition: N-1
		let dfTotal = result.dfBetweenGroups + result.dfSubgroupsWithin + result.dfWithinSubgroups
		#expect(dfTotal == result.totalCount - 1)
	}

	// MARK: - Test 10: Unbalanced — Different b Per Group

	@Test("Unbalanced: different number of subgroups per group")
	func testUnbalancedSubgroupCounts() throws {
		let data: [[[Double]]] = [
			[[1, 2], [3, 4], [5, 6]],     // group 0: 3 subgroups
			[[10, 11], [12, 13]]           // group 1: 2 subgroups
		]

		let result = try nestedANOVA(data)

		// SS decomposition still holds
		let ssSum = result.ssBetweenGroups + result.ssSubgroupsWithin + result.ssWithinSubgroups
		#expect(abs(result.ssTotal - ssSum) < 1e-8)

		// df: between = a-1 = 1
		// df_subgroups_within = sum_i(b_i - 1) = (3-1)+(2-1) = 3
		#expect(result.dfBetweenGroups == 1)
		#expect(result.dfSubgroupsWithin == 3)

		// df decomposition
		let dfTotal = result.dfBetweenGroups + result.dfSubgroupsWithin + result.dfWithinSubgroups
		#expect(dfTotal == result.totalCount - 1)
	}

	// MARK: - Test 11: Fewer Than 2 Groups Throws

	@Test("Fewer than 2 groups throws insufficientData")
	func testFewerThan2Groups() {
		#expect(throws: BusinessMathError.self) {
			let _: NestedANOVAResult<Double> = try nestedANOVA([
				[[1, 2, 3], [4, 5, 6]]
			])
		}
	}

	// MARK: - Test 12: Group With Fewer Than 2 Subgroups Throws

	@Test("Group with fewer than 2 subgroups throws insufficientData")
	func testFewerThan2Subgroups() {
		#expect(throws: BusinessMathError.self) {
			let _ = try nestedANOVA([
				[[1, 2, 3], [4, 5, 6]],
				[[7, 8, 9]]             // only 1 subgroup
			])
		}
	}

	// MARK: - Test 13: Empty Subgroup Throws

	@Test("Empty subgroup throws insufficientData")
	func testEmptySubgroup() {
		#expect(throws: BusinessMathError.self) {
			let _ = try nestedANOVA([
				[[1, 2, 3], []],
				[[4, 5, 6], [7, 8, 9]]
			])
		}
	}

	// MARK: - Test 14: Negative Variance Component Truncated to Zero

	@Test("Negative variance component truncated to zero")
	func testNegativeVarianceTruncated() throws {
		// When MS_subgroups < MS_within, sigma_beta^2 would be negative
		// This can happen with certain data patterns; use data where subgroup effect is zero
		// but random noise creates the condition.
		// Construct: subgroups have very similar means but high within-subgroup variance
		let data: [[[Double]]] = [
			[[1, 100], [50, 51]],
			[[200, 201], [1, 300]]
		]

		let result = try nestedANOVA(data)

		// Variance components must be non-negative
		#expect(result.varianceBetweenGroups >= 0)
		#expect(result.varianceSubgroupsWithin >= 0)
		#expect(result.varianceWithinSubgroups >= 0)
	}
}

// MARK: - Multi-Level Nested ANOVA Tests

@Suite("Multi-Level Nested ANOVA")
struct MultiLevelNestedANOVATests {

	// MARK: - Test 15: Three-Level Hierarchy

	@Test("Three-level hierarchy via multiLevelNestedANOVA")
	func testThreeLevelHierarchy() throws {
		// Level 0 (between groups), Level 1 (subgroups within), Level 2 (within subgroups)
		let data: NestedData<Double> = .group([
			.group([
				.observations([1, 2, 3]),
				.observations([4, 5, 6])
			]),
			.group([
				.observations([10, 11, 12]),
				.observations([13, 14, 15])
			]),
			.group([
				.observations([20, 21, 22]),
				.observations([23, 24, 25])
			])
		])

		let result = try multiLevelNestedANOVA(data)
		#expect(result.levels == 3)
		#expect(result.ssLevels.count == 3)
		#expect(result.msLevels.count == 3)
		#expect(result.dfLevels.count == 3)
		#expect(result.fStatistics.count == 2)  // one fewer than levels
		#expect(result.pValues.count == 2)
		#expect(result.varianceComponents.count == 3)
	}

	// MARK: - Test 16: Multi-Level SS Decomposition

	@Test("Multi-level SS decomposition sums to total SS")
	func testMultiLevelSSDecomposition() throws {
		let data: NestedData<Double> = .group([
			.group([
				.observations([2.3, 4.1, 3.5]),
				.observations([5.2, 6.0, 4.8])
			]),
			.group([
				.observations([8.1, 7.5, 9.0]),
				.observations([10.2, 11.0, 9.8])
			])
		])

		let result = try multiLevelNestedANOVA(data)
		let ssSum = result.ssLevels.reduce(0.0, +)

		// Compute total SS manually
		let allObs: [Double] = [2.3, 4.1, 3.5, 5.2, 6.0, 4.8, 8.1, 7.5, 9.0, 10.2, 11.0, 9.8]
		let grandMean = allObs.reduce(0.0, +) / Double(allObs.count)
		let ssTotal = allObs.map { ($0 - grandMean) * ($0 - grandMean) }.reduce(0.0, +)

		#expect(abs(ssSum - ssTotal) < 1e-8)
	}

	// MARK: - Test 17: Multi-Level df Decomposition

	@Test("Multi-level df decomposition sums to N-1")
	func testMultiLevelDfDecomposition() throws {
		let data: NestedData<Double> = .group([
			.group([
				.observations([1, 2, 3]),
				.observations([4, 5, 6])
			]),
			.group([
				.observations([10, 11, 12]),
				.observations([13, 14, 15])
			]),
			.group([
				.observations([20, 21, 22]),
				.observations([23, 24, 25])
			])
		])

		let result = try multiLevelNestedANOVA(data)
		let dfSum = result.dfLevels.reduce(0, +)
		// N = 18, so df total = 17
		#expect(dfSum == 17)
	}

	// MARK: - Test 18: Single Level Equivalent to One-Way ANOVA

	@Test("Single-level NestedData equivalent to one-way ANOVA")
	func testSingleLevelEquivalent() throws {
		// Two-level hierarchy: groups with observations
		// This should behave like one-way ANOVA
		let data: NestedData<Double> = .group([
			.observations([3.0, 4.0, 5.0]),
			.observations([6.0, 7.0, 8.0]),
			.observations([1.0, 2.0, 3.0])
		])

		let multiResult = try multiLevelNestedANOVA(data)

		// Compare with one-way ANOVA
		let groups: [[Double]] = [
			[3.0, 4.0, 5.0],
			[6.0, 7.0, 8.0],
			[1.0, 2.0, 3.0]
		]
		let oneWayResult = try oneWayANOVA(groups)

		#expect(multiResult.levels == 2)
		// SS between should match one-way ssBetween
		#expect(abs(multiResult.ssLevels[0] - oneWayResult.ssBetween) < 1e-8)
		// SS within should match one-way ssWithin
		#expect(abs(multiResult.ssLevels[1] - oneWayResult.ssWithin) < 1e-8)
	}

	// MARK: - Test 19: Four-Level Hierarchy

	@Test("Four-level hierarchy produces correct number of variance components")
	func testFourLevelHierarchy() throws {
		let data: NestedData<Double> = .group([
			.group([
				.group([
					.observations([1, 2]),
					.observations([3, 4])
				]),
				.group([
					.observations([5, 6]),
					.observations([7, 8])
				])
			]),
			.group([
				.group([
					.observations([10, 11]),
					.observations([12, 13])
				]),
				.group([
					.observations([14, 15]),
					.observations([16, 17])
				])
			])
		])

		let result = try multiLevelNestedANOVA(data)
		#expect(result.levels == 4)
		#expect(result.varianceComponents.count == 4)
		#expect(result.fStatistics.count == 3)
		#expect(result.pValues.count == 3)
		#expect(result.ssLevels.count == 4)
		#expect(result.dfLevels.count == 4)

		// SS decomposition
		let ssSum = result.ssLevels.reduce(0.0, +)
		let allObs: [Double] = [1,2,3,4,5,6,7,8,10,11,12,13,14,15,16,17]
		let grandMean = allObs.reduce(0.0, +) / Double(allObs.count)
		let ssTotal = allObs.map { ($0 - grandMean) * ($0 - grandMean) }.reduce(0.0, +)
		#expect(abs(ssSum - ssTotal) < 1e-8)

		// df decomposition: N-1 = 15
		let dfSum = result.dfLevels.reduce(0, +)
		#expect(dfSum == 15)

		// All variance components non-negative
		for vc in result.varianceComponents {
			#expect(vc >= 0)
		}
	}
}
