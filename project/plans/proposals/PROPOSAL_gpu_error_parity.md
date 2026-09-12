# Design Proposal — the GPU says what went wrong, or stops saying anything

**Status:** proposal, 2026-09-12. Phase 0 (Design).
**Scope:** error behaviour of the Metal Monte Carlo kernel against `BytecodeInterpreter`.
**Motivated by:** `REVIEW_simulation_tests.md` §3.7, the fifth of its five CPU/GPU gaps — the four
others landed in `4df8a678`. This one was held back because it is a decision, not a correction.
**Revised:** 2026-09-12 — §2's central measurement was an artifact and is retracted in §2.1. The
correction lowers the urgency and changes the recommendation's justification, not its shape.

---

## 1. Objective

**The same model, on the same inputs, must not answer differently for having run on the GPU — and
where it cannot avoid differing, it must say so rather than return a number.**

`BytecodeInterpreter` throws on three conditions. The kernel has no way to throw and currently
carries on. Whatever is done here, a caller has to be able to tell a computed answer from an
abandoned one.

---

## 2. What is actually true today

Measured on an Apple M1 Max against a replica of `evaluateModel`'s exact shape — a
`float stack[32]` indexed by a runtime counter, operands opaque to the compiler.

| expression | `BytecodeInterpreter` | Metal kernel |
|---|---|---|
| `1 / 0` | throws `.divisionByZero` | `inf` |
| `-1 / 0` | throws `.divisionByZero` | `-inf` |
| `0 / 0` | throws `.divisionByZero` | `NaN` |
| `sqrt(-1)` | throws `.invalidOperation("sqrt of negative")` | `NaN` |
| `log(0)` | throws `.invalidOperation("log of non-positive")` | `-inf` |
| `log(-1)` | throws `.invalidOperation("log of non-positive")` | `NaN` |
| `inf * 0` | `NaN` | `NaN` |

Every divergence is the one the review anticipated: **the CPU refuses to answer and the GPU
returns a non-finite value.** A caller who tests `isNaN` and `isInfinite` on every output can
detect all of them; a caller who does not, silently keeps them. Nothing here returns a *plausible*
wrong number.

### 2.1 A wrong version of this section, and what it was

The first draft reported `0 / 0 = 1.0` and `inf * 0 = 1.0` on the GPU, and built its argument on
them. **That was a measurement artifact and is retracted.**

The probe wrote `v / v` directly. Fast math — on by default, and what `options: nil` selects — lets
the compiler apply `x / x → 1` because it may assume no NaNs. `evaluateModel` divides
`stack[sp-2] / stack[sp-1]`, and the compiler cannot establish that those two slots hold the same
value, so the identity never fires. Re-measured in the kernel's real shape, fast and safe math
agree on all seven rows above.

Two consequences, and they point in opposite directions:

1. **The urgency drops.** There is no plausible-but-wrong result on this path. The gap is real but
   visible, which moves it from "correctness hole" to "ergonomics and contract".
2. **The kernel's IEEE behaviour rests on the optimizer failing to see through an array
   subscript.** That is not a guarantee. This package has been caught by exactly that shape before:
   `factorial`'s overflow trap was incidental to an arithmetic result, and once inlined the
   optimizer deleted the multiply and its check together — a trap became `exit 0` under `-O`, and
   `Release Tests` went red on two platforms for a day before the cause was found.

So fast math is now off (`mathMode = .safe`, with `fastMathEnabled = false` below macOS 15), on
argument 2 rather than on any measured difference. §7 has the cost. **This is a judgement call and
is flagged as one** — the alternative, leaving the default and documenting the dependency, is
defensible and costs nothing.

### 2.2 The residue that no design removes

The kernel is Float32 and the interpreter is Float64, and **they do not agree on what zero is.**

| divisor, as `Double` | `Double` sees | `Float` sees | outcome |
|---|---|---|---|
| `1e-40` | non-zero | `1e-40` | both divide |
| `1e-45` | non-zero | `1e-45` | both divide |
| `1e-50` | non-zero | **`0.0`** | CPU divides, GPU divides by zero |
| `5e-324` | non-zero | **`0.0`** | CPU divides, GPU divides by zero |

