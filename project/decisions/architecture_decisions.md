# Architecture Decisions — BusinessMath

This project's own decision log, extracted from the v1
`development-guidelines/rules/architecture_decisions.md` during the v2 migration.
The format is documented in `development-guidelines/rules/architecture_decisions.md`.


---

```yaml
id: ADR-001
date: 2026-09-04
status: accepted
category: api
title: Inverse transform is the distribution contract; other samplers are opt-outs
context: |
  DistributionRandom requires only next(). That is enough to run a simulation and not
  enough for anything else: a distribution cannot be checked against a reference CDF,
  cannot be inverted for an Excel-facing quantile, and cannot be handed a chosen point
  in the unit interval. The last of these blocks quasi-random sampling entirely, since
  a point set must be able to ask "what value sits at this coordinate".
decision: |
  ContinuousDistribution and DiscreteDistribution add cdf and quantile, and supply
  next(using:) by inverse transform. A conformer may override the sampler; doing so does
  NOT forfeit quasi-random eligibility, because the quasi-random path calls quantile
  directly and never consults next(using:).
rationale: |
  - The test template, the Excel quantile and the sampling seam are one requirement.
  - Eligibility becomes a compile-time property (does it conform?) rather than a
    convention (did it override a method?), so an unrelated refactor cannot break it.
  - Existing samplers keep their streams: DistributionNormal stays on Box-Muller and
    DistributionGamma on Marsaglia-Tsang rejection, and both remain eligible.
consequences: |
  Positive: 33 planned distributions are written against one contract and verified by one
  battery. Retrofitting the existing fifteen exposed four numerical defects.
  Negative: two new public protocols to support. Twelve of the fifteen needed new
  mathematics rather than a declaration, which was more work than the audit first
  suggested.
alternatives_rejected:
  - "Free functions only, no protocol: no seam for the point sets, and no generic battery."
  - "Put cdf/quantile on DistributionRandom: source-breaking for every conformer, and a
     lie for any distribution defined only by a sampling procedure."
  - "Generalise RandomNumberGenerator to a low-discrepancy source: silently wrong.
     Feeding successive Sobol coordinates to Box-Muller pairs dimension j with j+1 and
     destroys the equidistribution while producing numbers that look fine."
affected_files:
  - Sources/BusinessMath/Simulation/ContinuousDistribution.swift
  - Sources/BusinessMath/Simulation/DiscreteDistribution.swift
supersedes: null
amends: null
superseded_by: null
```

```yaml
id: ADR-002
date: 2026-09-04
status: accepted
category: architecture
title: Sobol uses Joe & Kuo (2008) direction numbers, vendored and capped at 256 dimensions
context: |
  Sobol sequences are not unique. Implementations differ by their primitive polynomials
  and initial direction numbers, and two that disagree produce entirely different point
  sets while both being valid. A sequence whose table is unstated cannot be reproduced
  against another tool, which is most of the reason to use a low-discrepancy sequence.
decision: |
  Vendor Joe & Kuo's new-joe-kuo-6.21201 as generated Swift source, capped at 256
  dimensions, generated from SciPy's bundled copy of the same table. State the choice in
  the type's documentation. Throw above the cap rather than reducing the dimension.
  Keep the origin: the half-cell offset every coordinate carries lifts it off zero, and
  skipping it would break the balance property over 2^m points.
rationale: |
  - Agreement with scipy.stats.qmc.Sobol becomes checkable, and is checked, against 1,984
    fixture cases.
  - Generated rather than typed: 256 polynomials and 4,608 direction numbers are not
    transcribed correctly by hand, and one wrong entry gives a sequence that still looks
    random.
  - A silently reduced dimension would answer a different question convincingly.
consequences: |
  Positive: reproducible against any tool using the same table. Roughly 20 KB of
  generated source.
  Negative: raising the cap means regenerating a file. The generator needs SciPy, though
  only at authoring time — CI never runs it.
alternatives_rejected:
  - "Vendor all 21,201 dimensions: megabytes of source for dimensions no financial model
     reaches."
  - "Compute direction numbers from first principles: the initial values are tabulated
     search results, not derivable."
  - "Skip the origin as SciPy advises: the offset already removes the infinity that
     advice exists for, and skipping costs the balance property."
affected_files:
  - Sources/BusinessMath/Simulation/Sampling/SobolSequence.swift
  - Sources/BusinessMath/Simulation/Sampling/SobolDirectionNumbers.swift
  - Scripts/reference-fixtures/generate_sobol_directions.py
supersedes: null
amends: null
superseded_by: null
```

