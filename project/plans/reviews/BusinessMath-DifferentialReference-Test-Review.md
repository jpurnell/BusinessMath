# BusinessMath differential reference tests

*September 2026. Covers 6 files: NormalReferenceTests, DistributionCDFReferenceTests, QuantileType7ReferenceTests, TVMReferenceTests, BlackScholesReferenceTests, SamplerMomentReferenceTests — the TrustPlan §2.2 set. Companion to the twenty-one preceding domain reviews.*

*Every reference value in this batch was independently recomputed: A&S tables and Hull's examples with mpmath at 40–50 digits, the distribution tables with scipy, the quantile definitions by hand from Hyndman & Fan.*

## 1. Summary

These six files are the best work in the corpus, and they are the answer to the criticism the other twenty-one reviews have been making. Each one:

- **cites its source with enough precision to re-derive it** — A&S Table 26.1 with the NBS series number, Hull's chapter, Hyndman & Fan 1996 with journal, volume and page range, the specific Microsoft documentation example;
- **carries a tolerance table** giving the bound, what it covers, and the *measured* worst case underneath it;
- **separates the reference's precision from the code's** — the A&S 26.2 quantiles are asserted at 1e-9 "because the table prints 9 decimals; this is the reference's precision, not the code's. Measured worst case: 4.4e-16";
- **states what it checks without any reference at all** — round trips, symmetry, parity, monotonicity, affine equivariance — and says those are the strongest assertions because "nothing about them can be tuned."

**The sentence that matters most is in `NormalReferenceTests`:**

> "No tolerance in this file was chosen by loosening one that failed. Where the library disagreed with the reference the test was marked `withKnownIssue` with the measured magnitude, so that fixing the defect made the marker fail. Three such markers — §2.1's two `normalCDF` tail claims and the duplicate quantile — were removed when the defects were fixed, not when they became inconvenient."

That is the discipline this review series has been asking for, stated as policy and evidenced by three removed markers.

**I verified the hardest claim in the batch and it holds.** `NormalReferenceTests` asserts the A&S 26.1 CDF values at 1e-15 and says the measured worst case is 4.4e-16 at x = 3.5, which "is the table's truncation rather than the code's error — the same 4.4e-16 before and after the §2.1 fix." Computing P(3.5) = erfc(−3.5/√2)/2 at 50 digits gives 0.999767370920964475, while the table prints 0.999767370920964 — the printed entry is 4.75e-16 from the true value. So the residual really is the reference, not the implementation, and the diagnosis is correct.

The findings below are two small items in one file. Nothing structural.

### What each file's oracle is

| File | Oracle | Verified |
|---|---|---|
| NormalReferenceTests | A&S Tables 26.1 and 26.2, plus mpmath extensions and exact identities | All 10 CDF entries and both upper-tail entries confirmed at 50 digits |
| DistributionCDFReferenceTests | A&S 26.7–26.10 for χ², t, F; exact rationals for beta and exponential | χ²(3.841, 1) = 0.949986, t(0.975, 1) = 12.706204736, F(0.95, 5, 10) = 3.3258345, I₀.₅(2,3) = 11/16, I₀.₂₅(2,2) = 5/32, tCDF(1,1) = 3/4 — all confirmed |
| QuantileType7ReferenceTests | Hyndman & Fan definition 7, worked by hand | Every h and Q in the comments recomputed and correct |
| TVMReferenceTests | Microsoft's published NPV/PMT/XNPV/XIRR examples, textbook IRR | IRR 0.14488844278585600, XNPV 2086.6476, npvExcel 1188.4434123352230 — all confirmed |
| BlackScholesReferenceTests | Hull chapters 15 and 19 | d₁ = 0.769263, call 4.75942239, put 0.80859937; Δ 0.5216, Γ 0.06554, vega 12.105, Θ −4.305, ρ 8.907 — all reproduce Hull's printed figures |
| SamplerMomentReferenceTests | Inverse-CDF closed forms; analytic moments at five standard errors | Approach verified; see §3.3 |

