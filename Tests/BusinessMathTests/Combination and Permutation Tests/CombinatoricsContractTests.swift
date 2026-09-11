//
//  CombinatoricsContractTests.swift
//  BusinessMath
//
//  What the combinatorics functions do at and beyond their domain.
//

import Testing
import TestSupport
@testable import BusinessMath

/// The edges of `factorial`, `combination` and `permutation`, pinned.
///
/// The review raised these as a conditional: *if* they are computed from factorials, then
/// `combination(30, c: 2)` and `permutation(25, p: 2)` trap or lose exactness, even though
/// the answers are 435 and 600.
///
/// They are not. `maxFactorialInt` is 20, and above it both functions switch to the
/// multiplicative form — `C(n,k) = Π(n−i)/Π(i+1)` — which reaches far beyond `20!`. So the
/// conditional does not hold, and the values are exact.
///
/// What was genuinely unpinned is the behaviour at the edges, and it splits two ways:
///
/// - **Outside the domain** — `k > n`, negative arguments — the unchecked functions return
///   `0` and the `…Checked` variants throw. Zero is a defensible answer for a count of
///   arrangements that cannot be made, and it is only defensible if it is deliberate.
/// - **Beyond `Int`** — `factorial(21)` — the multiplication traps. That is also deliberate:
///   `factorialChecked` exists precisely so a caller who cannot accept a trap has somewhere
///   to go. A trap is a contract like any other, and this suite states it rather than
///   leaving the next reader to find out in production.
@Suite("Combinatorics contract")
struct CombinatoricsContractTests {

	// MARK: - Beyond the factorial ceiling

	@Test("Values above the factorial ceiling are exact, not overflowed")
	func aboveTheCeilingIsExact() {
		// The two the review named. Both are past `maxFactorialInt`, so both take the
		// multiplicative path, and both are exactly right.
		#expect(combination(30, c: 2) == 435)
		#expect(permutation(25, p: 2) == 600)

		// Further out, where a factorial-based implementation could not go at all: 52! has
		// 68 digits and `Int` holds 19, yet C(52, 5) is a five-card poker hand.
		#expect(combination(52, c: 5) == 2_598_960)
		#expect(combination(49, c: 6) == 13_983_816)
	}

