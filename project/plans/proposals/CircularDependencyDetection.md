# Design Proposal: circular-dependency detection

**Status:** proposal, for argument. Nothing here is implemented.

**Last updated:** 2026-08-10

**Companion:** `IterativeSolver.md`, in this folder. The two are halves of one
capability — **detect the cycle, then resolve it** — and neither is worth much alone. Detection
without resolution tells an Excel migrant that their model is broken when it is not. Resolution
without detection has nothing to tell it *what* to iterate. Read both before deciding either.

Every claim about current state below carries a `file:line` and was verified against the working
tree on 2026-08-10, after the retraction described in `CHANGELOG.md:14-56` landed.

---

## 1. The motivating case

**People migrating from Excel.**

A circular reference in a spreadsheet is a defect. A circular reference in a *three-statement
financial model* is the normal shape of the thing. The canonical instance is **circular interest**:

- Interest expense depends on the average debt balance for the period.
- The debt balance depends on the period's cash flow — a revolver draws to cover a shortfall and
  sweeps to repay a surplus.
- The cash flow depends on interest expense, because interest is a cash cost.

`interest → debt → cash flow → interest`. Every analyst who has built a levered model has built
this cycle deliberately. Excel's answer is `File → Options → Formulas → Enable iterative
calculation`, with `Maximum Iterations` and `Maximum Change`, and the model settles.

There are others of the same kind, and they are not exotic:

| cycle | why it closes |
|---|---|
| circular interest | interest is a cash cost, and cash determines the debt it is charged on |
| cash sweep / revolver | the amount swept depends on the cash left after the sweep's own interest |
| bonus or profit-share on net income | the accrual is an expense inside the income it is computed from |
| tax on income net of an interest shield | the shield depends on interest, which depends on debt, which depends on after-tax cash |
| percentage fee on a total that includes the fee | the classic gross-up |

A modelling library that cannot express these is a wall for anyone porting a real model, and it is
a wall they hit on day one. That is the constituency this proposal serves. It is not a library
maintainer's interest in graph theory.

**What this means for the design, stated up front:** the important output of a cycle detector is
not "your model is invalid". Most of the time it is "here is a cycle, it has three accounts, it is
linear in them, and it is the kind that resolves". Section 6 is where this is argued, and it is the
central question of the document.

---

## 2. What exists today

The two functions that used to claim this capability have been deleted. From `CHANGELOG.md:14-56`:
`ModelDebugger.detectCircularDependencies(in:)` was `return []` unconditionally, and
`ModelInspector.detectCircularReferences()` walked a graph that assigns `graph[revenue.name] = []`
(still visible at `Developer Tools/ModelInspector.swift:174`) and so could only ever return
`false`. Both are gone. This proposal is what replaces them, and it starts from an honest zero
rather than from a stub.

What survived the retraction:

| symbol | state, verified |
|---|---|
| `BusinessMathError.circularDependency(path: [String])` | declared `Error Handling/BusinessMathError.swift:74`; code `E201` at `:340`; message at `:167`. **Zero throw sites in `Sources`** — the only `throw BusinessMathError.circularDependency` in the tree is inside a documentation example, `1.7-ErrorHandlingGuide.md:504`. |
| its `recoverySuggestion` | `BusinessMathError.swift:264-275`. Rewritten during the retraction; it no longer promises an iterative solver, and now names `FormulaEvaluator.accountNames(in:)` at `:271`. Two tests pin that string: `BusinessMathErrorTests.swift:199` and `:496`. |
| `FormulaEvaluator.accountNames(in:)` | `Time Series/FormulaEvaluator.swift:136`. `public static`, tokenises without evaluating, returns `Set<String>`. **Zero production call sites** — every reference outside its own file and tests is documentation. |
| `ModelInspector.buildDependencyGraph()` | `Developer Tools/ModelInspector.swift:158`. Still present. Returns `[String: [String]]`, but the edges are synthesised from component *kind* (`:165` gives variable costs every revenue name, `:168` and `:174` give everything else `[]`), not from anything a user wrote. It is a picture of the type system, not of a model. |
| `1.6-DebuggingGuide.md:183-240` | "Finding Dependency Cycles" — states plainly that the library does not do this, and shows a caller-side depth-first walk over a `[String: String]` definition map, with `accountNames(in:).sorted()` at `:215` and `definitions.keys.sorted()` at `:223`. |

That last row matters more than it looks. **The article already contains the algorithm this
proposal wants to ship**, written to be read, already sorting for determinism. The question is not
"can this be done" — it demonstrably can, in about twenty lines. The question is what the library
should own, and §4 and §6 are where the real work is.

---

## 3. Why there is nothing to analyse yet

The hard part of this proposal is not the algorithm. It is that **the condition is not currently
representable**. There is no way, using the public API, to construct a model in which one account
refers to another. Four independent confirmations:

**`FormulaEvaluator` maps names to data, not to formulas.**
`Time Series/FormulaEvaluator.swift:106` stores `private let accounts: [String: TimeSeries<T>]`.
Resolving a `.name` node is a single dictionary lookup — `:150-151`, `guard let series =
accounts[name]` — with no re-entry into the evaluator. A formula can name an account; an *account*
cannot name a formula. Mutual reference has nowhere to live.

**`FinancialModel` holds components, and components hold amounts.**
`Fluent API/ModelBuilder.swift:42` declares the type; `:46` and `:49` hold
`[RevenueComponent]`/`[CostComponent]`. Neither carries a formula string or any reference to
another component by name.

**`Account` holds a computed series.**
`Financial Statements/Account.swift:382`, with `public let timeSeries: TimeSeries<T>` at `:411`.
The account *is* its answer. There is no derivation recorded.

**`AccountNode` is a tree, and a tree is acyclic by construction.**
`Financial Statements/AccountNode.swift:62`, `children: [AccountNode<T>]` at `:77`. Aggregation
hierarchies cannot contain cycles even in principle — which is correct for what they are, and
therefore not the layer where this problem lives.

So the first deliverable of this proposal is not a detector. It is **a place for a cycle to
exist.**

### 3.1 The finding that most changes the picture

`FormulaEvaluator`'s own documentation, `Time Series/FormulaEvaluator.swift:99` and
`1.9-FormulaEvaluation.md:152-156`:

> No functions, no aggregation, **no references to other periods**. A formula reads accounts in
> the period it is evaluating and combines them arithmetically.

This is a deliberate and well-argued restriction — the reasoning at `1.9:158-161` is that every
feature added to a configuration language is another way for that configuration to be subtly
wrong, and it is right. But it has a consequence nobody has written down:

**The canonical circular-interest model cannot be expressed in this formula language, and adding
cycle detection will not change that.**

Circular interest needs two things, not one:

1. A **within-period cycle**: `interest = rate × (openingDebt + closingDebt) / 2`, where
   `closingDebt` depends on `cashFlow`, which depends on `interest`. Cycle detection plus
   iteration handles this.
2. A **cross-period roll-forward**: `openingDebt(t) = closingDebt(t−1)`. This is a lag, and the
   language has no lag operator. `TimeSeries` has no `lag`/`shift`/`previous` either — the public
   surface at `Time Series/TimeSeries.swift` and `TimeSeriesOperations.swift` has `fillForward`
   (`:119`), `fillBackward` (`:150`), `interpolate` (`:211`), `aggregate` (`:297`) and the four
   period-wise operators (`:391-427`), and nothing that reads period *t−1* while computing *t*.

A user could supply `openingDebt` as data, solve one period, and re-supply — but then they are
running the roll-forward by hand, in Swift, and the library has helped with half a problem.

**Recommendation: say this in the proposal's own scope section rather than discovering it during
implementation.** Either (a) the deliverable is honestly scoped to *within-period* cycles and the
roll-forward stays the caller's, and the documentation says so in the same sentence that introduces
circular interest; or (b) a prior-period reference is added to the language — a real expansion,
with its own design decisions about the first period, about periodicity mismatches, and about what
`[Debt]{-1}` should even look like — and it should be its own proposal, not a paragraph in this
one.

I recommend (a) for the first release, stated loudly, and (b) tracked as the thing that makes the
motivating case actually work end to end. Shipping (a) while *illustrating* it with circular
interest would repeat exactly the failure the retraction just corrected: documentation describing a
capability the code does not have.

---

## 4. The data-model change

Something must hold formulas, keyed by the account they define. Four candidates, in the order they
suggest themselves.

### Option A — a free function over `[String: String]`

Ship the `1.6-DebuggingGuide.md:204` walk as library API, taking the definition map directly.

```swift
public enum DependencyGraph {
    public static func cycles(in definitions: [String: String]) throws -> [Cycle]
}
```

**Cost:** almost none. No new stored type, no change to any existing type, no break for any
caller. Works today, against the evaluator that exists.

**What it gives up:** `[String: String]` is a weak type. Nothing distinguishes an account name from
a typo, nothing carries units or a role, nothing stops two definitions of the same account, and the
result cannot be handed back to anything — the caller still has to drive `FormulaEvaluator` in
topological order themselves.

### Option B — a `ModelDefinition` type: formulas as a first-class model

A new value type holding the *derivation*, distinct from `FinancialModel`, which holds results.

```swift
public struct AccountDefinition: Sendable {
    public let name: String
    public let formula: String          // parsed lazily; names come from accountNames(in:)
}

