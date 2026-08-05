# StockOpt — Shopify Inventory Intelligence Platform

**Date:** 2026-05-08
**Status:** ACTIVE — Project initiated, June 2026 MVP target
**Authors:** Justin Purnell
**Project:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/StockOpt`

---

## Executive Summary

Shopify is sunsetting Stocky (its free inventory management app) on August 31, 2026. Thousands of POS Pro merchants are being forced into third-party solutions — and the features they're angriest about losing (demand forecasting, auto-generated PO suggestions, reorder points) have **no native replacement**.

StockOpt is a Shopify embedded app that replaces every Stocky feature merchants are losing, then upgrades the analytics with BusinessMath's quantitative engine: Holt-Winters seasonal forecasting, Monte Carlo uncertainty quantification, profitability decomposition, and cash flow modeling.

**Go-to-market strategy:** Launch a free Stocky Migration Package by June 2026 with a 4–6 month free trial. Merchants run StockOpt alongside Stocky through the summer, building confidence before Stocky dies August 31. The free trial ends October–December — right before holiday season, when merchants are most dependent on forecasting. Conversion is organic.

**Longer-term vision:** The Shopify analytics market is fragmented across 3–4 point solutions ($300–$800/month combined). No app connects demand forecasting, profitability, marketing attribution, and cash flow planning. StockOpt starts as a Stocky replacement and grows into the unified analytics platform. Partnership with Akikumo (merchandising intelligence) remains an option from a position of strength.

---

## 1. Market Opportunity

### 1.1 Market Size

| Metric | Value | Source |
|--------|-------|--------|
| Shopify platform revenue (2025) | $11.56B (30% YoY growth) | Shopify earnings |
| Apps in ecosystem | 11,000+ | Shopify App Store |
| Merchants using apps | 87% of all Shopify stores | Branvas 2026 |
| Average apps per merchant | 6 | Uptek 2026 |
| TrueProfit installs alone | 70,000+ stores, $98B tracked revenue | TrueProfit |
| Combined analytics tool spend | $300–$800/month per merchant | Market survey |

### 1.2 Target Segment

**Primary:** DTC brands on Shopify at $1M–$50M annual revenue

This segment is large enough to need quantitative tools but too lean to hire dedicated analysts:

| Revenue Stage | Typical Team | Analyst Headcount | Tool Budget |
|---------------|-------------|-------------------|-------------|
| $1M–$3M | Founder + generalist | 0 | $100–$300/mo |
| $3M–$8M | 5–8 people, ops coordinator | 0 | $300–$600/mo |
| $8M–$20M | 10–20 people | 0–1 (often fractional) | $500–$1,200/mo |
| $20M–$50M | 20–50 people | 1–2 dedicated | $1,000–$3,000/mo |

A demand planner costs $82K/year ($61K–$109K). A fractional CFO runs $3K–$10K/month. Our platform replaces both at a fraction of the cost.

### 1.3 Timing Catalysts

1. **Stocky sunset (Aug 2026):** Shopify is killing its own inventory management app, forcing POS Pro merchants into third-party tools. This is a one-time migration event.
2. **Rising CAC:** Customer acquisition costs are up 40–60% since 2023. Brands need to optimize spend, not just track it.
3. **ROAS compression:** Average ecommerce ROAS fell to 2.87 in 2025 (median 2.04). Half of all ecommerce businesses operate below 2:1. The margin for error is gone.
4. **GraphQL mandate:** All new Shopify apps must use GraphQL as of April 2025. Older apps face technical debt.

---

## 2. Competitive Landscape

### 2.1 Category Map

The market is split into four non-overlapping categories. No app spans all four.

```
                    BACKWARD-LOOKING          FORWARD-LOOKING
                    (What happened?)          (What should we do?)

INVENTORY     ┌──────────────────────┐   ┌──────────────────────┐
              │ Akikumo              │   │ Inventory Planner    │
              │ (merchandising       │   │ Prediko              │
              │  intelligence)       │   │ Fabrikator           │
              └──────────────────────┘   └──────────────────────┘

