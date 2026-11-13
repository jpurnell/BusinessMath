//
//  SpearmanDistributionTests.swift
//  BusinessMath
//
//  The exact null distribution of Spearman's rho against brute-force enumeration of every
//  permutation, with and without ties, and its contract: moments, validation, the degenerate
//  judge, and the resource guard. Values from outside the package are in
//  SpearmanReferenceTests.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Spearman's rho: exact null distribution")
struct SpearmanDistributionTests {

    // MARK: - Brute force

    /// Every permutation of `values`, duplicates included (Heap's algorithm, iterative).
    static func permutations(_ values: [Double]) -> [[Double]] {
        var a: [Double] = values
        var c: [Int] = Array(repeating: 0, count: a.count)
        var out: [[Double]] = [a]
        var i: Int = 0
        while i < a.count {
            if c[i] < i {
                if i % 2 == 0 { a.swapAt(0, i) } else { a.swapAt(c[i], i) }
                out.append(a)
                c[i] += 1
                i = 0
            } else {
                c[i] = 0
                i += 1
            }
        }
        return out
    }

    /// Averaged ranks 1…n, ties given the mean of the places they span.
    static func averagedRanks(_ values: [Double]) -> [Double] {
        let order: [Int] = values.indices.sorted { values[$0] < values[$1] }
        var ranks: [Double] = Array(repeating: 0, count: values.count)
        var start: Int = 0
        while start < order.count {
            var end: Int = start + 1
            while end < order.count && values[order[end]] == values[order[start]] { end += 1 }
            let average: Double = Double(start + end + 1) / 2
            for k in start..<end { ranks[order[k]] = average }
            start = end
        }
        return ranks
    }

    /// The distribution of S = Σd² over all n! permutations of y's ranks against x's, as
    /// probabilities keyed by 4S (an integer for averaged ranks). Counted, then divided once.
    static func bruteForce(_ x: [Double], _ y: [Double]) -> [Int: Double] {
        let rx: [Double] = averagedRanks(x)
        let ry: [Double] = averagedRanks(y)
        var counts: [Int: Int] = [:]
        let all = permutations(ry)
        for perm in all {
            var fourS: Double = 0
            for i in rx.indices {
                let d: Double = rx[i] - perm[i]
                fourS += 4 * d * d
            }
            counts[Int(fourS), default: 0] += 1
        }
        return counts.mapValues { Double($0) / Double(all.count) }
    }

    static let panels: [(String, [Double], [Double])] = [
        ("untied n = 3", [1, 2, 3], [3, 1, 2]),
        ("untied n = 5", [1, 2, 3, 4, 5], [2, 1, 4, 5, 3]),
        ("untied n = 7", [1, 2, 3, 4, 5, 6, 7], [7, 1, 3, 2, 5, 4, 6]),
        ("untied n = 8", [1, 2, 3, 4, 5, 6, 7, 8], [2, 8, 1, 3, 7, 4, 6, 5]),
        ("y one tied pair", [1, 2, 3, 4], [1, 2, 2, 4]),
        ("ties in both", [1, 1, 3, 4, 5], [1, 2, 2, 2, 5]),
        ("y two values", [1, 2, 3, 4, 5, 6], [0, 0, 0, 1, 1, 1]),
        ("scores 1-4 against scores", [3, 1, 4, 1, 5, 9, 2], [2, 4, 1, 3, 3, 2, 4]),
        ("scores 1-5 both, n = 8", [1, 2, 2, 3, 4, 4, 5, 5], [2, 1, 3, 3, 5, 4, 4, 1]),
    ]

    @Test("The pmf over Σd² matches brute force over every permutation, tied and untied",
          arguments: panels.indices)
    func matchesBruteForce(_ index: Int) throws {
        let (name, x, y) = Self.panels[index]
        let expected: [Int: Double] = Self.bruteForce(x, y)
        let distribution: SpearmanDistribution<Double> = try spearmanDistribution(x, vs: y)
        #expect(distribution.items == x.count)
        #expect(distribution.sumsOfSquaredDifferences.count == expected.count, "\(name)")
        #expect(distribution.probabilities.count == distribution.rhoValues.count)
        var seen: Set<Int> = []
        for (s, p) in zip(distribution.sumsOfSquaredDifferences, distribution.probabilities) {
            let key: Int = Int(4 * s)
            #expect(Double(key).isEqual(to: 4 * s), "\(name): 4S is an integer")
            seen.insert(key)
            let want: Double = expected[key] ?? -1
            #expect(abs(p - want) < 1e-15, "\(name): S = \(s), brute force \(want), this \(p)")
        }
        #expect(seen == Set(expected.keys), "\(name)")
    }

    // MARK: - Shape

