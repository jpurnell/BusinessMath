# Contaminated-input contract

**Status:** active spec for the adversarial-input sweep
**Established:** 2026-09-27, from defects measured in commits `3898aafb` … `30055db4`

This is the behavioural contract every public API in BusinessMath must follow when it is
handed data it cannot compute with — principally `nan`, and secondarily an infinity where that
is not a legitimate observation.

It is **not** an invention. Every rule below was already being followed correctly somewhere in
the library; the sweep found the siblings that had drifted from it. Where this document and a
correctly-behaving existing function disagree, the existing function wins and this document is
wrong — say so rather than changing the function.

---

## 1. Why this needs writing down

The defect class is *inconsistency*. `Percentiles(values:)` refused contaminated input by
throwing while `ValueAtRisk.calculate` computed a confident number from it.
`Portfolio.sharpeRatio(weights:)` returned an infinity and documented why, while five
independently written siblings returned `0`.

So the hazard in fixing this in parallel is obvious: if each area decides for itself, the
result is a library where some functions throw, some return `nan`, and some return `0` — which
is *more* of the thing being removed, not less. Freeze the contract, then fan out.

---

## 2. The one fact underneath

**Every comparison involving `nan` is false, including `nan == nan`.**

It never raises and never fails loudly. It quietly answers *no*, and "no" is a valid answer
everywhere in Swift. Five structurally different defects came from this single fact:

| expression | what breaks | measured |
|---|---|---|
| `nan > 0` | a **guard fires** | `kurtosis` → `0` ("normal-tailed"); `VectorSpace.norm` → `0` ("a stationary point", per its own doc) |
| `nan < x` | `sorted()` is **unspecified** | `[3,1,nan,2,5,4].sorted()` → `[1,3,nan,2,4,5]` — *valid* elements out of order |
| `nan == nan` | `firstIndex(of:)` → `nil` | `rank()` returned a **shorter array**; `spearmansRho` trapped |
| `nan > 0` **and** `nan < 0` | **both arms skipped** | a cash flow vanished from `profitabilityIndex` / `mirr` |
| `nan >= 0` | a condition **never becomes true** | `paybackPeriod` → `nil` = "never pays back" |

Pure arithmetic is safe without help: IEEE propagates `nan` through `+ - * /` and through
`normalPDF`, `normalCDF`, `zScore`, `erf` (all verified). **Only control flow over the data is
dangerous.**

---

## 3. The contract

### 3.1 Non-throwing, returns a floating-point value

Return `.nan`.

Matches `mean`, `median`, `stdDev`, `Skewness`, `npv`, `npvExcel`, `geometricMean`.

```swift
guard !flow.isNaN else { return T.nan }
```

### 3.2 Throwing

Throw `BusinessMathError.dataQuality(message:context:)`, with `context` carrying the count of
offending elements.

Matches `Percentiles(values:)`, and now `spearmansRho`, `kendallsTau`, `mirr`,
`correlationCoefficient` and its population and sample forms.

```swift
guard values.allSatisfy({ $0.isFinite }) else {
    throw BusinessMathError.dataQuality(
        message: "<what this needs> requires finite observations",
        context: ["invalid_count": "\(values.filter { !$0.isFinite }.count)"]
    )
}
```

**Do not** reuse `divisionByZero` for contamination. It was doing that job by accident — a
`nan` denominator fails `> T.ulpOfOne`, so the zero-variance guard caught it and reported "one
or both variables have zero variance" for data with no constant column. Right action, wrong
diagnosis, and it sends a reader hunting for something that is not there.

### 3.3 Returns `Optional`

**Document, do not change the signature.** `Int?` cannot distinguish "no answer exists" from
"cannot be computed", and widening it is source-breaking. State the conflation at the call
site and in the DocC, and add a test pinning the documented behaviour.

Example: `paybackPeriod` / `discountedPaybackPeriod` answer `nil` for both "never pays back"
and "contaminated". Whether these should gain throwing forms is an open API decision, not a
fix to make in passing.

### 3.4 Returns an enum / classification

Use the existing "nothing detected" case, paired with zero confidence where the type has one.
**Never add an enum case** — that breaks exhaustive `switch` in consumers.

Example: `TrendDirection` has only `.upward` / `.downward` / `.flat`, so an unusable window
reports `.flat` with confidence `0`.

### 3.5 Returns a collection

**Preserve the length invariant.** A result with one element per input is a contract callers
index against. Mark the unusable position (`.nan`) rather than omitting it.

`rank()` omitted it, returned a shorter array, and `spearmansRho` indexed past the end and
trapped.

### 3.6 Infinities

Leave them alone unless they are genuinely unusable for the operation. They order correctly,
they are a legitimate observation in a return series, and several APIs now return them
deliberately — an unbounded Sharpe ratio at zero risk, an unbounded Altman component D for a
debt-free company. Screen infinity only where it breaks the specific computation (e.g. `fCDF`
throws on an infinite statistic).

### 3.7 Keyed by period

**Narrow the domain; do not fabricate the observation.** A lookup for a period the data does
not cover has no answer, and `?? T(0)` does not decline to give one — it reports a measured
zero. `altmanZScore` scored one solvent, profitable company 5.92 ("Safe Zone") for a covered
quarter and 0.00 — "Distress Zone (High bankruptcy risk within 2 years)", in its own DocC — for
the next quarter, which was simply outside the statements the caller had supplied.

Matches `TimeSeries.zip(with:)`, which emits only the periods present in both operands. It is
why every binary operation on a series is already right here, and why the multi-period
`altmanZScore` never had the defect its single-period sibling did.

