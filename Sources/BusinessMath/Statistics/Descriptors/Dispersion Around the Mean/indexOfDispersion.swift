//
//  File.swift
//  
//
//  Created by Justin Purnell on 1/6/24.
//

import Foundation
import Numerics

public func indexOfDispersion<T: Real>(_ values: [T]) -> T {
	return variance(values) / mean(values)
}