```yaml
id: ADR-003
date: 2026-09-04
status: accepted
category: performance
title: Discrete sampling keeps two implementations, selected by sampling path
context: |
  Sampling an explicit pmf by inverting its CDF costs a search. Vose's alias method makes
  it O(1), and the obvious move is to use it everywhere.
decision: |
  The alias table serves the pseudo-random path through next(using:). The quasi-random
  path uses a monotone binary search through quantile(_:). Both are implemented; neither
  is used on the other's path.
rationale: |
  - The alias method is not monotone in its uniform: it maps the unit interval through a
    permuted table, so nearby uniforms land on distant outcomes.
  - The entire benefit of a stratified or low-discrepancy uniform is that a monotone
    transform carries the stratification through to the sample. Pushed through an alias
    table, the distribution is still correct and the variance reduction is gone — you pay
    for Sobol and receive pseudo-random convergence, with nothing in the output saying so.
  - O(log n) on a 1,000-outcome pmf is ten comparisons, which is not worth trading
    correctness for.
consequences: |
  Positive: O(1) on the default path, which is the common case, and correct convergence on
  the quasi-random one.
  Negative: two code paths per discrete distribution, and a rule a future contributor
  could break by "simplifying" quantile to use the table.
alternatives_rejected:
  - "Alias everywhere: silently forfeits the variance reduction under QMC."
  - "Binary search everywhere: pays O(log n) on the path where it buys nothing."
affected_files:
  - Sources/BusinessMath/Simulation/AliasTable.swift
  - Sources/BusinessMath/Simulation/DiscreteDistribution.swift
supersedes: null
amends: null
superseded_by: null
```

```yaml
id: ADR-004
date: 2026-09-04
status: accepted
category: testing
title: Reference fixtures are generated once, committed, and version-pinned
context: |
  Twenty-four of the planned distributions name scipy.stats as their authority, as do the
  quasi-random point sets. Generating those values ad hoc, per distribution, is how a
  parameterisation error becomes a passing test.
decision: |
  A committed generator script (Scripts/reference-fixtures/) produces JSON fixtures into
  the test bundle, with a MANIFEST recording the SciPy and NumPy versions and a sha256 per
  fixture. CI never executes Python. Parameter conversions are recorded as data inside the
  fixture. Every fixture with an independent authority also gets a spot-check against it.
rationale: |
  - A Swift suite that needs a working SciPy goes red for reasons unrelated to the library.
  - Distribution parameterisations change between SciPy releases — `reciprocal` became
    `loguniform` — and a version mismatch should be readable in a file, not debugged
    through a tolerance.
  - Writing a conversion in both the generator and the Swift implementation risks getting
    it wrong in the same direction twice, which is a green test and a wrong library.
    Recording it as data makes it reviewable in the diff.
consequences: |
  Positive: 2,680 reference cases with stated provenance. The convention extends to every
  remaining row of the coverage work list.
  Negative: regenerating requires a pinned Python environment; the test target gained a
  resources clause it did not have before.
alternatives_rejected:
  - "Call SciPy from the test suite: makes CI depend on a Python toolchain."
  - "Type expected values by hand: unreviewable, and the errors are invisible."
affected_files:
  - Scripts/reference-fixtures/
  - Tests/BusinessMathTests/Fixtures/
  - Tests/BusinessMathTests/Support/ReferenceFixture.swift
supersedes: null
amends: null
superseded_by: null
```

```yaml
id: ADR-005
date: 2026-09-04
status: accepted
category: architecture
title: Constants are derived where they can be derived, and deleted where they cannot
context: |
  Both special-function inverses opened with a textbook initial estimate — Wilson-Hilferty
  over a rational fit to the normal quantile, and Abramowitz & Stegun 26.5.22 — carrying
  nine decimal coefficients between them. Those are curve-fit output with nothing behind
  them, in a library whose other constants all have derivations.
decision: |
  A fitted constant whose only job is to seed a bracketed root-finder is deleted, and the
  bracket starts from a quantity the problem supplies — the distribution's mean. Format
  constants come from the format (a random draw's shift is
  UInt64.bitWidth - (significandBitCount + 1); its scale is ulpOfOne/2; iteration caps are
  the exponent range plus the significand width). A statistical critical value in a test is
  computed and then checked against the published table, so the table validates the
  derivation rather than substituting for it.
rationale: |
  - The fitted estimates bought a few iterations and cost several numbers no reader can
    check. All 344 SciPy reference cases still pass without them.
  - Derived format constants make the same code correct for Float.
  - A derived critical value can be asked for a different significance level; a quoted one
    requires another table.
consequences: |
  Positive: no unexplainable numbers in the new code. The Kolmogorov and chi-square
  derivations reproduce the published tables (1.22, 1.36, 1.52, 1.63, 1.95; 6.635 through
  50.892), which is itself a test.
  Negative: the root-finders take a few more iterations from a worse start.
  Exception: where a fitted constant IS the algorithm rather than a disposable guess —
  Acklam's minimax coefficients in inverseNormalCDF, Burley's scrambling multipliers — it
  stays, with its source named.
alternatives_rejected:
  - "Name the fitted coefficients and keep them: a named magic number is still one."
  - "Quote the statistical tables: unadjustable, and uncheckable by a reader."
affected_files:
  - Sources/BusinessMath/Statistics/SpecialFunctions/
  - Sources/BusinessMath/Simulation/ContinuousDistribution.swift
  - Tests/BusinessMathTests/Support/DistributionConformance.swift
supersedes: null
amends: null
superseded_by: null
```
