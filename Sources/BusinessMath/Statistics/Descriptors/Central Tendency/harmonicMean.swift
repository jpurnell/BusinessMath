//
//  harmonicMean.swift
//  
//
//  Created by Justin Purnell on 5/17/23.
//

import Foundation
import Numerics

//public func harmonicMean<T: Real>(_ x: T, _ y: T) -> T {
//    return (T(2) * x * y) / (x + y)
//}

public func harmonicMean<T: Real>(_ values: [T]) -> T {
	T(values.count) / (values.map({T.pow($0, T(-1))}).reduce(0, +))
}
