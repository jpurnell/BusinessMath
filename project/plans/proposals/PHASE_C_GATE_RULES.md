# Phase C — the gate rules, specified

**Status:** design only. Nothing in `quality-gate-swift` has been changed.
**Written:** 2026-09-14, after B, D and E were swept in BusinessMath.

Phase C's four items land rules in **a different repository** —
`/Users/jpurnell/Dropbox/Computer/Development/Swift/Tools/quality-gate-swift` — whose output is
**blocking** and which is shared with other projects. That is why this is a specification rather
than a branch: a blocking rule that misfires stops the next commit in every project that uses the
gate, not just this one.

## Where the code lives

| | |
|---|---|
| Auditor | `Sources/TestQualityAuditor/TestQualityAuditor.swift` (~47K, the SwiftSyntax visitor) |
| Rule predicates | `Sources/TestQualityAuditor/SemanticTestRules.swift` (~32K, static helpers per rule) |
| Tests | `Tests/TestQualityAuditorTests/SemanticTestRuleTests.swift` and siblings |

Existing rule ids, for naming consistency: `assertion-on-constant`, `missing-assertion`,
`non-strict-improvement`, `tolerance-without-magnitude`, `unasserted-optional-unwrap`,
`unseeded-random`, `unvaried-parameter`, `weak-assertion`, `force-try-in-test`, `hardcoded-date`,
`skipped-test-inventory`.

The shape to copy: a `static func` predicate in `SemanticTestRules`, called from a `visit(...)`
override in the auditor, emitting a `Diagnostic` with a `ruleId` and a `suggestedFix`, and
respecting `overrideIfExempted(line:ruleId:)`.

---

## C4 — **already fixed. The work was deleting the workarounds, and that is done.**

C4 was filed as "fix the checker's nested-scope bug — it misses assertions after a local `func`
and inside nested `struct` suites", with 18 `#expect(true) // TEST-QUALITY: checker workaround for
nested struct scope` markers in BusinessMath standing in for it.

**Reproduced against the shipping binary and it does not reproduce.** Removing the marker from
`testMonteCarloIntegration` — a test with two local `func` declarations followed by four real
`#expect`s — produces **no** `missing-assertion` diagnostic. The auditor already handles it, and
says so in its own code:

```swift
} else if currentTestFunctionName != nil {
    // A helper declared inside the test body. Its `return` is its own.
    nestedScopeDepth += 1
}
```

`currentTestHasAssertion` is set by *any* `#expect`/`#require` macro anywhere in the test's
subtree, so nesting depth never suppressed it.

All 18 markers have been removed from BusinessMath and the checker reports 0 errors. **C4 needs no
change to the tool.** If the bug was real once, it was fixed and the workarounds outlived it —
which is its own lesson: a workaround with no expiry outlives its cause.

---

## C1 — nil-coalescing inside an assertion

**Rule id:** `coalesced-assertion`

**What to flag.** A `??` whose right-hand side is a *literal* appearing inside the condition of
`#expect` or `#require`. `x[k] ?? 0` turns a missing lookup into a passing comparison, so a test
that stops finding its key stops testing and says nothing.

**Carve-outs, all of which appear in BusinessMath today:**

1. **String interpolation in the message, not the condition.** `#expect(found?.count == 1, "got
   \(found ?? [])")` is harmless — the coalescing formats a failure message. Flag only the
   condition argument.
2. **`?? .infinity` / `?? .nan`** as a deliberate poison value. These make a missing lookup *fail*
   rather than pass, which is the opposite of the defect. Flag only literals that could satisfy
   the comparison.
3. **Non-optional `??`** does not exist in Swift, so no check needed there.

**Suggested fix text:** `let value = try #require(expr)` on the line before, then the comparison
against `value`. **The suggestion must say that `try #require` cannot be inlined** — see below.

**Baseline:** 211 sites measured in 24 files (the roadmap said 225). **All 211 are now swept**, so
the rule lands at **zero**, not as a burn-down. That is a better place to introduce a blocking rule
than the roadmap anticipated.

---

## C2 — ambient calendar or clock in a test target

**Rule id:** `ambient-time-in-test`

**What to flag.** `Calendar.current` and `Date()` in files under the test target.

**The carve-out is the whole design, and without it the rule is wrong:**

1. **Bracketing.** Two `Date()` readings either side of a call, compared to each other for
   *ordering*, are correct and must not be flagged. `WallClockAdoptionTests` has nine of these.
   Flag a reading used in an **arithmetic comparison against a fixed value**, not one compared to
   another reading.
2. **Zone-proof suites.** `ZoneInvariance.swift`, `CalendarZoneInvarianceTests`,
   `ThirtyThreeSixtyVariantTests`, `CouponPeriodCalendarTests` and `BondClockZoneInvarianceTests`
   use `Calendar.current` **deliberately**, to prove behaviour is invariant under it. These need a
   file-level exemption comment rather than a silent pass, so the exemption is visible.
3. **`Calendar(identifier: .gregorian)` must be flagged too.** It *looks* fixed and carries
   `TimeZone.current`. This is the form that put January's value in the previous year's Q4 and was
   invisible to a search for `Calendar.current`.

**Suggested fix:** `gregorianUTC` (internal to BusinessMath, reachable from tests via
`@testable import`).

**Baseline:** 91 `Calendar.current` sites measured. **65 are now swept**; the 26 remaining are the
zone-proof suites plus comment-only mentions. The `Date()` population (~210) is largely the
bracketing case and should be measured separately *after* the carve-out exists, or the rule will
report a number nobody can act on.

---

## C3 — `#expect(true)` as a test's only assertion

**Rule id:** `constant-only-assertion` (note: `assertion-on-constant` already exists — check
whether this is a widening of that rule rather than a new one).

**What to flag.** A test function whose *only* assertion is `#expect(true)` or `#expect(false)`.
Not any `#expect(true)` — one alongside real assertions is redundant rather than dangerous.

**Carve-out:** a test that asserts nothing but *not throwing* should use
`#expect(throws: Never.self)`, and the suggested fix should say so, because that is the form this
corpus converted to.

**Baseline:** 72 measured. 18 were the stale C4 workarounds and are **gone**; 27 have been
converted. **53 remain**, and they break down as: `LoggerTests` 13 (need a recording sink),
`MatrixBackendBenchmarks` 9 and `MonteCarloGPUPerformanceTests` 5 (in suites already gated
`.benchmarkOnly`), and singletons whose throwing call is wrapped in `try?`, where a no-throw claim
is meaningless and a different assertion is wanted.

---

## One finding the rules should encode, because it cost time

**`try #require` cannot be inlined into `#expect`.** Writing

```swift
#expect(abs(try #require(x) - v) < t)     // error: errors thrown from here are not handled
```

fails to compile: the macro expands its condition into a non-throwing closure. Every converted site
needs a real `let` binding **and** its enclosing function marked `throws`. C1's and C3's suggested
fixes should both say this, or every person who acts on the diagnostic will discover it the same
way.

---

## Order to land them

1. **C4 — nothing to do.** Confirmed already fixed; workarounds removed.
2. **C2 first among the rest**, because its carve-out is the one that makes a rule wrong if
   omitted, and it wants the most thought.
3. **C1 next.** Its population is already at zero, so it lands clean.
4. **C3 last**, after the 53 remaining sites are either converted or exempted — a blocking rule
   with 53 known violations is a rule nobody can turn on.
