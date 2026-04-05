//
//  StreamingFrequencyDomain.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-05.
//

import Foundation

// MARK: - Frequency Spectrum

/// The frequency-domain representation of a signal, produced by FFT.
///
/// Contains power values at each frequency bin, along with metadata for
/// converting bin indices to physical frequencies. Provides band-power
/// queries for extracting energy in specific frequency ranges.
///
/// ## Usage Example
/// ```swift
/// let spectrum = FrequencySpectrum(powers: fftOutput, sampleRate: 4.0, sampleCount: 1024)
/// let lfPower = spectrum.power(in: 0.04..<0.15)   // LF band
/// let hfPower = spectrum.power(in: 0.15..<0.40)   // HF band
/// let lfhfRatio = lfPower / hfPower
/// ```
///
/// ## Mathematical Background
/// ```
/// Frequency resolution: Δf = sampleRate / sampleCount
/// Frequency at bin k:   f[k] = k × Δf
/// Band power:           P(f₁, f₂) = Σ P[k]  for k where f₁ ≤ f[k] < f₂
/// ```
public struct FrequencySpectrum: Sendable {
    /// Power values at each frequency bin (length N/2 + 1).
    public let powers: [Double]

    /// The sample rate of the original signal in Hz.
    public let sampleRate: Double

    /// The number of samples in the original (or zero-padded) signal.
    public let sampleCount: Int

    /// Frequency resolution in Hz per bin.
    ///
    /// Each bin spans `sampleRate / sampleCount` Hz.
    public var frequencyResolution: Double {
        guard sampleCount > 0 else { return 0.0 }
        return sampleRate / Double(sampleCount)
    }

    /// Creates a frequency spectrum from FFT output.
    ///
    /// - Parameters:
    ///   - powers: Power values at each frequency bin.
    ///   - sampleRate: The sample rate of the original signal in Hz.
    ///   - sampleCount: The number of samples (before or after zero-padding).
    public init(powers: [Double], sampleRate: Double, sampleCount: Int) {
        self.powers = powers
        self.sampleRate = sampleRate
        self.sampleCount = sampleCount
    }

    /// Total power within a frequency band.
    ///
    /// Sums the power of all bins whose center frequency falls within the
    /// specified range `[lowerBound, upperBound)`.
    ///
    /// - Parameter range: The frequency range in Hz (half-open interval).
    /// - Returns: Sum of power values in the band. Returns 0 if the range
    ///   is outside the spectrum or the spectrum is empty.
    ///
    /// ## Usage Example
    /// ```swift
    /// let lfPower = spectrum.power(in: 0.04..<0.15)  // LF band for HRV
    /// let hfPower = spectrum.power(in: 0.15..<0.40)  // HF band for HRV
    /// ```
    public func power(in range: Range<Double>) -> Double {
        let resolution = frequencyResolution
        guard resolution > 0, powers.isEmpty == false else { return 0.0 }

        let startBin = Swift.max(0, Int((range.lowerBound / resolution).rounded(.down)))
        let endBin = Swift.min(powers.count - 1, Int((range.upperBound / resolution).rounded(.up)))

        guard startBin <= endBin, startBin < powers.count else { return 0.0 }

        var total = 0.0
        for k in startBin...endBin {
            let binFreq = Double(k) * resolution
            if binFreq >= range.lowerBound && binFreq < range.upperBound {
                total += powers[k]
            }
        }
        return total
    }
}

// MARK: - Streaming FFT Sequence

