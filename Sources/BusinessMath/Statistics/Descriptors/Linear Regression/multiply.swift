//
//  File.swift
//  
//
//  Created by Justin Purnell on 10/19/22.
//

import Foundation
import Numerics

public func multiplyVectors<T: Real>(_ x: [T], _ y: [T]) -> [T] {
    return zip(x, y).map(*)
}
