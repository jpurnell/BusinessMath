# Handoff — 2026-08-09

**70 of 73 DocC articles now compile as one program.** Nothing is committed beyond `68b91dd`.

---

## Git state

Branch `fix/simplex-scale-relative-feasibility`, two commits ahead of `origin/main`, unpushed:

| commit | what |
|---|---|
| `817ea6f` | simplex scale-invariance fix (the follow-on WIP was deliberately reverted — the committed fix stands) |
| `68b91dd` | `docs(1.5)`: first article made to compile as one program |

Everything else is **uncommitted in the working tree**: ~70 `.docc` articles, plus the source
changes below. Separable — `git add Sources/BusinessMath/BusinessMath.docc` takes only the docs.

---

## What landed

### Source (tested, full suite green)
- **`OptimizationError` gained `dimensionMismatch` and `numericalInstability`**
  (`Valuation/Debt/BondPricing.swift:1031`), with doc comments explaining why each is distinct
  from its neighbour. Four throw sites converted:
  `Optimization/NumericalDifferentiation.swift` (empty vs ragged vs wrong-length; exact
  singularity vs near-zero pivot) and `Optimization/LinearityValidation.swift:61`.
- **`Tests/BusinessMathTests/Optimization Tests/OptimizationErrorPrecisionTests.swift`** — 7 tests,
  green. Note the near-singular fixture must have a *whole column* small
  (`[[1e-12, 1], [1e-13, 2]]`): partial pivoting swaps away a small leading entry, so
  `[[1e-12, 1], [1, 1]]` solves fine.

### Documentation
- **Part 1 complete** — all ten articles, 197 blocks, 2 exemptions.
- 70 of 73 overall green.

### Elsewhere
- **quality-gate-swift** `docs/doc-code-example-rules` branch → guidelines commit (see below).
  `project/plans/proposals/DocCodeAuditor.md` — the living design doc, now with §8a (the four-rule
  family) and the `--stage`-as-default decision.
- **development-guidelines** (canonical: `Tools/development-guidelines`) — branch
  `docs/doc-code-example-rules`, commit `13b45a3`. Adds the one-program rule, the
  `docs:illustrative` marker, Rule 5 (never shadow a public module symbol), Rule 6 (no playground
  scaffolding), and "regenerate expected output, never hand-edit". Unpushed, untagged; suggest
  `v2.2.0` since it makes existing projects newly non-compliant.
- **`project/plans/proposals/IntendedSurface.md`** (this repo) — the design doc on API the
  documentation promises and we do not have.

---

## The three outstanding articles

| article | why |
|---|---|
| `5.8-IntegerProgramming` | 86 blocks; never assigned in the original waves. Agent in flight. |
| `3.16-FinancialStatementsReference` | being rewritten around a **generator** (see below). Agent in flight. |
| `3.15-DataIngestionGuide` | **blocked on a product decision**, not effort. |

`3.15` documents an ingestion subsystem that does not exist — the library is export-only
(`Developer Tools/DataExport.swift:47,83`). It fails on one error, `Period.custom(start:end:)`,
which is the same decision. Do not rewrite it until §2.1 of `IntendedSurface.md` is called: build
ingestion and 3.15 largely survives as the spec; don't, and it becomes a short "getting data in
with what exists" plus a design doc. Rewriting now is throwaway either way.

---

## The tooling

`quality-gate-swift/project/plans/proposals/DocCodeAuditor-prototype/` — SwiftPM, tools 6.0,
SwiftSyntax/SwiftParser. Two executables:

- **`doccollisions`** — `[--json] <module-search-path> <article.md>…`. Exit 0 = clean.
  Stateless and parallel-safe (`NSTemporaryDirectory()/docaudit-<UUID>`), so N agents can audit N
  articles at once.
- **`docref`** — the generator + freshness check for `3.16` (in flight).

```sh
cd <prototype> && swift build -c release
.build/release/doccollisions <BM>/.build/debug <BM>/Sources/BusinessMath/BusinessMath.docc/1.2-TimeSeries.md
```

**Before folding into quality-gate-swift:** `Package.swift` points at swift-syntax via an absolute
path into *BusinessMath's* `.build/checkouts`. Replace with `.package(url:from: "600.0.0")` —
verified 2026-08-09 that both resolve to revision `0687f719`, so it is a no-op at resolution time.

---

## Hard-won lessons — do not relearn these

- **Never bulk-rename with regex.** It rewrote prose (`// Create a retail model` →
  `// Create a retail saasModel`) and renamed correctly-scoped loop bindings.
- **Fix collisions first, re-run, and only then look at type errors.** Routinely 40-90% of
  diagnostics are cascade. Errors that read as API drift are usually a shadowed variable.
- **Never satisfy `cannot find X in scope` with the nearest type-compatible symbol.** It compiles
  and prints a wrong number.
- **A green auditor does not mean the references landed on the right object.** Renaming re-binds
  blocks that use a name without declaring it. In `MultipleLinearRegressionGuide` six blocks
  re-bound to a one-predictor model while printing VIF and t-tests.
- **Labels are mechanical; *meanings* are not.** `shape:scale:` → `r:λ:` compiles and is wrong by
  9× because λ is a rate. `min:mode:max:` → `low:high:base:` invites a positional swap that
  returns `NaN`.
- **Compile barriers make error counts meaningless.** `3.15` ranked "1 error" and was ~27;
  `5.18` reported 14 while all 20 blocks were unchecked behind a bad import.
- **Prefer resolving a barrier to exempting past it** — an exemption at a barrier hides
  everything behind it.
- **Verify "this symbol does not exist" case-insensitively.** `percentileLocation` is real; it is
  `PercentileLocation`.
- **Check the working directory before believing a count.** A classifier run from the wrong cwd
  reported 3,504 phantom missing symbols; the real number was 672.

---

## First action on resume

`git -C . log --oneline -3` should show `817ea6f` / `68b91dd`. Then run the full sweep:

```sh
cd Sources/BusinessMath/BusinessMath.docc
<prototype>/.build/release/doccollisions <BM>/.build/debug *.md | grep '^✗'
```

Nothing is pushed. Decide committing strategy before anything else — the working tree holds a
day's work across ~70 files.