FINANCIAL     ┌──────────────────────┐   ┌──────────────────────┐
              │ TrueProfit           │   │                      │
              │ BeProfit             │   │  ← NOBODY IS HERE →  │
              │ Lifetimely           │   │                      │
              └──────────────────────┘   └──────────────────────┘

MARKETING     ┌──────────────────────┐   ┌──────────────────────┐
              │ Triple Whale         │   │                      │
              │ Lebesgue             │   │  ← NOBODY IS HERE →  │
              │                      │   │                      │
              └──────────────────────┘   └──────────────────────┘
```

**The gap is the right half.** Every existing app tells you what happened. None tells you what to do about it with quantitative rigor.

### 2.2 Competitor Detail

#### Inventory Forecasting

| App | Price | Installs | Strengths | Weaknesses |
|-----|-------|----------|-----------|------------|
| **Inventory Planner (Sage)** | $245–$599/mo | ~800 reviews | Market leader, PO automation, multi-location | Expensive, acquired by Sage (enterprise drift), no financial modeling |
| **Prediko** | From $119/mo | ~200 reviews (5.0★) | Best UX, AI-native, growing fast | New, no profitability layer, limited integrations |
| **Fabrikator** | $99–$749/mo | ~150 reviews | SKU-level forecasting, backorder mgmt | No financial integration |
| **Forthcast** | $19.99/mo | Newer | Budget pricing | Limited feature set |

#### Financial Analytics

| App | Price | Installs | Strengths | Weaknesses |
|-----|-------|----------|-----------|------------|
| **TrueProfit** | From $25/mo | 70K+ | Largest install base, real-time P&L, autopilot costs | Known PayPal fee bug, no forecasting, no inventory link |
| **BeProfit** | $49–$450/mo | ~600 reviews | Multi-channel | Ad attribution is UTM-only (massively inflates profit) |
| **Lifetimely** | Free–$149/mo | Good adoption | LTV + profit combined, cohort analysis | No forecasting, no inventory |

#### Marketing Intelligence

| App | Price | Installs | Strengths | Weaknesses |
|-----|-------|----------|-----------|------------|
| **Triple Whale** | $149–$219/mo | ~700 reviews | DTC attribution standard, Triple Pixel, MMM | 4.3★ (lowest-rated leader), expensive, no inventory link |
| **Lebesgue** | Free–$299/mo | ~500 reviews | AI copilot, competitor benchmarking, high satisfaction | No financial modeling |

#### Merchandising

| App | Price | Installs | Strengths | Weaknesses |
|-----|-------|----------|-----------|------------|
| **Akikumo** | Unknown | Early stage | Unified merchandising view, ops+marketing bridge, experienced founders | No quantitative engine, no forecasting, early traction |

### 2.3 Universal Weaknesses (What Everyone Gets Wrong)

These pain points appear across reviews in every category:

1. **Broken ad attribution:** BeProfit only counts UTM-attributable spend. Triple Whale's pixel conflicts with GA4. No app handles Performance Max. Merchants distrust all profit numbers.
2. **COGS accuracy gap:** Most apps miss shipping costs, payment processing fees (2.5–3%), refunds, subscription fees, and exchange rate fluctuations between order and payout dates.
3. **No unified view:** Inventory, profit, and marketing live in separate apps. Merchants run 8–12 SaaS tools and still export to spreadsheets for the integrated view.
4. **Manual data entry persists:** Ad spend from Meta, Google, TikTok must be manually pulled and correlated. 10–15 hours/week of CSV workflow introduces 15–20% reporting variance.
5. **No CLV-to-channel linkage:** Customer lifetime value is never connected to acquisition channels automatically.
6. **Manufacturing blind spots:** Retail replenishment only — no production planning, BOM, or lead-time modeling.

---

## 3. The Problem We Solve

### 3.1 DTC Scaling Pain Points (Data-Backed)

| Problem | Impact | Current Solution |
|---------|--------|-----------------|
| **Cash flow timing** | 68% of DTC loan applicants denied; cash conversion cycle 60–90 days | Spreadsheets, prayer |
| **Stockouts** | 25–30% of peak-season revenue lost; 52% of $818B global inventory distortion | Reactive alerts (Akikumo, Stockie) |
| **Overstock** | Carrying costs 20–30% of inventory value; 44% of distortion cost | Gut-feel ordering |
| **Marketing waste** | ROAS median 2.04; Meta CPMs up 19% YoY; frequency >3x drops ROAS 20%+ | Triple Whale dashboards (backward-looking) |
| **Tool fragmentation** | $200K–$850K/year on BI stack; 10–15 hrs/week CSV exports | No solution |
| **Scaling death zone** | 73% of brands that reach $10M fail before $50M | No solution |

### 3.2 Our Thesis

**The 73% failure rate between $10M and $50M is not a marketing problem — it's a financial modeling problem.** These brands have product-market fit. They fail because they can't model the cash flow impact of inventory decisions, can't optimize marketing spend allocation, and can't forecast demand with statistical rigor.

Every tool in the market gives them a dashboard. None gives them a financial model.

---

## 4. Product Vision

### 4.1 Platform Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    MERCHANT DASHBOARD                           │
│  (Shopify Embedded App — Polaris + App Bridge)                 │
├──────────┬──────────┬──────────┬──────────┬────────────────────┤
│ Product  │ Inventory│ Marketing│ Cash Flow│ Scenario           │
│ Intel    │ Forecast │ Optimize │ Forecast │ Planner            │
├──────────┴──────────┴──────────┴──────────┴────────────────────┤
│              BUSINESSMATH ANALYTICS ENGINE                      │
│  ┌──────────┐ ┌───────────┐ ┌──────────┐ ┌──────────────────┐ │
│  │Holt-     │ │Monte Carlo│ │Portfolio │ │Three-Statement   │ │
│  │Winters   │ │Simulation │ │Optimizer │ │Financial Model   │ │
│  │Forecast  │ │Engine     │ │(Spend    │ │(P&L → BS → CF)   │ │
│  │          │ │           │ │Allocation│ │                  │ │
│  └──────────┘ └───────────┘ └──────────┘ └──────────────────┘ │
│  ┌──────────┐ ┌───────────┐ ┌──────────┐ ┌──────────────────┐ │
│  │A/B Test  │ │Seasonal   │ │Anomaly   │ │Sensitivity       │ │
│  │Stats     │ │Decomp     │ │Detection │ │Analysis          │ │
│  └──────────┘ └───────────┘ └──────────┘ └──────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│              DATA INTEGRATION LAYER                             │
│  Shopify GraphQL + Bulk Ops │ Meta Ads API │ Google Ads API   │
│  Merchant-supplied COGS     │ 3PL / WMS    │ Payment processor│
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Feature Modules

#### Module 1: Product Intelligence (Akikumo Feature Parity)
Replicate Akikumo's core merchandising visibility:
- Collection performance tracking
- Product/variant-level analytics
- Underperforming SKU identification
- Wasted ad spend alerts (ads running for OOS products)

*BusinessMath components:* `descriptive_stats_extended`, `calculate_profit_margin`, `detect_anomalies`

**Why clone this:** It's table-stakes visibility that every merchant needs. Building it ourselves means we own the full data pipeline and don't depend on a partner's roadmap. If we partner instead, this module is what Akikumo contributes.

#### Module 2: Demand Forecasting & Reorder Engine
Go beyond alerts to prescriptive purchasing:
- SKU-level demand forecasting with confidence intervals
- Seasonal decomposition (auto-detect holiday, back-to-school, etc.)
- Optimal reorder quantities with safety stock
- Purchase order generation with lead-time awareness
- Stockout probability alerts (not just "low stock" — "82% chance of stockout in 14 days")

*BusinessMath components:* `holt_winters_forecast`, `calculate_seasonal_indices`, `forecast_with_seasonality`, `detect_anomalies`, `run_monte_carlo`

**Differentiation:** Existing tools forecast demand. We forecast demand *with uncertainty quantification* — confidence intervals and probability distributions, not point estimates. A merchant sees "order 500 units (90% CI: 420–610)" instead of "order 500 units."

#### Module 3: True Profitability Engine
Accurate, all-in profit by SKU, by channel, by customer cohort:
- Revenue minus COGS, shipping, payment processing fees (2.5–3%), returns, ad attribution
- DuPont decomposition at the SKU level (margin × turnover × leverage)
- Customer LTV tied to acquisition channel
- Pareto analysis (which 20% of SKUs drive 80% of profit?)

*BusinessMath components:* `create_income_statement`, `calculate_dupont_3way`, `calculate_profit_margin`, `calculate_roi`, `calculate_ecommerce_metrics`, `calculate_saas_metrics`

**Differentiation:** TrueProfit tracks costs. We decompose *why* profitability varies — is it margin, turnover, or leverage? DuPont analysis at SKU level is enterprise-grade finance that no Shopify app offers.

#### Module 4: Marketing Spend Optimizer
Move from "what happened" to "where should the next dollar go":
- Channel-level ROAS tracking with proper attribution
- Budget allocation optimization across Meta, Google, TikTok, email
- Diminishing returns modeling (frequency saturation curves)
- Campaign simulation ("what if we shift 20% of Meta spend to TikTok?")

*BusinessMath components:* `optimize_capital_allocation`, `calculate_efficient_frontier`, `sensitivity_analysis`, `run_monte_carlo`, `tornado_analysis`

**Differentiation:** Triple Whale shows you ROAS. We solve for the *optimal allocation* — treating ad channels as a portfolio and maximizing return at a given risk tolerance. This is how hedge funds allocate capital, applied to ad spend.

#### Module 5: Cash Flow Forecasting & Scenario Planner
The killer feature no one else has:
- Forward-looking P&L → Balance Sheet → Cash Flow projection
- "What if" scenario modeling: "If we place a $200K PO and ROAS drops 20%, when do we run out of cash?"
- Cash conversion cycle tracking and optimization
- Seasonal cash flow patterns with Monte Carlo confidence bands
- Financing decision support (loan vs. revenue-based financing vs. equity)

*BusinessMath components:* `create_cash_flow_statement`, `scenario_financial_statements`, `calculate_cash_conversion_cycle`, `run_scenario_analysis`, `run_monte_carlo`, `compare_financing_options`, `calculate_working_capital`

**Differentiation:** This is the module that could save the 73% of brands that die between $10M and $50M. No Shopify app connects inventory decisions to cash flow impact. We turn "should we order more inventory?" into "here's what happens to your cash position in each scenario."

### 4.3 Data Architecture Constraints

| Data Source | Access Method | Limitation | Mitigation |
|-------------|--------------|------------|------------|
| Shopify orders | GraphQL Bulk Operations | Default 60-day limit; `read_all_orders` requires approval | Apply during app review; bulk sync on install |
| Shopify inventory | GraphQL `read_inventory` | Multi-location complexity | Aggregate across locations with per-location drill-down |
| Product COGS | `cost_per_item` field | Merchant must enter; often missing | Onboarding wizard prompts for COGS; estimate from margins |
| Ad spend (Meta) | Meta Marketing API | Requires merchant OAuth to Meta | Optional integration; manual entry fallback |
| Ad spend (Google) | Google Ads API | Same | Same |
| Payment fees | Shopify Payments API or manual | Varies by processor | Default to 2.9% + $0.30; let merchant override |
| Shipping costs | Order data or carrier API | Actual vs. estimated diverge | Reconcile monthly from order fulfillment data |

**Critical constraint:** Shopify does not expose comprehensive financial data. True profitability requires merchant-supplied COGS and optional ad platform integrations. The onboarding experience must make data entry painless or the product fails at activation.

---

## 5. Pricing Strategy

### 5.1 Competitive Pricing Landscape

| Solution Stack | Monthly Cost | What You Get |
|----------------|-------------|--------------|
| Prediko + TrueProfit + Triple Whale | $293–$567/mo | Forecasting + profit + attribution (3 apps, 3 logins, no integration) |
| Inventory Planner + BeProfit + Lebesgue | $373–$1,148/mo | Forecasting + profit + marketing (3 apps, enterprise-tier) |
| Our platform (proposed) | $149–$499/mo | All five modules, unified, with financial modeling |

### 5.2 Proposed Tiers

| Tier | Price | Target | Modules | Order Volume |
|------|-------|--------|---------|-------------|
| **Starter** | $49/mo | $0–$500K revenue | Product Intel + Profitability | Up to 1,000 orders/mo |
| **Growth** | $149/mo | $500K–$5M revenue | + Demand Forecasting + Marketing | Up to 5,000 orders/mo |
| **Scale** | $299/mo | $5M–$20M revenue | + Cash Flow + Scenarios | Up to 20,000 orders/mo |
| **Enterprise** | $499/mo | $20M+ revenue | All modules + API access + custom models | Unlimited |

**Billing:** Must use Shopify Billing API (app store requirement). 14-day free trial (industry standard is 7–30 days).

### 5.3 Revenue Projections (Conservative)

Assumptions: 500 installs in Year 1, 40% convert from trial, 5% monthly churn, average $180/mo blended ARPU.

| Quarter | Paying Merchants | MRR | ARR |
|---------|-----------------|-----|-----|
| Q1 | 50 | $9,000 | $108K |
| Q2 | 120 | $21,600 | $259K |
| Q3 | 200 | $36,000 | $432K |
| Q4 | 280 | $50,400 | $605K |
| Year 2 (exit rate) | 600 | $108,000 | $1.3M |

---

## 6. Strategic Options

### 6.1 Option A: Build Independently

**Approach:** Build all five modules ourselves. Clone Akikumo's merchandising layer as Module 1 (table-stakes feature), then differentiate with Modules 2–5.

| Pros | Cons |
|------|------|
| Full control over roadmap and pricing | Longer time to market (6–9 months for MVP) |
| Own the entire value chain | Must build merchandising UX from scratch |
| No revenue sharing | No existing customer base at launch |
| Can optimize the full data pipeline | Competing with a friend |

**Estimated timeline:** 6–9 months to MVP (Modules 1–2), 12–15 months for full platform.

### 6.2 Option B: Partner with Akikumo

**Approach:** Akikumo contributes Module 1 (merchandising intelligence) and their existing customer base. We contribute Modules 2–5 (the quantitative engine). Joint product, co-branded or white-labeled.

| Pros | Cons |
|------|------|
| Faster to market (3–4 months for integration) | Revenue sharing reduces margins |
| Existing customers migrate to joint platform | Dependency on partner's roadmap and reliability |
| Complementary strengths (UX + engine) | Decision-making friction on priorities |
| Founders have enterprise pedigree (NBC, Amazon, GameStop, FIGS) | If partnership dissolves, we lose Module 1 |

**Integration model:** Akikumo's frontend calls BusinessMath's engine via API (or MCP). Their existing merchants get "upgraded" with forecasting, optimization, and cash flow — a retention and upsell play for Akikumo, a distribution channel for us.

**Migration path:** Existing Akikumo customers see new "Advanced Analytics" modules appear in their dashboard. No reinstall, no data loss. For customers who came through us, they get the merchandising layer included.

### 6.3 Option C: Hybrid — Build with Partnership Optionality

**Approach:** Build all five modules ourselves but architect Module 1 as a swappable layer. If Akikumo wants to partner, their merchandising component plugs into our platform. If not, our own Module 1 ships.

| Pros | Cons |
|------|------|
| No dependency on partnership outcome | Slightly more engineering effort (abstraction layer) |
| Partnership becomes a growth accelerator, not a requirement | Must build Module 1 regardless (as fallback) |
| Akikumo can evaluate the partnership based on a working product | |
| Preserves friendship regardless of business outcome | |

**Recommended.** This is the lowest-risk path. Build the platform, offer Akikumo a partnership from a position of strength, and don't tie your timeline to their decision.

---

## 7. Technical Architecture

### 7.1 Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| **Analytics engine** | BusinessMath (Swift) running as API service | Existing library, battle-tested, 4,900+ tests |
| **API layer** | BusinessMath MCP server or REST API | MCP already exists; REST wrapper straightforward |
| **Web frontend** | Shopify App Bridge + Polaris (React) | Required for embedded apps; Polaris is Shopify's design system |
| **Data pipeline** | Node.js or Python Shopify app (OAuth, webhooks, bulk sync) | Shopify's app ecosystem is JS/Python-native |
| **Database** | PostgreSQL | Time-series order data, merchant configs, forecast cache |
| **Hosting** | Fly.io or Railway | Low-ops, auto-scaling, good for early-stage |

### 7.2 Data Flow

```
Shopify Store → Webhooks (real-time) ──→ Data Pipeline ──→ PostgreSQL
                                                              │