## 2. Findings

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **`TVMReferenceTests`' header cites an expression that evaluates to the wrong number** | Line 26 records the provenance as `NPV(10%, 3000, 4200, 6800) - 10000 = 1188.44`. That expression is 1307.28775356875. Excel's actual documented example discounts *every* flow from t = 1, including the outlay: `NPV(10%, -10000, 3000, 4200, 6800)` = **1188.44341233522**, which is what the test body computes and what its own inline comment (line 97) states correctly. | Fix the header. The test is right; the provenance record is not, and the header is the part a reader consults to reproduce the value. Worth flagging because this is the same discounting convention that the time-series review found genuinely mis-asserted in `NPVTests.npvExcelDocumentationExample` (expects 13234.62; correct is 13233.25). This file getting the function right strengthens the case that the other test is wrong rather than the implementation. |
| 2 | **`excelExampleDates` falls back to the epoch** | `return parts.date ?? Date(timeIntervalSince1970: 0)`. The comment justifies it — "the Gregorian calendar always resolves these; the fallback keeps the helper total rather than trapping inside a test" — and the premise is true. But if it ever fired, the day offsets would silently become 0, 60, 303, 411, 456 measured from 1970, and the XIRR assertions would fail with a confusing message rather than a clear one. | Make the static `throws` and use `try #require`, or `preconditionFailure` with the components in the message. The file elsewhere is careful to make every failure legible; this is the one place a failure would not be. |
| 3 | **`monotoneInP` issues 1,001 expectations** | One per grid point, on a claim that either holds everywhere or fails at a specific p. | Accumulate the first violating p and assert once. Minor, and the same pattern the distribution review flags in `InverseNormalCDFTests` (200,000 sites) — this is a much milder instance. |

## 3. Techniques worth propagating

### 3.1 Pinning a convention by what it disagrees with

`QuantileType7ReferenceTests` opens with a table:

| definition | Q(0.4) on [15, 20, 35, 40, 50] |
|---|---|
| type 7 (R, NumPy default) | **29** |
| type 6 (Minitab, SPSS) | 26 |
| type 4 | 20 |
| nearest-rank | 20 or 35 |

"so a single assertion at that point distinguishes type 7 from the three most common alternatives." I recomputed h = 4(0.4) = 1.6 and Q = 20 + 0.6(35 − 20) = 29; the separation is real.

This is the "assert the property, then assert a sibling violates it" pattern from the interpolation review, applied to *conventions* rather than implementations — and it is the direct answer to the convention questions still open across the corpus. The statistics review found five percentile implementations in this library using two algorithms; this file's header names that as the reason it exists: "the question is not 'is this number plausible' but 'which of the nine published definitions is this'."

**The obvious next targets** are the conventions the other reviews left open, each of which has the same shape — several published definitions, all plausible, currently unpinned:

| Open convention | Where found | Discriminating case |
|---|---|---|
| `weightedPercentile`: type 5 vs type 7 | statistics review §2 item 1 | n = 7 equal weights at p = 0.25: type 5 gives 2.25, type 7 gives 2.5 |
| Skewness: biased g₁ vs adjusted G₁ | statistics review §3 | the 24-point fixture: −0.0577 vs −0.0616 |
| `weightedVariance`: frequency vs reliability weights | statistics review §3 | any non-integer weight set |
| Day count: DIO on 365 vs DSO on 150 | valuation batch 2 §2 item 3 | the two are internally inconsistent today |
| H-model: H as half-life vs decline period | valuation batch 1 §2 item 1 | 61.33 vs 48.00 — a 27% gap |
| Max drawdown: peak- vs trough-relative | risk review §2 item 1 | 29.17% vs 41.18% on the test's own series |
| Rolling variance: sample vs population | streaming review §4 | consecutive integers: 1.0 vs 2/3 |
| `confidenceInterval`: coverage vs CI of the mean | statistics review §2 item 3 | differs by √n |

