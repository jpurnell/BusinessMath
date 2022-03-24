//
//  combination.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation

func combination(_ n: Int, c r: Int) -> Int {
    return (factorial(n) / (factorial(r) * factorial(n - r)))
}
