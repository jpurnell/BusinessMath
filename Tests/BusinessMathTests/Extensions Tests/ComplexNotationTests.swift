//
//  ComplexNotationTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 9/9/26.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Tests for the `Complex` ↔ `String` codec in conventional `a+bi` notation.
///
/// The round-trip property is the whole test: for every special case the writer
/// has a convention for, `Complex(notation: z.notation) == z`. The rejection
/// cases are named individually because a parser's failures matter more than its
/// successes — a permissive parser returns a plausible wrong answer, which is the
/// one outcome this package refuses.
@Suite("Complex Notation")
struct ComplexNotationTests {

	// MARK: - The reader refuses anything it cannot read exactly

	@Test(
		"Malformed notation parses to nil",
		arguments: [
			"3+4",			// a missing suffix is not an implied one
			"3+4k",			// k is not an imaginary unit
			"i3",			// the suffix trails the coefficient, never leads it
			"3i+4i",		// two imaginary terms
			"",				// nothing at all
			"+",			// a sign with no number
			"(3.0, 4.0)",	// the coordinate form, rejected deliberately
			"(3.0,4.0)",	// and without the space
			"3 4i",			// whitespace where an operator belongs
			"i+3",			// the imaginary term does not lead
			"--3i",			// a doubled sign
			"3++4i",		// likewise, between terms
			"3ii",			// a doubled suffix
			"3+i4",			// the suffix leads again, in the second term
			"3+",			// an operator with no second term
			"4i5"			// digits after the suffix
		]
	)
	func rejectsMalformedNotation(_ text: String) {
		let parsed = Complex<Double>(notation: text)
		#expect(parsed == nil, "\(text) is not complex notation")
	}

	// MARK: - The reader accepts what the writer emits, plus the tolerable variations

	@Test("The reader accepts the forms a person writes")
	func readsWrittenForms() throws {
		let cases: [(text: String, real: Double, imaginary: Double)] = [
			("3+4i", 3, 4),
			("3-4i", 3, -4),
			("i", 0, 1),
			("-i", 0, -1),
			("+i", 0, 1),
			("5", 5, 0),
			("3i", 0, 3),
			("0", 0, 0),
			("-2.5i", 0, -2.5),
			("+3+4i", 3, 4),
			("3 + 4i", 3, 4),
			("3 - 4i", 3, -4),
			("  3+4i  ", 3, 4),
			("3+4j", 3, 4),
			("3+4J", 3, 4),
			("3+4I", 3, 4),
			("3-j", 3, -1),
			("3e-4-5i", 3e-4, -5),
			("3e+4i", 0, 3e4)
		]
		for testCase in cases {
			let z = try #require(Complex<Double>(notation: testCase.text), "\(testCase.text) should parse")
			let realMatches = z.real.isEqual(to: testCase.real)
			#expect(realMatches, "real part of \(testCase.text)")
			let imaginaryMatches = z.imaginary.isEqual(to: testCase.imaginary)
			#expect(imaginaryMatches, "imaginary part of \(testCase.text)")
		}
	}

	// MARK: - The writer's conventions, one row of the table each

	@Test("A default value writes both parts")
	func writesBothParts() {
		let text = Complex<Double>(3, 4).notation
		#expect(text == "3+4i")
	}

	@Test("A negative imaginary part replaces the operator rather than doubling it")
	func writesNegativeImaginaryPart() {
		let text = Complex<Double>(3, -4).notation
		#expect(text == "3-4i")
	}

	@Test("A unit coefficient is omitted")
	func writesUnitCoefficient() {
		let text = Complex<Double>(0, 1).notation
		#expect(text == "i")
	}

	@Test("A negative unit coefficient keeps only its sign")
	func writesNegativeUnitCoefficient() {
		let text = Complex<Double>(0, -1).notation
		#expect(text == "-i")
	}

	@Test("A zero imaginary part is not written")
	func writesRealOnly() {
		let text = Complex<Double>(5, 0).notation
		#expect(text == "5")
	}

	@Test("A zero real part is not written")
	func writesImaginaryOnly() {
		let text = Complex<Double>(0, 3).notation
		#expect(text == "3i")
	}

	@Test("Zero writes as a zero, not as the empty string")
	func writesZero() {
		let text = Complex<Double>(0, 0).notation
		#expect(text == "0")
	}

	@Test("A non-finite value writes as inf or nan")
	func writesNonFinite() {
		let infinite = Complex<Double>.infinity.notation
		#expect(infinite == "inf")
		let negativelyInfinite = Complex<Double>(-.infinity, 0).notation
		#expect(negativelyInfinite == "inf")
		let notANumber = Complex<Double>(.nan, 0).notation
		#expect(notANumber == "nan")
	}

	@Test("Magnitudes defer to the component type's own description")
	func writesExtremeMagnitudes() {
		let tiny = Complex<Double>(1e-300, 1).notation
		#expect(tiny == "1e-300+i")
		let huge = Complex<Double>(0, 1e300).notation
		#expect(huge == "1e+300i")
	}

	// MARK: - The round-trip property, which is the whole test

	@Test("Notation round-trips over a spread including every special case")
	func notationRoundTrips() throws {
		let spread: [Complex<Double>] = [
			Complex(3, 4),
			Complex(3, -4),
			Complex(-3, 4),
			Complex(-3, -4),
			Complex(0, 1),
			Complex(0, -1),
			Complex(1, 1),
			Complex(-1, -1),
			Complex(5, 0),
			Complex(-5, 0),
			Complex(0, 3),
			Complex(0, -3),
			Complex(0, 0),
			Complex(-0.0, 0),
			Complex(0, -0.0),
			Complex(0.1, 0.2),
			Complex(2.5, -2.5),
			Complex(3.0000000000000004, -7.5),
			Complex(1e-300, 1),
			Complex(1e300, -1e-300),
			Complex(.leastNonzeroMagnitude, .greatestFiniteMagnitude),
			Complex.infinity,
			Complex(-.infinity, 0),
			Complex(.nan, 0),
			Complex(.infinity, .nan)
		]
		for z in spread {
			let text = z.notation
			let parsed = try #require(Complex<Double>(notation: text), "\(text) should parse")
			let matches = parsed == z
			#expect(matches, "round trip through \(text)")
		}
	}

	@Test("Notation round-trips for Float components too")
	func notationRoundTripsForFloat() throws {
		let spread: [Complex<Float>] = [
			Complex(3, 4),
			Complex(0, -1),
			Complex(2.5, 0),
			Complex(0, 0),
			Complex.infinity
		]
		for z in spread {
			let text = z.notation
			let parsed = try #require(Complex<Float>(notation: text), "\(text) should parse")
			let matches = parsed == z
			#expect(matches, "round trip through \(text)")
		}
	}

	// MARK: - description is left alone

	@Test("description keeps returning the coordinate form")
	func descriptionIsUnchanged() {
		let text = String(describing: Complex<Double>(3, 4))
		#expect(text == "(3.0, 4.0)")
	}
}
