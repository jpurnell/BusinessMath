//
//  WallClock.swift
//  BusinessMath
//

/// BusinessMath's wall-clock abstraction is SwiftDeterminism's, re-exported.
///
/// The seeded-RNG half of determinism was adopted across this library some time ago; the
/// clock half was not, and around twenty sites called `Date()` directly. Each of those
/// made the *value returned* depend on the moment it was constructed, which is only
/// testable against a tolerance — and a tolerance is exactly what a test of a timestamp
/// should not need.
///
/// Re-exported rather than aliased, following ``SplitMix64``: the names are unchanged, so
/// a caller writing `FixedWallClock(at:)` needs only `import BusinessMath`. This matters
/// because the clock now appears in BusinessMath's own public signatures — a caller who
/// wants to inject one should not have to discover a transitive dependency to do it.
///
/// ## What is injected, and what is not
///
/// Types that *record* a moment on a value they return take a clock:
/// ``CapTable``, ``ModelDebugger``, ``ModelProfiler``, ``ModelValidator``,
/// ``CalculationTrace``, ``TemplateRegistry``, ``CalculationCache``, and
/// ``AsyncGradientDescentOptimizer``.
///
/// Code that *measures elapsed time* deliberately does not. `WallClock` vends a `Date`,
/// and a `Date` is the wrong instrument for a duration whoever supplies it: wall time is
/// subject to NTP correction and can run backwards, so a benchmark built on differences
/// of `Date` can report a negative interval. Those sites want a monotonic source —
/// `ContinuousClock`, which ``AsyncGradientDescentOptimizer`` already uses for its
/// progress-reporting interval. Injecting a `WallClock` there would make them testable
/// and leave them wrong.
///
/// ## Example
///
/// ```swift
/// // Production: the real clock, supplied by default.
/// let table = CapTable(shareholders: founders, optionPool: 2_000_000)
///
/// // Test: a chosen moment, asserted exactly.
/// let instant = Date(timeIntervalSince1970: 1_767_225_600)
/// let table = CapTable(shareholders: founders, optionPool: 0, clock: FixedWallClock(at: instant))
/// #expect(table.grantOptions(recipient: "Alice", shares: 1_000, strikePrice: 0.01)
///     .shareholders.last?.investmentDate == instant)
/// ```
@_exported import protocol SwiftDeterminism.WallClock

/// The real clock, and the default for every injection point in BusinessMath.
///
/// The only implementation that consults the operating system, so a type left to its
/// default behaves exactly as it did when it called `Date()` directly.
@_exported import struct SwiftDeterminism.SystemWallClock

/// A clock stopped at a chosen moment.
///
/// The right choice wherever a timestamp is simply *recorded*: every reading returns the
/// same value, so the assertion is an exact equality rather than a window.
@_exported import struct SwiftDeterminism.FixedWallClock

/// A clock that advances only when told to.
///
/// The right choice where behaviour depends on time *passing* rather than on a single
/// instant. In BusinessMath that is ``CalculationCache`` and `CalculationCacheAsync`,
/// whose entries expire against a TTL: `advance(by:)` steps past the boundary without a
/// test sleeping for it, which would be both slow and timing-dependent.
@_exported import class SwiftDeterminism.ManualWallClock
