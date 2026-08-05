# Power Spectral Density (PSD) Normalization — v2.1.1

**Status:** APPROVED — feature branch `feature/psd-normalization` active
**Target release:** v2.1.1 (patch — purely additive, no breaking changes)
**Driver:** Downstream consumer BioFeedbackKit needs physically meaningful
spectral units (ms² for HRV) without every consumer reinventing normalization.

---

## Objective

Add a normalized **power spectral density (PSD)** method to the `FFTBackend`
protocol so consumers get physically meaningful spectral values directly,
without having to know about FFT padding, one-sided/two-sided conventions,
or DC/Nyquist edge cases.

The existing `powerSpectrum(_:)` returns raw `|X[k]|²`. Useful as a primitive,
but every consumer that wants real units (variance/Hz, ms², dB) has to apply
the same normalization steps. That's redundant and error-prone — the
normalization has subtle gotchas that are easy to get wrong.

**The padding gotcha specifically:** `powerSpectrum(_:)` zero-pads to the next
power of 2. For PSD normalization to give physically meaningful units (the
integral over frequency must equal time-domain variance per Parseval's
theorem), the normalization factor needs to use the **unpadded** signal length
`M`, not the padded `N`. This fix lives in BusinessMath where it can be
tested in isolation.

---

## API Surface

### Protocol addition

```swift
public protocol FFTBackend: Sendable {

    /// Raw power spectrum |X[k]|² (existing — unchanged).
    func powerSpectrum(_ signal: [Double]) -> [Double]

    /// One-sided power spectral density in units²/Hz.
    ///
    /// The integral of the returned PSD over frequency equals the
    /// time-domain variance of the input signal (Parseval's theorem).
    ///
    /// **Normalization conventions:**
    /// - One-sided spectrum: bins `1..<N/2` are doubled; DC bin `0` and
    ///   Nyquist bin `N/2` are NOT doubled.
    /// - The normalization uses the **unpadded** signal length `M`, not
    ///   the internally zero-padded length `N`. This ensures the PSD
    ///   integral equals the time-domain variance regardless of padding.
    /// - No window function is applied. Callers that need windowing must
    ///   apply it before calling, and compensate by dividing the result
    ///   by the window's noise-equivalent bandwidth `(1/M) · Σ w[m]²`.
    ///
    /// - Parameters:
    ///   - signal: Real-valued input. Apply mean removal and windowing
    ///     before calling. Internally zero-padded to next power of 2.
    ///   - sampleRate: Sample rate in Hz. Must be positive.
    /// - Returns: PSD bins of length `N/2 + 1` where `N` is the padded
    ///   length. Returns an empty array for empty signal or non-positive
    ///   sample rate.
    func powerSpectralDensity(_ signal: [Double], sampleRate: Double) -> [Double]
}
```

### Default implementation

A single default implementation in an extension, shared by all backends
(`PureSwiftFFTBackend`, `AccelerateFFTBackend`):

```swift
extension FFTBackend {
    public func powerSpectralDensity(
        _ signal: [Double],
        sampleRate: Double
    ) -> [Double] {
        guard signal.isEmpty == false, sampleRate > 0 else { return [] }

        let M = signal.count
        let raw = powerSpectrum(signal)
        guard raw.isEmpty == false else { return [] }

        let nyquistBin = raw.count - 1
        // Typical bins: factor of 2 for one-sided convention
        let typicalFactor = 2.0 / (Double(M) * sampleRate)
        // DC and Nyquist: no factor of 2
        let edgeFactor = 1.0 / (Double(M) * sampleRate)

        var psd = [Double](repeating: 0.0, count: raw.count)
        psd[0] = raw[0] * edgeFactor
        if nyquistBin > 0 {
            psd[nyquistBin] = raw[nyquistBin] * edgeFactor
        }
        if nyquistBin > 1 {
            for k in 1..<nyquistBin {
                psd[k] = raw[k] * typicalFactor
            }
        }
        return psd
    }
}
```

Backends *can* override for performance, but the default is correct and
stable.

### Convenience: PSD bins with frequency labels

Optional convenience method that pairs PSD values with their frequencies,
saving downstream consumers from having to compute `Δf` themselves:

```swift
public struct PSDBin: Sendable, Equatable {
    public let frequency: Double  // Hz
    public let power: Double      // units²/Hz
}

extension FFTBackend {
    public func powerSpectralDensityBins(
        _ signal: [Double],
        sampleRate: Double
    ) -> [PSDBin] {
        let psd = powerSpectralDensity(signal, sampleRate: sampleRate)
        guard psd.isEmpty == false else { return [] }
        let N = (psd.count - 1) * 2
        guard N > 0 else { return [] }
        let deltaF = sampleRate / Double(N)
        return psd.enumerated().map { idx, value in
            PSDBin(frequency: Double(idx) * deltaF, power: value)
        }
    }
}
```

This makes downstream band-integration trivial:

