# BioFeedbackKit + BusinessMath Streaming — Planning Handoff

## Context

This document captures the goal, architecture strategy, and specific gaps identified
during a design session. It is intended to bootstrap a planning and implementation
session in Claude Code.

-----

## Goal

Build **BioFeedbackKit**, a cross-platform Swift library that processes real-time
biofeedback data (primarily heart rate variability from devices like a Polar H10 or
EEG headband) and uses an algorithm to deliver feedback to users for managing HRV
and coherence state.

The library must run on **iOS, watchOS, visionOS, and Android** (via Swift 6.3’s
Android SDK). It is on-device sovereign — the full algorithm runs locally with no
server dependency for core function. Anonymized session data syncs to a backend
for algorithm improvement over time; the algorithm config (weights, thresholds) is
updatable OTA without an App Store release.

**BioFeedbackKit** depends on **BusinessMath**
(`https://github.com/jpurnell/BusinessMath`) for signal processing, statistics,
forecasting, anomaly detection, and optimization. Some work must be contributed
upstream to BusinessMath before BioFeedbackKit can be built cleanly. That upstream
work is the primary focus of this planning session.

-----

## Architecture Strategy

### Package Boundaries

```
BusinessMath               ← Mathematical primitives, algorithms, streaming ops
    Sources/BusinessMath/Streaming/   ← Already exists; gaps identified below

BioFeedbackKit             ← New library; depends on BusinessMath
    Devices/               ← BiofeedbackDevice protocol + adapters (Polar, Apple Watch, etc.)
    Signal/                ← RR buffering, HRV metrics (RMSSD, SDNN, pNN50), FFT wrapper
    Algorithm/             ← HRVAlgorithm protocol, CoreAlgorithm, AlgorithmConfig (OTA)
    Feedback/              ← FeedbackEvent emission (semantic, not prescriptive)
    Sync/                  ← Anonymized telemetry pipeline, OTA config fetch

Apps (iOS / watchOS / visionOS / Android)
    ← Thin platform shells consuming BioFeedbackKit via SwiftUI or JNI bridge
```

### Key Architectural Decisions

**On-device sovereign.** The algorithm runs fully offline after initial config fetch.
Sessions complete without any network dependency.

**OTA algorithm updates via config, not code.** The algorithm logic ships with the
app. A remote `AlgorithmConfig` (weights, thresholds, feature flags) is fetched and
persisted locally. This covers ~80% of algorithm improvement use cases without App
Store review cycles. A lightweight expression DSL is the stretch goal for more
flexible rule updates.

**Anonymization at the edge.** All PII is stripped or hashed in the library before
any data leaves the device. The sync layer never sees identifiable data.

**Algorithm version tagging.** Every synced session carries the `AlgorithmConfig`
version that produced it, enabling clean cohort separation when training on
aggregated data.

**Swift 6 strict concurrency throughout.** BusinessMath’s existing Streaming layer
is already Swift 6 compliant. BioFeedbackKit must match.

**Android via Swift 6.3 SDK.** The Swift core (BioFeedbackKit + BusinessMath) cross-
compiles to Android as a shared library. A thin Kotlin shell handles Android Activity
lifecycle, permissions, and BLE events, passing raw RR intervals up to Swift via
`swift-java` JNI. All algorithm logic is pure Swift.

-----

## BusinessMath Streaming — Current State

The existing `Sources/BusinessMath/Streaming/` folder contains six files:

|File                             |Contents                                                                                                                                                     |
|---------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|
|`AsyncValueStream.swift`         |`AsyncValueStream`, `AsyncGeneratorStream`, tumbling/sliding windows (count-based), `buffer(size:)`, `retry`, `catchErrors`, `throttle`                      |
|`StreamingStatistics.swift`      |Rolling and cumulative: mean, variance (Welford’s), stdDev, min, max, sum, EMA, comprehensive stats bundles                                                  |
|`StreamingComposition.swift`     |Merge, zip, combineLatest, withLatestFrom, debounce, sample, distinct, startWith, take/skip, timeout; `ThreadSafeBox` actor, `ContinuationBox` wrappers      |
|`StreamingForecasting.swift`     |SES, Holt’s double, Holt-Winters triple, moving average forecast, trend detection (linear regression), change point detection, forecast error (MAE/RMSE/MAPE)|
|`StreamingAnomalyDetection.swift`|CUSUM, EWMA control charts, z-score/IQR/MAD outlier detection, seasonal anomaly detection, composite anomaly scoring                                         |
|`DurationCompat.swift`           |`CompatDuration`, `CompatClock` — iOS 14+ and Linux-compatible duration/timing primitives                                                                    |

This is approximately **70% of what BioFeedbackKit needs** from BusinessMath.

-----

## Gaps to Fill in BusinessMath

These are listed in priority order. Items 1–4 are blockers for BioFeedbackKit. Items
5–6 are high-value additions that generalize well to other domains (trading, quality
control) and belong in BusinessMath rather than BioFeedbackKit.

-----

