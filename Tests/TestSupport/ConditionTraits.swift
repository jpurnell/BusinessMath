//
//  ConditionTraits.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2/28/26.
//
import Testing
import Foundation

extension Trait where Self == ConditionTrait {

	/// Runs the test only outside continuous integration.
	///
	/// The previous condition was
	/// `CI == nil || GITHUB_ACTIONS != "true"`, which reads as "not in CI" and is not.
	/// The disjunction meant a runner that sets `CI` but not `GITHUB_ACTIONS` — GitLab,
	/// Jenkins, Xcode Cloud, anything that is not GitHub Actions — evaluated
	/// `nil != "true"` as `true` and ran the test anyway. It skipped on exactly one CI
	/// provider while appearing to skip on all of them.
	///
	/// Both variables are checked because neither is universal: `CI` is the convention
	/// most runners follow, and `GITHUB_ACTIONS` is the specific guarantee where this
	/// project's CI runs. Absence of both is the closest thing to "this is a developer's
	/// machine" the environment offers.
	///
	/// Reach for this only when a test genuinely cannot be made deterministic. It is not
	/// a place to put a flaky test: a timing assertion that fails on a contended runner
	/// will fail on a contended runner too, and moving it out of CI only moves where the
	/// failure is noticed. `ModelProfilerTests` carried this trait until its measured
	/// durations became injectable, at which point the test needed no trait at all.
	///
	/// For a timing assertion specifically, reach for ``benchmarkOnly`` instead — this
	/// trait skips where `CI` is set and *runs* on a developer's machine, which is where
	/// the parallel quality-gate run happens and therefore where a wall-clock bound is
	/// most likely to be exceeded. It guards the calm environment and leaves the loud one
	/// unguarded. It has no call sites for that reason; it is kept for the case it was
	/// written for, a test that genuinely cannot be deterministic and is not about time.
	public static var localOnly: Self {
		.enabled(
			if: ProcessInfo.processInfo.environment["CI"] == nil
				&& ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == nil,
			"Skipped in CI: this test depends on the machine it runs on"
		)
	}

	/// Runs the test only when parallel hardware has been opted into explicitly.
	public static var requiresParallelHardware: Self {
		.enabled(if: ProcessInfo.processInfo.environment["RUN_PARALLEL_TESTS"] == "1", "Skipped in CI: set RUN_PARALLEL_TESTS=1 to enable")
	}

	/// Runs the test only when benchmarks have been asked for explicitly.
	///
	/// For a test whose entire result *is* a wall-clock number — no correctness statement
	/// underneath it that survives removing the timer. Such a test cannot be made
	/// deterministic, because determinism would delete the thing it measures. The honest
	/// treatment is to stop running it by accident and keep it runnable on purpose.
	///
	/// Prefer this over ``localOnly`` for anything timed. `localOnly` skips where `CI` is
	/// set, which is precisely where nobody is watching; the routine local quality-gate
	/// run — parallel test execution, load average in the dozens — is both the harshest
	/// environment these assertions ever see and the one `localOnly` leaves them exposed
	/// to. A trait that skips a timing test everywhere except the machine most likely to
	/// fail it is protection pointed the wrong way.
	///
	/// The condition matches the five suite-level gates already spelled inline
	/// (`DDMPerformanceTests`, `PerformanceBenchmarkTests`, `SparsePerformanceBenchmark`,
	/// `ParallelOptimizerTests`, `MultivariateOptimizerPerformanceTests`), including the
	/// `!= nil` rather than `== "1"`: `RUN_BENCHMARKS=0` reads as a request for
	/// benchmarks everywhere else in this repo, and one member of the set disagreeing
	/// about that would be worse than the looser check.
	public static var benchmarkOnly: Self {
		.enabled(
			if: ProcessInfo.processInfo.environment["RUN_BENCHMARKS"] != nil,
			"Set RUN_BENCHMARKS=1 to enable. This test asserts only elapsed time."
		)
	}
}
