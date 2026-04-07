//
//  FFTBackend.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-05.
//

import Foundation

// MARK: - FFT Backend Protocol

/// Backend protocol for Fast Fourier Transform computations.
///
/// Implementations provide platform-optimized FFT execution. All backends must produce
/// mathematically equivalent results within numerical tolerance.
///
/// ## Available Backends
///
/// - ``PureSwiftFFTBackend``: Cooley-Tukey radix-2 FFT, runs on all platforms.
/// - ``AccelerateFFTBackend``: vDSP-backed FFT for Darwin platforms (macOS, iOS, etc.).
///
/// ## Performance Characteristics
///
/// | Backend | Best For | Platform |
/// |---------|----------|----------|
/// | PureSwift | Universal fallback | All (Linux, Android, Darwin) |
/// | Accelerate | Optimized performance | Darwin only |
///
/// ## Usage Example
///
/// ```swift
/// let backend = FFTBackendSelector.selectBackend()
/// let spectrum = backend.powerSpectrum(signal)
/// ```
///
/// - Note: All implementations must be thread-safe and conform to `Sendable`.
public protocol FFTBackend: Sendable {

    /// Compute the power spectrum (magnitude squared) of a real-valued signal.
    ///
    /// The input signal is zero-padded to the next power of 2 if needed. Returns
    /// `N/2 + 1` power values representing frequencies from DC to Nyquist.
    ///
    /// - Parameter signal: Real-valued input signal.
    /// - Returns: Power spectrum values of length `N/2 + 1` where N is the
    ///   zero-padded signal length.
    func powerSpectrum(_ signal: [Double]) -> [Double]

    /// Compute the one-sided power spectral density (PSD) of a real-valued signal.
    ///
    /// The integral of the returned PSD over frequency equals the time-domain
    /// variance of the input signal (Parseval's theorem). Values are in
    /// `units²/Hz` where `units` is the unit of the input signal — for example,
    /// HRV RR-interval data in milliseconds yields PSD in `ms²/Hz` and
    /// integrated band power in `ms²`.
    ///
    /// **Normalization conventions:**
    /// - One-sided spectrum: bins `1..<N/2` carry a factor of 2; the DC bin
    ///   `0` and the Nyquist bin `N/2` do **not**.
    /// - The normalization uses the **unpadded** signal length `M`, not the
    ///   internally zero-padded length `N`. This ensures the PSD integral
    ///   equals the time-domain variance regardless of input length.
    /// - No window function is applied. Callers that want a tapered window
    ///   (Hann, Hamming, etc.) must apply it before calling, and compensate
    ///   the result by dividing by the window's noise-equivalent bandwidth
    ///   `(1/M) · Σ w[m]²`.
    /// - For Parseval to hold exactly, the input should be zero-mean (apply
    ///   mean removal before calling). Otherwise the DC bin reflects the
    ///   signal's mean and the integral exceeds the variance by `mean²`.
    ///
    /// ## Example
    /// ```swift
    /// let backend = FFTBackendSelector.selectBackend()
    /// let mean = signal.reduce(0, +) / Double(signal.count)
    /// let zeroMean = signal.map { $0 - mean }
    /// let psd = backend.powerSpectralDensity(zeroMean, sampleRate: 4.0)
    /// ```
    ///
    /// - Parameters:
    ///   - signal: Real-valued input signal. Should be mean-removed (and
    ///     optionally windowed) before calling. Internally zero-padded to
    ///     the next power of 2 for the FFT.
    ///   - sampleRate: Sample rate in Hz. Must be positive.
    /// - Returns: One-sided PSD bins of length `N/2 + 1` where `N` is the
    ///   zero-padded length. Returns an empty array for an empty signal or
    ///   non-positive sample rate.
    func powerSpectralDensity(_ signal: [Double], sampleRate: Double) -> [Double]
}

// MARK: - PSD Default Implementation

extension FFTBackend {

