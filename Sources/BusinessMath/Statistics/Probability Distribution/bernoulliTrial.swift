//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func bernoulliTrial<T: Real>(p: T) -> Int {
    if T(Int(drand48() * 1000000000 / 1000000000)) < p {
        return 1
    }
    return 0
}
