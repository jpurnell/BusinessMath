//
//  File.swift
//  
//
//  Created by Justin Purnell on 1/6/24.
//

import Foundation
import Numerics

///Provides the contraharmonic mean, i.e. the ratio of the sum of squares to the sum: https://www.johndcook.com/blog/2023/05/20/contraharmonic-mean/

public func contraharmonicMean<T: Real>(_ x: T, _ y: T) -> T {
	return (T.pow(x, T(2)) + T.pow(y, T(2))) / (x + y)
}

