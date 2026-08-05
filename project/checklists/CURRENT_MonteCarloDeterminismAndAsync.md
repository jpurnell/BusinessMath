# Monte Carlo Determinism + Async Execution Checklist
**Created**: 2026-07-14
**Proposal**: `project/plans/upcoming/MonteCarloDeterminismAndAsyncExecution.md` (approved 2026-07-14)
**Target version**: 2.4.0

---

## Phase 0: Design Proposal ✅ COMPLETE
- [x] Proposal written, reviewed against auditor semantics and existing GPU seed path
- [x] User approved as proposed (correlated seeding deferred; async included)
- [x] Moved to UPCOMING/

## Phase 1: Tests (RED) ✅ COMPLETE
- [x] `SplitMix64Tests` — golden vectors vs Vigna's reference splitmix64.c (seed → first 3 outputs), Sendable, uniform range
- [x] `SeedableDistributionTests` — per-distribution: same seed → identical sample stream; seeded moments match distributional expectations (15 distributions)
- [x] `SimulationSeedTests` — CPU: same seed → identical `values`; different/nil seeds → differ; custom-sampler input + seed → `.seedingUnsupported`; correlationMatrix + seed → `.seedingUnsupported`
- [x] `SimulationSeedTests` (GPU, Metal-gated) — same seed → identical `values`; seed reaches kernel
- [x] `AsyncRunTests` — async `run()` seed-equivalent to sync; GPU async equivalence; cancellation throws `CancellationError` promptly

## Phase 2: Implementation (GREEN) ✅ COMPLETE
- [x] `SplitMix64.swift` (RandomNumberGenerator, Sendable)
- [x] `DistributionRandom<T>` primary associated type; `SeedableDistribution<T>` refinement
- [x] 15 distribution conformances (all concrete DistributionRandom structs) — extract math into `next(using:)`, `next()` delegates via SystemRandomNumberGenerator
- [x] `SimulationInput` — capture seeded sampler when distribution is seedable; expose `supportsSeeding`
- [x] `SimulationError.seedingUnsupported(inputName:details:)`
- [x] `MonteCarloSimulation.seed` + init params (defaulted); CPU seeded loop; GPU seed pass-through
- [x] `MonteCarloGPUDevice.runSimulation(...) async` — `addCompletedHandler` + checked continuation
- [x] `MonteCarloSimulation.run() async` — non-blocking GPU wait; `Task.checkCancellation()` + `Task.yield()` every 1,024 CPU iterations

## Phase 3: Refactoring ✅ COMPLETE (shared helpers extracted during GREEN; full suite green)
- [x] Deduplicate sync/async `run()` decision logic (shared helpers, no behavior change)
- [x] Full suite green after refactor

## Phase 4: Documentation
- [x] DocC on all new/changed public API (100% doc-coverage maintained)
- [x] Narrative article `DeterministicSimulationGuide.md` (determinism scope, per-path reproducibility, fallback caveat, async usage)
- [x] CHANGELOG 2.4.0 entry; README simulation section updated if needed

## Phase 5: Quality Gates
- [x] `quality-gate` 0 errors / 0 warnings (no suppressions)
- [x] Full test suite green
- [x] New ADR recorded (seedable refinement + async overloads)
- [x] Session summary in docs/sessions/
- [x] Commit (user pushes separately)
