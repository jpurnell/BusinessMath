# Design Proposal — the four Bessel functions

**Status:** proposal, 2026-09-10. Phase 0 (Design).
**Scope:** `BESSELJ`, `BESSELY`, `BESSELI`, `BESSELK` — four functions in
`Sources/BusinessMath/Statistics/SpecialFunctions/`, for BusinessMath.
**Motivated by:** the Excel engineering block, which after this proposal contains no
mathematics that is not already available.
**Release position:** **3.1.0, not 3.0.0.** Nothing here blocks the 3.0.0 release, and §8
argues it should not be pulled into it.

---

## 1. Objective

**Answer Bessel's equation for integer order, in the four forms Excel names.**

```swift
besselJ(x: 1.5, order: 2)      // 0.2320876721... — oscillatory, first kind
besselY(x: 1.5, order: 2)      // -1.1194180169... — oscillatory, second kind
besselI(x: 1.5, order: 2)      // 0.3378346183... — modified, first kind
besselK(x: 1.5, order: 2)      // 0.5836559627... — modified, second kind
```

Four functions, one file each, generic over `T: Real`, returning `T.nan` for invalid input —
the same shape as every other file in `SpecialFunctions/`.

---

## 2. Motivation

### 2.1 These are the last unimplemented mathematics in Excel's engineering block

Excel's engineering category holds 30 functions this package could plausibly owe something to.
Twenty-nine of them turn out to need nothing from BusinessMath:

| Group | Count | What it actually needs |
|---|---:|---|
| `IM*` — `IMABS`, `IMEXP`, `IMLN`, `IMPOWER`, `IMSQRT`, the trig and hyperbolic set | 24 | swift-numerics `ComplexModule`, already resolved at 1.1.1 and already a dependency. `exp`, `log`, `pow`, `sqrt`, the trig family, `real`, `imaginary`, `length`, `phase` — all present. These are parsing and formatting of the `"3+4i"` text form, which is a SwiftExcelFunctions concern, not a mathematical one. |
| `COMPLEX` | 1 | The same text form, in the writing direction. |
| `CONVERT` | 1 | A unit table. Data entry, and it belongs beside the function that reads it. |
| `BESSELJ`, `BESSELY`, `BESSELI`, `BESSELK` | **4** | **This proposal.** |

So the engineering block collapses to four functions, and the four are genuinely new
mathematics. That is the whole of the case for doing them: not that anyone asked, but that
they are the last thing standing between "the Excel surface needs mathematics BusinessMath does
not have" and "it does not."

### 2.2 Why here and not in SwiftExcelFunctions

The family splits on exactly this line, and it is written down in
`BusinessMathExcel/project/plans/proposals/PROPOSAL_swift_excel_architecture.md`:

| Package | Holds |
|---|---|
| SwiftExcelCore | the vocabulary |
| SwiftXLSX | syntax and storage |
| SwiftExcelFunctions | the function library and evaluator |
| **BusinessMath** | **the mathematics, and only the mathematics** |

A Bessel implementation inside SwiftExcelFunctions would be the first piece of real numerical
analysis to live there, reachable only through a spreadsheet formula, and invisible to every
other consumer of this package. The precedent already runs the other way: `erfInv`,
`gammaCDF`, `betaCDF`, `gammaQuantile`, `regularizedLowerIncompleteGamma`,
`inverseRegularizedIncompleteBeta` and `inverseRegularizedLowerIncompleteGamma` are all here,
several of them promoted *out of* the place they were first written when it became clear they
were shared kernels rather than private helpers. Writing Bessel upstream is the cheap version
of that same promotion, done before it needs doing.

### 2.3 Nobody is calling them

Stated plainly, up front, because it governs how this should be sized.

All four measure **0 calls across every sheet of the 79-workbook corpus** — see
`corpus_usage.tsv`, and the README beside it for what that denominator does and does not mean.
That is one well-defined observation, not a ranking against the other 726 zero rows.

But it is enough to settle the priority question: **this is completeness work.** It should be
scheduled as completeness work, sized as completeness work, and it should not displace anything
a user has asked for. `PROPOSAL_psi_completeness.md` took the same position about the same kind
of work, and it was right to.

---

## 3. What Excel specifies

```
BESSELI(X, N)    modified first kind,   Iₙ(x)
BESSELJ(X, N)    first kind,            Jₙ(x)
BESSELK(X, N)    modified second kind,  Kₙ(x)
BESSELY(X, N)    second kind,           Yₙ(x)   (also called Weber's or Neumann's)
```

