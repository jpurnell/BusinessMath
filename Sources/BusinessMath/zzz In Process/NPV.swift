//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/24/23.
//

import Foundation
import OSLog
import Numerics

/// The Net Present Value of a series of cash flows for a given rate.
/// - Parameters:
///   - r: Discount Rate
///   - c: An array representing a series of cash flows
/// - Returns: The net present value of the series of cash flows discounted at a single rate, from time 0. The equivalent of NPV(rate, value) in Excel
public func npv<T: Real>(discountRate r: T, cashFlows c: [T]) -> T {
    var presentValues: [T] = []
    for (period, flow) in c.enumerated() {
        presentValues.append(flow / T.pow((T(1) + r), T(period)))
    }
    print(presentValues)
    return presentValues.reduce(0, +)
}