Shopify Store → Bulk Operations (daily sync) ─────────────────┘
                                                              │
                                                              ▼
                                                     BusinessMath API
                                                     (forecast, optimize,
                                                      simulate, model)
                                                              │
                                                              ▼
                                                     Embedded Dashboard
                                                     (Polaris + App Bridge)
```

### 7.3 Shopify API Constraints & Mitigations

| Constraint | Impact | Mitigation |
|------------|--------|------------|
| `read_all_orders` scope requires approval | Can't access full order history without it | Apply during initial app review; degrade gracefully (60-day forecasts) until approved |
| GraphQL rate: 50 pts/sec (standard) | Initial sync takes hours for large stores | Use Bulk Operations (async, no rate limit); incremental sync via webhooks after |
| No native ad spend data | Can't calculate true ROAS without external APIs | Meta + Google API integrations; manual entry fallback |
| Shopify Billing API required | Can't use Stripe or custom billing | Build on Shopify's billing from day one |
| GDPR webhooks mandatory | Must handle data deletion requests | Implement `customers/redact`, `shop/redact` handlers |

---

## 8. Stocky Migration Strategy

### 8.1 The Opportunity

Shopify is sunsetting Stocky on August 31, 2026 (delisted Feb 2, 2026). Merchants are losing features they describe as "90% of the lift" — particularly demand forecasting, auto-PO generation, and reorder points. Community sentiment is deeply frustrated. Supplier records and historical data cannot even be exported.

### 8.2 Stocky Feature Parity Matrix

**Features Shopify Native Now Covers (we don't rebuild):**
- Basic PO creation & receiving
- Inventory transfers between locations
- Manual stock adjustments (incl. barcode scanning)
- Supplier records (create, assign to POs)
- Low-stock alerts (via Shopify Flow)
- Inventory history tracking
- Bin location assignment

**Gaps We Fill (Stocky features with no replacement):**

| Lost Stocky Feature | StockOpt Replacement | Enhancement |
|---------------------|---------------------|-------------|
| Demand forecasting (velocity-based) | Holt-Winters seasonal forecasting | Confidence intervals, Monte Carlo uncertainty bands |
| Auto-generated PO suggestions | Statistical PO recommendations | Safety stock calculations, lead-time awareness |
| Reorder points / min-max thresholds | Dynamic reorder engine | Adjusts for seasonality and demand variance |
| Supplier lead-time tracking | Lead-time-aware reordering | Variability buffers, supplier performance scoring |
| Cost-price auto-update on receiving | Auto-sync COGS on receipt | Cost trend tracking over time |
| PO spend-by-supplier reporting | Supplier analytics dashboard | Spend tracking, lead-time performance, reliability |
| Barcode scanner receiving | Web-based camera barcode scanning | Works on phone/tablet without POS hardware |
| Separate receiver documents | Receiver docs with variance tracking | Ordered vs. received discrepancy alerts |
| CSV import for PO line items | CSV/Excel import with validation | Error checking, duplicate detection |
| Label printing (Dymo) | Native label generation | Multiple printer support |
| Weekly inventory email reports | Scheduled reports | Trend analysis, anomaly alerts |
| SKU-level profit margins | DuPont profitability decomposition | Margin × turnover analysis, Pareto identification |

**Capabilities Stocky Never Had (StockOpt upgrades):**
- Stockout probability alerts ("82% chance of stockout in 14 days")
- Seasonal pattern auto-detection (holiday, back-to-school, etc.)
- Anomaly detection (unusual sales spikes/drops)
- Scenario planning ("what if we order 2x for holiday?")
- Cash flow impact modeling tied to inventory decisions
- Marketing waste alerts (ads running for OOS products)
- Multi-location demand-based allocation optimization

### 8.3 Migration Timeline & Free Trial

```
May 2026     ── Build MVP (Stocky Migration Package)
June 2026    ── Launch with 4-6 month free trial
                Merchants install StockOpt alongside Stocky
                Run both in parallel, compare results
