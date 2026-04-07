// PSD_Validation.swift
//
// Standalone validation script for the PSD normalization upstream change
// (v2.1.1). Hand-rolls the entire FFT + PSD pipeline with NO BusinessMath
// dependency, then prints the values that the test suite will assert.
//
// Run with: swift Tests/Validation/PSD_Validation.swift
//
// The defining property of a correctly-normalized one-sided PSD is Parseval's
// theorem:  σ²_time = Σ_k PSD[k] · Δf
//
// where Δf = fs / N_padded.
//
// This script verifies the formulas BEFORE any tests or production code touch
// the package, so the test fixtures have an independent ground truth.

import Foundation

// MARK: - Naive radix-2 FFT (Cooley-Tukey, decimation in time)

func nextPowerOf2(_ n: Int) -> Int {
    guard n > 0 else { return 1 }
    var p = 1
    while p < n { p *= 2 }
    return p
}

func bitReverse(_ x: Int, bits: Int) -> Int {
    var r = 0
    var v = x
    for _ in 0..<bits {
        r = (r << 1) | (v & 1)
        v >>= 1
    }
    return r
}

/// In-place radix-2 FFT. `real`/`imag` arrays must have length n, a power of 2.
func fft(_ real: inout [Double], _ imag: inout [Double], _ n: Int) {
    let logN = Int(log2(Double(n)))
    for i in 0..<n {
        let j = bitReverse(i, bits: logN)
        if i < j {
            real.swapAt(i, j)
            imag.swapAt(i, j)
        }
    }
    var size = 2
    while size <= n {
        let half = size / 2
        let angle = -2.0 * .pi / Double(size)
        for start in stride(from: 0, to: n, by: size) {
            for k in 0..<half {
                let theta = angle * Double(k)
                let c = cos(theta)
                let s = sin(theta)
                let evenIdx = start + k
                let oddIdx = start + k + half
                let tReal = c * real[oddIdx] - s * imag[oddIdx]
                let tImag = s * real[oddIdx] + c * imag[oddIdx]
                real[oddIdx] = real[evenIdx] - tReal
                imag[oddIdx] = imag[evenIdx] - tImag
                real[evenIdx] = real[evenIdx] + tReal
                imag[evenIdx] = imag[evenIdx] + tImag
            }
        }
        size *= 2
    }
}

/// Raw power spectrum |X[k]|², matching BusinessMath's existing
/// `powerSpectrum(_:)` semantics (zero-pads to next power of 2, returns
/// N/2+1 bins).
func rawPowerSpectrum(_ signal: [Double]) -> [Double] {
    guard !signal.isEmpty else { return [] }
    let n = nextPowerOf2(signal.count)
    var real = [Double](repeating: 0, count: n)
    var imag = [Double](repeating: 0, count: n)
    for i in 0..<signal.count { real[i] = signal[i] }
    fft(&real, &imag, n)
    let bins = n / 2 + 1
    var power = [Double](repeating: 0, count: bins)
    for k in 0..<bins {
        power[k] = real[k] * real[k] + imag[k] * imag[k]
    }
    return power
}

/// One-sided PSD with the M-vs-N normalization.
/// PSD[k] = 2·|X[k]|² / (M·fs)   for typical bins
/// PSD[0] = |X[0]|² / (M·fs)     (DC, not doubled)
/// PSD[Nyq] = |X[Nyq]|² / (M·fs) (Nyquist, not doubled)
func psd(_ signal: [Double], sampleRate: Double) -> [Double] {
    guard !signal.isEmpty, sampleRate > 0 else { return [] }
    let M = signal.count
    let raw = rawPowerSpectrum(signal)
    guard !raw.isEmpty else { return [] }
    let nyquistBin = raw.count - 1
    let typicalFactor = 2.0 / (Double(M) * sampleRate)
    let edgeFactor = 1.0 / (Double(M) * sampleRate)
    var out = [Double](repeating: 0, count: raw.count)
    out[0] = raw[0] * edgeFactor
    if nyquistBin > 0 {
        out[nyquistBin] = raw[nyquistBin] * edgeFactor
    }
    if nyquistBin > 1 {
        for k in 1..<nyquistBin {
            out[k] = raw[k] * typicalFactor
        }
    }
    return out
}

func variance(_ x: [Double]) -> Double {
    guard !x.isEmpty else { return 0 }
    let mean = x.reduce(0, +) / Double(x.count)
    let sq = x.map { ($0 - mean) * ($0 - mean) }
    return sq.reduce(0, +) / Double(x.count)
}

func parsevalIntegral(psd: [Double], sampleRate: Double) -> Double {
    guard !psd.isEmpty else { return 0 }
    let N = (psd.count - 1) * 2
    guard N > 0 else { return 0 }
    let deltaF = sampleRate / Double(N)
    return psd.reduce(0, +) * deltaF
}

// MARK: - Test fixtures

print("=== PSD Normalization Validation ===")
print()

// MARK: Fixture 1 — Pure sine wave, M = 64 (power of 2, no padding)
do {
    print("--- Fixture 1: Pure sine, M=64, fs=64 Hz, f0=4 Hz, A=1 ---")
    let M = 64
    let fs = 64.0
    let f0 = 4.0
    let A = 1.0
    let x = (0..<M).map { i in A * sin(2.0 * .pi * f0 * Double(i) / fs) }
    let timeVar = variance(x)
    let p = psd(x, sampleRate: fs)
    let integral = parsevalIntegral(psd: p, sampleRate: fs)
    print("Time-domain variance:        \(timeVar)")
    print("Analytic A²/2:                \(A * A / 2)")
    print("PSD integral (should match):  \(integral)")
    print("Relative error:               \(abs(integral - timeVar) / timeVar)")
    print()
}

