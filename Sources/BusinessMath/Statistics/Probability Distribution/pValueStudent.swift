//
//  pValueStudent.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func pValueStudent<T: Real>(_ tValue: T, dFr: T) -> T {
    let rhoTop = T.gamma((dFr + 1) / T(2))
    let rhoBot = T.sqrt(dFr * T.pi) * T.gamma(dFr / T(2))
    let left = rhoTop / rhoBot
    let center = (1 + ((tValue * tValue)/dFr))
    let centEx = -1 * ((dFr + 1) / 2)
    let right = T.pow(center, centEx)
    let pValueStudent = left * right
    return pValueStudent
}
