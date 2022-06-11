//
//  factorial.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func factorial(_ n: Int) -> Int {
    var returnValue = 1
    if n == 0 { return returnValue }
    else {
        returnValue = (1...n).map({$0}).reduce(1, *)
    }
    return returnValue
}

extension Int {
    public func factorial() -> Int {
        if self >= 0 {
            return self == 0 ? 1 : self * (self - 1).factorial()
        } else {
            return 0
        }
    }
}