Each of those is a one-file addition in exactly this style, and each would close a question that is currently answered only by whatever the implementation happens to do.

### 3.2 Recording that the published reference is wrong

`TVMReferenceTests`' XIRR test asserts against Excel's published 0.373362535 at 1e-8, then separately pins 0.37336253351883151 — noting that Excel's figure is "away from the exact root of the same equation." I confirmed the exact root is 0.373362533519, so Excel's published value is 1.5e-9 off.

That is the same handling `BesselFunctionsTests` gives SciPy's error at J₂₀₀(3000), and `NormalReferenceTests` gives A&S's truncation at x = 3.5. Three files, three different published sources found imprecise, each recorded rather than worked around. The pattern: **assert against the published figure at the published figure's precision, and pin the exact value separately.**

### 3.3 Derived rather than discovered statistical bounds

`SamplerMomentReferenceTests` states its rule plainly: each moment tolerance is "five standard errors of the estimator, computed from the distribution's own analytic moments — not chosen by running the test and rounding up," with SE = σ/√n for the mean and √((μ₄ − σ⁴)/n) for the variance, and the bands written out per case "so a reader can check the arithmetic."

Two details make it better than the same idea elsewhere in the corpus:

- **Five is justified, not assumed**: the sample is seeded, so one fixed number is being checked, and 5σ "makes the test insensitive to a change of generator while still failing on any systematic bias above ~0.5%." That is exactly the argument the distribution review makes for 4σ over 2σ, with the reasoning supplied.
- **Where the fourth moment does not exist — Pareto at α = 3 — the variance is not asserted, and "the reason is recorded rather than a band invented."** That is the same honest-skip discipline `LinearProgrammingCertificateTests` applies to degenerate duals and `HoltWintersReferenceTests` applies to its exactness conditions.

### 3.4 Two-sided table entries

`DistributionCDFReferenceTests`' chi-squared test explains its arrangement: "feed the *published quantile* and require the *published probability* back. Both halves of the pair are citable, so neither can drift to accommodate the other."

That is a stronger use of a table than asserting a CDF at an arbitrary x, because the pair (3.841, 0.95) is published as a pair. I confirmed χ²(3.841, 1) = 0.949986316236 — the table's 3.841 is itself rounded, which is why the test's 1e-3 band on the published entry is right and its 1e-14 band applies to the extended-precision values.

## 4. What these files establish about the defects they were written for

Each header records a defect the file now pins, and the descriptions are specific enough to be useful:

**`inverseNormalCDF` was discontinuous for months** — "it jumped from 0.30 to 1.372 at u = 0.6, making an entire interval of outputs unreachable — and it survived because nothing in the suite compared it to a known-good answer. A tolerance test against the library's own output cannot catch that." That last sentence is the thesis of this whole batch.

**Five empirical percentile implementations coexisted**, using two different algorithms. `orderStatisticsAreReachable` sweeps p = i/(n−1) for every index and notes it "is the sweep that would have caught the inverse CDF's unreachable interval had it been applied there."

**Black-Scholes routed through an A&S 7.1.26 polynomial** accurate to ~1.5e-7 in erf, worth 6.25e-4 of price error on an index-scale option. The file's 1e-13 band is chosen so "a regression to it fails here rather than showing up in someone's hedge." I confirmed Hull's Chapter 15 call is 4.75942239287153 against Hull's printed 4.76, so the polynomial's 6e-4 error is seven orders outside the new band.

**`irr` and `xirr` shared an absolute stopping rule** that broke scale invariance — `xirrIsScaleInvariant` notes "`xirr` had the same absolute stopping rule as `irr` and the same two problems."

## 5. Coverage gaps

These files cover the normal, the main continuous CDFs and quantiles, the empirical quantile, TVM, Black-Scholes and the samplers' moments. What a §2.2-style file does not yet exist for:

