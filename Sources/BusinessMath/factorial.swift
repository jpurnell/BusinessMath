//
//  factorial.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

func factorial(_ n: Int) -> Int {
    var returnValue = 1
    if n == 0 { return returnValue }
    else {
        returnValue = (1...n).map({$0}).reduce(1, *)
    }
    return returnValue
}
