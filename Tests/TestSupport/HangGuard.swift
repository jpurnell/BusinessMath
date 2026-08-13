//
//  HangGuard.swift
//  TestSupport
//
//  The `.timeLimit` for tests whose subject is the answer, not the clock.
//

import Testing
import Foundation

/// A Swift Testing `timeLimit` sized to catch a hang and nothing else.
///
/// This is the ``unboundedSolverTimeLimit`` argument applied to the test trait rather than
/// to a solver: a test asserting `all scores in (0, 1]` is making a claim about the library,
/// and a wall-clock limit converts it into the weaker claim *and it finished within N
/// seconds on this machine right now*, which a loaded runner can falsify without any change
/// to the code under test.
///
/// The trait cannot simply be dropped the way a solver budget can. It is the reason CI
/// notices a hang at all — the 2.5.1 streaming producer that never terminated was caught by
/// exactly this — so the limit stays and its *value* is what changes.
///
/// ## Why so large
///
/// Swift Testing measures **elapsed wall clock per test, not work performed**. Tests run
/// concurrently, so an `async` test that awaits is descheduled while other tests hold the
/// cores, and its clock keeps running. Measured on this suite: tests reporting ~25s in a
/// full run take **0.014s** when run alone, and the three that failed under Thread Sanitizer
/// take 15–33 *milliseconds* in isolation. Their elapsed time is a reading of the machine,
/// not of themselves.
///
/// So the binding number is not any test's runtime — it is the whole suite's, because a test
/// that starts early and awaits will span the entire run. Under `--sanitize thread` this
/// suite takes ~320s against ~28s uninstrumented, roughly 11×, and the old `.minutes(2)`
/// sat below that. It failed twice: once as a timeout on `fiftyDMUsModerateScale` (120s
/// limit, 281s elapsed), having passed the night before. Nothing about the code changed
/// between those runs.
///
/// Twenty minutes is chosen against two bounds rather than against any measurement of the
/// tests. It must exceed the worst-case suite duration under the heaviest instrumentation
/// with room for the suite to grow, and it must stay well under the job's `timeout-minutes:
/// 120` — because a hang should be reported by the test that hung, naming itself, rather
/// than by the job timeout, which names nothing.
///
/// ## Why raising it costs nothing
///
/// A limit this far above real runtime cannot detect a performance regression, but neither
/// could `.minutes(2)`: a test taking 33ms would have to regress by ~3,600× to trip it. That
/// is not a slowdown, it is a stall. Both values catch exactly one thing — code that stopped
/// making progress — and only one of them also fires when the runner is busy.
///
/// Performance claims belong in a benchmark that measures in isolation, where the number
/// means something. `SparsePerformanceBenchmark` is the pattern: an explicit
/// `#expect(duration < 1.0)`, a `// TIMING:` marker, and a `RUN_BENCHMARKS` condition trait.
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public let testHangGuard: TimeLimitTrait.Duration = .minutes(20)
