//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/19/24.
//

import Foundation
import Numerics

public func exponentialCDF<T: Real>(_ x: T, λ: T) -> T {
	guard x >= 0 else { return 0 }
	return T(1) - T.exp(T(-1) * λ * x)
}