1. **The eight open conventions in §3.1.** This is the highest-value extension and the most mechanical, since each needs one discriminating fixture rather than a new oracle.
2. **The non-central distributions.** The statistics review found ncx2, ncf and nct asserted at 0.02 against seven-digit references (0.706648647777453, 0.524036069210168, 0.807611562530375). Power analysis depends on them and they are the loosest numeric assertions left in the library.
3. **Greeks beyond Hull's Chapter 19 set.** `BlackScholesReferenceTests` covers Δ, Γ, vega, Θ, ρ at one point. The options review notes the 13-case reference table in `BlackScholesNormalCDFAccuracyTests` covers prices only; extending that table to the Greeks would give the same coverage at 13 points instead of one.
4. **Bond analytics.** The valuation review found price, duration and convexity asserted as 300-point bands where exact values exist (1163.5143334460, 7.8949973402, 71.7853980), and convexity has a period-squared versus year-squared convention that a 200-wide band hides.
5. **The ANOVA and mixed-model families.** The statistics review lists `generalizedGStudy`, `nestedANOVA`, `multiWayANOVA`, `nakagawaR2` and the LME diagnostics as oracle-free, with `statsmodels` as the natural source.

## 6. Recommended order of work

1. **Fix the `TVMReferenceTests` header expression** (§2 item 1) and make the date helper throwing (§2 item 2). Both are small; the first matters because it is a provenance record.
2. **Write a convention-pinning file per open question in §3.1.** `QuantileType7ReferenceTests` is the template, and each needs only a discriminating fixture plus the published definitions. This closes eight questions that currently have no answer other than the implementation's behaviour.
3. **Extend the non-central distributions** into this style (§5 item 2) — the loosest remaining numeric assertions in the library.
4. **Extend the Black-Scholes Greeks** to the 13-case table (§5 item 3).
5. **Add bond analytics** (§5 item 4).
6. **Accumulate the 1,001-expectation loop** (§2 item 3).

## 7. Gate rules

No violations to report. Three positive patterns from this batch belong in the gate's positive-pattern list, which the reviews have been accumulating:

**A tolerance table in the suite doc comment.** Bound, coverage, justification, measured worst case. This is checkable statically in a weak form: a suite whose assertions use more than one distinct tolerance literal should have a doc comment mentioning each. More usefully it is a review checklist item, and these six files show what it looks like when done completely.

**Provenance with enough detail to re-derive.** Not "from SciPy" but "mpmath 1.4.1 at 50 decimal digits, leading digits checked against A&S 26.1." The fixture-coverage report should record, per reference file, whether the source is named to that standard.

**A statement that no tolerance was loosened to pass.** The `withKnownIssue`-then-remove workflow is what makes that claim verifiable, and this batch demonstrates it three times over. The gate already proposes requiring `.bug(…)` on `.disabled`; the complement is worth noting — a `withKnownIssue` that starts failing is the signal a defect got fixed, and Swift Testing reports it, which is why the risk review could point to the CVaR marker's removal as evidence rather than as a claim.

## Appendix. Verified reference values

### A.1 A&S Table 26.1 — P(x), standard normal

Computed as erfc(−x/√2)/2 at 50 digits. The right-hand column is how far the table's printed entry sits from the true value, which is the floor on any test asserting against the table.

| x | P(x), 18 digits | Table entry error |
|---|---|---|
| 0.0 | 0.5 | 0 |
| 0.5 | 0.691462461274013104 | 1.0e-16 |
| 1.0 | 0.841344746068542949 | 5.1e-17 |
| 1.5 | 0.933192798731141934 | 6.6e-17 |
| 2.0 | 0.977249868051820793 | 2.1e-16 |
| 2.5 | 0.993790334674223865 | 1.4e-16 |
| 3.0 | 0.998650101968369905 | 9.5e-17 |
| 3.5 | 0.999767370920964475 | **4.7e-16** |
| 4.0 | 0.99996832875816688 | 1.2e-16 |
| 5.0 | 0.999999713348428121 | 1.2e-16 |

