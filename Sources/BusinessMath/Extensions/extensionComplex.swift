//
//  extensionComplex.swift
//  BusinessMath
//
//  Created by Justin Purnell on 9/9/26.
//

import Foundation
import Numerics

//  A `Complex` ↔ `String` codec in the notation people actually write, `a+bi`.
//
//  `ComplexModule` is complete on the mathematics and silent on the text: `description`
//  yields the coordinate pair `"(3.0, 4.0)"`, and there is no way to read it back. That is a
//  defensible choice upstream — unambiguous, debugger-friendly, free of the i-versus-j
//  argument — and it is a gap for anyone whose output a person reads.
//
//  This is a MEMBER on an extension, deliberately, and not a conformance to
//  `LosslessStringConvertible`. A conformance is global and unscoped: every downstream
//  caller's `"\(z)"` would change, with no import to drop and no way to opt out. It would
//  also collide the day swift-numerics adds its own. And it buys nothing here — `Complex`
//  is not a `Real`, so it cannot satisfy the `Real & Sendable & LosslessStringConvertible`
//  constraint that every generic site in this package writes. `description` is left alone.

// MARK: - Notation

public extension Complex where RealType: LosslessStringConvertible {

	/// This number in conventional notation — `"3+4i"`, `"-2.5i"`, `"5"`, `"i"`.
	///
	/// The conventions, each of which is a decision rather than an obvious consequence:
	///
	/// | Value | Written | Why |
	/// |---|---|---|
	/// | `Complex(3, 4)` | `3+4i` | the default form |
	/// | `Complex(3, -4)` | `3-4i` | the sign replaces the `+`, it is not doubled |
	/// | `Complex(0, 1)` | `i` | a unit coefficient is omitted, as in `x` rather than `1x` |
	/// | `Complex(0, -1)` | `-i` | likewise |
	/// | `Complex(5, 0)` | `5` | a zero imaginary part is not written |
	/// | `Complex(0, 3)` | `3i` | a zero real part is not written |
	/// | `Complex(0, 0)` | `0` | not the empty string |
	/// | non-finite | `inf` / `nan` | matching upstream's existing behaviour |
	///
	/// The writer is canonical rather than configurable, and emits only `i`. A caller that
	/// needs `j` — Excel's `COMPLEX` takes a suffix argument — swaps one character, because
	/// the suffix is always the final character whenever there is one. A configurable writer
	/// would also be one nothing could round-trip against.
	///
	/// Magnitudes are `RealType`'s own `description`, so `1e-300` stays `1e-300` rather than
	/// being expanded or rounded to a precision this type has no basis for choosing. The one
	/// tidy-up is a trailing `.0`, which is dropped: `Complex(3, 4)` is `3+4i` and not
	/// `3.0+4.0i`. Dropping it is lossless — `"3"` and `"3.0"` parse to the same value.
	///
	/// ```swift
	/// import Numerics
	///
	/// let z = Complex<Double>(3, -4)
	/// let text = z.notation          // "3-4i"
	/// let unit = Complex<Double>(0, 1).notation   // "i"
	/// print(text, unit)
	/// ```
	///
	/// - Complexity: O(1).
	var notation: String {
		guard isFinite else {
			// `real` and `imaginary` report `.nan` for any non-finite value, so the raw
			// storage is the only place the distinction survives. An infinity anywhere
			// means the point at infinity; a NaN with no infinity is indeterminate.
			let raw = rawStorage
			let isInfinite = raw.x.isInfinite || raw.y.isInfinite
			return isInfinite ? "inf" : "nan"
		}
		let realPart: RealType = real
		let imaginaryPart: RealType = imaginary
		guard !imaginaryPart.isZero else { return notationDigits(realPart) }
		let term: String = notationImaginaryTerm(imaginaryPart)
		guard !realPart.isZero else { return term }
		// The term already carries its own sign, so a negative one needs no operator.
		let separator: String = imaginaryPart < 0 ? "" : "+"
		return notationDigits(realPart) + separator + term
	}

	/// Reads conventional notation, and returns `nil` for anything it cannot read exactly.
	///
	/// Accepted: everything ``notation`` emits, plus the variations a person types — a
	/// leading `+`, spaces around the operator, and `j`, `J` or `I` in place of `i`.
	///
	/// Rejected, always as `nil` and never as a guess:
	///
	/// - `"3+4"` — a missing suffix is not an implied one. Returning `Complex(7, 0)` here
	///   would be the plausible-but-wrong answer this package exists to refuse.
	/// - `"3i+4i"` — two imaginary terms.
	/// - `"i3"` — the suffix trails its coefficient, it never leads it.
	/// - `"3+4k"` — `k` is not an imaginary unit.
	/// - `"(3.0, 4.0)"` — the coordinate form `description` produces, rejected **deliberately**.
	///   A pair in parentheses is a point, a tuple, a size, an interval or a range; accepting
	///   it would make any `"(a, b)"` a caller happens to hold into a complex number. It is
	///   also the representation this notation exists to replace, and a second accepted form
	///   would make the round-trip property describe one path through the type rather than
	///   the type.
	///
	/// ```swift
	/// import Numerics
	///
	/// let z = Complex<Double>(notation: "3 + 4i")     // Complex(3.0, 4.0)
	/// let unit = Complex<Double>(notation: "-i")      // Complex(0.0, -1.0)
	/// let refused = Complex<Double>(notation: "3+4")  // nil
	/// print(z as Any, unit as Any, refused as Any)
	/// ```
	///
	/// - Parameter notation: The text to read, such as `"3+4i"`.
	/// - Complexity: O(*n*) in the length of the text.
	init?(notation: String) {
		guard let parts: (real: RealType, imaginary: RealType) = parseNotation(notation) else { return nil }
		self.init(parts.real, parts.imaginary)
	}
}