public struct ModelDefinition<T>: Sendable {
    public private(set) var definitions: [AccountDefinition]   // ordered, deterministic
    public var inputs: [String: TimeSeries<T>]                 // leaves — supplied, not derived
}
```

**Cost:** a new public type and its documentation. No break to `FinancialModel`, `Account`,
`FormulaEvaluator` or anything downstream, because it sits *beside* them rather than inside them.
It composes with `FormulaEvaluator` rather than replacing it: evaluation of a single definition is
still `FormulaEvaluator(accounts:).evaluate(_:)`.

**What it buys:** a place to put everything §6-§8 need — the expected-cycle declarations, the
detection report, the topological evaluation order, and later the solver's configuration. It also
gives `accountNames(in:)` its first production call site, which is the point at which that function
stops being decoration.

**Note the ordering choice already made for you.** `definitions` is an *array*, not a dictionary.
Swift's `Dictionary` iteration order is seeded per process and is not stable across runs; storing
the definitions in insertion order and deriving every traversal order from a sort makes
reproducibility structural rather than incidental. §7 of `IterativeSolver.md` argues this at
length; it applies here too, because a *cycle path* is an ordered thing and its rotation depends on
which node the walk entered first.

### Option C — teach `FormulaEvaluator` to hold formulas alongside data

Add a second dictionary, `formulas: [String: String]`, and make `.name` resolution re-enter the
evaluator when the name is a formula rather than a series.

**Cost:** this is the option that looks cheapest and is the most expensive. It turns a
value-semantic, `Sendable`, stateless struct (`FormulaEvaluator.swift:103`) into something with a
recursive evaluation path, a memo cache, and a re-entrancy hazard. Every existing caller of
`evaluate(_:)` inherits the possibility of a cycle error from a function that today can only fail
on syntax and missing accounts. And it conflates two jobs — "evaluate this expression" and "run
this model" — in one type, which is the reason `ModelDebugger`'s doc comment had to be corrected
during the retraction (`Diagnostics/ModelDebugger.swift:527-540`).

**Reject.** The evaluator is small, sharply scoped and correct. Keep it that way and build above
it.

### Option D — extend `FinancialModel`

Give `RevenueComponent`/`CostComponent` an optional formula.

**Cost:** `FinancialModel` is a result-builder DSL whose components are already fixed/variable
amounts (`ModelInspector.swift:141-149` switches on exactly those two cases). Adding a third,
formula-shaped kind means every consumer — `calculateRevenue()` at `ModelBuilder.swift:95`,
`ModelInspector.listCostDrivers()` at `:132`, `ModelDebugger.validate(_:)` at `:552` — grows a
branch for a component that cannot be evaluated without a solver. It also makes the model
non-evaluable in general, which is a real semantic break for existing callers who currently know
that `calculateProfit()` always returns a number.

**Reject**, or at most defer to a later bridging step once `ModelDefinition` has proven itself.

### Recommendation

**Option B, with Option A's signature preserved as the low-ceremony entry point.** The graph
algorithm should be expressible over a bare `[String: String]` — that keeps it testable in
isolation and keeps the `1.6` article honest — and `ModelDefinition` should be the thing that owns
it, carries the policy from §6, and hands its ordering to the solver.

Cost to existing callers of B: **zero**. That is the argument.

---

## 5. The algorithm

### 5.1 Tarjan, and why the standard answer is only half the answer

Tarjan's strongly-connected-components algorithm is the right primitive: single depth-first pass,
`O(V + E)`, finds *every* SCC rather than the first cycle, and the SCC condensation is exactly the
structure the solver needs (§ `IterativeSolver.md` §4 — iterate inside each SCC, evaluate the SCCs
in topological order). Kosaraju is equally correct and needs the reverse graph; Tarjan does not.
Take Tarjan.

But an SCC is a **set**, and what a user asks for is a **path**: `A → B → C → A`, in order. That is
what `1.6-DebuggingGuide` used to print, and it is the difference between a diagnostic someone can
act on and a list of names. The two are not the same problem, and conflating them is the most
likely way to ship something technically correct and practically useless.

Proposed shape, therefore:

1. **Tarjan** over the definition graph → the set of SCCs with more than one member, plus any
   single-member SCC carrying a self-edge (`A: "A * 1.1"`, which Tarjan reports as a trivial
   component and which is nonetheless a cycle).
2. **Within each SCC**, a bounded depth-first walk restricted to that component's vertices, to
   recover one concrete cycle path. Because the walk is confined to an SCC, a cycle is guaranteed
   to exist and will be found; the exponential blow-up that makes general cycle enumeration
   expensive does not arise when you only need *one*.
3. **Report the SCC and the path.** The SCC is the canonical identity (§6 depends on this); the
   path is the human-readable rendering.

### 5.2 What was considered and rejected

| approach | why not |
|---|---|
| DFS-with-path only, as `1.6:204` does | returns the *first* cycle and stops. A model with three independent circularities reports one, the user fixes it, and the next appears. Fine for an article; not fine as the library's answer. |
| Johnson's algorithm, enumerating all elementary cycles | correct, and output-sensitive — but the output itself is exponential. A 6-account SCC can hold 400+ elementary cycles, and printing them is not a diagnostic, it is a denial of service on the reader's attention. |
| Iterative deepening / BFS shortest cycle | a *shortest* cycle is not the most explanatory one. `interest → cashFlow → interest` is shorter than the four-account path an analyst recognises, and less useful. |
| Detecting cycles at evaluation time, by re-entry | this is Option C's failure mode. It finds a cycle only on the code path that happens to hit it, with whatever data happened to be loaded, and it cannot report anything before data exists. Detection should work on an empty model. |

### 5.3 Determinism

Non-negotiable, and cheap here if it is designed in.

- Adjacency lists come from `accountNames(in:)`, which returns `Set<String>`
  (`FormulaEvaluator.swift:136`). **Sort them.** The `1.6` article already does
  (`1.6:215`), and the reason is that `Set` iteration order is seeded per process.
- Root order for the outer DFS loop: sort the definition names (`1.6:223` does this too), or use
  `ModelDefinition`'s stored insertion order. Either is deterministic; pick one and document
  which, because it decides which rotation of a cycle path a user sees.
- The reported SCC membership should be emitted **sorted**, so that two runs produce byte-identical
  diagnostics and so that §6's expected-cycle matching has a canonical key.

This is the same standard the library applied in `git show 0b52198` and `git show d247691`, and the
same reasoning as `Determinism/WallClock.swift`. A diagnostic that names a different account first
on Tuesday is a diagnostic nobody will trust on Wednesday.

---

## 6. What "detected" should mean

**This is the central question of the proposal.** Everything above is engineering; this is the
design.

### 6.1 The trap

The obvious API is:

```swift
func validate(_ model: ModelDefinition<T>) throws   // throws E201 on any cycle
```

It is wrong, and it is wrong in a way that would take a year to walk back. It says *every cycle is
an error*. For the entire constituency named in §1, the cycle is the model. An Excel migrant would
port their three-statement model, get `E201: Circular dependency detected: interest → debt →
cashFlow → interest`, and conclude — correctly, from the evidence we gave them — that this library
cannot represent their work.

Excel gets this right and has for decades. A circular reference is an *error* when iterative
calculation is off and a *resolvable condition* when it is on. The user declares which regime they
are in. That declaration is the whole design.

### 6.2 The proposal: detection reports, classification decides

Split the two jobs that "detect" is hiding.

**Detection is total and never throws.** It returns a report describing what is in the graph. A
model with a cycle is not thereby invalid, and this function has no opinion.

```swift
public struct DependencyReport: Sendable {
    public let evaluationOrder: [String]      // topological over the SCC condensation
    public let cycles: [Cycle]                // empty for an acyclic model
    public let undefinedNames: [String]       // named by a formula, defined by nothing — the leaves
}

