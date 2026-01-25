---

# Credit‑First Trading Copilot — LLM‑Implementable Plan (v1)

## 0. Purpose & Constraints

**Purpose**  
Build a consumer-facing, credit‑first trading copilot that:
- Maintains a live fundamental credit view of companies
- Detects disagreements between fundamentals and market pricing
- Proposes small, risk‑aware trades
- Requires explicit human approval for execution

**Primary User**
- Trained credit analyst
- Skeptical of equity valuation as signal
- Trades small lots with strict risk limits
- Values explainability and capital preservation

**Hard Constraints**
- No Bloomberg / institutional CDS feeds
- LLM must be able to reason over all steps
- Human-in-the-loop required for all trades
- System must be conservative under uncertainty

---

## 1. System Architecture (Conceptual)

```
Data Ingestion
   ↓
State Builders (Credit / Market / Equity / Risk)
   ↓
Disagreement Engine
   ↓
Trade Construction Engine
   ↓
Human Review Gate
   ↓
Execution Interface
   ↓
Post‑Trade Monitoring & Learning
```

Each block below maps to **explicit LLM tasks**.

---

## 2. Data Inputs (Explicit, Replaceable)

### 2.1 Fundamental / Accounting Data
- Quarterly financials (income, balance sheet, cash flow)
- Debt outstanding, maturities (from filings / summaries)
- Cash & equivalents
- Share count

**Update frequency:** Quarterly (LLM interpolates daily state)

---

### 2.2 Market Data (Daily)
- Equity price
- Equity realized volatility (20d, 60d)
- Equity implied volatility (ATM, skew if available)
- Risk‑free yield curve (UST)
- IG corporate spread indices (rating & duration buckets)
- Broad credit regime indicator (e.g., CDX IG proxy)

---

### 2.3 User‑Defined Parameters
- Max position size (% NAV)
- Max drawdown tolerance
- Tradable instruments (equity, options, ETFs)
- Sector / rating preferences
- Hard red flags (e.g., liquidity < X months)

---

## 3. Persistent Internal States (LLM‑Maintained)

The LLM must maintain and update **explicit state objects**.

---

### 3.1 Fundamental Credit State (FCS)

**Purpose:** Represent the analyst’s “would I lend to this company?” view.

**Components**
- Liquidity score
- Leverage score
- Coverage score
- FCF durability score
- Maturity risk score

**Output**
- Internal credit band: {Strong / Stable / Watch / Weak}
- Expected spread range (qualitative or numeric band)

**Rules**
- Changes slowly
- Cannot move more than one band per quarter unless explicit shock
- Must cite which fundamentals caused any change

---

### 3.2 Market‑Implied Credit State (MICS)

**Purpose:** Represent how markets are pricing credit risk.

**Components**
- Rating‑matched IG spread level (z‑score vs history)
- Peer‑relative spread positioning
- Macro credit regime (risk‑on / neutral / risk‑off)

**Output**
- Market stress level: {Low / Medium / High}
- Directional trend: {Tightening / Stable / Widening}

---

### 3.3 Equity Stress State (ESS)

**Purpose:** Use equity purely as a stress and timing sensor.

**Components**
- Realized volatility vs trailing median
- Implied volatility vs realized
- Skew steepness
- Drawdown velocity
- Correlation anomalies (equity vs rates / credit proxy)

**Output**
- Equity stress signal: {Calm / Elevated / Distressed}
- Confidence level (Low / Medium / High)

---

### 3.4 Risk Budget State (RBS)

**Purpose:** Enforce capital preservation.

**Components**
- Current exposure by asset
- Remaining risk budget
- Scenario loss estimates
- Liquidity constraints

**Output**
- Max allowable position size for new trades
- Trade eligibility: {Allowed / Reduce / Block}

---

## 4. Disagreement Engine (Core Logic)

**Trigger Condition**
- Fundamental Credit State ≠ Market‑Implied Credit State

---

### 4.1 Disagreement Classification

The LLM must classify into exactly one:

1. **Market Overpricing Risk**
   - Fundamentals strong/stable
   - Market stress elevated

2. **Market Underpricing Risk**
   - Fundamentals deteriorating
   - Market stress low

3. **Aligned**
   - No material disagreement

---

### 4.2 Actionability Filter

Before any trade consideration, the LLM must answer:

- Is the disagreement **material**?
- Is it **persistent** (not 1‑day noise)?
- Is risk budget available?

If any answer is “no” → **No trade proposal**.

---

## 5. Trade Construction Engine

**Principle:** Trade expresses a **credit thesis**, not an equity view.

---

### 5.1 Trade Thesis Object

Must include:
- Credit thesis (1–2 sentences)
- Evidence from FCS, MICS, ESS
- Explicit invalidation conditions

---

### 5.2 Instrument Selection Logic

If user can trade:
- Equity only → use equity as expression
- Options → prefer defined‑risk structures
- ETFs → sector / IG exposure if appropriate

LLM must justify instrument choice in credit terms.

---

### 5.3 Position Sizing

Inputs:
- Risk Budget State
- Equity stress level
- Worst‑case scenario loss

Rules:
- Size ≤ user max % NAV
- Size reduced if equity stress ≠ credit view
- No trade if worst‑case loss breaches drawdown tolerance

---

### 5.4 Trade Proposal Output (Structured)

The LLM must generate:

- Instrument
- Direction
- Size (% NAV)
- Rationale (credit‑first)
- Invalidation triggers
- Review cadence

---

## 6. Human Review Gate (Mandatory)

The LLM must pause and present:

- Full trade proposal
- Explicit question: **Approve / Modify / Reject**

No execution path without explicit approval.

---

## 7. Execution Interface (Non‑Autonomous)

Upon approval:
- Generate order ticket (symbol, size, limit/market)
- Log rationale and timestamp
- Await external confirmation

LLM does **not** send orders directly unless explicitly integrated.

---

## 8. Post‑Trade Monitoring

### 8.1 Continuous Thesis Monitoring

LLM must monitor:
- Changes in Fundamental Credit State
- Escalation in Market‑Implied Stress
- Equity stress exceeding confidence bounds

---

### 8.2 Alert Logic

Alerts must be:
- Thesis‑based, not price‑based
- Clearly explain *why* review is needed

---

## 9. Trade Review & Learning Loop

For every closed trade, generate:

- Credit thesis outcome: {Correct / Incorrect / Inconclusive}
- Timing assessment
- Risk management assessment

Store this to adjust:
- Which equity stress signals matter
- How conservative sizing should be for this user

---

## 10. LLM Behavior Rules (Non‑Negotiable)

- Prefer **no trade** over low‑confidence trade
- Always explain reasoning in credit language
- Never invent data
- Explicitly state uncertainty
- Degrade conservatively when data quality is weak

---

## 11. Upgrade Path Awareness

Every proxy must be tagged with:
- Institutional equivalent (e.g., CDS → Markit)
- Confidence penalty for proxy usage

---

## 12. Definition of “Success” (v1)

The system is successful if:
- It produces few but explainable trades
- It avoids large drawdowns
- A credit analyst trusts it as a thinking partner
- Upgrading data sources does not require redesign

---

**END OF PLAN**