    /// Default one-sided PSD implementation, derived from `powerSpectrum(_:)`.
    ///
    /// All conforming backends inherit this for free. Backends MAY override
    /// for performance, but the default is correct and stable.
    public func powerSpectralDensity(
        _ signal: [Double],
        sampleRate: Double
    ) -> [Double] {
        guard signal.isEmpty == false, sampleRate > 0 else { return [] }

        let unpaddedLength = signal.count
        let raw = powerSpectrum(signal)
        guard raw.isEmpty == false else { return [] }

        let nyquistBin = raw.count - 1
        // Typical bins: factor of 2 for the one-sided convention
        let typicalFactor = 2.0 / (Double(unpaddedLength) * sampleRate)
        // DC bin and Nyquist bin: no factor of 2
        let edgeFactor = 1.0 / (Double(unpaddedLength) * sampleRate)

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

    /// One-sided PSD with each bin labeled by its center frequency in Hz.
    ///
    /// Convenience that pairs ``powerSpectralDensity(_:sampleRate:)`` values
    /// with their bin frequencies, so downstream code doesn't need to
    /// recompute `Δf = sampleRate / N_padded`.
    ///
    /// - Parameters:
    ///   - signal: Real-valued input signal. See ``powerSpectralDensity(_:sampleRate:)``
    ///     for preparation requirements.
    ///   - sampleRate: Sample rate in Hz.
    /// - Returns: An array of ``PSDBin`` values. Empty for empty input.
    public func powerSpectralDensityBins(
        _ signal: [Double],
        sampleRate: Double
    ) -> [PSDBin] {
        let psd = powerSpectralDensity(signal, sampleRate: sampleRate)
        guard psd.isEmpty == false else { return [] }
        let paddedLength = (psd.count - 1) * 2
        guard paddedLength > 0 else { return [] }
        let deltaF = sampleRate / Double(paddedLength)
        return psd.enumerated().map { idx, value in
            PSDBin(frequency: Double(idx) * deltaF, power: value)
        }
    }
}

// MARK: - PSDBin

/// A single power spectral density value paired with its center frequency.
///
/// Returned by ``FFTBackend/powerSpectralDensityBins(_:sampleRate:)``.
public struct PSDBin: Sendable, Equatable {

    /// Center frequency of the bin, in Hz.
    public let frequency: Double

    /// Power spectral density at this bin, in `units²/Hz`.
    public let power: Double

    /// Creates a PSD bin with the given frequency and power.
    public init(frequency: Double, power: Double) {
        self.frequency = frequency
        self.power = power
    }
}

// MARK: - Pure Swift FFT Backend

/// Cooley-Tukey radix-2 FFT implementation in pure Swift.
///
/// Runs on all platforms including Linux and Android. For Darwin platforms,
/// ``AccelerateFFTBackend`` provides better performance via vDSP.
///
/// The algorithm operates on power-of-2 length inputs. Non-power-of-2 inputs
/// are automatically zero-padded.
///
/// ## Mathematical Background
///
/// The Discrete Fourier Transform:
/// ```
/// X[k] = Σ(n=0..N-1) x[n] · e^(-j·2π·k·n/N)
/// ```
///
/// Power spectrum:
/// ```
/// P[k] = |X[k]|² = Re(X[k])² + Im(X[k])²
/// ```
///
/// - Complexity: O(N log N) where N is the (padded) signal length.
public struct PureSwiftFFTBackend: FFTBackend, Sendable {

    /// Creates a new Pure Swift FFT backend.
    public init() {}

