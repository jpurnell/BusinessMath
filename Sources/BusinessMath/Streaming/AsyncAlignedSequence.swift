//
//  AsyncAlignedSequence.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-05.
//

import Foundation

// MARK: - Duration Helpers

/// Converts a `Duration` to nanoseconds as a `Double`.
///
/// Uses the `components` property to extract seconds and attoseconds,
/// combining them into a single nanosecond value.
private func durationToNanoseconds(_ duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds) * 1e9 + Double(components.attoseconds) / 1e9
}

// MARK: - Alignment Strategy

/// Strategy for aligning two timestamped streams running at different sample rates.
///
/// When a primary stream element arrives, the alignment strategy determines how to
/// select or compute a corresponding value from the secondary stream.
///
/// ## Strategies
///
/// - ``nearest``: Snaps to the secondary value with the closest timestamp.
/// - ``linearInterpolation``: Computes a weighted blend between the two nearest
///   secondary values bracketing the primary timestamp.
public enum AlignmentStrategy: Sendable, Equatable {
    /// Snap to the secondary value with the closest timestamp.
    ///
    /// Fast and simple. Appropriate when the secondary stream's sample rate is
    /// sufficiently high relative to the primary stream.
    case nearest

    /// Linearly interpolate between the two nearest secondary values.
    ///
    /// Produces smoother alignment by computing a weighted blend based on temporal
    /// proximity: `v = v₀ + (v₁ - v₀) × (t - t₀) / (t₁ - t₀)`.
    case linearInterpolation
}

// MARK: - Alignment State Actor

/// Actor holding the two most recent secondary stream values for alignment.
private actor AlignmentState {
    private var previous: Timestamped<Double>?
    private var current: Timestamped<Double>?
    private var hasFinished = false

    func update(_ value: Timestamped<Double>) {
        previous = current
        current = value
    }

    func getCurrent() -> Timestamped<Double>? {
        current
    }

    func getPrevious() -> Timestamped<Double>? {
        previous
    }

    func markFinished() {
        hasFinished = true
    }

    func isFinished() -> Bool {
        hasFinished
    }
}

// MARK: - AsyncAlignedSequence

/// An async sequence that aligns a primary timestamped stream with a secondary stream
/// running at a different sample rate.
///
/// Each element from the primary stream is paired with an aligned value from the secondary
/// stream, determined by the chosen ``AlignmentStrategy``. This enables correlation of
/// signals sampled at different rates — for example, HRV data (~1 Hz) with accelerometer
/// data (50 Hz).
///
/// Unlike `combineLatest`, which emits whenever either stream updates without temporal
/// registration, alignment ensures each output is temporally coherent.
///
/// ## Usage Example
/// ```swift
/// let rrIntervals = rrStream.timestamped()     // ~1 Hz, irregular
/// let accelStream = accel.timestamped()         // 50 Hz
/// for try await (rr, accelValue) in rrIntervals.aligned(with: accelStream, strategy: .nearest) {
///     print("RR: \(rr), motion: \(accelValue)")
/// }
/// ```
///
/// - Note: Generalizes to joining financial time series at different frequencies,
///   multi-sensor IoT fusion, and combining user event logs with server metrics.
public struct AsyncAlignedSequence<
    Primary: AsyncSequence & Sendable,
    Secondary: AsyncSequence & Sendable
