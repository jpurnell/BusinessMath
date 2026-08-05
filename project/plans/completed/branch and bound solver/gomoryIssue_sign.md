### ✅ Technical Summary of the Current Issue (For an LLM)

We refactored the cutting-plane implementation to correctly express Gomory cuts in **original variable space** using an explicit `SimplexRow` mapping. The previous architectural bug (tableau-space vs original-space mismatch) is resolved.

However, tests are failing because:

> The generated Gomory cuts eliminate valid integer solutions.

---

## 🔴 Observed Behavior

For certain integer points (e.g. `[0,0,0,0]`, `[2,0,0,0]`, `[2,2,0,0]`):

```
violation > 0
```

This means the cut excludes integer-feasible points.

That is mathematically invalid.

A correct Gomory fractional cut must:

1. ✅ Eliminate the current fractional LP solution
2. ✅ Be valid for all integer-feasible solutions

The current implementation satisfies (1) but violates (2).

---

## 🎯 Root Cause

The problem is a **sign convention error in the Gomory derivation**.

The implementation assumes the tableau row is:

```
x_B = b + Σ a_j x_j
```

But canonical simplex rows are actually:

```
x_B + Σ a_j x_j = b
```

or equivalently:

```
x_B = b − Σ a_j x_j
```

Gomory cuts must be derived from the canonical form:

```
x_B = b − Σ a_j x_j
```

However, the implementation computes:

```swift
let frac = fractionalPart(coeff)
```

It should instead compute the fractional part of the canonical coefficient:

```swift
let frac = fractionalPart(-coeff)
```

because in canonical form the coefficient of each non-basic variable is `-a_j`.

---

## ✅ Why This Causes Integer Points to Fail

Correct Gomory derivation:

From canonical row:

```
x_B = b − Σ a_j x_j
```

Let:

```
f0 = frac(b)
fj = frac(a_j)
```

The valid cut is:

```
Σ fj x_j ≥ f0
```

Converted to ≤ form:

```
-Σ fj x_j ≤ -f0
```

If the wrong sign is used when computing `fj`, the inequality no longer preserves integer feasibility.

That is exactly what the failing tests show.

---

## ✅ What Is Working Correctly

- ✅ Cuts are generated in original variable space
- ✅ Variable index mapping is correct
- ✅ Violation is computed consistently
- ✅ Fractional solutions are correctly eliminated

---

## ❌ What Is Still Incorrect

The Gomory fractional coefficient is derived using the wrong algebraic orientation of the tableau row.

The implementation must respect canonical simplex form:

```
x_B = b − Σ a_j x_j
```

---

## 📌 Core Issue in One Sentence

The Gomory implementation computes fractional parts from tableau coefficients with the wrong sign convention, causing generated cuts to invalidate legitimate integer solutions.

---

## ✅ Conceptual Fix

Inside `generateGomoryCut`, replace:

```swift
let frac = fractionalPart(coeff)
```

with:

```swift
let canonicalCoeff = -coeff
let frac = fractionalPart(canonicalCoeff)
```

This aligns the cut with canonical simplex form and restores integer validity.

---

## ✅ Final Diagnosis

The system architecture is correct.

The remaining failures are due to an incorrect sign assumption in the Gomory cut derivation.
