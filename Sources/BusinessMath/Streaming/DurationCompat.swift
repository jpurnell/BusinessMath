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

/// Backwards-compatible duration representation
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct CompatDuration: Sendable {
    let nanoseconds: Int64

    public init(nanoseconds: Int64) {
        self.nanoseconds = nanoseconds
    }

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public init(_ duration: Duration) {
        self.nanoseconds = Int64(duration.components.seconds) * 1_000_000_000 +
                          Int64(duration.components.attoseconds / 1_000_000_000)
    }

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public var duration: Duration {
        let seconds = nanoseconds / 1_000_000_000
        let attoseconds = (nanoseconds % 1_000_000_000) * 1_000_000_000
        return Duration(secondsComponent: seconds, attosecondsComponent: attoseconds)
    }

    public static func seconds(_ value: Int64) -> CompatDuration {
        CompatDuration(nanoseconds: value * 1_000_000_000)
    }

    public static func milliseconds(_ value: Int64) -> CompatDuration {
        CompatDuration(nanoseconds: value * 1_000_000)
    }

    public static func microseconds(_ value: Int64) -> CompatDuration {
        CompatDuration(nanoseconds: value * 1_000)
    }

    public static func < (lhs: CompatDuration, rhs: CompatDuration) -> Bool {
        lhs.nanoseconds < rhs.nanoseconds
    }

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

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct CompatClock: Sendable {
    private let startTime: UInt64

    public init() {
        self.startTime = Self.currentNanos()
    }

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
    public var compat: CompatDuration {
        CompatDuration(self)
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension CompatDuration {
    public static func from(_ duration: Duration) -> CompatDuration {
        CompatDuration(duration)
    }
}
