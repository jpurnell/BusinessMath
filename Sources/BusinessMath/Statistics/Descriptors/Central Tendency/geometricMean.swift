//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/17/23.
//

import Foundation
import Numerics

public func geometricMean<T: Real>(_ values: [T]) -> T {
    return T.pow(values.reduce(T(1), *), T(1) / T(values.count))
}
