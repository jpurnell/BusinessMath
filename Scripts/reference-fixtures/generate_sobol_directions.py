#!/usr/bin/env python3
"""Emit the Joe & Kuo (2008) direction-number table as Swift source.

Unlike generate.py this writes into Sources/, not Tests/ — the table is data the
library needs at runtime, not a test fixture. It is generated rather than typed for
the same reason: 256 primitive polynomials and 4,608 initial direction numbers are
not something a human transcribes correctly, and a single wrong entry produces a
sequence that still looks random.

The values come from SciPy's bundled copy of Joe & Kuo's `new-joe-kuo-6.21201`, which
is the same table scipy.stats.qmc.Sobol uses — so our sequence and SciPy's agree by
construction, and the fixture comparison in SobolSequenceTests proves it.

    .venv/bin/python generate_sobol_directions.py
"""

import os
from pathlib import Path

import numpy as np
import scipy
import scipy.stats

# How many dimensions to vendor. Not a derived quantity — a policy choice about how
# much generated source to carry. Financial models do not approach it; the table
# supports 21,201 and the cap can be raised by editing this line and re-running.
DIMENSIONS = 256

OUT = (Path(__file__).resolve().parents[2]
       / "Sources" / "BusinessMath" / "Simulation" / "Sampling"
       / "SobolDirectionNumbers.swift")


def main() -> int:
    source = os.path.join(os.path.dirname(scipy.stats.__file__),
                          "_sobol_direction_numbers.npz")
    data = np.load(source)
    poly = data["poly"][:DIMENSIONS]
    vinit = data["vinit"][:DIMENSIONS]

    # Reported so a regeneration that changes the table's shape is visible, but not
    # emitted: SobolSequence reads each dimension's degree from its own polynomial.
    max_degree = max(int(p).bit_length() - 1 for p in poly)
    columns = vinit.shape[1]

    def rows(values, per_line):
        out, line = [], []
        for v in values:
            line.append(str(int(v)))
            if len(line) == per_line:
                out.append("\t\t" + ", ".join(line) + ",")
                line = []
        if line:
            out.append("\t\t" + ", ".join(line) + ",")
        return "\n".join(out).rstrip(",")

    flat = [v for row in vinit for v in row]

    OUT.write_text(f'''//
//  SobolDirectionNumbers.swift
//  BusinessMath
//
//  GENERATED FILE — do not edit by hand.
//  Regenerate with Scripts/reference-fixtures/generate_sobol_directions.py
//

/// Joe & Kuo (2008) direction numbers, the table that defines *which* Sobol sequence
/// this is.
///
/// Sobol sequences are not unique. Two implementations agree only if they use the same
/// primitive polynomials and the same initial direction numbers, so a sequence whose
/// table is unstated cannot be reproduced against any other tool — which defeats the
/// purpose of using a low-discrepancy sequence in the first place.
///
/// These are the `new-joe-kuo-6.21201` values, taken from SciPy {scipy.__version__}'s
/// bundled copy of the same table. `scipy.stats.qmc.Sobol` uses them too, so the two
/// libraries produce identical points — asserted in `SobolSequenceTests` rather than
/// assumed.
///
/// Reference: S. Joe and F. Y. Kuo, *Constructing Sobol sequences with better
/// two-dimensional projections*, SIAM J. Sci. Comput. 30 (2008), 2635–2654.
internal enum SobolDirectionNumbers {{

	/// The highest dimension this table covers.
	///
	/// A policy choice about how much generated source to carry, not a limit of the
	/// method: Joe & Kuo publish {len(data["poly"]):,} dimensions. `SobolSequence`
	/// throws above this rather than silently degrading.
	internal static let dimensionCount = {DIMENSIONS}

	/// Initial direction numbers per dimension, {columns} columns wide.
	internal static let columnsPerDimension = {columns}

	/// Primitive polynomials, one per dimension, encoded with the leading and constant
	/// terms present. The degree is `bitWidth - 1`.
	internal static let polynomials: [UInt32] = [
{rows(poly, 12)}
	]

	/// Initial direction numbers, row-major: dimension `d`'s values begin at
	/// `d * columnsPerDimension`.
	internal static let initialDirections: [UInt32] = [
{rows(flat, 18)}
	]
}}
''')
    print(f"{DIMENSIONS} dimensions, max degree {max_degree} → {OUT.relative_to(Path.cwd())}")
    print(f"{OUT.stat().st_size:,} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