### Gap 1 — `Timestamped<T>` (foundational type)

**What it is:** A generic wrapper that pairs any value with a `ContinuousClock.Instant`
timestamp.

```swift
public struct Timestamped<Value: Sendable>: Sendable {
    public let value: Value
    public let timestamp: ContinuousClock.Instant
}
```

**Why it’s needed:** RR intervals are irregular — the time between heartbeats is
the signal, not a fixed sample rate. Tick data in trading is similarly irregular.
Without timestamps carried through the pipeline, time-based windowing and multi-rate
alignment are impossible.

**Suggested location:** `Streaming/Timestamped.swift`

**Generalizes to:** Any sensor or event stream with irregular timing. Trading ticks,
log events, IoT sensors, user interactions.

-----

### Gap 2 — Time-based windowing (explicitly deferred in code)

**What it is:** Window operators that group elements by elapsed time rather than
element count.

```swift
// Proposed API
device.rrIntervals
    .timestamped()                          // wrap each element with its arrival time
    .window(duration: .seconds(300))        // 5-minute tumbling windows
    .map { window in window.rmssd() }

device.rrIntervals
    .timestamped()
    .slidingWindow(duration: .seconds(300), stride: .seconds(1))
```

The code in `AsyncValueStream.swift` explicitly comments out `buffer(duration:)` with
the note “deferred to Phase 2.5.” This is that phase.

Both tumbling (non-overlapping) and sliding (overlapping with configurable stride)
variants are needed.

**Implementation note:** Requires `Timestamped<T>` (Gap 1). The window boundary logic
must handle irregular arrival rates correctly — a window closes when the elapsed
time since the first element exceeds the duration, not after a fixed element count.

**Suggested location:** Extend `AsyncValueStream.swift` or new
`AsyncTimeWindowedSequence.swift` within `Streaming/`.

**Generalizes to:** OHLC bar construction from tick data, time-bucketed revenue
aggregation, sensor data resampling.

-----

### Gap 3 — Successive difference operators

**What it is:** Streaming operators that compute statistics over successive differences
(i.e., the delta between consecutive elements), not the elements themselves.

```swift
// Proposed API extensions on AsyncSequence where Element == Double
.successiveDifferences()              // emits diff between each pair: [x1-x0, x2-x1, ...]
.rollingSuccessiveDifferenceRMS(window: Int)   // RMSSD: sqrt(mean(diff^2)) over window
.rollingThresholdExceedanceRate(window: Int, threshold: Double)  // pNN50-style
```

**Why it’s needed:**

- **RMSSD** (root mean square of successive differences) is the primary time-domain
  HRV metric. It cannot be expressed with current rolling operators without
  materializing the whole window manually each step.
- **pNN50** (percentage of successive differences > 50ms) requires threshold
  exceedance rate over differences.

**Implementation note:** `rollingSuccessiveDifferenceRMS` should use an incremental
accumulator (O(1) per sample) rather than recomputing over the full window buffer
each step. Track: running sum of squared differences, evict the oldest squared
difference when the window slides.

**Suggested location:** Extend `StreamingStatistics.swift`.

**Generalizes to:** Day-over-day revenue volatility, intraday price jitter,
production output consistency, any “rate of change” monitoring use case.

-----

### Gap 4 — Multi-rate stream alignment

**What it is:** An operator that aligns two `Timestamped` streams at different sample
rates, pairing each trigger element with the nearest (or interpolated) element from
the other stream.

```swift
// Proposed API
rrIntervals                                   // ~1 Hz, irregular
    .timestamped()
    .aligned(with: accelerometer.timestamped(), // 50 Hz
             strategy: .nearest)               // or .linearInterpolation
```

**Why it’s needed:** BioFeedbackKit needs to correlate HRV with motion artifacts
(accelerometer) and potentially respiration signals from other sensors. These streams
run at very different rates. `combineLatest` exists but has no alignment strategy —
it just emits whenever either stream updates, without temporal registration.

**Strategies to implement:** `.nearest` (snap to closest timestamp) and
`.linearInterpolation` (weighted blend). `.nearest` is sufficient for v1.

**Suggested location:** New `AsyncAlignedSequence.swift` within `Streaming/`, or
extend `StreamingComposition.swift`.

**Generalizes to:** Joining financial time series at different frequencies (daily
prices + intraday ticks), multi-sensor IoT fusion, combining user event logs with
server-side metrics.

-----

### Gap 5 — FFT / frequency domain on streams

**What it is:** A streaming operator that applies a Fast Fourier Transform to each
window of a timestamped stream, yielding power spectral density.

```swift
// Proposed API
rrIntervals
    .timestamped()
    .window(duration: .seconds(300))
    .fft()                                // yields FrequencySpectrum per window
    .map { spectrum in
        spectrum.power(in: 0.04...0.15)   // LF band
        / spectrum.power(in: 0.15...0.40) // HF band
    }
```

**Why it’s needed:** LF/HF ratio is a standard frequency-domain HRV metric. It
requires FFT over windowed RR intervals (resampled to a regular grid first).

