# Design Proposal: Phase C — three test-quality gate rules

**Status:** proposal, awaiting approval. Nothing in `quality-gate-swift` has been changed.
**Written:** 2026-09-14. **Supersedes** the specification-only draft of the same name, which
skipped Phase 0's template — including the mandatory Adversarial Review, which materially changed
two of the three designs below.

---

## 1. Objective

**Objective:** Land blocking gate rules for three test-quality defects whose corpus-wide sweeps have
just completed, so the swept populations cannot regrow.

**Roadmap reference:** `project/plans/TEST_REVIEW_ROADMAP.md` §5.2, Phase C. Principle 3 of that
document is the argument: *past ~100 sites, a sweep without a rule is a one-off.*

**C4 is already closed and is not part of this proposal.** It was filed as "fix the checker's
nested-scope bug"; reproduced against the shipping binary, the bug does not occur, the auditor
already handles the case in code, and all 18 workaround markers have been removed from BusinessMath.

---

## 2. Motivation

**Current situation.** Three defect shapes were swept out of BusinessMath's 7,799-test suite during
Phases B–E: 211 nil-coalescing assertions, 65 ambient-calendar sites, and 45 constant-true
assertions. Nothing prevents any of them returning.

**How this is worked around today.** It isn't. The corpus grew all three over roughly two years,
and each was found by a human reading tests, not by tooling. The reviews that found them are
expensive and arrive in batches.

**Drawback of the status quo.** Every one of these shapes makes a test *silently stop testing*:
`x[k] ?? 0` turns a missing key into a passing comparison; `Calendar.current` makes a fiscal-year
assertion depend on where CI runs; `#expect(true)` satisfies the existing `missing-assertion` rule
without asserting anything. A regrown instance is indistinguishable from a passing test, which is
precisely the class of defect a gate is for.

---

## 3. Proposed Architecture

**Repository:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Tools/quality-gate-swift`
— **a different repository from BusinessMath**, shared with other projects, whose output is
blocking.

**Modified files:**
- `Sources/TestQualityAuditor/SemanticTestRules.swift` — one `static func` predicate per rule,
  matching the existing shape (`isNonStrictImprovement`, `toleranceRatio`, `isUnvaried`).
- `Sources/TestQualityAuditor/TestQualityAuditor.swift` — call sites in the existing
  `visit(_:)` overrides; emit `Diagnostic(severity:message:filePath:lineNumber:ruleId:suggestedFix:)`
  and honour `overrideIfExempted(line:ruleId:)`.

**New files:**
- `Tests/TestQualityAuditorTests/CoalescedAssertionTests.swift`
- `Tests/TestQualityAuditorTests/AmbientTimeInTestTests.swift`

**Module placement:** `TestQualityAuditor` — the existing home for every rule of this kind. No new
module.

---

## 4. API Surface

No public API. These are internal rule predicates plus diagnostics. The externally visible surface
is the **rule id**, which appears in output and in `// quality-gate:disable <ruleId>` overrides, so
the ids are the compatibility contract:

```swift
// SemanticTestRules
static func coalescedLiteral(in condition: ExprSyntax) -> CoalescingSite?
static func ambientCalendarReference(in node: DeclReferenceExprSyntax) -> AmbientTimeSite?
```

Proposed ids: `coalesced-assertion`, `ambient-calendar-in-test`. **C3 proposes no new id** — see §12.

---

## 5. MCP Schema

**N/A.** These rules are compile-time diagnostics inside a CLI auditor. They expose no callable API
and no AI tool consumes them directly. The gate's existing JSON report already carries `ruleId`,
`filePath` and `lineNumber` for every diagnostic; these rules add rows to it and require no schema
change.

---

## 6. Constraints & Compliance

- **Concurrency:** rule predicates are pure `static func`s over SwiftSyntax nodes — no shared state,
  trivially `Sendable`.
- **Safety:** no force unwraps; every `SyntaxProtocol` cast is `as?` with a `guard`.
- **Determinism:** a syntax visitor over a fixed file set; no clock, no randomness.
- **Generics:** N/A — these operate on concrete SwiftSyntax types.
- **No forbidden patterns:** no recursion without a base case, no pointer escape, no ambient time in
  the checker itself.

