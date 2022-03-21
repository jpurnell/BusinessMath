//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

func fisher<T: Real>(_ r: T) -> T {
    return (T.log((1 + r) / (1 - r)) / 2)
}