```swift
guard let totalAssets = balanceSheet.totalAssets[period] else { return T.nan }
```

**Detection is not available, and the rule does not need it.** `TimeSeries.periods` is derived
from the value keys — `self.periods = valueDict.keys.sorted()` at `TimeSeries.swift:177`, and
`self.periods = data.keys.sorted()` again at `:264` — and `Period: Comparable` sorts
**type-first** (`Period.swift:1248`: type, then start date, then end date; the ladder is
`daily < monthly < quarterly < semiannual < annual < custom`), so `periods.first` / `.last` do
not bound a span. `subscript(period:)` is a plain dictionary lookup, so `nil` comes back
identically for a hole, for before the start, and for after the end. So the rule is about the
query rather than the gap: a period the data does not cover is not answerable, whichever kind
of absence it turns out to be.

The same fact has a second face on the way in. `init(periods:values:)` builds that dictionary,
so **duplicate periods collapse silently, last value wins**, and the series comes back shorter
than the array the caller passed with no diagnostic — twelve observations in, eleven out. That
is an input-validation question rather than a lookup one, and belongs to `init(validating:)` —
which today checks emptiness, count agreement and label count, but not duplicates — rather than
to this clause. It is recorded here because it has the same cause: the keys are the truth and
the caller's array is not.

**This needs no API change.** A function returning `T` says it with `.nan` (§3.1); one returning
a `TimeSeries` says it by leaving the period out of the result, as `zip` does; one returning
`Optional` documents it (§3.3). Where the return type has no room for "not answerable" at all —
`PiotroskiScore`, `FinancialPeriodSummary` — that is an API decision to take deliberately, not a
guard to add in passing.

---

## 4. Forbidden

- Silently **dropping** a value from an aggregation because it matched no branch.
- Substituting a **meaningful constant** — `0`, `1`, `1e10`, `1_000_000` — for "cannot
  compute". Zero is not neutral: it is *perfect agreement* for an error measure, *perfectly
  normal* for an anomaly score, and *mid-table* for anything ranked.
- Letting a **clamp** convert `nan` into a bound. `Swift.min(1.0, .nan)` returns **`1.0`**, so
  the idiomatic `Swift.max(0, Swift.min(1, x))` turns "unknown" into *maximum confidence*.
- Reporting contamination through a guard written for a **different** condition.

---

## 5. How to find sites

Grep the shapes, not the word "NaN". Counts are as of 2026-09-27.

```bash
# A — guard on a computed fp quantity with a benign fallback  (172 sites)
grep -rnE "guard [a-zA-Z.]+ > (T\(0\)|T\.zero|0(\.0)?) else \{ return (T\(0\)|T\.zero|0(\.0)?|nil|false) \}" Sources/ \
  | grep -viE "guard (n|count|size|len|length|dimension|rows|cols|periods|steps|iterations) >"

# B — two-way sign classification  (5 sites)
grep -rnE "if [a-zA-Z.]+ (>|<) (T\.zero|T\(0\)|0(\.0)?)" Sources/ -A 6 | grep -E "else if [a-zA-Z.]+ (<|>) "

# C — sorted() on a floating-point collection  (~20 files)
grep -rlE "\.sorted\(\)" Sources/ | xargs grep -lE "\[Double\]|\[T\]"

# D — clamp of a computed statistic  (2 sites)
grep -rnE "Swift\.(max|min)\(0(\.0)?, *Swift\.(min|max)\(1(\.0)?" Sources/
```

**A site is not a defect.** The question is never "can this be NaN" but:

> If a caller **ranks or thresholds** this result, where does the fallback land?

If the answer is "in the middle" or "at the good end", it is a defect. If the fallback is
genuinely the right answer — a proportion of an empty total really is `0` — leave it and say
why in a comment.

Two guards can be textually identical and one correct. In `altmanZScore`, `totalAssets == 0 →
0` is right (a firm with no assets belongs in the distress zone) while `totalLiabilities == 0
→ 0` was maximally wrong (debt-free is the safest balance sheet). Four lines apart. **Do not
"tidy" them into agreement.**

---

## 6. Method

1. **Probe before theorising.** Build a harness — a loop over `(name, closure)` printing
   `clean / nanFirst / nanMiddle` and flagging any *finite* contaminated result. One run found
   `kurtosis` and the `spearmansRho` crash together. Two hypotheses during this sweep were
   wrong and the probe settled both in minutes.
2. **Vary the position of the `nan`.** The defects are position-dependent: `var95` gave
   `nan` / `1.45` / `1.45` for first / middle / last, and `kendallsTau` on a contaminated pair
   returned *exactly* the clean coefficient. A single placement can look fine.
3. **Look for the correctly-guarded sibling** before choosing behaviour. It decided the
   contract four times here. If the sibling throws and the broken one does not, that asymmetry
   is usually the whole reason one complied.
4. **Write the test red first**, against the unfixed source, and keep controls that pass both
   before and after — they are what prove the suite discriminates rather than just failing.
5. **Measure control values, never recall them.** Two fabricated expected values were caught
   by tests during this sweep.

---

## 7. Verification

- Full suite green (`swift test`), not `--filter` alone.
- `quality-gate --no-cache --check all` → 45/45, **0 errors and 0 warnings**.
- **A gate run from a `.claude/worktrees/` path examines 0 files and prints PASSED.** An agent
  working in a worktree must not self-certify; the gate is run from the main checkout.
- Push, then verify by transfer (`git ls-remote`), never by exit status.
