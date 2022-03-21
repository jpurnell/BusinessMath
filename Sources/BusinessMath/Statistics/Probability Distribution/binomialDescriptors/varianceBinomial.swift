//
//  varianceBinomial.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func varianceBinomial<T: Real>(n: Int, prob: T) -> T {
    return T(n) * prob * (1 - prob)
}

