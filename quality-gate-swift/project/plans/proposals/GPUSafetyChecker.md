# Design Proposal — a `gpu-safety` checker

**Status:** Proposed
**Author:** BusinessMath session of 2026-08-13
**Motivating defect:** eleven GPU kernels dispatched with rounded-up threadgroups and no
bound on the thread id, found only because a seeded test happened to use a population size
that was not a multiple of 256.

---

## 1. The defect

Metal dispatches whole threadgroups. The universal idiom is to round up:

```swift
let threadsPerGroup = MTLSize(width: min(populationSize, 256), height: 1, depth: 1)
let threadGroups    = MTLSize(width: (populationSize + 255) / 256, height: 1, depth: 1)
encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
```

At `populationSize = 1200` that is 5 × 256 = **1280 threads for 1200 elements**. The 80
surplus threads run the kernel body. If the kernel does not bound its thread id:

```metal
uint seed = randomSeeds[id];          // read past a 1200-element buffer
offspring[id * dimension + i] = ...;  // write past the population buffer
```

An out-of-bounds read and an out-of-bounds write. Undefined behaviour, and undefined
behaviour is what differs between two otherwise identical runs.

### 1.1 Why nobody noticed

The symptom was a seeded optimizer that reproduced *sometimes*. Three separate rounds of
fixes — a `catch` guard, a `nil`-return converted to a throw, a missing `commandBuffer.status`
check — each found a real defect on the **fallback** path and each failed to cure it, because
this bug never fails a dispatch. The GPU reports success and returns different numbers.

It is also invisible at the sizes people test. In the codebase that motivated this:

| population | threads dispatched | surplus | observed |
|---|---|---|---|
| 999 | — | — | CPU path; never reached the GPU |
| 1000 | 1024 | 24 | intermittent mismatch |
| 1200 | 1280 | 80 | intermittent mismatch |

A test written with 1024 would have passed forever.

---

## 2. What is and is not statically decidable

This distinction is the proposal. A checker that ignores it will do harm.

| property | decidable? |
|---|---|
| The kernel has **no bound available at all** — no count parameter exists in its signature | **Yes.** It cannot be correct. |
| The dispatch rounds up | **Yes.** Syntactic. |
| A present guard uses the **correct** bound | **No.** `tid >= numOps` type-checks as well as `tid >= iterations`. |
| An early `return` is safe here | **No**, and assuming it is causes bugs. |

### 2.1 The case that proves the last row

```metal
kernel void matrixMultiplyTiled(..., uint2 gid [[thread_position_in_grid]]) {
    threadgroup float tileA[16][16];
    for (uint t = 0; t < numTiles; t++) {
        tileA[tid.y][tid.x] = (row < m && tileACol < n) ? A[...] : 0.0f;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        ...
    }
    if (row < m && col < p) { C[row * p + col] = sum; }   // guarded at the write
}
```

This kernel is **correct**, and a naive scan calls it unguarded because it has no
`if (gid >= …) return`. It must not have one: out-of-range threads have to keep reaching
`threadgroup_barrier`, or the threads that do reach it wait forever. Adding the "obvious
fix" converts a correct kernel into a hang.

So the checker must report *absence of any possible bound*, not *absence of an early return*.

---

## 3. Proposed rules

### Rule 1 — `gpu/unbounded-thread-id` (error)

A `kernel void` whose `[[thread_position_in_grid]]` parameter indexes a `device` or
`constant` pointer, **and whose signature contains no scalar parameter the id could be
bounded against**, is reported. No count in scope means no guard is possible.

This is deliberately narrower than "has no guard". It reported all six live instances in the
motivating codebase with no false positives, and correctly stayed silent on
`matrixMultiplyTiled`.

### Rule 2 — `gpu/rounded-dispatch` (warning)

A `dispatchThreadgroups` whose threadgroup count is computed with `(n + k - 1) / k` or
`(n + K) / K` is a site where surplus threads exist. Warning, not error: the kernels it
reaches may be correctly guarded.

Suggested fix in the diagnostic: `dispatchThreads(_:threadsPerThreadgroup:)` dispatches an
exact thread count and removes the hazard by construction. Gate on
`device.supportsFamily(.apple4)`; there is no non-uniform threadgroup support before it.

### Rule 3 — `gpu/unchecked-command-buffer` (error)

`waitUntilCompleted()` followed by a read of a shared buffer, with no check of
`commandBuffer.status` or `.error` in between. `.error` is a terminal state, so the read
proceeds and returns whatever the buffer held — the pre-kernel contents, or partial output.
Every GPU path in the motivating codebase had this.

### Not proposed

Matching pipelines to dispatch sites across files, so as to prove a particular kernel is
only ever reached by a bounded dispatch. It is the expensive part, it needs cross-file
dataflow through `MTLComputePipelineState` handles, and Rules 1 and 2 catch the defect
without it.

---

## 4. Where the shader source lives

Both forms must be read, and getting this wrong makes the checker audit dead code:

1. **Standalone `.metal` files.**
2. **Embedded in a Swift string literal**, compiled with `device.makeLibrary(source:)`.

In the motivating codebase the `.metal` files were **excluded from the target** in
`Package.swift` — to avoid requiring the Metal toolchain in Playgrounds — and the live
shaders were the embedded strings. An audit of the `.metal` files alone would have reported
eight defects in code the compiler never sees, and missed the two that ship.

**The checker should therefore report which source it read**, and flag `.metal` files that
are excluded from every target as dead, which is a useful finding in itself.

---

## 5. Why this is not part of `stochastic-determinism`

The symptom was nondeterminism; the defect is memory safety. An unguarded kernel corrupts an
*unseeded* run identically — nothing pins the output, so nobody notices. Filing it under
determinism would under-report by exactly that population, and would name the symptom rather
than the defect. "This kernel indexes past its buffer" is actionable; "this might be
nondeterministic" is not.

There is also a capability argument: `stochastic-determinism` is a Swift-AST checker, and
this needs a Metal parser.

**One rule does belong to determinism** and should go there instead: *a seeded run must not
silently substitute a different implementation.* That is its remit already, and it is the
third GPU defect the motivating session found.

---

## 6. What the checker cannot give you

It finds kernels that are certainly wrong. It cannot certify that the rest are right — §2.

Two things do give assurance, and the proposal recommends both as conventions rather than
pretending the static rule replaces them:

- **`MTL_SHADER_VALIDATION=1`** on a test run. Metal's runtime bounds checking on buffer
  access catches the real thing, empirically, including wrong-bound guards that Rule 1
  passes.
- **A CPU-parity test at a deliberately non-aligned size.** This is what actually caught the
  motivating defect: a seeded determinism test at 1000 and 1200, neither a multiple of 256.
  A GPU path tested only at 1024 is untested.

The second is worth a `test-quality` rule of its own: a test exercising a GPU path at a size
that *is* a multiple of the threadgroup width is testing the one case that cannot fail.

---

## 7. Testing the checker

- Both source forms: a `.metal` file and an embedded string literal.
- A kernel with no count parameter → Rule 1 fires.
- A kernel guarded by early return → silent.
- `matrixMultiplyTiled` verbatim → **silent**. This is the regression test that matters; a
  checker that flags it will be turned off within a week.
- A `.metal` file excluded in `Package.swift` → reported as dead, not audited for Rule 1.
- `dispatchThreads` at the dispatch site → Rule 2 silent.
