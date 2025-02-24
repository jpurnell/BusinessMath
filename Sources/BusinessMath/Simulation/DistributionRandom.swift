//
//  DistributionRandom.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2/24/25.
//

import Numerics

protocol DistributionRandom {
	associatedtype T: Real
	
	func next() -> T
}
