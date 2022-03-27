//
//  normSDist.swift
//  
//
//  Created by Justin Purnell on 3/26/22.
//

import Foundation
import Numerics

// Excel Compatibility – Equivalent of Excel's NORM.S.DIST function, culumative probability = true
func normSDist<T: Real>(zScore z: T) -> T {
    return percentile(zScore: z)
}
