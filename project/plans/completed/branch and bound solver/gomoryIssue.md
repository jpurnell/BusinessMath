### ✅ Concise Technical Summary of the Issue (For an LLM)

#### Problem Domain
We are implementing **Gomory fractional cuts** inside a cutting‑plane generator for integer programming.

#### Observed Failure
`selectMostViolatedCut(...)` returns `nil` in a convergence test because the generated Gomory cuts are **not violated by the LP solution they were derived from**.

---

# 🎯 Root Cause

There is a **coordinate space mismatch**.

### Current Implementation Behavior

`generateGomoryCut(tableauRow:rhs:basicVariableIndex:)`:

- Interprets `tableauRow` as coefficients of **non-basic variables**
- Builds a cut using those coefficients directly
- Returns a `CuttingPlane` whose `coefficients` array corresponds to **non-basic variable space**

However:

- `CuttingPlane.violation(at:)`
- `selectMostViolatedCut`
- The LP `solution` vector

all assume that cuts are expressed in **original variable space**.

These are not the same coordinate systems.

---

# 🔴 Why This Is Architecturally Incorrect

In a simplex tableau:

```
x_B = b + Σ a_j x_j
```

- `x_B` is a basic variable
- `x_j` are non-basic variables
- Non-basic variables are 0 at the basic solution
- Column ordering no longer matches original variable ordering
- Slack/artificial variables may be present

Your implementation:

- Drops all information about which original variable each `a_j` corresponds to
- Returns a cut whose coefficient index implicitly assumes:
  
  ```
  tableauRow index == original variable index
  ```

That assumption is false in general.

---

# 🧠 Consequence

When the test evaluates:

```
cut.violation(at: currentSolution)
```

it is evaluating:

- A non-basic-space cut
- Against an original-variable-space solution

This produces zero or negative violation.

So:

```
selectMostViolatedCut → nil
```

Even though mathematically the Gomory cut is correct.

---

# ✅ What the Architecture Actually Needs

Gomory cuts must be expressed in **original variable space**.

To do that, the generator must know:

1. Which original variables correspond to each non-basic column.
2. The total number of original variables.
3. Which variable is basic.

So the correct API must include a mapping:

```swift
nonBasicVariableIndices: [Int]
totalVariableCount: Int
```

Then construct a full-length coefficient vector:

```swift
var fullCoefficients = Array(repeating: 0.0, count: totalVariableCount)

for (colIndex, originalIndex) in nonBasicVariableIndices.enumerated() {
    fullCoefficients[originalIndex] = -fractionalPart(tableauRow[colIndex])
}
```

Now the cut lives in the same space as the solution vector.

Now violation testing is correct.

---

# 📌 Core Conceptual Bug

**The generator currently confuses tableau-space coordinates with original-variable coordinates.**

It assumes:

```
row index == solution index
```

That only holds in a toy implementation.

In a real solver, this assumption breaks immediately.

---

# ✅ Final Architectural Diagnosis

This is not a math error.

This is a **representation-layer architectural flaw**:

- Missing basis mapping
- Missing column-to-variable index tracking
- Cuts returned in the wrong coordinate system

The correct fix is:

> Express all cuts in original variable space and require explicit non-basic → original index mapping.

---

# ✅ One-Line Summary

The cutting-plane generator currently produces Gomory cuts in non-basic tableau space, but evaluates them in original-variable space, causing violation detection to fail due to a coordinate system mismatch.
