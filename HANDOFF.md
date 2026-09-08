# Handoff — 2026-09-08

**2.15.0 is released, pushed and tagged. The tree is clean, the gate is 45/45 at zero, and
there is no work in flight.** This is a good stopping point rather than a pause mid-task.

The one thing that needs a decision is at the bottom, under *Worktrees*. Everything above
it is state.

## State

| | |
|---|---|
| branch | `main` at `be704795`, pushed, tag `v2.15.0` pushed |
| release | https://github.com/jpurnell/BusinessMath/releases/tag/v2.15.0 |
| tests | 7,308 in 650 suites, green |
| gate | `quality-gate --no-cache --check all` → 45/45, 0 errors, 0 warnings |
| working tree | clean, except `project/plans/proposals/excel_function_coverage_matrix_bak.tsv` — **the user's own backup, deliberately untracked, leave it alone** |

Run the gate as `quality-gate --no-cache --check all --continue-on-failure`. Plain
`--no-cache` runs only the default profile — 40 of 45 — and prints an identical PASSED
summary while `doc-run`, `doc-claims` and three others never execute.

## What just finished

Risk Solver's distribution surface, closed at **52 landed, 5 excluded**. Nothing is
blocked, partial or unresolved. The five exclusions are `PsiSip`, `PsiSlurp`, `PsiTSSip`,
`PsiCertified` and `PsiVary` — they resolve stored data or declare a solver role, which is
a spreadsheet host's job, and the row notes say so rather than leaving them blank.

Full account in `project/summaries/SUMMARY_2026-09-08_psi-completeness-and-2.15.0.md`.
The joinable record is `project/plans/proposals/excel-coverage/psi_upstream_gaps.tsv`
(5 fields, LF, trailing newline — preserve those when editing).

## What is genuinely open

Nothing is half-done. These are candidates, in the order I would take them.

**The six absent optimization algorithms.** `project/plans/proposals/PROPOSAL_advanced_optimization_gap.md`
audits the roadmap against the source and finds SQP, Interior Point, GRG, Network Flow,
Convexity detection and ADMM genuinely missing, with a revised priority order — GRG moves
up because Excel Solver parity acquired an argument it did not have in January. That
proposal is the best-specified next piece of work in the repo.

**`NonlinearRelaxationSolver` on degenerate nodes.** A node whose feasible set is a single
point still runs the full 100 outer steps — about 28 seconds at `nlpMaxIterations: 1000`.
The infeasible case was fixed in `cf6ac6de`; this one was deliberately left alone, because
it is still making feasibility progress and stopping it would prune a feasible node. Fixing
it properly means giving the augmented Lagrangian something better than a stalled
stationarity test on a KKT-degenerate point. **Read the comment at the stopping rule in
`InequalityOptimizer` before touching this** — it records a near-miss that would have
returned wrong answers.

**`PsiNormalSkew` beyond two points.** The skew-to-median map is confirmed at `c = 0` and
`c = 0.5` against Risk Solver. Two points fix a line without proving linearity; a reading
at `c = 0.9` (predicted median 57, mean 55.04) would close it. One function body changes if
it disagrees: `DistributionMyerson.normalSkewMedian(...)`.

**Three roadmap items still open** in `project/master_plan.md` Phase 1 and Phase 2 —
`negativeValue`/`outOfRange`/`resourceExhausted`, differential suites for the distribution
family, and recording measured accuracy in doc comments where the answer is approximate.

## Two things that will bite you

**Commit with an explicit pathspec.** `git commit -- <paths>`, never a bare `git commit`
after `git add`. Git builds the commit from the *whole index*, so anything another session
has staged comes along, and staging your own files does not protect you because their
`git add` lands in the same index. This happened here in a *foreground* commit — `affa6c91`
carries another session's file rename under this session's message. Foreground versus
background was never the mechanism.

**Do not reach for the suppression markers.** `// stochastic:exempt` and
`// fp-safety:disable` are real and are used elsewhere in the tree, but every case this
release would have needed one was avoidable by reusing something that already existed: a
Gaussian constant became `2·normalPDF(x: 0)`, a hand-rolled uniform became
`Double.random(in:using:)`, an unseeded `random()` became a ratio over two free functions
that already owned that entry point. Zero markers were added. Assume the same is possible
before adding one.

## Worktrees — the one decision waiting

Three agent worktrees under `.claude/worktrees/` are dated **2026-08-10**, a month old:

```
agent-a14cf47c53ee99c22   11 modified files
agent-a3154fd65f1e28520    7 modified files
agent-a5aa29fab3e53904e   13 modified files
```

Their commits are ancestors of `main`, so the committed work is merged. The uncommitted
modifications were compared file-by-file against `main`, and **`main` holds the newer
version in every case that differs** — seeded RNG where the worktree has an unseeded draw,
justification comments the worktree lacks, a fuller and corrected `TrustPlan.md`. They look
like earlier iterations of work that subsequently landed in better form.

That is evidence, not proof, so nothing was deleted. Full diffs are captured at
`<scratchpad>/worktree-backup/*.diff` (86 KB), but a scratchpad does not survive
indefinitely — **if these are to be pruned, capture the diffs somewhere durable first, or
confirm they are dead and prune.** They cost a stale `git worktree list` and, per
`feedback-worktree-spm-conflicts`, can interfere with SPM builds.
