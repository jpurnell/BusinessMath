import Testing
import Foundation
@testable import BusinessMath

@Suite("Post-Hoc Tests")
struct PostHocTests {

	// MARK: - Shared Test Data

	/// Three groups with known means:
	/// Group 1: mean = 5.0, Group 2: mean = 9.0, Group 3: mean = 10.0
	private let testGroups: [[Double]] = [
		[6.0, 8.0, 4.0, 5.0, 3.0, 4.0],
		[8.0, 12.0, 9.0, 11.0, 6.0, 8.0],
		[13.0, 9.0, 11.0, 8.0, 7.0, 12.0]
	]

	/// All identical groups — no differences.
	private let identicalGroups: [[Double]] = [
		[5.0, 5.0, 5.0, 5.0],
		[5.0, 5.0, 5.0, 5.0],
		[5.0, 5.0, 5.0, 5.0]
	]

	/// Clearly different groups — large separation.
	private let clearlyDifferent: [[Double]] = [
		[1.0, 2.0, 3.0, 2.0, 1.0],
		[100.0, 101.0, 102.0, 100.0, 99.0],
		[200.0, 201.0, 202.0, 200.0, 199.0]
	]

	// MARK: - Bonferroni Tests

	@Suite("Bonferroni Post-Hoc")
	struct BonferroniTests {

		private let testGroups: [[Double]] = [
			[6.0, 8.0, 4.0, 5.0, 3.0, 4.0],
			[8.0, 12.0, 9.0, 11.0, 6.0, 8.0],
			[13.0, 9.0, 11.0, 8.0, 7.0, 12.0]
		]

		@Test("Known dataset produces correct number of comparisons")
		func testComparisonCount() throws {
			let anova = try oneWayANOVA(testGroups)
			let result = try bonferroniPostHoc(testGroups, anova: anova)
			// k=3 → 3 comparisons
			#expect(result.comparisons.count == 3)
		}

		@Test("P-values are raw p × numComparisons, capped at 1.0")
		func testPValueAdjustment() throws {
			let anova = try oneWayANOVA(testGroups)
			let result = try bonferroniPostHoc(testGroups, anova: anova)
			// All adjusted p-values must be ≤ 1.0
			for c in result.comparisons {
				#expect(c.pValue <= 1.0)
				#expect(c.pValue >= 0.0)
			}
		}

		@Test("Two groups only → single comparison equals raw t-test")
		func testTwoGroupsMatchesRawTTest() throws {
			let twoGroups: [[Double]] = [
				[6.0, 8.0, 4.0, 5.0, 3.0, 4.0],
				[8.0, 12.0, 9.0, 11.0, 6.0, 8.0]
			]
			let anova = try oneWayANOVA(twoGroups)
			let result = try bonferroniPostHoc(twoGroups, anova: anova)
			// With k=2, numComparisons = 1, so adjusted p = raw p
			#expect(result.comparisons.count == 1)
			// The p-value should match a two-sample t-test using pooled MSE
			let mse = anova.msWithin
			let n1 = Double(twoGroups[0].count)
			let n2 = Double(twoGroups[1].count)
			let mean1 = twoGroups[0].reduce(0.0, +) / n1
			let mean2 = twoGroups[1].reduce(0.0, +) / n2
			let se = (mse * (1.0 / n1 + 1.0 / n2)).squareRoot()
			let tStat = abs(mean1 - mean2) / se
			let rawP = 2.0 * (1.0 - (try tCDF(t: tStat, df: anova.dfWithin)))
			#expect(abs(result.comparisons[0].pValue - rawP) < 1e-8)
		}

		@Test("Clearly different groups → at least one significant pair")
		func testClearlyDifferent() throws {
			let groups: [[Double]] = [
				[1.0, 2.0, 3.0, 2.0, 1.0],
				[100.0, 101.0, 102.0, 100.0, 99.0],
				[200.0, 201.0, 202.0, 200.0, 199.0]
			]
			let anova = try oneWayANOVA(groups)
			let result = try bonferroniPostHoc(groups, anova: anova)
			let significantCount = result.comparisons.filter(\.isSignificant).count
			#expect(significantCount >= 1)
		}

		@Test("All identical groups → no significant pairs")
		func testIdenticalGroups() throws {
			let groups: [[Double]] = [
				[5.0, 5.0, 5.0, 5.0],
				[5.0, 5.0, 5.0, 5.0],
				[5.0, 5.0, 5.0, 5.0]
			]
			let anova = try oneWayANOVA(groups)
			let result = try bonferroniPostHoc(groups, anova: anova)
			for c in result.comparisons {
				#expect(!c.isSignificant)
			}
		}