---

## 7. Source & API Compatibility

**Breaking changes:** **Yes, for every consuming project, and this is the central risk.** A new
blocking rule fails builds in every repository using the gate — not only BusinessMath. Known
consumers: BusinessMath, BusinessMathMarketData, businessMathMCP, BusinessMathPro,
BusinessMathCharts.

**Mitigation, and it is part of the design:** each rule ships at `severity: .warning` first, in one
release, so every consumer can see its own population before anything blocks. Promotion to `.error`
is a separate, deliberate change.

**Incremental adoption:** yes — `overrideIfExempted` already supports per-line suppression with a
justification comment, which is how legitimate exceptions are recorded rather than silently passed.

---

## 8. Backend Abstraction

**N/A.** Not compute-intensive. The full 42-checker gate runs in about four minutes over ~7,800
tests; three more syntax predicates are noise against that.

---

## 9. Dependencies

**Internal:** `SwiftSyntax` (already a dependency), `SemanticTestRules`, the `Diagnostic` type,
`overrideIfExempted`.
**External:** none.

---

## 10. Test Strategy

**Reference truth:** **the swept BusinessMath corpus itself**, at commit `1063934b`. This is the
strongest oracle available and it is unusual to have one for a linter: every site that *was* a
violation is recorded in git history, and every site that remains has been individually judged and
is documented in the roadmap. A rule is correct when it flags the removed population and does not
flag the retained one.

**Validation trace — specific, checkable:**

| Rule | Must flag | Must **not** flag |
|---|---|---|
| `coalesced-assertion` | `#expect(abs((ma[periods[0]] ?? 0) - 100.0) < 1e-6)` — `TimeSeriesAnalyticsTests.swift@2251c71a:111` | `#expect(found?.count == 1, "got \(found ?? [])")` — coalescing in the *message* |
| | `#expect(result.allocations["proj1"] ?? 0.0 > 0.5)` | `#expect((rHat ?? .infinity) < 1.1)` — poison value makes absence *fail* |
| `ambient-calendar-in-test` | `let calendar = Calendar.current` — `BondPricingTests.swift@2251c71a:31` | every use in `ZoneInvariance.swift` — deliberate, file-level exemption |
| | `Calendar(identifier: .gregorian)` — looks fixed, carries `TimeZone.current` | `gregorianUTC` |

**Test categories:** golden path (a flagged fixture), carve-out (each "must not flag" row above),
exemption (an `overrideIfExempted` comment suppresses and is counted), and idempotence (running
twice yields identical diagnostics).

**Corpus regression:** run the built gate against BusinessMath at `1063934b` and assert
**`coalesced-assertion` reports zero** — the population is already swept, so any hit is a false
positive.

---

## 11. Architecture Decision Review

**ADR check:**
- [x] Reviewed `project/decisions/architecture_decisions.md`.
- [x] Supersedes an existing ADR? **No.**
- [x] Amends an existing ADR? **No.** ADR-004 (`category: testing`) governs *reference fixtures*,
      not lint rules, and is untouched.
- [x] New ADR required? **Yes** — the warning-then-error rollout is a policy decision affecting five
      repositories and will outlive this proposal.

**New ADR draft:**
- **Title:** Blocking gate rules ship as warnings for one release before promotion
- **Category:** testing
- **Key decision:** A new gate rule lands at `.warning`, its population is measured per consuming
  repository, and promotion to `.error` is a separate change — because the gate is shared, and a
  rule that blocks five repositories on its first run cannot be evaluated before it has already
  cost someone a morning.

---

## 12. Adversarial Review

*Required before approval. Answered per rule, because the three are not equally defensible — and
two of them changed as a result.*

### C1 — `coalesced-assertion`

**Strongest case for a different approach.** Do not add the rule. The population is **already
zero**: all 211 sites were swept. A blocking rule over an empty population can only ever produce
false positives — it has no true positives left to find. A reviewer would reasonably say the sweep
*is* the fix, and that the rule buys prevention of a hypothetical regression at the cost of certain
noise.