>: AsyncSequence
    where Primary.Element == Timestamped<Double>,
          Secondary.Element == Timestamped<Double>,
          Primary.Element: Sendable,
          Secondary.Element: Sendable {

    /// Yields tuples of (primary value, aligned secondary value).
    public typealias Element = (Double, Double)

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let primary: Primary
    private let secondary: Secondary
    private let strategy: AlignmentStrategy

    init(primary: Primary, secondary: Secondary, strategy: AlignmentStrategy) {
        self.primary = primary
        self.secondary = secondary
        self.strategy = strategy
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields aligned value pairs.
    public func makeAsyncIterator() -> Iterator {
        Iterator(primary: primary, secondary: secondary, strategy: strategy)
    }

    /// Iterator that aligns two timestamped streams.
    ///
    /// Uses a task group to concurrently consume both streams. The secondary stream's
    /// latest values are stored in an actor for thread-safe access. When the primary
    /// stream emits, the iterator reads the secondary state and applies the alignment
    /// strategy.
    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let channel: AsyncStream<Element>
        private var iterator: AsyncStream<Element>.AsyncIterator

        init(primary: Primary, secondary: Secondary, strategy: AlignmentStrategy) {
            let (channel, continuationBox): (AsyncStream<Element>, ContinuationBox<Element>) = {
                var box: ContinuationBox<Element>!  // swiftlint:disable:this identifier_name
                let ch = AsyncStream<Element> { cont in
                    box = ContinuationBox(cont)
                }
                return (ch, box)
            }()
            self.channel = channel
            self.iterator = channel.makeAsyncIterator()

            Task { @Sendable in
                let state = AlignmentState()

                await withTaskGroup(of: Void.self) { group in
                    // Secondary consumer: continuously updates state with latest values
                    group.addTask { @Sendable in
                        var iter = secondary.makeAsyncIterator()
                        while !Task.isCancelled {
                            do {
                                guard let value = try await iter.next() else {
                                    await state.markFinished()
                                    break
                                }
                                await state.update(value)
                            } catch {
                                await state.markFinished()
                                break
                            }
                        }
                    }

                    // Primary consumer: reads state and emits aligned pairs
                    group.addTask { @Sendable in
                        var iter = primary.makeAsyncIterator()
                        // Give secondary a moment to start producing values
                        try? await Task.sleep(for: .milliseconds(1))

                        while !Task.isCancelled {
                            do {
                                guard let primaryElement = try await iter.next() else {
                                    break
                                }

                                // Wait briefly for secondary to have at least one value
                                var secondaryCurrent = await state.getCurrent()
                                if secondaryCurrent == nil {
                                    try? await Task.sleep(for: .milliseconds(5))
                                    secondaryCurrent = await state.getCurrent()
                                }

                                guard let current = secondaryCurrent else {
                                    continue
                                }

                                let alignedValue: Double
                                switch strategy {
                                case .nearest:
                                    let previous = await state.getPrevious()
                                    if let prev = previous {
                                        let distToCurrent = durationToNanoseconds(primaryElement.timestamp.duration(to: current.timestamp))
                                        let distToPrev = durationToNanoseconds(primaryElement.timestamp.duration(to: prev.timestamp))
                                        alignedValue = abs(distToCurrent) <= abs(distToPrev) ? current.value : prev.value
                                    } else {
                                        alignedValue = current.value
                                    }

                                case .linearInterpolation:
                                    let previous = await state.getPrevious()
                                    if let prev = previous {
                                        let totalNs = durationToNanoseconds(prev.timestamp.duration(to: current.timestamp))
                                        let elapsedNs = durationToNanoseconds(prev.timestamp.duration(to: primaryElement.timestamp))

                                        guard abs(totalNs) > 1e-3 else {
                                            alignedValue = current.value
                                            break
                                        }

                                        let fraction = elapsedNs / totalNs
                                        let clampedFraction = Swift.min(Swift.max(fraction, 0.0), 1.0)
                                        alignedValue = prev.value + (current.value - prev.value) * clampedFraction
                                    } else {
                                        alignedValue = current.value
                                    }
                                }

                                continuationBox.yield((primaryElement.value, alignedValue))
                            } catch {
                                break
                            }
                        }
                    }

                    await group.waitForAll()
                    continuationBox.finish()
                }
            }
        }

        /// Advances to the next aligned value pair.
        ///
        /// - Returns: A tuple of (primary value, aligned secondary value), or `nil`
        ///   when the primary stream completes.
        public mutating func next() async throws -> Element? {
            return await iterator.next()
        }
    }
}

// MARK: - Alignment Extension

extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Aligns this timestamped stream with another timestamped stream running at a different rate.
    ///
    /// For each element in this (primary) stream, produces an aligned value from the
    /// secondary stream using the specified strategy.
    ///
    /// - Parameters:
    ///   - other: The secondary timestamped stream to align with.
    ///   - strategy: The alignment method to use. Defaults to `.nearest`.
    /// - Returns: An async sequence of `(primaryValue, alignedSecondaryValue)` tuples.
    ///
    /// ## Usage Example
    /// ```swift
    /// let hrv = rrIntervals.timestamped()       // ~1 Hz
    /// let motion = accelerometer.timestamped()   // 50 Hz
    /// for try await (rr, accel) in hrv.aligned(with: motion, strategy: .nearest) {
    ///     print("RR: \(rr), accel: \(accel)")
    /// }
    /// ```
    public func aligned<Secondary: AsyncSequence & Sendable>(
        with other: Secondary,
        strategy: AlignmentStrategy = .nearest
    ) -> AsyncAlignedSequence<Self, Secondary>
        where Self.Element == Timestamped<Double>,
              Secondary.Element == Timestamped<Double>,
              Secondary.Element: Sendable {
        AsyncAlignedSequence(primary: self, secondary: other, strategy: strategy)
    }
}
