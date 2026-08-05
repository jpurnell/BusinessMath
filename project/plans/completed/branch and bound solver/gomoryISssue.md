### ✅ Precise Technical Summary of the Current Issue (For an LLM)

We refactored the cutting‑plane system to:

- Represent simplex rows using `SimplexRow`
- Generate Gomory cuts in **original variable space**
- Evaluate violations consistently in that space

The architectural coordinate mismatch has been fixed.

However, multiple tests now fail because:

> The generated Gomory cuts eliminate valid integer solutions.

---

# 🔴 Observed Failures

Examples:

- Integer point `[0,0,0,0]` has violation `0.5`
- Integer point `[2,0,0,0]` has violation `0.5`
- Integer point `[2,2,0,0]` has violation `0.3333`

All failures show:

```
violation > 0
```

Meaning the cut excludes integer‑feasible points.

This violates a fundamental property:

> A Gomory fractional cut must eliminate the current fractional basic solution, but must never eliminate integer-feasible solutions.

---

# 🎯 Root Cause

The issue is a **sign convention mismatch in the Gomory derivation**.

The implementation assumes the tableau row is:

```
x_B = b + Σ a_j x_j
```

But canonical simplex rows are:

```
x_B + Σ a_j x_j = b
```

or equivalently:

```
x_B = b − Σ a_j x_j
```

Gomory’s derivation requires using coefficients from the canonical form:

```
x_B = b − Σ a_j x_j
```

However, the implementation currently applies:

```
frac(a_j)
```

when it should apply:

```
frac(-a_j)
```

because the true canonical coefficient of each non-basic variable is `-a_j`.

---

# ✅ Why This Breaks Validity

Gomory cut (correct derivation):

Given canonical row:

```
x_B = b − Σ a_j x_j
```

Let:

```
f0 = frac(b)
fj = frac(a_j)
```

The valid Gomory cut is:

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

That is exactly what the failing tests demonstrate.

---

# ✅ What Is Correct Now

- ✅ Cuts are expressed in original variable space
- ✅ Variable index mapping is correct
- ✅ Violation evaluation is correct
- ✅ Architecture is sound

---

# ❌ What Is Still Incorrect

The Gomory fractional part is being computed using the wrong algebraic orientation of the tableau row.

Specifically:

```swift
let frac = fractionalPart(coeff)
```

must instead reflect the canonical form:

```swift
let frac = fractionalPart(-coeff)
```

---

# 📌 Core Issue in One Sentence

The Gomory implementation uses the wrong sign convention for tableau coefficients, causing generated cuts to invalidate legitimate integer solutions.

---

# ✅ Conceptual Fix

Inside `generateGomoryCut`:

Replace:

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
