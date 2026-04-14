# Product Hunt Launch Preparation Kit -- BusinessMath

---

## 1. Product Hunt Listing Copy

### Tagline (56 chars)

**Financial math for Swift -- now with an AI-native API**

### Description (256 chars)

Open-source Swift library with 300+ financial functions: DCF, Monte Carlo, portfolio optimization, options pricing, and more. Ships with an MCP server so Claude and other AI tools can run real calculations. 4,700+ tests. GPU-accelerated. MIT licensed.

### First Comment (Maker's Comment)

Hey Product Hunt -- I'm Justin, and I've been building BusinessMath for the past two years.

The seed for this was planted almost 20 years ago at Goldman Sachs, where I modeled oil and gas company revenues in high yield credit. Each model depended on productivity estimates for sometimes thousands of individual wells and realized oil prices for the quarter. Spreadsheets couldn't handle the combinatorics. These were prime candidates for Monte Carlo simulation -- especially in high yield, where a miss on revenue doesn't just affect your price target. It translates to a major credit event.

I've been thinking about that problem ever since: how do you make serious financial computation accessible, fast, and trustworthy? When I started building for Apple platforms, I realized Swift had nothing. You either bridged to Python or rolled your own. So I built it.

BusinessMath now covers 300+ functions across financial statements, securities valuation (Black-Scholes, ISDA CDS pricing), portfolio optimization (efficient frontier, risk parity), Monte Carlo simulation with 15 probability distributions, time series forecasting, and statistical modeling. It ships with GPU acceleration via Metal -- the Monte Carlo engine compiles financial model expressions into Metal compute shader bytecode. Simulations that take 8+ seconds on CPU finish in 100ms on Apple Silicon. The whole thing is built on strict TDD with 4,700+ tests and zero compiler warnings under Swift 6 strict concurrency.

The piece I'm most excited about is the **MCP server**. If you use Claude or another AI tool that supports the Model Context Protocol, you can connect BusinessMath directly -- and the AI can call any of the 300+ functions with real data. Ask it to price an option, run a sensitivity analysis, or optimize a portfolio, and it actually computes the answer instead of approximating. It turns your AI assistant into a financial calculator that understands context.

I've also been using BusinessMath as the engine behind tools I use: **MortgagePayoffCalculator**, an iOS app that models extra mortgage payments against your amortization schedule and shows exactly how much interest you save; **WineTaster**, a tasting evaluation app that computes statistical significance of judge rankings using Kendall's W and chi-square tests; and **LedgeOS**, a capital allocation platform for small business survival modeling with stress-tested cash runway projections.

These aren't demos -- they're real products that depend on the library every day, which is the best kind of stress test.

The library is MIT licensed, works on iOS 17+, macOS 14+, tvOS, watchOS, visionOS, and Linux, and you can add it to any Swift project with a single SPM dependency. I'd love to hear what you'd build with it.

---

## 2. Three Alternative Positioning Angles

### Angle A: AI-Native Financial Math

**Tagline:** Give your AI agent a real financial calculator

Most AI tools fake financial math -- they approximate, hallucinate numbers, or punt to "consult a professional." BusinessMath ships with an MCP server that exposes 300+ validated financial functions directly to Claude and other AI tools. Your AI can price bonds, run Monte Carlo simulations, calculate VaR, optimize portfolios, and build DCF models using the same implementations that production systems use. Every result is computed, not generated. Every function is backed by tests. This is what AI-assisted financial analysis should look like: the AI handles the reasoning, the library handles the math.

### Angle B: Swift-Native Alternative to Python and R

**Tagline:** Stop shelling out to Python for financial math

If you build for Apple platforms, you've probably accepted that serious financial computation means bridging to Python or spinning up an R session. BusinessMath is a pure Swift library that covers what NumPy/SciPy, statsmodels, and QuantLib handle in the Python world -- NPV, IRR, Monte Carlo, Black-Scholes, portfolio optimization, multiple regression, time series decomposition -- all with Swift's type safety, strict concurrency, and native performance. GPU-accelerated Monte Carlo runs 5-20x faster on Apple Silicon. It works in Xcode Playgrounds, SwiftUI apps, and server-side Swift. MIT licensed.

### Angle C: Tools Built with BusinessMath

**Tagline:** The engine behind MortgagePayoffCalculator and WineTaster

