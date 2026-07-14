# Session Summary — 2026-07-14 — Monte Carlo determinism + async execution (2.4.0)

## Goal
Implement the two follow-ups from the flaky-test session, per the approved design
proposal (`development-guidelines/02_IMPLEMENTATION_PLANS/UPCOMING/MonteCarloDeterminismAndAsyncExecution.md`,
ADR-005): reproducible seeded simulations, and an async `run()` that doesn't block
cooperative-pool threads on GPU waits.

## What shipped (2.4.0)
- **`SplitMix64`** — public seedable `RandomNumberGenerator`; golden-tested against
  Vigna's reference vectors (seed 0 → `0xE220A8397B1DCDAF`, plus seeds 42/1234567
  recomputed from the published algorithm).
- **`SeedableDistribution<T>`** refinement of `DistributionRandom` (which gained a
  primary associated type). All 15 concrete distributions conform; each draws every
  uniform from the caller's generator while preserving its probability law.
- **`MonteCarloSimulation.seed: UInt64?`** — GPU passes it to the existing kernel
  seed path; CPU samples through one SplitMix64. Seeded runs throw
  `SimulationError.seedingUnsupported` for custom-sampler inputs and correlated
  sampling (loud, never silently non-deterministic). `SimulationInput` gained a
  seeded-sampler capture via a more-specific init overload plus `supportsSeeding`.
- **`run() async`** — same decision logic/results as sync; GPU completion awaited
  via `addCompletedHandler` + checked continuation (no blocked thread; safe because
  buffer caching is disabled — each call owns fresh buffers); CPU loop checks
  cancellation and yields every 1,024 iterations.
- DocC article `4.5-DeterministicSimulationGuide` (curated in Part4-Simulation);
  ADR-005; CHANGELOG 2.4.0.

## Verification
- 63 new swift-testing tests across 7 suites, all passing (including Metal-gated
  GPU determinism and async-equivalence tests).
- Full regression suite: **5,927 tests in 520 suites, green** (124.6s).
- quality-gate: see commit (target 0 errors / 0 warnings).

## Implementation notes worth remembering
- **Marker-protocol cast trap**: `distribution as? (any SeedableDistribution<Double>
  & Sendable)` does not compile (Sendable is a marker protocol). Solution: a second,
  more-specific generic init `init<D: SeedableDistribution & Sendable>` that Swift
  prefers at concrete call sites — statically typed, no casts. Consequence: inputs
  constructed through generic code bound only to `DistributionRandom` (e.g.
  `ScenarioAnalysis.setDistribution`, `ProbabilisticDriver`) do not capture a seeded
  sampler and will throw `.seedingUnsupported` in seeded runs — documented v1 scope.
- **Async overload gotcha**: in async contexts a bare `run()` selects the async
  overload; calling the sync one requires a synchronous helper. Affected the
  equivalence tests themselves.
- **ChiSquared seeding**: the existing `gammaVariate` path silently falls back to
  unseeded `Double.random` when its seeds array runs out, so its seeded conformance
  is built from the defining law (sum of df squared standard normals) instead.
- Three test files carry their own private SplitMix64 copies
  (RankingStatisticsTests, MultivariateLBFGSTests, SparsePerformanceBenchmark,
  plus TestSupport/DeterministicHelpers) — consolidation onto the public
  `SplitMix64` is a cheap future cleanup.

## Deferred / follow-ups
- Seeding for correlated sampling (Iman-Conover) — throws `.seedingUnsupported` in
  v1; needs its own design pass.
- Seeded-sampler capture through generic `DistributionRandom`-bound call sites
  (would need the protocol requirement or runtime openings — revisit if
  ScenarioAnalysis users need seeded runs).
- `AsyncAlignedSequence` iterator still uses an unstructured producer Task with
  sleep-based startup — the async GPU path removes the main starvation source, but
  that iterator design is worth revisiting if stalls recur.
