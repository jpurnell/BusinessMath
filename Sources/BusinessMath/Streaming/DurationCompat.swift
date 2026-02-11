//
//  DurationCompat.swift
//  BusinessMath
//
//  Created on December 31, 2025.
//  Provides backwards compatibility for Duration API on iOS 14

import Foundation

// MARK: - Duration Compatibility

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Backwards-compatible duration representation for iOS 14+.
///
/// Provides a duration type that works on iOS 14 and later, bridging to Swift's
/// `Duration` type (available iOS 16+) when running on newer platforms. This enables
/// streaming analytics to work across a wider range of OS versions.
///
/// ## Example
/// ```swift
/// let timeout = CompatDuration.seconds(30)
/// try await Task.compatSleep(for: timeout)
/// ```
///
/// - Note: Internally stores duration as nanoseconds for precise measurement
///
/// - SeeAlso: ``CompatClock``
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct CompatDuration: Sendable {
    let nanoseconds: Int64

    /// Creates a duration from a nanosecond count.
    ///
    /// - Parameter nanoseconds: The duration in nanoseconds.
    public init(nanoseconds: Int64) {
        self.nanoseconds = nanoseconds
    }

    /// Creates a compatible duration from Swift's Duration type (iOS 16+).
    ///
    /// Converts a native Duration to CompatDuration for use with backwards-compatible APIs.
    ///
    /// - Parameter duration: The Duration to convert
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public init(_ duration: Duration) {
        self.nanoseconds = Int64(duration.components.seconds) * 1_000_000_000 +
                          Int64(duration.components.attoseconds / 1_000_000_000)
    }

    /// Converts this compatible duration to Swift's Duration type (iOS 16+).
    ///
    /// Bridges CompatDuration to the native Duration type on platforms that support it.
    ///
    /// - Returns: A Duration with equivalent time span
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public var duration: Duration {
        let seconds = nanoseconds / 1_000_000_000
        let attoseconds = (nanoseconds % 1_000_000_000) * 1_000_000_000
        return Duration(secondsComponent: seconds, attosecondsComponent: attoseconds)
    }

    /// Creates a duration from a number of seconds.
    ///
    /// - Parameter value: The number of seconds.
    /// - Returns: A duration representing that many seconds.
    public static func seconds(_ value: Int64) -> CompatDuration {
        CompatDuration(nanoseconds: value * 1_000_000_000)
    }

    /// Creates a duration from a number of milliseconds.
    ///
    /// - Parameter value: The number of milliseconds.
    /// - Returns: A duration representing that many milliseconds.
    public static func milliseconds(_ value: Int64) -> CompatDuration {
        CompatDuration(nanoseconds: value * 1_000_000)
    }

    /// Creates a duration from a number of microseconds.
    ///
    /// - Parameter value: The number of microseconds.
    /// - Returns: A duration representing that many microseconds.
    public static func microseconds(_ value: Int64) -> CompatDuration {
        CompatDuration(nanoseconds: value * 1_000)
    }

    /// Compares two durations for ordering.
    ///
    /// - Returns: `true` if the left duration is shorter than the right duration.
    public static func < (lhs: CompatDuration, rhs: CompatDuration) -> Bool {
        lhs.nanoseconds < rhs.nanoseconds
    }

    /// Subtracts one duration from another.
    ///
    /// - Returns: The difference between the two durations.
    public static func - (lhs: CompatDuration, rhs: CompatDuration) -> CompatDuration {
        CompatDuration(nanoseconds: lhs.nanoseconds - rhs.nanoseconds)
    }
}

// MARK: - Backwards-Compatible Sleep

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension Task where Success == Never, Failure == Never {
    /// Sleep for a duration, with fallback for iOS 14
    public static func compatSleep(for duration: CompatDuration) async throws {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
            try await Task.sleep(for: duration.duration)
        } else {
            try await Task.sleep(nanoseconds: UInt64(max(0, duration.nanoseconds)))
        }
    }
}

// MARK: - Clock Compatibility

/// Backwards-compatible monotonic clock for measuring elapsed time.
///
/// Provides high-resolution time measurement that works on iOS 14+, using
/// platform-specific APIs (`mach_absolute_time` on Darwin, `clock_gettime` on Linux).
///
/// ## Example
/// ```swift
/// let clock = CompatClock()
/// // ... perform work ...
/// let elapsed = clock.now()
/// ```
///
/// - Note: Uses `mach_absolute_time` on Darwin and `clock_gettime` on Linux for high-resolution timing
///
/// - SeeAlso: ``CompatDuration``
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct CompatClock: Sendable {
    private let startTime: UInt64

    /// Creates a clock initialized to the current time.
    ///
    /// The clock's ``now()`` method will return elapsed time since initialization.
    public init() {
        self.startTime = Self.currentNanos()
    }

    /// Returns the elapsed time since the clock was created.
    ///
    /// - Returns: A duration representing the time elapsed since initialization.
    public func now() -> CompatDuration {
        let currentNanos = Self.currentNanos()
        return CompatDuration(nanoseconds: Int64(currentNanos - startTime))
    }

    private static func currentNanos() -> UInt64 {
        #if canImport(Darwin)
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let time = mach_absolute_time()
        return time * UInt64(info.numer) / UInt64(info.denom)
        #else
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        return UInt64(ts.tv_sec) * 1_000_000_000 + UInt64(ts.tv_nsec)
        #endif
    }
}

// MARK: - Extension to convert from iOS 16+ Duration

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Duration {
    /// Converts a Duration to CompatDuration for backwards compatibility.
    ///
    /// Use this property to bridge from iOS 16+ Duration to CompatDuration when
    /// supporting older platforms.
    ///
    /// - Returns: A compatible duration with the same time span.
    public var compat: CompatDuration {
        CompatDuration(self)
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension CompatDuration {
    /// Creates a CompatDuration from a Duration.
    ///
    /// - Parameter duration: The Duration to convert.
    /// - Returns: A compatible duration with the same time span.
    public static func from(_ duration: Duration) -> CompatDuration {
        CompatDuration(duration)
    }
}
