# Design Proposal: Data Envelopment Analysis (DEA)

## 1. Objective

**Objective:** Add Data Envelopment Analysis capability to evaluate the relative efficiency of decision-making units (DMUs) across multiple inputs and outputs, built on the existing `SimplexSolver`.

**Use Case:** Evaluating products for purchase (e.g., home appliances) where each product has multiple cost dimensions (inputs) and multiple benefit dimensions (outputs). DEA discovers which products are Pareto-efficient without requiring the user to pre-assign importance weights.

**Master Plan Reference:** Optimization module — extends LP infrastructure with a new operations research technique.

---

## 2. Proposed Architecture

**New Files:**
- `Sources/BusinessMath/Optimization/DEA/DEAModel.swift` — Core model enum (CCR, BCC) and shared types
- `Sources/BusinessMath/Optimization/DEA/DEAResult.swift` — Result types (per-DMU scores, reference sets, targets)
- `Sources/BusinessMath/Optimization/DEA/DEASolver.swift` — Solver that constructs and dispatches LPs to `SimplexSolver`

**New Test Files:**
- `Tests/BusinessMathTests/Optimization Tests/DEA Tests/DEAModelTests.swift` — Input validation
- `Tests/BusinessMathTests/Optimization Tests/DEA Tests/DEASolverTests.swift` — Golden path, edge cases, cross-validation

**Modified Files:** None. This is purely additive — it consumes `SimplexSolver` as-is.

**Module Placement:** `Sources/BusinessMath/Optimization/DEA/` (new subdirectory under existing Optimization module)

---

## 3. API Surface

```swift
// MARK: - Model Configuration

/// Specifies the DEA model type.
public enum DEAModelType: Sendable {
    /// Charnes-Cooper-Rhodes model (constant returns to scale).
    /// Appropriate when DMUs operate at optimal scale.
    case ccr

    /// Banker-Charnes-Cooper model (variable returns to scale).
    /// Appropriate when DMUs may operate at different scales.
    case bcc
}

/// Specifies the orientation of the DEA model.
public enum DEAOrientation: Sendable {
    /// Input-oriented: minimize inputs while maintaining output levels.
    /// "How much can I reduce costs while keeping the same quality?"
    case inputOriented

    /// Output-oriented: maximize outputs while maintaining input levels.
    /// "How much more quality can I get for the same cost?"
    case outputOriented
}

// MARK: - Problem Definition

/// A decision-making unit (DMU) with named inputs and outputs.
public struct DMU: Sendable {
    /// Identifier for this DMU (e.g., product name).
    public let name: String

    /// Input values (resources consumed — lower is better).
    /// Example: price, energy cost, maintenance cost.
    public let inputs: [Double]

    /// Output values (benefits produced — higher is better).
    /// Example: quality rating, warranty years, feature count.
    public let outputs: [Double]

    public init(name: String, inputs: [Double], outputs: [Double])
}

// MARK: - Solver

/// Solves Data Envelopment Analysis problems using the simplex method.
public struct DEASolver: Sendable {

    /// Evaluate the relative efficiency of DMUs.
    ///
    /// Solves one LP per DMU to determine its efficiency score.
    /// Each LP uses the existing `SimplexSolver` for the actual optimization.
    ///
    /// - Parameters:
    ///   - dmus: Array of decision-making units to evaluate.
    ///   - model: CCR (constant returns to scale) or BCC (variable returns to scale).
    ///   - orientation: Input-oriented or output-oriented.
    ///   - inputNames: Optional labels for input dimensions.
    ///   - outputNames: Optional labels for output dimensions.
    /// - Returns: DEA results including efficiency scores and improvement targets.
    /// - Throws: `DEAError` if inputs are invalid or LP fails.
    public func solve(
        dmus: [DMU],
        model: DEAModelType = .ccr,
        orientation: DEAOrientation = .inputOriented,
        inputNames: [String]? = nil,
        outputNames: [String]? = nil
    ) throws -> DEAResult
}

// MARK: - Results

/// Complete DEA analysis results.
public struct DEAResult: Sendable {
    /// Per-DMU efficiency evaluation.
    public let scores: [DMUScore]

    /// The model type used.
    public let model: DEAModelType

    /// The orientation used.
    public let orientation: DEAOrientation

    /// Names of efficient DMUs (score == 1.0).
    public var efficientDMUs: [String]

    /// Names of inefficient DMUs (score < 1.0).
    public var inefficientDMUs: [String]

    /// Total simplex iterations across all LPs.
    public let totalIterations: Int
}

/// Efficiency score and improvement targets for a single DMU.
public struct DMUScore: Sendable {
    /// Name of the DMU.
    public let name: String

    /// Normalized efficiency score ∈ (0, 1].
    /// 1.0 = efficient (on the frontier), < 1.0 = inefficient.
    ///
    /// This is always normalized to the (0, 1] range regardless of orientation:
    /// - Input-oriented: θ* directly from LP (already in (0, 1])
    /// - Output-oriented: 1/η* where η* is the raw LP result (η* ≥ 1)
    ///
    /// The raw (un-normalized) LP value is available via ``rawScore``.
    public let efficiency: Double

    /// Raw LP objective value before normalization.
    /// - Input-oriented: same as ``efficiency`` (θ* ∈ (0, 1])
    /// - Output-oriented: η* ∈ [1, ∞) where η* is the output expansion factor
    public let rawScore: Double

    /// Whether this DMU is on the efficient frontier.
    public var isEfficient: Bool { abs(efficiency - 1.0) < 1e-6 }

    /// Reference set: the efficient DMUs that define the comparison
    /// point, with their lambda weights.
    public let referenceSet: [ReferenceUnit]

    /// Target input values to become efficient (input-oriented).
    public let targetInputs: [Double]?

    /// Target output values to become efficient (output-oriented).
    public let targetOutputs: [Double]?

    /// Input slack values (excess input reduction possible beyond radial).
    public let inputSlacks: [Double]?

    /// Output slack values (additional output expansion possible beyond radial).
    public let outputSlacks: [Double]?
}

/// A reference unit in the efficient frontier used to benchmark an inefficient DMU.
public struct ReferenceUnit: Sendable {
    /// Name of the efficient DMU.
    public let name: String

    /// Lambda weight — contribution of this efficient DMU to the virtual target.
    public let weight: Double
}

// MARK: - Errors

/// Errors specific to DEA analysis.
public enum DEAError: Error, Sendable {
    /// Fewer than 2 DMUs provided.
    case insufficientDMUs(count: Int)

    /// A DMU has zero or negative input/output values.
    case nonPositiveValues(dmu: String, dimension: String)

    /// DMUs have inconsistent input or output dimensions.
    case dimensionMismatch(expected: Int, actual: Int, dmu: String)

    /// No inputs or no outputs specified.
    case emptyDimension(description: String)

    /// The underlying LP solver failed for a specific DMU.
    case solverFailed(dmu: String, status: SimplexStatus)
}
```