public struct Cycle: Sendable, Hashable {
    public let accounts: [String]             // SCC membership, sorted — the canonical identity
    public let path: [String]                 // one concrete traversal, first == last
    public let form: Form                     // see §7
}
```

**Classification is a separate call, and takes a policy.**

```swift
public struct CyclePolicy: Sendable {
    /// Cycles the caller expects. Matched by account *set*, never by path.
    public var expected: Set<Set<String>>
    /// What to do with a cycle that is not in `expected`.
    public var unexpected: Disposition        // .error (default) | .warn | .allow
}
```

### 6.3 Why matching is by set and not by path

Because a path is not canonical and a set is. `interest → debt → cashFlow → interest` and
`debt → cashFlow → interest → debt` are the same cycle; which one a user sees depends on which
account the DFS entered first, which depends on the sort order of names, which changes when they
rename an account. An expected-cycle declaration keyed on a path would silently stop matching after
a rename and start reporting an error on a model the user has already blessed. Keyed on the SCC
membership, it survives renaming everything except a member.

This is not a detail. It is the difference between a suppression mechanism people use and one they
learn to ignore.

### 6.4 The default

`unexpected: .error`. A user who has declared nothing gets told about cycles, which is the behaviour
that catches the genuine mistake — `1.7-ErrorHandlingGuide.md:481-500`'s `A → B → C → A`, a real
error with no financial meaning. A user who has declared the interest cycle gets silence about it
and an error about anything else. That is the correct asymmetry: expressing an intent is cheap,
and the thing we must never do is let an unintended cycle pass unremarked.

### 6.5 The alternative that was considered and rejected

**Declaring intent at the account, not at the model** — a `@circular` marker on the definition that
closes the loop. Rejected: it puts the declaration on *one* account of a cycle when the cycle is a
property of the group, and it makes the meaning depend on which account the modeller happened to
think of as "the one that closes it". For circular interest, three different modellers would mark
three different accounts and all three would be reasonable. A cycle is a set; declare it as a set.

**A single global `allowCycles: Bool`, exactly like Excel's checkbox.** Rejected as the *only*
mechanism, though it should exist as sugar for `unexpected: .allow`. Excel's checkbox is a blunt
instrument and its cost is well known to anyone who has used it: once iterative calculation is on, a
genuine accidental circularity — a fat-fingered `=SUM` that includes its own cell — is silently
absorbed into the iteration and never reported. That is precisely the failure mode this library
spent a day removing elsewhere. Per-cycle declaration is strictly more informative and costs the
user one line.

---

## 7. Resolvability: what detection can honestly say

The report should say whether a cycle looks resolvable by iteration. It must be careful about how
much it claims, because `TestQualityAuditor.md` §6a is directly on point:

> A diagnostic that confidently names the wrong cause is worse than one that says "here are the
> four things this could be", because a confident wrong answer is followed.

**What detection cannot know:** whether iteration converges. That depends on the data, on the
coefficients, and on the initial values, none of which detection has seen. Any field named
`willConverge` is a lie waiting to be believed.

**What detection genuinely can know, from the formula text alone.** The grammar
(`FormulaEvaluator.swift:76-82`) is `+ − × ÷`, parentheses, unary minus, names and numbers. That is
small enough that a structural classification is decidable, not heuristic:

| `Cycle.Form` | condition, checked on the parse tree | what it licenses saying |
|---|---|---|
| `.linear` | no cycle member appears multiplied by another cycle member, and none appears in a denominator | the cycle is a linear system in its members. It has a unique solution unless the system is singular — and it can be solved **exactly**, without iterating at all. See `IterativeSolver.md` §9. |
| `.nonlinear` | a cycle member multiplies another, or divides | iteration is the available method; convergence is a property of the data, not of the structure |
| `.selfReferential` | an account's own formula names itself | usually a typo. `Revenue: "Revenue * 1.1"` has no fixed point except zero and is worth calling out separately. |

Circular interest is `.linear`: `interest = rate × (opening + closing) / 2` is linear in `closing`
because `rate` and `opening` are not cycle members. That single fact is the most useful thing this
whole subsystem can tell a user, and it is available before any data is loaded.

The report should therefore say something like *"this cycle is linear in its three members; a
solver can resolve it exactly"* — a structural claim, provable — and never *"this will
converge"* — a numerical claim, unprovable from here.

---

## 8. Diagnostics

Three consumers, three renderings, one source of truth.

**The error.** `BusinessMathError.circularDependency(path: [String])` already exists and its shape
is already right: an ordered path, rendered `A → B → C → A` at `BusinessMathError.swift:167`. This
proposal gives it its **first throw site in `Sources`** — currently zero, per §2 — which is the
smallest honest way to close the gap between the vocabulary and the code.

One change worth arguing for: the case carries only a path, and §6.3 argued the path is not the
identity. Either add an `accounts:` payload, or accept that the error is the human-facing rendering
and `DependencyReport` is the machine-facing one. I lean to the latter — changing a public error
case's associated values is a break, and the path is the right thing for a message. But it should
be a decision, not an omission.

**The report.** Enumerates every cycle, not the first (§5.2). Sorted, so two runs match.

**The text.** Per §7 and `TestQualityAuditor.md` §6a: state the structural facts, then list the
possibilities in the order they are worth checking, cheapest first.

```
Circular dependency: interest → debt → cashFlow → interest
  Accounts:  cashFlow, debt, interest
  Form:      linear in all three members
  This may be intentional. Circular interest, cash sweeps and gross-ups are cycles
  by design, and a linear cycle has an exact solution.
    • If intended, declare it:  policy.expected.insert(["cashFlow", "debt", "interest"])
    • If not, the usual causes, most common first:
        – a formula that reads a total it contributes to
        – a sign error that turned a subtraction into a feedback
        – an account renamed on one side of a pair