	@Test("Pascal's rule holds across the ceiling")
	func pascalsRuleHolds() {
		// C(n, k) = C(n−1, k−1) + C(n−1, k). A property rather than a table, and it
		// straddles `maxFactorialInt` so it exercises both branches and their agreement --
		// which a table of values on one side of the boundary would not.
		for n in 2...30 {
			for k in 1..<n {
				let whole: Int = combination(n, c: k)
				let left: Int = combination(n - 1, c: k - 1)
				let right: Int = combination(n - 1, c: k)
				#expect(whole == left + right,
						"C(\(n), \(k)) = \(whole), but C(\(n-1), \(k-1)) + C(\(n-1), \(k)) = \(left + right)")
			}
		}
	}

	@Test("Symmetry holds across the ceiling")
	func symmetryHolds() {
		for n in 0...30 {
			for k in 0...n {
				#expect(combination(n, c: k) == combination(n, c: n - k),
						"C(\(n), \(k)) != C(\(n), \(n - k))")
			}
		}
	}

	// MARK: - Outside the domain

	@Test("An arrangement that cannot be made counts zero")
	func outsideTheDomainIsZero() {
		#expect(combination(5, c: 6) == 0, "choosing 6 from 5")
		#expect(permutation(5, p: 6) == 0, "arranging 6 from 5")
		#expect(combination(-1, c: 0) == 0, "negative n")
		#expect(combination(5, c: -1) == 0, "negative k")
		#expect(permutation(-1, p: 0) == 0, "negative n")
		#expect(permutation(5, p: -1) == 0, "negative k")
		#expect(factorial(-1) == 0, "negative n")
	}

	@Test("The checked variants throw where the unchecked ones return zero")
	func checkedVariantsThrow() {
		// The pair is the point: zero is only a safe answer because a caller who needs the
		// distinction has `…Checked` to reach for.
		#expect(throws: BusinessMathError.self) { _ = try combinationChecked(-1, c: 0) }
		#expect(throws: BusinessMathError.self) { _ = try permutationChecked(-1, p: 0) }
		#expect(throws: BusinessMathError.self) { _ = try factorialChecked(-1) }
	}

	@Test("The identities at the boundary")
	func boundaryIdentities() {
		#expect(factorial(0) == 1, "0! is 1 by definition, not 0")
		#expect(factorial(1) == 1)
		#expect(combination(0, c: 0) == 1, "there is exactly one way to choose nothing")
		#expect(permutation(0, p: 0) == 1)
		#expect(combination(30, c: 0) == 1)
		#expect(combination(30, c: 30) == 1)
	}

	// MARK: - The ceiling itself

	@Test("The largest exact factorial is the documented one")
	func factorialCeiling() {
		// 20! = 2,432,902,008,176,640,000 fits in Int64; 21! does not.
		#expect(maxFactorialInt == 20)
		#expect(factorial(20) == 2_432_902_008_176_640_000)
		#expect(throws: BusinessMathError.self) { _ = try factorialChecked(21) }
	}

	// An exit test spawns a child process, which iOS, tvOS and watchOS do not permit.
	#if os(macOS) || os(Linux)
	/// The alternative to trapping is silently returning 21! reduced modulo 2⁶⁴, which is a
	/// plausible-looking `Int` that is the factorial of nothing. Trapping is the right call
	/// for a programmer error, and `factorialChecked` is the way out — asserted above.
	///
	/// **The discarded result is the point, not an accident.** This test failed in release
	/// from 2026-09-11 while passing in debug, because `factorial` relied on `Int` overflow
	/// to trap and an overflow check guards an arithmetic *result*: once the function is
	/// inlined and the result is unused, the optimiser may delete the multiply and the check
	/// together. Measured at the time — `_ = factorial(21)` exited 0 under `-O` with
	/// whole-module optimisation, while `let x = factorial(21)` trapped. `factorial` now
	/// states the bound as a `precondition`, which is an effect in its own right and survives
	/// that. Keep the result discarded here: it is the configuration that regressed.
	///
	/// The stderr assertion is what makes this catch a *removed* precondition in **debug** as
	/// well. Without it, deleting the precondition leaves `Int` overflow trapping in debug, the
	/// test passes there, and it goes red only in the release workflow — which runs on a
	/// schedule, so the signal arrives hours late and attached to whatever landed since.
	///
	/// **And reading stderr found a second thing, which is why the trait is here.** Under
	/// `--sanitize thread` the child aborts in sanitizer start-up — *"Interceptors are not
	/// working … ThreadSanitizer is loaded too late"* — because a re-launched child does not
	/// inherit the `DYLD_INSERT_LIBRARIES` that installs the interceptors. That abort is a
	/// non-zero exit, so `processExitsWith: .failure` was satisfied **by the sanitizer killing
	/// the child**, and this test passed under TSan for months having run none of the code it
	/// names. The stderr assertion is what surfaced it; ``Trait/requiresUnsanitizedRuntime``
	/// now skips rather than passes there.
	///
	/// It is gated to debug because the message does not exist anywhere else.
	/// `precondition(_:_:)` takes its message as `@autoclosure () -> String`; in `-Onone` that
	/// reaches `_assertionFailure`, which prints it, and in `-O` the whole call becomes
	/// `Builtin.condfail_message(error, "precondition failure")` — a fixed `StaticString` — so
	/// the caller's message is never evaluated. Measured: stderr is empty in a release run. The
	/// exit status is the assertion that carries release, and it is the one that regressed.
	@Test("factorial(21) traps rather than returning a wrapped value",
		  .requiresUnsanitizedRuntime)
	func factorialBeyondIntTraps() async {
		let result = await #expect(processExitsWith: .failure,
								   observing: [\.standardErrorContent]) {
			_ = factorial(21)
		}
		#if DEBUG
		let errorBytes = result?.standardErrorContent ?? []
		let message = String(decoding: errorBytes, as: UTF8.self)
		#expect(message.contains("factorialChecked"),
				"""
				The trap fired, but not from factorial's precondition — stderr never named \
				factorialChecked. Standard error was: \(message)
				""")
		#else
		// Nothing further to assert here: the exit status checked above is the whole of the
		// contract that release can observe, and a stand-in like `result != nil` would look
		// like an assertion while proving nothing. Discarded explicitly instead.
		_ = result
		#endif
	}
	#endif
}
