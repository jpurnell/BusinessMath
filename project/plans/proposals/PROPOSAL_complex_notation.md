# Design Proposal — complex numbers that read like complex numbers

**Status:** proposal, 2026-09-09. Phase 0 (Design).
**Scope:** a `Complex` ↔ `String` codec in conventional `a+bi` notation, for BusinessMath.
**Revised:** 2026-09-09 — a member rather than a conformance; see §6.
**Motivated by:** Excel's 21 `IM*` functions, which need it — but the gap is not Excel's.

---

## 1. Objective

**Let a complex number round-trip through the notation people write it in.**

```swift
let z = Complex<Double>("3+4i")!     // parses
String(describing: z)                // "3+4i"
```

Neither line works today.

---

## 2. Motivation

### 2.1 What swift-numerics does and does not do

`ComplexModule` is complete on the mathematics. `Complex+ElementaryFunctions.swift` supplies
`exp`, `log`, `sqrt`, `pow`, `root`, the six trigonometric functions, the six hyperbolics and
all their inverses; `Polar.swift` supplies `length`, `phase`, `polar`, `conjugate`,
`reciprocal`. Nothing on that list needs writing, and BusinessMath already depends on the
package.

What it does not do is text:

```swift
extension Complex: CustomStringConvertible {
  public var description: String {
    guard isFinite else { return "inf" }
    return "(\(x), \(y))"
  }
}
```

A coordinate pair. There is no `LosslessStringConvertible`, no `init?(_ description: String)`,
no string-literal conformance. So `Complex(3, 4)` prints as `(3.0, 4.0)` and **cannot be read
back**.

That is a defensible choice upstream — unambiguous, debugger-friendly, free of the
`i`-versus-`j` argument — and it is a gap for anyone whose output a person reads.

### 2.2 Why this belongs here rather than in the Excel layer

The first version of this argument was that the `IM*` family is "just dressing up
swift-numerics", and therefore belongs wherever the Excel bindings live. That was wrong in one
specific way: **the notation is not Excel's.** `3+4i` is how the notation is written in every
textbook, every engineering paper and every other language's complex type. Excel adopted it;
it did not invent it.

What *is* Excel's, and stays in the binding layer:

- the optional `j` suffix as `COMPLEX`'s third argument, and its refusal of any other letter
- `#NUM!` for a malformed string, `#VALUE!` for a non-string
- the exact spelling of the function names

What is general, and belongs here:

- reading `3+4i`, `-2.5i`, `5`, `i`, `-i`, `+i`, `3 + 4i`
- writing the same, with the conventions a reader expects

This belongs beside the numerics because the notation is general, not because of any
genericity it unlocks — §6 records the argument that claimed otherwise, and why it was wrong.

---

## 3. Proposed Architecture

### 3.1 A member, not a conformance

```swift
public extension Complex where RealType: LosslessStringConvertible {

    /// This number in conventional notation: `"3+4i"`, `"-2.5i"`, `"5"`, `"i"`.
    var notation: String { get }

    /// Reads conventional notation. `nil` for anything it cannot read exactly.
    init?(notation: String)
}
```

**`description` is left alone.** An earlier draft conformed `Complex` to
`LosslessStringConvertible`, which would have replaced `description` for every downstream
caller. That is a worse trade than it looked, and §6 records why the reasoning behind it was
wrong.

`notation` because the pair is symmetric and the word says what the string *is* rather than
how it is styled. The name is not the load-bearing part — anything that is not `description`
carries the same benefit.

### 3.2 What the writer decides

The conventions, stated because each is a decision and not an obvious consequence:

| Value | Written | Why |
|---|---|---|
| `Complex(3, 4)` | `3+4i` | the default form |
| `Complex(3, -4)` | `3-4i` | the sign replaces the `+`, not doubled |
| `Complex(0, 1)` | `i` | a unit coefficient is omitted, as in `x` rather than `1x` |
| `Complex(0, -1)` | `-i` | likewise |
| `Complex(5, 0)` | `5` | a zero imaginary part is not written |
| `Complex(0, 3)` | `3i` | a zero real part is not written |
| `Complex(0, 0)` | `0` | not the empty string |
| non-finite | `inf` / `nan` | matching upstream's existing behaviour |

