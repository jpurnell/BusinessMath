//
//  DisplayNonFiniteRenderingTests.swift
//  BusinessMath
//
//  `percent()` rendered `-Double.infinity` as `"∞"`. That is not a presentation choice — it
//  drops the sign, so a value at negative infinity was displayed as one at positive infinity,
//  and `number()` gave `-∞` for the same input. Two formatters in one extension disagreeing
//  about the direction of a magnitude.
//
//  `number()` and `currency()` had no explicit non-finite handling at all: their spelling came
//  from ICU and was therefore locale-dependent, so the same infinity could render differently
//  on two machines. All three now share `displayNonFiniteToken`, which is also what
//  `FloatingPointFormatter`'s display strategies use — so a lowercase `nan`/`inf` in this
//  library now means exactly one thing: the field is going to be parsed.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Display formatters agree about non-finite values")
struct DisplayNonFiniteRenderingTests {

	// MARK: - The defect: a dropped sign

	@Test("percent() keeps the sign of an infinity")
	func percentKeepsTheSignOfInfinity() {
		#expect(Double.infinity.percent() == "∞")
		#expect((-Double.infinity).percent() == "-∞", "the sign was dropped, so -∞ read as +∞")
	}

	@Test("The three display formatters agree with each other")
	func displayFormattersAgree() {
		// Previously: percent() said "∞", number() said "-∞", currency() said whatever ICU
		// chose for the current locale.
		#expect((-Double.infinity).percent() == (-Double.infinity).number())
		#expect((-Double.infinity).number() == (-Double.infinity).currency())
		#expect(Double.nan.percent() == "NaN")
		#expect(Double.nan.number() == "NaN")
		#expect(Double.nan.currency() == "NaN")
	}

	@Test("A non-finite rendering does not depend on the locale")
	func renderingIsLocaleIndependent() {
		// ICU supplied the spelling for number()/currency() before, so this pair could differ.
		let germanInfinity = (-Double.infinity).number(2, .toNearestOrAwayFromZero, Locale(identifier: "de_DE"))
		let usInfinity = (-Double.infinity).number(2, .toNearestOrAwayFromZero, Locale(identifier: "en_US"))
		#expect(germanInfinity == usInfinity)
		#expect(germanInfinity == "-∞")
	}

	// MARK: - Controls: finite values are untouched

	@Test("Finite values still format normally")
	func finiteValuesAreUnchanged() {
		// The guard returns `nil` for anything finite, so every ordinary path is as it was.
		let quarter = 0.25.percent(0)
		#expect(quarter.contains("25"), "got \(quarter)")

		let thousand = 1000.0.number(0, .toNearestOrAwayFromZero, Locale(identifier: "en_US"))
		#expect(thousand.contains("1"), "got \(thousand)")

		let zero = 0.0.percent(0)
		#expect(zero.contains("0"), "got \(zero)")
	}

	@Test("The machine-readable tokens are deliberately different and unchanged")
	func csvTokensStayLowercase() {
		// Lowercase ASCII means "this field is going to be parsed". That distinction is the
		// reason the CSV path was left spelled differently rather than unified.
		#expect(Double.nan.percent() != "nan")
		#expect(Double.infinity.number() != "inf")
	}
}
