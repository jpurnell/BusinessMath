# Design Proposal: Monte Carlo Determinism + Non-Blocking Execution

**Date:** 2026-07-14
**Status:** PROPOSED

---

## 1. Objective

Two defects observed during the 2026-07-14 quality-gate session
(`docs/sessions/2026-07-14-flaky-gpu-conditional-test.md`):

1. **No determinism**: `MonteCarloGPUDevice.runSimulation` already accepts
   `seed: UInt64?`, but `MonteCarloSimulation` never exposes it and the CPU path has
   no seeded sampling at all. Simulation tests therefore roll dice on every gate run
   (root cause of the flaky `min > 0` failure).
2. **Blocking GPU wait**: `MonteCarloGPUDevice.executePipeline` blocks with
   `commandBuffer.waitUntilCompleted()` inside the synchronous `run()`. Called from
   async contexts (swift-testing runs suites concurrently), this pins
   cooperative-pool threads and starves unrelated tasks — the plausible mechanism
   behind the one-off `StreamAlignmentTests` 60s stall.

**Master Plan Reference:** Simulation & Risk Analytics (existing module hardening).

## 2. Proposed Architecture

**New Files:**
- `Sources/BusinessMath/Simulation/SplitMix64.swift` — seedable
  `RandomNumberGenerator` (published algorithm with reference test vectors)
- `Sources/BusinessMath/Simulation/SeedableDistribution.swift` — protocol refinement

**Modified Files:**
- `Sources/BusinessMath/Simulation/DistributionRandom.swift` — add primary
  associated type `<T>` (source-compatible)
- 19 distribution files (`distributionNormal.swift`, `DistributionUniform`, …) —
  adopt `SeedableDistribution` by extracting the existing math into
  `next(using:)`; `next()` delegates through `SystemRandomNumberGenerator`
- `Sources/BusinessMath/Simulation/MonteCarlo/SimulationInput.swift` — capture an
  optional seeded sampler at init
- `Sources/BusinessMath/Simulation/MonteCarlo/MonteCarloSimulation.swift` — `seed`
  property + async `run()` overload
- `Sources/BusinessMath/Simulation/MonteCarlo/GPU/MonteCarloGPUDevice.swift` —
  async `runSimulation` variant awaiting `addCompletedHandler`
- `Sources/BusinessMath/Simulation/MonteCarlo/SimulationError.swift` — new case

**Module Placement:** all within the existing `Simulation/` module.

## 3. API Surface

```swift
// New: seedable RNG with published reference vectors (Vigna, 2015)
public struct SplitMix64: RandomNumberGenerator, Sendable {
    public init(seed: UInt64)
    public mutating func next() -> UInt64
}

// DistributionRandom gains a primary associated type (source-compatible):
public protocol DistributionRandom<T> { associatedtype T: Real; func next() -> T }

// New refinement — existing conformances opt in; external conformers unaffected:
public protocol SeedableDistribution<T>: DistributionRandom {
    func next<G: RandomNumberGenerator>(using generator: inout G) -> T
}

// MonteCarloSimulation — additive, defaulted (API-compatible):
public struct MonteCarloSimulation: Sendable {
    /// Seed for reproducible runs. `nil` (default) preserves current behavior.
    public var seed: UInt64?

    public init(iterations: Int, enableGPU: Bool = true, seed: UInt64? = nil,
                model: @escaping @Sendable ([Double]) -> Double)
    public init(iterations: Int, enableGPU: Bool = true, seed: UInt64? = nil,
                expressionModel: MonteCarloExpressionModel)

    public func run() throws -> SimulationResults          // existing, unchanged
    public func run() async throws -> SimulationResults    // NEW async overload
}

// SimulationError — new case:
case seedingUnsupported(inputName: String, details: String)

// MonteCarloGPUDevice — async variant (existing sync method unchanged):
public func runSimulation(distributions: [DistributionConfig],
                          modelBytecode: [ModelOperation],
                          iterations: Int,
                          seed: UInt64? = nil) async throws -> [Float]
```

### Semantics

- **Seed + GPU**: passed straight to the existing kernel seed path. Same seed, same
  iteration count, same machine → identical results.
- **Seed + CPU**: one `SplitMix64` drives the whole loop through each input's seeded
  sampler (captured at `SimulationInput` init when the distribution conforms to
  `SeedableDistribution`). Same seed → identical results.
- **Seed + custom-closure input (or non-seedable distribution)**: `run()` throws
  `.seedingUnsupported` — loud, not silently non-deterministic.
- **Seed + correlationMatrix**: v1 throws `.seedingUnsupported` (correlated path has
  its own sampling; deferred).
- **GPU→CPU fallback under a seed** still occurs and is recorded in
  `executionNotes`; determinism is guaranteed *per execution path*, and GPU/CPU
  produce different (each internally reproducible) streams. Documented.
- **Async `run()`**: identical decision logic to sync `run()`; the GPU wait becomes
  `await` on `addCompletedHandler` (no blocked thread); the CPU loop calls
  `Task.checkCancellation()` and `Task.yield()` every 1,024 iterations, surfacing
  `CancellationError` (consistent with the v2.3.1 cancellation work). Existing sync
  `run()` behavior is untouched.

## 4. MCP Schema

