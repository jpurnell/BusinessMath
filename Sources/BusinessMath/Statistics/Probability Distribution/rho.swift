//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

func rho<T: Real>(from fisherR: T) -> T {
    return (T.exp(2 * fisherR) - 1) / (T.exp(2 * fisherR) + 1)
}
