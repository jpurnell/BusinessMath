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

```yaml
id: ADR-006
date: 2026-11-12
status: accepted
category: architecture
title: Weighted graphs and graph measures live in Network/
context: |
  The ClassGraph app carries its own MIT-licensed package (SwiftGraphMetrics) that duplicates
  part of Network/ and adds a validated undirected weighted graph, weighted measures, Burt's
  constraint, diffusion, p-median siting and a metric record layer. The NetworkAnalysis plan
  (section 8) already said graph algorithms belong in BusinessMath; the duplication was an
  oversight. The owner decided on 2026-11-12 that the code moves under BusinessMath's licence
  and that ClassGraph may depend on the full package.
decision: |
  WeightedGraph<Node> is a new type beside Graph in Sources/BusinessMath/Network/Weighted/.
  Graph is not modified. Weights stay Double so stored records reproduce bit for bit. Public
  type and member names, metric identifiers, metric versions and the Codable shape of every
  record are preserved from the prior package, so later steps and the ClassGraph cutover are
  source-compatible. Weights are validated once, at construction (NaN, infinite and negative
  are refused; sums that overflow are refused; zero is legal). Behaviour the prior package
  changed silently is changed here only by explicit metric-version bumps, each with its own
  test and ADR note. The 19 proposed type names were checked for collisions by grep on
  2026-11-12 and none collides; if one does later, the fallback is a caseless namespace
  (Network.Centrality), decided here rather than ad hoc. Test support moves to Tests/TestSupport.
rationale: |
  - One implementation of each measure to keep correct, under this repository's gate.
  - Additive: no existing public API changes, so adoption is incremental.
  - Index-based adjacency keeps the inner loops fast; a protocol over both graph types would
    put dispatch in them.
consequences: |
  Positive: the duplicate package can be retired; weighted ties are representable.
  Negative: a larger module; two graph types with partly duplicated algorithms until a shared
  protocol is justified. WeightedGraph<T: Real> later would be source-breaking (recorded
  trade-off). Nothing here has been built on Linux CI at the time of writing.
alternatives_rejected:
  - "Add weights and an isDirected flag to Graph: changes a public struct used by DependencyGraph and BipartiteProjection and forces every algorithm to be re-specified."
  - "A GraphProtocol over both graph types: protocol dispatch in hot loops and a larger rewrite; may be revisited once both types exist."
  - "Keep a separate package: recreates the duplication the NetworkAnalysis plan rejected."
affected_files:
  - Sources/BusinessMath/Network/Weighted/
  - Tests/BusinessMathTests/Network Tests/Weighted/
  - project/plans/upcoming/NetworkWeightedGraph.md
supersedes: null
amends: null
superseded_by: null
```

---

