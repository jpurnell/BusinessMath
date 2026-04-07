//
//  PowerSpectralDensityTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-06.
//
//  Tests for the v2.1.1 powerSpectralDensity additions to FFTBackend.
//  Reference truth: Parseval's theorem — the integral of a one-sided PSD
//  over frequency must equal the time-domain variance of the (zero-mean)
//  input signal.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Power Spectral Density (v2.1.1)")
struct PowerSpectralDensityTests {

    // MARK: - Helpers

    /// Subtract the mean from a signal so Parseval's theorem holds without
    /// the DC term skewing comparisons.
    static func meanRemoved(_ x: [Double]) -> [Double] {
        let m = x.reduce(0, +) / Double(x.count)
        return x.map { $0 - m }
    }

    /// Sample variance with `n` denominator (matches Σx²/n for zero-mean signals).
    static func populationVariance(_ x: [Double]) -> Double {
        let m = x.reduce(0, +) / Double(x.count)
        let sq = x.map { ($0 - m) * ($0 - m) }
        return sq.reduce(0, +) / Double(x.count)
    }

    /// Integrate a one-sided PSD over frequency: Σ PSD[k] · Δf where Δf = fs/N_padded.
    static func parsevalIntegral(psd: [Double], sampleRate: Double) -> Double {
        guard !psd.isEmpty else { return 0 }
        let N = (psd.count - 1) * 2
        guard N > 0 else { return 0 }
        let deltaF = sampleRate / Double(N)
        return psd.reduce(0, +) * deltaF
    }

    // MARK: - Parseval — pure sine wave (no padding)

    @Test("Parseval: pure sine, M=64 (power of 2, no padding)")
    func parsevalPureSineNoPadding() {
        let backend = PureSwiftFFTBackend()
        let M = 64
        let fs = 64.0
        let f0 = 4.0
        let A = 1.0
        let signal = Self.meanRemoved((0..<M).map { i in
            A * sin(2.0 * .pi * f0 * Double(i) / fs)
        })

        let timeVar = Self.populationVariance(signal)
        let psd = backend.powerSpectralDensity(signal, sampleRate: fs)
        let integral = Self.parsevalIntegral(psd: psd, sampleRate: fs)

        #expect(abs(integral - timeVar) / timeVar < 1e-12)
        // Sanity: also matches the analytic A²/2 for a pure sine
        #expect(abs(timeVar - A * A / 2) < 1e-12)
    }

    // MARK: - Parseval — multiple tones

    @Test("Parseval: two-tone signal, variances add")
    func parsevalTwoTones() {
        let backend = PureSwiftFFTBackend()
        let M = 256
        let fs = 256.0
        let f1 = 8.0
        let f2 = 32.0
        let A1 = 2.0
        let A2 = 3.0
        let signal = Self.meanRemoved((0..<M).map { i in
            let t = Double(i) / fs
            return A1 * sin(2.0 * .pi * f1 * t) + A2 * sin(2.0 * .pi * f2 * t)
        })

        let timeVar = Self.populationVariance(signal)
        let analyticVar = A1 * A1 / 2 + A2 * A2 / 2
        let psd = backend.powerSpectralDensity(signal, sampleRate: fs)
        let integral = Self.parsevalIntegral(psd: psd, sampleRate: fs)

        #expect(abs(timeVar - analyticVar) < 1e-12)
        #expect(abs(integral - timeVar) / timeVar < 1e-12)
    }

    // MARK: - The critical M-vs-N normalization test