A divisor that underflows Float32 makes the GPU raise an error the CPU never sees. The reverse also
exists: a quantity that overflows Float32 to `inf` can make a GPU `log` or `sqrt` argument
non-positive when the Double was fine.

`gpuNarrowingIssues()` (`4df8a678`) catches this for *constants*. It cannot catch it for a value
computed at run time, and nothing can, short of running the kernel in double precision.

**Therefore exact parity is not achievable and should not be promised.** §6 states the contract that
is achievable instead.

---

## 3. Why the kernel cannot simply throw

Metal has no exceptions, no `errno`, and no way to abort a dispatch from inside a thread. A thread
can only write to a buffer it was given. Every mechanism below is a variation on that one fact.

There is also no early exit worth having: threads run in SIMD groups, so one thread taking a branch
does not save the others any work, and stopping a dispatch mid-flight is not something Metal offers.
The kernel must finish; the question is only what it records on the way.

---

## 4. Options considered

### 4.1 Do nothing, document the divergence — viable, and weaker than it looks

Cheapest. Every divergence is an `inf` or a `NaN`, which a caller can test for, so nothing is
silently plausible. What it does not give is *attribution*: a `NaN` in the output could be
`sqrt(-1)`, `log(-1)`, `0/0`, or a model that legitimately produced one, and there is no way to
tell which, or at which iteration, or from which operation.

For a library whose CPU path names the operation and the reason, that is a real gap. It is not,
after §2.1, an emergency.

### 4.2 Turn off fast math — done, and it changes no result

Landed as part of this work. Measured to change nothing the kernel computes (§2); taken as
insurance against the optimizer's blindness ceasing to be blindness. See §7 for cost.

### 4.3 Sentinel value in the output buffer — rejected

Write a distinguished NaN payload per error kind. Avoids a second buffer, and NaN payloads do
propagate through arithmetic on Apple silicon. Rejected: payload propagation through a *chain* of
operations is not guaranteed by IEEE for all operations, fast math is free to discard it, and a
model may legitimately produce NaN, making the sentinel ambiguous with real data.

### 4.4 Make the CPU interpreter stop throwing — rejected

Would achieve parity by lowering the CPU to the GPU. It deletes information the CPU currently has
and moves the library toward returning plausible-but-wrong results, which is the failure this
codebase's rules exist to prevent. Rejected on principle, and it would also break
`0195cf31`, which has just finished making constant folding preserve exactly these errors.

### 4.5 A per-thread error buffer — recommended

One `device int*` of `iterationCount` entries, buffer index 8 (0–7 are taken). Each thread writes
`0`, or the code of the **first** condition it hits, and continues. The host reads the buffer back
alongside the outputs and decides what to do.

- Cost: one buffer allocation of `4 * iterations` bytes — for 1,000,000 iterations, 4 MB, against
  the 4 MB the outputs buffer already needs — and one store per thread.
- No branch divergence beyond the comparisons themselves, which are already cheap scalar tests.
- Composes with §4.2: safe math makes the conditions detectable, and the buffer makes them
  *attributable* — which operation, at which iteration.

---

## 5. Recommendation

**§4.5.** The error buffer, for attribution. §4.2 is already done and, per §2.1, buys correctness
of principle rather than of result.

The kernel checks before each of the three operations, rather than testing the result afterwards.
Testing afterwards cannot distinguish `log(0)` from a model that produced `-inf` honestly.

```c
// in evaluateModel, replacing `case OP_DIV:`
case OP_DIV: {
    float divisor = stack[stackPtr - 1];
    if (divisor == 0.0f) { recordError(err, ERR_DIVISION_BY_ZERO); }
    stack[stackPtr - 2] = stack[stackPtr - 2] / divisor;
    stackPtr--;
    break;
}
```

`recordError` keeps the first code and ignores later ones, so the reported error is the one that
happened first, matching the interpreter, which throws at the first and never reaches the rest.

Evaluation continues after recording. Stopping the thread would leave its output slot holding
whatever the buffer had, which is a second undefined value to explain; letting IEEE finish at least
leaves something whose provenance is understood, and the error code says not to trust it.

---

## 6. The contract