June-Aug     ── Parallel operation period
                Merchants validate forecasts against Stocky
                Stocky data import tool available
Aug 31       ── Stocky dies
                Merchants already confident in StockOpt
                No panic migration — they've been using it for 2+ months
Oct-Dec      ── Free trial ends (configurable per cohort)
                Holiday season: peak forecasting dependency
                Conversion pressure is organic, not pushy
Jan 2027     ── Paid tiers active
                Modules 3-5 available for upsell
```

**Why 4–6 months free:** Merchants need to run both systems in parallel to build trust. Once they see confidence intervals and seasonal decomposition vs. Stocky's linear velocity, they won't go back. The trial ending before holiday season creates natural conversion urgency.

### 8.4 Stocky Data Import

Before August 31, merchants can export from Stocky:
- Purchase order history (CSV)
- Stocktake records
- Product cost data

**Cannot be exported from Stocky (data loss risk):**
- Supplier records (must be recreated manually)
- Historical transfer data
- Vendor lead-time settings

StockOpt provides a **Stocky Import Wizard** that:
1. Ingests Stocky CSV exports (POs, costs)
2. Prompts merchant to re-enter supplier info (guided flow)
3. Reconstructs lead-time baselines from Shopify order/fulfillment history
4. Validates imported data against live Shopify inventory

### 8.5 Distribution Channels

| Channel | Cost | Expected Impact |
|---------|------|-----------------|
| Shopify App Store organic | Free (Shopify takes 0% on first $1M/year) | Primary discovery channel |
| **"Migrate from Stocky" landing page** | Time | **#1 acquisition channel** — SEO for "Stocky alternative" |
| Shopify Community forums | Time | Respond directly to Stocky sunset threads |
| DTC Twitter/X + LinkedIn content | Time | Thought leadership on inventory science |
| Akikumo partnership (if pursued) | Revenue share | Warm leads, existing trust |
| Shopify Partner program | Free | Co-marketing, featured placement |

**Key insight:** Shopify takes **0% revenue share** on the first $1M/year in app revenue.

### 8.6 Content Strategy

Lead with the Stocky migration pain, then educate on what's possible:
- "Stocky Is Dead. Here's What You're Actually Losing (and How to Get It Back)"
- "Your Reorder Points Are Guesses. Here's What Statistical Forecasting Looks Like"
- "The Cash Flow Trap: Why Profitable Shopify Brands Go Broke"
- "The $82K Question: Do You Need a Demand Planner or an Algorithm?"

---

## 9. Risk Analysis

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Shopify builds native analytics (again) | Medium | High | Differentiate on financial modeling depth; Shopify has historically killed its own analytics tools |
| `read_all_orders` scope denied | Low | High | App functions with 60-day data; reapply with usage metrics |
| Merchants won't enter COGS data | High | Medium | Estimate from industry benchmarks; incentivize with "profit unlock" gating |
| Forecast accuracy insufficient with limited data | Medium | Medium | Require 90+ days of order history; honest confidence intervals |
| Prediko or Inventory Planner adds financial modeling | Medium | Medium | Speed to market; depth of engine (Monte Carlo, scenario planning) is hard to replicate |
| Partnership with Akikumo falls through | Low | Low | Option C architecture means we don't depend on it |
| Ad platform API access restricted | Medium | Low | Manual entry always works; this is a nice-to-have layer |

---

## 10. BusinessMath Capability Mapping

Direct mapping of platform modules to existing BusinessMath capabilities:

| Platform Module | BusinessMath Feature Areas | Readiness |
|----------------|---------------------------|-----------|
| Product Intelligence | Descriptive stats, anomaly detection, profitability ratios | **Ready** |
| Demand Forecasting | Holt-Winters, seasonal decomposition, trend fitting, Monte Carlo | **Ready** |
| Profitability Engine | Income statement, DuPont analysis, ecommerce metrics, ratios | **Ready** |
| Marketing Optimizer | Capital allocation, efficient frontier, sensitivity analysis | **Ready** |
| Cash Flow Forecasting | Three-statement model, scenario analysis, Monte Carlo, cash conversion cycle | **Ready** |

**Assessment:** The analytical engine is fully built. The work is in the data pipeline (Shopify API integration), the web frontend (Polaris/React), and the product UX — not the math.

---

## 11. Decision Framework

### Build if:
- You want full control and maximum long-term value
- You're willing to invest 6–9 months before revenue
- You want to own the merchandising layer
- The friendship with Akikumo's founders would be complicated by business entanglement

### Partner if:
- Speed to market is the priority
- Akikumo's founders are genuinely interested and aligned on vision
- Their existing customer base is large enough to matter (validate this)
- Revenue sharing terms are favorable (e.g., they get 20–30% of Module 1 revenue, we keep Modules 2–5)

### Don't do this if:
- You don't want to build and maintain a web frontend (React/Polaris)
- The Shopify ecosystem's billing and review requirements feel too constraining
- You'd rather license BusinessMath's engine to existing apps (pure B2B play)

---

## 12. Next Steps (Active)

**Decision made:** Option C (Hybrid — build independently, partnership-ready architecture).
**Project:** StockOpt at `/Users/jpurnell/Dropbox/Computer/Development/Swift/StockOpt`
**Target:** June 2026 MVP (Stocky Migration Package)

### Immediate (Week 1)
1. **Set up project** — scaffold StockOpt repo with development-guidelines, master plan, and architecture
2. **Shopify Partner account** — register app, apply for `read_all_orders` scope early (can take weeks)
3. **Prototype data pipeline** — Shopify GraphQL Bulk Operations → order data → BusinessMath forecasting engine

### Build Sprint (Weeks 2–4)
4. **Core data layer** — Shopify OAuth, webhook handlers, GDPR compliance, PostgreSQL schema
5. **Forecasting API** — BusinessMath REST wrapper serving Holt-Winters forecasts from Shopify order data
6. **Embedded app frontend** — Polaris/React dashboard with forecast visualization, PO generation
7. **Stocky Import Wizard** — CSV ingestion, supplier re-entry flow, data validation

### Launch (Week 4–5)
8. **App Store submission** — listing, screenshots, GDPR webhooks, Shopify Billing API
9. **Migration landing page** — SEO for "Stocky alternative", community forum engagement
10. **Private beta** — 10–20 merchants, validate forecast accuracy and UX

---

## Appendix A: Key Data Points

- Global inventory distortion: **$818B/year** (52% stockouts, 44% overstock)
- DTC failure rate $10M→$50M: **73%**
- Average ecommerce ROAS (2025): **2.87** (median 2.04)
- Meta CPM (Q1 2025): **$10.88** (up 19% YoY)
- DTC brands denied financing: **68%** (seasonal revenue misread as instability)
- Demand planner salary: **$82K/year** ($61K–$109K)
- Shopify app revenue share: **0% on first $1M/year**
- Typical DTC SaaS stack cost: **$200K–$850K/year** at growth stage
- Manual CSV workflow: **10–15 hours/week**, 15–20% reporting variance

## Appendix B: Sources

Market data compiled from: Shopify earnings, TrueProfit public metrics, Branvas 2026 ecosystem report, Uptek app store statistics, Common Thread Collective, Admetrics, Intelligence Node, OnRamp Funds, PPC Land, Modern Retail, Zippia salary data, and individual app store listings (accessed May 2026).
