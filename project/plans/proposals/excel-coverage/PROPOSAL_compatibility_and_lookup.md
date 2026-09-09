# Plan — the compatibility and lookup buckets

**Status:** plan, 2026-09-08. Written from measurement, not from reading the function names.
**Scope:** the 26 `compatibility` and 24 `lookup` rows still `unreviewed` in
`excel_function_coverage_matrix.tsv`.
**Audience:** whoever picks these up. Most of the work is BusinessMath's, which is why the plan
lives here.

---

## 1. The headline, because it reverses the obvious assumption

**Compatibility is not alias work, and it is not cheap.**

The obvious reading is that a compatibility function is the pre-2010 spelling of a function we
already have — `POISSON` for `POISSON.DIST` — so binding 26 of them is 26 lines in an alias
table. That reading is wrong twice over, and both errors point the same way.

**First: there is nothing to alias to.** Checked, all 26 modern counterparts, against the
registry source:

```
BETA.DIST BETA.INV BINOM.DIST CHISQ.DIST.RT CHISQ.INV.RT CHISQ.TEST
CONFIDENCE.NORM BINOM.INV EXPON.DIST F.DIST.RT F.INV.RT F.TEST
GAMMA.DIST GAMMA.INV HYPGEOM.DIST LOGNORM.INV LOGNORM.DIST NEGBINOM.DIST
PERCENTRANK.INC POISSON.DIST QUARTILE.INC T.DIST.2T T.INV.2T T.TEST
WEIBULL.DIST Z.TEST
```

**Every one is absent from the registry.** All 26 sit in the `statistical` unreviewed bucket
themselves. So compatibility is not a bucket of 26 cheap rows; it is 26 rows *downstream* of 26
rows that do not exist yet.

**But the mathematics mostly does.** An earlier draft of this section said compatibility was
downstream of *"26 rows of real distribution work"*, and that was wrong — it confused "absent from
the registry" with "absent from BusinessMath", which are different questions and the second was
never asked. Asked now, against BusinessMath's sources:

| | count |
|---|---:|
| upstream implementation confirmed | **24** |
| **genuinely absent** | **2** — `CHISQ.TEST`, `F.TEST` |

The first pass of this survey said 21 and named five as absent. Three of those five were false
negatives, and **the reason is worth carrying to the next survey**: the probe searched file
contents for *free functions* matching a name — `chiSquaredQuantile`, `lognormalQuantile`. But
`DistributionChiSquared.quantile(_:)` and `DistributionLogNormal.quantile(_:)` are **methods on
types**, and no keyword built from the distribution's name matches them. `BINOM.INV` is likewise
an accumulation over `binomialPMF`, which is what `PsiBinomial` already does.

A name-shaped probe finds free functions and misses methods. Every survey of this kind should
check the type as well as the symbol.

`betaCDF`, `chiSquaredCDF`, `binomialPMF`, `exponentialCDF`, `gammaCDF`, `poissonCDF`,
`studentTPDF`, `tQuantile`, `zStatistic`, `DistributionHyperGeometric` and
`regularizedLowerIncompleteGamma` are present as free functions;
`DistributionChiSquared.quantile`, `DistributionLogNormal.quantile` and `DistributionBeta` carry
theirs as methods.

So the work is **Excel-facing bindings over mathematics that largely exists** — argument order,
tail convention, error semantics — rather than writing distributions. That is a much smaller job,
and it is the binding layer's rather than BusinessMath's for most of the 26.

**The two genuine absences are hypothesis tests, not distributions.** `CHISQ.TEST` and `F.TEST`
each reduce to a statistic plus a tail over a CDF that already exists — but the *statistic* is
written nowhere, so they are honestly `unreviewed` rather than `bindable`. Calling them bindable
would overstate what is there.

**Caveat that still stands:** some hits in the confirmed column came from incidental matches —
`CHISQ.DIST.RT` first matched a file that *uses* chi-squared for Kendall's W, not one exporting a
reusable CDF. Each row wants confirming against the actual symbol before it is scheduled.

**Second: even once they exist, eight of the 26 are not aliases.** §2.

The practical consequence: **compatibility should not be scheduled as a batch at all.** It should
be a per-function follow-on, taken as each modern counterpart lands.

---

## 2. The eight that are not aliases

These are the ones where an alias entry would compile, answer, and be wrong. Grouped by why.