    @Test("Parseval with zero-padding: M=50 padded to 64 still satisfies Parseval")
    func parsevalZeroPaddingEquivalence() {
        let backend = PureSwiftFFTBackend()
        let fs = 64.0
        let f0 = 8.0
        let A = 1.5

        // M=50 — NOT a power of 2, will be padded internally to 64
        let signal = Self.meanRemoved((0..<50).map { i in
            A * sin(2.0 * .pi * f0 * Double(i) / fs)
        })

        let timeVar = Self.populationVariance(signal)
        let psd = backend.powerSpectralDensity(signal, sampleRate: fs)
        let integral = Self.parsevalIntegral(psd: psd, sampleRate: fs)

        // This is the test that proves the M-vs-N fix:
        // if normalization used the padded length N=64 instead of M=50,
        // PSD values would be too small by a factor of 50/64 and the
        // integral would be ~22% off, not at machine epsilon.
        #expect(abs(integral - timeVar) / timeVar < 1e-12)
    }

    // MARK: - Output bin count

    @Test("PSD output length matches N_padded/2 + 1")
    func outputLengthMatchesPaddedNyquist() {
        let backend = PureSwiftFFTBackend()
        // M=100 → padded to 128 → 65 bins
        let signal = [Double](repeating: 0.0, count: 100)
        let psd = backend.powerSpectralDensity(signal, sampleRate: 100.0)
        #expect(psd.count == 128 / 2 + 1)
    }

    // MARK: - DC bin (not doubled in one-sided convention)

    @Test("DC bin uses edge factor (not doubled)")
    func dcBinEdgeFactor() {
        let backend = PureSwiftFFTBackend()
        // Pure DC signal — all power should land in bin 0
        let M = 16
        let fs = 16.0
        let signal = [Double](repeating: 5.0, count: M)
        let psd = backend.powerSpectralDensity(signal, sampleRate: fs)

        // Raw |X[0]|² for a constant signal of value c is (c·M)² = c²·M²
        // Edge factor for DC: 1/(M·fs)
        // So PSD[0] should equal c² · M² · 1/(M·fs) = c² · M / fs = 25 · 16 / 16 = 25
        #expect(abs(psd[0] - 25.0) < 1e-12)

        // All non-DC bins should be ~0
        for k in 1..<psd.count {
            #expect(abs(psd[k]) < 1e-12)
        }
    }

    // MARK: - Nyquist bin (also not doubled)

    @Test("Nyquist bin uses edge factor (not doubled)")
    func nyquistBinEdgeFactor() {
        let backend = PureSwiftFFTBackend()
        // Alternating +1, -1 — all energy at exactly the Nyquist frequency
        let M = 16
        let fs = 16.0
        let signal = (0..<M).map { i in i.isMultiple(of: 2) ? 1.0 : -1.0 }
        let timeVar = Self.populationVariance(signal)  // = 1.0

        let psd = backend.powerSpectralDensity(signal, sampleRate: fs)
        let integral = Self.parsevalIntegral(psd: psd, sampleRate: fs)

        // Variance is 1.0 for ±1 alternation
        #expect(abs(timeVar - 1.0) < 1e-12)
        // Parseval must hold
        #expect(abs(integral - timeVar) < 1e-12)
        // The Nyquist bin (last bin) should carry the power, not other bins
        let nyq = psd.last ?? 0
        let otherMax = psd.dropLast().max() ?? 0
        #expect(nyq > otherMax)
    }

    // MARK: - Smoke tests

    @Test("Empty signal returns empty PSD")
    func emptySignalReturnsEmpty() {
        let backend = PureSwiftFFTBackend()
        #expect(backend.powerSpectralDensity([], sampleRate: 100.0).isEmpty)
    }

    @Test("Non-positive sample rate returns empty PSD")
    func nonPositiveSampleRateReturnsEmpty() {
        let backend = PureSwiftFFTBackend()
        let signal = [Double](repeating: 1.0, count: 16)
        #expect(backend.powerSpectralDensity(signal, sampleRate: 0.0).isEmpty)
        #expect(backend.powerSpectralDensity(signal, sampleRate: -1.0).isEmpty)
    }

    // MARK: - Backend equivalence (Darwin only)

