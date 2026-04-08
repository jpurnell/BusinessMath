//
//  StreamingFrequencyDomainTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-05.
//

import Testing
import Foundation
@testable import BusinessMath

/// Tests for FFT / frequency domain streaming operators (Phase 2.5 — Gap 5)
@Suite("Streaming Frequency Domain Tests")
struct StreamingFrequencyDomainTests {

    // MARK: - PureSwiftFFTBackend Tests

    @Test("Pure Swift FFT: known sinusoid produces correct peak frequency")
    func pureSwiftFFTSinusoid() {
        let backend = PureSwiftFFTBackend()
        let n = 256
        let sampleRate = 256.0  // 256 Hz → frequency resolution = 1 Hz
        let signalFreq = 10.0   // 10 Hz sinusoid

        // Generate sinusoid
        var signal = [Double](repeating: 0.0, count: n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            signal[i] = sin(2.0 * .pi * signalFreq * t)
        }

        let spectrum = backend.powerSpectrum(signal)

        // Find peak (skip DC at bin 0)
        guard spectrum.count > 1 else {
            Issue.record("Power spectrum too short")
            return
        }
        let peakBin = (1..<spectrum.count).max(by: { spectrum[$0] < spectrum[$1] }) ?? 1
        let peakFreq = Double(peakBin) * sampleRate / Double(n)

        #expect(abs(peakFreq - signalFreq) < 2.0)  // Within 2 Hz
    }

    @Test("Pure Swift FFT: DC signal has all power at bin 0")
    func pureSwiftFFTDC() {
        let backend = PureSwiftFFTBackend()
        let signal = [Double](repeating: 5.0, count: 64)

        let spectrum = backend.powerSpectrum(signal)

        guard spectrum.count > 1 else {
            Issue.record("Power spectrum too short")
            return
        }

        // DC bin should have the dominant power
        let dcPower = spectrum[0]
        let totalNonDC = spectrum[1...].reduce(0.0, +)
        #expect(dcPower > totalNonDC)
    }

    @Test("Pure Swift FFT: zero-pads non-power-of-2 input")
    func pureSwiftFFTZeroPad() {
        let backend = PureSwiftFFTBackend()
        // 100 samples → should be zero-padded to 128
        let signal = [Double](repeating: 1.0, count: 100)

        let spectrum = backend.powerSpectrum(signal)

        // Should produce a valid spectrum (not crash)
        #expect(spectrum.count > 0)
    }

    @Test("Pure Swift FFT: empty signal returns empty spectrum")
    func pureSwiftFFTEmpty() {
        let backend = PureSwiftFFTBackend()
        let spectrum = backend.powerSpectrum([])
        #expect(spectrum.isEmpty)
    }

    // MARK: - FrequencySpectrum Tests

    @Test("FrequencySpectrum: band power extraction")
    func frequencySpectrumBandPower() {
        // Create a spectrum with known power distribution
        // 16 bins at 1 Hz resolution (sampleRate=32, sampleCount=32)
        var powers = [Double](repeating: 0.0, count: 17)  // N/2 + 1 for N=32
        powers[4] = 10.0   // 4 Hz
        powers[5] = 20.0   // 5 Hz
        powers[6] = 15.0   // 6 Hz
        powers[10] = 5.0   // 10 Hz

        let spectrum = FrequencySpectrum(powers: powers, sampleRate: 32.0, sampleCount: 32)

        // Band 4-7 Hz should capture bins 4, 5, 6
        let bandPower = spectrum.power(in: 4.0..<7.0)
        #expect(abs(bandPower - 45.0) < 1.0)  // 10 + 20 + 15

        // Frequency resolution should be 1 Hz
        #expect(abs(spectrum.frequencyResolution - 1.0) < 1e-10)
    }

    @Test("FrequencySpectrum: out-of-range band returns 0")
    func frequencySpectrumOutOfRange() {
        let spectrum = FrequencySpectrum(powers: [1.0, 2.0, 3.0], sampleRate: 6.0, sampleCount: 4)

        let power = spectrum.power(in: 100.0..<200.0)
        #expect(abs(power) < 1e-10)
    }

