# One compiler warning under `--strict`, and a README that had stopped counting

**2026-10-05** · `fc986410` on `main`, after `v3.0.0-alpha.11` · 8,975 tests / 837 suites ·
quality-gate `--check all --strict --no-cache` 46/46, 0 errors, 0 warnings, no suppression
markers added · CI run 37319648861 green on all four jobs

A short session. `quality-gate --check build --strict` failed on a single warning in a test
file. It was fixed by changing what the test compares, and the README was reconciled against
the figures the full run produced.

---

## What changed

### The warning

`Tests/BusinessMathTests/ComparableInversionTests.swift:38` read

    let rawAtLeast: Bool = Double.nan >= 1.7e9

and Swift reported "comparison with '.nan' using '>=' is always false". The compiler was
right: with a literal `.nan` as an operand it knows the answer at compile time, so the line
was pinning a constant rather than a runtime comparison. Without `--strict` the gate passes
with that warning; with it, one warning fails the run.

The raw comparison now uses the two `Double`s that back the test's own fixtures:

    let rawNaN: Double = Self.nanDate.timeIntervalSinceReferenceDate
    let rawReal: Double = Self.realDate.timeIntervalSinceReferenceDate
    #expect(rawNaN.isNaN, "the fixture must still carry the NaN it claims to")
    let rawAtLeast: Bool = rawNaN >= rawReal

That is a tighter test than the one it replaces. The raw and the wrapped comparison are now of
the same operands, where before the raw side used a separate literal that only happened to
match `realDate`. The `isNaN` assertion is there because the new operands come from a `Date`:
if `Date` ever stopped preserving a NaN interval, the raw comparison would be of two finite
numbers and the test would have nothing to say about the mechanism it is named for.

### The README

Five figures in the current-status sections were behind the code:

| Claim | Was | Is | Source |
|---|---|---|---|
| tests | 8,962 | 8,975 | `swift test`, this session |
| suites | 835 | 837 | the same run |
| public APIs documented | 7,902 of 7,902 | 7,935 of 7,935 | `doc-coverage` |
| DocC lines | ~50,900 | ~53,900 | line count of the catalogue's 79 `.md` files, 53,934 |
| gate | 40 of 45 checkers | 46 checkers; pre-commit runs 41, pre-push all 46 | the hooks' own summaries |

The "73 comprehensive guides" figure was checked and left. The catalogue holds 79 Markdown
files; 73 is that less the root page and the five part landing pages.

The status table under **Previous release: 2.6.0** (7,908 tests in 721 suites, 7,902 APIs) was
left as it is. It is a snapshot of that release, not a claim about today.

---

## Process

**A bulk replace reached into a historical table.** "7,902 of 7,902 public APIs documented"
appears twice in the README, once as a current claim and once in the 2.6.0 snapshot. The
replacement updated both, and the snapshot was put back by hand. The current figure had
evidently not moved since 2.6.0, which is how the two came to be identical.

**The first commit went out without its changelog entry.** The edit that added the entry was
rejected, because its anchor heading occurs twice in `CHANGELOG.md`, in the same step that ran
the commit. The commit was unpushed and was amended before the push.

**The pre-commit and pre-push hooks select different checker sets** — 41 of 46 and 46 of 46.
The pre-push line is the one that covers everything.

---

## Not done

- `project/master_plan.md` still quotes 8,962 tests / 835 suites at lines 51 and 799. Both are
  dated statements about alpha.10 and alpha.11 and were left; the next release reconciliation
  should carry the new figures.
- There is no session summary between `SUMMARY_2026-09-08` and this one, a span that covers
  2.16.0 through 3.0.0-alpha.11. The CHANGELOG records those releases; this directory does not.
