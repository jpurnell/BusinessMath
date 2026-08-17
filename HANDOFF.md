# Handoff — 2026-08-17

**v2.6.0 is tagged, pushed, and green on CI.** The release that was held for two
months is out. What follows is what shipped, the one decision waiting on you, and
the things I got wrong on the way — the last of those being the most useful part.

## State

| | |
|---|---|
| branch | `main`, clean, **0 ahead / 0 behind `origin/main`** |
| HEAD | `0041e0b` |
| tag | **`v2.6.0`** → `c6e44a7`, pushed |
| CI on the tagged commit | **success** (run 2026-08-15T16:49) |
| tests | **6,610 in 582 suites**, 0 failures, ~42s |
| build | 0 warnings; CI-parity solver threshold 500ms clean |
| `quality-gate --check all` | **43 of 43, 0 errors, 0 warnings**, installed binary |
| nightly Release Tests | green through 2026-08-17 |
| **gate on GitHub CI** | **still not running** — see the open decision |

### Commits after the tag

```
eaff6ee  fix(docs): three XNPV/XIRR figures the program did not reproduce
59a66df  ci(gate): re-enable the Quality Gate workflow, runnable on demand
90d802a  ci(gate): grant issues:write so the gate workflow can start
3caa230  ci(gate): temporary diagnostic pin      (reverted by the next commit)
0041e0b  ci(gate): revert the diagnostic pin, and record what it proved
```

---

## The one decision waiting on you

**The `Quality Gate` workflow cannot run, and the fix is a judgement call, not a patch.**

`BusinessMath` is **public**. `jpurnell/quality-gate-swift` is **private**. Three other
public repos — `businessMathMCP`, `ApplesoftBASIC`, `jpurnell.github.io` — call the same
private reusable workflow and have been dead the same way since June.

The failure gives you nothing to work with: **0 seconds, no job, no log, no annotation**,
and the run is titled by file path because GitHub never parsed a `name`.

What was ruled out, so nobody repeats it:

- **`245cd20` / `issues: write`.** Pinning the caller to `4f65852` — the last commit before
  that change — failed *identically*. The cause is constant, not a change in the callee.
  (`issues: write` was still granted and left in place: the callee does require it, and its
  absence would break `ApplesoftBASIC` independently, whose default workflow token is read-only.)
- **Repo permission ceiling.** BusinessMath's default workflow token is already `write`.
- **The private repo's Actions access policy.** Already `user`.
- **Inputs and secrets.** Every input we pass exists and is optional; `CORPUS_PUSH_TOKEN` is defined.
- **SSH/auth.** Authenticates fine; read access works.

The timeline fits a visibility change: the gate **succeeded** at 2026-06-17 07:53 in two
public repos and startup-failed the next morning. `245cd20` landing at 14:08 that same day
is a coincidence that cost most of an investigation. GitHub emits an event when a repo goes
*public*, not private, so the flip cannot be dated from the API — the timeline is
corroboration, not proof.

### Two ways forward

1. **Publish `quality-gate-swift`.** Almost certainly fixes all four repos at once.
   One-way: content gets fetched and indexed even if reverted. Also note **public repos get
   unlimited free Actions minutes and private ones bill against quota** — so if the repo went
   private to reduce CI cost, that reasoning runs backwards.
2. **Inline the gate steps and keep it private.** The reusable workflow already does
   `git clone --depth 1 … quality-gate-swift.git && swift build -c release` internally, so it
   never needed cross-repo `uses:` resolution. Inlining that into each caller, authenticated
   with a PAT, sidesteps the rule entirely. Costs: the steps duplicate across four repos, and
   `CORPUS_PUSH_TOKEN` becomes load-bearing rather than incidental — it is dated 2026-06-07
   and **may be expired; that has not been verified**.

Until one of these happens, "CI green" means build, test, lint and the Linux compile check.
**It has never included the gate.** Every release note in this repository that implied
otherwise was wrong, including the ones written this session.

