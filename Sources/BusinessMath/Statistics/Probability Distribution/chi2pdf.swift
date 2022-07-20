//
//  chi2pdf.swift
//  
//
//  Created by Justin Purnell on 6/11/22.
//

import Foundation
import Numerics

public func chi2pdf<T: Real>(x: T, dF: Int) -> T {
    var returnValue: T = 0
    guard x != 0 else {
        return T(0) }
    let limitHigh = ("\(x * T(1000))" as NSString).integerValue
    
    let limit = max(limitHigh, 1)
    if limit == 1 { return T(0) }
    for i in 1...limit {
        let x: T = T(i)/1000
        let dF = T(dF)

        let topLeft = T.pow(x, ((dF - 2) / 2))
        let topRight = 1 / T.exp(x / 2)
        let bottomLeft = T.pow(2, (dF / 2))
        let bottomRight = T.gamma(dF / 2)

        let top  = topLeft * topRight
        let bottom = bottomLeft * bottomRight

        returnValue += top / bottom
    }
        return returnValue / T(1000)
}