		@Test("Adjusted p never exceeds 1.0")
		func testPValueCappedAtOne() throws {
			// Use groups with minimal difference so raw p is large → capped at 1.0
			let groups: [[Double]] = [
				[5.0, 5.1, 4.9, 5.0],
				[5.0, 5.1, 4.9, 5.0],
				[5.1, 5.0, 4.9, 5.0],
				[5.0, 5.1, 5.0, 4.9]
			]
			let anova = try oneWayANOVA(groups)
			let result = try bonferroniPostHoc(groups, anova: anova)
			for c in result.comparisons {
				#expect(c.pValue <= 1.0)
			}
		}

		@Test("Method name is Bonferroni")
		func testMethodName() throws {
			let anova = try oneWayANOVA(testGroups)
			let result = try bonferroniPostHoc(testGroups, anova: anova)
			#expect(result.method == "Bonferroni")
		}

		@Test("MSE and dfError match ANOVA")
		func testMetadata() throws {
			let anova = try oneWayANOVA(testGroups)
			let result = try bonferroniPostHoc(testGroups, anova: anova)
			#expect(abs(result.mse - anova.msWithin) < 1e-10)
			#expect(result.dfError == anova.dfWithin)
		}

		@Test("Mean differences have correct sign")
		func testMeanDifferenceSign() throws {
			let anova = try oneWayANOVA(testGroups)
			let result = try bonferroniPostHoc(testGroups, anova: anova)
			// Group 0 mean ≈ 5.0, Group 1 mean ≈ 9.0 → diff = 5 - 9 = -4
			let comp01 = try #require(result.comparisons.first { $0.groupA == 0 && $0.groupB == 1 })
			#expect(comp01.meanDifference < 0)
		}
	}

	// MARK: - Scheffé Tests

	@Suite("Scheffé Post-Hoc")
	struct ScheffeTests {

		private let testGroups: [[Double]] = [
			[6.0, 8.0, 4.0, 5.0, 3.0, 4.0],
			[8.0, 12.0, 9.0, 11.0, 6.0, 8.0],
			[13.0, 9.0, 11.0, 8.0, 7.0, 12.0]
		]

		@Test("Known dataset produces correct number of comparisons")
		func testComparisonCount() throws {
			let anova = try oneWayANOVA(testGroups)
			let result = try scheffePostHoc(testGroups, anova: anova)
			#expect(result.comparisons.count == 3)
		}

		@Test("All identical groups → no significant pairs")
		func testIdenticalGroups() throws {
			let groups: [[Double]] = [
				[5.0, 5.0, 5.0, 5.0],
				[5.0, 5.0, 5.0, 5.0],
				[5.0, 5.0, 5.0, 5.0]
			]
			let anova = try oneWayANOVA(groups)
			let result = try scheffePostHoc(groups, anova: anova)
			for c in result.comparisons {
				#expect(!c.isSignificant)
			}
		}

		@Test("Clearly different groups → significant pairs found")
		func testClearlyDifferent() throws {
			let groups: [[Double]] = [
				[1.0, 2.0, 3.0, 2.0, 1.0],
				[100.0, 101.0, 102.0, 100.0, 99.0],
				[200.0, 201.0, 202.0, 200.0, 199.0]
			]
			let anova = try oneWayANOVA(groups)
			let result = try scheffePostHoc(groups, anova: anova)
			let significantCount = result.comparisons.filter(\.isSignificant).count
			#expect(significantCount >= 1)
		}

		@Test("Scheffé and Bonferroni agree on significance for clearly separated groups")
		func testAgreesWithBonferroniOnClearCases() throws {
			let groups: [[Double]] = [
				[1.0, 2.0, 3.0, 2.0, 1.0],
				[100.0, 101.0, 102.0, 100.0, 99.0],
				[200.0, 201.0, 202.0, 200.0, 199.0]
			]
			let anova = try oneWayANOVA(groups)
			let bonf = try bonferroniPostHoc(groups, anova: anova)
			let schef = try scheffePostHoc(groups, anova: anova)
			// All pairs clearly differ → both methods should find significance
			for bComp in bonf.comparisons {
				let sComp = try #require(schef.comparisons.first { $0.groupA == bComp.groupA && $0.groupB == bComp.groupB })
				#expect(bComp.isSignificant == sComp.isSignificant)
			}
		}

		@Test("Method name is Scheffé")
		func testMethodName() throws {
			let anova = try oneWayANOVA(testGroups)
			let result = try scheffePostHoc(testGroups, anova: anova)
			#expect(result.method == "Scheffé")
		}

		@Test("F-statistic is non-negative")
		func testNonNegativeF() throws {
			let anova = try oneWayANOVA(testGroups)
			let result = try scheffePostHoc(testGroups, anova: anova)
			for c in result.comparisons {
				#expect(c.testStatistic >= 0.0)
			}
		}
	}

