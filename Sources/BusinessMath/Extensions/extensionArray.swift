//
//  extensionArray.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

extension Array where Element: Real {
    internal func rank() -> [Element] {
        let sorted = self.sorted(by: {$0 > $1})
        var rankArray: [Element] = []
        for i in 0..<self.count {
            rankArray.append(Element(sorted.firstIndex(of: self[i])! + 1))
        }
        var counts:[Element: Int] = [:]
        rankArray.forEach({counts[$0, default: 0] += 1})
        var tieAdjustment: Element = 0
        for count in counts {
            tieAdjustment += (((count.key * count.key * count.key) - count.key) / 12)
        }
        for (index, absoluteRank) in rankArray.enumerated() {
            let n = Element(counts[absoluteRank]!)
            rankArray[index] = (((n * absoluteRank) + (((n - 1) * n) / 2)) / n)
        }
        return rankArray
    }

    internal func reverseRank() -> [Element] {
        let sorted = self.sorted(by: {$0 < $1})
        var rankArray: [Element] = []
        for i in 0..<self.count {
            rankArray.append(Element(sorted.firstIndex(of: self[i])! + 1))
        }
        var counts:[Element: Int] = [:]
        rankArray.forEach({counts[$0, default: 0] += 1})
        var tieAdjustment: Element = 0
        for count in counts {
            tieAdjustment += (((count.key * count.key * count.key) - count.key) / 12)
        }
        for (index, absoluteRank) in rankArray.enumerated() {
            let n = Element(counts[absoluteRank]!)
            rankArray[index] = (((n * absoluteRank) + (((n - 1) * n) / 2)) / n)
        }
        return rankArray
    }

    internal func tauAdjustment() -> Element {
        let sorted = self.sorted(by: {$0 > $1})
        var rankArray: [Element] = []
        for i in 0..<self.count {
            rankArray.append(Element(sorted.firstIndex(of: self[i])! + 1))
        }
        var counts:[Element: Int] = [:]
        rankArray.forEach({ counts[$0, default: 0] += 1})
        var tieAdjustment: Element = 0
        for count in counts {
            var adjustment: Element = 0
            if count.value > 1 {
                adjustment = ((Element((count.value * count.value * count.value) - count.value)) / 12)
            }
            tieAdjustment += adjustment
        }
        return tieAdjustment
    }
}
