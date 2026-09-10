# Handoff — 2026-09-10

**`3.0.0-alpha.2` is released and the breaking set is complete.** `main` is clean, CI-green,
and nothing is in flight. The next decision is whether the alpha has been exercised enough to
drop the pre-release suffix.

## State

| | |
|---|---|
| branch | `main` at `90f773be`, pushed, CI green |
| latest stable | `v2.18.0` — what `from:` consumers resolve to |
| latest pre-release | `v3.0.0-alpha.2` |
| tests | 7,626 in 679 suites |
| gate | `quality-gate --no-cache --check all --continue-on-failure` → 45/45, 0/0 |
| working tree | clean except `project/plans/proposals/excel_function_coverage_matrix_bak.tsv` — **the user's own backup, deliberately untracked, leave it alone** |

Always `--check all`. Plain `--no-cache` runs 40 of 45 and prints an identical PASSED line.

## What shipped today

Five releases in one day, which is unusual and worth reading in order:

| Release | Contents |
|---|---|
| `2.16.0` | Marketing leg stages 0–4 — 28 additive files, four new `Statistics/` areas, `Network/`, `Marketing/` |
| `2.17.0` | Stage 5 — attribution (heuristics, Markov removal effect, exact Shapley), association rules, behavioural segmentation. Plus parameterising the constraint penalty weight |
| `2.18.0` | ETS parameter fitter, complex-notation codec, a GPU read-back crash fix, chapter 7 |
| `3.0.0-alpha.1` | The breaking set: `optimizeDetailed` throws, `CLVDefinition.perpetuityDue`, template LTV delegation with seven deprecations |
| `3.0.0-alpha.2` | `sampleSize` deleted — the fourth and last breaking item |

**The marketing leg is complete.** All six stages of `completed/marketing/MarketingLeg.md`.

## The one decision waiting

**Drop the `-alpha.2` suffix and cut `3.0.0` final?** Nothing technical is outstanding. The
question is whether the alpha has been used enough to trust.

If yes it is a docs-only release: retitle the CHANGELOG section, update README's pre-release
block, reconcile `master_plan.md`, tag, publish without `--prerelease`.

## Why the alphas are pre-releases, and do not undo it

The user initially asked for the breaking work as `2.19.0`, reasoning that nothing was using
what it broke. That is true and is not the whole question: **this project's own README tells
consumers `from: "2.7.0"`**, which in SPM means `.upToNextMajor` — so a 2.19.0 would have
pulled every existing consumer into three source-breaking changes on their next
`swift package update`, with no constraint that would have stopped it. SPM **excludes
pre-releases from `from:` ranges**, which is why the alphas reach only callers who name them
exactly. GitHub still shows 2.18.0 as Latest.

Also: `3.0.0a` is **not valid semver** — SPM would ignore the tag entirely and nobody could
depend on it by version. The hyphen in `-alpha.1` is load-bearing.

## Open work, in the order it is likely to be picked up

1. **`project/plans/STATUS.md` is the ledger.** Read it before anything else — it says what is
   complete, open and in progress across 130 plan files, with the evidence for each line and
   an explicit marker where a claim is inference rather than a file.
2. **Six absent optimization algorithms** — `proposals/PROPOSAL_advanced_optimization_gap.md`,
   audited and real. SQP, Interior Point, GRG, Network Flow, Convexity, ADMM. §10.5's
   "parameterise the penalty weight" branch closed in 2.17.0; **adapting it across restarts is
   still open** and is the better answer for a caller who does not know their objective's scale.
3. **Excel coverage**: exactly **one** row of 49 is genuinely absent — `ImportanceSampling`.
   Everything else is present or excluded. Three planned-not-started buckets remain:
   `PROPOSAL_compatibility_and_lookup.md`, and the ETS/complex bindings which are the *other*
   session's work, not ours.
4. **A test-quality proposal in a sibling repo** —
   `../../Tools/quality-gate-swift-project/plans/proposals/TestQualityAuditor_SemanticRules.md`.
   Eight new rules plus a mutation-testing path. **BusinessMath does not pass it**: 11
   `guard let … else { return }` in tests that pass silently on nil, and 18 disabled tests
   whose stated reasons include two unfixed product defects.

## Cross-session context

Another Claude session works **SwiftExcelFunctions** and cannot reach this tree. The lane is
settled: **mathematics here, spreadsheet argument semantics there.** It is building the Excel
argument layer against `ETSSeasonality` and `ETSFit`, which shipped in 2.18.0 — **do not change
those shapes without telling it.**

Its corpus work produced one finding worth carrying: the coverage matrix's column labelled
`books` **counts sheets**, over a **79-workbook** sweep. A `0/0` row means "absent from every
formula on every sheet of those 79" — one sample, not a ranking signal across 726 rows. The
full account is in `project/plans/proposals/excel-coverage/README.md`.

## Traps, in the order they bite

**Budget nine minutes for a commit and a push.** Both hooks run a 40-checker gate. At machine
load above ~60 even that is not enough — a push timed out twice today. Pass a long `timeout`;
never background a commit.

**Commit with an explicit FILE pathspec.** `git commit -- <file>`, never `git add <directory>`
— a directory pathspec swept the user's untracked backup into a commit today. And a `git mv`
stages **two** entries; a pathspec naming only the new path leaves the deletion staged, which
later blocks a merge.

**A gate run from inside `.claude/worktrees/` examines ZERO files and prints PASSED.** The
tracked config excludes that path. Copy the config, drop the exclusion, and **check the file
count** — a real run reports ~1,240.

**`doc-run` article timeouts are load artefacts above roughly load 30.** Four errors at load
41, zero at 10.8, unchanged tree. Under a zero-warnings policy this invites a permanent wrong
edit to a DocC file. Run `uptime` before believing one.

**No suppression markers, ever.** `// stochastic:exempt`, `// fp-safety:disable`, `// LIVE:`
exist and are used elsewhere. Every case this work would have needed one was avoidable by
reusing something that already existed. Zero added across roughly fifty commits.

**The gate rejects `#expect(x != nil)`, `!= 0`, and `==` on floating point.** Assert the
value; name the comparison (`isEqual(to:)` for a deliberate IEEE one). It also flags a test
call that omits a parameter defaulted to a seed — state the seed at the call site.

## How this work has been done

Strict TDD, commit at each green state, and one rule that has mattered more than any other:

**Verify against an identity, not a fixture.** AUC against the Mann–Whitney statistic
exactly; Kaplan–Meier against the empirical survival function it must reduce to; Gini against
its own second formula; the two uplift estimators against each other, algebraically equal on a
balanced design and computed by separate code paths; the Lerner condition at the optimum of
all three demand forms; Shapley's null player, which is exact rather than approximate.

**And write the stub.** The strongest test-design question found today: *what is the simplest
wrong implementation that still passes this?* The ETS proposal's headline assertion — "fitted
error ≤ the library defaults" — was passed by a fitter returning its starting point, and was
replaced with a comparison against a 1,331-point brute-force grid.

## The thing that cost the most, so it is not repeated

Five hours went into reconciling coverage numbers across three files. The answer was that one
column labelled `books` counts **sheets**, and it was readable in forty lines of Swift in a
**sibling repository** that this repo's own README names. Both sessions searched the tree they
were standing in.

**Read the generator before reasoning about the data.** Two corollaries, each of which beat a
session independently: the generator is frequently **not** in the repository holding the data,
and **a truncated read of a provenance document is not a read of it** — the first look at the
file that held the answer was `head -6`, seven lines short.
