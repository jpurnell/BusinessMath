//
//  GPUAttempt.swift
//  BusinessMath
//
//  The seed contract for GPU-accelerated heuristics.
//
//  Three optimizers accelerate on Metal above a population threshold, and all three draw
//  one kernel seed per individual *before* the first operation that can fail. That makes
//  two distinct mistakes available at every failure site, and the codebase made both:
//
//  1. Abandoning the attempt without rewinding leaves the generator advanced by one draw
//     per individual, so the CPU fallback resumes where no seed predicts.
//
//  2. Rewinding and then running the CPU anyway fixes the stream and returns a different
//     answer, because the kernels compute in Float where the CPU computes in Double. This
//     is the harder one to see: the run is now seed-*consistent*, agreeing on every draw
//     while disagreeing on the result, so nothing about the symptom points at seeding.
//
//  The rule against both was written once, as a comment, inside the `catch` branch of one
//  optimizer. The `nil` return in the same function did not inherit it, and the two
//  sibling optimizers never received any part of it. This file exists so that the rule
//  lives in a type instead, where a call site cannot decline to implement it.
//

import Foundation

// MARK: - Outcome

/// Why a GPU attempt was abandoned, and what that costs the caller.
internal struct GPUAttemptAbandonment {

	/// Whether abandoning breaks a promise the caller was given.
	///
	/// True when a seed was configured. The CPU fallback computes in `Double` where the
	/// kernels compute in `Float`, so it cannot reproduce the GPU's answer; running it
	/// under a seed that promises reproducibility answers a question nobody asked.
	///
	/// False for an unseeded run, where falling back is not only acceptable but wanted —
	/// resilience is worth more than a guarantee nobody requested.
	internal let seedPromiseBroken: Bool

	/// The underlying failure, when the attempt threw rather than returning `nil`.
	internal let underlying: (any Error)?
}

/// The result of a GPU attempt that may have drawn from the optimizer's generator.
///
/// There is deliberately no case meaning "abandoned, and you may ignore that". A caller
/// must `switch`, which is the whole mechanism: the previous shape returned `nil` for
/// both "the GPU does not apply here" and "the GPU failed after consuming randomness",
/// and every site that conflated them was wrong in the same way.
internal enum GPUAttemptOutcome<Success> {

	/// The GPU produced a result. The generator is left where the attempt advanced it.
	case completed(Success)

	/// The attempt was abandoned and the generator has been rewound to where it stood
	/// before the attempt began.
	case abandoned(GPUAttemptAbandonment)
}

// MARK: - Runner

extension RNGWrapper {

	/// Runs a GPU attempt that draws from this generator, rewinding it if abandoned.
	///
	/// Everything inside `body` is treated as having possibly consumed randomness, so
	/// **applicability checks must happen before this call**. Device availability, vector
	/// type, and the population threshold are not failures — they are reasons not to
	/// attempt at all, and routing them through here would relabel a normal CPU run as a
	/// broken seed promise.
	///
	/// - Parameters:
	///   - seeded: Whether the caller configured a seed. Determines whether abandoning
	///     the attempt breaks a promise or is merely a fallback.
	///   - body: The GPU attempt. Returning `nil` and throwing both abandon it; the two
	///     differ only in whether an error is available to report.
	/// - Returns: The result, or an abandonment whose generator has already been rewound.
	internal func attemptGPU<Success>(
		seeded: Bool,
		_ body: () throws -> Success?
	) -> GPUAttemptOutcome<Success> {
		let checkpoint = snapshot()

		func abandon(_ error: (any Error)?) -> GPUAttemptOutcome<Success> {
			restore(checkpoint)
			return .abandoned(GPUAttemptAbandonment(seedPromiseBroken: seeded, underlying: error))
		}

		// `Result` rather than do/catch: the error is not handled here, it is *carried* to
		// the caller in `GPUAttemptAbandonment.underlying`, and a catch block that neither
		// logs nor rethrows reads like one that swallowed it.
		switch Result(catching: body) {
		case .success(let value):
			guard let value else {
				return abandon(nil)
			}
			return .completed(value)

		case .failure(let error):
			return abandon(error)
		}
	}
}