> On the GPU path, an error reports a condition **the kernel's own Float32 arithmetic encountered**.
> Because the kernel computes in single precision, it can encounter a condition the double-precision
> interpreter would not, and can miss one the interpreter would find. `gpuNarrowingIssues()` reports
> the constants where this is visible ahead of time; values computed at run time cannot be checked
> in advance. Where the two must agree exactly, use `evaluate(inputs:)`.

This is weaker than "the two agree", and it is the strongest statement that is true. Writing the
weaker true one is the point of §2.2.

---

## 7. What it costs

`GPUPerformanceBenchmark`, 100,000 iterations, three runs each, same machine and session:

| | runs (ms) | median |
|---|---|---|
| fast math, as shipped before this work | 392.7, 367.1, 376.1 | **376** |
| safe math | 625.3, 408.2, 373.7 | **408** |

Median difference about 8%, and the run-to-run spread (374–625 ms) is larger than the effect. The
honest summary is *somewhere between nothing measurable and roughly ten percent, on a benchmark too
noisy to resolve it further*.

Worth stating alongside: this benchmark reports the GPU at **1.2–1.4× the CPU**, not the "5–15×
after warmup" its own closing note claims. Whatever fast math is buying here, it is not the
difference between using the GPU path and not — which is what makes §2.1's judgement call an easy
one in one direction and an arguable one in the other.

The error buffer's own cost is not measured yet and is expected to be dominated by the allocation:
4 bytes per iteration, against the 4 the outputs buffer already needs.
**Measuring it is step 2 of §9, before any of the kernel work is committed to.**

## 8. The decision this proposal cannot make

**What does a partially-failed batch return?**

The interpreter evaluates one input vector and throws. A batch of a million has no obvious analogue.
Three candidates:

1. **Throw if any iteration failed**, naming the count, the first failing iteration and its
   condition. Faithful to the CPU, loudest, and discards 999,999 good results because one draw hit a
   pole.
2. **Return the results, and the per-iteration errors alongside them**, as
   `(values: [Float], errors: [GPUIterationError?])`. Keeps the data, and puts the decision where
   the domain knowledge is. Silent if a caller ignores the second element — which is exactly the
   fail-silent shape this library refuses elsewhere.
3. **Throw above a threshold, report below it.** Needs a threshold nobody can derive.

A tail-risk model that divides by a draw which is occasionally zero is a *badly specified model*,
and 1 says so. A model where one draw in 10⁶ legitimately hits a pole is a *normal* Monte Carlo
situation, and 1 makes it unusable.

Leaning to **1, with an explicit opt-out** — `runSimulation(..., onIterationError: .throw)` as the
default and `.collect` for callers who ask for the per-iteration detail. That keeps the default
honest and the escape hatch visible at the call site rather than in a return value someone may
never destructure.

**This is the question to settle before §9 starts.**

---

## 9. Build order

1. ~~Safe math (§4.2), alone.~~ **Done.** It changed no numerical result (§2.1), and landed with
   the per-opcode CPU/GPU differential §4.5 needs anyway — 22 opcodes, exact inputs fed through
   degenerate uniforms (`param1 == param2`), compared at Float32 tolerance.
2. **Measure the error buffer's cost** on the existing benchmark before building on it. If the
   allocation dominates at large iteration counts, reuse it through the existing buffer cache.
3. `GPUIterationError` and the error codes, in `GPUExecutionContract.swift` beside `GPUOpcode`, with
   the MSL codes generated from the Swift enum exactly as the opcodes now are.
4. Kernel: `recordError` and the three guards.
5. Host: read-back, and whichever of §8 is chosen.
6. Tests: one per condition, asserting the *case*, against both executors. Plus the Float32 boundary
   of §2.2 asserted as the documented contract rather than as a defect.

Steps 1 and 2 are independent of §8 and can start immediately.

---

## 10. What this proposal does not cover

- `power`: `pow(-8, 1/3)` is NaN in both and neither throws. No divergence, no work.
- The comparison opcodes' `1e-6f` epsilon against the interpreter's `1e-10`. A real divergence, and
  a different one — it makes `equal` answer differently, with no error involved. Belongs with the
  §4.5 per-opcode differential, filed separately.
- `MonteCarloCommon.h`, still a hand-maintained mirror that nothing compiles or checks.