    @Test("rho ascends, S descends, and the probabilities sum to one")
    func ordering() throws {
        for (name, x, y) in Self.panels {
            let d: SpearmanDistribution<Double> = try spearmanDistribution(x, vs: y)
            for i in 1..<d.rhoValues.count {
                #expect(d.rhoValues[i] > d.rhoValues[i - 1], "\(name)")
                #expect(d.sumsOfSquaredDifferences[i] < d.sumsOfSquaredDifferences[i - 1], "\(name)")
            }
            let total: Double = d.probabilities.reduce(0, +)
            #expect(abs(total - 1) < 1e-14, "\(name)")
            #expect(d.probabilities.allSatisfy { $0 > 0 }, "\(name): attainable values only")
        }
    }

    /// Under permutation the correlation of two fixed, non-constant vectors has mean 0 and
    /// variance exactly 1/(n − 1), ties or not: a closed form independent of the method.
    @Test("Mean 0 and variance 1/(n − 1), tied and untied")
    func moments() throws {
        for (name, x, y) in Self.panels {
            let d: SpearmanDistribution<Double> = try spearmanDistribution(x, vs: y)
            var mean: Double = 0
            var second: Double = 0
            for (r, p) in zip(d.rhoValues, d.probabilities) {
                mean += r * p
                second += r * r * p
            }
            #expect(abs(mean) < 1e-14, "\(name)")
            #expect(abs(second - 1 / Double(x.count - 1)) < 1e-13, "\(name)")
        }
    }

    @Test("Untied: the distribution is symmetric, rho = 1 − 6S/(n³ − n), and items: matches data")
    func untiedSymmetry() throws {
        for n in 2...11 {
            let d: SpearmanDistribution<Double> = try spearmanDistribution(items: n)
            let row: [Double] = (1...n).map(Double.init)
            let fromData: SpearmanDistribution<Double> = try spearmanDistribution(row, vs: row.reversed())
            #expect(d.rhoValues == fromData.rhoValues, "n = \(n)")
            #expect(d.probabilities == fromData.probabilities, "n = \(n)")
            #expect(!d.hasTies)
            let cube: Double = Double(n * n * n - n)
            for i in d.rhoValues.indices {
                let mirror: Int = d.rhoValues.count - 1 - i
                #expect(abs(d.rhoValues[i] + d.rhoValues[mirror]) < 1e-14, "n = \(n)")
                #expect(d.probabilities[i] == d.probabilities[mirror], "n = \(n)")
                let s: Double = d.sumsOfSquaredDifferences[i]
                #expect(abs(d.rhoValues[i] - (1 - 6 * s / cube)) < 1e-14, "n = \(n)")
            }
        }
    }

    /// n = 4: P(rho = 1) = 1/24. n = 5: P(rho = 1) = 1/120 and P(rho = 0.9) = 4/120 (the four
    /// adjacent swaps). n = 2: rho = ±1, each with probability ½.
    @Test("Small n by hand")
    func smallByHand() throws {
        let four: SpearmanDistribution<Double> = try spearmanDistribution(items: 4)
        #expect(four.rhoValues.last == 1)
        #expect(four.probabilities.last?.isEqual(to: 1.0 / 24) == true)
        let five: SpearmanDistribution<Double> = try spearmanDistribution(items: 5)
        #expect(five.probability(atLeast: 1).isEqual(to: 1.0 / 120))
        #expect(abs(five.probability(atLeast: 0.9) - 5.0 / 120) < 1e-16)
        let two: SpearmanDistribution<Double> = try spearmanDistribution(items: 2)
        #expect(two.rhoValues == [-1, 1])
        #expect(two.probabilities.elementsEqual([0.5, 0.5]) { $0.isEqual(to: $1) })
    }

    /// A rho computed elsewhere carries rounding; a value within a quarter lattice step of an
    /// attainable rho is that rho.
    @Test("Tail queries take a computed rho as the attainable value it rounds from")
    func tailsSnapToLattice() throws {
        let x: [Double] = [1, 2, 3, 4, 5, 6, 7]
        let y: [Double] = [2, 1, 4, 3, 6, 5, 7]
        let rho: Double = try spearmansRho(x, vs: y)
        let d: SpearmanDistribution<Double> = try spearmanDistribution(items: 7)
        let exact: Double = d.probability(atLeast: rho)
        #expect(d.probability(atLeast: rho.nextUp).isEqual(to: exact))
        #expect(d.probability(atLeast: rho.nextDown).isEqual(to: exact))
        #expect(d.probability(atMost: 1) == 1)
        #expect(d.probability(atMost: -1.5) == 0)
        #expect(d.probability(atLeast: 1.5) == 0)
        #expect(d.probability(atMost: .nan).isNaN)
    }