```

Note what that text does *not* do: it does not say "this is an error", and it does not say "this
will work". Both would be claims we cannot support.

---

## 9. What this design cannot do

Stated so it is not oversold, and so the documentation written against it stays true.

- **It sees only declared formulas.** A cycle expressed in Swift — a function that calls back into
  a model — is invisible to it. It analyses configuration, not code.
- **It cannot see cross-period dependencies, because the language has none** (§3.1). This is the
  limitation most likely to disappoint the very users §1 is written for, and it must appear in the
  first paragraph of any documentation, not the last.
- **It cannot distinguish an intended cycle from a mistake.** Only the user can, which is why §6
  makes them say. A library that guessed would be wrong in exactly the cases that matter.
- **It cannot promise convergence** (§7). `.linear` is a structural claim about the formulas, not
  a numerical claim about the data. A linear system can still be singular.
- **It cannot tell you the cycle is *wrong* when it is merely surprising.** A four-account cycle
  that closes through an account the modeller forgot about is a real bug, and this will report it
  as a cycle like any other. The path is what helps; the tool cannot do the recognising.
- **It says nothing about the accounting.** A model can be acyclic, converge, and still not
  balance.

---

## 10. The argument against this proposal

Recorded because a proposal that only argues for itself is worth less.

**The case for doing nothing.** The library just retracted two functions for claiming this
capability. The retraction was right, the article at `1.6:183-240` is now honest, and it teaches a
twenty-line walk that works today. A user who needs cycle detection has it. Building `ModelDefinition`
is a new public subsystem in a library that already has four parallel validation vocabularies
(`TrustPlan.md:68-70`) and an ingestion path the documentation describes and the code lacks
(`IntendedSurface.md` §2.1). Adding a fifth model representation to a library with that much
unreconciled surface is a defensible thing to refuse.

**The counter.** The gap is not "users cannot find cycles". It is that the library has no
representation in which a derivation is data — which is why `accountNames(in:)` has zero
production call sites (`FormulaEvaluator.swift:136`), why `buildDependencyGraph()` describes the
type system rather than a model (`ModelInspector.swift:158-176`), and why E201 has no throw site.
Those are three symptoms of one absence. `ModelDefinition` is that absence, and cycle detection is
the smallest useful thing built on it.

**The genuine risk, named.** If §3.1 is not addressed, this ships a detector and a solver for
cycles that the canonical motivating example cannot express. That would be a subtler version of the
same failure the retraction corrected: not a function that lies, but a *feature set* that is honest
about each part and misleading about the whole. **Do not write the circular-interest tutorial until
the roll-forward exists.** If that constraint is unacceptable, the honest move is to sequence the
prior-period reference *first* and this second.

---

## 11. Size, and order

**Size: medium.** Roughly, in TDD increments:

| piece | size |
|---|---|
| `Cycle`, `DependencyReport`, `CyclePolicy` value types + tests | small |
| Tarjan + in-SCC path recovery over `[String: String]` | small — the algorithm is textbook and the article already prototypes it |
| `Cycle.Form` classification over the parse tree | small-to-medium. `FormulaEvaluator.Node` (`FormulaEvaluator.swift:265`) is already module-internal, so a same-module classifier can walk it without widening any public surface — but the parser that builds it is reachable only through `evaluate(_:)`, so a `parse`-without-resolve entry point is needed. |
| `AccountDefinition` / `ModelDefinition` + evaluation in topological order | medium — this is the public-surface work, and the documentation is most of it |
| diagnostics, DocC article, CHANGELOG | medium |

**Order.** Build detection first. It is a prerequisite in fact and not only in narrative: the
solver needs the SCC decomposition to know what to iterate and in what order, and it needs
`Cycle.Form` to know whether to iterate at all (`IterativeSolver.md` §9). Detection also stands on
its own — an acyclic `ModelDefinition` that evaluates in topological order is a useful thing to
ship even if the solver never follows.

Suggested sequence:

1. `ModelDefinition` + topological evaluation of an **acyclic** definition set. No cycles yet. This
   is the smallest thing that gives `accountNames(in:)` a production caller.
2. Tarjan + path recovery + `DependencyReport`. Detection, reporting only, never throwing.
3. `CyclePolicy` and the first `throw BusinessMathError.circularDependency` in `Sources`.
4. `Cycle.Form`.
5. `IterativeSolver`, which consumes 2 and 4.
6. Prior-period reference — separately, and only then the circular-interest tutorial.
