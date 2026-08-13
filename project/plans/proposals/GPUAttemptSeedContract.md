# Design Proposal — A GPU attempt that cannot break the seed promise

**Status:** Accepted — abstraction implemented in 2.6.0; §4 deferred to 3.0.0
**Author:** Session of 2026-08-12
**Area:** `Optimization/Heuristic` (GPU fallback paths)

---

## 1. Problem

Three heuristic optimizers accelerate on Metal above a population threshold of 1000
(`MetalDevice.shouldUseGPU(populationSize:)`): `GeneticAlgorithm`,
`DifferentialEvolution`, and `ParticleSwarmOptimization`. All three follow the same
shape:

1. Decide whether the GPU applies (device present, `V == VectorN<Double>`, size ≥ 1000).
2. Draw one `UInt32` kernel seed **per individual** from the optimizer's generator.
3. Allocate buffers, fetch pipelines, vend a command buffer, dispatch.
4. On any failure, fall back to the CPU implementation.

Steps 3 and 4 are where this goes wrong, in two distinct ways.

### 1.1 The generator is left advanced

The seeds at step 2 are drawn *before* the first operation that can fail. Abandoning the
attempt at step 3 therefore leaves the generator advanced by one draw per individual, and
the CPU fallback resumes the stream at a position no seed predicts. A seeded run then
reproduces only when the GPU happens to succeed on every generation of both runs.

### 1.2 The fallback is a different algorithm

Rewinding the generator fixes 1.1 and introduces a subtler problem. The GPU kernels
compute in `Float`; the CPU implementations compute in `Double`. A run that falls back is
now *seed-consistent* — it agrees with the GPU run on every random draw — and still
returns a different answer. That is materially harder to diagnose than 1.1, because
nothing about the symptom points at seeding.

For a caller who set no seed, silently substituting the CPU is correct and desirable:
resilience is worth more than a promise nobody asked for. For a caller who set one, it
answers a question they did not ask.

### 1.3 What the codebase actually did

| | rewind on abandon | refuses seeded fallback |
|---|---|---|
| `GeneticAlgorithm`, `catch` branch | yes | yes |
| `GeneticAlgorithm`, `return nil` at the command-buffer guard | yes | **no** |
| `DifferentialEvolution` (4 post-draw `return nil` sites) | **no** | **no** |
| `ParticleSwarmOptimization` (3 post-draw `return nil` sites) | **no** | **no** |

The rule was written once, as a comment, in the `catch` branch of one file. The `nil`
return two dozen lines below it in the same function did not inherit it, and the two
sibling optimizers never received any part of it.

This is the failure mode the abstraction is for. The rule is not hard; it is just not
attached to anything that travels.

### 1.4 Why it stayed hidden

A command queue that cannot vend a command buffer is transient resource exhaustion, so
the defect surfaces only under memory or GPU pressure — a full parallel test run. Run in
isolation, the seed-determinism test passed 4 times out of 4 while failing the full suite.

---

## 2. Proposal

Move the rule into a type, so that the correct behaviour is the reachable one and each
call site is *forced* to state what it does when the promise cannot be kept.

```swift
/// The outcome of a GPU attempt that may have drawn from the optimizer's generator.
internal enum GPUAttemptOutcome<Success> {
    /// The GPU produced a result. The generator is left where the attempt advanced it.
    case completed(Success)

    /// The attempt was abandoned and the generator has been rewound to where it stood
    /// before the attempt began.
    case abandoned(GPUAttemptAbandonment)
}

internal struct GPUAttemptAbandonment {
    /// True when the caller configured a seed.
    ///
    /// The CPU fallback computes in `Double` where the GPU kernels compute in `Float`,
    /// so it will not reproduce the GPU's answer. Running it anyway would answer a
    /// question the caller did not ask, under a seed that promises otherwise.
    let seedPromiseBroken: Bool

    /// The failure, when the attempt threw rather than returning nil.
    let underlying: (any Error)?
}

extension RNGWrapper {
    /// Runs a GPU attempt that draws from this generator, rewinding it if abandoned.
    ///
    /// Everything inside `body` is treated as having possibly consumed randomness, so
    /// **applicability checks must happen before this call** — device availability,
    /// vector type, and the population threshold are not failures, they are reasons not
    /// to attempt at all, and they must not reach this method.
    ///
    /// - Parameters:
    ///   - seeded: Whether the caller configured a seed.
    ///   - body: The attempt. Returning `nil` or throwing both abandon it.
    func attemptGPU<Success>(
        seeded: Bool,
        _ body: () throws -> Success?
    ) -> GPUAttemptOutcome<Success>
}
```

### 2.1 Why it returns an outcome instead of throwing

The obvious signature throws on a broken seed promise and lets each optimizer propagate
it. That does not work here: `DifferentialEvolution.optimizeDetailed` and
`ParticleSwarmOptimization.optimizeDetailed` are **non-throwing public API**, so they
cannot propagate anything, and changing that is source-breaking for every caller.

Returning an outcome the caller must `switch` over keeps the decision at the call site
while making it impossible to *not notice*. `GeneticAlgorithm.evolvePopulation` already
throws and maps `seedPromiseBroken` to an error. `DifferentialEvolution` and
`ParticleSwarmOptimization` record it in their result until §4 is decided.

