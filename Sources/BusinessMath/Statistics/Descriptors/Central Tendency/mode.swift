//
//  mode.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Equivalent of Excel MODE(xx:xx)
/// - Parameter x: An array of values.
/// - Returns: Mode is the number that appears most frequently in a given set of samples
public func mode<T: Real>(_ x: [T]) -> T {
	guard !x.isEmpty else { return T.nan }
    let counted = NSCountedSet(array: x)
    let max = counted.max { counted.count(for: $0) < counted.count(for: $1)}
    return max as! T
}
