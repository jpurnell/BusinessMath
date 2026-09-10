//
//  GPUAttemptTests.swift
//  BusinessMath
//
//  The defect this guards against needed a Metal command queue to refuse a command
//  buffer under resource pressure — not something a test can summon on demand, which is
//  why it survived as an occasional red suite rather than a reproducible failure.
//
//  Testing the runner directly removes the GPU from the question entirely. A `body` that
//  draws from the generator and then fails reproduces the exact hazard in microseconds,
//  and would have caught the original bug in all three optimizers at once.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("GPU Attempt Seed Contract")
struct GPUAttemptTests {

	/// The failure that mattered: an attempt draws seeds, then fails, and the generator
	/// is left advanced. The CPU fallback resumes at a position no seed predicts.
	@Test("An abandoned attempt rewinds the generator")
	func abandonedAttemptRewinds() {
		let rng = RNGWrapper(generator: DeterministicRNG(seed: 4242))

		// What the stream yields if no attempt ever runs.
		let reference = RNGWrapper(generator: DeterministicRNG(seed: 4242))
		let expected = (0..<4).map { _ in reference.next() }

		let outcome: GPUAttemptOutcome<Int> = rng.attemptGPU(seeded: true) {
			// Draw as the kernels' seed loop does, then fail as the command-buffer
			// guard does.
			for _ in 0..<64 { _ = rng.next() }
			return nil
		}

		guard case .abandoned = outcome else {
			Issue.record("a body returning nil must abandon the attempt")
			return
		}

		let actual = (0..<4).map { _ in rng.next() }
		#expect(actual == expected, "64 abandoned draws must leave the stream where it started")
	}

	@Test("A throwing attempt rewinds and reports the error")
	func throwingAttemptRewinds() {
		struct Boom: Error {}
		let rng = RNGWrapper(generator: DeterministicRNG(seed: 99))

		let reference = RNGWrapper(generator: DeterministicRNG(seed: 99))
		let expected = (0..<4).map { _ in reference.next() }

		let outcome: GPUAttemptOutcome<Int> = rng.attemptGPU(seeded: true) {
			for _ in 0..<32 { _ = rng.next() }
			throw Boom()
		}

		guard case .abandoned(let abandonment) = outcome else {
			Issue.record("a throwing body must abandon the attempt")
			return
		}
		#expect(abandonment.underlying is Boom, "the underlying failure must reach the caller")

		let actual = (0..<4).map { _ in rng.next() }
		#expect(actual == expected, "a throwing attempt must rewind exactly as a nil one does")
	}

	/// A completed attempt must *not* rewind — its draws are the ones the kernels used,
	/// and rewinding them would make the next generation replay the same seeds.
	@Test("A completed attempt leaves the generator advanced")
	func completedAttemptDoesNotRewind() {
		let rng = RNGWrapper(generator: DeterministicRNG(seed: 7))

		let reference = RNGWrapper(generator: DeterministicRNG(seed: 7))
		for _ in 0..<16 { _ = reference.next() }
		let expected = (0..<4).map { _ in reference.next() }

		let outcome: GPUAttemptOutcome<Int> = rng.attemptGPU(seeded: true) {
			for _ in 0..<16 { _ = rng.next() }
			return 1
		}

		guard case .completed(let value) = outcome else {
			Issue.record("a body returning a value must complete")
			return
		}
		#expect(value == 1)

		let actual = (0..<4).map { _ in rng.next() }
		#expect(actual == expected, "a successful attempt keeps its draws")
	}

	// MARK: - The seed promise

	@Test("Abandoning a seeded run breaks the promise")
	func seededAbandonmentBreaksPromise() {
		let rng = RNGWrapper(generator: DeterministicRNG(seed: 1))
		let outcome: GPUAttemptOutcome<Int> = rng.attemptGPU(seeded: true) { nil }

		guard case .abandoned(let abandonment) = outcome else {
			Issue.record("expected abandonment")
			return
		}
		#expect(abandonment.seedPromiseBroken, "a seeded caller cannot accept a CPU answer")
	}

