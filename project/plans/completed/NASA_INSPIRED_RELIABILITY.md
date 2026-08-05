# Design Proposal: NASA-Inspired Reliability Improvements

**Date:** 2026-04-14
**Status:** Proposed
**Origin:** Analysis of NASA Artemis II fault-tolerant computer architecture ([CACM article](https://cacm.acm.org/news/how-nasa-built-artemis-iis-fault-tolerant-computer/))

---

## 1. Objective

Apply NASA Artemis II reliability principles to BusinessMath's multi-stage computation pipelines. The guidelines have been updated with new rules (Fail-Silent Principle, Cross-Validation Testing, Fault Injection Testing, Concurrency Determinism, Integration Monte Carlo). This proposal implements those rules in BusinessMath source code and tests.

**Master Plan Reference:** Quality and reliability improvements across all computation pipelines.

---

## 2. Scope

Four workstreams, independently committable:

| Workstream | Type | Files Changed | New Test Files |
|---|---|---|---|
| **A: Fail-Silent Source Fixes** | Source code | 3-5 modified | 0 |
| **B: Cross-Validation Tests** | Tests only | 0 modified | 4 new |
| **C: Fault Injection Tests** | Tests only | 0 modified | 3 new |
| **D: Integration Monte Carlo Tests** | Tests only | 0 modified | 3 new |

---

## 3. Workstream A: Fail-Silent Source Code Fixes

### A.1: MonteCarloSimulation — GPU Fallback Transparency

**File:** `Sources/BusinessMath/Simulation/MonteCarlo/MonteCarloSimulation.swift` (~line 474)

**Problem:** When GPU execution fails, the system silently falls back to CPU. The returned `SimulationResults` gives no indication that a fallback occurred. The caller receives results computed at potentially different precision without knowing.

**Fix:**
- Add `executionNotes: [String]` property to `SimulationResults` (default `[]`)
- When GPU fails and CPU takes over, append the reason to `executionNotes`
- Add computed property `var isDegraded: Bool { !executionNotes.isEmpty }`
- Remove `print()` statements, replace with structured metadata

**API Impact:** Additive only. New property with default value; all existing call sites unchanged.

```swift
// SimulationResults.swift
public struct SimulationResults: Sendable {
    // ... existing properties ...
    public let executionNotes: [String]
    public var isDegraded: Bool { !executionNotes.isEmpty }
}
```

### A.2: MultivariateGradientDescent — Termination Reason

**File:** `Sources/BusinessMath/Optimization/Algorithms/MultivariateGradientDescent.swift` (~line 378)

**Problem:** When the gradient becomes NaN/Inf, the optimizer returns its best-so-far result with `converged: false`. This is ambiguous — the caller cannot distinguish "hit max iterations" from "encountered numerical instability."

**Fix:**
- Add `TerminationReason` enum: `.converged`, `.maxIterations`, `.numericalInstability`, `.userCancelled`
- Add `terminationReason: TerminationReason` to `MultivariateOptimizationResult`
- Retain `converged` as computed property (`terminationReason == .converged`) for backward compatibility

**API Impact:** Additive. Existing code checking `.converged` continues to work.

```swift
public enum TerminationReason: Sendable, Equatable {
    case converged
    case maxIterations
    case numericalInstability(atIteration: Int)
    case userCancelled
}
```

### A.3: MonteCarloExpressionModel — Throw on Compilation Failure

**File:** `Sources/BusinessMath/Simulation/MonteCarlo/Compilation/MonteCarloExpressionModel.swift` (~line 96)

**Problem:** When bytecode compilation fails, the model silently stores empty bytecode `[]`. Downstream evaluation then produces zero or NaN without any error.

**Fix Options (choose during implementation):**
- **Option A (preferred):** Make `init` throwing. Callers already use `try` for simulation setup.
- **Option B:** Add `static func create(...) throws -> MonteCarloExpressionModel` factory, deprecate non-throwing `init`.

### A.4: Verify Correlation Matrix Error Propagation

**File:** `Sources/BusinessMath/Simulation/MonteCarlo/MonteCarloSimulation.swift`

**Verify:** That `CorrelatedNormals` validation errors propagate to the caller. `CorrelatedNormals.init` already validates and throws `CorrelatedNormalsError.invalidCorrelationMatrix`. Confirm `MonteCarloSimulation.run()` does not catch and swallow this error.

---

## 4. Workstream B: Cross-Validation Tests

### B.1: Optimizer Cross-Validation

**New File:** `Tests/BusinessMathTests/Optimization Tests/OptimizerCrossValidationTests.swift`

Run the same optimization problems through `MultivariateGradientDescent` and `MultivariateNewtonRaphson`, compare solutions within tolerance.

**Test cases:**
- Rosenbrock function (known minimum at [1, 1])
- Quadratic bowl (trivial case — both must find exact minimum)
- Sphere function in higher dimensions
- At least one constrained problem via `ConstrainedOptimizer` vs `InequalityOptimizer`

### B.2: Monte Carlo Theory Cross-Validation

**New File:** `Tests/BusinessMathTests/Simulation Tests/MonteCarlo/MonteCarloTheoryCrossValidationTests.swift`

Validate simulation statistics against theoretical distribution properties.

**Test cases:**
- Normal(mu, sigma): simulated mean -> mu, simulated variance -> sigma^2
- Uniform(a, b): simulated variance -> (b-a)^2/12
- Exponential(lambda): simulated mean -> 1/lambda
- Black-Scholes: Monte Carlo option price -> analytical price (within tolerance)

*Note: `SimulationStatisticsTests.swift` has partial coverage — extend, don't duplicate.*

### B.3: Financial Function Reference Validation

**New File:** `Tests/BusinessMathTests/Financial Reference Tests/FinancialReferenceValidationTests.swift`

Validate against published reference values using parameterized tests.

**Test cases:**
- Bond duration: known coupon/yield/maturity -> published Macaulay duration
- NPV: cash flow series -> Excel NPV() reference values
- IRR: cash flow series -> Excel IRR() reference values
- WACC: capital structure -> textbook reference values (Damodaran, Brealey-Myers)

### B.4: Statistics Reference Validation

**New File:** `Tests/BusinessMathTests/Statistics Tests/StatisticsReferenceValidationTests.swift`

Validate against R/scipy reference outputs.

**Test cases:**
- Linear regression coefficients on known datasets (e.g., Anscombe's quartet)
- Correlation on published datasets
- Standard deviation: verify against known population/sample values

---

## 5. Workstream C: Fault Injection Tests

### C.1: Monte Carlo Fault Injection

**New File:** `Tests/BusinessMathTests/Simulation Tests/MonteCarlo/MonteCarloFaultInjectionTests.swift`

**Test cases:**
- Model function that returns NaN after N iterations — verify detection
- Extreme distribution parameters (stdDev = 1e-15, mean = 1e15)
- Correlation matrix that passes basic validation but causes Cholesky decomposition issues
- Zero iterations, negative iterations

### C.2: Optimizer Fault Injection

**New File:** `Tests/BusinessMathTests/Optimization Tests/OptimizerFaultInjectionTests.swift`

**Test cases:**
- Objective function whose gradient becomes NaN at specific points
- Objective function that returns Inf in certain regions
- Extremely ill-conditioned problem (Hessian condition number > 1e12)
- Verify `terminationReason == .numericalInstability` (after Workstream A)

### C.3: Expression Compiler Fault Injection

**New File:** `Tests/BusinessMathTests/Simulation Tests/Compilation/BytecodeFaultInjectionTests.swift`

**Test cases:**
- After A.3 fix: verify compilation failure throws
- Corrupted bytecode array evaluation
- Empty expression string
- Expression with undefined variables

---

## 6. Workstream D: Integration Monte Carlo Tests

### D.1: Full Monte Carlo Pipeline

**New File:** `Tests/BusinessMathTests/Simulation Tests/MonteCarlo/MonteCarloIntegrationMonteCarloTests.swift`

10,000 iterations with seeded RNG:
- Randomize distribution types (Normal, Uniform, Triangular, Exponential)
- Randomize parameters within valid ranges
- Randomize iteration counts (100-10,000)
- Assert: all results finite, variance >= 0, sample count matches request

### D.2: Full Optimization Pipeline

**New File:** `Tests/BusinessMathTests/Optimization Tests/OptimizationIntegrationMonteCarloTests.swift`

1,000 iterations (optimization is slower):
- Randomize starting points within [-10, 10]^n
- Randomize objective functions from curated set (Rosenbrock, Sphere, Rastrigin, Ackley)
- Assert: every run converges OR terminates with valid reason, no NaN in solutions

### D.3: Financial Statement Pipeline

**New File:** `Tests/BusinessMathTests/Financial Statement Tests/FinancialStatementIntegrationMonteCarloTests.swift`

1,000 iterations:
- Randomize revenue, costs, growth rates within realistic ranges
- Build income statement, balance sheet, cash flow statement via ModelBuilder
- Assert: balance sheet balances (assets = liabilities + equity), all ratios finite, no NaN

---

## 7. Dependencies

**Internal:**
- `MultivariateOptimizationResult` struct (modified in A.2)
- `SimulationResults` struct (modified in A.1)
- `MonteCarloExpressionModel` init (modified in A.3)
- All existing optimizer algorithms (tested in B.1, C.2)
- All distribution generators (tested in B.2, D.1)

**External:** None. All tests use existing BusinessMath APIs only.

---

## 8. Test Strategy

This proposal IS the test strategy. All workstreams B, C, and D are pure test additions. Workstream A modifies source code that will be validated by existing tests (no regressions) plus the new tests in B, C, and D.

**Execution order:**
1. Workstream A first (source changes)
2. Workstreams B, C, D in parallel (independent test additions)

**Reference Truth:**
- B.1: Known optimization minima (Rosenbrock: [1,1], Sphere: [0,...,0])
- B.2: Theoretical distribution statistics (textbook formulas)
- B.3: Excel financial functions (FV, PV, NPV, IRR, DURATION)
- B.4: R `lm()`, `cor()`, `sd()` outputs on published datasets

---

## 9. Architecture Decision Review

- [ ] Reviewed `architecture_decisions.md` for related decisions
- [ ] Does this supersede an existing ADR? No
- [ ] Does this amend an existing ADR? No
- [x] New ADR required? Yes

**New ADR Draft:**
- **Title:** Adopt Fail-Silent Principle for Multi-Stage Pipelines
- **Category:** architecture
- **Key decision:** Computation pipelines must annotate degraded results rather than silently returning plausible-but-wrong answers. `SimulationResults` and `MultivariateOptimizationResult` gain metadata fields for execution notes and termination reasons.

---

## 10. Open Questions

1. **MonteCarloExpressionModel init:** Should it become `throws` (Option A) or use a factory method (Option B)? Option A is cleaner but may break callers.
2. **TerminationReason placement:** Should it live in `MultivariateOptimizationResult.swift` or in a shared `Optimization/` types file?
3. **Integration Monte Carlo test duration:** 10K iterations may exceed CI time limits. Should we parameterize iteration count via environment variable?
4. **Scope of `executionNotes`:** Should other pipeline stages (not just GPU fallback) also populate execution notes? E.g., Kahan summation activation, Accelerate fallback.

---

## 11. Documentation Strategy

**Documentation Type:** API Docs Only

Changes are internal (struct properties, enum cases) and test-only. No narrative article required. Updated DocC comments on modified types are sufficient.

---

## Related Documents

- `development-guidelines/rules/coding_rules.md` — Fail-Silent Principle (new section)
- `development-guidelines/rules/test_driven_development.md` — Cross-Validation, Fault Injection, Integration Monte Carlo (new sections)
- `development-guidelines/rules/architecture_decisions.md` — Pending ADR for fail-silent adoption