    @Test("FrequencySpectrum: LF/HF ratio computation (HRV use case)")
    func lfhfRatio() {
        // Simulate a spectrum with known LF and HF power for HRV analysis
        // sampleRate = 4 Hz, sampleCount = 1024 → resolution ≈ 0.0039 Hz
        let n = 1024
        let sampleRate = 4.0
        let resolution = sampleRate / Double(n)
        let numBins = n / 2 + 1
        var powers = [Double](repeating: 0.01, count: numBins)

        // Add LF power (0.04-0.15 Hz)
        let lfStartBin = Int(0.04 / resolution)
        let lfEndBin = Int(0.15 / resolution)
        for i in lfStartBin...lfEndBin {
            if i < numBins { powers[i] = 1.0 }
        }

        // Add HF power (0.15-0.40 Hz)
        let hfStartBin = Int(0.15 / resolution)
        let hfEndBin = Int(0.40 / resolution)
        for i in hfStartBin...hfEndBin {
            if i < numBins { powers[i] = 0.5 }
        }

        let spectrum = FrequencySpectrum(powers: powers, sampleRate: sampleRate, sampleCount: n)

        let lfPower = spectrum.power(in: 0.04..<0.15)
        let hfPower = spectrum.power(in: 0.15..<0.40)

        #expect(lfPower > 0)
        #expect(hfPower > 0)
        // LF/HF ratio should be approximately 2.0 (1.0/0.5 per bin, similar bin counts)
        guard abs(hfPower) > 1e-10 else {
            Issue.record("HF power too small for ratio")
            return
        }
        let ratio = lfPower / hfPower
        #expect(ratio > 0.5)  // Sanity check
    }

    // MARK: - Streaming FFT Tests

    @Test("Streaming FFT: windowed stream produces correct number of spectra")
    func streamingFFTWindowCount() async throws {
        let ref = ContinuousClock.now

        // Create 2 windows worth of timestamped data
        let window1 = (0..<64).map { i in
            Timestamped(value: sin(2.0 * .pi * 5.0 * Double(i) / 64.0),
                        timestamp: ref.advanced(by: .milliseconds(i * 10)))
        }
        let window2 = (0..<64).map { i in
            Timestamped(value: sin(2.0 * .pi * 10.0 * Double(i) / 64.0),
                        timestamp: ref.advanced(by: .milliseconds(640 + i * 10)))
        }

        let windows: [[Timestamped<Double>]] = [window1, window2]
        let stream = AsyncValueStream(windows)

        var spectra: [FrequencySpectrum] = []
        for try await spectrum in stream.fft() {
            spectra.append(spectrum)
        }

        #expect(spectra.count == 2)
    }

    @Test("Streaming FFT: empty window stream produces no spectra")
    func streamingFFTEmpty() async throws {
        let windows: [[Timestamped<Double>]] = []
        let stream = AsyncValueStream(windows)

        var count = 0
        for try await _ in stream.fft() {
            count += 1
        }

        #expect(count == 0)
    }

    // MARK: - AccelerateFFTBackend Tests (conditional)

    #if canImport(Accelerate)
    @Test("Accelerate FFT: matches Pure Swift bin-for-bin (tightened in v2.1.3)")
    func accelerateMatchesPureSwift() {
        let pureBackend = PureSwiftFFTBackend()
        let accelBackend = AccelerateFFTBackend()
        let n = 256
        let sampleRate = 256.0
        let signalFreq = 10.0

        var signal = [Double](repeating: 0.0, count: n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            signal[i] = sin(2.0 * .pi * signalFreq * t)
        }

        let pureSpectrum = pureBackend.powerSpectrum(signal)
        let accelSpectrum = accelBackend.powerSpectrum(signal)

        // Tightened in v2.1.3: assert ABSOLUTE bin-for-bin equivalence, not
        // just peak location. The previous version only checked peak bin
        // index, which let the v2.1.0 4× scaling bug slip through (the
        // peak was at the right bin, just 4× too large). The PSD work in
        // v2.1.1 fixed AccelerateFFTBackend to apply a ×0.25 scaling
        // correction; this test locks that fix in by requiring exact
        // bin-by-bin agreement at machine precision.
        #expect(pureSpectrum.count == accelSpectrum.count)
        guard pureSpectrum.count == accelSpectrum.count else { return }
        for k in 0..<pureSpectrum.count {
            let p = pureSpectrum[k]
            let a = accelSpectrum[k]
            let tol = max(1e-9, max(abs(p), abs(a)) * 1e-9)
            #expect(abs(p - a) < tol, "bin \(k): pure=\(p), accel=\(a)")
        }
    }
    #endif

