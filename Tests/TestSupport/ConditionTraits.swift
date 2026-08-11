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
	/// will fail on a contended laptop too, and moving it out of CI only moves where the
	/// failure is noticed. `ModelProfilerTests` carried this trait until its measured
	/// durations became injectable, at which point the test needed no trait at all.
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
}
