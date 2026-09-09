# Design Proposal — complex numbers that read like complex numbers

**Status:** proposal, 2026-09-09. Phase 0 (Design).
**Scope:** a `Complex` ↔ `String` codec in conventional `a+bi` notation, for BusinessMath.
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

`LosslessStringConvertible` is already a constraint this package builds on — `PeriodDriver`,
`LinearCycleSolver` and `IterativeCycleSolver` all require it of their numeric type — so the
conformance is idiomatic here in a way it would not be next to a formula evaluator.

---

## 3. Proposed Architecture

### 3.1 The conformance

```swift
extension Complex: LosslessStringConvertible where RealType: LosslessStringConvertible {

    /// Reads conventional notation: `"3+4i"`, `"-2.5i"`, `"5"`, `"i"`.
    ///
    /// Returns `nil` for anything it cannot read exactly. Lossless means lossless: a
    /// string this accepts and a string this produces round-trip.
    public init?(_ description: String)

    /// Writes conventional notation.
    public var description: String { get }
}
```

`description` is a **behavioural change** to a type this package does not own, and §7 is about
that.

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
successes: `"3+4"`, `"3+4k"`, `"i3"`, `"3i+4i"`, `""`, `"+"`.

**Known-value tests** for the eight rows of §3.2's table, which are the conventions rather
than arithmetic.

---

## 6. Alternatives Considered

**Put it in SwiftExcelFunctions.** Rejected — §2.2. The notation predates and outlives the
spreadsheet, and the package that owns numerics is where a numeric type's string form belongs.
The Excel layer keeps what is genuinely Excel's.

**Ask swift-numerics to add it.** The better long-term answer, and worth doing separately.
Upstream has declined a `description` change before on ambiguity grounds, and this proposal
does not block on that conversation. If they adopt it, this extension collapses to nothing.

**A free function pair rather than a conformance.** `parseComplex(_:)` and
`formatComplex(_:)` avoid touching `description`. Rejected because the conformance is what
makes the type usable with everything already generic over `LosslessStringConvertible` —
which in this package is `PeriodDriver` and both cycle solvers.

**Support `j` only in the Excel layer.** Rejected: electrical engineering writes `j`
universally, so a reader that refuses it is wrong for a whole discipline rather than
permissive for Excel's sake. The *writer* emits only `i`; choosing `j` on output stays an
Excel concern, since that is where the argument selecting it lives.

---

## 7. Source & API Compatibility

**Conforming a type you do not own is the risk in this proposal, and it is worth stating
plainly.**

`Complex` already conforms to `CustomStringConvertible` upstream. Adding
`LosslessStringConvertible` here changes what `description` returns for every existing caller
in every package that imports BusinessMath — `(3.0, 4.0)` becomes `3+4i`.

Three consequences:

1. **Anything parsing the old format breaks.** Nothing in this package does; a downstream
   consumer might.
2. **If swift-numerics later adds its own conformance, this becomes a redeclaration** and
   fails to compile. That is a loud failure rather than a silent one, which is the right
   direction, but it will happen on a dependency bump.
3. **A retroactive conformance across module boundaries** is exactly what Swift 6 warns about
   and what `@retroactive` exists to annotate. It should be annotated.

The alternative that avoids all three is §6's free-function pair, at the cost of the
genericity that motivated the conformance. **Recommend the conformance, annotated, with the
compatibility note in the release entry** — but this is the decision a reviewer should
actually weigh, not the parser.

---

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
| 4 | `@retroactive`, and the §7 note in the changelog | A reviewer can see what changed for downstream callers |

---

**Next action:** step 1. The reader is where the ambiguity lives, and writing it first means
the writer is designed against a parser that already refuses what it should.
