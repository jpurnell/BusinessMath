//
//  ExcelBindableParityTests.swift
//  BusinessMathTests
//
//  The functions this package computes that no formula can reach — compared to a
//  spreadsheet for the first time.
//
//  The coverage matrix marks 86 Excel functions *bindable*: BusinessMath has the
//  quantity and nothing binds a name to it. That also means none of them had ever been
//  checked against an independent implementation, only against its own definition —
//  which is exactly how `DayCountConvention.thirty360` shipped for months missing the
//  NASD February rule, with a green suite the whole time.
//
//  Reference: LibreOffice Calc, via Scripts/reference-fixtures/generate_excel_bindable.py.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Excel parity — functions that were computed but never compared")
struct ExcelBindableParityTests {

	/// LibreOffice writes about fifteen significant digits.
	static let tolerance = 1e-12

	static let fixture: ReferenceFixture? = try? ReferenceFixture.load("excelBindable")

	static func cases(_ function: String) throws -> [[String: Double]] {
		let fixture = try #require(Self.fixture)
		let order = try #require(fixture.functionOrder)
		let index = try #require(order.firstIndex(of: function))
		return fixture.cases.filter { $0["function"] == Double(index) }
	}

	/// Anscombe I, read from the fixture rather than restated, so the two sides cannot
	/// drift apart.
	static func dataset() throws -> (x: [Double], y: [Double]) {
		let rows = try cases("DATASET").sorted { ($0["index"] ?? 0) < ($1["index"] ?? 0) }
		return (rows.map { $0["x"] ?? 0 }, rows.map { $0["y"] ?? 0 })
	}

