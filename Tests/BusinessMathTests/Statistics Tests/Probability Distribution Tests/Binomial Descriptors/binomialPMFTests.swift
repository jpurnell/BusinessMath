//
//  binomialPMFTests.swift
//  BusinessMathTests
//
//  Coverage for `binomialPMF`, including the p = 0 / p = 1 boundary where a degenerate
//  binomial puts all its mass on a single outcome. These boundaries exercise the
//  `(1 - p)^(n - k)` term at `pow(0, 0)`, which must evaluate to 1 (an empty product),
//  not NaN.
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Binomial PMF Tests")
struct BinomialPMFTests {

    @Test("Known interior values")
    func knownValues() {
        // C(10,3) · 0.5^10 = 120/1024
        #expect(abs(binomialPMF(n: 10, k: 3, p: 0.5) - 0.1171875) < 1e-12)
        // C(5,2) · 0.5^5 = 10/32
        #expect(abs(binomialPMF(n: 5, k: 2, p: 0.5) - 0.3125) < 1e-12)
    }

    @Test("Full PMF sums to 1")
    func sumsToOne() {
        let n = 12
        let p = 0.37
        let total = (0...n).reduce(0.0) { $0 + binomialPMF(n: n, k: $1, p: p) }
        #expect(abs(total - 1.0) < 1e-12)
    }

    @Test("p = 1 puts all mass on k = n")
    func pEqualsOne() {
        #expect(abs(binomialPMF(n: 10, k: 10, p: 1.0) - 1.0) < 1e-12)  // all successes
        #expect(abs(binomialPMF(n: 10, k: 3, p: 1.0) - 0.0) < 1e-12)   // impossible
    }

    @Test("p = 0 puts all mass on k = 0")
    func pEqualsZero() {
        #expect(abs(binomialPMF(n: 10, k: 0, p: 0.0) - 1.0) < 1e-12)   // no successes
        #expect(abs(binomialPMF(n: 10, k: 4, p: 0.0) - 0.0) < 1e-12)   // impossible
    }

    @Test("Out-of-range k is zero")
    func outOfRange() {
        #expect(binomialPMF(n: 10, k: -1, p: 0.5) == 0)
        #expect(binomialPMF(n: 10, k: 11, p: 0.5) == 0)
    }
}
