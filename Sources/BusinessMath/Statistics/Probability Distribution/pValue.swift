//
//  pValue.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func pValue<T: Real>(_ independent: [T], _ variable: [T]) -> T {
    return pValueStudent(tStatistic(independent, variable), dFr: T(independent.count - 2))
}
