//
//  permutation.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation

public func permutation(_ n: Int, p r: Int) -> Int {
    return (factorial(n) / factorial(n - r))
}
