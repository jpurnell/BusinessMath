//
//  zScoreFisherR.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the Z-Score given the Fisher's R value and the number of items.
///
/// This function calculates the Z-Score (also known as a standard score) for the Fisher's R and the number of items.
///
/// - Parameters:
///   - fisherR: The Fisher's R value.
///   - items: The number of items.
/// - Returns: The Z-Score associated with the given Fisher's R and number of items.
/// - Precondition: The `items` count must be an integer greater than 3.
///
///     let z = zScore(fisherR: 0.68, items: 7)
public func zScore<T: Real>(fisherR: T, items: Int) -> T {
    return T.sqrt(T(items - 3)/T(Int(106) / 100)) * fisherR
}