	static func check(_ actual: Double, _ expected: Double, _ label: String,
					  tolerance: Double = tolerance,
					  sourceLocation: SourceLocation = #_sourceLocation) {
		let scale = Swift.max(abs(expected), 1.0)
		#expect(abs(actual - expected) / scale < tolerance,
			"\(label): ours \(actual), spreadsheet \(expected), relative \(abs(actual - expected) / scale)",
			sourceLocation: sourceLocation)
	}

	// MARK: - Distributions

	@Test("NORM.DIST and NORM.INV")
	func normal() throws {
		let normDist = try Self.cases("NORM.DIST")
		#expect(normDist.count == 5, "the fixture supplied \(normDist.count) NORM.DIST cases")
		for c in normDist {
			let actual: Double = normalCDF(x: c["x"] ?? 0, mean: c["mean"] ?? 0, stdDev: c["stdDev"] ?? 1)
			Self.check(actual, c["value"] ?? 0, "NORM.DIST(\(c["x"] ?? 0))")
		}
		let normInv = try Self.cases("NORM.INV")
		#expect(normInv.count == 5)
		for c in normInv {
			let actual: Double = inverseNormalCDF(p: c["p"] ?? 0, mean: c["mean"] ?? 0, stdDev: c["stdDev"] ?? 1)
			Self.check(actual, c["value"] ?? 0, "NORM.INV(\(c["p"] ?? 0))")
		}
	}

	@Test("T.DIST and T.INV")
	func studentT() throws {
		let tDist = try Self.cases("T.DIST")
		#expect(tDist.count == 12, "the fixture supplied \(tDist.count) T.DIST cases")
		for c in tDist {
			let actual: Double = try tCDF(t: c["x"] ?? 0, df: Int(c["df"] ?? 1))
			Self.check(actual, c["value"] ?? 0, "T.DIST(\(c["x"] ?? 0), df \(c["df"] ?? 0))")
		}
		let tInv = try Self.cases("T.INV")
		#expect(tInv.count == 12)
		for c in tInv {
			let actual: Double = try tQuantile(p: c["p"] ?? 0, df: Int(c["df"] ?? 1))
			Self.check(actual, c["value"] ?? 0, "T.INV(\(c["p"] ?? 0), df \(c["df"] ?? 0))")
		}
	}

	@Test("F.DIST and F.INV")
	func fDistribution() throws {
		let fDist = try Self.cases("F.DIST")
		#expect(fDist.count == 9, "the fixture supplied \(fDist.count) F.DIST cases")
		for c in fDist {
			let actual: Double = try fCDF(f: c["x"] ?? 0, df1: Int(c["df1"] ?? 1), df2: Int(c["df2"] ?? 1))
			Self.check(actual, c["value"] ?? 0, "F.DIST(\(c["x"] ?? 0))")
		}
		let fInv = try Self.cases("F.INV")
		#expect(fInv.count == 9)
		for c in fInv {
			let actual: Double = try fQuantile(p: c["p"] ?? 0, df1: Int(c["df1"] ?? 1), df2: Int(c["df2"] ?? 1))
			Self.check(actual, c["value"] ?? 0, "F.INV(\(c["p"] ?? 0))")
		}
	}

	@Test("CHISQ.DIST")
	func chiSquared() throws {
		let chi = try Self.cases("CHISQ.DIST")
		#expect(chi.count == 9, "the fixture supplied \(chi.count) CHISQ.DIST cases")
		for c in chi {
			let actual: Double = try chiSquaredCDF(x: c["x"] ?? 0, df: Int(c["df"] ?? 1))
			Self.check(actual, c["value"] ?? 0, "CHISQ.DIST(\(c["x"] ?? 0), df \(c["df"] ?? 0))")
		}
	}

	@Test("BETA.DIST")
	func beta() throws {
		let beta = try Self.cases("BETA.DIST")
		#expect(beta.count == 9, "the fixture supplied \(beta.count) BETA.DIST cases")
		for c in beta {
			let actual: Double = try betaCDF(x: c["x"] ?? 0, alpha: c["a"] ?? 1, beta: c["b"] ?? 1)
			Self.check(actual, c["value"] ?? 0, "BETA.DIST(\(c["x"] ?? 0); \(c["a"] ?? 0), \(c["b"] ?? 0))")
		}
	}

	@Test("BINOM.DIST, POISSON.DIST and HYPGEOM.DIST")
	func discreteDistributions() throws {
		let binom = try Self.cases("BINOM.DIST")
		#expect(binom.count == 4, "the fixture supplied \(binom.count) BINOM.DIST cases")
		for c in binom {
			let actual: Double = binomialPMF(n: Int(c["n"] ?? 0), k: Int(c["k"] ?? 0), p: c["p"] ?? 0)
			Self.check(actual, c["value"] ?? 0, "BINOM.DIST(\(c["k"] ?? 0) of \(c["n"] ?? 0))")
		}
		let poisson = try Self.cases("POISSON.DIST")
		#expect(poisson.count == 3)
		for c in poisson {
			let actual: Double = poissonCDF(c["k"] ?? 0, µ: c["mean"] ?? 1)
			Self.check(actual, c["value"] ?? 0, "POISSON.DIST(\(c["k"] ?? 0), mean \(c["mean"] ?? 0))")
		}
		let hyper = try Self.cases("HYPGEOM.DIST")
		#expect(hyper.count == 3)
		for c in hyper {
			let actual: Double = hypergeometric(
				total: Int(c["population"] ?? 0), r: Int(c["successes"] ?? 0),
				n: Int(c["draws"] ?? 0), x: Int(c["x"] ?? 0))
			Self.check(actual, c["value"] ?? 0, "HYPGEOM.DIST(\(c["x"] ?? 0))")
		}
	}

	@Test("LOGNORM.DIST, EXPON.DIST and FISHER")
	func remainingDistributions() throws {
		let logNormal = try Self.cases("LOGNORM.DIST")
		#expect(logNormal.count == 3, "the fixture supplied \(logNormal.count) LOGNORM.DIST cases")
		for c in logNormal {
			let actual: Double = logNormalCDF(c["x"] ?? 0, mean: c["mean"] ?? 0, stdDev: c["stdDev"] ?? 1)
			Self.check(actual, c["value"] ?? 0, "LOGNORM.DIST(\(c["x"] ?? 0))")
		}
		let exponential = try Self.cases("EXPON.DIST")
		#expect(exponential.count == 3)
		for c in exponential {
			let actual: Double = exponentialCDF(c["x"] ?? 0, λ: c["lambda"] ?? 1)
			Self.check(actual, c["value"] ?? 0, "EXPON.DIST(\(c["x"] ?? 0))")
		}
		let fisherCases = try Self.cases("FISHER")
		#expect(fisherCases.count == 5)
		for c in fisherCases {
			let actual: Double = try fisher(c["x"] ?? 0)
			Self.check(actual, c["value"] ?? 0, "FISHER(\(c["x"] ?? 0))")
		}
	}

	// MARK: - Descriptive statistics and regression

	@Test("Correlation, regression and the dotted dispersion family")
	func descriptiveStatistics() throws {
		let (x, y) = try Self.dataset()
		#expect(x.count == 10 && y.count == 10,
			"the dataset travelled with the fixture as \(x.count) points")

		Self.check(try correlationCoefficient(x, y),
				   try Self.cases("CORREL")[0]["value"] ?? 0, "CORREL")
		Self.check(try slope(x, y), try Self.cases("SLOPE")[0]["value"] ?? 0, "SLOPE")
		Self.check(try intercept(x, y), try Self.cases("INTERCEPT")[0]["value"] ?? 0, "INTERCEPT")

		Self.check(mean(x), try Self.cases("AVERAGE")[0]["value"] ?? 0, "AVERAGE")
		Self.check(median(x), try Self.cases("MEDIAN")[0]["value"] ?? 0, "MEDIAN")
		Self.check(geometricMean(x), try Self.cases("GEOMEAN")[0]["value"] ?? 0, "GEOMEAN")
		Self.check(try harmonicMean(x), try Self.cases("HARMEAN")[0]["value"] ?? 0, "HARMEAN")

		Self.check(stdDevS(x), try Self.cases("STDEV.S")[0]["value"] ?? 0, "STDEV.S")
		Self.check(stdDevP(x), try Self.cases("STDEV.P")[0]["value"] ?? 0, "STDEV.P")
		Self.check(variance(x, .sample), try Self.cases("VAR.S")[0]["value"] ?? 0, "VAR.S")
		Self.check(varianceP(x), try Self.cases("VAR.P")[0]["value"] ?? 0, "VAR.P")

		Self.check(covariance(x, y, .population),
				   try Self.cases("COVARIANCE.P")[0]["value"] ?? 0, "COVARIANCE.P")
		Self.check(covariance(x, y, .sample),
				   try Self.cases("COVARIANCE.S")[0]["value"] ?? 0, "COVARIANCE.S")

		Self.check(skew(x, .sample), try Self.cases("SKEW")[0]["value"] ?? 0, "SKEW")
		Self.check(kurtosis(x, .sample), try Self.cases("KURT")[0]["value"] ?? 0, "KURT")
	}

	@Test("PERCENTILE.INC")
	func percentiles() throws {
		let (x, _) = try Self.dataset()
		let sorted = x.sorted()
		let percentileCases = try Self.cases("PERCENTILE.INC")
		#expect(percentileCases.count == 5, "the fixture supplied \(percentileCases.count) PERCENTILE.INC cases")
		for c in percentileCases {
			let actual: Double = quantile(sorted: sorted, p: c["p"] ?? 0)
			Self.check(actual, c["value"] ?? 0, "PERCENTILE.INC(\(c["p"] ?? 0))")
		}
	}

	// MARK: - Prediction, ranking and confidence

	@Test("TREND, GROWTH and the two fits")
	func predictionMatchesReference() throws {
		let (x, y) = try Self.dataset()

		let trendCases = try Self.cases("TREND")
		#expect(trendCases.count == 3, "the fixture supplied \(trendCases.count) TREND cases")
		for c in trendCases {
			let actual = try linearForecast(at: c["x"] ?? 0, knownX: x, knownY: y)
			Self.check(actual, c["value"] ?? 0, "TREND(\(c["x"] ?? 0))")
		}

		let growthCases = try Self.cases("GROWTH")
		#expect(growthCases.count == 3)
		for c in growthCases {
			let actual = try exponentialForecast(at: c["x"] ?? 0, knownX: x, knownY: y)
			Self.check(actual, c["value"] ?? 0, "GROWTH(\(c["x"] ?? 0))")
		}

		// LOGEST returns the exponential fit's two coefficients, y = b·mˣ.
		let fit = try exponentialFit(knownX: x, knownY: y)
		Self.check(fit.base, try Self.cases("LOGEST.BASE")[0]["value"] ?? 0, "LOGEST base")
		Self.check(fit.coefficient,
				   try Self.cases("LOGEST.COEFFICIENT")[0]["value"] ?? 0, "LOGEST coefficient")

		// LINEST's first two outputs are the slope and intercept already verified through
		// SLOPE and INTERCEPT — checked again here because LINEST is the name a formula
		// reaches them by, and a binding could plausibly wire it to the wrong pair.
		Self.check(try slope(x, y),
				   try Self.cases("LINEST.SLOPE")[0]["value"] ?? 0, "LINEST slope")
		Self.check(try intercept(x, y),
				   try Self.cases("LINEST.INTERCEPT")[0]["value"] ?? 0, "LINEST intercept")
	}

	@Test("CONFIDENCE.NORM")
	func confidenceMatchesReference() throws {
		let cases = try Self.cases("CONFIDENCE.NORM")
		#expect(cases.count == 3)
		for c in cases {
			// Excel returns the half-width; this package returns the interval, so the
			// comparison takes half its span. Same quantity, stated differently.
			let alpha = c["alpha"] ?? 0.05
			let interval: (low: Double, high: Double) =
				confidence(alpha: alpha, stdev: 3.2041639575198, sampleSize: 10)
			let halfWidth = (interval.high - interval.low) / 2
			Self.check(halfWidth, c["value"] ?? 0, "CONFIDENCE.NORM(\(alpha))")
		}
	}

	@Test("RANK.EQ, RANK.AVG and PERCENTRANK.INC")
	func rankingMatchesReference() throws {
		let (x, _) = try Self.dataset()

		// Excel ranks *descending* by default: the largest value is rank 1. That is the
		// opposite of what "rank 1" suggests to most readers, so both orders are checked.
		let descending = try Self.cases("RANK.EQ")
		#expect(descending.count == 5, "the fixture supplied \(descending.count) RANK.EQ cases")
		for c in descending {
			let actual = try rank(c["at"] ?? 0, in: x)
			Self.check(actual, c["value"] ?? 0, "RANK.EQ(\(c["at"] ?? 0))")
		}

		for c in try Self.cases("RANK.EQ.ASC") {
			let actual = try rank(c["at"] ?? 0, in: x, ascending: true)
			Self.check(actual, c["value"] ?? 0, "RANK.EQ ascending(\(c["at"] ?? 0))")
		}

		// Anscombe I has no ties, so RANK.AVG must agree with RANK.EQ here. The tie
		// behaviour that distinguishes them is exercised separately below, where a
		// spreadsheet is not needed to know the answer.
		for c in try Self.cases("RANK.AVG") {
			let actual = try rank(c["at"] ?? 0, in: x, ties: .averageOfTied)
			Self.check(actual, c["value"] ?? 0, "RANK.AVG(\(c["at"] ?? 0))")
		}

		let percentRanks = try Self.cases("PERCENTRANK.INC")
		#expect(percentRanks.count == 5)
		for c in percentRanks {
			let actual = try percentRank(c["at"] ?? 0, in: x)
			Self.check(actual, c["value"] ?? 0, "PERCENTRANK.INC(\(c["at"] ?? 0))")
		}
	}

	@Test("Ties separate RANK.EQ from RANK.AVG")
	func rankTiesBehaveAsExcelDocuments() throws {
		// Three values tied at 20, in a set of five. Descending, they occupy ranks 2, 3
		// and 4. RANK.EQ gives them all the best of those; RANK.AVG gives them the
		// average. Derived from the definition — no spreadsheet needed, and the fixture's
		// dataset has no ties to exercise it with.
		let values: [Double] = [30, 20, 20, 20, 10]
		#expect(try rank(30, in: values).isEqual(to: 1))
		#expect(try rank(20, in: values, ties: .highestOfTied).isEqual(to: 2))
		#expect(try rank(20, in: values, ties: .averageOfTied).isEqual(to: 3))
		#expect(try rank(10, in: values).isEqual(to: 5))

		// And a value that is not in the set is refused rather than guessed at — Excel
		// reports #N/A.
		#expect(throws: (any Error).self) { _ = try rank(25, in: values) }
	}

	@Test("PERCENTRANK reduces to three significant digits, as the spreadsheet does")
	func percentRankTruncation() throws {
		let (x, _) = try Self.dataset()
		// 7 is third-lowest of ten, so the exact rank is 2/9 = 0.2222…, returned as
		// 0.222. Eleven is seventh, 6/9 = 0.6666…, returned as 0.667 — rounded rather
		// than truncated, which is measured rather than assumed: truncation would give
		// 0.666, and the spreadsheet does not.
		#expect(try percentRank(7, in: x).isEqual(to: 0.222))
		#expect(try percentRank(11, in: x).isEqual(to: 0.667))
		#expect(try percentRank(10, in: x).isEqual(to: 0.556),
			"5/9 rounds to 0.556; truncation would give 0.555")
		// Asking for more digits gives them, so the truncation is Excel's default rather
		// than a limit of the calculation.
		let exact = try percentRank(11, in: x, significantDigits: 12)
		#expect(abs(exact - 6.0 / 9.0) < 1e-12, "got \(exact)")
	}

	@Test("STANDARDIZE")
	func standardizeMatchesReference() throws {
		let cases = try Self.cases("STANDARDIZE")
		#expect(cases.count == 1)
		let c = cases[0]
		let actual = try standardize(c["x"] ?? 0, mean: c["mean"] ?? 0, stdDev: c["stdDev"] ?? 1)
		Self.check(actual, c["value"] ?? 0, "STANDARDIZE")

		// A zero or negative spread has no z-score to give, and returning one anyway
		// would be an infinity flowing into whatever asked.
		#expect(throws: (any Error).self) { _ = try standardize(11.0, mean: 10, stdDev: 0) }
		#expect(throws: (any Error).self) { _ = try standardize(11.0, mean: 10, stdDev: -1) }
	}
}