/// An async sequence that applies FFT to each window of timestamped values,
/// yielding frequency spectra.
///
/// Operates on the output of time-based windowing operators. Each window of
/// `[Timestamped<Double>]` is resampled to a regular grid (since biological and
/// financial signals are often irregularly sampled), then transformed to the
/// frequency domain.
///
/// ## Usage Example
/// ```swift
/// rrIntervals
///     .timestamped()
///     .tumblingWindow(duration: .seconds(300))
///     .fft()
///     .map { spectrum in
///         let lfhf = spectrum.power(in: 0.04..<0.15) / spectrum.power(in: 0.15..<0.40)
///         return lfhf
///     }
/// ```
///
/// - Note: Uses ``FFTBackendSelector`` to automatically choose the optimal FFT
///   backend for the current platform.
public struct AsyncFFTSequence<Base: AsyncSequence>: AsyncSequence
    where Base.Element == [Timestamped<Double>] {

    /// Yields frequency spectra.
    public typealias Element = FrequencySpectrum

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base

    init(base: Base) {
        self.base = base
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields frequency spectra.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator())
    }

    /// Iterator for the streaming FFT sequence.
    ///
    /// For each window of timestamped values, resamples to a regular grid,
    /// applies FFT, and produces a ``FrequencySpectrum``.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let backend: any FFTBackend
        private var isComplete = false

        init(base: Base.AsyncIterator) {
            self.baseIterator = base
            self.backend = FFTBackendSelector.selectBackend()
        }

        /// Advances to the next frequency spectrum.
        ///
        /// Takes the next window of timestamped values, resamples to a regular grid,
        /// and computes the FFT.
        ///
        /// - Returns: The frequency spectrum of the next window, or `nil` when exhausted.
        /// - Throws: Rethrows any error from the base sequence.
        public mutating func next() async throws -> FrequencySpectrum? {
            guard !isComplete else { return nil }

            guard let window = try await baseIterator.next() else {
                isComplete = true
                return nil
            }

            // Need at least 2 samples for meaningful FFT
            guard window.count >= 2 else {
                return FrequencySpectrum(powers: [], sampleRate: 0, sampleCount: 0)
            }

            // Compute sample rate from timestamps
            let firstTimestamp = window[0].timestamp
            let lastTimestamp = window[window.count - 1].timestamp
            let totalDuration = durationToSeconds(firstTimestamp.duration(to: lastTimestamp))

            guard totalDuration > 0 else {
                return FrequencySpectrum(powers: [], sampleRate: 0, sampleCount: 0)
            }

            let sampleRate = Double(window.count - 1) / totalDuration

            // Resample to regular grid via linear interpolation
            let resampled = resampleToRegularGrid(window, count: window.count)

            // Compute power spectrum
            let powers = backend.powerSpectrum(resampled)

            return FrequencySpectrum(
                powers: powers,
                sampleRate: sampleRate,
                sampleCount: resampled.count
            )
        }

        /// Resamples irregularly-spaced timestamped values to a regular grid.
        ///
        /// Uses linear interpolation between known points.
        ///
        /// - Parameters:
        ///   - window: Timestamped values (assumed sorted by timestamp).
        ///   - count: Number of output samples.
        /// - Returns: Regularly-spaced values.
        private func resampleToRegularGrid(_ window: [Timestamped<Double>], count: Int) -> [Double] {
            guard window.count >= 2 else {
                return window.map(\.value)
            }

            let firstTime = window[0].timestamp
            let lastTime = window[window.count - 1].timestamp
            let totalNs = durationToSeconds(firstTime.duration(to: lastTime))

            guard totalNs > 0 else {
                return window.map(\.value)
            }

            var result = [Double](repeating: 0.0, count: count)
            var windowIdx = 0

            for i in 0..<count {
                let targetFraction = Double(i) / Double(count - 1)
                let targetNs = targetFraction * totalNs

                // Advance to the bracketing pair
                while windowIdx < window.count - 2 {
                    let nextNs = durationToSeconds(firstTime.duration(to: window[windowIdx + 1].timestamp))
                    if nextNs >= targetNs { break }
                    windowIdx += 1
                }

                let t0Ns = durationToSeconds(firstTime.duration(to: window[windowIdx].timestamp))
                let v0 = window[windowIdx].value

                if windowIdx + 1 < window.count {
                    let t1Ns = durationToSeconds(firstTime.duration(to: window[windowIdx + 1].timestamp))
                    let v1 = window[windowIdx + 1].value
                    let interval = t1Ns - t0Ns
                    if abs(interval) > 1e-15 {
                        let fraction = (targetNs - t0Ns) / interval
                        let clampedFraction = Swift.min(Swift.max(fraction, 0.0), 1.0)
                        result[i] = v0 + (v1 - v0) * clampedFraction
                    } else {
                        result[i] = v0
                    }
                } else {
                    result[i] = v0
                }
            }

            return result
        }

        /// Converts a Duration to seconds as a Double.
        private func durationToSeconds(_ duration: Duration) -> Double {
            let components = duration.components
            return Double(components.seconds) + Double(components.attoseconds) / 1e18
        }
    }
}

// MARK: - FFT Extension

extension AsyncSequence where Element == [Timestamped<Double>] {
    /// Applies FFT to each window of timestamped values, yielding frequency spectra.
    ///
    /// Each window is resampled to a regular grid (handling irregular timestamps)
    /// and transformed using the platform's optimal FFT backend.
    ///
    /// - Returns: An async sequence of ``FrequencySpectrum`` values.
    ///
    /// ## Usage Example
    /// ```swift
    /// let spectra = rrIntervals
    ///     .timestamped()
    ///     .tumblingWindow(duration: .seconds(300))
    ///     .fft()
    ///
    /// for try await spectrum in spectra {
    ///     let lfhf = spectrum.power(in: 0.04..<0.15) / spectrum.power(in: 0.15..<0.40)
    ///     print("LF/HF ratio: \(lfhf)")
    /// }
    /// ```
    public func fft() -> AsyncFFTSequence<Self> {
        AsyncFFTSequence(base: self)
    }
}
