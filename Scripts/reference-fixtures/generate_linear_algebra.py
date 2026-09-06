#!/usr/bin/env python3
"""Reference values for the dense linear algebra, from LAPACK via SciPy.

Run once; commit the output. CI never executes this.

    .venv/bin/python generate_linear_algebra.py

## Why this one first

`DenseMatrixCholeskyTests` had 15 tests and no external check, and the Cholesky
factorisation is the foundation the rest of the package stands on: the mixed models solve
through it, and so do the regression and optimisation paths. A defect here would surface
as small wrongness everywhere and be attributed to whatever called it — which is close to
what happened with the REML projection bug, where the fault sat two layers below the
symptom.

It is also the easiest thing in the package to check properly. LAPACK's `potrf` is about
as settled a reference as numerical software has, and unlike a distribution or an
estimator there is no parameterisation to get wrong.

## Conventions, which do differ

SciPy's `cholesky` returns **upper** triangular by default; `lower=True` gives the L such
that `A = L Lᵀ`. BusinessMath returns lower. The factorisation is unique for a positive
definite matrix once the triangle is fixed, so with that settled there is exactly one
right answer and no tolerance argument to have.
"""

import hashlib
import json
import platform
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import scipy
from scipy import linalg

OUTPUT = (Path(__file__).resolve().parents[2]
          / "Tests" / "BusinessMathTests" / "Fixtures" / "linearAlgebra.json")


def spd(n, seed, condition=None):
    """A symmetric positive definite matrix, optionally with a chosen condition number."""
    rng = np.random.default_rng(seed)
    q, _ = np.linalg.qr(rng.normal(size=(n, n)))
    if condition is None:
        eigenvalues = rng.uniform(0.5, 4.0, n)
    else:
        # Log-spaced eigenvalues spanning the requested condition number.
        eigenvalues = np.logspace(0, np.log10(condition), n)
    return q @ np.diag(eigenvalues) @ q.T


CASES = [
    ("identity3", "The identity: L must be the identity too, and any solve is the "
                  "right-hand side unchanged.", np.eye(3), 20260906),
    ("small2x2", "Two by two, hand-checkable: A = [[4,2],[2,3]] gives L = "
                 "[[2,0],[1,sqrt(2)]].", np.array([[4.0, 2.0], [2.0, 3.0]]), 20260906),
    ("diagonal4", "Diagonal: L is the elementwise square root, which catches a "
                  "factorisation that has transposed itself.",
     np.diag([9.0, 4.0, 16.0, 1.0]), 20260906),
    ("wellConditioned5", "Five by five, condition number near one.", spd(5, 1), None),
    ("moderate8", "Eight by eight, condition number 1e3 — where a naive "
                  "factorisation still holds but a sloppy one starts to drift.",
     spd(8, 2, condition=1e3), None),
    ("illConditioned6", "Condition number 1e8. Still positive definite, and still "
                        "factorisable, but the solve loses about eight digits — the "
                        "fixture records what is achievable, not what would be nice.",
     spd(6, 3, condition=1e8), None),
    ("nearSingular4", "Condition number 1e11, close to the edge. Included so the "
                      "tolerance in the test is set by measurement rather than hope.",
     spd(4, 4, condition=1e11), None),
]


def build_case(name, note, A, seed):
    n = A.shape[0]
    rng = np.random.default_rng(seed if seed is not None else 99)
    L = linalg.cholesky(A, lower=True)
    inverse = linalg.inv(A)
    b = rng.normal(size=n)
    x = linalg.solve(A, b, assume_a="pos")

    # A second right-hand side as a matrix, since choleskySolve is overloaded for both.
    B = rng.normal(size=(n, 2))
    X = linalg.solve(A, B, assume_a="pos")

    return {
        "name": name,
        "note": note,
        "A": [[float(v) for v in row] for row in A],
        "L": [[float(v) for v in row] for row in L],
        "inverse": [[float(v) for v in row] for row in inverse],
        "b": [float(v) for v in b],
        "x": [float(v) for v in x],
        "B": [[float(v) for v in row] for row in B],
        "X": [[float(v) for v in row] for row in X],
        "conditionNumber": float(np.linalg.cond(A)),
        "determinant": float(np.linalg.det(A)),
        "logDeterminant": float(np.linalg.slogdet(A)[1]),
    }


def main() -> int:
    cases = [build_case(name, note, A, seed) for name, note, A, seed in CASES]

    payload = {
        "name": "linearAlgebra",
        "reference": f"scipy {scipy.__version__} (LAPACK potrf/potrs/getri)",
        "note": ("Generated once by Scripts/reference-fixtures/generate_linear_algebra.py. "
                 "L is LOWER triangular, matching BusinessMath and scipy's lower=True. "
                 "The Cholesky factor is unique once the triangle is fixed, so these are "
                 "exact answers rather than one implementation's opinion. Condition "
                 "numbers are recorded so a test can scale its tolerance to the problem "
                 "instead of applying one bound to all of them."),
        "cases": cases,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    OUTPUT.write_text(text)

    print(f"{OUTPUT.name}: {len(cases)} matrices")
    for c in cases:
        print(f"  {c['name']:<20} {len(c['A'])}x{len(c['A'])}  "
              f"cond={c['conditionNumber']:.3e}  logdet={c['logDeterminant']:+.6f}")
    print(f"  sha256 {hashlib.sha256(text.encode()).hexdigest()}")
    print(f"  scipy {scipy.__version__} · numpy {np.__version__} · "
          f"python {platform.python_version()}")
    print(f"  generated {datetime.now(timezone.utc).isoformat()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
