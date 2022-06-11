//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func chi2cdf<T: Real>(x: T, dF: Int) -> T {
    return 1 - chi2pdf(x: x, dF: dF)
}
