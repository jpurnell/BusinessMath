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

        let sorted = self.sorted(by: { $0.magnitude > $1.magnitude })
        var rankArray: [Element] = []

        for i in 0..<self.count {
            guard let index = sorted.firstIndex(of: self[i]) else { continue }
            rankArray.append(Element(index + 1))
        }

        var counts: [Element: Int] = [:]
        rankArray.forEach { counts[$0, default: 0] += 1 }

        for (index, absoluteRank) in rankArray.enumerated() {
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

        let sorted = self.sorted(by: { $0.magnitude < $1.magnitude })
        var rankArray: [Element] = []

        for i in 0..<self.count {
            guard let index = sorted.firstIndex(of: self[i]) else { continue }
            rankArray.append(Element(index + 1))
        }

        var counts: [Element: Int] = [:]
        rankArray.forEach { counts[$0, default: 0] += 1 }

        for (index, absoluteRank) in rankArray.enumerated() {
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
    /// - Returns: The tie correction factor. Returns 0 if no ties exist.
    ///
    /// - Complexity: O(n log n) due to sorting.
    public func tauAdjustment() -> Element {
        guard !isEmpty else { return Element(0) }

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
