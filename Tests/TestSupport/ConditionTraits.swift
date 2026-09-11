//
//  ConditionTraits.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2/28/26.
//
import Testing
import Foundation
#if canImport(Metal)
import Metal
#endif

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
	///
	/// The message used to read "Skipped in CI", which it is not: the condition is the
	/// presence of an environment variable, so the test skips on a developer's machine
	/// exactly as it skips on a runner. Saying "in CI" told a reader that a local run would
	/// exercise it, which is the opposite of what happens and the reason a skip like this
	/// goes unnoticed for months.
	///
	/// `!= nil` rather than `== "1"`, matching ``benchmarkOnly``. Two opt-in gates in one
	/// file disagreeing about whether `RUN_PARALLEL_TESTS=0` is a request is worse than
	/// either convention on its own.
	public static var requiresParallelHardware: Self {
		.enabled(
			if: ProcessInfo.processInfo.environment["RUN_PARALLEL_TESTS"] != nil,
			"Set RUN_PARALLEL_TESTS=1 to enable. This test needs parallel hardware to mean anything."
		)
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

	/// Runs the test only where Metal can actually execute a kernel.
	///
	/// The GPU suites used to open each test with `guard let x = try helper() else { return }`,
	/// where `nil` meant "this machine has no GPU". That reports the test as **passed**.
	/// Swift Testing already has a way to say "did not run" — a condition trait, which
	/// reports **skipped** — and the difference is the whole point: a suite that silently
	/// passes on a machine without a GPU is indistinguishable from one that works, which is
	/// how `MonteCarloRNGTests` went a year without executing a single kernel.
	///
	/// The condition is device **and** compiler, not device alone, because those are two
	/// different absences and only one of them is benign. A machine with no `MTLDevice`
	/// cannot run these tests and should skip. A machine whose runtime MSL compiler rejects
	/// our shader source has found a real defect and must fail. Testing only for the device
	/// would report the second as the first — the exact confusion ``MonteCarloRNGTests``
	/// documents in its suite comment, where a kernel that could not compile was swallowed
	/// by `try?` and read as "no GPU on this machine".
	///
	/// A trivial kernel is the probe because it is the smallest thing that distinguishes
	/// them: if *it* fails to compile, nothing on this machine compiles, and the failure is
	/// not about our source. `try?` is deliberate there and is the one place it belongs —
	/// the thrown error is the answer being asked for, not an error being discarded.
	public static var requiresMetalGPU: Self {
		.enabled(
			if: MetalAvailability.canRunKernels,
			"No Metal device that compiles MSL on this machine: the GPU path cannot be exercised here"
		)
	}

	/// Runs the test only where an exit test can actually execute its closure.
	///
	/// `#expect(processExitsWith:)` re-launches the test executable as a child process. Under
	/// a sanitizer that child does **not** inherit the `DYLD_INSERT_LIBRARIES` entry that
	/// installs the runtime's interceptors, so it aborts during sanitizer start-up with
	/// *"Interceptors are not working. This may be because ThreadSanitizer is loaded too late"*
	/// — before reaching the closure body at all.
	///
	/// The reason this needs a trait rather than a tolerance is that the abort is still a
	/// non-zero exit, so `processExitsWith: .failure` is **satisfied by the sanitizer killing
	/// the child**. Every exit test in this package passed under `--sanitize thread` for that
	/// reason, having executed none of the code it names. That was only visible once
	/// ``CombinatoricsContractTests/factorialBeyondIntTraps()`` began reading the child's
	/// standard error and found a ThreadSanitizer diagnostic where a precondition message
	/// should have been.
	///
	/// Skipping is the honest outcome and passing is not, for the same reason
	/// ``Trait/requiresMetalGPU`` exists: a test that reports green without running is worse
	/// than no test, because it also discourages anyone from writing the real one.
	public static var requiresUnsanitizedRuntime: Self {
		.enabled(
			if: !SanitizerPresence.isThreadSanitizerLoaded,
			"Exit tests cannot run under ThreadSanitizer: the re-launched child aborts in sanitizer start-up before the closure runs"
		)
	}
}

/// Whether a sanitizer runtime is linked into this test binary.
///
/// Separated from the trait and cached in a `static let` so the probe runs once per process,
/// matching ``MetalAvailability``.
public enum SanitizerPresence {

	/// `true` when the ThreadSanitizer runtime is present.
	///
	/// Detected by looking for `__tsan_init` in the running image rather than by a compilation
	/// condition, because SwiftPM's `--sanitize thread` passes `-sanitize=thread` to the
	/// compiler and defines no Swift flag a test could read. Verified both ways: the symbol is
	/// absent from an ordinary build and present under `-sanitize=thread`.
	public static let isThreadSanitizerLoaded: Bool = {
		guard let handle = dlopen(nil, RTLD_NOW) else { return false }
		defer { dlclose(handle) }
		return dlsym(handle, "__tsan_init") != nil
	}()
}

/// Whether this machine can compile and run Metal kernels.
///
/// Backs ``Trait/requiresMetalGPU``. Separated from the trait so the probe runs **once per
/// process** rather than once per test: `static let` is lazily initialised and cached, and
/// the thirty-odd GPU tests that consult it would otherwise each pay a device lookup and a
/// shader compile.
public enum MetalAvailability {

	/// `true` where a Metal device exists, compiles MSL at runtime, and yields a command queue.
	///
	/// All three are required before a GPU test can assert anything, and each can be absent
	/// independently — a device with no command queue is as unusable as no device at all.
	/// Any of them missing means "skip", never "fail".
	public static let canRunKernels: Bool = {
		#if canImport(Metal)
		guard let device = MTLCreateSystemDefaultDevice() else { return false }
		let trivial = """
		#include <metal_stdlib>
		using namespace metal;
		kernel void trivial(device float* out [[buffer(0)]], uint tid [[thread_position_in_grid]]) {
		    out[tid] = 1.0f;
		}
		"""
		guard (try? device.makeLibrary(source: trivial, options: nil)) != nil else { return false }
		return device.makeCommandQueue() != nil
		#else
		return false
		#endif
	}()
}
