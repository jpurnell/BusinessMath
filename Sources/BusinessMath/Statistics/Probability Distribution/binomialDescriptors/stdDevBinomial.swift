//
//  stdDevBinomial.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func stdDevBinomial<T: Real>(n: Int, prob: T) -> T {
    return T.sqrt(varianceBinomial(n: n, prob: prob))
}
