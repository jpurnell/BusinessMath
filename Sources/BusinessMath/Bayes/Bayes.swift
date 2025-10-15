//
//  File.swift
//  BusinessMath
//
//  Created by Justin Purnell on 9/17/25.
//

import Foundation
import Numerics
import Testing

func bayes(_ probabilityD: Double, _ probabilityTGivenD: Double, _ probabiityTGivenNotD: Double) -> Double {
	let pNotD = 1-probabilityD
	let pT = probabilityTGivenD * probabilityD + probabiityTGivenNotD * pNotD
	let probabilityDGivenT = (probabilityTGivenD * probabilityD) / pT
	return probabilityDGivenT
}