---

## 4. MCP Schema

**Tool Name:** `dea_analysis`

**Tool Description:** Evaluate the relative efficiency of decision-making units (products, departments, branches) across multiple input and output dimensions using Data Envelopment Analysis.

**REQUIRED STRUCTURE (JSON):**
```json
{
  "dmus": [
    {
      "name": "Dishwasher A",
      "inputs": [800, 35],
      "outputs": [8.5, 3]
    },
    {
      "name": "Dishwasher B",
      "inputs": [550, 45],
      "outputs": [7.0, 2]
    },
    {
      "name": "Dishwasher C",
      "inputs": [1200, 25],
      "outputs": [9.2, 5]
    }
  ],
  "model": "ccr",
  "orientation": "input_oriented",
  "input_names": ["Price ($)", "Energy ($/yr)"],
  "output_names": ["Quality Score", "Warranty (yrs)"]
}
```

**Parameter Types:**
- dmus (array of objects): Decision-making units to evaluate. Each must have:
  - name (string): Identifier for the DMU
  - inputs (array of numbers): Input values (resources consumed). All must be > 0.
  - outputs (array of numbers): Output values (benefits produced). All must be > 0.
- model (string): `"ccr"` (constant returns to scale) or `"bcc"` (variable returns to scale). Default: `"ccr"`.
- orientation (string): `"input_oriented"` or `"output_oriented"`. Default: `"input_oriented"`.
- input_names (array of strings, optional): Labels for input dimensions.
- output_names (array of strings, optional): Labels for output dimensions.

---

## 5. Constraints & Compliance

**Concurrency:** All types are `Sendable` — `DEASolver`, `DMU`, `DEAResult`, `DMUScore`, `ReferenceUnit` are all immutable value types.

**Generics:** Not used here. DEA operates on `Double` matrices (matches `SimplexSolver` which is `Double`-only). This is appropriate because DEA is an applied OR technique, not a pure numerical primitive.

