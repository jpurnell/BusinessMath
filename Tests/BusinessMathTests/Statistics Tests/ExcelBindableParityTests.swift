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
}