Both arguments are numbers, and `N` is the order.

| Rule | Excel's behaviour |
|---|---|
| `N` not an integer | **truncated** toward zero |
| `N < 0` | `#NUM!` |
| `X` or `N` non-numeric | `#VALUE!` |
| `X ≤ 0` for `BESSELK`, `BESSELY` | `#NUM!` — Kₙ and Yₙ are undefined there |
| `X < 0` for `BESSELI`, `BESSELJ` | defined mathematically; see §3.1 |

### 3.1 Negative `X` — measured 2026-09-10, and half answered

Jₙ and Iₙ *are* defined for negative `x` — both satisfy `f(−x) = (−1)ⁿ f(x)` — and
Microsoft's reference says nothing about it. Kₙ and Yₙ are genuinely undefined there, so
those two need no decision.

Under ADR-001 the specification is Excel, so this was measured rather than reasoned about:

| Cell | Excel returned |
|---|---|
| `=BESSELJ(-1.5,2)` | `0.232087679` |
| `=BESSELI(-1.5,2)` | `0.337834621` |

**What that settles: Excel does not refuse a negative `X`.** The `#NUM!` branch is
eliminated, which removes the guard clause that would otherwise have to be written into
all four functions. That is real progress and it is the larger half of the question.

**What it does not settle: parity or absolute value.** Order 2 is even, so `(−1)ⁿ = +1` and
the two candidate rules give *identical* answers. The measurement is consistent with both.
Discriminating needs an **odd** order, where they differ in sign:

| Cell | If parity | If \|x\| |
|---|---|---|
| `=BESSELJ(-1.5,1)` | `-0.557936508` | `+0.557936508` |
| `=BESSELI(-1.5,1)` | `-0.981666429` | `+0.981666429` |

Two cells. Until they are run, **`besselJ` and `besselI` should not be written**, because
the sign convention is not recoverable from the code afterwards without redoing this.

The proposal's own framing was at fault here: §3.1 originally offered `BESSELJ(-1.5, 2)` as
the probe, and it is the one call in the family that cannot answer the question it was
chosen to answer. An even order was picked because it matched the reference value already
written down elsewhere in this document, which is a bad reason to choose a measurement.

---

### 3.2 Excel's own accuracy — the same two cells answered this unasked

The measurement above was taken for the sign question and settled a different one as a
byproduct. Set beside the true values, Excel's answers diverge at the **eighth significant
figure**:

| | Excel | True value | Absolute | Relative |
|---|---|---|---|---|
| J₂(1.5) | `0.232087679` | `0.2320876721442` | 6.9 × 10⁻⁹ | 3.0 × 10⁻⁸ |
| I₂(1.5) | `0.337834621` | `0.3378346183357` | 2.7 × 10⁻⁹ | 7.9 × 10⁻⁹ |

Both land around 10⁻⁸ relative, which is what a rational minimax approximation tuned for
about eight digits produces — not a `Double` computed to its own precision. The true values
here are derived from J₀(1.5), J₁(1.5), I₀(1.5) and I₁(1.5) through the three-term
recurrences, so they are self-consistent to full precision and independent of anything
this package computes.

**One caveat before this is treated as settled.** The figures were read from cells showing
nine significant digits. Display rounding cannot explain the gap — rounding
`0.2320876721442` to nine significant figures gives `0.232087672`, not `0.232087679` — so
the divergence is almost certainly real. But re-reading with the full mantissa would remove
the last doubt:

```
=TEXT(BESSELJ(-1.5,2),"0.000000000000000E+00")
=TEXT(BESSELI(-1.5,2),"0.000000000000000E+00")
```

### 3.3 What follows from Excel being the less accurate of the two

This changes what an oracle comparison is worth for this family, and it changes it in a way
that should be decided now rather than during a test failure.

- **The test plan in §6 stands unchanged**, and this is the reason it was built on published
  values and identities rather than on Excel: had it been an Excel oracle, a correct
  implementation would now be failing it.
- **ADR-001 does not apply.** Excel is the specification where it *defines* something
  differently — a different day-count rule, a different sign convention. It is not the
  specification for how many digits of a well-defined transcendental function are right.
  Matching Excel's error would mean deliberately building a worse function to agree with a
  worse one.
- **So: implement to full `Double` precision, and expect ~10⁻⁸ disagreement with Excel.**
  Any oracle harness that later reads these from a workbook needs a per-family tolerance
  rather than the tolerance used for arithmetic, and that tolerance should be recorded as
  *Excel's* error budget rather than ours.

