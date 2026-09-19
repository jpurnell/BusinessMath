import Foundation
import Numerics

/// Kendall's tau-b — rank correlation by counting concordant and discordant pairs.
///
/// Two observations are **concordant** when both variables move the same way between them
/// and **discordant** when they move opposite ways. Tau is the balance of the two, scaled to
/// `[-1, 1]`. Unlike Pearson's correlation it assumes nothing about the shape of either
/// variable; unlike ``spearmansRho(_:vs:)`` it counts pairs rather than differencing ranks,
/// which makes it less sensitive to a single badly-placed observation.
///
/// ## Tau-b, and why the distinction matters
///
/// Tau-**a** divides by every pair. A variable with ties therefore cannot reach 1 however
/// perfectly the two agree: `[1,1,2,2]` against itself answers 0.333, because four of its six
/// pairs are tied and tau-a counts them against the total anyway.
///
/// Tau-**b** removes the tied pairs from the denominator, **separately for each variable**:
///
/// ```
/// τ_b = (C − D) / √((n₀ − n₁)(n₀ − n₂))
/// ```
///
/// where `n₀` is every pair, `n₁` the pairs tied in `x` and `n₂` the pairs tied in `y`. The
/// two sums are not interchangeable and the pairs tied in *both* belong to each, which is the
/// part that is easy to get wrong — and why the tests enumerate their small cases by hand
/// rather than quoting a reference value.
///
/// ## `n log n`, not `n²`
///
/// The definition is a double loop over pairs. That is quadratic, and the caller this was
/// written for — a Monte Carlo run's trial values — routinely has ten thousand of them, where
/// a pairwise count is fifty million comparisons per statistic.
///
/// Knight's method gets the same number in `n log n`: sort by `x`, then count the
/// **inversions** in `y` by merge sort. An inversion is precisely a discordant pair, so
/// `C − D = n₀ − n₁ − n₂ + n₃ − 2·inversions`, with `n₃` the pairs tied in both. The tests
/// check this form against the quadratic definition on tie-heavy data, which is where the two
/// would part company if the corrections were wrong.
///
/// - Parameters:
///   - independent: One variable.
///   - variable: The other, paired with the first by position.
/// - Returns: Tau-b, in `[-1, 1]`.
/// - Throws: ``BusinessMathError/mismatchedDimensions(message:expected:actual:)`` if the two
///   differ in length, ``BusinessMathError/insufficientData(required:actual:context:)`` for
///   fewer than two observations, and
///   ``BusinessMathError/divisionByZero(context:)`` when either variable is constant — where
///   every pair is tied, the denominator is zero, and zero is not the answer, because zero
///   would report the two as uncorrelated when nothing was measured at all.
///
/// - Example:
///   ```swift
///   let x: [Double] = [1, 2, 3, 4, 5]
///   let y: [Double] = [1, 3, 2, 5, 4]
///   let tau = try kendallsTau(x, vs: y)   // 0.6
///   ```
public func kendallsTau<T: Real>(_ independent: [T], vs variable: [T]) throws -> T {
    guard independent.count == variable.count else {
        throw BusinessMathError.mismatchedDimensions(
            message: "Kendall's tau pairs observations by position",
            expected: "\(independent.count)", actual: "\(variable.count)")
    }
    guard independent.count >= 2 else {
        throw BusinessMathError.insufficientData(
            required: 2, actual: independent.count, context: "Kendall's tau")
    }

    // Sorted by x, ties broken by y, which is what makes a run of equal x contiguous and its
    // y values already ordered — so the inversion count below sees only genuine discordance.
    var pairs = zip(independent, variable).map { (x: $0, y: $1) }
    pairs.sort { left, right in
        left.x == right.x ? left.y < right.y : left.x < right.x
    }

    let count = pairs.count
    let total = count * (count - 1) / 2
    let tiedInX = tiedPairs(pairs.map(\.x))
    let tiedInBoth = tiedPairs(pairs.map { PairKey(x: $0.x, y: $0.y) })

    var ys = pairs.map(\.y)
    let inversions = inversionCount(&ys)
    // `ys` is sorted now, so the tied runs in it are contiguous and can be counted directly.
    let tiedInY = tiedPairs(ys)

    let numerator = total - tiedInX - tiedInY + tiedInBoth - 2 * inversions
    let denominator = T(total - tiedInX) * T(total - tiedInY)
    guard denominator > T.zero else {
        throw BusinessMathError.divisionByZero(
            context: "Kendall's tau: every pair is tied in at least one variable, so there "
                + "is no correlation to report")
    }
    return T(numerator) / T.sqrt(denominator)
}

/// Both values of one observation, so pairs tied in *both* variables can be counted the same
/// way as pairs tied in one.
private struct PairKey<T: Real>: Equatable {
    let x: T
    let y: T
}

/// How many pairs are tied, given a sorted sequence.
///
/// A run of `k` equal values contributes `k(k−1)/2` pairs. Requires its input to be sorted so
/// that equal values are adjacent — which every caller here has already arranged, and which is
/// why this takes the sorted array rather than sorting defensively and hiding a caller's
/// mistake.
private func tiedPairs<E: Equatable>(_ sorted: [E]) -> Int {
    var total = 0, runLength = 1
    for index in 1..<Swift.max(sorted.count, 1) where sorted.count > 1 {
        if sorted[index] == sorted[index - 1] {
            runLength += 1
        } else {
            total += runLength * (runLength - 1) / 2
            runLength = 1
        }
    }
    return total + runLength * (runLength - 1) / 2
}

/// Sorts in place and returns how many inversions it took.
///
/// An inversion — a pair out of order — is exactly a discordant pair once the data is sorted
/// by the other variable, which is what lets the quadratic count collapse to a merge sort.
/// Equal values are **not** inversions, so the merge takes from the left run on a tie: taking
/// from the right would count each tied pair as discordant and drag tau toward −1 on exactly
/// the data tau-b exists to handle.
private func inversionCount<T: Comparable>(_ values: inout [T]) -> Int {
    guard values.count > 1 else { return 0 }
    var buffer = values
    return mergeCount(&values, &buffer, 0, values.count - 1)
}

private func mergeCount<T: Comparable>(
    _ values: inout [T], _ buffer: inout [T], _ low: Int, _ high: Int
) -> Int {
    guard low < high else { return 0 }
    let middle = low + (high - low) / 2
    var total = mergeCount(&values, &buffer, low, middle)
    total += mergeCount(&values, &buffer, middle + 1, high)

    var left = low, right = middle + 1, index = low
    while left <= middle && right <= high {
        if values[left] <= values[right] {
            buffer[index] = values[left]; left += 1
        } else {
            // Everything still unconsumed on the left is greater than this right-hand value,
            // so each of those is one inversion — the whole reason this is n log n.
            total += (middle - left + 1)
            buffer[index] = values[right]; right += 1
        }
        index += 1
    }
    while left <= middle { buffer[index] = values[left]; left += 1; index += 1 }
    while right <= high { buffer[index] = values[right]; right += 1; index += 1 }
    for position in low...high { values[position] = buffer[position] }
    return total
}