    /// Compute the power spectrum using Cooley-Tukey radix-2 FFT.
    ///
    /// - Parameter signal: Real-valued input signal. Zero-padded to next power of 2 if needed.
    /// - Returns: Power spectrum of length `N/2 + 1`. Empty array for empty input.
    public func powerSpectrum(_ signal: [Double]) -> [Double] {
        guard signal.isEmpty == false else { return [] }

        // Zero-pad to next power of 2
        let n = nextPowerOf2(signal.count)
        var real = [Double](repeating: 0.0, count: n)
        var imag = [Double](repeating: 0.0, count: n)

        for i in 0..<signal.count {
            real[i] = signal[i]
        }

        // In-place Cooley-Tukey FFT
        cooleyTukeyFFT(&real, &imag, n)

        // Compute power spectrum (N/2 + 1 unique frequencies)
        let numBins = n / 2 + 1
        var power = [Double](repeating: 0.0, count: numBins)
        for k in 0..<numBins {
            power[k] = real[k] * real[k] + imag[k] * imag[k]
        }

        return power
    }

    /// Cooley-Tukey radix-2 decimation-in-time FFT.
    ///
    /// Operates in-place on separate real and imaginary arrays.
    ///
    /// - Parameters:
    ///   - real: Real part of the signal (modified in-place).
    ///   - imag: Imaginary part of the signal (modified in-place).
    ///   - n: Signal length (must be a power of 2).
    private func cooleyTukeyFFT(_ real: inout [Double], _ imag: inout [Double], _ n: Int) {
        guard n > 1 else { return }

        // Bit-reversal permutation
        let logN = Int(log2(Double(n)))
        for i in 0..<n {
            let j = bitReverse(i, bits: logN)
            if i < j {
                real.swapAt(i, j)
                imag.swapAt(i, j)
            }
        }

        // Butterfly operations
        var size = 2
        while size <= n {
            let halfSize = size / 2
            let angle = -2.0 * Double.pi / Double(size)

            for start in stride(from: 0, to: n, by: size) {
                for k in 0..<halfSize {
                    let theta = angle * Double(k)
                    let cosTheta = cos(theta)
                    let sinTheta = sin(theta)

                    let evenIdx = start + k
                    let oddIdx = start + k + halfSize

                    let tReal = cosTheta * real[oddIdx] - sinTheta * imag[oddIdx]
                    let tImag = sinTheta * real[oddIdx] + cosTheta * imag[oddIdx]

                    real[oddIdx] = real[evenIdx] - tReal
                    imag[oddIdx] = imag[evenIdx] - tImag
                    real[evenIdx] = real[evenIdx] + tReal
                    imag[evenIdx] = imag[evenIdx] + tImag
                }
            }

            size *= 2
        }
    }

    /// Reverse the lower `bits` bits of the integer `x`.
    private func bitReverse(_ x: Int, bits: Int) -> Int {
        var result = 0
        var value = x
        for _ in 0..<bits {
            result = (result << 1) | (value & 1)
            value >>= 1
        }
        return result
    }

    /// Returns the smallest power of 2 that is ≥ n.
    private func nextPowerOf2(_ n: Int) -> Int {
        guard n > 0 else { return 1 }
        var p = 1
        while p < n {
            p *= 2
        }
        return p
    }
}

// MARK: - Accelerate FFT Backend

#if canImport(Accelerate)
import Accelerate

/// vDSP-backed FFT for optimized performance on Darwin platforms.
///
/// Uses Apple's Accelerate framework (vDSP) for hardware-optimized FFT computation.
/// Automatically handles zero-padding and split-complex format conversion.
///
/// - Note: Only available on Darwin platforms (macOS, iOS, tvOS, watchOS, visionOS).
///
/// ## Usage Example
/// ```swift
/// let backend = AccelerateFFTBackend()
/// let spectrum = backend.powerSpectrum(signal)
/// ```
public struct AccelerateFFTBackend: FFTBackend, Sendable {

    /// Creates a new Accelerate FFT backend.
    public init() {}

    /// Compute the power spectrum using vDSP.
    ///
    /// - Parameter signal: Real-valued input signal. Zero-padded to next power of 2 if needed.
    /// - Returns: Power spectrum of length `N/2 + 1`. Empty array for empty input.
    public func powerSpectrum(_ signal: [Double]) -> [Double] {
        guard signal.isEmpty == false else { return [] }

        let n = nextPowerOf2(signal.count)
        let log2n = vDSP_Length(log2(Double(n)))

        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return PureSwiftFFTBackend().powerSpectrum(signal)
        }
        defer { vDSP_destroy_fftsetupD(fftSetup) }