The unit-coefficient rule is the one that makes round-tripping non-trivial: `i` must parse
back to `Complex(0, 1)`, so the reader has to treat a bare suffix as an implicit 1.

### 3.3 What the reader accepts

Everything the writer produces, plus the tolerable variations a person types: leading `+`,
spaces around the operator, `J` or `j` as the suffix, and either case. What it rejects is
anything ambiguous — two imaginary terms, a missing operator between parts, a suffix that is
not `i` or `j`.

**Rejection is `nil`, never a guess.** `"3+4"` is not a complex number with an implied
suffix; it is a malformed string, and returning `Complex(7, 0)` from it would be the
plausible-wrong-answer this package's tests exist to catch.

### 3.4 The coordinate form is rejected, deliberately

`"(3.0, 4.0)"` — the format `description` produces *today* — must **not** parse.

Three reasons, and the first is the one that matters:

- **It is not distinctive.** A pair in parentheses is a point, a tuple, a size, an interval,
  a range. Accepting it means any `"(a, b)"` a caller happens to hold becomes a complex
  number, and a type that will read anything shaped vaguely like it is a type that will
  silently accept the wrong input. The whole reason `3+4i` is worth adding is that it says
  what it is.
- **Two accepted forms make "lossless" ambiguous.** The conformance promises that what the
  writer emits, the reader reads back. If the reader also accepts a second form the writer
  never produces, the round-trip property no longer describes the type — it describes one
  path through it.
- **It is the format being replaced.** Accepting it for compatibility would preserve exactly
  the representation §2.1 identifies as the problem.

The migration cost is real and is the honest counter-argument: a caller who stored
`description` output before this change cannot read it back afterwards. That is §7's
territory, and the answer there is a release note rather than a permissive parser.

---

## 4. Constraints & Compliance

- No force unwraps, no `try!`. The parser is guard-clause throughout and returns `nil`.
- No new dependency: `Numerics` is already a product this package takes.
- `Sendable` and `Codable` conformances on `Complex` are untouched.
- The extension is constrained to `RealType: LosslessStringConvertible`, so it does not
  apply where the component type cannot itself round-trip.

---

## 5. Test Strategy

**Round-trip is the property, and it is the whole test.** For a spread of values including
every special case in §3.2, `Complex(String(describing: z)) == z`. That single assertion
catches a writer that omits something the reader needs and a reader that mis-parses something
the writer emits — which no pair of one-directional tests does.

**Rejection cases get named tests**, because a parser's failures matter more than its
successes: `"3+4"`, `"3+4k"`, `"i3"`, `"3i+4i"`, `""`, `"+"`, and `"(3.0, 4.0)"` — the last
being the one a reviewer is most likely to think should work. §3.4 is why it must not.

**Known-value tests** for the eight rows of §3.2's table, which are the conventions rather
than arithmetic.

---

## 6. Alternatives Considered

**Conform to `LosslessStringConvertible` and replace `description`.** This is what the first
draft proposed, and it was wrong on a fact I had not checked.

The case for it was that the conformance makes `Complex` usable with everything already
generic over `LosslessStringConvertible` — in this package, `PeriodDriver`,
`LinearCycleSolver`, `IterativeCycleSolver`, `ModelDefinition` and `FormulaEvaluator`.
There are **five** such sites, not three; the count was checked against the tree.

**`Complex` cannot satisfy any of those.** All five constrain their numeric type to
`Real & Sendable & LosslessStringConvertible`, and `Complex` is not a `Real` — it conforms to
`AlgebraicField`, `AdditiveArithmetic`, `Numeric` and `ElementaryFunctions`, and `Real` is the
constraint on its *component* type rather than on itself. So the conformance buys nothing
here, and every cost in §7 was being paid for a benefit that does not exist.

Rejected. The costs it avoids are worth listing because they were the whole of the old §7:
`description` changing under every downstream caller; a redeclaration error the day
swift-numerics adds its own conformance; and a cross-module retroactive conformance that
Swift 6 warns about and would need annotating.