**Safety:**
- No force unwraps — all array access guarded
- Division safety — denominators checked before normalization
- Input validation — all DMU values must be strictly positive (DEA mathematical requirement)
- Dimension consistency checks before constructing LPs
- LP solver failures are caught and wrapped in `DEAError.solverFailed`

**Fail-Silent Compliance:** If the LP solver returns a non-optimal status for a DMU, we throw `DEAError.solverFailed` rather than returning a plausible-but-wrong efficiency score.

**Generic Expression Complexity:** N/A — no generic arithmetic (pure `Double` operations).

---

## 6. Backend Abstraction

Not required for v1. DEA solves n LPs each with n+1 variables, giving O(n²) practical complexity. This is fast for hundreds of DMUs but becomes meaningful at thousands. The architecture is designed so each LP is independent — a natural fit for concurrent dispatch. See Appendix D for the async parallel fast-follow that addresses the 1,000+ DMU case using the existing `AsyncSimplexSolver` and `TaskGroup`.

---

## 7. Dependencies

**Internal Dependencies:**
- `SimplexSolver` — for solving the per-DMU linear programs
- `SimplexConstraint`, `ConstraintRelation` — for constructing LP constraints
- `SimplexResult`, `SimplexStatus` — for reading LP results

**External Dependencies:** None (uses swift-numerics only transitively via SimplexSolver)

---

## 8. Test Strategy

**Test Categories:**

### Golden Path
- 3-DMU problem with known efficient/inefficient units (hand-calculated)
- Verify efficiency scores match within tolerance
- Verify reference sets for inefficient DMUs

### Edge Cases
- All DMUs identical → all efficient (score = 1.0)
- 2 DMUs (minimum valid) → one dominates or both efficient
- DMU with extreme values (very large/small but positive)
- Single input, single output (reduces to ratio comparison)

### Invalid Input
- Empty DMU array → throws `insufficientDMUs(count: 0)`
- Single DMU → throws `insufficientDMUs(count: 1)` (DEA is relative; one DMU is degenerate)
- Non-positive input/output values
- Mismatched input/output dimensions across DMUs
- Zero inputs or zero outputs

### Property-Based
- All efficiency scores in (0, 1] for both orientations (output-oriented is normalized via 1/η)
- For output-oriented: rawScore ≥ 1.0 and efficiency == 1.0/rawScore
- Efficient DMUs have themselves in their reference set
- Target inputs ≤ actual inputs (input-oriented)
- Target outputs ≥ actual outputs (output-oriented)
- BCC scores ≥ CCR scores (variable returns to scale is less restrictive)

### Cross-Validation (Tier 2: External Reference)

**Reference Source:** Cooper, Seiford & Tone, *Data Envelopment Analysis* (2nd ed., Springer 2007), Table 1.3 — the canonical textbook example.

**Validation Trace — CCR Input-Oriented (Cooper et al. Table 1.3):**

| DMU | Input 1 | Input 2 | Output 1 | Output 2 | Expected θ* |
|-----|---------|---------|----------|----------|-------------|
| A   | 2       | 5       | 1        | 4        | 1.000       |
| B   | 3       | 3       | 2        | 2        | 1.000       |
| C   | 6       | 2       | 3        | 1        | 1.000       |
| D   | 5       | 5       | 1        | 3        | 0.632       |
| E   | 2       | 4       | 2        | 1        | 1.000       |
| F   | 4       | 6       | 1        | 5        | 0.893       |

These will serve as the primary assertion targets with tolerance < 0.01.

**Supplementary Validation — Textbook 1-input/1-output:**

For a single-input, single-output CCR model, efficiency = (output/input) / max(output/input). This is a closed-form analytical cross-check:

| DMU | Input | Output | Ratio  | Expected θ* |
|-----|-------|--------|--------|-------------|
| P1  | 2     | 1      | 0.500  | 0.625       |
| P2  | 3     | 2      | 0.667  | 0.833       |
| P3  | 5     | 4      | 0.800  | 1.000       |
| P4  | 4     | 3      | 0.750  | 0.938       |

### Numerical Stability
- Very small input/output values (1e-8) — still positive, should solve
- Large spread between values (inputs in thousands, outputs in fractions)

### Stress Test
- 100 DMUs, 5 inputs, 5 outputs — verify completes within time limit
- 500 DMUs — verify O(n²) scaling is practical (n LPs each with n+1 variables)

---

## 9. Architecture Decision Review