```swift
let bins = backend.powerSpectralDensityBins(signal, sampleRate: 4.0)
let lfPower = bins
    .filter { $0.frequency >= 0.04 && $0.frequency < 0.15 }
    .reduce(0) { $0 + $1.power }
    * (4.0 / Double((bins.count - 1) * 2))  // × Δf
```

---

## Test Strategy: Parseval as ground truth

The defining property of a correctly-normalized one-sided PSD is that its
integral over frequency equals the time-domain variance:

```
σ²(time) = Σ_k PSD[k] · Δf       where Δf = fs / N_padded
```

This is the strongest possible test: pick any signal, compute its variance,
compute its PSD, integrate, assert equality within numerical tolerance.

### Test cases (added to `StreamingFrequencyDomainTests.swift`)

1. **Parseval — pure sine wave** at `f₀=4 Hz, fs=64 Hz, M=64`. Time variance
   = `A²/2`. Verify integral matches within `1e-9` relative.

2. **Parseval — multiple tones.** Sum of two sines with known amplitudes;
   verify total integral equals sum of `Aᵢ²/2`.

3. **Parseval with zero-padding.** Same signal at `M=100` (padded to 128)
   and `M=128` (no padding) — both PSDs' integrals must equal the same time
   variance. **This is the critical test for the M-vs-N normalization fix.**

4. **DC bin not doubled.** Verify DC bin uses edge factor.

5. **Nyquist bin not doubled.** Construct alternating `+1, -1` signal whose
   only frequency content is at Nyquist. Verify Nyquist bin uses edge factor.

6. **Bin spacing correctness.** Output length is `N_padded/2 + 1`.

7. **Empty input → empty output.**

8. **Non-positive sample rate → empty output.**

9. **Backend equivalence.** PureSwift and Accelerate backends produce PSDs
   that agree within `1e-9` relative on the same input.

10. **PSDBin convenience.** Frequencies start at 0, increment by `Δf`, and
    pair correctly with the bare PSD output.

### Validation playground

Standalone hand-rolled implementation at
`Tests/Validation/PSD_Validation.swift`. Generates the test fixtures, runs
both BusinessMath's PSD and a from-scratch reference computation, prints
both for human verification before any tests touch the package.

---

## Constraints & Compliance

- **No breaking changes.** Existing `powerSpectrum(_:)` is unchanged.
- **Default in extension.** All backends inherit for free; no per-backend implementation required.
- **Concurrency:** Pure functions. Sendable by composition.
- **Determinism:** Same input → same output, exactly.
- **Safety:** No force unwraps. Empty/invalid input returns empty array, never crashes.
- **Generics:** Concrete `Double` matches existing `powerSpectrum` signature.

---

## Files Changed

| File | Change |
|------|--------|
| `Sources/BusinessMath/Streaming/FFTBackend.swift` | Add protocol method, default implementation, `PSDBin` type, convenience method |
| `Tests/BusinessMathTests/StreamingTests/StreamingFrequencyDomainTests.swift` | Add PSD test suite |
| `Tests/Validation/PSD_Validation.swift` | New standalone validation playground |
| `CHANGELOG.md` | Add v2.1.1 entry |
| `Package.swift` | (No change — PSD is additive within existing module) |

---

## Open Questions

1. **Two-sided PSD?** Recommendation: not in this PR. Add `powerSpectralDensityTwoSided` later if a real consumer needs it.

2. **Backend-specific overrides?** Recommendation: not in this PR. Default implementation is correct and adds negligible overhead (linear pass over already-computed power spectrum).

3. **Should `PSDBin` go in a separate file?** Recommendation: keep in `FFTBackend.swift` for now since it's a tiny supporting type. Refactor into its own file if it grows.

---

## v2.1.1 Release Notes (CHANGELOG entry to add)

```markdown
## [2.1.1] - 2026-04-06

### Added

- **Power Spectral Density (PSD) on `FFTBackend`** — new
  `powerSpectralDensity(_:sampleRate:)` method returns one-sided PSD in
  units²/Hz, with the integral over frequency equaling the time-domain
  signal variance (Parseval's theorem). Normalization correctly uses the
  unpadded signal length, so PSD values are physically meaningful regardless
  of whether the input length is a power of 2.

- **`PSDBin` value type and `powerSpectralDensityBins(_:sampleRate:)`
  convenience** — pairs each PSD value with its center frequency in Hz,
  saving downstream consumers from computing bin spacing manually.

- **Default implementation in extension** — all `FFTBackend` conformers
  (`PureSwiftFFTBackend`, `AccelerateFFTBackend`) inherit PSD support for
  free.

### Notes

- v2.1.1 is purely additive. The existing `powerSpectrum(_:)` is unchanged.
- Driven by the BioFeedbackKit project, which needs LF/HF HRV bands in ms²
  units without reinventing FFT normalization.
```

---

**Last Updated:** 2026-04-06
