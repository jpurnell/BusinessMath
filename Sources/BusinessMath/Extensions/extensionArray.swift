//
//  extensionArray.swift
//
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

extension Array where Element: Real {
    /// Ranks elements in the array by magnitude in descending order with tie averaging.
    ///
    /// Elements with higher magnitude receive lower (better) ranks. When multiple
    /// elements have the same value (ties), they receive the average of the ranks
    /// they would occupy.
    ///
    /// ## Overview
    ///
    /// Ranking is fundamental to non-parametric statistics. This method assigns
    /// ranks from 1 (highest magnitude) to n (lowest magnitude), where ties
    /// receive fractional ranks equal to the mean of their positions.
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// let values: [Double] = [100, 80, 60, 40, 20]
    /// let ranks = values.rank()
    /// // ranks = [1.0, 2.0, 3.0, 4.0, 5.0]
    ///
    /// let unsorted: [Double] = [60, 100, 20, 80, 40]
    /// let unsortedRanks = unsorted.rank()
    /// // unsortedRanks = [3.0, 1.0, 5.0, 2.0, 4.0]
    /// ```
    ///
    /// ## Tie Handling
    ///
    /// ```swift
    /// let withTies: [Double] = [100, 80, 80, 40]
    /// let tiedRanks = withTies.rank()
    /// // 80 appears at positions 2 and 3, so both get (2+3)/2 = 2.5
    /// // tiedRanks = [1.0, 2.5, 2.5, 4.0]
    /// ```
    ///
    /// - Returns: An array of ranks corresponding to each input position.
    ///   Returns an empty array if input is empty.
    ///
    /// - Complexity: O(n log n) due to sorting.
    ///
    /// - SeeAlso: ``reverseRank()``
    /// - SeeAlso: ``tauAdjustment()``
    public func rank() -> [Element] {
        guard !isEmpty else { return [] }

        // The earlier fix in the `firstIndex(of:)` branch below restored the *length*
        // invariant — one rank per observation — and stopped `spearmansRho` trapping. It left
        // the ordering itself untouched, and the ordering is the second half of the same
        // fact: `sorted(by:)` given a comparator that is not a strict weak ordering does not
        // merely misplace the `nan`, it is free to return the **valid** elements out of order
        // (contract §2: `[3, 1, nan, 2, 5, 4].sorted()` gives `[1, 3, nan, 2, 4, 5]`). So the
        // finite observations were receiving finite, plausible, *wrong* ranks, and the one
        // marked `nan` was the only position that admitted anything had gone wrong.
        //
        // Ranks are relative, so one unrankable observation costs the whole vector: there is
        // no permutation left to read positions off. Every position says so, and the length
        // invariant the earlier fix established is preserved.
        guard allSatisfy({ $0.isFinite }) else {
            return Array(repeating: Element.nan, count: count)
        }

        let sorted = self.sorted(by: { $0.magnitude > $1.magnitude })
        var rankArray: [Element] = []

        for i in 0..<self.count {
            guard let index = sorted.firstIndex(of: self[i]) else {
                // `firstIndex(of:)` compares with `==`, and `nan == nan` is false, so a
                // `nan` is never found in `sorted` and this branch is reached. It used to
                // `continue`, appending nothing — which made the result *shorter than the
                // input* and broke the one-rank-per-observation invariant every caller
                // relies on. `spearmansRho` then indexed past the end and trapped with
                // "Index out of range".
                //
                // A `nan` has no rank, so say that and keep the position.
                rankArray.append(Element.nan)
                continue
            }
            rankArray.append(Element(index + 1))
        }

        var counts: [Element: Int] = [:]
        rankArray.forEach { counts[$0, default: 0] += 1 }

        for (index, absoluteRank) in rankArray.enumerated() {
            // An unrankable position belongs to no tie group.
            guard absoluteRank.isFinite else { continue }
            guard let countValue = counts[absoluteRank] else { continue }
            let n = Element(countValue)
            rankArray[index] = ((n * absoluteRank) + (((n - 1) * n) / 2)) / n
        }

        return rankArray
    }