```yaml
id: ADR-007
date: 2026-11-12
status: accepted
category: behaviour
title: Burt's constraint ignores zero-weight ties; topology measures count them; scheduled behaviour changes
context: |
  The weighted measures (Centrality, Community, Brokerage) were ported from SwiftGraphMetrics
  (SGM) in step 2 of ADR-006 with behaviour, tie-breaking, tolerances, ceilings, normalisation and
  public names unchanged, because stored metric records (eigenvector-centrality v4, pagerank v2,
  and the rest) depend on them. Two things in that code need a recorded decision rather than a
  silent inheritance. First, SGM's own ADR-003 chose that a tie recorded with weight zero is not a
  tie for Burt's constraint, while the topology measures read the same edge as a tie, so one graph
  answers "is a-c a tie?" differently depending on the measure. Second, several behaviours would
  be rejected by the fail-silent principle in coding_rules.md if written fresh. They are ported
  as they are, and this record lists them so they are known, scheduled and closed on purpose.
decision: |
  1. Burt's constraint (Brokerage.constraint) ignores zero-weight ties. A contact is a neighbour
     with a tie of positive weight; adding a zero-weight edge to a graph changes no node's
     constraint, and a node whose every tie is zero is omitted from the result like an isolate.
     This follows Burt (1992) and differs from networkx.constraint, which counts a zero-weight
     neighbour as a contact that receives only indirect investment (for a-b = 1, a-c = 0, b-c = 1,
     networkx gives a the constraint 1.25; this gives 1). The dense-matrix oracle in the tests
     reads it the same way, and the reference fixtures that compare with networkx must exclude
     graphs containing zero-weight ties.
  2. Degree (which sums weights, so a zero-weight tie adds nothing), clustering, k-core, connected
     components, betweenness, closeness and harmonic closeness count a zero-weight edge as an
     edge, because WeightedGraph stores it as one and they read topology. This is a recorded
     inconsistency, not a design: a zero-weight edge is a tie to the topology measures and not a
     tie to Burt. It is kept because changing either side moves stored records; WeightedGraph
     documents that a zero weight is a recorded tie that carries no strength.
  3. Known fail-silent behaviours ported as they are, each closed explicitly, with a metric-version
     bump and its own red test, in the step shown (phasing table of NetworkWeightedGraph.md):
     - PageRank returns the last iterate at its ceiling, converged or not, with no flag
       (pagerank v2): step 4, measured first (PageRankConvergence plan; at defaults 200 passes
       suffice, so this bites only for damping near 1 or a small maxIterations).
     - PageRank clamps damping into [0, 0.999] instead of refusing it: step 4.
     - PageRank with a NaN damping returns NaN scores: step 4 (NaN damping rejection).
     - Modularity skips nodes absent from the partition, and does not notice nodes the graph does
       not have, where the unweighted Graph.modularity(of:) returns nil: step 4 (partition
       validation).
     - Eigenvector centrality does not refuse a disconnected graph: it scores the dominant
       component and leaves every other node near zero (not exactly zero: the others decay with
       each pass), where the unweighted version returns nil
       (listed in section 6 of the plan; the phasing table row for step 4 names three of these
       and this one rides with them): step 4.
     - Eigenvector centrality at its iteration ceiling returns the last iterate without a marker
       from eigenvector(_:maxIterations:tolerance:); eigenvectorConvergence reports it, and the
       registered metric reports it through the convergence record: closed by the metric layer in
       step 3, not by a change here.
     Recorded without a scheduled change, for review in step 4: Louvain does not validate
     resolution (NaN or negative) and treats maxPasses below one as one; an edgeless graph scores 1
     for every node under eigenvector centrality (documented as the absence of a ranking); Louvain
     builds each contracted level's adjacency from a Dictionary, so neighbour order, and with it
     the floating-point summation order of a super-node's degree, depends on the per-process hash
     seed. The 1e-12 move threshold absorbs this on every fixture tested, but the order is not
     fixed by the code.
rationale: |
  - Stored records must not move silently: a measure that changes its answer inside a code move
    makes every older record incomparable with newer ones.
  - Leaving the behaviours unrecorded would let the port read as an endorsement of them. Listing
    them with the step that closes each keeps the plan honest about where it departs from the
    fail-silent principle.
  - Ignoring zero-weight ties in Burt is what the source text defines (contacts are the people a
    node has a tie to) and what a zero-strength tie means; counting them in the topology measures
    is what an undirected graph that stores the edge does. Choosing one reading for both would
    have changed stored values on one side.
consequences: |
  Positive: the port is verifiably identical to the source (bit-for-bit golden test), the
  inconsistencies are written down, and each has an owner step.
  Negative: until step 4, a caller can get a plausible number from an unconverged PageRank, a
  clamped damping, a partial partition or a disconnected eigenvector; the doc comment of each
  measure says so. Burt and the topology measures disagree about zero-weight ties.
alternatives_rejected:
  - "Fix the fail-silent behaviours during the port: moves stored records inside a code move, which the plan's phasing exists to prevent."
  - "Make Burt count zero-weight ties like networkx: changes stored constraint values and departs from Burt (1992)."
  - "Make every topology measure ignore zero-weight edges: changes stored degree, k-core, component and path-based records, and zero-weight edges are legitimately recorded ties."
affected_files:
  - Sources/BusinessMath/Network/Weighted/WeightedCentrality.swift
  - Sources/BusinessMath/Network/Weighted/WeightedCommunity.swift
  - Sources/BusinessMath/Network/Weighted/BurtConstraint.swift
  - Tests/BusinessMathTests/Network Tests/Weighted/
  - project/plans/upcoming/NetworkWeightedGraph.md
supersedes: null
amends: null
superseded_by: null
```
