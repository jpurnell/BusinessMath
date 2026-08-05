# FEATURE_SPEC_TEMPLATE.md

This template serves as the mandatory specification document for implementing any new feature in the BusinessMath ecosystem. All sections must be completed before development begins, enforcing the project’s strict **Test-Driven Development (TDD)** methodology and architectural principles.

## 1. Feature Definition

| Field | Input |
| :--- | :--- |
| **Feature Name** | (e.g., Return on Invested Capital (ROIC) Calculation) |
| **Priority** | (e.g., P1 - Critical, P3 - Low) |
| **Target Topic** | (e.g., Topic 5: Financial Ratios & Metrics) |
| **Goal/Objective** | (Briefly state the feature's function and intended output.) |

## 2. Architectural Placement

| Field | Input |
| :--- | :--- |
| **Location (File Path)** | (e.g., `Sources/BusinessMath/Financial Statements/FinancialRatios.swift`) |
| **Target API** | (e.g., Extension on `FinancialModel` or standalone `struct`) |
| **Generic Constraints** | (Must include `<T: Real & Sendable>` where applicable [1-3]) |
| **Protocol Conformance** | (Does the new component conform to an existing protocol? If so, list it.) |

## 3. Test-Driven Development (TDD) Requirements

**TDD Rule:** Tests must be written and compiled **first**, defining the expected behavior before any implementation code is added [4-6].

### 3.1 Basic Calculation Test Cases

Define the minimal set of unit tests required to verify the core mathematical correctness.

| Test Case Name | Input Data/State | Expected Output | Rationale (Why Test This?) |
| :--- | :--- | :--- | :--- |
| `testFeature_BasicPositiveCase` | (e.g., Net Income: 100, Assets: 500) | (e.g., 0.20) | (Verifies fundamental formula correctness) |
| `testFeature_TimeSeriesVerification` | (e.g., 5 periods of input data) | (e.g., TimeSeries<T> with 5 correct values) | (Verifies TimeSeries compatibility [7]) |
| `testFeature_ZeroResult` | (e.g., Numerator = 0) | (e.g., 0.0) | (Validates handling of zero inputs) |

### 3.2 Edge Case & Invalid Input Testing

All public APIs must handle invalid inputs either by returning **NaN** or **throwing an explicit error** [8-11].

| Test Case Name | Invalid Input Data | Expected Behavior (NaN / Throw) | Expected Error Type (if throwing) |
| :--- | :--- | :--- | :--- |
| `testFeature_DivisionByZero` | (e.g., Denominator = 0) | **NaN** [9] | (N/A) |
| `testFeature_InvalidDomain` | (e.g., Log of a negative number) | **NaN** [9] | (N/A) |
| `testFeature_ProgrammingError` | (e.g., Missing required input account [9]) | **Throw** | (e.g., `FinancialError.missingRequiredData`) |
| `testFeature_NegativeInput` | (e.g., Negative input that is mathematically valid) | (Correct calculated negative value) | (N/A) |

### 3.3 Stochastic Function Requirements (If applicable)

If the feature uses random number generation (distributions, simulation), **deterministic seeding** is mandatory [5, 12].

| Test Case Name | Seed Value | Expected Mean/Median (with tolerance) | Expected Variance (with tolerance) |
| :--- | :--- | :--- | :--- |
| `testFeature_DeterministicSeeding_01` | (e.g., `seed: 42`) | (e.g., Mean: 5.0 ± 0.01) | (e.g., Var: 1.0 ± 0.005) |
| `testFeature_ToleranceVerification` | (Must use tolerance calculation based on standard error: $\sigma/\sqrt{n}$ [12, 13]) | (Define standard error, sample size, and resulting tolerance) | (N/A) |

## 4. Implementation Constraints & Standards

1.  **Immutability:** The function must not modify input data structures. It must return a **new value** [3, 14].
2.  **Concurrency:** All parameters and return types must be explicitly marked **`Sendable`** [15].
3.  **Performance:** If complexity is non-trivial, document it: **Complexity:** (e.g., O(n) or O(n $\log$ n)) [16].
4.  **Dependencies:** Only import required packages (`Foundation`, `Numerics`, etc.) [15].

## 5. Documentation (DocC) Requirements

All public APIs must include complete DocC documentation [10, 17, 18].

| DocC Element | Requirement | Example |
| :--- | :--- | :--- |
| **Summary** | Single-line overview [19] | `/// Calculates the Return on Invested Capital (ROIC).` |
| **Parameters** | Document all parameters [19] | `- Parameter netIncome: The company's net income.` |
| **Returns** | Document return value [19] | `- Returns: A TimeSeries of the calculated ROIC.` |
| **Throws** | Document errors that can be thrown [19] | `- Throws: FinancialError.missingAccount if required inputs are absent.` |
| **Excel Equivalent** | Mandatory for financial functions [20] | `/// Equivalent of Excel's ROIC function (custom).` |
| **Mathematical Formula** | Include clear mathematical definition [18] | `/// Formula: Net Operating Profit After Tax / Invested Capital` |
| **Usage Example** | At least one runnable Swift code block example [20] | (Code block demonstrating usage) |

---
***AI Code Generator Checklist:***

*   [ ] Created test file mirroring source structure.
*   [ ] Wrote all required test cases *before* implementation.
*   [ ] Implementation uses `<T: Real>` generic constraint.
*   [ ] Invalid inputs return `NaN` or throw a documented error [11].
*   [ ] Completed all DocC requirements, including Formula and Excel Equivalent.
*   [ ] Verified test stability (seeded for stochastic functions).