**A free function pair, `parseComplex(_:)` and `formatComplex(_:)`.** Equivalent in safety and
worse to read: `z.notation` at a call site says more than `formatComplex(z)`, and the failable
initialiser is where a Swift reader looks for parsing.

**`ExpressibleByStringLiteral`.** Would allow `let z: Complex = "3+4i"`, which reads well, but
a literal that traps at runtime on a typo is a poor trade for four saved characters. The
initialiser is failable for a reason.

**Support `j` only in the Excel layer.** Rejected: electrical engineering writes `j`
universally, so a reader refusing it is wrong for a whole discipline rather than permissive
for Excel's sake. The *writer* emits only `i`; choosing `j` on output stays an Excel concern,
since that is where the argument selecting it lives.

**A wrapper type, `ComplexNotation<R: Real>`, owning the conformance.** A struct holding a
`Complex<R>` and conforming to `LosslessStringConvertible` itself. It avoids every cost the
conformance carried — the conformance is ours, so nothing is retroactive, nothing is global
and unscoped, and no downstream caller's `"\(z)"` changes — and it adds one the member does
not avoid: no member is added to a foreign type, so there is no ambiguity the day
swift-numerics ships its own `notation`, which is the one residual risk §7 still carries.

Rejected for now, on the same fact that rejected the conformance. `ComplexNotation<R>` is not
a `Real` either, so it cannot satisfy `Real & Sendable & LosslessStringConvertible` any more
than `Complex` can, and all five constraint sites stay closed to it. **No type built around
`Complex` can open them** — the benefit the wrapper appears to preserve does not exist for any
shape of this idea. Against that, the only known consumer — the `IM*` bindings, 21 functions
parsing and formatting on both sides, so 42 conversions — reads worse:
`ComplexNotation(s)?.value` where `Complex(notation: s)` would do.

If a genuine `LosslessStringConvertible`-generic context ever appears, the wrapper is the
right shape for it, and at that point it is five lines delegating to the member rather than a
second parser. That ordering is what keeps one implementation of the grammar.

**Ask swift-numerics to add it.** Still the better long-term answer and worth doing
separately. Nothing here blocks on that conversation, and a member on an extension is far
easier to retire than a conformance if they adopt one.

## 7. Source & API Compatibility

**Purely additive.** Two new members on an extension of a type from another module, both
constrained to `RealType: LosslessStringConvertible`. Nothing existing changes behaviour,
`description` keeps returning `"(3.0, 4.0)"`, and no downstream caller is affected.

The one residual risk is a name collision: if swift-numerics later adds its own `notation`
member, this becomes an ambiguity. That is a compile error rather than a silent change, and it
is a member rather than a conformance, so retiring ours is a deletion.

This section was three paragraphs of real hazard in the previous draft. Removing the
conformance removed the hazard rather than mitigating it, which is the better kind of fix.

## 8. Open Questions

1. **Should the writer be configurable at all** — a suffix parameter, a precision parameter —
   or stay a single canonical form with any variation done by the caller? Leaning canonical:
   a configurable `description` is a `description` nobody can rely on.
2. **How should a very large or very small component print?** `1e-300+1i` is correct and
   unreadable. Deferring to `RealType`'s own `description` is consistent and gives that
   result; a formatted alternative would need a precision decision this proposal has no basis
   for making.
3. **Does `ExpressibleByStringLiteral` belong too?** It would allow `let z: Complex = "3+4i"`,
   which reads well — but a literal that can fail at runtime is a trap, and the initialiser
   is failable for good reason. Leaning no.

---

## 9. Sequencing

| # | Deliverable | Ends when |
|---|---|---|
| 1 | The reader, with §5's rejection cases | Every malformed string in the list returns `nil` |
| 2 | The writer, with §3.2's table | The eight conventions hold |
| 3 | The round-trip property test | It passes over a spread including every special case |
| 4 | Changelog entry | Additive, so the entry is a mention rather than a warning |

---

**Next action:** step 1. The reader is where the ambiguity lives, and writing it first means
the writer is designed against a parser that already refuses what it should.
