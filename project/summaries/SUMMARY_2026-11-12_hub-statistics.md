# Three statistics for the Diagnostics Hub, and the spike rule against the library's detectors

**2026-11-12** · branch `feature/hub-statistics` on `ad2a2ed8` (v3.0.0-alpha.14), commits `d76dde9e`,
`f087dbda`, `8919af60`, `1248a313`; released as 3.0.0-alpha.15 · 9,077 tests / 847 suites

The Diagnostics Hub's owner rule (SwiftDiagnosticsHub `Analysis.md` §3.0): the hub carries no private
copy of a formula; what it needs is added here first, tested and tagged.

---

## What was added

- `wilsonInterval(successes:trials:confidence:)` → `WilsonInterval<T>` (`value`, `lower`, `upper`,
  `confidence`): the Wilson score interval without continuity correction, with exact bounds at 0 and
  n, because a healthy app sits there. Zero trials is `insufficientData`; negative counts, successes
  above trials and a confidence outside (0, 1) are `invalidInput`.
- `medianAbsoluteDeviation(_:scale:)`: raw by default (R's `mad(x, constant = 1)`), or
  `.normalConsistent` with the exact 1/Φ⁻¹(3/4) = 1.482602218505602 (SciPy's `scale = "normal"`;
  R rounds it to 1.4826). Empty input is `insufficientData`; non-finite values are `invalidInput`. A
  MAD of 0 on sparse counts is a real value, not an error.
- `poissonSurvival(k:lambda:)`: P(X ≥ k), summed from whichever side is small, so a tail of 1e-19 is
  exact where `1 − poissonCDF` returns rounding noise. The library's incomplete gamma was not used:
  its series stops at 200 terms.

## How it was checked

R 4.6.2 (base) and SciPy 1.17.1, through `Scripts/reference-fixtures/generate_hub_statistics.{R,py}`.
R and SciPy agree with each other to 4e-16 (Wilson), exactly (MAD) and 1.1e-13 relative (Poisson).
Tolerances are stated in each test file; Poisson's widen to 1e-9 relative at λ = 100,000.

## The detector assessment (nothing in the detectors changed)

300 seeded 90-day histories per scenario, replayed through the hub's Poisson rule and the library's
EWMA, CUSUM and outlier detectors (the harness is outside the repository because it encodes the
hub's rule). The Poisson rule is the quietest on flat and low-count data, catches large and
low-count spikes, and is the only rule both quiet and robust to an earlier spike. It fails on
overdispersed histories (4.6 to 13.5% false alarms a day); a 14-day MAD widening reduces that but does
not remove it. Nothing detects slow ramps well.

Defects seen and not changed: CUSUM does not reset after a signal; EWMA estimates σ from the whole
stream, spikes included; the streaming MAD detector alarms on 28% of days when the MAD is 0, and
`ModifiedZScoreAnomalyDetector` goes silent there.

## Honest notes

- Green steps were verified one function at a time, but all three implementations were in the tree
  before the first commit, because the hook checks the working tree, not the index.
- Commits were first refused by the float-equality rule and by doc-code, which compiles the guide as
  one program; both were fixed in code. One gate run failed with an unexplained test exit under
  load and passed on a clean rerun.
- This summary was written by the coordinating session; the stream's environment could not.

## Next

- The hub depends on 3.0.0-alpha.15 and decides how to treat overdispersion (a longer dispersion
  window, or a negative-binomial tail, which would be another addition here).