MortgagePayoffCalculator models extra mortgage payments against your amortization schedule and shows exactly how much interest you save. WineTaster collects rankings from multiple wine judges and computes statistical significance to determine consensus. LedgeOS stress-tests small business cash runway projections with Monte Carlo simulation. These tools all run on BusinessMath -- an open-source Swift library with 300+ financial functions, from basic TVM calculations to GPU-accelerated Monte Carlo simulations. We're open-sourcing the engine so other developers can build the same caliber of financial tools for Apple platforms and beyond.

---

## 3. Launch Day Checklist

### Before Launch (1-2 weeks prior)

- [ ] Finalize which positioning angle to lead with (A, B, or C)
- [ ] Prepare 4-6 visual assets (see Section 4)
- [ ] Record a 1-2 minute demo video or GIF walkthrough
- [ ] Write and schedule the HN posts (coordinate per Section 6)
- [ ] Draft Twitter/X thread (see Section 5)
- [ ] Prepare a "Show HN" post linking to the library
- [ ] Recruit 10-15 people who will genuinely upvote and comment on launch day
- [ ] Ensure README, CONTRIBUTING, and LICENSE are polished
- [ ] Create a GitHub Discussions welcome thread for Product Hunt visitors
- [ ] Test the MCP server setup flow end to end -- new user should connect to Claude in under 5 minutes
- [ ] Prepare answers to anticipated questions (pricing, roadmap, comparison to alternatives, why Swift)
- [ ] Update the GitHub repo description and topics for discoverability

### Launch Day

- [ ] Submit to Product Hunt between 12:01 AM and 12:30 AM PT (see Section 6)
- [ ] Post the maker's comment immediately after submission
- [ ] Publish the HN post (if not already live)
- [ ] Post the Twitter/X thread within 30 minutes of going live
- [ ] Share on relevant Slack/Discord communities (Swift, indie dev, fintech, AI)
- [ ] Post on relevant subreddits: r/swift, r/iOSProgramming, r/LocalLLaMA (MCP angle), r/fintech
- [ ] Monitor and respond to every comment on Product Hunt within the first 4-6 hours
- [ ] Monitor HN comments and respond thoughtfully
- [ ] Post on LinkedIn (see LINKEDIN_POST.md)
- [ ] Track GitHub stars, forks, and traffic throughout the day

### Follow-Up (Days 2-7)

- [ ] Thank commenters and voters individually where appropriate
- [ ] Write a "lessons learned" or "building in public" follow-up post
- [ ] Publish a blog post expanding on the most-asked questions from launch day
- [ ] Follow up with anyone who expressed interest in contributing
- [ ] Update the README with a "Featured on Product Hunt" badge if it performs well
- [ ] Analyze traffic sources and double down on what worked
- [ ] Create GitHub Issues for feature requests that came from launch day feedback

---

## 4. Visual Assets Needed

### Asset 1: Hero Image / Thumbnail (Required)

**What it should show:** A clean, dark-themed code editor screenshot showing a BusinessMath workflow -- the Quick Example from the README (investment analysis with NPV, IRR, Monte Carlo) with syntax highlighting. Overlay the BusinessMath logo and tagline. Dimensions: 1270x760px.

### Asset 2: MCP Server in Action (High Priority)

**What it should show:** A screen recording or annotated screenshot of Claude connected to the BusinessMath MCP server. Show the user asking a natural-language financial question ("What's the NPV of this project at a 10% discount rate?") and the AI calling the actual BusinessMath function and returning a computed result. This is the "wow" moment.

### Asset 3: GPU Acceleration Benchmark (Medium Priority)

**What it should show:** A clean chart comparing CPU vs GPU performance for Monte Carlo simulation at different iteration counts. Keep it simple -- a bar chart or styled table.

### Asset 4: Architecture Overview (Medium Priority)

**What it should show:** A visual diagram of BusinessMath's module structure -- the major capability areas (Financial Statements, Securities Valuation, Risk & Simulation, Optimization, Statistics, Time Series) arranged around the core, with the MCP server as an outer layer.

### Asset 5: Tool Screenshots (High Priority if using Angle C)

**What it should show:** Screenshots of MortgagePayoffCalculator, WineTaster, and LedgeOS in use. Each should show the tool doing something financially meaningful -- a chart, a calculation result, a dashboard. Caption each with "Powered by BusinessMath."