    /// Ranks elements in the array by magnitude in ascending order with tie averaging.
    ///
    /// Elements with lower magnitude receive lower ranks. This is the inverse
    /// of ``rank()`` - useful when lower values indicate better performance.
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// let values: [Double] = [20, 40, 60, 80, 100]
    /// let ranks = values.reverseRank()
    /// // ranks = [1.0, 2.0, 3.0, 4.0, 5.0]
    ///
    /// let unsorted: [Double] = [60, 100, 20, 80, 40]
    /// let unsortedRanks = unsorted.reverseRank()
    /// // unsortedRanks = [3.0, 5.0, 1.0, 4.0, 2.0]
    /// ```
    ///
    /// ## Relationship to rank()
    ///
    /// For any array without ties, the sum of corresponding ranks from
    /// `rank()` and `reverseRank()` equals n+1.
    ///
    /// - Returns: An array of ranks corresponding to each input position.
    ///   Returns an empty array if input is empty.
    ///
    /// - Complexity: O(n log n) due to sorting.
    ///
    /// - SeeAlso: ``rank()``
    public func reverseRank() -> [Element] {
        guard !isEmpty else { return [] }

        // Same mechanism as ``rank()``: an unorderable element makes the comparator stop
        // being a strict weak ordering, so the ranks handed to the *finite* elements are
        // read off an arbitrary permutation.
        guard allSatisfy({ $0.isFinite }) else {
            return Array(repeating: Element.nan, count: count)
        }

        let sorted = self.sorted(by: { $0.magnitude < $1.magnitude })
        var rankArray: [Element] = []

        for i in 0..<self.count {
            guard let index = sorted.firstIndex(of: self[i]) else {
                // `firstIndex(of:)` compares with `==`, and `nan == nan` is false, so a
                // `nan` is never found in `sorted` and this branch is reached. It used to
                // `continue`, appending nothing — which made the result *shorter than the
                // input* and broke the one-rank-per-observation invariant every caller
                // relies on. `spearmansRho` then indexed past the end and trapped with
                // "Index out of range".
                //
                // A `nan` has no rank, so say that and keep the position.
                rankArray.append(Element.nan)
                continue
            }
            rankArray.append(Element(index + 1))
        }

        var counts: [Element: Int] = [:]
        rankArray.forEach { counts[$0, default: 0] += 1 }

        for (index, absoluteRank) in rankArray.enumerated() {
            // An unrankable position belongs to no tie group.
            guard absoluteRank.isFinite else { continue }
            guard let countValue = counts[absoluteRank] else { continue }
            let n = Element(countValue)
            rankArray[index] = ((n * absoluteRank) + (((n - 1) * n) / 2)) / n
        }

        return rankArray
    }

    /// Computes the tau adjustment (tie correction factor) for the array.
    ///
    /// When there are tied values in a ranking, Kendall's tau and other
    /// statistics need correction. This method computes the adjustment
    /// factor using the formula Σ(t³-t)/12, where t is the size of each
    /// tie group.
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// let values = [100.0, 110.0, 120.0, 130.0]
    /// // No ties
    /// let noTies: [Double] = [100, 80, 60, 40, 20]
    /// let adj1 = noTies.tauAdjustment()  // Returns 0.0
    ///
    /// // Two values tied
    /// let twoTied: [Double] = [100, 80, 80, 40]
    /// let adj2 = twoTied.tauAdjustment()
    /// // Adjustment = (2³ - 2) / 12 = 0.5
    ///
    /// // Multiple tie groups
    /// let multiTied: [Double] = [100, 80, 80, 40, 40]
    /// let adj3 = multiTied.tauAdjustment()
    /// // Adjustment = 2 × (2³ - 2) / 12 = 1.0
    /// ```
    ///
    /// - Returns: The tie correction factor. Returns 0 if no ties exist, and `nan` if any
    ///   element is not finite.
    ///
    /// - Complexity: O(n log n) due to sorting.
    public func tauAdjustment() -> Element {
        guard !isEmpty else { return Element(0) }

        // Two separate failures met here, and `0` is the answer that hid both. The sort is
        // unspecified with an unorderable element present, so the ranks that drive the tie
        // groups are read off an arbitrary permutation; and `firstIndex(of:)` compares with
        // `==`, so the unorderable element is never found and used to be dropped by the
        // `continue` below — leaving a shorter `rankArray` and, with it, fewer ties. The
        // correction came back smaller, or exactly `0`, which is the value that means "this
        // sample has no ties to correct for" and leaves Kendall's τ believing it.
        guard allSatisfy({ $0.isFinite }) else { return Element.nan }

        let sorted = self.sorted(by: { $0.magnitude > $1.magnitude })
        var rankArray: [Element] = []

        for i in 0..<self.count {
            guard let index = sorted.firstIndex(of: self[i]) else { continue }
            rankArray.append(Element(index + 1))
        }

        var counts: [Element: Int] = [:]
        rankArray.forEach { counts[$0, default: 0] += 1 }

        var tieAdjustment = Element(0)
        for count in counts where count.value > 1 {
            let adjustment = Element(count.value * count.value * count.value - count.value) / 12
            tieAdjustment += adjustment
        }

        return tieAdjustment
    }
}