Upper tail: Q(1) = 0.158655253931457051, Q(2) = 0.0227501319481792072. Quantile: z(0.975) = 1.95996398454005.

The x = 3.5 row is the file's measured worst case, and it is the table's own truncation.

### A.2 Distribution tables

| Entry | Value |
|---|---|
| χ²CDF(3.841, df 1) | 0.949986316236043 |
| χ²CDF(18.307, df 10) | 0.949999410908602 |
| χ²CDF(23.209, df 10) | 0.989999134185259 |
| t quantile(0.975, df 1) | 12.706204736174694 |
| t quantile(0.975, df 10) | 2.228138851986274 |
| t quantile(0.95, df 1) | 6.313751514675037 |
| F quantile(0.95, 5, 10) | 3.3258345304 |
| F quantile(0.95, 1, 1) | 161.4476387976 |
| F quantile(0.95, 2, 3) | 9.5520944959 |
| I₀.₅(2, 3) | 11/16 = 0.6875 exactly |
| I₀.₂₅(2, 2) | 5/32 = 0.15625 exactly |
| tCDF(1, df 1) | 3/4 exactly (Cauchy) |
| 1 − e⁻¹ | 0.6321205588285577 |

### A.3 Quantile type 7

n = 10 on 1…10, h = 9p:

| p | h | Q | exact in binary |
|---|---|---|---|
| 0.00 | 0.0 | 1 | yes |
| 0.10 | 0.9 | 1.9 | no (0.9 and 0.1 both round) |
| 0.25 | 2.25 | 3.25 | yes |
| 0.50 | 4.5 | 5.5 | yes |
| 0.75 | 6.75 | 7.75 | yes |
| 0.90 | 8.1 | 9.1 | no |
| 1.00 | 9.0 | 10 | yes |

n = 5 on [15, 20, 35, 40, 50], h = 4p: Q(0.05) = 16, Q(0.30) = 23, **Q(0.40) = 29**, Q(0.50) = 35, Q(0.75) = 40.

### A.4 Time value of money

| Quantity | Value |
|---|---|
| `npv(0.10, [-1000, 500, 400, 300, 100])` | 78.819752749129158 |
| IRR of the same flows | 0.14488844278585600 |
| `npvExcel(0.10, [-10000, 3000, 4200, 6800])` | 1188.4434123352230 (Excel prints 1188.44) |
| PMT(8%/12, 10, 10000) | 1037.03208936 (Excel prints −1037.03) |
| 30-year mortgage, 200k at 6% | 1199.10105031 (published 1199.10) |
| XNPV(9%) on Microsoft's example | 2086.64760203 (published 2086.6476) |
| XIRR on the same | **0.37336253351883151** (Excel publishes 0.373362535 — 1.5e-9 off) |
| Day offsets for the XIRR dates | 0, 60, 303, 411, 456 |

### A.5 Hull's Black-Scholes examples

Chapter 15 — S = 42, K = 40, r = 10%, σ = 20%, T = 0.5:

| Quantity | Exact | Hull prints |
|---|---|---|
| d₁ | 0.769263 | 0.7693 |
| d₂ | 0.627841 | 0.6278 |
| Call | 4.75942239287153 | 4.76 |
| Put | 0.808599372900094 | 0.81 |

Chapter 19 — S = 49, K = 50, r = 5%, σ = 20%, T = 20/52:

| Greek | Exact | Hull prints |
|---|---|---|
| Call | 2.40052732327 | 2.40 |
| Δ | 0.52160466 | 0.522 |
| Γ | 0.065544039 | 0.066 |
| vega | 12.10548 | 12.1 |
| Θ (per year) | −4.3053298 | −4.31 |
| ρ | 8.9069619 | 8.91 |

The A&S 7.1.26 polynomial this replaced misses the Chapter 15 call by about 6e-4 — seven orders outside the file's 1e-13 band.