The two identity checks below would confirm the size of that budget directly, since both
are exact and any residual is Excel's alone:

```
=BESSELJ(1.5,0)*BESSELY(1.5,1)-BESSELJ(1.5,1)*BESSELY(1.5,0)     exactly -2/(PI()*1.5) = -0.424413181578
=BESSELI(1.5,0)*BESSELK(1.5,1)+BESSELI(1.5,1)*BESSELK(1.5,0)     exactly 1/1.5         =  0.666666666667
```

---

## 4. Proposed surface

Four files, one function each, matching `SpecialFunctions/` exactly.

```swift
/// The Bessel function of the first kind, Jₙ(x).
public func besselJ<T: Real>(x: T, order n: Int) -> T

/// The Bessel function of the second kind, Yₙ(x).
public func besselY<T: Real>(x: T, order n: Int) -> T

/// The modified Bessel function of the first kind, Iₙ(x).
public func besselI<T: Real>(x: T, order n: Int) -> T

/// The modified Bessel function of the second kind, Kₙ(x).
public func besselK<T: Real>(x: T, order n: Int) -> T
```

**`order` is `Int`, not `T`.** Excel truncates a fractional order, so the truncation is a
spreadsheet convention rather than a mathematical one, and it belongs at the binding where the
convention lives. A `T` order would also invite passing `2.5` and silently getting J₂ — which
is Excel's behaviour, but only Excel's; nothing else should inherit it. The binding in
SwiftExcelFunctions does `Int(truncating)` and maps `n < 0` to `#NUM!`.

**Invalid input returns `T.nan`.** House rule, and the reason for it applies with unusual force
here: a Bessel function is oscillatory and takes every value in its range repeatedly, so there
is no sentinel that could not be mistaken for an answer. `T.nan` is the only honest one.

| Condition | Returns |
|---|---|
| `n < 0` | `T.nan` |
| `x` is NaN or infinite | `T.nan` |
| `x ≤ 0` for `besselY`, `besselK` | `T.nan` |
| `x < 0` for `besselJ`, `besselI` | per §3.1 — parity or `T.nan`, decided by measurement |
| result overflows `T` | `T.infinity` for Iₙ, `T.zero` for Kₙ — see §5.4 |

---

## 5. The numerical design

This is the part that is not mechanical, and it comes down to one question asked four times:
**which direction is the recurrence stable in?**

All four satisfy a three-term recurrence in the order, and all four can in principle be
computed by evaluating orders 0 and 1 and stepping up. For two of them that works. For the
other two it destroys the answer, and it does so quietly — returning a number, of the right
magnitude, that is wrong.

### 5.1 The two that recur upward

```
Yₙ₊₁(x) = (2n/x)·Yₙ(x) − Yₙ₋₁(x)
Kₙ₊₁(x) = (2n/x)·Kₙ(x) + Kₙ₋₁(x)
```

Yₙ and Kₙ both **grow** with `n` at fixed `x`. The recurrence is dominated by the solution
being computed, so relative error does not amplify: upward recurrence from Y₀, Y₁ and from
K₀, K₁ is stable and is the correct method. These two are the easy ones.

### 5.2 The two that do not

```
Jₙ₊₁(x) = (2n/x)·Jₙ(x) − Jₙ₋₁(x)
Iₙ₊₁(x) = Iₙ₋₁(x) − (2n/x)·Iₙ(x)
```

Jₙ and Iₙ both **decay** rapidly with `n` once `n > x`. The same recurrence now computes a
decaying solution in the presence of a growing one — Yₙ for the first, Kₙ for the second — and
any rounding error at all seeds that growing solution, which then swamps the answer. By `n = 20`
at `x = 1` the result can be wrong by orders of magnitude while still looking like a plausible
small number.

The standard treatment (Numerical Recipes §6.5, Abramowitz & Stegun §9.12) is **Miller's
downward recurrence**: start at some order `m` well above both `n` and `x` with the arbitrary
seed `f_{m+1} = 0`, `f_m = 1`, recur *downward* — the direction in which the wanted solution now
dominates — and normalize at the end against an identity that pins the scale:

```
J₀(x) + 2·Σ J₂ₖ(x) = 1               for the ordinary case
I₀(x) − 2·I₂(x) + 2·I₄(x) − … = 1     (or simply normalize against an independently computed I₀)
```

A starting order of roughly `n + √(c·n)` with `c ≈ 40`, rounded up, is the usual choice and
gives full double precision.

