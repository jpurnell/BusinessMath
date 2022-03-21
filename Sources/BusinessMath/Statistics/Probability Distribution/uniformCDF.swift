//
//  uniformCDF.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func uniformCDF<T: Real>(x: T) -> T {
    if x < T(0) {
        return T(0)
    }
    else if x < T(1) {
        return x
    }
    return T(1)
}
