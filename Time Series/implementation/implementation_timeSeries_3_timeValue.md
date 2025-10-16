 Phase 3: Time Value of Money

  3.1 Present/Future Value (Sources/BusinessMath/Time Series/TVM/PresentValue.swift)

  /// Calculate present value of a future amount
  public func presentValue<T: Real>(
      futureValue: T,
      rate: T,
      periods: Int
  ) -> T

  /// Calculate future value of a present amount
  public func futureValue<T: Real>(
      presentValue: T,
      rate: T,
      periods: Int
  ) -> T

  /// PV of an annuity (equal periodic payments)
  public func presentValueAnnuity<T: Real>(
      payment: T,
      rate: T,
      periods: Int,
      type: AnnuityType = .ordinary
  ) -> T

  public enum AnnuityType {
      case ordinary  // Payments at end of period
      case due       // Payments at beginning of period
  }

  Design Decisions:
  - Separate functions for single values vs. annuities
  - Support both ordinary annuities and annuities due
  - Follow Excel naming conventions where applicable

  3.2 Payment Calculations (Sources/BusinessMath/Time Series/TVM/Payment.swift)

  /// Calculate periodic payment for a loan
  public func payment<T: Real>(
      presentValue: T,
      rate: T,
      periods: Int,
      futureValue: T = T(0),
      type: AnnuityType = .ordinary
  ) -> T

  /// Calculate principal portion of payment
  public func principalPayment<T: Real>(
      rate: T,
      period: Int,
      totalPeriods: Int,
      presentValue: T
  ) -> T

  /// Calculate interest portion of payment
  public func interestPayment<T: Real>(
      rate: T,
      period: Int,
      totalPeriods: Int,
      presentValue: T
  ) -> T

  3.3 Internal Rate of Return (Sources/BusinessMath/Time Series/TVM/IRR.swift)

  /// Calculate IRR for a series of cash flows
  public func irr<T: Real>(
      cashFlows: [T],
      guess: T = T(0.1),
      tolerance: T = T(0.000001),
      maxIterations: Int = 100
  ) throws -> T

  /// Calculate MIRR with separate financing and reinvestment rates
  public func mirr<T: Real>(
      cashFlows: [T],
      financeRate: T,
      reinvestmentRate: T
  ) throws -> T

  Design Decisions:
  - Use Newton-Raphson method (leverage existing goalSeek)
  - Throw errors for invalid inputs (all positive/negative flows)
  - MIRR more realistic for most business cases

  3.4 NPV Refinement (Sources/BusinessMath/Time Series/TVM/NPV.swift)

  Move from "zzz In Process" and enhance:
  - Remove debug print() statement
  - Add variant that takes TimeSeries as input
  - Add XNPV for irregular periods
  - Comprehensive documentation
  - Add related metrics: Profitability Index, Payback Period

  ---