    // MARK: - Degenerate and invalid input

    /// A judge who tied everything has no ranking to correlate: rho is 0/0. The distribution
    /// says so; it does not pretend to be a point mass at zero agreement.
    @Test("A judge who tied everything: degenerate, no rho values")
    func degenerate() throws {
        let d: SpearmanDistribution<Double> = try spearmanDistribution([1, 2, 3, 4, 5], vs: [3, 3, 3, 3, 3])
        #expect(d.isDegenerate)
        #expect(d.rhoValues.isEmpty)
        #expect(d.probabilities.isEmpty)
        #expect(d.pValue(rho: 0) == nil)
        let both: SpearmanDistribution<Double> = try spearmanDistribution([2, 2, 2], vs: [3, 3, 3])
        #expect(both.isDegenerate)
    }

    @Test("Invalid input is refused")
    func refusesInvalid() {
        #expect(throws: BusinessMathError.self) { _ = try spearmanDistribution([1.0], vs: [1.0]) }
        #expect(throws: BusinessMathError.self) { _ = try spearmanDistribution([Double](), vs: []) }
        #expect(throws: BusinessMathError.self) { _ = try spearmanDistribution([1.0, 2, 3], vs: [1, 2]) }
        #expect(throws: BusinessMathError.self) { _ = try spearmanDistribution([1.0, .nan, 3], vs: [1, 2, 3]) }
        #expect(throws: BusinessMathError.self) { _ = try spearmanDistribution([1.0, 2, 3], vs: [1, .infinity, 3]) }
        #expect(throws: BusinessMathError.self) { _ = try spearmanDistribution(items: 1) as SpearmanDistribution<Double> }
    }

    /// The exact method's state space grows as 2ⁿ without ties. It refuses before allocating
    /// rather than exhausting memory.
    @Test("A panel too large to count exactly is refused with resourceExhausted")
    func refusesTooLarge() {
        let error = #expect(throws: BusinessMathError.self) {
            let _: SpearmanDistribution<Double> = try spearmanDistribution(items: 60)
        }
        var exhausted: Bool = false
        if case .resourceExhausted? = error { exhausted = true }
        #expect(exhausted, "expected resourceExhausted, got \(String(describing: error))")
    }

    /// Ties shrink the state space: twenty-four wines scored 1–3 by one judge need only
    /// 9³ states, where the untied panel would need 2²⁴, so the panel is counted exactly.
    @Test("Heavily tied panels are exact past the untied limit")
    func tiedLargeIsExact() throws {
        let x: [Double] = (0..<24).map { Double($0 % 3) }
        let y: [Double] = (1...24).map(Double.init)
        #expect(throws: BusinessMathError.self) {
            _ = try spearmanDistribution(items: 24) as SpearmanDistribution<Double>
        }
        let d: SpearmanDistribution<Double> = try spearmanDistribution(x, vs: y)
        let total: Double = d.probabilities.reduce(0, +)
        #expect(abs(total - 1) < 1e-12)
        var mean: Double = 0
        var second: Double = 0
        for (r, p) in zip(d.rhoValues, d.probabilities) {
            mean += r * p
            second += r * r * p
        }
        #expect(abs(mean) < 1e-14)
        #expect(abs(second - 1.0 / 23) < 1e-13)
    }

    /// The counts do not depend on how many limbs hold them: the same panel counted in one,
    /// two and three limbs per count gives the same numbers.
    @Test("Multi-limb counts equal single-limb counts")
    func multiLimbAgrees() throws {
        let positions: [Int] = (1...9).map { 2 * $0 }
        let values: [DoubledRankGroup] = [DoubledRankGroup(doubledRank: 3, count: 2),
                                          DoubledRankGroup(doubledRank: 8, count: 3),
                                          DoubledRankGroup(doubledRank: 13, count: 1),
                                          DoubledRankGroup(doubledRank: 16, count: 3)]
        let one = try SpearmanExactCounts.make(positions: positions, values: values, scale: 1,
                                               limbBudget: 1 << 20, stateBudget: 1 << 20)
        for width in [2, 3] {
            let wide = try SpearmanExactCounts.make(positions: positions, values: values, scale: 1,
                                                    limbBudget: 1 << 20, stateBudget: 1 << 20,
                                                    minimumWidth: width)
            #expect(wide.width == width)
            #expect(wide.keys == one.keys)
            for index in 0..<one.entries {
                #expect(wide.count(index) == one.count(index) + Array(repeating: 0, count: width - 1))
            }
            #expect(wide.total == one.total + Array(repeating: 0, count: width - 1))
        }
        // 9!/(2!·3!·1!·3!) arrangements.
        #expect(one.total == [5040])
    }
}