**When `n < x` the upward recurrence is stable for J and I too**, and it is cheaper. So both
functions branch on `n` against `x` and use whichever direction is dominated by the answer.
That branch is the substance of this proposal; everything else is bookkeeping.

### 5.3 Orders 0 and 1, and how to get them generically

Every method above needs J₀, J₁ (and Y₀, Y₁, I₀, I₁, K₀, K₁) computed directly. There are two
ways, and the choice matters more than it looks:

| Approach | For | Against |
|---|---|---|
| **Rational minimax coefficients** (A&S 9.4, the `bessj0`-family polynomials) | fast, well-tested, everywhere in the literature | tuned for `Double`, ~1e-8 relative, and **silently no better** if `T` is wider. Bakes magic constants into a generic function. |
| **Ascending series for small `x`, asymptotic (Hankel) expansion for large `x`** | genuinely generic — both converge to whatever `T` can represent, and the crossover can be chosen from `T.ulpOfOne` | more code, and the crossover needs care |

**Recommend the second**, because it is what this directory already does.
`regularizedLowerIncompleteGamma` splits series against continued fraction at `x = a + 1`, caps
both at 200 iterations, and exits on convergence — the same shape, and its accuracy note claims
better than 1e-12 because the method allows it rather than because a coefficient table was
copied. A generic function whose accuracy is pinned at `Double`'s by constants it cannot see
past is worse than it appears.

For the K family, K₀ and K₁ need the series-with-log form for small `x` (they diverge
logarithmically at the origin) and the asymptotic form for large; Y₀ and Y₁ likewise. This is
the bulkiest part of the work and is where the implementation time actually goes.

### 5.4 Overflow and underflow

Iₙ(x) grows like `eˣ/√(2πx)` and Kₙ(x) decays like `e⁻ˣ·√(π/2x)`, so both leave `Double`'s range
at moderate arguments — around `x ≈ 700`. Two decisions:

- **Return `T.infinity` / `T.zero`** at the extremes rather than `T.nan`. These are real limits,
  correctly signed, and distinguishable from the invalid-input case.
- **Do not ship the exponentially scaled variants** (`e⁻ˣIₙ(x)`, `eˣKₙ(x)`) in this pass. They are
  the right answer for anyone doing serious work with these, and they are also a second API
  surface nothing currently needs. Note them here so the option is on the record; add them when
  something asks.

The binding maps `T.infinity` to `#NUM!`, which is what Excel does on overflow.

---

## 6. Test strategy

Three layers, deliberately independent, because they fail for different reasons.

### 6.1 Published reference values

Abramowitz & Stegun tables 9.1 (J and Y), 9.8 (I and K) and the NIST DLMF chapter 10 give
values to 8–10 significant figures. Take a grid: `x ∈ {0.1, 0.5, 1, 2, 5, 10, 20, 50}` crossed
with `n ∈ {0, 1, 2, 5, 10, 25}`, which straddles the `n < x` / `n > x` boundary in both
directions and therefore exercises both recurrence branches.

Every expected value **quoted from the published table**, never from what the implementation
returns. That is the same rule `MicrosoftSpecificationTests` runs under downstream, and it is
the only thing that makes these tests evidence rather than a snapshot.

### 6.2 Identities, which share no code path with the implementation

The strongest tests available here, because they relate two functions computed by different
methods:

```
Wronskian, ordinary:   Jₙ(x)·Yₙ₊₁(x) − Jₙ₊₁(x)·Yₙ(x) = −2/(πx)
Wronskian, modified:   Iₙ(x)·Kₙ₊₁(x) + Iₙ₊₁(x)·Kₙ(x) =  1/x
Recurrence:            Jₙ₋₁(x) + Jₙ₊₁(x) = (2n/x)·Jₙ(x)
Derivative:            J₀′(x) = −J₁(x),   I₀′(x) = I₁(x)
```

The Wronskians hold for every `n` and every `x > 0`, cost nothing to check, and catch a whole
class of error the reference tables would miss — including the Miller normalization being off
by a constant factor, which is the single most likely bug in §5.2 and which a table lookup at
one order would not necessarily reveal.

### 6.3 Boundaries and invalid input

`n = 0`; `x` just above zero for Y and K; the overflow edges from §5.4; every row of the
invalid-input table in §4. Fully deterministic, no tolerance needed.

### 6.4 Tolerance

`1e-12` relative, **except near a zero of Jₙ or Yₙ**, where relative accuracy is not achievable
by any method — the function passes through zero and the reference value carries the same
cancellation. Use an absolute tolerance there and say in the test why. A test suite that
demands relative precision at a zero crossing is a test suite that will be quietly loosened
later by someone who does not know why it was tight.

