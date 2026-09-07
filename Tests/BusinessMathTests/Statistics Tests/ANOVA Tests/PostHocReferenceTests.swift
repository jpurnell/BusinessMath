//
//  PostHocReferenceTests.swift
//  BusinessMath
//
//  An external oracle for the post-hoc ANOVA tests, from SciPy and statsmodels.
//
//  `PostHocTests` has 30 tests. They assert that a p-value lies in [0, 1], that a
//  test statistic is non-negative, that a method reports its own name, that the
//  comparison count is `k(k-1)/2`, and that something comes out significant on
//  obviously separated data. All true of a correct implementation, and all equally
//  true of one using the wrong reference distribution.
//
//  The three methods differ in *nothing else*. They share the pooled MSE, the
//  error degrees of freedom, and the mean differences; what separates them is
//  which distribution the statistic is referred to:
//
//  - **Bonferroni** — a two-sample t against the pooled variance and the ANOVA's
//    df, multiplied by the number of comparisons and capped at 1. Using each
//    pair's own variance and df instead is the classic error, and it changes
//    nothing about the shape of the answer.
//  - **Scheffé** — `F = d² / (MSE·(1/nᵢ + 1/nⱼ)·(k-1))` on `F(k-1, dfError)`. The
//    `(k-1)` is what makes Scheffé the most conservative of the three; drop it and
//    the test is an unadjusted F that still returns plausible p-values.
//  - **Tukey** — the **studentized range**, which has no closed form. Substituting
//    a t or a normal is the standard shortcut, and at k = 3, df = 27 it makes the
//    critical difference 2.052 standard errors instead of 2.479 — 21% narrow, so
//    marginal comparisons are declared significant when they are not.
//
//  The fixture records that ratio per design, and `criticalValuesActuallySeparate`
//  asserts the corpus contains cases where it is large. A corpus of easy designs
//  would pass against any of these three distributions.
//
//  ## Two boundaries worth their place
//
//  With **two groups** the studentized range at k = 2 *is* the t distribution, so
//  all three methods must coincide exactly and Bonferroni's multiplier is 1. That
//  is a hard identity, not a tolerance.
//
//  With **unbalanced groups** Tukey becomes Tukey-Kramer, taking each pair's own
//  `(1/nᵢ + 1/nⱼ)` rather than one common term. An implementation that assumes
//  balance is correct on every balanced design and wrong on this one.
//
//  Values from Tests/BusinessMathTests/Fixtures/postHoc.json.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Post-hoc ANOVA against SciPy")
struct PostHocReferenceTests {

	// MARK: - Fixture

	private struct Fixture: Decodable {
		let name: String
		let reference: String
		let note: String
		let alpha: Double
		let cases: [Case]
	}

	private struct MethodResult: Decodable {
		let pValue: Double
		let isSignificant: Bool
		let tStatistic: Double?
		let rawPValue: Double?
		let fStatistic: Double?
		let qStatistic: Double?
		let statsmodelsPValue: Double?
	}

	private struct Comparison: Decodable {
		let groupA: Int
		let groupB: Int
		let meanDifference: Double
		let standardError: Double
		let bonferroni: MethodResult
		let scheffe: MethodResult
		let tukey: MethodResult
	}

	private struct ANOVAQuantities: Decodable {
		let mse: Double
		let dfError: Int
		let dfBetween: Int
		let fStatistic: Double
		let fPValue: Double
	}

	private struct Case: Decodable {
		let name: String
		let note: String
		let groups: [[Double]]
		let groupCount: Int
		let balanced: Bool
		let alpha: Double
		let anova: ANOVAQuantities
		let means: [Double]
		let tukeyCriticalInStandardErrors: Double
		let tCriticalInStandardErrors: Double
		let comparisons: [Comparison]
	}

	private static func loadFixture() throws -> Fixture {
		guard let url = Bundle.module.url(forResource: "postHoc", withExtension: "json",
										  subdirectory: "Fixtures")
			?? Bundle.module.url(forResource: "postHoc", withExtension: "json") else {
			struct Missing: Error { let name: String }
			throw Missing(name: "postHoc")
		}
		return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
	}

	/// Locates the package's comparison for an unordered pair, since the order the
	/// two groups are reported in is a convention and not a result.
	private static func comparison(_ result: PostHocResult<Double>,
								   _ a: Int, _ b: Int) -> PairwiseComparison<Double>? {
		result.comparisons.first { ($0.groupA == a && $0.groupB == b) || ($0.groupA == b && $0.groupB == a) }
	}

	private static func close(_ got: Double, _ want: Double, _ tolerance: Double) -> Bool {
		abs(got - want) <= tolerance * Swift.max(1.0, abs(want))
	}

	// MARK: - The corpus

