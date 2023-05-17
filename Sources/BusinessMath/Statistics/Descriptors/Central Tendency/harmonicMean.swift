//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/17/23.
//

import Foundation
import Numerics

public func harmonicMean<T: Real>(_ x: T, _ y: T) -> T {
    return (T(2) * x * y) / (x + y)
}

