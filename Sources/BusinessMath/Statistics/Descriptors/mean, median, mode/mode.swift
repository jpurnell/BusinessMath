//
//  mode.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// Mode is the number that appears most frequently in a given set of samples
// Equivalent of Excel MODE(xx:xx)
public func mode<T: Real>(_ x: [T]) -> T {
    let counted = NSCountedSet(array: x)
    let max = counted.max { counted.count(for: $0) < counted.count(for: $1)}
    return max as! T
}