This also matches the project's fail-silent rule, which permits either horn: *"never
return plausible-but-wrong results; throw **or annotate degradation**."*

### 2.2 The contract this enforces

- The generator cannot be left advanced by an abandoned attempt — the rewind belongs to
  the runner, not to each of the seven `return nil` sites that would otherwise need it.
- A post-draw failure cannot be mistaken for "the GPU did not apply" — applicability is
  decided before the call, so anything inside is by construction an abort.
- A seeded run cannot silently receive a CPU answer — the outcome type has no case that
  means "abandoned, and you may ignore that".

---

## 3. Error handling

`attemptGPU` itself does not throw; it catches whatever `body` throws and reports it in
`GPUAttemptAbandonment.underlying`, having first rewound the generator. Callers decide:

| Caller | On `.abandoned(seedPromiseBroken: true)` | On `.abandoned(seedPromiseBroken: false)` |
|---|---|---|
| `GeneticAlgorithm` | throw `OptimizationError.invalidInput`, naming the underlying failure | run the CPU path |
| `DifferentialEvolution` | record degradation on the result (§4) | run the CPU path |
| `ParticleSwarmOptimization` | record degradation on the result (§4) | run the CPU path |

---

## 4. Open decision — DE and PSO's public API

`GeneticAlgorithm.optimizeDetailed` throws, so it can refuse. The other two cannot. Three
options, in order of preference:

1. **Annotate degradation.** Add `public let usedCPUFallback: Bool` to
   `DifferentialEvolutionResult` and `ParticleSwarmResult`, defaulted in the initialiser
   so it is source-compatible. A seeded caller can check it; nothing breaks.
   Weakest guarantee — a caller who never looks is back where they started — but it is
   honest, non-breaking, and shippable in 2.6.0.
2. **Make `optimizeDetailed` throwing.** Strongest and consistent with
   `GeneticAlgorithm`, but source-breaking for every caller: a major-version change.
3. **Refuse the GPU entirely on seeded runs.** Deterministic and simple, and gives up the
   acceleration precisely for the callers most likely to be running something large.

**Decision (2026-08-12):** (2) is the end state, but it makes the release a major, and a
major should carry all the breaking work at once rather than one item that happened to
surface first. So (2) moves to 3.0.0, and 2.6.0 ships **(3) as the interim**: DE and PSO
decline the GPU outright when a seed is set.

(3) was rejected above as giving up acceleration for the callers most likely to want it.
That reasoning holds for a permanent answer and not for an interim one, because the
caller it costs — someone who set a seed *and* has a population over 1000 — is asking for
reproducibility, which is a testing and audit posture rather than a throughput one. It is
also the only option that needs no new API, so 3.0.0 inherits no interim surface to
deprecate: the guard is deleted when the throwing signature lands, and GPU plus seed work
together again.

Chosen over (1) because (1) adds a public property to two result types purely as a
staging step, and a flag a caller can forget to check is a weaker guarantee than a run
that is deterministic by construction.

---

## 5. Testing

- **Determinism across the threshold, per optimizer.** Same seed at 999 (CPU) and 1000
  (GPU), asserting bit-for-bit equality of fitness and solution. `GeneticAlgorithm` had
  this; `DifferentialEvolution` and `ParticleSwarmOptimization` did not, which is why
  their copy of the defect went unnoticed.
- **The tests must not be vacuous.** A determinism test below the threshold exercises the
  CPU and reports on the API. Assert `MetalDevice.shouldUseGPU(populationSize: 1000)` so
  the suite fails loudly on a machine where the GPU case silently never runs, rather than
  passing without testing anything.
- **Rewind under injected failure.** The real trigger — a command queue refusing to vend
  a buffer — cannot be summoned on demand, so test `attemptGPU` directly with a `body`
  that draws from the generator and then returns nil, asserting the generator's next
  draw matches what it would have been had the attempt never run. This is the assertion
  that would have caught §1.1 in all three optimizers, without needing GPU pressure.
- **Seeded refusal.** `attemptGPU(seeded: true)` with a failing body reports
  `seedPromiseBroken: true`; with `seeded: false`, false.

---

## 6. Performance

None on the success path: one generator snapshot per GPU attempt, which copies a value
type of a few words, against a dispatch that already allocates buffers sized by
population × dimension. Snapshots occur once per generation, not per individual.

The failure path gains a rewind of the same cost, and for `GeneticAlgorithm` converts a
silent CPU generation into a thrown error — faster, though that is not the point.

---

## 7. Scope

- `Optimization/Heuristic/GPU/GPUAttempt.swift` (new) — the outcome types and the
  `RNGWrapper` extension.
- `GeneticAlgorithm.swift` — replace the hand-rolled snapshot/restore/catch with the
  runner; the command-buffer `nil` is already converted to a throw.
- `DifferentialEvolution.swift`, `ParticleSwarmOptimization.swift` — adopt the runner,
  replacing the `defer`-based rewind added alongside this proposal.
- Result types, if §4 option 1 is taken.

Not in scope: `MetalMatrixBackend` and `MonteCarloGPUDevice` also have GPU fallbacks, but
neither draws from an optimizer-seeded generator before failing. They should be re-checked
against this contract, not silently assumed to be covered.
