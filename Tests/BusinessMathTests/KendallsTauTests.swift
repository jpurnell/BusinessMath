import Testing
import Foundation
@testable import BusinessMath

/// Kendall's tau-b.
///
/// ## Why tau-b rather than tau-a
///
/// Tau-a divides by every pair, so a variable with ties can never reach 1 however perfectly
/// the two agree. Tau-b removes tied pairs from the denominator separately for each variable,
/// which is what makes it the form reported in practice — and what makes it easy to get
/// wrong, since the correction is two different sums that are not interchangeable.
///
/// ## Every expected value here is computed from the definition
///
/// `τ_b = (C − D) / √((n₀ − n₁)(n₀ − n₂))`, with `n₀` every pair, `n₁` the pairs tied in `x`
/// and `n₂` the pairs tied in `y`. The tie cases below are small enough to enumerate by hand
/// and the enumeration is written into the comment, so a reader can check the expected number
/// without trusting either the implementation or a recalled reference value.
@Suite("Kendall's tau-b")
struct KendallsTauTests {

    // MARK: - No ties

    @Test("Perfect agreement is one")
    func perfectConcordance() throws {
        let x: [Double] = [1, 2, 3, 4, 5]
        #expect(try kendallsTau(x, vs: x) == 1)
    }

    @Test("Perfect disagreement is minus one")
    func perfectDiscordance() throws {
        let x: [Double] = [1, 2, 3, 4, 5]
        let y: [Double] = [5, 4, 3, 2, 1]
        #expect(try kendallsTau(x, vs: y) == -1)
    }

    /// `x = [1,2,3]`, `y = [1,3,2]`. Pairs: (1,2) concordant, (1,3) concordant,
    /// (2,3) discordant. So `C − D = 1`, `n₀ = 3`, and τ = 1/3.
    @Test("One swap out of three pairs")
    func oneDiscordantPair() throws {
        let tau = try kendallsTau([1, 2, 3], vs: [1, 3, 2])
        #expect(abs(tau - 1.0 / 3.0) < 1e-12)
    }

    /// Reversing one argument reverses the sign, whatever the data.
    @Test("Reversing one side negates the answer")
    func reversalNegates() throws {
        let x: [Double] = [3, 1, 4, 1, 5, 9, 2, 6]
        let y: [Double] = [2, 7, 1, 8, 2, 8, 1, 8]
        let forward = try kendallsTau(x, vs: y)
        let backward = try kendallsTau(x, vs: y.map { -$0 })
        #expect(abs(forward + backward) < 1e-12)
    }

    /// Symmetric in its arguments.
    @Test("The order of the arguments does not matter")
    func symmetry() throws {
        let x: [Double] = [3, 1, 4, 1, 5, 9, 2, 6]
        let y: [Double] = [2, 7, 1, 8, 2, 8, 1, 8]
        #expect(abs(try kendallsTau(x, vs: y) - (try kendallsTau(y, vs: x))) < 1e-12)
    }

    // MARK: - Ties, which is the whole reason for tau-b

    /// `x = [1,1,2]`, `y = [1,2,3]`.
    ///
    /// Pairs: (0,1) tied in `x` — neither concordant nor discordant; (0,2) concordant;
    /// (1,2) concordant. So `C − D = 2`, `n₀ = 3`, `n₁ = 1` (one tied pair in `x`),
    /// `n₂ = 0`, and τ_b = 2 / √(2·3) = 0.816496…
    @Test("A tie in one variable, enumerated by hand")
    func oneTieInX() throws {
        let tau = try kendallsTau([1, 1, 2], vs: [1, 2, 3])
        #expect(abs(tau - 2 / (6.0).squareRoot()) < 1e-12)
    }

    /// **Tau-b reaches one where tau-a cannot.**
    ///
    /// `x = [1,1,2,2]` against `y = [1,1,2,2]`: the two agree perfectly, and four of the six
    /// pairs are tied in both. Tau-a would answer 2/6 = 0.333 because it divides by every
    /// pair. Tau-b removes the tied pairs from each side's denominator and answers 1, which is
    /// the difference between the two definitions in a single case.
    @Test("Tau-b reaches one on tied but perfectly agreeing data")
    func tiesDoNotCapTheCoefficient() throws {
        let x: [Double] = [1, 1, 2, 2]
        #expect(abs(try kendallsTau(x, vs: x) - 1) < 1e-12)
    }