### 2.1 The legacy name means the *right-tailed* variant

| Legacy | Correct target | The trap |
|---|---|---|
| `CHIDIST(x, df)` | `CHISQ.DIST.RT` | **not** `CHISQ.DIST`, which is left-tailed |
| `CHIINV(p, df)` | `CHISQ.INV.RT` | **not** `CHISQ.INV` |
| `FDIST(x, df1, df2)` | `F.DIST.RT` | **not** `F.DIST` |
| `FINV(p, df1, df2)` | `F.INV.RT` | **not** `F.INV` |

Four functions whose modern spelling exists under a name that differs by three characters and
means the complement. An alias to the wrong one returns a probability in `[0, 1]` — plausible,
wrong, and reported by nothing. This is the same failure `PsiTarget` produced: the matrix recorded
`probabilityAbove` where the truth was `probabilityBelow`.

### 2.2 The legacy name is two-tailed and takes a `tails` argument

| Legacy | Correct target |
|---|---|
| `TDIST(x, df, tails)` | **dispatches**: `tails = 1` → `T.DIST.RT`, `tails = 2` → `T.DIST.2T` |
| `TINV(p, df)` | `T.INV.2T` — **not** `T.INV`, which is one-tailed |

`TDIST` is not an alias in any sense: it is a three-argument function that selects between two
different modern functions on its third argument. `TINV` looks like an alias and is off by a
factor of two in the tail.

### 2.3 The legacy name has no `cumulative` argument

| Legacy | Correct target |
|---|---|
| `BETADIST(x, α, β, [A], [B])` | `BETA.DIST(x, α, β, TRUE, [A], [B])` |
| `LOGNORMDIST(x, μ, σ)` | `LOGNORM.DIST(x, μ, σ, TRUE)` |

Both legacy forms are *always cumulative*. The modern ones take the flag as a required argument,
and it sits **in the middle** of the list for `BETA.DIST` — so the shim inserts an argument
rather than appending one. An alias here does not merely return the wrong value; it passes `[A]`
where `cumulative` is expected and the arity check may not even notice.

### 2.4 The remaining eighteen

Genuine aliases, once the target exists: `BINOMDIST`, `CHITEST`, `CONFIDENCE`, `CRITBINOM`,
`EXPONDIST`, `FTEST`, `GAMMADIST`, `GAMMAINV`, `HYPGEOMDIST`, `LOGINV`, `NEGBINOMDIST`,
`PERCENTRANK`, `POISSON`, `QUARTILE`, `TTEST`, `WEIBULL`, `ZTEST`.

Two are worth a second look even so: `CRITBINOM` → `BINOM.INV` and `LOGINV` → `LOGNORM.INV` are
renames rather than respellings, so nothing about the legacy name suggests its target. A person
scanning for a dotted equivalent will not find one.

---

## 3. What compatibility actually needs, in order

1. **The 26 modern statistical functions**, and for most of them this is a *binding* rather than
   a distribution: §1 found roughly 21 of 26 with upstream mathematics already present. What is
   missing is the Excel-facing layer — argument order, tail convention, and the `#NUM!` domain
   errors — which is this package's job and not BusinessMath's.

   The exception is `CHISQ.TEST` and `F.TEST`, which need a test statistic written before either
   can be bound. Everything else has its mathematics.
2. **Eighteen alias entries**, one line each, as their targets land.
3. **Eight shims** (§2), each with a test that would fail if it were written as an alias. That
   test is the deliverable, not the shim — the shim is three lines and the test is the thing that
   stops the next person "simplifying" it into the alias table.

**Do not schedule this as a bucket.** Take each compatibility row when its modern counterpart
lands, in the same commit. That keeps the pair together and makes the tail convention a decision
made once rather than rediscovered.

---

## 4. Lookup: one prerequisite, then most of it falls out

The 24 lookup rows split cleanly, and 18 of them share a single blocker.

### 4.1 Blocked on array return (18)

`CHOOSECOLS`, `CHOOSEROWS`, `DROP`, `EXPAND`, `FILTER`, `GROUPBY`, `HSTACK`, `PIVOTBY`, `SORT`,
`SORTBY`, `TAKE`, `TOCOL`, `TOROW`, `TRIMRANGE`, `UNIQUE`, `VSTACK`, `WRAPCOLS`, `WRAPROWS`.