### Asset 6: Before/After -- AI Without vs With BusinessMath (Optional, High Impact)

**What it should show:** Side-by-side. Left: an AI assistant asked to calculate bond duration, giving a vague or incorrect answer. Right: same question with BusinessMath MCP connected, returning precise, validated numbers.

---

## 5. Cross-Promotion Plan

### Leveraging the HN Posts

1. **Day -3 to -1:** Publish the HN NASA fault-tolerance post. Let it run its natural course.
2. **Launch Day:** Submit BusinessMath to Product Hunt. In the maker's comment, reference the HN discussion: "Last week I shared how we applied NASA reliability principles -- BusinessMath is the project where we battle-tested that approach."
3. **Day +1 or +2:** Post "Show HN: BusinessMath" with the Metal/GPU angle. HN loves technical depth.

### Twitter/X Thread Outline

**Tweet 1 (Hook):**
Almost 20 years ago at Goldman, I modeled O&G revenues across thousands of wells for high yield credit. A miss meant a credit event. I've been thinking about accessible, trustworthy financial computation ever since. Today I'm open-sourcing what I built. [link]

**Tweet 2 (What it is):**
BusinessMath: 300+ financial functions in pure Swift. NPV, Monte Carlo, Black-Scholes, portfolio optimization, regression, financial statements. 100K lines. 4,700+ tests. GPU-accelerated via Metal.

**Tweet 3 (MCP):**
The wildest part: it ships with an MCP server. Connect it to Claude, and your AI can call any of the 300+ functions with real data. It computes -- it doesn't approximate. [screenshot]

**Tweet 4 (GPU):**
The Monte Carlo engine compiles financial model expressions into Metal compute shader bytecode. Simulations that take 8+ seconds on CPU finish in 100ms on Apple Silicon.

**Tweet 5 (Tools):**
I've been using it to build MortgagePayoffCalculator (amortization modeling), WineTaster (statistical analysis of wine competitions), and LedgeOS (business survival stress testing). The library is the engine. [screenshots]

**Tweet 6 (CTA):**
Open source. MIT licensed. iOS, macOS, visionOS, watchOS, tvOS, Linux. If you do anything with financial math in Swift, I'd love your feedback. [Product Hunt link] [GitHub link]

### Other Channels

- **Swift Forums (forums.swift.org):** "Related Projects" category. Focus on generic numerics, strict concurrency, Metal integration.
- **iOS Dev Weekly / Swift Weekly Brief:** Submit for inclusion. Email curators directly.
- **Mastodon (iosdev.space, hachyderm.io):** Mirror the Twitter thread.
- **LinkedIn:** See LINKEDIN_POST.md. Post same morning as PH launch.
- **Discord:** iOS Developers, Swift (unofficial), Indie Dev Monday, AI/ML communities.
- **Reddit:** r/swift, r/iOSProgramming, r/fintech, r/LocalLLaMA or r/ClaudeAI (MCP angle).
- **Dev.to / Hashnode:** Cross-post the HN blog post with PH launch mention.

---

## 6. Timing Recommendation

### Best Launch Day

**Tuesday or Wednesday** -- highest-traffic days on Product Hunt. Avoid Monday (catching up) and Friday (checking out). Tuesday is the sweet spot for developer tools.

### Best Time

Submit between **12:01 AM and 12:30 AM Pacific Time**. PH day resets at midnight PT, so posting early gives you the full 24-hour voting window.

### Coordinating with HN

| Day | Action |
|-----|--------|
| **Thursday/Friday (Week -1)** | Publish the NASA fault-tolerance HN post. Let it run over the weekend. |
| **Monday** | Engage with HN comments if the post gained traction. |
| **Tuesday 12:01 AM PT** | Product Hunt launch goes live. Post maker's comment immediately. |
| **Tuesday morning** | Twitter/X thread, LinkedIn post, Reddit, Discord. |
| **Tuesday-Wednesday** | Monitor and respond to all comments across platforms. |
| **Wednesday or Thursday** | Post "Show HN: BusinessMath" with the Metal/GPU shader angle. |
| **Friday** | Follow-up content: what you learned from launch week. |

**Key Principle:** Never launch the same content on HN and Product Hunt the same day. They're different audiences. Stagger by 2-3 days.
