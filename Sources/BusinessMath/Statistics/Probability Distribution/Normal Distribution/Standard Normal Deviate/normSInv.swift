//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/26/22.
//

import Foundation
import Numerics

// MARK: - Excel Compatibility: Equivalent of Excel's NORM.S.INV function, culumative probability = true
public func normSInv<T: Real>(probability x: T) -> T {
    return zScore(percentile: x)
}