**Implementation note:** This is the one gap that requires a dependency outside
BusinessMath — `vDSP` from Apple’s Accelerate framework (Darwin only). On Linux/
Android, a pure Swift FFT or a `vDSP`-compatible abstraction layer is needed.
Consider a `FFTBackend` protocol with a `vDSP` implementation for Darwin and a
fallback pure-Swift implementation for Linux/Android.

**Suggested location:** New `StreamingFrequencyDomain.swift` within `Streaming/`.

**Generalizes to:** Seasonality detection in revenue streams, dominant frequency
identification in any periodic business metric, signal filtering.

-----

### Gap 6 — Online/incremental rolling operators (performance)

**What it is:** The existing rolling statistics operators (mean, variance, stdDev)
recompute over the full buffer on every step — O(n) per element. For high-frequency
streams (50Hz+ sensors, trading ticks), this becomes a bottleneck.

The Welford implementation in `AsyncRollingVarianceSequence` is numerically stable
but still iterates the full window each step. A proper incremental variant would
maintain a running accumulator and evict the oldest element in O(1).

**Why it’s needed:** At 50Hz with a 300-sample window, the current approach does
15,000 additions per second just for rolling mean. At trading tick rates this is
worse. This is not a blocker for v1 at HRV rates (~1Hz), but is important for the
library’s general utility.

**Suggested location:** Either replace the existing implementations in
`StreamingStatistics.swift` or add incremental variants alongside.

**Note:** Gap 3’s `rollingSuccessiveDifferenceRMS` should be implemented with the
incremental pattern from the start.

-----

## BioFeedbackKit — What Stays Out of BusinessMath

The following belong in BioFeedbackKit, not BusinessMath. They are either
physiologically specific or app-layer concerns:

|Component                                                   |Reason it stays in BioFeedbackKit                                                          |
|------------------------------------------------------------|-------------------------------------------------------------------------------------------|
|`RRBuffer` — sliding window buffer for incoming RR intervals|Device-specific plumbing                                                                   |
|`HRVMetrics` — named RMSSD, SDNN, pNN50 computations        |Names and thresholds are physiological conventions (the 50ms in pNN50 is anatomy, not math)|
|LF/HF band definitions (0.04–0.15 Hz, 0.15–0.40 Hz)         |Physiological convention                                                                   |
|`CoherenceScorer` — MLR-based coherence score               |Domain algorithm                                                                           |
|`AlgorithmConfig` + OTA fetch logic                         |Product concern                                                                            |
|`BiofeedbackDevice` protocol + Polar/Apple Watch adapters   |Hardware abstraction                                                                       |
|`FeedbackEvent` emission                                    |Product concern                                                                            |
|Anonymized telemetry sync pipeline                          |Product concern                                                                            |

**The boundary:** BusinessMath owns the math. BioFeedbackKit owns the physiology
and product logic.

-----

## BusinessMath Dependency Map for BioFeedbackKit

|BioFeedbackKit component       |BusinessMath dependency                                                                  |
|-------------------------------|-----------------------------------------------------------------------------------------|
|`RRBuffer` → `HRVMetrics`      |`Timestamped<T>` (Gap 1), time-based windowing (Gap 2), successive difference ops (Gap 3)|
|Frequency domain HRV           |FFT streaming (Gap 5)                                                                    |
|Multi-sensor fusion            |Multi-rate alignment (Gap 4)                                                             |
|`CoherenceScorer`              |Multiple linear regression (existing, `MultipleLinearRegression`)                        |
|`ConfigOptimizer` (server-side)|Genetic algorithms (existing, GPU-accelerated)                                           |
|Session trend analysis         |`TimeSeries`, decomposition, forecasting (existing)                                      |
|Algorithm A/B validation       |Hypothesis testing (existing)                                                            |
|Artifact / noise detection     |CUSUM, composite anomaly scoring (existing)                                              |

-----

## Suggested Implementation Order

1. `Timestamped<T>` — unblocks everything time-based
1. `successiveDifferences()` + `rollingSuccessiveDifferenceRMS(window:)` — core HRV math
1. `rollingThresholdExceedanceRate(window:, threshold:)` — pNN50
1. Time-based windowing (tumbling + sliding) — requires `Timestamped<T>`
1. Multi-rate alignment — requires `Timestamped<T>` and time-based windowing
1. FFT streaming — requires time-based windowing; needs `vDSP` backend abstraction
1. Incremental rolling operators — performance pass, not a blocker

Items 1–4 are the minimum to begin building BioFeedbackKit’s `Signal/` layer.

-----

## Repository

**BusinessMath:** `https://github.com/jpurnell/BusinessMath`
Existing streaming code: `Sources/BusinessMath/Streaming/`
Swift 6.0+, iOS 14+ / macOS 13+ / watchOS 7+ / visionOS 1+ / Linux
Dependency: `swift-numerics` (`Real` protocol)

**BioFeedbackKit:** New package, not yet created.
