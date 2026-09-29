//
//  TimeSeriesAnalytics.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - Forecast Error Metrics

/// Error metrics for comparing forecasted values against actual values.
///
/// Contains standard forecast accuracy measures used to evaluate and compare
/// different forecasting models.
///
/// ## Metrics Included
/// - **RMSE** (Root Mean Squared Error): Penalizes large errors more heavily
/// - **MAE** (Mean Absolute Error): Average magnitude of errors
/// - **MAPE** (Mean Absolute Percentage Error): Percentage error, scale-independent
///
/// ## Example
/// ```swift
/// let periods = Period.documentationQuarters
/// let actual = TimeSeries(periods: periods, values: [100, 110, 120])
/// let forecast = TimeSeries(periods: periods, values: [98, 112, 118])
///
/// let metrics = actual.forecastError(against: forecast)
/// print("RMSE: \(metrics.rmse)")
/// print("MAE: \(metrics.mae)")
/// print("MAPE: \(metrics.mape)")
///
/// // Compare models
/// let altForecast = TimeSeries(periods: periods, values: [101, 108, 123])
/// let model1Metrics = actual.forecastError(against: forecast)
/// let model2Metrics = actual.forecastError(against: altForecast)
///
/// if model1Metrics.rmse < model2Metrics.rmse {
///     print("Model 1 is more accurate")
/// }
/// ```
/// ## When the comparison cannot be scored
///
/// Every metric here is a **ranking key** — the whole point of the type is that a caller
/// compares two of them and keeps the better model. So the one thing it must never do is
/// report a good score for a comparison that did not happen.
///
/// The invariant is: **the three metrics never disagree about whether the comparison
/// succeeded.** If the overlapping observations contain anything non-finite, or the two series
/// do not overlap at all, ``rmse``, ``mae`` and ``mape`` are *all* `.nan`.
///
/// Measured before that was true: one `nan` actual gave `rmse = nan` and `mape = 0.0` in the
/// same returned value — the best score MAPE can take, from an explicit `isNaN ? 0` rewrite —
/// so a model ranked on MAPE won on data that could not be scored while the same object
/// admitted, in the next field, that it could not be scored.
///
/// ``mape`` alone may still be `.nan` while the other two are finite, and that is a different
/// statement: MAPE divides by the actual, so it is undefined when *every* overlapping actual
/// is zero. There the comparison did succeed and RMSE and MAE are real measurements; it is
/// MAPE's own domain that is empty. The same rewrite used to report that case as `0.0` too —
/// a perfect forecast of a series nobody could express a percentage error against.
public struct ForecastErrorMetrics<T: Real & Sendable & Codable>: Sendable where T: BinaryFloatingPoint {
	/// Root Mean Squared Error - sqrt(mean((actual - forecast)²))
	///
	/// RMSE penalizes larger errors more heavily due to squaring.
	/// Lower values indicate better forecast accuracy.
	///
	/// `.nan` when the comparison could not be scored at all — see the type's
	/// **When the comparison cannot be scored**.
	public let rmse: T

	/// Mean Absolute Error - mean(|actual - forecast|)
	///
	/// MAE represents the average magnitude of errors.
	/// Lower values indicate better forecast accuracy.
	///
	/// `.nan` when the comparison could not be scored at all — see the type's
	/// **When the comparison cannot be scored**.
	public let mae: T

	/// Mean Absolute Percentage Error - mean(|actual - forecast| / |actual|)
	///
	/// MAPE expresses error as a percentage, making it scale-independent.
	/// Lower values indicate better forecast accuracy.
	/// Note: Excludes periods where actual value is zero to avoid division by zero.
	///
	/// `.nan` either when the comparison could not be scored at all — in which case ``rmse``
	/// and ``mae`` are `.nan` too — or when every overlapping actual was zero, leaving MAPE's
	/// domain empty while RMSE and MAE remain genuine measurements. It is never `0` except as
	/// a measured perfect forecast.
	public let mape: T

	/// Number of periods included in the error calculation
	///
	/// Only periods present in both actual and forecast series are counted. This counts the
	/// overlap itself, so it stays truthful when the metrics are `.nan`: `count = 4` with
	/// three `.nan` metrics says four periods lined up and none of them could be scored,
	/// which is a different fact from `count = 0`.
	public let count: Int

	/// Creates forecast error metrics.
	///
	/// - Parameters:
	///   - rmse: Root mean squared error
	///   - mae: Mean absolute error
	///   - mape: Mean absolute percentage error
	///   - count: Number of periods compared
	public init(rmse: T, mae: T, mape: T, count: Int) {
		self.rmse = rmse
		self.mae = mae
		self.mape = mape
		self.count = count
	}

	/// Human-readable summary of error metrics.
	@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
	public var summary: String {
		"""
		Forecast Error Metrics
		======================
		Periods Compared: \(count)
		RMSE: \(rmse.number(4))
		MAE:  \(mae.number(4))
		MAPE: \(mape.percent(2))
		"""
	}
}

// MARK: - TimeSeries Analytics

extension TimeSeries {

	// MARK: - Growth Metrics