// MARK: Fixture 2 — Pure sine, M = 100 (NOT power of 2; padded to 128)
do {
    print("--- Fixture 2: Pure sine, M=100 (padded to 128), fs=100 Hz, f0=10 Hz ---")
    let M = 100
    let fs = 100.0
    let f0 = 10.0
    let A = 1.0
    let x = (0..<M).map { i in A * sin(2.0 * .pi * f0 * Double(i) / fs) }
    let timeVar = variance(x)
    let p = psd(x, sampleRate: fs)
    let integral = parsevalIntegral(psd: p, sampleRate: fs)
    print("M (unpadded):                \(M)")
    print("N (padded):                  \(nextPowerOf2(M))")
    print("Time-domain variance:        \(timeVar)")
    print("PSD integral:                \(integral)")
    print("Relative error:              \(abs(integral - timeVar) / timeVar)")
    print("Note: Some leakage expected because f0 doesn't land exactly on a bin")
    print("after zero-padding (true bin freqs at fs/N_padded, not fs/M).")
    print()
}

// MARK: Fixture 3 — Two-tone signal, M = 256
do {
    print("--- Fixture 3: Two tones, M=256, fs=256 Hz, f1=8 Hz A1=2, f2=32 Hz A2=3 ---")
    let M = 256
    let fs = 256.0
    let f1 = 8.0
    let f2 = 32.0
    let A1 = 2.0
    let A2 = 3.0
    let x = (0..<M).map { i in
        let t = Double(i) / fs
        return A1 * sin(2.0 * .pi * f1 * t) + A2 * sin(2.0 * .pi * f2 * t)
    }
    let timeVar = variance(x)
    let analyticVar = A1 * A1 / 2 + A2 * A2 / 2  // independent sines: variances add
    let p = psd(x, sampleRate: fs)
    let integral = parsevalIntegral(psd: p, sampleRate: fs)
    print("Time-domain variance:        \(timeVar)")
    print("Analytic A1²/2 + A2²/2:      \(analyticVar)")
    print("PSD integral:                \(integral)")
    print("Relative error:              \(abs(integral - timeVar) / timeVar)")
    print()
}

// MARK: Fixture 4 — Zero-padding equivalence (with mean removal)
do {
    print("--- Fixture 4: Zero-padding equivalence (mean-removed signals) ---")
    print("Same logical signal at M=64 (no padding) and M=50 (padded to 64)")
    print("Mean is removed first, per the PSD method's contract.")
    let fs = 64.0
    let A = 1.5
    let f0 = 8.0
    func meanRemoved(_ x: [Double]) -> [Double] {
        let m = x.reduce(0, +) / Double(x.count)
        return x.map { $0 - m }
    }
    let xFull = meanRemoved((0..<64).map { i in A * sin(2.0 * .pi * f0 * Double(i) / fs) })
    let xShort = meanRemoved(Array((0..<50).map { i in A * sin(2.0 * .pi * f0 * Double(i) / fs) }))
    let varFull = variance(xFull)
    let varShort = variance(xShort)
    let pFull = psd(xFull, sampleRate: fs)
    let pShort = psd(xShort, sampleRate: fs)
    let intFull = parsevalIntegral(psd: pFull, sampleRate: fs)
    let intShort = parsevalIntegral(psd: pShort, sampleRate: fs)
    print("xFull (M=64):  variance=\(varFull),  PSD integral=\(intFull),  rel.err=\(abs(intFull-varFull)/varFull)")
    print("xShort (M=50): variance=\(varShort), PSD integral=\(intShort), rel.err=\(abs(intShort-varShort)/varShort)")
    print("Both should now satisfy Parseval at machine epsilon — proves M-vs-N normalization is correct.")
    print()
}

// MARK: Fixture 5 — DC signal
do {
    print("--- Fixture 5: DC signal, M=16, fs=16 Hz, value=5 ---")
    let M = 16
    let fs = 16.0
    let x = [Double](repeating: 5.0, count: M)
    let timeVar = variance(x)  // 0
    let p = psd(x, sampleRate: fs)
    print("Time-domain variance: \(timeVar)  (should be 0)")
    print("PSD bin 0 (DC):       \(p[0])")
    print("PSD bin 1:            \(p[1])  (should be 0 within numerical noise)")
    print("PSD Nyquist:          \(p[p.count - 1])")
    print("Sum of non-DC bins:   \(p[1...].reduce(0, +))")
    print("Note: DC bin is non-zero (signal has DC), but variance is zero,")
    print("which is exactly what Parseval expects: variance is the AC content.")
    print()
}

// MARK: Fixture 6 — Nyquist-only signal
do {
    print("--- Fixture 6: Nyquist signal, alternating +1/-1, M=16, fs=16 Hz ---")
    let M = 16
    let fs = 16.0
    let x = (0..<M).map { i in i.isMultiple(of: 2) ? 1.0 : -1.0 }
    let timeVar = variance(x)  // 1.0
    let p = psd(x, sampleRate: fs)
    let integral = parsevalIntegral(psd: p, sampleRate: fs)
    print("Time-domain variance:    \(timeVar)  (should be 1.0)")
    print("PSD Nyquist bin:         \(p[p.count - 1])")
    print("PSD other bins (max):    \(p.dropLast().max() ?? 0)")
    print("PSD integral:            \(integral)  (should match variance)")
    print("Relative error:          \(abs(integral - timeVar) / timeVar)")
    print()
}

print("=== End validation ===")
