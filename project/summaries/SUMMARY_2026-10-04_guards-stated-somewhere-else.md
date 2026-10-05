# Guards that were stated somewhere else: a synthesised `>=`, and twenty-two divisors

**2026-09-29 to 2026-10-04** · shipped **v3.0.0-alpha.10** at `6dcad887` (8,962 tests / 835
suites · quality-gate 46/46, 0 errors, 0 warnings) and **v3.0.0-alpha.11** at `184f1583`
(8,975 tests / 837 suites)

Reconstructed on 2026-10-05 from the git history and the CHANGELOG; it is not a contemporaneous
note.

Six commits above `v3.0.0-alpha.9` (`e63b142a`), in two sittings five days apart. Both releases
are source-compatible and add no API. What they have in common is where the protection lived:
in alpha.10 an operator nobody wrote, in alpha.11 a bound or a comment that described some other
line than the one doing the division.

---

## What shipped

| | Commits | Content |
|---|---|---|
| **alpha.10**, 2026-09-30 | `0df5209c`, `6dcad887` | `FormattedValue` supplies `<=` and `>=`; three releases written up after the fact |
| **alpha.11**, 2026-10-04 | `b59f1bef`, `e1bc0011`, `42a180ea`, `184f1583` | 22 divisions reported by a wider `fp-division-unguarded`; three public functions return `.nan` for a zero divisor |

alpha.11 adds `ZeroDivisorRefusalTests` (9 tests) and `MomentFitZeroScaleTests` (4 tests), which
is the whole of the move from 8,962 / 835 to 8,975 / 837.

---

## Worth carrying forward

### 1. Swift's synthesised `<=` and `>=` invert on a NaN

`FormattedValue` declared `Comparable` with only `<`, so the inclusive operators came from the
defaults: `a <= b` as `!(b < a)`, `a >= b` as `!(a < b)`. Every comparison against a NaN is
false, so both negations answer true. A guard written `guard a >= b` fails *open*, admitting
what it was written to reject. Measured, from `0df5209c`:

    raw Double : nan >= x               -> false
    Date       : nanDate >= realDate    -> TRUE
    control    : Date(0) >= Date(1.7e9) -> false   // a real inversion IS still rejected

The CHANGELOG calls this the exception the contaminated-input campaign found last: the single
place where a NaN makes a guard succeed rather than fall through. The same shape had been live
in `Date`, where it let a contaminated date through `Period.custom`'s ordering guard and into an
unbounded loop. In `FormattedValue` it was prophylaxis, because no validation guard uses the
type yet, but the struct constrains `T: FloatingPoint`, so the hazard is never conditional.

Both operators now delegate to `rawValue`. The synthesis is a sound default for a total order
and wrong for IEEE ordering, which is not total. `==` was deliberately left alone: it already
delegates, so a NaN-valued instance is not equal to itself, exactly as a bare `Double` is not.

### 2. Three public functions answered a zero divisor with a figure

A wider `fp-division-unguarded` rule, one that follows a divisor back through
`let d = Double(n)` and treats a `Double` parameter as a divisor in its own right, reported 22
sites. Eighteen were already safe. Four sat in three public functions (`b59f1bef`):

- `bs(stockPrice:strikePrice:…)` returned the stock price for a strike of zero, because the
  log-moneyness was `+inf`. Finite, plausible, and not something the model computed.
- `applyAntiDilution` returned `+inf` shares for a new price of zero and, for a new price of
  `-1.0`, -10,000,000 shares (full ratchet) or -2,500,000 (weighted average). The CHANGELOG
  names the negative count as the worse of the two: finite, signed, and it would add into a cap
  table without complaint.
- `Lease.depreciation(period:)` returned `0 / 0` for a lease with no payments, or `+inf` once
  direct costs or a prepayment gave the right-of-use asset a value.

Each now returns `.nan`, which is how the neighbouring code in those files already refuses a
figure it cannot compute. `Lease.carryingValue(period:)` divided by the payment count before
looking the period up and then discarded the quotient when the period was off the schedule; it
looks first now, so that path answers as it always did. Red first: 6 of the 9 new tests failed
against the unguarded code, and the three that pin sound inputs passed before and after.

