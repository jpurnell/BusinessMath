///	
///	  File.swift
///	  
///	
///	  Created by Justin Purnell on 5/24/23.
///	

import Foundation
import OSLog
import Numerics

///	This function calculates the net present value (NPV) of a series of cash flows. This is a common financial analysis technique for assessing the time value of money. The net present value reflects the amount that each future cash flow is worth in terms of today's dollars.
///	
///	**Parameters**
///	- `discountRate r: T`
///	   - The interest rate used in discounting future cash flows. It must conform to the Swift standard library's `Real` type.
///	
///	- `cashFlows c: [T]`
///	   - An array of cash flows by period. The first item is the initial investment (always a negative number), and the remaining items are future returns. Each element must conform to the Swift standard library's `Real` type.
///	
///	**Return Value**
///	- Returns a `Real` value which is the net present value (NPV) of the series of cash flows, discounted according to the provided discount rate.
///	
///	- Complexity: O(n), where n is the number of cash flows. The function first iterates over the cash flows to calculate the present value for each, then it uses `reduce` to sum them up. Both operations are linear.
///	
///	**Usage Example**
///	```swift
///	let discountRate = 0.1
///	let cashFlows = [-1000, 200, 300, 400, 500]
///	let npvValue = npv(discountRate: discountRate, cashFlows: cashFlows)
///	print(npvValue)  ///	 prints the worth of the cash flows in terms of today's dollars
///	```
public func npv<T: Real>(discountRate r: T, cashFlows c: [T]) -> T {
    var presentValues: [T] = []
    for (period, flow) in c.enumerated() {
        presentValues.append(flow / T.pow((T(1) + r), T(period)))
    }
    print(presentValues)
    return presentValues.reduce(0, +)
}