	@Test("Abandoning an unseeded run breaks no promise")
	func unseededAbandonmentIsFine() {
		let rng = RNGWrapper(generator: DeterministicRNG(seed: 1))
		let outcome: GPUAttemptOutcome<Int> = rng.attemptGPU(seeded: false) { nil }

		guard case .abandoned(let abandonment) = outcome else {
			Issue.record("expected abandonment")
			return
		}
		#expect(
			!abandonment.seedPromiseBroken,
			"an unseeded caller asked for resilience, not reproducibility"
		)
	}
}

/// Resolving an outcome is the half of the contract every optimizer shares.
///
/// ``GPUAttemptOutcome`` forces a call site to *notice* an abandonment; it does not say
/// what to do about one. `GeneticAlgorithm` wrote that answer inline, which is how the
/// rule failed to travel the first time — so this suite pins the resolution itself, once,
/// independently of any optimizer and of any GPU.
@Suite("GPU Attempt Resolution")
struct GPUAttemptResolutionTests {

	/// A failure that reports something recognisable, so the message assertions below test
	/// propagation rather than the spelling of a synthesised description.
	private struct QueueExhausted: Error, CustomStringConvertible {
		var description: String { "command queue exhausted" }
	}

	@Test("A completed outcome resolves to its value")
	func completedOutcomeResolvesToItsValue() throws {
		let outcome = GPUAttemptOutcome<Int>.completed(7)
		let resolved = try outcome.resultOrCPUFallback(operation: "test dispatch")

		#expect(resolved == 7, "a completed attempt is the answer, not a fallback")
	}

	@Test("An unseeded abandonment resolves to the CPU fallback")
	func unseededAbandonmentResolvesToCPU() throws {
		let abandonment = GPUAttemptAbandonment(seedPromiseBroken: false, underlying: QueueExhausted())
		let outcome = GPUAttemptOutcome<Int>.abandoned(abandonment)

		let resolved = try outcome.resultOrCPUFallback(operation: "test dispatch")

		#expect(resolved == nil, "an unseeded caller asked for resilience, so the CPU path is the right answer")
	}

	/// The whole point of the throwing signature: a seeded run gets a refusal instead of a
	/// different answer computed by a different implementation.
	@Test("A seeded abandonment refuses rather than falling back")
	func seededAbandonmentRefuses() {
		let abandonment = GPUAttemptAbandonment(seedPromiseBroken: true, underlying: QueueExhausted())
		let outcome = GPUAttemptOutcome<Int>.abandoned(abandonment)

		#expect(throws: OptimizationError.self) {
			try outcome.resultOrCPUFallback(operation: "test dispatch")
		}
	}

	/// A refusal a caller cannot act on is only marginally better than a wrong answer, so
	/// the message names both what was attempted and why it stopped.
	@Test("The refusal names the operation and the underlying failure")
	func refusalCarriesContext() {
		let abandonment = GPUAttemptAbandonment(seedPromiseBroken: true, underlying: QueueExhausted())
		let outcome = GPUAttemptOutcome<Int>.abandoned(abandonment)

		do {
			_ = try outcome.resultOrCPUFallback(operation: "GPU differential evolution generation")
			Issue.record("a seeded abandonment must not resolve to a value")
		} catch let error as OptimizationError {
			guard case .invalidInput(let message) = error else {
				Issue.record("expected invalidInput, got \(error)")
				return
			}
			#expect(message.contains("GPU differential evolution generation"), "the caller needs to know what was attempted")
			#expect(message.contains("command queue exhausted"), "the caller needs to know why it stopped")
		} catch {
			Issue.record("unexpected error: \(error)")
		}
	}

	/// A `nil` return carries no error, and the refusal still has to be a refusal.
	@Test("A seeded abandonment with no underlying error still refuses")
	func seededAbandonmentWithoutErrorRefuses() {
		let abandonment = GPUAttemptAbandonment(seedPromiseBroken: true, underlying: nil)
		let outcome = GPUAttemptOutcome<Int>.abandoned(abandonment)

		#expect(throws: OptimizationError.self) {
			try outcome.resultOrCPUFallback(operation: "test dispatch")
		}
	}
}