**Where this design is most likely wrong.** It assumes `?? <literal>` inside an assertion is always
a defect. It is not. For a genuinely **sparse** map — a counter where "no entry" and "zero" mean the
same thing — `#expect((counts[k] ?? 0) >= 0)` is correct and idiomatic, and the rule would force
either noise or an exemption comment on correct code. I found no such case in BusinessMath, but
BusinessMath is one of five consumers and the only one I swept.

**What an experienced critic would say.** *"You are promoting a house style to a blocking rule over
a population you have already reduced to zero, in a shared tool, without having looked at the other
four repositories."*

**Proceeding anyway, with a change:** the counterargument is strong enough that C1 ships at
`.warning` and stays there until the other four repositories' populations are measured. The
prevention argument is real — this shape regrew over two years and no reviewer caught it — but it
does not justify blocking five repositories on day one.

### C2 — `ambient-calendar-in-test`

**Strongest case for a different approach.** Inject a clock instead of linting for one. A rule
catches the symptom; a `Clock`/`Calendar` abstraction threaded through the test support layer makes
the ambient reading *unavailable*, which is a stronger guarantee than a diagnostic anyone can
suppress. That is genuinely better engineering.

**Where this design is most likely wrong — and this changed the design.** The original draft flagged
`Date()` as well as `Calendar.current`, with a "bracketing carve-out" for two readings compared to
each other. **That carve-out is semantic and the implementation is a syntax visitor.** Deciding
whether a `Date()` reading is "compared to another reading" rather than to a constant requires
following the value through bindings, helper calls and stored properties — which a
`SyntaxVisitor` cannot do. It would be wrong in both directions: flagging the nine correct
bracketing tests in `WallClockAdoptionTests`, and missing readings laundered through a helper.

**What an experienced critic would say.** *"The carve-out you need is a dataflow analysis and you
are writing a syntax matcher; it will be wrong in both directions and you will spend more time on
exemption comments than the rule saves."*

**Response — the design changed.** **`Date()` is dropped from the rule entirely.** The rule covers
`Calendar.current` and `Calendar(identifier:)` only, where there is no legitimate bracketing use and
the match is purely syntactic. The `Date()` population (~210 sites) is left to human review and
recorded as such. This is a smaller rule than proposed, and it is the part that can be made correct.

The clock-injection alternative is not rejected — it is deferred, and recorded in §14. It is a
change to BusinessMath's test support, not to the gate, and does not belong in Phase C.

### C3 — `#expect(true)` as a test's only assertion

**Strongest case for a different approach — and it is convincing.** The auditor **already has**
`assertion-on-constant` and `missing-assertion`. `#expect(true)` is not a new defect; it is a
*deliberate evasion of `missing-assertion`*, which counts any `#expect` regardless of what it
asserts. The right fix is therefore not a third rule but a one-line change to an existing one:
**`missing-assertion` should not count an assertion whose condition is a literal.** That closes the
loophole at its source, adds no rule id, and makes the 18 stale workaround markers impossible to
write in the first place.

**Where this design is most likely wrong.** Assuming `#expect(true)` is always evasion. It can be a
reachability marker — "control got here" — which is a real, if weak, claim. Under the proposed
change such a test becomes `missing-assertion`, and the author must either assert something real or
record an exemption. That is the correct outcome, but it *is* a behaviour change to an existing
rule, which is a larger blast radius than a new rule with no existing users.

**What an experienced critic would say.** *"You already have two rules in this space. Adding a third
means you have not worked out which one was wrong."*

**Response — the design changed.** **C3 is withdrawn as a new rule.** It becomes an amendment to
`missing-assertion`: a `#expect`/`#require` whose condition is a boolean literal does not count
toward "has an assertion". Same effect, no new id, and the loophole closes rather than being
policed.

**Blocked on a precondition either way:** 53 `#expect(true)` sites remain in BusinessMath
(`LoggerTests` 13 needing a recording sink, 14 in already-gated benchmark suites, the rest wrapping
throwing calls in `try?`). A rule with 53 known violations is one nobody turns on. **This amendment
must not land until those are resolved.**