    // MARK: - Edge Case Tests

    @Test("FFT with single-sample signal returns empty or trivial spectrum")
    func fftSingleSample() {
        let backend = PureSwiftFFTBackend()
        let spectrum = backend.powerSpectrum([5.0])

        // Single sample zero-pads to 1 (power of 2), producing N/2+1 = 1 bin
        // The result should be non-crashing and finite
        for power in spectrum {
            #expect(power.isFinite)
        }
    }

    @Test("FFT with two-sample signal (minimal valid input)")
    func fftTwoSamples() {
        let backend = PureSwiftFFTBackend()
        let spectrum = backend.powerSpectrum([1.0, -1.0])

        // Two samples -> N=2, should produce N/2+1 = 2 bins
        #expect(spectrum.count == 2)
        for power in spectrum {
            #expect(power.isFinite)
            #expect(power >= 0.0)
        }
    }

    @Test("FrequencySpectrum with negative frequency range returns 0")
    func frequencySpectrumNegativeRange() {
        let spectrum = FrequencySpectrum(powers: [1.0, 2.0, 3.0, 4.0], sampleRate: 8.0, sampleCount: 8)

        // Negative frequencies are outside the spectrum
        let power = spectrum.power(in: -10.0 ..< -1.0)
        #expect(abs(power) < 1e-10)
    }

    @Test("FrequencySpectrum with zero-width range returns 0")
    func frequencySpectrumZeroWidthRange() {
        let spectrum = FrequencySpectrum(powers: [1.0, 2.0, 3.0, 4.0], sampleRate: 8.0, sampleCount: 8)

        let power = spectrum.power(in: 2.0..<2.0)
        #expect(abs(power) < 1e-10)
    }

    // MARK: - Property-Based Tests

    @Test("Power spectrum values are all non-negative")
    func powerSpectrumNonNegative() {
        let backend = PureSwiftFFTBackend()
        let n = 128

        // Generate a mixed signal
        var signal = [Double](repeating: 0.0, count: n)
        for i in 0..<n {
            let t = Double(i) / Double(n)
            signal[i] = sin(2.0 * .pi * 5.0 * t) + 0.5 * cos(2.0 * .pi * 12.0 * t) - 0.3
        }

        let spectrum = backend.powerSpectrum(signal)

        for power in spectrum {
            #expect(power >= 0.0)
        }
    }

    @Test("Parseval's theorem: time-domain energy equals frequency-domain energy (tightened in v2.1.3)")
    func parsevalsTheorem() {
        let backend = PureSwiftFFTBackend()
        let n = 256

        // Generate a known signal
        var signal = [Double](repeating: 0.0, count: n)
        for i in 0..<n {
            let t = Double(i) / Double(n)
            signal[i] = sin(2.0 * .pi * 10.0 * t) + 0.5 * cos(2.0 * .pi * 25.0 * t)
        }

        // Time-domain energy: sum of x[n]^2
        let timeDomainEnergy = signal.reduce(0.0) { $0 + $1 * $1 }

        // Frequency-domain power
        let spectrum = backend.powerSpectrum(signal)

        // For a real signal of length N, Parseval's: sum(|x|^2) = (1/N) * sum(|X|^2)
        // Power spectrum P[k] = |X[k]|^2
        // Account for one-sided spectrum: DC and Nyquist counted once, others doubled
        var freqDomainEnergy = 0.0
        for k in 0..<spectrum.count {
            if k == 0 || k == spectrum.count - 1 {
                freqDomainEnergy += spectrum[k]
            } else {
                freqDomainEnergy += 2.0 * spectrum[k]
            }
        }
        freqDomainEnergy /= Double(n)

        // Tightened in v2.1.3: previously this used `0.5 < ratio < 2.0`,
        // a 2× margin in either direction so loose it would have passed
        // even with major numerical bugs. Parseval's theorem holds at
        // machine precision for this discrete formulation, so the assertion
        // is now `1e-12` relative tolerance.
        let ratio = timeDomainEnergy / freqDomainEnergy
        #expect(abs(ratio - 1.0) < 1e-12, "Parseval ratio off: \(ratio)")
    }