    /// Ties in **both** variables are removed from both denominators, and the pairs tied in
    /// both must not be double-counted.
    ///
    /// `x = [1,1,2,3]`, `y = [1,2,2,3]`. Pairs and their state:
    ///
    /// | pair | x | y | |
    /// |---|---|---|---|
    /// | (0,1) | 1,1 **tied** | 1,2 | counts toward `n₁` only |
    /// | (0,2) | 1,2 | 1,2 | concordant |
    /// | (0,3) | 1,3 | 1,3 | concordant |
    /// | (1,2) | 1,2 | 2,2 **tied** | counts toward `n₂` only |
    /// | (1,3) | 1,3 | 2,3 | concordant |
    /// | (2,3) | 2,3 | 2,3 | concordant |
    ///
    /// So `C − D = 4`, `n₀ = 6`, `n₁ = 1`, `n₂ = 1`, and τ_b = 4 / √(5·5) = **0.8**.
    ///
    /// The first version of this comment called (1,2) concordant and expected 1. It is tied
    /// in `y`, and a pair tied in either variable is neither concordant nor discordant — the
    /// one rule tau-b turns on. The enumeration is laid out as a table now because prose was
    /// evidently not enough to get six pairs right.
    @Test("Ties in both variables")
    func tiesInBoth() throws {
        let tau = try kendallsTau([1, 1, 2, 3], vs: [1, 2, 2, 3])
        #expect(abs(tau - 0.8) < 1e-12)
    }

