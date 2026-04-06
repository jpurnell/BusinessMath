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

        // Compute power spectrum from results
        let numBins = n / 2 + 1
        var power = [Double](repeating: 0.0, count: numBins)

        // DC component
        power[0] = realPart[0] * realPart[0]

        // Nyquist component (packed in imagPart[0] for real FFT)
        if numBins > 1 {
            power[numBins - 1] = imagPart[0] * imagPart[0]
        }

        // Other bins
        for k in 1..<(n / 2) {
            if k < numBins {
                power[k] = realPart[k] * realPart[k] + imagPart[k] * imagPart[k]
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