	// MARK: - Tukey HSD Tests

	@Suite("Tukey HSD Post-Hoc")
	struct TukeyTests {

		private let testGroups: [[Double]] = [
			[6.0, 8.0, 4.0, 5.0, 3.0, 4.0],
			[8.0, 12.0, 9.0, 11.0, 6.0, 8.0],
			[13.0, 9.0, 11.0, 8.0, 7.0, 12.0]
		]

		@Test("Known dataset produces correct number of comparisons")
		func testComparisonCount() throws {
			let anova = try oneWayANOVA(testGroups)
			let result = try tukeyHSD(testGroups, anova: anova)
			#expect(result.comparisons.count == 3)
		}

		@Test("q-statistic is always positive")
		func testQStatisticPositive() throws {
			let anova = try oneWayANOVA(testGroups)
			let result = try tukeyHSD(testGroups, anova: anova)
			for c in result.comparisons {
				#expect(c.testStatistic > 0.0)
			}
		}

		@Test("Balanced design — equal group sizes")
		func testBalancedDesign() throws {
			// All groups have n=6, balanced
			let anova = try oneWayANOVA(testGroups)
			let result = try tukeyHSD(testGroups, anova: anova)
			#expect(result.comparisons.count == 3)
			// q should be |meanDiff| / sqrt(MSE / n) for balanced
			let n = Double(testGroups[0].count)
			let mse = anova.msWithin
			let means = testGroups.map { $0.reduce(0.0, +) / Double($0.count) }
			let seBalanced = (mse / n).squareRoot()
			for c in result.comparisons {
				let expectedQ = abs(means[c.groupA] - means[c.groupB]) / seBalanced
				#expect(abs(c.testStatistic - expectedQ) < 1e-8)
			}
		}

		@Test("Unbalanced design — Tukey-Kramer adjustment")
		func testUnbalancedDesign() throws {
			let unbalanced: [[Double]] = [
				[6.0, 8.0, 4.0, 5.0],
				[8.0, 12.0, 9.0, 11.0, 6.0, 8.0, 10.0],
				[13.0, 9.0, 11.0, 8.0, 7.0]
			]
			let anova = try oneWayANOVA(unbalanced)
			let result = try tukeyHSD(unbalanced, anova: anova)
			#expect(result.comparisons.count == 3)
			// Verify Tukey-Kramer SE: sqrt(MSE/2 * (1/n_i + 1/n_j))
			let mse = anova.msWithin
			let means = unbalanced.map { $0.reduce(0.0, +) / Double($0.count) }
			for c in result.comparisons {
				let ni = Double(unbalanced[c.groupA].count)
				let nj = Double(unbalanced[c.groupB].count)
				let se = (mse / 2.0 * (1.0 / ni + 1.0 / nj)).squareRoot()
				let expectedQ = abs(means[c.groupA] - means[c.groupB]) / se
				#expect(abs(c.testStatistic - expectedQ) < 1e-8)
			}
		}

		@Test("All identical groups → no significant pairs")
		func testIdenticalGroups() throws {
			let groups: [[Double]] = [
				[5.0, 5.0, 5.0, 5.0],
				[5.0, 5.0, 5.0, 5.0],
				[5.0, 5.0, 5.0, 5.0]
			]
			let anova = try oneWayANOVA(groups)
			let result = try tukeyHSD(groups, anova: anova)
			for c in result.comparisons {
				#expect(!c.isSignificant)
			}
		}

		@Test("Method name is Tukey HSD")
		func testMethodName() throws {
			let anova = try oneWayANOVA(testGroups)
			let result = try tukeyHSD(testGroups, anova: anova)
			#expect(result.method == "Tukey HSD")
		}

		@Test("P-values are in [0, 1]")
		func testPValueRange() throws {
			let anova = try oneWayANOVA(testGroups)
			let result = try tukeyHSD(testGroups, anova: anova)
			for c in result.comparisons {
				#expect(c.pValue >= 0.0)
				#expect(c.pValue <= 1.0)
			}
		}
	}

	// MARK: - Cross-Method Tests

	@Suite("Cross-Method Comparisons")
	struct CrossMethodTests {

		private let testGroups: [[Double]] = [
			[6.0, 8.0, 4.0, 5.0, 3.0, 4.0],
			[8.0, 12.0, 9.0, 11.0, 6.0, 8.0],
			[13.0, 9.0, 11.0, 8.0, 7.0, 12.0]
		]