// MARK: - Writing

/// A component's own `description`, with a trailing `.0` removed.
///
/// The trim is lossless for every value: a description ending in `.0` is an integral value,
/// and the same digits without the suffix parse back to it exactly.
private func notationDigits<R: Real & LosslessStringConvertible>(_ value: R) -> String {
	let text = String(value)
	guard text.hasSuffix(".0") else { return text }
	return String(text.dropLast(2))
}

/// One signed imaginary term — `"4i"`, `"-2.5i"`, `"i"`, `"-i"`.
private func notationImaginaryTerm<R: Real & LosslessStringConvertible>(_ value: R) -> String {
	let sign: String = value < 0 ? "-" : ""
	let magnitude: R = value.magnitude
	guard !magnitude.isEqual(to: 1) else { return sign + "i" }
	return sign + notationDigits(magnitude) + "i"
}

// MARK: - Reading

/// The characters that may end an imaginary term. The writer emits only `i`; the reader
/// takes `j` too, because electrical engineering writes `j` universally and a reader that
/// refused it would be wrong for a whole discipline.
private let notationSuffixes: Set<Character> = ["i", "I", "j", "J"]

/// The characters that may introduce an exponent, and so make a following sign part of a
/// single number rather than an operator between two terms.
private let notationExponentMarkers: Set<Character> = ["e", "E", "p", "P"]

/// Splits and reads conventional notation, or returns `nil`.
///
/// The grammar is `real`, or `imaginary`, or `real operator imaginary`. Nothing else — an
/// imaginary term never leads, and there are never two of them.
private func parseNotation<R: Real & LosslessStringConvertible>(_ text: String) -> (real: R, imaginary: R)? {
	let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
	guard !trimmed.isEmpty else { return nil }
	guard let operatorIndex = notationOperatorIndex(in: trimmed) else {
		return parseSingleTerm(trimmed)
	}
	let realText = String(trimmed[trimmed.startIndex..<operatorIndex])
		.trimmingCharacters(in: .whitespacesAndNewlines)
	let imaginaryText = String(trimmed[trimmed.index(after: operatorIndex)...])
		.trimmingCharacters(in: .whitespacesAndNewlines)
	guard !realText.isEmpty, !imaginaryText.isEmpty else { return nil }
	// Whitespace is tolerated at the ends and around the operator, nowhere else. Without
	// this, `"3 4i"` would read as `34i` — a missing operator silently forgiven.
	guard !notationHasInteriorWhitespace(realText) else { return nil }
	guard !notationHasInteriorWhitespace(imaginaryText) else { return nil }
	guard let realValue = R(realText) else { return nil }
	guard let magnitude: R = parseUnsignedImaginary(imaginaryText) else { return nil }
	let isNegative: Bool = trimmed[operatorIndex] == "-"
	let imaginaryValue: R = isNegative ? -magnitude : magnitude
	return (realValue, imaginaryValue)
}

/// The index of the sign separating two terms, if there is one.
///
/// Searched from the end, so the last top-level sign wins and `"3e-4-5i"` splits at the
/// operator rather than inside the exponent. A sign at the very start is the first term's
/// own, and a sign directly after an exponent marker belongs to that exponent.
private func notationOperatorIndex(in text: String) -> String.Index? {
	var index = text.endIndex
	while index > text.startIndex {
		index = text.index(before: index)
		guard index > text.startIndex else { return nil }
		let character = text[index]
		guard character == "+" || character == "-" else { continue }
		let previous = text[text.index(before: index)]
		guard !notationExponentMarkers.contains(previous) else { continue }
		return index
	}
	return nil
}

/// True if the text holds whitespace anywhere. It has already been trimmed at both ends, so
/// anything left is interior.
private func notationHasInteriorWhitespace(_ text: String) -> Bool {
	text.contains(where: { $0.isWhitespace })
}

/// Reads a lone term: `"5"`, `"-2.5i"`, `"i"`, `"+i"`, `"3i"`.
private func parseSingleTerm<R: Real & LosslessStringConvertible>(_ text: String) -> (real: R, imaginary: R)? {
	guard !notationHasInteriorWhitespace(text) else { return nil }
	guard let last = text.last, notationSuffixes.contains(last) else {
		guard let realValue = R(text) else { return nil }
		return (realValue, 0)
	}
	var body = text.dropLast()
	var isNegative = false
	if let first = body.first, first == "+" || first == "-" {
		isNegative = (first == "-")
		body = body.dropFirst()
	}
	guard let magnitude: R = parseUnsignedImaginary(String(body) + String(last)) else { return nil }
	let imaginaryValue: R = isNegative ? -magnitude : magnitude
	return (0, imaginaryValue)
}

/// Reads an unsigned imaginary term and returns its coefficient.
///
/// The term must end in a suffix. An empty coefficient is the implicit 1 that lets `i` mean
/// `Complex(0, 1)`, exactly as `x` means `1x`; that omission is what makes the round-trip
/// non-trivial, since the writer drops the coefficient the reader has to put back.
private func parseUnsignedImaginary<R: Real & LosslessStringConvertible>(_ text: String) -> R? {
	guard let last = text.last, notationSuffixes.contains(last) else { return nil }
	let coefficient = text.dropLast()
	guard let first = coefficient.first else { return 1 }
	// A sign here is one the caller has already accounted for, so a second is malformed:
	// `"--3i"` must not read as `3i`.
	guard first != "+", first != "-" else { return nil }
	return R(String(coefficient))
}