**Tool Description:** Run a Monte Carlo simulation with optional deterministic seed.

**REQUIRED STRUCTURE (JSON):**
```json
{
  "iterations": 10000,
  "seed": 42,
  "enableGPU": true,
  "inputs": [
    {"name": "Demand", "type": "normal", "parameters": {"mean": 1000, "stdDev": 200}}
  ],
  "model": {"expression": "min(inputs[0], inputs[1])"}
}
```

**Parameter Types:**
- iterations (integer): Number of runs. Must be > 0.
- seed (integer, optional): 64-bit unsigned seed. Omit for non-deterministic runs.
  Required for reproducible results (stochastic-function rule).
- enableGPU (boolean, optional, default true): GPU eligibility (≥ 1000 iterations).
- inputs (array of objects): name (string); type (string enum: "normal", "uniform",
  "triangular", "exponential", "lognormal", …); parameters (object, per type).
- model (object): expression-model description.

## 5. Constraints & Compliance

- **Concurrency:** all new types `Sendable`; async overload is Swift 6
  strict-concurrency clean; no blocking waits on cooperative threads in the async
  path; the `Task.sleep`-free continuation pattern uses `withCheckedThrowingContinuation`.
- **Determinism:** seed parameter on every stochastic entry point (MCP rule);
  `SplitMix64` avoids `SystemRandomNumberGenerator` in seeded runs. The
  `stochastic-determinism` auditor exemption comment on the `arc4random()` fallback
  remains valid (unseeded path only).
- **Safety:** no force unwraps / `try!` / `as!`; guard-based validation; loud
  `.seedingUnsupported` rather than silent fallback.
- **Generics:** `SeedableDistribution<T>` constrained to `Real`, matching
  `DistributionRandom`.
- **Auditors:** justification comments only where already sanctioned (e.g. existing
  `@unchecked Sendable` on the GPU device, unchanged).

## 6. Backend Abstraction

Unchanged: CPU default, Metal for ≥ 1000 iterations with automatic fallback. The
async overload does not change backend selection — only how completion is awaited.
Linux/CPU-only builds compile the async overload with the CPU loop (Metal path is
already `#if canImport(Metal)`).

## 7. Dependencies

**Internal:** existing Simulation module only.
**External:** none (swift-numerics already present).

## 8. Test Strategy

**Test Categories (swift-testing):**
- **Golden path (determinism):** same seed twice → *identical* `values` arrays
  (CPU 100 iters; GPU 10K iters, gated on Metal). Different seeds → different arrays.
  `nil` seed → two runs differ.
- **SplitMix64 reference vectors:** seed `0x9E3779B97F4A7C15`-style published
  SplitMix64 outputs (Vigna's splitmix64.c reference: seed 42 → first outputs
  verified against the C reference implementation) — independently verifiable truth.
- **Seeded distribution sanity:** for each adopted distribution, seeded run of 10K
  samples matches `next()`'s distributional moments within deterministic tolerance
  (exact assertions possible because the stream is fixed).
- **Loud failures:** custom-sampler input + seed → `.seedingUnsupported`;
  correlationMatrix + seed → `.seedingUnsupported`.
- **Async equivalence:** `run() async` with seed → identical results to sync `run()`
  with the same seed (CPU and GPU paths).
- **Cancellation:** cancelled `Task` running async CPU simulation throws
  `CancellationError` promptly (< 1s on a 10M-iteration run).
- **Regression:** full suite (5,864 tests) stays green; sync API byte-for-byte
  source-compatible.

**Reference Truth:** Vigna's published SplitMix64 reference implementation and test
vectors; distribution math already validated by existing tests (unchanged formulas —
only the uniform source is parameterized).

**Validation Trace:** `SplitMix64(seed: 1234567)` first three outputs must equal the
C reference (`splitmix64.c`, Vigna 2015) outputs for the same state — computed from
the reference algorithm during RED phase and hard-coded as golden values.

## 9. Architecture Decision Review

- [x] Reviewed `architecture_decisions.md` — no existing ADR covers RNG seeding
      or async simulation surfaces.
- [ ] Supersedes: No.
- [x] New ADR required:
  - **Title:** Seedable randomness via `SeedableDistribution` refinement; async
    overloads for GPU-bound work
  - **Category:** api / concurrency
  - **Key decision:** Determinism is opt-in per distribution through a refinement
    protocol (non-breaking), seeded entry points fail loudly when an input cannot
    honor the seed, and blocking GPU waits are confined to the sync API.

## 10. Open Questions

1. ~~Modify `DistributionRandom` (source-breaking for external conformers) vs. add a
   `SeedableDistribution` refinement?~~ → **Refinement** recommended: non-breaking,
   runtime-detectable, lets seeded runs fail loudly for unsupported inputs.
2. Correlated sampling (`runCorrelated`) seeding — deferred to a follow-up; v1
   throws `.seedingUnsupported`.
3. Version: additive API → 2.4.0.

## 11. Documentation Strategy

**Documentation Type:** Narrative Article Required — combines 3+ APIs (seed,
SeedableDistribution, async run), needs determinism-scope explanation (per-path
reproducibility, fallback caveat).
**Article Name:** `DeterministicSimulationGuide.md` (no Swift symbol collision).