    /// A variable with no variation has no correlation to report.
    ///
    /// Every pair is tied, so the denominator is zero — and zero is not the answer, because
    /// zero would claim the two are uncorrelated when nothing was measured at all.
    @Test("A constant variable is refused")
    func aConstantIsRefused() {
        #expect(throws: BusinessMathError.self) {
            try kendallsTau([1, 1, 1, 1], vs: [1, 2, 3, 4])
        }
    }

    // MARK: - Shape

    @Test("Mismatched lengths are refused")
    func mismatchedLengths() {
        #expect(throws: BusinessMathError.self) {
            try kendallsTau([1, 2, 3], vs: [1, 2])
        }
    }

    @Test("Fewer than two observations is refused")
    func tooFewObservations() {
        #expect(throws: BusinessMathError.self) {
            try kendallsTau([1], vs: [1])
        }
    }

    // MARK: - Agreement with the definition, at scale

    /// **The O(n log n) form against the O(n²) definition.**
    ///
    /// The implementation counts inversions by merge sort because a pairwise count is
    /// quadratic and a simulation run is ten thousand trials. This checks the fast form
    /// against the slow one on data with heavy ties, which is where the two would diverge if
    /// the tie corrections were wrong — a clean dataset would agree under either.
    @Test("The fast form agrees with the definition, including under ties")
    func agreesWithTheQuadraticDefinition() throws {
        var seed: UInt64 = 0x5EED
        func next(_ bound: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int((seed >> 33) % UInt64(bound))
        }
        for _ in 0..<40 {
            let count = 60
            // Few distinct values, so ties are the common case rather than an edge one.
            let x = (0..<count).map { _ in Double(next(5)) }
            let y = (0..<count).map { _ in Double(next(5)) }
            guard let expected = quadraticTau(x, y) else { continue }
            let actual = try kendallsTau(x, vs: y)
            #expect(abs(actual - expected) < 1e-12,
                    "fast \(actual) against definition \(expected)")
        }
    }

    /// Tau-b straight from the definition, every pair enumerated. Test-only, and slow.
    private func quadraticTau(_ x: [Double], _ y: [Double]) -> Double? {
        var concordant = 0, discordant = 0, tiedX = 0, tiedY = 0
        for i in 0..<x.count {
            for j in (i + 1)..<x.count {
                let dx = x[i] - x[j], dy = y[i] - y[j]
                if dx == 0 && dy == 0 { tiedX += 1; tiedY += 1 }
                else if dx == 0 { tiedX += 1 }
                else if dy == 0 { tiedY += 1 }
                else if dx * dy > 0 { concordant += 1 }
                else { discordant += 1 }
            }
        }
        let total = x.count * (x.count - 1) / 2
        let denominator = (Double(total - tiedX) * Double(total - tiedY)).squareRoot()
        guard denominator > 0 else { return nil }
        return Double(concordant - discordant) / denominator
    }
	// MARK: - An external reference

	/// Values from SciPy 1.17.1 `kendalltau(x, y, variant='b')`.
	///
	/// The suite's other assertions check the `n log n` form against the quadratic definition,
	/// which is the right oracle for *that* question — it is the only way to catch a wrong
	/// inversion count or a mishandled tie correction. But both forms are this package's own
	/// reading of tau-b, so agreeing with each other says nothing about whether the reading is
	/// the standard one. Only something outside the package can say that.
	///
	/// The cases are chosen where the two conventions could differ: ties in one variable, ties in
	/// both, and a variable that is nearly constant. Clean data agrees under any convention and
	/// would prove nothing.
	///
	/// Note `perfect` and `reversed`: SciPy returns `±0.9999999999999999` where this returns
	/// exactly `±1`, because it forms the denominator as a product of square roots where this
	/// takes the square root of the product. Ours is the closer of the two to the exact answer,
	/// so the comparison is made at 1e-12 rather than by equality.
	/// One SciPy case: the two variables and the value SciPy reports.
	///
	/// A named type rather than a tuple, and hoisted out of the `@Test` macro, because eight
	/// four-element tuples of mixed integer and floating-point literals inside `arguments:`
	/// defeated the type checker outright — "unable to type-check this expression in reasonable
	/// time", on the *local* compiler. The macro expands its argument into generic closures with
	/// far less to anchor on than the source line suggests, so a literal array that is fine as a
	/// plain `let` is not fine there.
	struct SciPyCase: Sendable {
		let name: String
		let x: [Double]
		let y: [Double]
		let reference: Double
	}

	static let sciPyCases: [SciPyCase] = [
		SciPyCase(name: "perfect", x: [1, 2, 3, 4, 5], y: [1, 2, 3, 4, 5],
				  reference: 0.9999999999999999),
		SciPyCase(name: "reversed", x: [1, 2, 3, 4, 5], y: [5, 4, 3, 2, 1],
				  reference: -0.9999999999999999),
		SciPyCase(name: "one crossing", x: [1, 2, 3, 4, 5], y: [1, 3, 2, 5, 4],
				  reference: 0.6),
		SciPyCase(name: "tied in x only", x: [1, 1, 2, 2], y: [1, 2, 3, 4],
				  reference: 0.8164965809277261),
		SciPyCase(name: "tied in both, identical", x: [1, 1, 2, 2], y: [1, 1, 2, 2],
				  reference: 1.0),
		SciPyCase(name: "ties throughout", x: [1, 1, 1, 2, 2, 3], y: [1, 2, 2, 2, 3, 3],
				  reference: 0.7272727272727273),
		SciPyCase(name: "y nearly constant", x: [1, 2, 3, 4, 5, 6], y: [1, 1, 1, 1, 1, 2],
				  reference: 0.5773502691896257),
		SciPyCase(name: "binary against binary", x: [0, 0, 1, 1, 1, 0], y: [0, 1, 1, 1, 0, 0],
				  reference: 0.3333333333333333)
	]

	@Test("Tau-b matches SciPy on tie-heavy data", arguments: KendallsTauTests.sciPyCases)
	func matchesSciPy(testCase: SciPyCase) throws {
		let tau = try kendallsTau(testCase.x, vs: testCase.y)
		let gap = abs(tau - testCase.reference)
		#expect(gap < 1e-12,
				"\(testCase.name): SciPy gives \(testCase.reference), this gives \(tau)")
	}
}