---

## Open work, in rough priority order

1. **~20 residual `Date()` anchors** across eight DocC articles (`3.14-DebtAndFinancingGuide`,
   `Part3-Modeling`, `1.2-TimeSeries`, `3.8`, `3.16`, and others). Three were fixed in
   `eaff6ee`; the rest mostly feed illustrative constructions rather than documented
   `// Result:` values, which is why `doc-claims` does not flag them. Same latent class.
2. **`doc-claims` flakiness is a property of the checker's design, not a bug to wait out.**
   It runs each article twice and compares, so a non-reproducible value is caught only when
   the two runs straddle whatever boundary moves it. A green is weak evidence; several greens
   are weak evidence several times. Treat a *single* red as authoritative.
3. **`UnboundedRecursionIsAnError`** — the fourth proposal from this release, still `proposed`
   in quality-gate. Needs its advisory window.
4. **The orphan worktree `agent-a064a9af`**, from April 14, not registered with git.

---

## Corrections — read this before trusting anything above

Four claims in this repository's own documents were wrong when committed. They are listed
because the pattern matters more than the individual errors.

- **"The `gpu-safety` fix is staged, uncommitted, not installed."** It had been committed and
  installed twenty minutes earlier. The claim was carried across a context boundary and
  written into `master_plan.md` as blocker #1 without re-checking. Cost of the check: one
  `git status`.
- **"154 commits since the tag, not yet pushed."** 119 were already on origin.
- **"`continue-on-failure: true` means the gate can never fail CI."** It is not GitHub's
  `continue-on-error` — there is none in the reusable workflow, so a red gate *does* fail the
  job. It maps to the gate's own flag, "run the remaining checks even if one fails." Removing
  it would make CI report **less**. It stays.
- **"The pre-push hook only ran 52 tests."** A misread per-target summary; the log holds 57
  such lines, one per test target.

The `continue-on-failure` error also explains a thing left parked as "unexplained": local runs
reporting `16 of 43 checkers · 27 not selected`. Without that flag the gate **exits at the first
failing checker**. Nothing was being skipped by selection — the run was ending early. An
anomaly tolerated and a name not verified were the same fact seen from two directions.

---

## Two mechanisms that make a push report success and move nothing

Both were hit this session. Either one alone produces a ref that did not move, with a hook
that printed `Pre-push passed`.

1. **The hook never drained stdin.** Git writes the ref list to the hook's stdin; `swift
   build`/`swift test` inherited that pipe. Fixed with `cat > /dev/null` and `< /dev/null` on
   the build commands, in both the live hook and `scripts/install-hooks.sh`.
2. **The transport idles out.** Git opens the SSH connection *before* running the hook, then
   leaves it idle for the whole build. The server drops it, and git writes the pack to a closed
   socket. The defence lives in `~/.ssh/config`, not the hook:

   ```
   Host github.com
       ServerAliveInterval 30
       ServerAliveCountMax 40
   ```

Keep both — they are complementary, not alternatives.

**And a third way to be fooled:** `git push … | tail` reports *tail's* exit status, so a failed
push reads as clean. **Verify a push by transfer — `git ls-remote origin <branch>` — never by
exit status.** I reported a successful push twice on this basis before checking the ref.

---

## Working notes

- **Always `quality-gate --no-cache`.** A cached run silently executes a fraction of the
  checkers and prints an identical `PASSED`.
- `.quality-gate.yml` is tracked now. Unknown keys are a **startup refusal** in current
  quality-gate, not a silent discard — which is how `checkers:` (schema key: `enabledCheckers`)
  disabled `recursion` for as long as the file existed, in a repository whose parser had two
  unbounded recursions reachable from public API.
- Two index stores exist. `.build/out/v5` is what checkers read on Swift 6.4;
  `.build/index-build` is a derelict. Measure the one that was returned.
