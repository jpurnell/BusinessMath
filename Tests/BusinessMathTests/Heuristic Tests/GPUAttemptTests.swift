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