    // MARK: - Numerical Stability Tests

    @Test("FFT with very small amplitude signal (1e-15)")
    func fftVerySmallAmplitude() {
        let backend = PureSwiftFFTBackend()
        let n = 64

        var signal = [Double](repeating: 0.0, count: n)
        for i in 0..<n {
            let t = Double(i) / Double(n)
            signal[i] = 1e-15 * sin(2.0 * .pi * 5.0 * t)
        }

        let spectrum = backend.powerSpectrum(signal)

        #expect(spectrum.count > 0)
        for power in spectrum {
            #expect(power.isFinite)
            #expect(power >= 0.0)
        }
    }

    @Test("FFT with very large amplitude signal (1e10)")
    func fftVeryLargeAmplitude() {
        let backend = PureSwiftFFTBackend()
        let n = 64

        var signal = [Double](repeating: 0.0, count: n)
        for i in 0..<n {
            let t = Double(i) / Double(n)
            signal[i] = 1e10 * sin(2.0 * .pi * 5.0 * t)
        }

        let spectrum = backend.powerSpectrum(signal)

        #expect(spectrum.count > 0)
        for power in spectrum {
            #expect(power.isFinite)
            #expect(power >= 0.0)
        }

        // Peak should still be at bin 5
        guard spectrum.count > 1 else { return }
        let peakBin = (1..<spectrum.count).max(by: { spectrum[$0] < spectrum[$1] }) ?? 1
        #expect(peakBin == 5)
    }

    @Test("FFT with mixed NaN in signal does not crash")
    func fftWithNaN() {
        let backend = PureSwiftFFTBackend()
        var signal = [Double](repeating: 1.0, count: 32)
        signal[10] = Double.nan
        signal[20] = Double.nan

        // Should not crash — result may contain NaN but must not trap
        let spectrum = backend.powerSpectrum(signal)
        #expect(spectrum.count > 0)
    }

    // MARK: - Stress Tests

    @Test("FFT on 4096-sample signal", .timeLimit(.minutes(1)))
    func stressTestLargeFFT() {
        let backend = PureSwiftFFTBackend()
        let n = 4096
        let sampleRate = 4096.0

        var signal = [Double](repeating: 0.0, count: n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            signal[i] = sin(2.0 * .pi * 100.0 * t)
                      + 0.5 * sin(2.0 * .pi * 200.0 * t)
                      + 0.25 * sin(2.0 * .pi * 400.0 * t)
        }

        let spectrum = backend.powerSpectrum(signal)

        #expect(spectrum.count == n / 2 + 1)

        // Verify peak is at 100 Hz (bin 100)
        guard spectrum.count > 1 else { return }
        let peakBin = (1..<spectrum.count).max(by: { spectrum[$0] < spectrum[$1] }) ?? 1
        let peakFreq = Double(peakBin) * sampleRate / Double(n)
        #expect(abs(peakFreq - 100.0) < 2.0)
    }

    @Test("FrequencySpectrum.power(in:) with many band queries on large spectrum", .timeLimit(.minutes(1)))
    func stressTestManyBandQueries() {
        // Create a large spectrum: 2048 bins
        let n = 4096
        let sampleRate = 4096.0
        let numBins = n / 2 + 1
        var powers = [Double](repeating: 0.01, count: numBins)
        // Add some peaks
        for k in stride(from: 10, to: numBins, by: 50) {
            powers[k] = 100.0
        }

        let spectrum = FrequencySpectrum(powers: powers, sampleRate: sampleRate, sampleCount: n)

        // Query 1000 different bands
        var totalPower = 0.0
        for i in 0..<1000 {
            let lo = Double(i) * 2.0
            let hi = lo + 2.0
            totalPower += spectrum.power(in: lo..<hi)
        }

        #expect(totalPower.isFinite)
        #expect(totalPower > 0.0)
    }
}