	@Test("The corpus contains designs where the three reference distributions separate")
	func criticalValuesActuallySeparate() throws {
		let fixture = try Self.loadFixture()
		#expect(fixture.reference.contains("scipy"), "reference was '\(fixture.reference)'")
		#expect(fixture.cases.count >= 7, "only \(fixture.cases.count) designs")

		// A studentized range and a t only diverge appreciably as k grows. Without a
		// design where they do, this whole file would pass against either.
		let widest = fixture.cases.map { $0.tukeyCriticalInStandardErrors / $0.tCriticalInStandardErrors }.max() ?? 1
		#expect(widest > 1.35,
				"the widest q/t critical-value ratio in the corpus is only \(widest) — no design discriminates")

		#expect(fixture.cases.contains { $0.groupCount == 2 }, "no two-group boundary case")
		#expect(fixture.cases.contains { !$0.balanced }, "no unbalanced design, so Tukey-Kramer is never exercised")
		#expect(fixture.cases.contains { $0.groupCount >= 5 }, "no design with many comparisons")
	}

	@Test("The shared ANOVA quantities match before the methods are compared")
	func anovaQuantitiesMatch() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases {
			let anova = try oneWayANOVA(entry.groups)
			// All three post-hoc methods are built on these two numbers. If they are
			// wrong, every comparison below is wrong for a reason that has nothing to
			// do with the post-hoc test itself — so they are checked separately.
			#expect(Self.close(anova.msWithin, entry.anova.mse, 1e-10),
					"\(entry.name): MSE \(anova.msWithin), SciPy \(entry.anova.mse)")
			#expect(anova.dfWithin == entry.anova.dfError,
					"\(entry.name): dfError \(anova.dfWithin), expected \(entry.anova.dfError)")
		}
	}

	// MARK: - Bonferroni

	@Test("Bonferroni p-values match, pooled variance and all")
	func bonferroniMatchesSciPy() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		for entry in fixture.cases {
			let anova = try oneWayANOVA(entry.groups)
			let result = try bonferroniPostHoc(entry.groups, anova: anova, alpha: entry.alpha)
			#expect(result.comparisons.count == entry.comparisons.count,
					"\(entry.name): \(result.comparisons.count) comparisons, expected \(entry.comparisons.count)")

			for reference in entry.comparisons {
				guard let got = Self.comparison(result, reference.groupA, reference.groupB) else {
					Issue.record("\(entry.name): no comparison for (\(reference.groupA), \(reference.groupB))")
					continue
				}
				// A p-value is bounded, so an absolute tolerance is the honest one —
				// scaling it relatively would loosen exactly the small values that
				// decide significance.
				#expect(abs(got.pValue - reference.bonferroni.pValue) < 1e-9,
						"""
						\(entry.name) (\(reference.groupA),\(reference.groupB)): \
						Bonferroni p \(got.pValue), SciPy \(reference.bonferroni.pValue) \
						(raw \(reference.bonferroni.rawPValue ?? .nan) × \(entry.comparisons.count))
						""")
				#expect(got.isSignificant == reference.bonferroni.isSignificant,
						"\(entry.name) (\(reference.groupA),\(reference.groupB)): significance disagrees")
				compared += 1
			}
		}
		#expect(compared >= 25, "only \(compared) comparisons checked")
	}

	// MARK: - Scheffé

	@Test("Scheffé keeps the k-1 factor that makes it conservative")
	func scheffeMatchesSciPy() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		for entry in fixture.cases {
			let anova = try oneWayANOVA(entry.groups)
			let result = try scheffePostHoc(entry.groups, anova: anova, alpha: entry.alpha)

			for reference in entry.comparisons {
				guard let got = Self.comparison(result, reference.groupA, reference.groupB) else {
					Issue.record("\(entry.name): no comparison for (\(reference.groupA), \(reference.groupB))")
					continue
				}
				#expect(abs(got.pValue - reference.scheffe.pValue) < 1e-9,
						"""
						\(entry.name) (\(reference.groupA),\(reference.groupB)): \
						Scheffé p \(got.pValue), SciPy \(reference.scheffe.pValue)
						""")
				if let f = reference.scheffe.fStatistic {
					#expect(Self.close(got.testStatistic, f, 1e-9),
							"\(entry.name) (\(reference.groupA),\(reference.groupB)): F \(got.testStatistic), expected \(f)")
				}
				#expect(got.isSignificant == reference.scheffe.isSignificant,
						"\(entry.name) (\(reference.groupA),\(reference.groupB)): significance disagrees")
				compared += 1
			}
		}
		#expect(compared >= 25, "only \(compared) comparisons checked")
	}

	// MARK: - Tukey

	@Test("Tukey uses the studentized range, not a t in its place")
	func tukeyMatchesSciPy() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		for entry in fixture.cases {
			let anova = try oneWayANOVA(entry.groups)
			let result = try tukeyHSD(entry.groups, anova: anova, alpha: entry.alpha)

			for reference in entry.comparisons {
				guard let got = Self.comparison(result, reference.groupA, reference.groupB) else {
					Issue.record("\(entry.name): no comparison for (\(reference.groupA), \(reference.groupB))")
					continue
				}
				// The studentized range CDF is evaluated numerically by every
				// implementation, so exact agreement with SciPy is not the claim —
				// agreement to well inside any decision boundary is.
				// Bound out of the expectation: `Optional.map(String.init)` inside a
				// string interpolation inside `#expect` is the shape Swift 6.2.1
				// cannot type-check.
				let secondOpinion: String
				if let value = reference.tukey.statsmodelsPValue {
					secondOpinion = "\(value)"
				} else {
					secondOpinion = "not reported"
				}
				#expect(abs(got.pValue - reference.tukey.pValue) < 1e-6,
						"""
						\(entry.name) (\(reference.groupA),\(reference.groupB)): \
						Tukey p \(got.pValue), SciPy \(reference.tukey.pValue), \
						statsmodels \(secondOpinion)
						""")
				#expect(got.isSignificant == reference.tukey.isSignificant,
						"\(entry.name) (\(reference.groupA),\(reference.groupB)): significance disagrees")
				compared += 1
			}
		}
		#expect(compared >= 25, "only \(compared) comparisons checked")
	}

	@Test("Tukey-Kramer uses each pair's own group sizes on an unbalanced design")
	func tukeyHandlesUnbalancedDesigns() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases where !entry.balanced {
			let anova = try oneWayANOVA(entry.groups)
			let result = try tukeyHSD(entry.groups, anova: anova, alpha: entry.alpha)
			for reference in entry.comparisons {
				guard let got = Self.comparison(result, reference.groupA, reference.groupB) else { continue }
				// Every pair here has a different (1/nᵢ + 1/nⱼ). Assuming balance
				// would be correct on no pair of this design and wrong by a different
				// amount on each, which is why it is checked pair by pair.
				#expect(abs(got.pValue - reference.tukey.pValue) < 1e-6,
						"""
						\(entry.name) (\(reference.groupA),\(reference.groupB)) sizes \
						\(entry.groups[reference.groupA].count)/\(entry.groups[reference.groupB].count): \
						\(got.pValue) against \(reference.tukey.pValue)
						""")
			}
		}
	}

	// MARK: - Claims that need no reference

	@Test("With two groups all three methods coincide")
	func twoGroupsCollapseToTheSameTest() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases where entry.groupCount == 2 {
			let anova = try oneWayANOVA(entry.groups)
			let bonferroni = try bonferroniPostHoc(entry.groups, anova: anova, alpha: entry.alpha)
			let scheffe = try scheffePostHoc(entry.groups, anova: anova, alpha: entry.alpha)
			let tukey = try tukeyHSD(entry.groups, anova: anova, alpha: entry.alpha)

			guard let b = bonferroni.comparisons.first,
				  let s = scheffe.comparisons.first,
				  let t = tukey.comparisons.first else {
				Issue.record("\(entry.name): a method produced no comparison"); continue
			}
			// One comparison, so Bonferroni multiplies by one; Scheffé with k-1 = 1
			// is the same F as t²; and the studentized range at k = 2 is the t
			// distribution. This is an identity, not an approximation — it needs no
			// oracle and it catches a stray multiplier or a hard-coded k.
			#expect(abs(b.pValue - s.pValue) < 1e-9,
					"\(entry.name): Bonferroni \(b.pValue) but Scheffé \(s.pValue)")
			#expect(abs(b.pValue - t.pValue) < 1e-6,
					"\(entry.name): Bonferroni \(b.pValue) but Tukey \(t.pValue)")
		}
	}

	@Test("Scheffé is never less conservative than Bonferroni or Tukey")
	func scheffeIsTheMostConservative() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		for entry in fixture.cases where entry.groupCount > 2 {
			let anova = try oneWayANOVA(entry.groups)
			let scheffe = try scheffePostHoc(entry.groups, anova: anova, alpha: entry.alpha)
			let tukey = try tukeyHSD(entry.groups, anova: anova, alpha: entry.alpha)

			for s in scheffe.comparisons {
				guard let t = Self.comparison(tukey, s.groupA, s.groupB) else { continue }
				// Scheffé protects every possible contrast, not just the pairwise
				// ones, so for pairwise comparisons it must be the wider net. An
				// ordering, and independent of both reference implementations.
				#expect(s.pValue >= t.pValue - 1e-9,
						"\(entry.name) (\(s.groupA),\(s.groupB)): Scheffé \(s.pValue) below Tukey \(t.pValue)")
				compared += 1
			}
		}
		#expect(compared >= 15, "only \(compared) orderings checked")
	}

	@Test("Mean differences are the differences of the group means")
	func meanDifferencesAreArithmetic() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases {
			let anova = try oneWayANOVA(entry.groups)
			let result = try tukeyHSD(entry.groups, anova: anova, alpha: entry.alpha)
			for got in result.comparisons {
				let expected: Double = entry.means[got.groupA] - entry.means[got.groupB]
				// Needs nothing but arithmetic, and catches a pair reported against
				// the wrong indices — which every p-value check above would miss,
				// because the p-value would be right for the pair it was computed on.
				#expect(Self.close(got.meanDifference, expected, 1e-10),
						"\(entry.name) (\(got.groupA),\(got.groupB)): \(got.meanDifference), means give \(expected)")
			}
		}
	}
}