**ADR Check:**
- [x] Reviewed `architecture_decisions.md` for related decisions
- [x] Does this supersede an existing ADR? No
- [x] Does this amend an existing ADR? No
- [x] New ADR required? No — this is a straightforward addition to the Optimization module using existing LP infrastructure. No new architectural patterns introduced.

---

## 10. Open Questions (Resolved)

All three deferred items are approved as fast-follows. Detailed designs are in Appendices A–C below.

1. **Super-efficiency models** — Fast-follow v1.1. See Appendix A.
2. **Additive model** — Fast-follow v1.2. See Appendix B.
3. **Matrix-form convenience API** — Fast-follow v1.3. See Appendix C.

---

## 11. Documentation Strategy

**Documentation Type:** Narrative Article Required

**Complexity Threshold Check:**
- Does it combine 3+ APIs? Yes (DMU, DEASolver, DEAResult, DMUScore)
- Does explanation require 50+ lines? Yes
- Does it need theory/background context? Yes (CCR vs BCC, input vs output orientation, interpreting efficiency scores and reference sets)

**Article Name:** `DEAAnalysisGuide.md`
(Does NOT match any Swift symbol name)

**Article Topics:**
- What is DEA and when to use it
- Setting up a product comparison (home appliance example)
- Interpreting efficiency scores
- Understanding reference sets and improvement targets
- CCR vs BCC: choosing the right model
- Worked example with the MCP tool
- **Limitations and Interpretation Caveats** (mandatory section):
  - Dimensionality rule of thumb: n ≥ 2(m+s) — too few DMUs inflates efficiency counts
  - Most-favorable weighting: "efficient" means "not dominated under *any* weighting" — the weighting DEA finds may be unrealistic (e.g., 99% warranty, 1% quality)
  - Dimension sensitivity: adding/removing a single input or output can flip results
  - DEA measures *relative* efficiency — all DMUs can be "efficient" if none dominates another, even if all are objectively poor
  - **Scale sensitivity across dimensions:** DEA is unit-invariant *within* a dimension (doubling all prices doesn't change results) but *not across* dimensions. Inputs and outputs should be measured in meaningful, comparable units. Mixing raw dollars with percentages or counts can distort the analysis. Consider normalizing dimensions to comparable ranges when units differ dramatically (e.g., price in thousands vs. energy in single-digit kWh). Note: the SBM model (Appendix B) is fully units-invariant and avoids this issue entirely.
  - When to prefer simpler alternatives (weighted scoring, Pareto filtering) vs. when DEA adds real value

---

## Mathematical Formulation Reference

### CCR Input-Oriented (Primal / Envelopment Form)

For DMU₀ being evaluated:

```
minimize  θ
subject to:
  Σⱼ λⱼ · xᵢⱼ ≤ θ · xᵢ₀     for each input i
  Σⱼ λⱼ · yᵣⱼ ≥ yᵣ₀          for each output r
  λⱼ ≥ 0                       for all j
```

Where:
- θ = efficiency score (θ* = 1 means efficient)
- λⱼ = weight for DMU j in the reference set
- xᵢⱼ = input i of DMU j
- yᵣⱼ = output r of DMU j

### BCC Extension

Add the convexity constraint to CCR:
```
  Σⱼ λⱼ = 1
```

This constrains the reference point to lie on the convex hull (variable returns to scale) rather than the cone (constant returns to scale).

### CCR Output-Oriented (Envelopment Form)

```
maximize  η
subject to:
  Σⱼ λⱼ · xᵢⱼ ≤ xᵢ₀          for each input i
  Σⱼ λⱼ · yᵣⱼ ≥ η · yᵣ₀      for each output r
  λⱼ ≥ 0                       for all j
```

Where η* ≥ 1 is the raw output expansion factor. The solver normalizes to `efficiency = 1/η*` so all models return scores in (0, 1]. The raw η* is preserved in `DMUScore.rawScore` for users who want the expansion factor directly.

### Implementation Note

The LP variables are `[θ (or η), λ₁, λ₂, ..., λₙ]` — one scalar efficiency variable plus one lambda per DMU. The `SimplexSolver` requires all variables ≥ 0, which is satisfied: lambdas are non-negative by definition, and θ is naturally non-negative for valid problems. For output-oriented, η ≥ 1 is guaranteed for feasible problems.

---
---

# Fast-Follow Appendices

These are detailed designs for features to implement immediately after the v1 DEA foundation is in place. Each builds directly on the v1 types and solver infrastructure.

---

## Appendix A: Super-Efficiency Model (v1.1)

### Motivation

In standard DEA, all efficient DMUs score exactly 1.0 — there's no way to rank them relative to each other. The **Andersen-Petersen super-efficiency** model (1993) removes this limitation by excluding the DMU under evaluation from its own reference set. An efficient DMU can then score > 1.0, indicating *how much* its inputs could be inflated (or outputs deflated) and still remain efficient.

**Use case:** You've narrowed your dishwashers to 3 efficient options. Super-efficiency tells you which is *most* efficient — e.g., Dishwasher C scores 1.4 (could increase inputs by 40% and still be frontier), while A scores 1.1 (only 10% margin).

### Mathematical Formulation

Identical to standard CCR/BCC, but with one change: the constraint `λ_k ≥ 0` for the DMU k being evaluated is **removed** (equivalently, λ_k is fixed at 0). The DMU must be projected onto a frontier defined by all *other* DMUs.

**CCR Super-Efficiency (Input-Oriented):**
```
minimize  θ
subject to:
  Σⱼ₌₁,j≠k λⱼ · xᵢⱼ ≤ θ · xᵢₖ     for each input i
  Σⱼ₌₁,j≠k λⱼ · yᵣⱼ ≥ yᵣₖ          for each output r
  λⱼ ≥ 0                              for all j ≠ k
```

### API Surface

```swift
/// Extended model types including super-efficiency.
public enum DEAModelType: Sendable {
    case ccr
    case bcc
    /// Andersen-Petersen super-efficiency (allows scores > 1.0 for efficient DMUs).
    case superEfficiency(base: DEABaseModel)
}

/// Base model for super-efficiency variant selection.
public enum DEABaseModel: Sendable {
    case ccr
    case bcc
}
```

The `DEASolver.solve()` method handles `.superEfficiency` by constructing LPs that exclude the evaluated DMU's lambda variable. No new result types needed — `DMUScore.efficiency` simply allows values > 1.0, and `DMUScore.isEfficient` remains true when efficiency ≥ 1.0.

### Implementation Notes

- The LP has n-1 lambda variables instead of n (one fewer column per LP)
- For inefficient DMUs, super-efficiency scores equal standard scores (they're already projected onto others' frontier)
- **Infeasibility edge case:** In BCC super-efficiency, excluding a DMU from its own reference set can make the LP infeasible (if the DMU is at a vertex of the convex hull with no nearby peers). This must return a special status, not throw:

```swift
public struct DMUScore: Sendable {
    // ... existing fields ...

    /// Whether the super-efficiency LP was infeasible for this DMU.
    /// Only possible with BCC super-efficiency at extreme frontier vertices.
    public let superEfficiencyInfeasible: Bool
}
```

### Test Strategy

**Golden Path:** Run the Cooper et al. Table 1.3 dataset through super-efficiency:
- DMUs A, B, C, E (efficient in standard CCR) should score ≥ 1.0
- DMUs D, F (inefficient) should score identically to standard CCR

**Property-Based:**
- Super-efficiency score ≥ standard efficiency score for all DMUs
- Inefficient DMUs: super-efficiency == standard efficiency (exactly)
- For efficient DMUs: super-efficiency ≥ 1.0

**Cross-Validation:** Andersen & Petersen (1993) Table 1 provides reference super-efficiency scores.

**Edge Case:** BCC super-efficiency with a DMU at an extreme vertex — verify infeasibility is reported, not thrown.

### Files Modified

- `Sources/BusinessMath/Optimization/DEA/DEAModel.swift` — extend `DEAModelType` enum
- `Sources/BusinessMath/Optimization/DEA/DEASolver.swift` — add LP construction variant that excludes self-lambda
- `Sources/BusinessMath/Optimization/DEA/DEAResult.swift` — add `superEfficiencyInfeasible` field
- `Tests/BusinessMathTests/Optimization Tests/DEA Tests/DEASuperEfficiencyTests.swift` — new test file

---

## Appendix B: Additive Model (v1.2)

### Motivation

The standard radial models (CCR/BCC) measure efficiency by proportionally scaling all inputs (or outputs) by the same factor θ. This misses **dimension-specific slack** — a DMU might be efficient radially but still waste resources in one specific input.

The **additive model** (Charnes, Cooper, Golany, Seiford & Stutz, 1985) directly maximizes the sum of all input and output slacks. It is **units-invariant** (unlike the basic additive) when using the **SBM (Slacks-Based Measure)** variant (Tone, 2001), which normalizes slacks by the DMU's own values.

**Key advantage:** No orientation choice required. The additive model simultaneously improves inputs and outputs.

**Use case:** You want to know *specifically* where each product falls short — "this dishwasher's price is fine but its energy cost is 30% too high and its warranty is 1 year too short."

### Mathematical Formulation

**SBM (Slacks-Based Measure) — Tone (2001):**

```
minimize  ρ = (1 - (1/m) Σᵢ sᵢ⁻/xᵢₖ) / (1 + (1/s) Σᵣ sᵣ⁺/yᵣₖ)

subject to:
  Σⱼ λⱼ · xᵢⱼ + sᵢ⁻ = xᵢₖ      for each input i
  Σⱼ λⱼ · yᵣⱼ - sᵣ⁺ = yᵣₖ      for each output r
  λⱼ ≥ 0, sᵢ⁻ ≥ 0, sᵣ⁺ ≥ 0
```

This is a fractional program, but can be linearized via the **Charnes-Cooper transformation** into an LP:

Let `t = 1 / (1 + (1/s) Σᵣ Sᵣ⁺/yᵣₖ)`, substitute `Λⱼ = t·λⱼ`, `Sᵢ⁻ = t·sᵢ⁻`, `Sᵣ⁺ = t·sᵣ⁺`:

```
minimize  t - (1/m) Σᵢ Sᵢ⁻/xᵢₖ

subject to:
  t + (1/s) Σᵣ Sᵣ⁺/yᵣₖ = 1
  Σⱼ Λⱼ · xᵢⱼ + Sᵢ⁻ = t · xᵢₖ     for each input i
  Σⱼ Λⱼ · yᵣⱼ - Sᵣ⁺ = t · yᵣₖ     for each output r
  Λⱼ ≥ 0, Sᵢ⁻ ≥ 0, Sᵣ⁺ ≥ 0, t > 0
```

This is a standard LP solvable by `SimplexSolver`.

### API Surface

```swift
public enum DEAModelType: Sendable {
    case ccr
    case bcc
    case superEfficiency(base: DEABaseModel)

    /// Slacks-Based Measure (Tone 2001). No orientation required.
    /// Simultaneously optimizes all input reductions and output expansions.
    /// Efficiency ρ ∈ (0, 1], where 1.0 is efficient.
    case sbm(returnsToScale: DEAReturnsToScale)
}

/// Returns to scale assumption (used by SBM and future models).
public enum DEAReturnsToScale: Sendable {
    case constant   // CRS — equivalent to CCR's assumption
    case variable   // VRS — equivalent to BCC's assumption
}
```

When `model` is `.sbm`, the `orientation` parameter is ignored (the solver logs a note if one was specified). The result's `inputSlacks` and `outputSlacks` are always populated and represent the *specific* improvements per dimension, not just radial scaling.

### Implementation Notes

- The Charnes-Cooper linearization adds one extra variable `t` and one extra equality constraint to each LP
- LP variable order: `[t, Λ₁, ..., Λₙ, S₁⁻, ..., Sₘ⁻, S₁⁺, ..., Sₛ⁺]`
- After solving, recover original slacks: `sᵢ⁻ = Sᵢ⁻/t`, `sᵣ⁺ = Sᵣ⁺/t`, `λⱼ = Λⱼ/t`
- Division safety: `t` is guaranteed > 0 for feasible problems, but guard anyway
- BCC variant: add `Σⱼ Λⱼ = t` (convexity constraint scaled by `t`)

### Test Strategy

**Golden Path:** Same Cooper et al. dataset — verify SBM identifies the same efficient frontier as CCR but with different scores for inefficient DMUs.

**Property-Based:**
- SBM efficiency ∈ (0, 1]
- SBM-efficient iff CCR-efficient (for CRS case)
- All slacks ≥ 0
- Efficient DMU iff all slacks = 0

**Cross-Validation:** Tone (2001) Table 1 provides reference SBM scores.

**Edge Case:** DMU with one output very large relative to others — verify Charnes-Cooper transformation remains numerically stable (t doesn't approach zero).

### Files Modified

- `Sources/BusinessMath/Optimization/DEA/DEAModel.swift` — add `.sbm` case and `DEAReturnsToScale`
- `Sources/BusinessMath/Optimization/DEA/DEASolver.swift` — add SBM LP construction with Charnes-Cooper linearization
- `Tests/BusinessMathTests/Optimization Tests/DEA Tests/DEASBMTests.swift` — new test file

---

## Appendix C: Matrix-Form Convenience API (v1.3)

### Motivation

Power users working with data frames, CSV imports, or batch analysis often have their data as raw matrices rather than named structs. Requiring them to construct `DMU` objects adds boilerplate. A matrix-form initializer lets them pass `inputs: [[Double]]` and `outputs: [[Double]]` directly, with optional name arrays.

This also enables the MCP tool to accept a more compact JSON representation for large datasets.

### API Surface

```swift
extension DEASolver {

    /// Evaluate efficiency from raw input/output matrices.
    ///
    /// Convenience method that constructs DMU objects from row-major matrices.
    /// Row i of `inputs` and `outputs` corresponds to DMU i.
    ///
    /// - Parameters:
    ///   - inputs: Matrix of input values, shape [n × m]. Each row is one DMU.
    ///   - outputs: Matrix of output values, shape [n × s]. Each row is one DMU.
    ///   - names: Optional DMU names. If nil, defaults to "DMU_1", "DMU_2", etc.
    ///   - model: DEA model type. Default: `.ccr`.
    ///   - orientation: Input or output oriented. Default: `.inputOriented`.
    ///   - inputNames: Optional labels for input dimensions.
    ///   - outputNames: Optional labels for output dimensions.
    /// - Returns: DEA results.
    /// - Throws: `DEAError` if dimensions are inconsistent or values non-positive.
    public func solve(
        inputs: [[Double]],
        outputs: [[Double]],
        names: [String]? = nil,
        model: DEAModelType = .ccr,
        orientation: DEAOrientation = .inputOriented,
        inputNames: [String]? = nil,
        outputNames: [String]? = nil
    ) throws -> DEAResult
}
```

### Implementation Notes

This is a thin wrapper that:
1. Validates `inputs.count == outputs.count`
2. Validates all rows have consistent column counts
3. Generates default names if none provided (`"DMU_1"`, `"DMU_2"`, ...)
4. Constructs `[DMU]` array
5. Delegates to the primary `solve(dmus:...)` method

No new solver logic required.

### MCP Schema Addition

**Compact matrix form (alternative to named DMU array):**

```json
{
  "inputs": [
    [800, 35],
    [550, 45],
    [1200, 25]
  ],
  "outputs": [
    [8.5, 3],
    [7.0, 2],
    [9.2, 5]
  ],
  "names": ["Dishwasher A", "Dishwasher B", "Dishwasher C"],
  "model": "ccr",
  "orientation": "input_oriented"
}
```

The MCP tool handler accepts either `dmus` (named objects) or `inputs`+`outputs` (matrices), not both. If both are provided, `dmus` takes precedence.

### Test Strategy

**Golden Path:** Same Cooper et al. dataset in matrix form — verify identical results to named-DMU form.

**Edge Cases:**
- `names` array shorter than `inputs` — throw dimension mismatch
- `names` omitted — verify auto-generated names
- `inputs` and `outputs` with different row counts — throw
- Rows with inconsistent column counts — throw

### Files Modified

- `Sources/BusinessMath/Optimization/DEA/DEASolver.swift` — add matrix-form extension method
- `Tests/BusinessMathTests/Optimization Tests/DEA Tests/DEASolverTests.swift` — add matrix-form equivalence tests

---

---

## Appendix D: Async Parallel Dispatch (v1.4)

### Motivation

DEA solves n independent LPs — one per DMU. In v1, these run sequentially via `SimplexSolver`. For typical product comparisons (5–50 DMUs), this is instantaneous. But at scale (1,000+ DMUs, common in benchmarking branch networks, hospital systems, or supply chain nodes), the O(n²) sequential cost becomes noticeable.

Since each LP is fully independent — no shared state, no cross-DMU dependencies — this is an *embarrassingly parallel* workload. Swift's structured concurrency (`TaskGroup`) is a natural fit.

### API Surface

```swift
/// Async DEA solver with concurrent LP dispatch.
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public struct AsyncDEASolver: Sendable {

    /// Maximum concurrent LP solves. Defaults to system processor count.
    public let maxConcurrency: Int

    public init(maxConcurrency: Int? = nil)

    /// Evaluate DMU efficiency with parallel LP dispatch.
    ///
    /// Distributes LP solves across a TaskGroup, bounded by ``maxConcurrency``.
    /// Results are collected and returned in the same order as the input DMUs.
    ///
    /// - Parameters:
    ///   - dmus: Decision-making units to evaluate.
    ///   - model: DEA model type.
    ///   - orientation: Input or output oriented.
    ///   - inputNames: Optional input dimension labels.
    ///   - outputNames: Optional output dimension labels.
    /// - Returns: DEA results (identical to synchronous solver).
    /// - Throws: `DEAError` if inputs are invalid or any LP fails.
    public func solve(
        dmus: [DMU],
        model: DEAModelType = .ccr,
        orientation: DEAOrientation = .inputOriented,
        inputNames: [String]? = nil,
        outputNames: [String]? = nil
    ) async throws -> DEAResult

    /// Solve with progress streaming.
    ///
    /// Yields a progress update each time a DMU's LP completes.
    /// Useful for UI progress bars on large analyses.
    public func solveWithProgress(
        dmus: [DMU],
        model: DEAModelType = .ccr,
        orientation: DEAOrientation = .inputOriented,
        inputNames: [String]? = nil,
        outputNames: [String]? = nil
    ) -> AsyncThrowingStream<DEAProgress, Error>
}

/// Progress update during async DEA solving.
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public struct DEAProgress: Sendable {
    /// Number of DMUs solved so far.
    public let completed: Int

    /// Total number of DMUs.
    public let total: Int

    /// Name of the most recently completed DMU.
    public let lastCompleted: String

    /// Efficiency score of the most recently completed DMU.
    public let lastScore: Double

    /// Fraction complete (0.0 to 1.0).
    public var fractionComplete: Double {
        Double(completed) / Double(total)
    }
}
```

### Implementation Notes

- Uses `withThrowingTaskGroup` to dispatch LP solves concurrently
- Bounded concurrency via a semaphore-like pattern (add tasks up to `maxConcurrency`, `await` one before adding the next) to avoid memory pressure from thousands of simultaneous LPs
- Each task calls the synchronous `SimplexSolver` (not `AsyncSimplexSolver` — we don't need per-LP progress streaming, just inter-LP parallelism)
- Results collected into an array indexed by DMU position to preserve input order
- All types are `Sendable` — `DMU`, `SimplexConstraint`, and `SimplexResult` are already `Sendable`
- `DEAProgress` is yielded via `AsyncThrowingStream` continuation from within the task group
- Cancellation: checks `Task.isCancelled` between LP dispatches

### Concurrency Safety

The design avoids shared mutable state entirely:
- Each task receives its own LP formulation (constructed from immutable `[DMU]` slice)
- Results are collected via the `TaskGroup` return channel, not a shared array
- The `SimplexSolver` is a struct with no mutable state — safe to use from multiple tasks simultaneously

### Test Strategy

**Correctness:** Same Cooper et al. dataset — async results must exactly match synchronous v1 results.

**Concurrency Determinism:** Run with `maxConcurrency` of 1, 2, 4, and 8 — all must produce identical scores (order-independence).

**Cancellation:** Start a 500-DMU solve, cancel mid-flight, verify it throws `CancellationError` and doesn't leak tasks.

**Performance:** 1,000 DMUs with 3 inputs / 3 outputs:
- Async (maxConcurrency = processorCount) should complete in < 50% wall time of sequential
- Use `.timeLimit(.minutes(1))` as safety bound

**Stress:** 5,000 DMUs — verify bounded concurrency prevents memory exhaustion.

### Files

- `Sources/BusinessMath/Optimization/DEA/AsyncDEASolver.swift` — new file
- `Tests/BusinessMathTests/Optimization Tests/DEA Tests/AsyncDEASolverTests.swift` — new test file

---

## Implementation Order

| Phase | Feature | Depends On | Estimated Scope |
|-------|---------|-----------|-----------------|
| **v1.0** | CCR + BCC, input + output oriented | SimplexSolver | 3 new files, ~400 LOC |
| **v1.1** | Super-efficiency (Appendix A) | v1.0 | Modify solver + result, ~100 LOC |
| **v1.2** | SBM additive model (Appendix B) | v1.0 | Modify solver + model enum, ~200 LOC |
| **v1.3** | Matrix-form API (Appendix C) | v1.0 | Add extension, ~50 LOC |
| **v1.4** | Async parallel dispatch (Appendix D) | v1.0 | New async solver, ~250 LOC |

Each fast-follow is independently deployable once v1.0 is in place. No ordering constraints between v1.1–v1.4.