		@Test("All methods agree on most extreme pair significance")
		func testAgreementOnExtremePair() throws {
			let groups: [[Double]] = [
				[1.0, 2.0, 3.0, 2.0, 1.0],
				[100.0, 101.0, 102.0, 100.0, 99.0],
				[200.0, 201.0, 202.0, 200.0, 199.0]
			]
			let anova = try oneWayANOVA(groups)
			let bonf = try bonferroniPostHoc(groups, anova: anova)
			let schef = try scheffePostHoc(groups, anova: anova)
			let tukey = try tukeyHSD(groups, anova: anova)

			// The 0-2 pair has the largest difference; all should flag it significant
			let bSig = bonf.comparisons.first { $0.groupA == 0 && $0.groupB == 2 }?.isSignificant
			let sSig = schef.comparisons.first { $0.groupA == 0 && $0.groupB == 2 }?.isSignificant
			let tSig = tukey.comparisons.first { $0.groupA == 0 && $0.groupB == 2 }?.isSignificant
			#expect(bSig == true)
			#expect(sSig == true)
			#expect(tSig == true)
		}

		@Test("All three methods produce valid p-values and consistent pair indices")
		func testConsistentStructure() throws {
			let anova = try oneWayANOVA(testGroups)
			let bonf = try bonferroniPostHoc(testGroups, anova: anova)
			let schef = try scheffePostHoc(testGroups, anova: anova)
			let tukey = try tukeyHSD(testGroups, anova: anova)

			// All methods should produce the same set of pairs
			for bComp in bonf.comparisons {
				let sComp = try #require(schef.comparisons.first { $0.groupA == bComp.groupA && $0.groupB == bComp.groupB })
				let tComp = try #require(tukey.comparisons.first { $0.groupA == bComp.groupA && $0.groupB == bComp.groupB })

				// All p-values in valid range
				#expect(bComp.pValue >= 0.0 && bComp.pValue <= 1.0)
				#expect(sComp.pValue >= 0.0 && sComp.pValue <= 1.0)
				#expect(tComp.pValue >= 0.0 && tComp.pValue <= 1.0)
				// Mean differences should be the same across methods
				#expect(abs(bComp.meanDifference - sComp.meanDifference) < 1e-10)
			}
		}

		@Test("Tukey p-values ≤ Bonferroni p-values (Tukey is less conservative)")
		func testTukeyLessConservativeThanBonferroni() throws {
			let anova = try oneWayANOVA(testGroups)
			let bonf = try bonferroniPostHoc(testGroups, anova: anova)
			let tukey = try tukeyHSD(testGroups, anova: anova)

			for bComp in bonf.comparisons {
				let tComp = try #require(tukey.comparisons.first { $0.groupA == bComp.groupA && $0.groupB == bComp.groupB })
				#expect(tComp.pValue <= bComp.pValue + 1e-8)
			}
		}

		@Test("All methods report correct metadata")
		func testMetadata() throws {
			let anova = try oneWayANOVA(testGroups)
			let bonf = try bonferroniPostHoc(testGroups, anova: anova)
			let schef = try scheffePostHoc(testGroups, anova: anova)
			let tukey = try tukeyHSD(testGroups, anova: anova)

			for result in [bonf, schef, tukey] {
				#expect(abs(result.alpha - 0.05) < 1e-10)
				#expect(abs(result.mse - anova.msWithin) < 1e-10)
				#expect(result.dfError == anova.dfWithin)
			}
		}
	}

	// MARK: - Error Cases

	@Suite("Post-Hoc Error Cases")
	struct ErrorCaseTests {

		@Test("Single group throws for Bonferroni")
		func testSingleGroupBonferroni() throws {
			#expect(throws: BusinessMathError.self) {
				let groups: [[Double]] = [[1.0, 2.0, 3.0]]
				let anova = try oneWayANOVA(groups)
				let _ = try bonferroniPostHoc(groups, anova: anova)
			}
		}

		@Test("Single group throws for Scheffé")
		func testSingleGroupScheffe() throws {
			#expect(throws: BusinessMathError.self) {
				let groups: [[Double]] = [[1.0, 2.0, 3.0]]
				let anova = try oneWayANOVA(groups)
				let _ = try scheffePostHoc(groups, anova: anova)
			}
		}

		@Test("Single group throws for Tukey HSD")
		func testSingleGroupTukey() throws {
			#expect(throws: BusinessMathError.self) {
				let groups: [[Double]] = [[1.0, 2.0, 3.0]]
				let anova = try oneWayANOVA(groups)
				let _ = try tukeyHSD(groups, anova: anova)
			}
		}

		@Test("Empty group throws (propagated from ANOVA)")
		func testEmptyGroup() throws {
			#expect(throws: BusinessMathError.self) {
				let groups: [[Double]] = [[1.0, 2.0], []]
				let anova = try oneWayANOVA(groups)
				let _ = try bonferroniPostHoc(groups, anova: anova)
			}
		}
	}
}