---

## 13. Alternatives Considered

**Alternative 1 — no rules; rely on the review programme.**
*Advantage:* zero tooling cost, zero false positives, and the reviews demonstrably find these
shapes — every one in this proposal came from a review.
*Disadvantage:* reviews are expensive, arrive in batches, and are a lagging indicator. All three
populations grew for roughly two years before anyone noticed.
*Why rejected:* §2b of the roadmap makes the complementary case — reviews find *semantic* defects a
rule never could; these three are *syntactic* and are exactly what a rule is good at. Using each for
what it is good at is the point.

**Alternative 2 — a Semgrep rule set in `swift-security-rules` instead of SwiftSyntax checkers.**
*Advantage:* rules as data, editable without rebuilding the gate, shareable outside this toolchain.
*Disadvantage:* Semgrep's Swift support does not model macro expansions, and every rule here is
about the *inside of an `#expect` macro*.
*Why rejected:* the thing being matched is the thing Semgrep cannot see.

**Alternative 3 — fix the tests, delete the rules, and record the patterns in the coding rules
document instead.**
*Advantage:* no shared-tool risk at all; the guidance lands where developers already read it.
*Disadvantage:* documentation does not fail a build, and the corpus is evidence that written
guidance did not prevent 211 instances.
*Why rejected:* partially accepted, actually — C2's `Date()` half is being handled exactly this way,
because a rule there cannot be made correct.

---

## 14. Future Directions

- **Clock injection in test support** could make ambient time unavailable rather than merely
  flagged, which would retire C2 entirely.
- **A per-repository baseline file** could let a rule land at `.error` immediately with existing
  violations grandfathered, which would remove the need for the warning-first release.
- **`unasserted-optional-unwrap` and `coalesced-assertion` might merge** — both are about an
  optional whose absence is silently tolerated inside an assertion.

---

## 15. Open Questions

1. **Have the other four repositories been measured?** C1's and C2's populations are known only for
   BusinessMath. The warning-first release exists to answer this, but it is worth asking whether
   someone should simply run the rules locally against all five first.
2. **Does the `missing-assertion` amendment (C3) need its own ADR?** It changes an existing rule's
   behaviour for five repositories, which is a larger change than adding a new id.
3. **Should `coalesced-assertion` carve out sparse maps**, or require an exemption comment on them?
   No instance exists in BusinessMath; the answer depends on question 1.

---

## 16. Documentation Strategy

**Documentation Type:** API Docs Only.

- Combines 3+ APIs? **No** — two predicates and one amendment.
- Explanation requires 50+ lines? **No** — each rule's rationale fits in its doc comment.
- Needs theory or background? **No.**

Each rule gets a doc comment carrying its carve-outs and one worked example, matching the existing
rules in `SemanticTestRules.swift`. The `TestQualityAuditor.docc` catalogue gains a row per rule id.

**One thing the diagnostics themselves must say:** `try #require` **cannot be inlined into
`#expect`** — `#expect(abs(try #require(x) - v) < t)` fails to compile with *"errors thrown from
here are not handled"*, because the macro expands its condition into a non-throwing closure. Every
converted site needs a real binding **and** its enclosing function marked `throws`. If the
`suggestedFix` omits this, every person who acts on the diagnostic rediscovers it the same way.

---

## Revised scope, after the adversarial review

| | As first drafted | After §12 |
|---|---|---|
| **C1** | new blocking rule | new rule, **`.warning` until the other four repositories are measured** |
| **C2** | `Calendar.current` **and** `Date()`, with a bracketing carve-out | **`Date()` dropped** — the carve-out needs dataflow, not syntax. `Calendar.current` and `Calendar(identifier:)` only |
| **C3** | new blocking rule | **withdrawn as a rule** — becomes a one-line amendment to `missing-assertion`, blocked on the 53 remaining sites |
| **C4** | fix the checker | **already fixed**; 18 workaround markers removed |

Two of four items got smaller and one disappeared. That is the review working.
