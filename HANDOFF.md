# Handoff — 2026-09-08

**2.15.0 is released, pushed and tagged. The tree is clean, the gate is 45/45 at zero, and
there is no work in flight.** This is a good stopping point rather than a pause mid-task,
and there is nothing waiting on a decision.

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

## Worktrees — done, nothing outstanding

Pruned 2026-09-08. Four directories under `.claude/worktrees/` are gone, along with three
`worktree-agent-*` branches. `git worktree list` shows only the main checkout.

Checked before deleting, and recorded in case the question comes back:

- Three worktrees from 2026-08-10 held 31 modified files between them. Comparing each
  against `main` showed `main` holding the newer version everywhere they differed, and the
  equal-line-count cases settled it — they were `func x()` against `main`'s `func x() throws`,
  and `samples.min()!` against `main`'s `try #require(samples.min())`. The worktrees held
  pre-cleanup states from before the force unwraps came out.
- A fourth, `agent-a064a9af` from April, was orphaned: its `.git` file pointed at a gitdir
  that no longer existed, so git could not see it. It held five files absent from `main`,
  and `git log --all` showed every one deliberately removed by a named commit — `37db2527`
  de-cluttered the repo root, `6742c8dc` was housekeeping, and `09449cd1
  refactor(macros): remove @MCPTool and @BuilderInitializable` took both macro files out
  on purpose.

Two of the removals failed first with "Directory not empty", which is Dropbox sync rather
than git; a retry loop cleared them. See `feedback-worktree-spm-conflicts`.