	/// Calculates period-over-period growth rates.
	///
	/// Growth rate is calculated as (current - previous) / previous.
	///
	/// - Parameter lag: The number of periods to look back (default: 1). A `lag` outside
	///   `0...count` yields an empty series rather than trapping.
	/// - Returns: A time series of growth rates carrying **one entry for every period from
	///   index `lag` onward whose `lag`-predecessor is its calendar predecessor**. A period
	///   whose growth rate is undefined is marked `.nan`; it is never omitted, so `count` is
	///   `periods.count - lag` for a series with no gaps. See **Gaps in the period index**.
	///
	/// ## Example
	/// ```swift
	/// let months = Period.documentationQuarters
	/// let revenue = TimeSeries(periods: months, values: [100, 110, 121])
	/// let growth = revenue.growthRate(lag: 1)  // two entries: 0.10 and 0.10
	/// ```
	///
	/// ## Gaps in the period index
	/// A `TimeSeries` is keyed by period, so a month that was never recorded is simply absent
	/// from ``TimeSeries/periods`` — there is no hole to step over, only a shorter list, and
	/// `periods[i - lag]` is then the adjacent element of the *sorted list* rather than the
	/// calendar predecessor. Measured on Jan, Feb, Apr, May with `lag: 1`, the previous
	/// implementation computed `(Apr - Feb) / Feb` and **labelled it Apr**: two months of
	/// growth reported at one month's label, with the same shape, the same `count` and the
	/// same units as the genuine one-month rates either side of it. Annualising that series,
	/// or comparing April's figure against the others, compounds a two-month move as though it
	/// were one.
	///
	/// Following ``TimeSeries/zip(with:_:)`` and ``movingAverage(window:)``, the result narrows
	/// instead: April has no one-period growth rate, so the result does not contain April.
	///
	/// **This is not the zero-base case below, and the two are deliberately answered
	/// differently.** A zero base is an *observation*: both periods are present, the rate they
	/// imply is genuinely undefined, and dropping it would shorten a result whose domain the
	/// caller can enumerate — contract §3.5. A gap is the *absence* of the observation the rate
	/// would be about, so there is no position to mark; that is contract §3.7, *narrow the
	/// domain, do not fabricate the observation*, and this function's own `nil`-lookup branch
	/// below already committed to omission for exactly that reason.
	///
	/// Adjacency is decided by ``Period/nextIfSteppable()``. Where it cannot be decided — a
	/// ``PeriodType/custom`` range has no defined successor, and two periods of different types
	/// have no common step — the periods are treated as adjacent, so an irregular series keeps
	/// exactly the behaviour it has always had rather than silently emptying.
	///
	/// ## Growth from a zero base
	/// Growth from a base of zero is **undefined, not infinite**. `0 -> 100` and `0 -> 1` are
	/// equally "infinite" growth, and a pair of inputs that cannot be told apart by the answer
	/// is the signature of undefinedness rather than of an unbounded quantity. The period is
	/// therefore reported as `.nan` — the same answer ``cagr(from:to:)`` gives through
	/// ``BusinessMath/cagr(beginningValue:endingValue:years:)``, which returns `.nan` rather
	/// than the `+infinity` it used to for a non-positive beginning value.
	///
	/// Measured before that was true, the period was **dropped from the result entirely**: a
	/// twelve-month series with one zero month came back with ten growth rates instead of
	/// eleven, and `count` — which is exactly what a caller checks — reported a series one
	/// observation shorter than the one it was handed, with no diagnostic anywhere saying which
	/// month had gone or why. That is contract §3.5's length invariant and §4's "silently
	/// dropping a value" in the same line.
	///
	/// A `nan` previous value is *not* special-cased: `nan != 0` is true like every comparison
	/// against `nan`, so the division propagates the contamination to that period's rate and
	/// that period's rate only. That is already the right answer and is stated here rather than
	/// relied upon.
	public func growthRate(lag: Int = 1) -> TimeSeries<T> {
		guard !isEmpty else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		// A negative `lag` starts the loop at a negative `i` and reads `periods[i]`; a `lag` past
		// the end forms a range whose lower bound exceeds its upper. Both **trap**, so the caller
		// is not told anything at all — the process stops. Following ``movingAverage(window:)``,
		// which answers an impossible window with an empty series, a lag this series cannot
		// support has no growth rates to report and `count == 0` says so.
		guard lag >= 0, lag <= periods.count else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []
		let runStarts = contiguousRunStarts()

		for i in lag..<periods.count {
			let currentPeriod = periods[i]
			let previousPeriod = periods[i - lag]

			// A `lag`-period rate needs `lag + 1` consecutive periods ending here. Without this
			// the caller is told that April grew 8% in one month when the figure is two months
			// of growth with March missing — see **Gaps in the period index**. `lag == 0` asks
			// for a window of one, which no gap can break.
			guard windowSpansNoGap(endingAt: i, window: lag + 1, runStarts: runStarts) else {
				continue
			}

			// `periods` is derived from the value keys, so neither lookup can fail today. If one
			// ever did, the period is one the data does not cover and there is no rate to
			// report for it — §3.7's "narrow the domain, do not fabricate the observation",
			// which is what the omission here means. It is *not* the zero-base case below,
			// where the data is present and the answer is undefined.
			guard let currentValue = self[currentPeriod],
				  let previousValue = self[previousPeriod] else { continue }

			// Measured before this branch: a legitimately zero previous value failed
			// `previousValue != T.zero` and the period was appended to neither array, so the
			// returned series was shorter than the span it covered and nothing in it said so.
			// The rate is undefined rather than unbounded — see **Growth from a zero base** —
			// so the position is kept and marked.
			let rate: T
			if previousValue == T.zero {
				rate = T.nan
			} else {
				let change: T = currentValue - previousValue
				rate = change / previousValue
			}

			resultPeriods.append(currentPeriod)
			resultValues.append(rate)
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	/// Calculates the Compound Annual Growth Rate (CAGR).
	///
	/// CAGR = (endingValue / beginningValue)^(1/years) - 1
	///
	/// The number of years is calculated precisely from the period dates,
	/// accounting for the exact number of days between the start of the
	/// starting period and the end of the ending period.
	///
	/// - Parameters:
	///   - start: The starting period.
	///   - end: The ending period.
	/// - Returns: The CAGR as a decimal (e.g., 0.10 for 10%), `0` for a genuinely flat
	///   trajectory, or `.nan` when the rate cannot be computed — either period absent from
	///   the series, a non-positive or non-finite starting value, or a span that is not
	///   strictly positive. Per §3.1 of the contaminated-input contract, the three
	///   unanswerable cases share one answer, and none of them shares it with "no growth".
	///
	/// ## Example
	/// ```swift
	/// let jan2020 = Period.month(year: 2020, month: 1)
	/// let jan2025 = Period.month(year: 2025, month: 1)
	/// let revenue = TimeSeries<Double>(periods: [jan2020, jan2025], values: [100.0, 161.051])
	///
	/// let compound = revenue.cagr(from: jan2020, to: jan2025)
	/// // ~0.10 — the span is 1,827 days, which the 365.25-day mean year reads as 5.00 years.
	///
	/// let jan2030 = Period.month(year: 2030, month: 1)
	/// let unanswerable = revenue.cagr(from: jan2020, to: jan2030)
	/// // .nan — the series does not cover Jan 2030, so there is no rate to report.
	/// ```
	public func cagr(from start: Period, to end: Period) -> T {
		// Measured before this guard: an absent `start` or `end` period returned `0.0`, and so
		// did a `nan` start value (`nan > 0` is false, like every comparison against nan), and
		// so did a genuinely flat series. "No such period", "cannot be computed" and "grew 0%
		// a year" were one byte-identical answer, and a caller ranking divisions by CAGR put
		// the one whose statements it was simply missing level with the one that stood still.
		// §3.7: narrow the domain, do not fabricate the observation.
		guard let startValue = self[start], let endValue = self[end] else { return T.nan }

		// Calculate exact fractional years from period start dates
		// Using startDate for both provides intuitive period-to-period calculations
		// (e.g., "Jan 2020 to Jan 2025" = exactly 5 years)
		let calendar = gregorianUTC
		let components = calendar.dateComponents([.day],
												 from: start.startDate,
												 to: end.startDate)
		let days = T(components.day ?? 0)
		// Convention: 365.25, the mean Gregorian year, and deliberately **not** a
		// `DayCountConvention`. A growth rate is not an accrual — no counterparty settles
		// on it, so no standard governs it. What it must do is be stable across the leap
		// years a multi-year span contains, and the mean year is what makes "2020 to 2025"
		// read as 5.0 rather than 5.003. ACT/365 would drift upward with every leap day in
		// the window; ACT/ACT would make the answer depend on *which* years they were.
		let daysPerYear = T(365) + T(1) / T(4)
		let years = days / daysPerYear

		// Delegating rather than repeating the formula is the fix for the second half of this
		// defect: the free function and this method disagreed on the same bad input — one
		// returned `+infinity` where the other returned `0` — because each screened its
		// arguments in its own way. There is now one screen, and it lives at the formula.
		// The module qualifier is load-bearing: unqualified `cagr` resolves to this method.
		return BusinessMath.cagr(beginningValue: startValue, endingValue: endValue, years: years)
	}

	// MARK: - Forecast Evaluation

	/// Calculates forecast error metrics by comparing this series (actual) against a forecast.
	///
	/// Computes standard forecast accuracy measures: RMSE, MAE, and MAPE.
	/// Only periods present in both series are included in the calculation.
	///
	/// - Parameter forecast: The forecasted time series to compare against.
	/// - Returns: Forecast error metrics including RMSE, MAE, MAPE, and comparison count.
	///
	/// ## Example
	/// ```swift
	/// let periods = Period.documentationQuarters
	/// let actual = TimeSeries(periods: periods, values: [100, 110, 120, 130])
	/// let forecast = TimeSeries(periods: periods, values: [98, 112, 118, 132])
	///
	/// let metrics = actual.forecastError(against: forecast)
	///
	/// print("RMSE: \(metrics.rmse.number(2))")
	/// print("MAE: \(metrics.mae.number(2))")
	/// print("MAPE: \(metrics.mape.percent(2))")
	///
	/// // Compare two forecast models
	/// let linearForecast = TimeSeries(periods: periods, values: [99, 109, 119, 129])
	/// let exponentialForecast = TimeSeries(periods: periods, values: [97, 111, 121, 134])
	///
	/// let model1Metrics = actual.forecastError(against: linearForecast)
	/// let model2Metrics = actual.forecastError(against: exponentialForecast)
	///
	/// let bestModel = model1Metrics.rmse < model2Metrics.rmse ? "Linear" : "Exponential"
	/// print("Best model: \(bestModel)")
	/// ```
	///
	/// ## Metrics Explanation
	///
	/// **RMSE (Root Mean Squared Error)**
	/// - Calculated as: sqrt(mean((actual - forecast)²))
	/// - Penalizes large errors more heavily due to squaring
	/// - Same units as the original data
	/// - Useful when large errors are particularly undesirable
	///
	/// **MAE (Mean Absolute Error)**
	/// - Calculated as: mean(|actual - forecast|)
	/// - Average magnitude of all errors
	/// - Same units as the original data
	/// - More robust to outliers than RMSE
	///
	/// **MAPE (Mean Absolute Percentage Error)**
	/// - Calculated as: mean(|actual - forecast| / |actual|)
	/// - Expressed as a percentage
	/// - Scale-independent, useful for comparing across different data scales
	/// - Excludes periods where actual value is zero
	///
	/// ## Notes
	/// - If the series have no overlapping periods, every metric is `.nan` with `count = 0`
	/// - If any overlapping observation is non-finite, every metric is `.nan` and `count`
	///   still reports the size of the overlap
	/// - MAPE calculation skips periods where actual value is zero to avoid division by zero,
	///   and is `.nan` — not `0` — when that leaves nothing to average
	/// - RMSE ≥ MAE always (equality only when all errors are identical)
	public func forecastError(against forecast: TimeSeries<T>) -> ForecastErrorMetrics<T> where T: BinaryFloatingPoint {
		var actualValues: [T] = []
		var forecastValues: [T] = []

		for period in periods {
			guard let actualValue = self[period],
				  let forecastValue = forecast[period] else { continue }
			actualValues.append(actualValue)
			forecastValues.append(forecastValue)
		}

		// Measured before this guard: two series with no period in common returned
		// `rmse = 0, mae = 0, mape = 0` — three perfect scores for a comparison that never
		// took place, and the model that overlapped nothing beat every model that did.
		guard !actualValues.isEmpty else {
			return ForecastErrorMetrics(rmse: T.nan, mae: T.nan, mape: T.nan, count: 0)
		}

		// Measured before this guard: a single `nan` actual returned `rmse = nan` alongside
		// `mape = 0.0` — one field of one value admitting the failure while the next denied
		// it with the best score MAPE can take. The cause was an explicit `isNaN ? .zero`
		// rewrite on `mape` only, which is gone; screening the pairs here is what makes the
		// three agree rather than leaving it to how each formula happens to propagate. An
		// infinite observation is screened for the same reason: it sends RMSE and MAE to
		// `+infinity` (a ranked, comparable score) while MAPE divides it out to `nan`.
		let pairsAreScoreable = actualValues.allSatisfy { $0.isFinite } && forecastValues.allSatisfy { $0.isFinite }
		guard pairsAreScoreable else {
			return ForecastErrorMetrics(rmse: T.nan, mae: T.nan, mape: T.nan, count: actualValues.count)
		}

		// `mape` is passed through unmodified. It is `.nan` when every actual was zero, which
		// is MAPE's domain being empty rather than the comparison failing — RMSE and MAE are
		// real measurements there, and the type's DocC says so.
		return ForecastErrorMetrics(
			rmse: rmse(actualValues, forecastValues),
			mae: mae(actualValues, forecastValues),
			mape: mape(actualValues, forecastValues),
			count: actualValues.count
		)
	}

	// MARK: - Moving Averages

	/// Calculates a simple moving average.
	///
	/// The window is `window` *periods* wide, not `window` observations wide. A window that
	/// spans a period the series does not contain is **omitted from the result** rather than
	/// closed up over the hole — see **Gaps in the period index** below.
	///
	/// - Parameter window: The number of periods in the moving window.
	/// - Returns: A time series of moving averages, defined only on the periods that end a
	///   complete, uninterrupted run of `window` periods.
	///
	/// ## Example
	/// ```swift
	/// let revenue = TimeSeries<Double>(
	///     periods: (1...12).map { Period.month(year: 2024, month: $0) },
	///     values: (1...12).map { 100.0 * Double($0) }
	/// )
	/// let smoothed = revenue.movingAverage(window: 3)
	/// // 10 results: Mar 2024 through Dec 2024.
	/// ```
	///
	/// ## Gaps in the period index
	/// A `TimeSeries` is keyed by period, so a month that was never recorded is simply absent
	/// from ``TimeSeries/periods`` — there is no hole to step over, only a shorter list.
	/// Measured on Jan, Feb, Apr, May with `window: 3`, the previous implementation averaged
	/// **Feb + Apr + May and labelled the answer May**: a three-month average of two months
	/// and a skipped one, reported with the same shape and the same label as a complete one.
	///
	/// Following ``TimeSeries/zip(with:_:)``, the fix narrows the domain instead of fabricating
	/// the missing observation: May has no three-period average, so the result does not
	/// contain May. `count` is what a caller checks, and it now tells the truth.
	///
	/// Adjacency is decided by ``Period/nextIfSteppable()``. Where it cannot be decided — a
	/// ``PeriodType/custom`` range has no defined successor, and two periods of different
	/// types have no common step — the periods are treated as adjacent, so an irregular
	/// series keeps exactly the behaviour it has always had rather than silently emptying.
	///
	/// ## Contaminated input
	/// A window containing a non-finite observation reports `.nan`, and the **next window that
	/// does not contain it reports a real average** — the contamination lasts exactly `window`
	/// positions, no more.
	///
	/// That is not what a running sum does by default. `windowSum = windowSum - oldValue`
	/// cannot subtract a `nan` back out (`nan - nan` is `nan`), so once one entered the sum
	/// every later average was `nan` for the rest of the series — measured as 9 of 14 outputs
	/// on a 4-wide window, the last one included, against the recomputing sibling
	/// `rollingStatistics(window:)` which gave 4 of 14 and recovered. The fix is to keep the
	/// unusable observation out of the sum and count it separately, so the state that survives
	/// is exact and eviction restores it exactly.
	///
	/// Infinities are counted the same way, against contract §3.6's default of leaving them
	/// alone, because they break this specific computation rather than merely ordering oddly:
	/// `+infinity - +infinity` is `nan`, so an infinity in a running sum degrades into
	/// permanent contamination on eviction exactly as a `nan` does.
	public func movingAverage(window: Int) -> TimeSeries<T> {
		guard window > 0 && window <= count else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []
		let runStarts = contiguousRunStarts()

		// Optimized sliding window approach: maintain running sum
		var windowSum = T.zero
		var windowCount = 0
		// Counted rather than summed. See **Contaminated input** — the eviction step cannot
		// subtract a non-finite value back out, so one is kept out of `windowSum` entirely and
		// tracked here instead; the count falls back to zero as the window passes, which is
		// what makes recovery exact rather than approximate.
		var windowNonFinite = 0

		// Initialize the first window
		for i in 0..<window {
			if i < periods.count, let value = self[periods[i]] {
				if value.isFinite {
					windowSum = windowSum + value
				} else {
					windowNonFinite += 1
				}
				windowCount += 1
			}
		}

		// First window result
		if windowCount == window, windowSpansNoGap(endingAt: window - 1, window: window, runStarts: runStarts) {
			let average: T
			if windowNonFinite > 0 {
				average = T.nan
			} else {
				average = windowSum / T(window)
			}
			resultPeriods.append(periods[window - 1])
			resultValues.append(average)
		}

		// Slide the window for remaining positions
		for i in window..<periods.count {
			// Remove the leftmost value from the window
			if let oldValue = self[periods[i - window]] {
				if oldValue.isFinite {
					windowSum = windowSum - oldValue
				} else {
					windowNonFinite -= 1
				}
				windowCount -= 1
			}

			// Add the new rightmost value to the window
			if let newValue = self[periods[i]] {
				if newValue.isFinite {
					windowSum = windowSum + newValue
				} else {
					windowNonFinite += 1
				}
				windowCount += 1
			}

			// Only add result if we have a full window
			if windowCount == window, windowSpansNoGap(endingAt: i, window: window, runStarts: runStarts) {
				let average: T
				if windowNonFinite > 0 {
					average = T.nan
				} else {
					average = windowSum / T(window)
				}
				resultPeriods.append(periods[i])
				resultValues.append(average)
			}
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	/// Calculates an exponential moving average.
	///
	/// EMA = alpha * current + (1 - alpha) * previous_EMA
	///
	/// - Parameter alpha: The smoothing factor (0 < alpha <= 1).
	/// - Returns: A time series of exponential moving averages.
	///
	/// ## Example
	/// ```swift
	/// let periods = Period.documentationQuarters
	/// let revenue = TimeSeries<Double>(
	///     periods: (1...12).map { Period.month(year: 2024, month: $0) },
	///     values: (1...12).map { 100.0 * Double($0) }
	/// )
	/// let ema = revenue.exponentialMovingAverage(alpha: 0.3)
	/// ```
	///
	/// ## Contaminated input
	/// A non-finite observation is **not smoothed in**. Its own period is reported as `.nan`,
	/// the smoothing state from before it is preserved untouched, and the next finite
	/// observation smooths from that state — so recovery is at the **very next period**, and
	/// the values from there on are bit-identical to smoothing the same series with the bad
	/// observation removed. Output still carries one entry per period.
	///
	/// Measured before that was true: the recursion feeds its own output back in, so one `nan`
	/// pinned `ema` at `nan` for the entire remainder of the series — a caller was told every
	/// month after the bad one was unusable, not just the month that was. There is nothing to
	/// subtract back out of an exponential average, which is why the fix has to be at the point
	/// the observation is folded in rather than at the point it is emitted.
	///
	/// The screen is on `isFinite` rather than on `isNaN` alone, matching
	/// ``AsyncDoubleExponentialSmoothingSequence``: an infinite state degrades into `nan` on the
	/// next step anyway, because `alpha * inf + (1 - alpha) * inf` is finite for no `alpha` and
	/// any later subtraction of like signs is `inf - inf`. Screening it here keeps the recovery
	/// guarantee true for both.
	///
	/// This says nothing about `alpha` itself, which is the caller's parameter rather than the
	/// caller's data: a non-finite `alpha` contaminates every period after the first and keeps
	/// doing so, which is a visibly wrong answer to a visibly wrong argument, not a silent one.
	public func exponentialMovingAverage(alpha: T) -> TimeSeries<T> {
		guard !isEmpty else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []
		// `nil` until the first usable observation, rather than a `T.zero` seed. The seed was
		// only ever correct because the first period always resolves; stating "no state yet"
		// directly is what lets a leading contaminated period be skipped and the *second*
		// period seed the average, instead of the second period being smoothed against a zero
		// nobody observed.
		var ema: T? = nil

		for period in periods {
			guard let value = self[period] else { continue }

			// Measured before this guard: `ema` is its own input, so one non-finite observation
			// made every later period `nan` too — the caller was told the whole tail of the
			// series was unusable rather than the single period that was, and no amount of
			// later clean data could clear it. An unusable observation is no evidence about the
			// level, so it is not folded into the state; the state from before it survives, the
			// next finite observation smooths from there, and this period is still emitted —
			// marked `.nan` — so the result keeps one entry per period (contract §3.5) rather
			// than handing back the previous average as though it had been re-measured.
			guard value.isFinite else {
				resultPeriods.append(period)
				resultValues.append(T.nan)
				continue
			}

			let smoothed: T
			if let previous = ema {
				let weighted: T = alpha * value
				let carried: T = (T(1) - alpha) * previous
				smoothed = weighted + carried
			} else {
				smoothed = value  // Initialize with the first usable observation
			}

			ema = smoothed
			resultPeriods.append(period)
			resultValues.append(smoothed)
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	// MARK: - Cumulative Operations

	/// Calculates the cumulative sum.
	///
	/// - Returns: A time series of cumulative sums.
	///
	/// ## Example
	/// ```swift
	/// let months = (0..<12).map { Period.month(year: 2025, month: $0 + 1) }
	/// let monthlyRevenue = TimeSeries(periods: months, values: (0..<12).map { 100.0 + Double($0) })
	///
	/// let ytd = monthlyRevenue.cumulative()  // Year-to-date
	/// ```
	///
	/// ## Contaminated input
	/// A non-finite observation contaminates its own period **and every period after it**, and
	/// that is correct rather than a defect of the kind ``exponentialMovingAverage(alpha:)`` and
	/// ``movingAverage(window:)`` carry. A running total genuinely contains every observation
	/// that preceded it; if one of them is unusable then the total is unusable, permanently and
	/// by definition. The two window operators recover because an observation eventually leaves
	/// their window — nothing ever leaves a cumulative sum, so there is no recovery to owe.
	public func cumulative() -> TimeSeries<T> {
		guard !isEmpty else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []
		var sum = T.zero

		for period in periods {
			guard let value = self[period] else { continue }
			// No screen here, deliberately — see **Contaminated input**. Propagating is the
			// answer, not the problem.
			sum = sum + value
			resultPeriods.append(period)
			resultValues.append(sum)
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	// MARK: - Differences

	/// Calculates period-over-period differences.
	///
	/// - Parameter lag: The number of periods to look back (default: 1). A `lag` outside
	///   `0...count` yields an empty series rather than trapping.
	/// - Returns: A time series of differences, one entry for every period from index `lag`
	///   onward **whose `lag`-predecessor is its calendar predecessor**. A difference involving
	///   a non-finite observation is `.nan` at that period and at that period only —
	///   subtraction is not a recursion, so nothing carries forward.
	///
	/// ## Gaps in the period index
	/// A period missing from the series is absent from ``TimeSeries/periods`` rather than
	/// present and empty, so `periods[i - lag]` is the adjacent element of the *sorted list*
	/// and not the calendar predecessor. On Jan, Feb, Apr, May with `lag: 1` the previous
	/// implementation reported `Apr - Feb` **under April's label** — a two-month change carried
	/// in a series of one-month changes, which any rate per unit time computed from it divides
	/// by the wrong denominator. The period is therefore omitted rather than answered, which is
	/// contract §3.7 and matches ``growthRate(lag:)`` and ``movingAverage(window:)``.
	///
	/// ## Example
	/// ```swift
	/// let periods = Period.documentationQuarters
	/// let revenue = TimeSeries<Double>(
	///     periods: (1...12).map { Period.month(year: 2024, month: $0) },
	///     values: (1...12).map { 100.0 * Double($0) }
	/// )
	/// let change = revenue.diff(lag: 1)  // Period-over-period change
	/// ```
	public func diff(lag: Int = 1) -> TimeSeries<T> {
		guard !isEmpty else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		// The same trap ``growthRate(lag:)`` carries this guard for: a negative `lag` indexes
		// before the start of `periods` and a `lag` past the end forms an inverted range, and
		// each stops the process rather than answering. `lag == 0` is deliberately still
		// admitted — it means "difference from itself", it is zero everywhere, and that is a
		// measurement rather than a fallback.
		guard lag >= 0, lag <= periods.count else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []
		let runStarts = contiguousRunStarts()

		for i in lag..<periods.count {
			let currentPeriod = periods[i]
			let previousPeriod = periods[i - lag]

			// See **Gaps in the period index**: without this the caller is handed a two-month
			// change labelled as a one-month change, indistinguishable from the genuine
			// one-month changes around it. `lag == 0` asks for a window of one, which no gap
			// can break, so "difference from itself" is unaffected.
			guard windowSpansNoGap(endingAt: i, window: lag + 1, runStarts: runStarts) else {
				continue
			}

			if let currentValue = self[currentPeriod],
			   let previousValue = self[previousPeriod] {
				let difference = currentValue - previousValue
				resultPeriods.append(currentPeriod)
				resultValues.append(difference)
			}
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	/// Calculates period-over-period percent changes.
	///
	/// Percent change is calculated as ((current - previous) / previous).
	///
	/// - Parameter lag: The number of periods to look back (default: 1).
	/// - Returns: A time series of percent changes. This is ``growthRate(lag:)`` under another
	///   name and inherits its contract exactly, including the `.nan` it reports for a zero
	///   base and the one-entry-per-period length invariant that goes with it.
	///
	/// ## Example
	/// ```swift
	/// let periods = Period.documentationQuarters
	/// let revenue = TimeSeries<Double>(
	///     periods: (1...12).map { Period.month(year: 2024, month: $0) },
	///     values: (1...12).map { 100.0 * Double($0) }
	/// )
	/// let pctChange = revenue.percentChange(lag: 1)
	/// ```
	public func percentChange(lag: Int = 1) -> TimeSeries<T> {
		let growth = self.growthRate(lag: lag)
		return growth.mapValues { $0 }
	}

	// MARK: - Rolling Window Operations

	/// Calculates a rolling sum over a fixed window.
	///
	/// The window is `window` *periods* wide, and a window spanning a period the series does
	/// not contain is omitted from the result — the same rule ``movingAverage(window:)``
	/// follows, and for a sum the stakes are higher: a trailing-twelve-months total built from
	/// eleven months is otherwise returned with the same shape, the same label and no
	/// diagnostic, and the missing month reads as a month of zero.
	///
	/// - Parameter window: The number of periods in the rolling window.
	/// - Returns: A time series of rolling sums, defined only on the periods that end a
	///   complete, uninterrupted run of `window` periods.
	///
	/// ## Example
	/// ```swift
	/// let revenue = TimeSeries<Double>(
	///     periods: (1...12).map { Period.month(year: 2024, month: $0) },
	///     values: (1...12).map { 100.0 * Double($0) }
	/// )
	/// let rolling3Month = revenue.rollingSum(window: 3)
	/// // 10 results: Mar 2024 through Dec 2024.
	/// ```
	///
	/// ## Contaminated input
	/// A window containing a non-finite observation reports `.nan`, and the next window that
	/// does not contain it reports a real total — see ``movingAverage(window:)``'s
	/// **Contaminated input** for the mechanism, which is the same running sum and the same
	/// impossibility of subtracting a `nan` back out of it.
	public func rollingSum(window: Int) -> TimeSeries<T> {
		guard window > 0 && window <= count else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []
		let runStarts = contiguousRunStarts()

		// Optimized sliding window approach: maintain running sum
		var windowSum = T.zero
		var windowCount = 0
		// Counted rather than summed, for the reason given in ``movingAverage(window:)``: an
		// eviction cannot subtract a non-finite value back out, so one never enters the sum.
		var windowNonFinite = 0

		// Initialize the first window
		for i in 0..<window {
			if i < periods.count, let value = self[periods[i]] {
				if value.isFinite {
					windowSum = windowSum + value
				} else {
					windowNonFinite += 1
				}
				windowCount += 1
			}
		}

		// First window result
		if windowCount == window, windowSpansNoGap(endingAt: window - 1, window: window, runStarts: runStarts) {
			let total: T
			if windowNonFinite > 0 {
				total = T.nan
			} else {
				total = windowSum
			}
			resultPeriods.append(periods[window - 1])
			resultValues.append(total)
		}

		// Slide the window for remaining positions
		for i in window..<periods.count {
			// Remove the leftmost value from the window
			if let oldValue = self[periods[i - window]] {
				if oldValue.isFinite {
					windowSum = windowSum - oldValue
				} else {
					windowNonFinite -= 1
				}
				windowCount -= 1
			}

			// Add the new rightmost value to the window
			if let newValue = self[periods[i]] {
				if newValue.isFinite {
					windowSum = windowSum + newValue
				} else {
					windowNonFinite += 1
				}
				windowCount += 1
			}

			// Only add result if we have a full window
			if windowCount == window, windowSpansNoGap(endingAt: i, window: window, runStarts: runStarts) {
				let total: T
				if windowNonFinite > 0 {
					total = T.nan
				} else {
					total = windowSum
				}
				resultPeriods.append(periods[i])
				resultValues.append(total)
			}
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	/// Calculates a rolling minimum over a fixed window.
	///
	/// The window is `window` *periods* wide, and a window spanning a period the series does
	/// not contain is omitted from the result — the same rule ``movingAverage(window:)``
	/// follows. An extremum is the one statistic a gap can leave looking entirely plausible:
	/// the minimum of two months is a real number in the right range, and nothing in the
	/// result would have said it was not the minimum of three.
	///
	/// - Parameter window: The number of periods in the rolling window.
	/// - Returns: A time series of rolling minimums, defined only on the periods that end a
	///   complete, uninterrupted run of `window` periods.
	///
	/// ## Example
	/// ```swift
	/// let revenue = TimeSeries<Double>(
	///     periods: (1...12).map { Period.month(year: 2024, month: $0) },
	///     values: (1...12).map { 100.0 * Double($0) }
	/// )
	/// let rollingMin = revenue.rollingMin(window: 3)
	/// // 10 results: Mar 2024 through Dec 2024.
	/// ```
	///
	/// ## Contaminated input
	/// A window containing a non-finite observation reports `.nan`; the window recomputes from
	/// scratch, so the next window that excludes it reports a real minimum.
	///
	/// This one is not a recursion defect — it is a silent drop. `Swift.min(a, b)` is
	/// `b < a ? b : a`, and every comparison against `nan` is false, so a `nan` arriving
	/// **after** the first observation is discarded and the window reports the minimum of the
	/// observations that happened to be usable, labelled as the minimum of `window` of them.
	/// A `nan` arriving **first** seeds `minValue` and then survives every later comparison, so
	/// the same contamination in the same window gave `nan` or a plausible finite extremum
	/// depending only on where in the window it landed. Contract §4 forbids the first of those
	/// — a value dropped from an aggregation because it matched no branch — and the two
	/// disagreeing is worse than either.
	public func rollingMin(window: Int) -> TimeSeries<T> {
		guard window > 0 && window <= count else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []
		let runStarts = contiguousRunStarts()

		// Optimized: iterate over indices directly without creating arrays
		for i in (window - 1)..<periods.count {
			guard windowSpansNoGap(endingAt: i, window: window, runStarts: runStarts) else { continue }

			var minValue: T? = nil
			var validCount = 0
			var windowHasNonFinite = false

			// Find minimum in current window
			for j in (i - window + 1)...i {
				if let value = self[periods[j]] {
					validCount += 1
					// Recorded rather than compared. See **Contaminated input**: handing this
					// to `Swift.min` reports the minimum of the *rest* of the window under the
					// window's own label, or not, depending on its position.
					guard value.isFinite else {
						windowHasNonFinite = true
						continue
					}
					if let currentMin = minValue {
						minValue = Swift.min(currentMin, value)
					} else {
						minValue = value
					}
				}
			}

			// Only add result if we have a full window. A short window is not reported at all:
			// an extremum over fewer periods than the label claims is the most plausible wrong
			// answer this file can produce, since it is a real number in the right range.
			guard validCount == window else { continue }
			if windowHasNonFinite {
				resultPeriods.append(periods[i])
				resultValues.append(T.nan)
			} else if let min = minValue {
				resultPeriods.append(periods[i])
				resultValues.append(min)
			}
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	/// Calculates a rolling maximum over a fixed window.
	///
	/// The window is `window` *periods* wide, and a window spanning a period the series does
	/// not contain is omitted from the result — the same rule ``movingAverage(window:)``
	/// follows. An extremum is the one statistic a gap can leave looking entirely plausible:
	/// the maximum of two months is a real number in the right range, and nothing in the
	/// result would have said it was not the maximum of three.
	///
	/// - Parameter window: The number of periods in the rolling window.
	/// - Returns: A time series of rolling maximums, defined only on the periods that end a
	///   complete, uninterrupted run of `window` periods.
	///
	/// ## Example
	/// ```swift
	/// let revenue = TimeSeries<Double>(
	///     periods: (1...12).map { Period.month(year: 2024, month: $0) },
	///     values: (1...12).map { 100.0 * Double($0) }
	/// )
	/// let rollingMax = revenue.rollingMax(window: 3)
	/// // 10 results: Mar 2024 through Dec 2024.
	/// ```
	///
	/// ## Contaminated input
	/// A window containing a non-finite observation reports `.nan`, and the next window that
	/// excludes it reports a real maximum — see ``rollingMin(window:)``'s **Contaminated
	/// input**, which describes the same position-dependent silent drop in `Swift.max`.
	public func rollingMax(window: Int) -> TimeSeries<T> {
		guard window > 0 && window <= count else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []
		let runStarts = contiguousRunStarts()

		// Optimized: iterate over indices directly without creating arrays
		for i in (window - 1)..<periods.count {
			guard windowSpansNoGap(endingAt: i, window: window, runStarts: runStarts) else { continue }

			var maxValue: T? = nil
			var validCount = 0
			var windowHasNonFinite = false

			// Find maximum in current window
			for j in (i - window + 1)...i {
				if let value = self[periods[j]] {
					validCount += 1
					// Recorded rather than compared, for the reason given in
					// ``rollingMin(window:)``: `Swift.max` discards it and reports the maximum
					// of the rest of the window under the window's own label.
					guard value.isFinite else {
						windowHasNonFinite = true
						continue
					}
					if let currentMax = maxValue {
						maxValue = Swift.max(currentMax, value)
					} else {
						maxValue = value
					}
				}
			}

			// Only add result if we have a full window. A short window is not reported at all:
			// an extremum over fewer periods than the label claims is the most plausible wrong
			// answer this file can produce, since it is a real number in the right range.
			guard validCount == window else { continue }
			if windowHasNonFinite {
				resultPeriods.append(periods[i])
				resultValues.append(T.nan)
			} else if let max = maxValue {
				resultPeriods.append(periods[i])
				resultValues.append(max)
			}
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}
}

// MARK: - Window Contiguity

extension TimeSeries {

	/// For each position in ``TimeSeries/periods``, the position at which its run of
	/// consecutive periods begins.
	///
	/// A window of `w` periods ending at `i` covers no gap exactly when its run began at or
	/// before `i - w + 1`, which makes the check `O(1)` per window and the whole scan `O(n)`.
	///
	/// - Returns: An array parallel to ``TimeSeries/periods``; `[0, 0, 2, 2]` means the series
	///   has a break between its second and third periods.
	fileprivate func contiguousRunStarts() -> [Int] {
		var starts = [Int](repeating: 0, count: periods.count)
		guard periods.count > 1 else { return starts }

		for i in 1..<periods.count {
			let adjacent = TimeSeries.periodsAreAdjacent(periods[i - 1], periods[i])
			starts[i] = adjacent ? starts[i - 1] : i
		}
		return starts
	}

	/// Whether the `window` periods ending at `index` are consecutive with no period missing
	/// between them.
	fileprivate func windowSpansNoGap(endingAt index: Int, window: Int, runStarts: [Int]) -> Bool {
		guard index >= 0, index < runStarts.count else { return false }
		let firstIndex = index - window + 1
		guard firstIndex >= 0 else { return false }
		return runStarts[index] <= firstIndex
	}

	/// Whether `later` is the period immediately following `earlier`.
	///
	/// Answers `true` whenever adjacency cannot be decided — a ``PeriodType/custom`` range has
	/// no defined successor, and two periods of different types have no common step. That
	/// direction is deliberate: the alternative would silently empty the result of every
	/// window operation on an irregular series, which is a far larger change than the gap
	/// defect this check exists to fix, and it would be just as unannounced.
	///
	/// Visible beyond this file because `averageTimeSeries` in the financial-statement layer
	/// has the same defect over the same pair of indices and must answer it the same way. A
	/// second copy of this rule is how two functions come to disagree about what a gap is.
	internal static func periodsAreAdjacent(_ earlier: Period, _ later: Period) -> Bool {
		guard earlier.type == later.type else { return true }
		guard let following = earlier.nextIfSteppable() else { return true }
		return following == later
	}
}
