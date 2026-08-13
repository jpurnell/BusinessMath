# Handoff — 2026-08-13

**2.6.0 is still written and still unshipped**, and the reason has changed. The tag was
previously held for DocC checkers in quality-gate-swift; those landed. It is now held on one
thing only: `doc-comment-code` reports **852 errors**, down from 1,515, and the release should
not go out teaching examples that do not compile.

Everything is committed and pushed. There is no work in flight.

## State

| | |
|---|---|
| branch | `main`, clean, **0 ahead of `origin/main`** |
| tag | **none** — see "Why the tag is held" |
| tests | **6,582 in 579 suites**, 0 issues, ~29s |
| quality gate | **0 errors, 0 warnings**, 37 checkers, `--no-cache` |
| CI | green — 4/4 jobs, including `Linux release compile check` |
| nightly (Release Tests) | green — including Thread Sanitizer, 6,582 tests in 347s |
| commits since `v2.5.2` | 96 |
| `doc-comment-code` | **852 errors** ← the only thing gating the tag |

## Why the tag is held

`doc-comment-code` compiles every ```swift fence in isolation, with only Foundation and this
module in scope. 852 fences still fail. The stance driving this work is explicit: examples
should actually run. Apple ships documentation whose examples do not compile, and the decision
here was not to do that.

Progress is real but unfinished — 1,515 → 852, with the mechanism understood (below). This is
the resume point.

## First action on resume

```sh
swift build && swift test                      # expect 6,582 / 579, exit 0
quality-gate --no-cache                        # expect 0 errors, 0 warnings
quality-gate --check doc-comment-code --no-cache | grep -c '❌ error:'   # expect 852
```

The binary is `quality-gate`, the flag is `--check`, and it takes **no positional path**. A
failed invocation greps as `0 errors`, indistinguishable from a clean run — guard on log
length before trusting any count. This produced two false "clean" readings in one session.

## Where `doc-comment-code` stands

**What works, and scales.** Never infer a binding's type from its name; infer it from
something the example already committed to. An argument label (`entity:`), a generic argument
(`KMeans<Vector2D<Double>>`), or a method call (`.fillForward(`) are all parts of the API the
author could not have varied. `model` tells you nothing; `entity: model` tells you everything.
That technique placed 87 bindings in two passes.

**What does not exist.** Per-area preambles. The checker's `preambleImports` returns
`["Foundation", module]` unconditionally and ignores configuration — deliberately, since a
reader gets the fence and nothing else. Inline one-line bindings are the only surviving form.

**Remaining shape of the 852.** Roughly 445 undefined references, the rest compile failures.
The head of the tail is `builder` (29), `model` (26), `optimizer` (21), `result` (11) — these
need a real constructor per file rather than a shared fixture, because each names the type its
own file documents. 33 fences contain literal `...` elision and can never compile as written.

**Run each transformation as a separate pass.** Three self-inflicted regressions in one
session all had the same shape: a multi-step edit whose output invalidated a precondition
checked at the start. See `4b8ad7e`.

## What shipped this session

- **GPU seed contract.** Three optimizers could silently answer a seeded run with a different
  algorithm. `RNGWrapper.attemptGPU(seeded:_:)` now owns the rule; `GPUAttemptOutcome` has no
  case meaning "abandoned, and you may ignore that". Also: **no GPU path in the library
  checked `commandBuffer.status`** after `waitUntilCompleted()`.
- **Documentation fixtures** — new public API, `doc-comment-code` 1,515 → 852.
- **Linux release build fixed.** Four generic expressions the Ubuntu type-checker rejects.
  The package did not build on Linux in release configuration.
- **Two flakes closed.** Five scenario generators passed `seed: nil` while asking the
  optimizer for `seed: 42`; measured 298/300 convergence, a 1-in-150 red suite.
  `testHangGuard` replaced 46 `.timeLimit(.minutes(2))` sites.

## Open

1. **`doc-comment-code` → 0.** Gates the tag. See above.
2. **`project/plans/upcoming/v3.0.0_SCOPE.md`.** DE and PSO's `optimizeDetailed` must become
   `throws` to refuse a seeded CPU fallback; that is source-breaking, so it forces a major and
   should carry the other breaking work with it. Three open questions in §4, including whether
   the sibling packages' bumps are planned with 3.0.0 or discovered after it.
3. **One unexplained SEGV.** `generateRandomVolatilities` under TSan on 08-13. Did not recur
   across three later CI runs or two local attempts. The input is fully deterministic
   (`count: 100, seed: 20260812` through a pure xoshiro256\*\*), so no property of that code
   can differ between the run that crashed and the ones that did not — environmental by
   elimination. **Watch, do not fix.** If it recurs at the same site, that argument is what
   has to be given up.

## Convention notes

- Run the gate with `--no-cache`. A cached run executes 10 of 37 checkers and prints an
  identical PASSED summary.
- `--filter` passing proves nothing here. Two defects this session were visible only in the
  full parallel suite and clean in isolation, 4/4 and 6/6.
- Never background a `git commit`; the slow pre-commit hook is a window another session's
  staged work slips through.