    #if canImport(Accelerate)
    @Test("Parseval holds for PureSwiftFFTBackend on a two-tone signal")
    func parsevalPureSwift() {
        let backend = PureSwiftFFTBackend()
        let M = 256
        let fs = 256.0
        let signal = Self.meanRemoved((0..<M).map { i in
            let t = Double(i) / fs
            return 2.0 * sin(2.0 * .pi * 8.0 * t) + 3.0 * sin(2.0 * .pi * 32.0 * t)
        })
        let timeVar = Self.populationVariance(signal)
        let psd = backend.powerSpectralDensity(signal, sampleRate: fs)
        let integral = Self.parsevalIntegral(psd: psd, sampleRate: fs)
        #expect(abs(integral - timeVar) / timeVar < 1e-12)
    }

    /// Cross-backend equivalence: PureSwift and Accelerate must produce
    /// PSDs that agree to within numerical tolerance on the same input.
    ///
    /// This test was the lever that surfaced a pre-existing 4× scaling bug
    /// in `AccelerateFFTBackend.powerSpectrum`: `vDSP_fft_zripD` returns
    /// FFT outputs scaled by 2 vs the textbook DFT formula, and squaring
    /// produced values 4× the correct `|X[k]|²`. The fix (a `× 0.25`
    /// correction in the power computation) is part of v2.1.1 alongside
    /// the new PSD method.
    @Test("Cross-backend equivalence: PureSwift and Accelerate produce identical PSDs")
    func crossBackendEquivalence() {
        let pureSwift = PureSwiftFFTBackend()
        let accelerate = AccelerateFFTBackend()
        let M = 256
        let fs = 256.0
        let signal = Self.meanRemoved((0..<M).map { i in
            let t = Double(i) / fs
            return 2.0 * sin(2.0 * .pi * 8.0 * t) + 3.0 * sin(2.0 * .pi * 32.0 * t)
        })

        let psdSwift = pureSwift.powerSpectralDensity(signal, sampleRate: fs)
        let psdAccel = accelerate.powerSpectralDensity(signal, sampleRate: fs)

        #expect(psdSwift.count == psdAccel.count)
        for (a, b) in zip(psdSwift, psdAccel) {
            let tol = max(1e-9, max(abs(a), abs(b)) * 1e-9)
            let delta = abs(a - b)
            #expect(delta < tol)
        }

        // Both backends must satisfy Parseval, not just agree with each other.
        let varSignal = Self.populationVariance(signal)
        let intSwift = Self.parsevalIntegral(psd: psdSwift, sampleRate: fs)
        let intAccel = Self.parsevalIntegral(psd: psdAccel, sampleRate: fs)
        #expect(abs(intSwift - varSignal) / varSignal < 1e-12)
        #expect(abs(intAccel - varSignal) / varSignal < 1e-12)
    }
    #endif

    // MARK: - PSDBin convenience type

    @Test("PSDBin: frequencies start at 0 and increment by Δf")
    func psdBinFrequencySpacing() {
        let backend = PureSwiftFFTBackend()
        let signal = [Double](repeating: 0.0, count: 64)
        let bins = backend.powerSpectralDensityBins(signal, sampleRate: 64.0)
        let psd = backend.powerSpectralDensity(signal, sampleRate: 64.0)

        #expect(bins.count == psd.count)
        // Δf = fs / N_padded = 64 / 64 = 1.0
        #expect(abs(bins[0].frequency - 0.0) < 1e-12)
        #expect(abs(bins[1].frequency - 1.0) < 1e-12)
        #expect(abs(bins[bins.count - 1].frequency - 32.0) < 1e-12)
        // Power values match the bare PSD output
        for (bin, p) in zip(bins, psd) {
            #expect(bin.power == p)
        }
    }

    @Test("PSDBin: empty input returns empty bins")
    func psdBinEmptyInput() {
        let backend = PureSwiftFFTBackend()
        #expect(backend.powerSpectralDensityBins([], sampleRate: 100.0).isEmpty)
    }
}