---

## 7. Work breakdown

| Step | Content |
|---|---|
| 0 | **Measure Excel's negative-`X` behaviour at an *odd* order** (§3.1). The even-order half is done and eliminated `#NUM!`; the sign convention is still open and still blocks steps 1 and 3. Two cells. |
| 1 | `besselJ` — series/asymptotic J₀ and J₁, then the two-direction recurrence of §5.2. The hardest of the four; everything after reuses its structure. |
| 2 | `besselY` — Y₀ and Y₁ (series-with-log, asymptotic), then upward recurrence. |
| 3 | `besselI` — mirrors step 1, modified. |
| 4 | `besselK` — mirrors step 2, modified. |
| 5 | `BesselFunctionsTests` — the three layers of §6. |
| 6 | Bind the four in SwiftExcelFunctions: order truncation, `n < 0` → `#NUM!`, `x ≤ 0` → `#NUM!` for K and Y, overflow → `#NUM!`. Mechanical once the above exists. |

Steps 1–4 are each one file. Step 5 is one file and is the majority of the value.

---

## 8. Why this is 3.1.0

Three reasons, and the third is the one that matters.

1. **It is additive.** Four new free functions in an existing directory. Nothing changes shape,
   nothing is deprecated, no existing caller is affected. By the release checklist's own rule
   that is a minor-version feature, and a minor version can land the week after a major one.
2. **Nothing is waiting on it.** Zero corpus calls; no downstream consumer blocked; the
   SwiftExcelFunctions binding is a nice-to-have on a package already at 269 registered
   functions.
3. **Pulling it into 3.0.0 would trade a known-good release date for unbounded numerical work.**
   §5 is not difficult mathematics but it is *fiddly* mathematics, of the kind where the
   implementation looks finished two days before it is correct — and where the failure mode is a
   plausible number rather than a crash. That is precisely the work that should not be inside a
   release window it can silently extend.

If 3.0.0 ships without these, the honest statement of coverage is: *the Excel engineering block
needs four special functions BusinessMath does not yet have, and everything else in it is
already available.* That sentence is fine to publish.

---

## 9. Open questions

1. **Parity or absolute value for negative `X`** (§3.1). Half measured 2026-09-10: Excel
   accepts a negative `X` rather than refusing it. The sign is still open and needs
   `=BESSELJ(-1.5,1)` and `=BESSELI(-1.5,1)`. **Blocks steps 1 and 3.**
2. **Confirm Excel's precision with the full mantissa** (§3.2). The nine-digit reading puts
   Excel's error near 10⁻⁸ relative, which display rounding cannot account for. Does not
   block anything — the tests never depended on Excel — but it fixes the tolerance any
   future oracle run should use, and it is two `TEXT()` calls.
3. **Scaled variants** (§5.4). Deliberately deferred. Worth revisiting if anything ever
   needs Iₙ or Kₙ outside the range where the unscaled forms survive.
4. **Should the order be `Int` everywhere?** (§4). Proposed yes. The alternative — a `T`
   order with Excel's truncation baked in — makes the spreadsheet convention the library's
   convention, which is backwards. Worth one look before four signatures are committed to.

---

## 10. Measurement log

Kept because §3.2 was answered by a measurement taken for another purpose, and the next
person should be able to see what was actually run rather than what was concluded.

| Date | Call | Result | What it settled |
|---|---|---|---|
| 2026-09-10 | `=BESSELJ(-1.5,2)` | `0.232087679` | negative `X` accepted, not `#NUM!`; Excel ≈ 3.0 × 10⁻⁸ relative error |
| 2026-09-10 | `=BESSELI(-1.5,2)` | `0.337834621` | as above; Excel ≈ 7.9 × 10⁻⁹ relative error |
| pending | `=BESSELJ(-1.5,1)` | | parity vs absolute value |
| pending | `=BESSELI(-1.5,1)` | | parity vs absolute value |
| pending | Wronskian pair (§3.2) | | Excel's error budget, measured against an exact identity |

Reference values at `x = 1.5`, cross-checked against each other through the three-term
recurrences:

| | J | Y | I | K |
|---|---|---|---|---|
| n=0 | 0.5118276717 | 0.3824489237 | 1.6467231898 | 0.2138055626 |
| n=1 | 0.5579365079 | −0.4123086269 | 0.9816664286 | 0.2773878004 |
| n=2 | 0.2320876721 | −0.9321937507 | 0.3378346183 | 0.5836559627 |