### 3. Put the bound on the divisor, not on what it was converted from

The other eighteen were safe by an argument made somewhere else, and now carry it where the
division is (`e1bc0011`, `42a180ea`). No result changes for any input that reached those lines.

- `Double(Swift.max(n, 1))` became `Swift.max(Double(n), 1)` in `multipleLinearRegression` and
  its validation, `MultivariateResample.columnMeans`, the rolling-variance iterator, and the
  DSL's `Vary` and `ScenarioAnalysis`. The same number, stated on the value being divided by.
- `RealEstateModel`'s zero-term `precondition` is on `numberOfPayments`, the divisor, rather
  than on `loanTermYears`. Same condition, same trap, same message.
- `DistributionMomentFit.transform` and `exponentialRawMoments` refuse a non-positive `delta`
  with `nan` themselves. The shape solve carries `delta` as a logarithm and never passes one;
  called directly, five cases had returned 0, 1 or an infinity for a `delta` of zero.

### 4. An `fp-safety:disable` marker that was a statement about a different function

`HestonProcess.computeP` carried `fp-safety:disable — strike validated positive by caller`.
`europeanCallPrice` does screen the strike, so the claim was true. It was still a claim about
another function, attached to the line that divides. The marker is gone and `computeP` checks
`strike > 0` itself (`e1bc0011`).

### 5. A guard the checker cannot read at file scope

`Examples/MultipleLinearRegressionExample.swift` already guarded its mean absolute residual with
a ternary, in top-level code. The widened rule does not read a guard at file scope, so the
calculation moved into a function, `meanAbsolute(_:)`, with the guard unchanged (`42a180ea`).

---

## Process

**Three releases had been tagged and never written up.** alpha.8 and alpha.9 were tagged on
2026-09-29 and reached neither `CHANGELOG.md` nor `project/master_plan.md`. The
contaminated-input campaign's 32 commits sat under `[Unreleased]`, and the plan's Last Updated
still read 2026-09-18 / alpha.7. `6dcad887` carved `[Unreleased]` into alpha.8, alpha.9 and
alpha.10, added all three to Current Status, and moved the README's test count from 7,908 to
8,962. As the plan now puts it: not a wrong statement, an absent one.

**Two irregularities were checked and found not to be drift**, so they were recorded rather
than retrofitted. alpha.4 has no CHANGELOG heading on purpose; its content is folded into
alpha.5's section under a note saying so. alpha.1 through alpha.3 have GitHub releases whose
git tags exist in no clone and not on the remote. The real gap ran the other way: alpha.4
through alpha.9 were tagged and never released on GitHub, and were backfilled on 2026-09-30.

**The gate's warnings were cleared at the root, not by annotation** (`6dcad887`).
`BusinessMathFallbackLogger` was public with no DocC, which is also what held documentation
coverage at 7934/7935. A test variable named `secret` tripped the credential checker; the test
is about account numbers, so it is now `accountNumber`. The checker was right about the name.

**Merged is not deployed.** On 2026-09-30 the baseline-truncation fix was merged to
quality-gate `main` at 10:32, and the next BusinessMath commit was still gated by the old
behaviour: `PASSED`, `17 of 46 checkers · 5 not selected · 24 NOT REACHED`. The installed binary
was dated Sep 29 10:00. The hook runs the artifact on `PATH`, not the source. The 46/46 figure
for alpha.10 comes from a standalone run with `--continue-on-failure` on the tagged commit.
Recorded in `feedback_merged_is_not_deployed`.

---

## Not done

- **No gate figure is recorded for alpha.11.** None of its four commits states one, and neither
  does its CHANGELOG section. The next recorded full run is the 2026-10-05 session's, at
  `fc986410`.
- **`ComparableInversionTests` raised a compiler warning under `--strict`** (`Double.nan >=
  1.7e9` is folded at compile time). Both releases shipped with it; it was fixed the following
  day. See `SUMMARY_2026-10-05_strict-build-warning.md`.
- `HestonProcess.computeP` keeps a second marker, `fp-safety:disable — numSteps is constant
  2000`, on the line below the one that was removed.