Every one returns an **array**, not a scalar. The machinery for that mostly exists and is worth
naming so nobody rebuilds it:

- `CellValue.array(CellMatrix)` — the shaped value.
- `CellMatrix` — dimensions, which is what `TRANSPOSE` and the lookups needed and what v0.3.0's
  correction was about.
- `FormulaEvaluator.spill(_:over:…)` — one formula, evaluated once, filling a span.
- `BuiltinArrayFunctions` — `TRANSPOSE` and `COUNTBLANK`, the two that already do this.

So the prerequisite is not "build array support"; it is **decide the contract for a function that
returns a matrix of unknown size**. `TRANSPOSE`'s shape is determined by its input. `FILTER`'s and
`UNIQUE`'s are determined by their *data*, which the evaluator cannot know before evaluating. That
is a real design question and it is the whole of the work.

**Recommendation:** take `UNIQUE` and `FILTER` first, together, as the design spike. They are the
two most used, they are the simplest data-dependent shapes, and whatever contract they settle
carries the other sixteen. Do not start with `HSTACK`/`VSTACK` — their shapes are statically
known, so they would settle nothing.

### 4.2 Implementable now (1)

`XMATCH(lookup, array, [match_mode], [search_mode])` — returns a **position**, not an array. It is
`MATCH` with two extra modes: exact/next-smaller/next-larger/wildcard, and forward/reverse/binary
search. `MATCH` already exists and the shaped-array correction already landed, so this is a
self-contained afternoon.

**Take this one first.** It is the only lookup row that is not blocked, and it removes a name from
the bucket without waiting on a design decision.

### 4.3 Needs specific machinery, not arrays (2)

- **`AREAS(reference)`** — counts the areas in a reference. Needs a reference to survive as a
  *reference* through evaluation rather than collapsing to a value. Small, but it touches the
  evaluator's contract; worth its own decision.
- **`FORMULATEXT(reference)`** — returns a cell's formula as text. Notable because it is
  **nearly free and nobody would guess it**: the AST is already in `CellValue.formula(_, cached:)`,
  and SwiftXLSX has a `FormulaSerializer` that turns an AST back into a string. The only real
  question is whether that serializer round-trips faithfully enough to show a user.

### 4.4 Out of scope (3)

- **`RTD`** — a real-time data server. External process.
- **`IMAGE`** — fetches an image from a URL. Network.
- **`FIELDVALUE`** — reads from a linked data type. Network service.

All three belong where the cube and web functions already are, and should be marked
`out of scope` rather than left unreviewed. That is three rows resolved for the cost of a
decision.

---

## 5. Recommended order

| # | Work | Why here |
|---|---|---|
| 1 | Mark `RTD`, `IMAGE`, `FIELDVALUE` **out of scope** | Three rows resolved by a decision, not a commit |
| 2 | **`XMATCH`** | The only unblocked lookup row |
| 3 | **`FORMULATEXT`** | Nearly free, and the pieces already exist in two packages |
| 4 | ~~**Confirm the §1 survey**~~ **Done** — 24 of 26 confirmed upstream, 2 genuinely absent | Settled; step 5 is bindings, not distributions |
| 5 | The 26 **modern statistical** functions, mostly as bindings over existing math | The gate on everything in §3 |
| 6 | Compatibility, **paired with each target as it lands** | Never as a batch; §3 |
| 7 | `UNIQUE` + `FILTER` as the **array-return design spike** | Settles the contract for sixteen more |
| 8 | The remaining sixteen array functions | Mechanical once 7 is decided |
| 9 | `AREAS` | Needs the reference-survival decision; least urgent |

Steps 1–3 remove five rows without touching a distribution. Step 4 is done and settled the
question: step 5 is 24 bindings over existing mathematics plus two test statistics, not 26
distributions.

---

## 6. What this plan does not claim

The eight non-aliases in §2 are drawn from Microsoft's documented signatures, not from testing
against Excel — none of the modern targets exists yet, so there is nothing to test against. Each
should be confirmed against a published example when its target lands, and the confirmation is
what closes the row. ADR-001: reading a specification and asserting our reading of it proves only
that we read it the same way twice.

The array-return contract in §4.1 is described as a design question rather than answered, because
answering it without writing `UNIQUE` would be guessing about the case that matters.

---

**Next action:** step 1, which is a decision rather than a commit — and then `XMATCH`, which is
the only row in either bucket that nothing is blocking.
