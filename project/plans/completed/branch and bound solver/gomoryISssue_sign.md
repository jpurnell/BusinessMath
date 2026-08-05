### ✅ Clear Technical Summary of the Current Issue (For an LLM)

We implemented Gomory fractional cuts using a refactored architecture:

- `SimplexRow` explicitly maps tableau columns to original variable indices.
- `generateGomoryCut(from:totalVariableCount:)` builds cuts in **original variable space**.
- `violation(at:)` evaluates cuts consistently in that space.
- All coordinate-system issues are resolved.

However, multiple tests fail because:

> The generated Gomory cuts eliminate valid integer solutions.

---

# 🔴 Observed Failures

Examples:

- Integer point `[0,0,0,0]` → violation = `0.5`
- Integer point `[2,0,0,0]` → violation = `0.5`
- Integer point `[2,2,0,0]` → violation = `0.3333`

In all cases:

```
violation > 0
```

meaning the cut excludes integer-feasible points.

This violates a fundamental property:

> A Gomory fractional cut must eliminate the fractional LP solution  
> but must not eliminate any integer-feasible solution.

---

# 🎯 Root Cause

The issue is a **mathematical sign convention error in the Gomory derivation**.

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

The Gomory derivation must use coefficients from the canonical form:

```
x_B = b − Σ a_j x_j
```

However, the implementation currently computes:

```swift
let frac = fractionalPart(coeff)
```

It should instead compute the fractional part of the canonical coefficient:

```swift
let frac = fractionalPart(-coeff)
```

because the true coefficient of each non-basic variable in canonical form is `-a_j`.

---

# ✅ Why This Breaks Validity

Correct Gomory derivation:

From canonical row:

```
x_B = b − Σ a_j x_j
```

Define:

```
f0 = frac(b)
fj = frac(a_j)
```

Valid Gomory cut:

```
Σ fj x_j ≥ f0
```

Converted to ≤ form:

```
-Σ fj x_j ≤ -f0
```

If the wrong sign is used for `a_j`, the resulting inequality:

- Still cuts off the fractional solution
- But no longer guarantees validity for integer solutions

That is exactly what the failing tests show.

---

# ✅ What Is Correct Now

- ✅ Cuts are expressed in original variable space
- ✅ Variable index mapping is correct
- ✅ Violation evaluation is consistent
- ✅ Architecture is sound

---

# ❌ What Is Incorrect

The Gomory fractional part is computed using the wrong algebraic orientation of tableau coefficients.

The implementation must reflect canonical simplex form:

```
x_B = b − Σ a_j x_j
```

---

# 📌 Core Issue in One Sentence

The Gomory implementation uses the wrong sign convention for tableau coefficients, causing generated cuts to invalidate legitimate integer solutions.

---

# ✅ Conceptual Fix

Inside `generateGomoryCut`, replace:

```swift
let frac = fractionalPart(coeff)
```

with:

```swift
let canonicalCoeff = -coeff
let frac = fractionalPart(canonicalCoeff)
```

This restores consistency with canonical simplex form and reestablishes integer validity.

---

# ✅ Final Diagnosis

The architecture is correct.

The remaining failures are purely due to an incorrect canonical sign assumption in the Gomory cut derivation.
