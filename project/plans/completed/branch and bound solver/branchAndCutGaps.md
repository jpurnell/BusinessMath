Here is the **exact restatement** of the previous assessment, **cleaned and formatted for direct inclusion in documentation**, with **no additional commentary**.

---

# Remaining Work for Mathematical Accuracy and Robustness

The following items **remain unimplemented or incomplete**, assuming that all previously discussed Tier‑1 through Tier‑5 cutting‑plane and numerical‑stability gaps have already been fully addressed.

---

## 1. Objective Sense Normalization

The solver still mixes minimization and maximization logic across:
- Relaxation bounds
- Pruning rules
- Gap computation
- Node ordering

### Required
- Enforce a single internal canonical sense (recommended: **always minimize**)
- Negate objectives for maximization internally
- Normalize all bound comparisons
- Convert objective values back at output

---

## 2. Global Dual Bound Invariant

The solver still derives the global bound from queue ordering:
```swift
bestBound = queue.peek().relaxationBound
```

This is not mathematically valid in general.

### Required
- Maintain an explicit global dual bound:
  - Minimization: minimum over all active node bounds
  - Maximization: maximum over all active node bounds
- Update the global bound on:
  - Node insertion
  - Node removal
  - Node pruning
- Never infer the global bound from queue order alone

---

## 3. LP Unboundedness Handling

The solver currently conflates:
- Infeasible LPs
- Unbounded LPs
- Numerical solver failures

### Required
- Explicitly distinguish:
  - Infeasible relaxation → prune node
  - Unbounded relaxation → detect true unboundedness vs integrality restriction
  - Solver failure → controlled termination or fallback
- Propagate correct status through branch‑and‑bound logic

---

## 4. Explicit Bound Tightening in Branching

Branching currently adds constraints but does not maintain explicit variable bounds.

### Required
- Maintain per‑node lower and upper bounds for all variables
- On branching:
  - Intersect new bounds with parent bounds
  - Detect infeasibility early when lower bound exceeds upper bound
- Use bounds for:
  - Early pruning
  - Stronger relaxations

---

## 5. Integer Solution Validation

Integer feasibility checking is incomplete.

### Required
- After detecting an integer solution:
  - Re‑check all original constraints
  - Re‑evaluate the objective in the unshifted model
  - Verify binary bounds explicitly
- Reject or repair numerically invalid integer solutions

---

## 6. Primal Incumbent Heuristics

The solver relies almost exclusively on LP relaxations to discover incumbents.

### Required
- Implement at least one primal heuristic:
  - Rounding with repair
  - Feasibility pump
  - Local neighborhood search
- Use heuristics to obtain early incumbents for stronger pruning

---

## 7. Scalable Priority Queue

NodeQueue currently re‑sorts the entire node list on every insertion.

### Required
- Replace with a proper priority queue or heap
- Support stable tie‑breaking
- Ensure scalability as node count grows

---

## 8. Pseudocost and Strong Branching

Branching strategies beyond “most fractional” are declared but not implemented.

### Required
- Pseudocost branching:
  - Track up/down cost estimates per variable
  - Update costs after branch resolution
- Strong branching:
  - Temporarily evaluate candidate branches
  - Score bound improvements
  - Cache results for reuse

---

## 9. Robust Optimality Gap Definition

Current gap computation:
```text
|primal − dual| / max(|primal|, 1)
```
is insufficient.

### Required
- Use a robust MILP gap definition:
```text
gap = |primal − dual| / max(|primal|, |dual|, ε)
```
- Provide an absolute gap fallback
- Handle near‑zero objectives correctly
- Normalize gap computation for both minimization and maximization

---

## 10. Explicit Mathematical Invariants and Guards

Several solver assumptions remain implicit.

### Required
- Document and enforce runtime guards for:
  - Linearity requirements for cut generation
  - Tableau availability
  - Bound validity
  - Integer hull preservation
- Make solver invariants explicit to ensure correctness and maintainability

---

## Summary Table

| Area | Status |
|----|----|
Objective sense normalization | Not implemented |
Global dual bound invariant | Not implemented |
LP unboundedness handling | Not implemented |
Explicit bound tightening | Not implemented |
Integer solution validation | Not implemented |
Primal heuristics | Not implemented |
Scalable priority queue | Not implemented |
Pseudocost branching | Not implemented |
Strong branching | Not implemented |
Robust gap definition | Not implemented |
Formal invariants and guards | Not implemented |

---

**End of statement.**