        // Zero-pad signal
        var paddedSignal = [Double](repeating: 0.0, count: n)
        for i in 0..<signal.count {
            paddedSignal[i] = signal[i]
        }

        var realPart = [Double](repeating: 0.0, count: n / 2)
        var imagPart = [Double](repeating: 0.0, count: n / 2)

        // Convert to split complex and perform FFT — all unsafe pointers must be
        // nested within their withUnsafe* closures to avoid dangling references
        realPart.withUnsafeMutableBufferPointer { realBuf in
            imagPart.withUnsafeMutableBufferPointer { imagBuf in
                var splitComplex = DSPDoubleSplitComplex(
                    realp: realBuf.baseAddress!,
                    imagp: imagBuf.baseAddress!
                )

                // Convert interleaved real signal to split complex format
                paddedSignal.withUnsafeBufferPointer { signalPtr in
                    signalPtr.baseAddress!.withMemoryRebound(
                        to: DSPDoubleComplex.self,
                        capacity: n / 2
                    ) { complexPtr in
                        vDSP_ctozD(complexPtr, 2, &splitComplex, 1, vDSP_Length(n / 2))
                    }
                }

                // Forward real-input FFT in-place
                vDSP_fft_zripD(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }

        // Compute power spectrum from results.
        //
        // **vDSP scaling correction:** `vDSP_fft_zripD` returns FFT outputs
        // scaled by 2 vs the textbook DFT formula (vDSP convention for
        // packed real-input FFT). Squaring magnitudes therefore yields
        // values 4× the textbook |X[k]|². We divide by 4 to match the
        // mathematical definition that `PureSwiftFFTBackend` produces, so
        // both backends are interchangeable for absolute-power analysis
        // (Parseval, PSD, band integration, etc.).
        //
        // Without this correction, downstream PSD computation would be
        // off by 4× on Darwin only, breaking Parseval's theorem.
        let numBins = n / 2 + 1
        var power = [Double](repeating: 0.0, count: numBins)
        let vdspScalingCorrection = 0.25  // = 1/4

        // DC component
        power[0] = realPart[0] * realPart[0] * vdspScalingCorrection

        // Nyquist component (packed in imagPart[0] for real FFT)
        if numBins > 1 {
            power[numBins - 1] = imagPart[0] * imagPart[0] * vdspScalingCorrection
        }

        // Other bins
        for k in 1..<(n / 2) {
            if k < numBins {
                power[k] = (realPart[k] * realPart[k] + imagPart[k] * imagPart[k]) * vdspScalingCorrection
            }
        }

        return power
    }

    /// Returns the smallest power of 2 that is ≥ n.
    private func nextPowerOf2(_ n: Int) -> Int {
        guard n > 0 else { return 1 }
        var p = 1
        while p < n {
            p *= 2
        }
        return p
    }
}
#endif

// MARK: - FFT Backend Selector

/// Automatically selects the best available FFT backend for the current platform.
///
/// On Darwin platforms (macOS, iOS, etc.), selects ``AccelerateFFTBackend`` for
/// hardware-optimized performance. On Linux/Android, falls back to
/// ``PureSwiftFFTBackend``.
///
/// ## Usage Example
/// ```swift
/// let backend = FFTBackendSelector.selectBackend()
/// let spectrum = backend.powerSpectrum(signal)
/// ```
public struct FFTBackendSelector {

    /// Select the optimal FFT backend for the current platform.
    ///
    /// - Returns: The best available FFT backend.
    public static func selectBackend() -> any FFTBackend {
        #if canImport(Accelerate)
        return AccelerateFFTBackend()
        #else
        return PureSwiftFFTBackend()
        #endif
    }
}
