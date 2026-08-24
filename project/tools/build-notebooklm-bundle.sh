#!/bin/bash
# Build a four-document context bundle for NotebookLM (or any tool that ingests
# whole documents rather than a source tree).
#
# The library is 553 Swift files, 76 DocC guides and a large planning tree. None
# of that is uploadable as-is, and uploading it piecemeal produces a notebook
# that can quote a file but cannot say what the library is. These four documents
# are the smallest set that answers, in order: what is it, how do you use it,
# what rules govern it, and what is being proposed next.
#
# Regenerate after any release. Output is derived — safe to delete.
#
# Usage: project/tools/build-notebooklm-bundle.sh

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/project/notebooklm"
SRC="$ROOT/Sources/BusinessMath"
DOCC="$SRC/BusinessMath.docc"
mkdir -p "$OUT"

STAMP="$(git -C "$ROOT" log -1 --format='%h on %ad' --date=short 2>/dev/null || echo 'unknown')"
VERSION="$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null || echo 'untagged')"

banner () {   # banner <file> <title>
  printf '\n\n---\n\n# %s\n\n' "$2" >> "$1"
}
append () {   # append <target> <source> <heading>
  if [ -f "$3" ]; then
    printf '\n\n---\n\n## SOURCE: %s\n\n' "${3#$ROOT/}" >> "$1"
    cat "$3" >> "$1"
  fi
}

# =============================================================================
# 1. Overview and API inventory
# =============================================================================
F="$OUT/01-BusinessMath-Overview-and-API.md"
cat > "$F" <<HEADER
# BusinessMath — Overview and Complete API Inventory

**Generated:** from $STAMP, version $VERSION
**Regenerate with:** \`project/tools/build-notebooklm-bundle.sh\`

This document is one of four. The others are the narrative guides (02), the
engineering standards (03), and the 3.0.0 programme (04).

## What this library is

BusinessMath is a Swift package of business and financial mathematics. It is
generic over \`Real\` (swift-numerics), Swift 6 strict-concurrency clean, and
built around a principle it calls **fail-silent avoidance**: a function that
cannot compute an honest answer refuses rather than returning a plausible one.
That principle is the through-line of the codebase and of its release planning —
it is why GPU paths that cannot honour a seed now throw, and why the proposed
3.0.0 work extends the same rule from execution paths to statistical estimation.

The library is organised around four business domains. Three are deep; the
fourth is the subject of the 3.0.0 proposal in document 04.

| Leg | Coverage |
|---|---|
| **Finance** | Valuation, options, derivatives, credit, bonds, financial statements, ratios, portfolio, risk |
| **Operations** | Inventory, EOQ, newsvendor, safety stock, reorder point |
| **Strategy** | Scenario analysis, forecasting, optimization, Monte Carlo, decision models |
| **Marketing** | Thin. Present only as outputs of financial-model templates. |

## Package metadata

\`\`\`
HEADER
sed -n '1,60p' "$ROOT/Package.swift" >> "$F"
cat >> "$F" <<'HEADER2'
```

## Module map

Top-level source areas, with file and public-symbol counts. Counts are
mechanical; the descriptions say what each area is for.

| Module | Files | Public | Purpose |
|---|---|---|---|
HEADER2

describe () {
  case "$1" in
    Statistics) echo "Descriptive statistics, distributions, regression, hypothesis tests, correlation, matrix operations" ;;
    Optimization) echo "Linear/integer programming, gradient and heuristic optimizers, GPU-accelerated metaheuristics" ;;
    Simulation) echo "Monte Carlo engine, random distributions, seeded determinism" ;;
    Valuation) echo "Equity, bonds, credit derivatives, hazard-rate and recovery models" ;;
    "Financial Statements") echo "Income statement, balance sheet, cash flow, validation and scenarios" ;;
    "Fluent API") echo "Chainable model-building surface, plus the SaaS/subscription business templates" ;;
    "Time Series") echo "Trends, seasonality, decomposition, Holt-Winters, growth models" ;;
    Streaming) echo "Online/incremental statistics, FFT, anomaly detection" ;;
    Interpolation) echo "Splines, curve fitting, term-structure interpolation" ;;
    Forecasting) echo "Forecasters and a rigorous evaluation suite — rolling-origin backtest, baselines, scaled error" ;;
    "Model Definition") echo "Declarative model graphs, dependency analysis, cycle detection and solving (contains Tarjan SCC)" ;;
    "Operational Drivers") echo "Composable business drivers — deterministic, probabilistic, time-varying, constrained" ;;
    Risk) echo "Value at risk, stress testing, aggregate risk measures" ;;
    Stochastic) echo "Stochastic processes — GBM, Ornstein-Uhlenbeck, jump diffusion" ;;
    Ratios) echo "Financial ratio calculations and DuPont decomposition" ;;
    Operations) echo "Inventory management — EOQ, newsvendor, safety stock, reorder point" ;;
    Portfolio) echo "Mean-variance optimization, efficient frontier, risk parity" ;;
    Options) echo "Black-Scholes, binomial trees, Greeks" ;;
    Derivatives) echo "Volatility surfaces and derivative pricing support" ;;
    "Scenario Analysis") echo "Scenario modelling, sensitivity, tornado analysis" ;;
    AdvancedOptimization) echo "Robust, stochastic, and multi-period optimization" ;;
    BusinessOptimization) echo "Business-framed optimization — capital allocation, capital structure" ;;
    Determinism) echo "Seeded RNG contracts and the GPUAttempt protocol" ;;
    Diagnostics) echo "Runtime diagnostics and reporting" ;;
    Validation) echo "Input validation and constraint checking" ;;
    "Error Handling") echo "Structured error types" ;;
    Errors) echo "Error definitions" ;;
    Bayes) echo "Bayes' theorem" ;;
    Analysis) echo "DataTable — tabular data handling" ;;
    Visualization) echo "Command-line charting" ;;
    Core) echo "Core protocols and shared types" ;;
    Finance) echo "Time value of money" ;;
    FinancialModel) echo "Financial model container types" ;;
    "Industry Models") echo "Industry-specific templates (oil and gas E&P)" ;;
    "Combination and Permutation") echo "Combinatorics" ;;
    "Developer Tools") echo "Introspection and developer utilities" ;;
    Extensions) echo "Standard library extensions" ;;
    Utilities) echo "Shared helpers" ;;
    Integration) echo "Cross-module integration surfaces" ;;
    Schema) echo "Serialisation schemas" ;;
    Solver) echo "Equation solving" ;;
    Performance) echo "Performance measurement" ;;
    Audit) echo "Audit trail support" ;;
    *) echo "—" ;;
  esac
}

cd "$SRC"
for d in */; do
  d="${d%/}"
  [ "$d" = "BusinessMath.docc" ] && continue
  n=$(find "$d" -name '*.swift' | wc -l | tr -d ' ')
  p=$( { grep -rhE "^[[:space:]]*public (func|struct|enum|protocol|actor|final class|class)" --include='*.swift' "$d" 2>/dev/null || true; } | wc -l | tr -d ' ')
  printf '| `%s` | %s | %s | %s |\n' "$d" "$n" "$p" "$(describe "$d")" >> "$F"
done

cat >> "$F" <<'APIHEAD'

---

# Complete Public API Inventory

Every public declaration in the library, grouped by module and file. Signatures
only — bodies and documentation are omitted. Use document 02 for narrative
explanation of how these are meant to be used together.

APIHEAD

for d in */; do
  d="${d%/}"
  [ "$d" = "BusinessMath.docc" ] && continue
  printf '\n\n## Module: %s\n' "$d" >> "$F"
  find "$d" -name '*.swift' | sort | while read -r f; do
    decls=$( { grep -hE "^[[:space:]]*public (func|struct|enum|protocol|actor|final class|class|typealias|var|let|init|subscript|static)" "$f" || true; } \
            | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*{[[:space:]]*$//' | sort -u)
    if [ -n "$decls" ]; then
      printf '\n### %s\n\n```swift\n%s\n```\n' "$f" "$decls" >> "$F"
    fi
  done
done

# =============================================================================
# 2. Narrative guides
# =============================================================================
F="$OUT/02-BusinessMath-Guides.md"
cat > "$F" <<HEADER
# BusinessMath — Complete Narrative Documentation

**Generated:** from $STAMP, version $VERSION

All DocC narrative guides, concatenated in reading order. This is the library's
own teaching material: what each subsystem is for, worked examples with checked
numeric results, and the reasoning behind the design.

Every code example here is executed and verified by the \`doc-code\` and
\`doc-comment-code\` checkers described in document 03 — a documented example
that does not produce its claimed output fails the build.

HEADER
for g in "$DOCC"/BusinessMath.md "$DOCC"/LearningPath.md "$DOCC"/Part*.md; do
  append "$F" "" "$g"
done
find "$DOCC" -name '[0-9]*.md' | sort -V | while read -r g; do
  printf '\n\n---\n\n## SOURCE: %s\n\n' "${g#$ROOT/}" >> "$F"
  cat "$g" >> "$F"
done
append "$F" "" "$DOCC/Appendix-A-ReidsRaisinsExample.md"
append "$F" "" "$DOCC/MultipleLinearRegressionGuide.md"

# =============================================================================
# 3. Engineering standards
# =============================================================================
F="$OUT/03-BusinessMath-Engineering-Standards.md"
cat > "$F" <<HEADER
# BusinessMath — Engineering Standards and Governance

**Generated:** from $STAMP, version $VERSION

The rules the codebase is held to. These matter for evaluating any proposal
against this library: a design that violates the coding rules, cannot pass the
quality gate, or ignores the design-proposal process is not viable here
regardless of its technical merit.

Three things to know before reading:

1. **The quality gate is 45 SwiftSyntax auditors** run at build time, and the
   standing instruction is zero errors and zero warnings with **no overrides,
   suppressions, or config exclusions** — root causes only.
2. **Development is design-first TDD.** A design proposal precedes tests, tests
   precede implementation, and commits happen at each green state.
3. **Documented examples are executed.** The \`doc-code\` and
   \`doc-comment-code\` checkers verify that every documented example produces
   the value it claims.

HEADER
for f in "$ROOT/CLAUDE.md" "$ROOT/CONTRIBUTING.md" "$ROOT/project/reference/STABILITY.md" \
         "$ROOT/project/reference/overallRules.md" "$ROOT/.quality-gate.yml" \
         "$ROOT/project/decisions/architecture_decisions.md"; do
  append "$F" "" "$f"
done
banner "$F" "Development Guidelines Framework"
for r in README coding_rules design_proposal test_driven_development testing \
         ci_quality_gate enforcement docc_guidelines architecture_decisions \
         capability_map no_hardcoded_constants floating_point_formatting \
         performance release_checklist session_workflow usage_examples \
         swift_development; do
  append "$F" "" "$ROOT/development-guidelines/rules/$r.md"
done

# =============================================================================
# 4. The 3.0.0 programme
# =============================================================================
F="$OUT/04-BusinessMath-3.0-Programme.md"
cat > "$F" <<HEADER
# BusinessMath — Master Plan and the 3.0.0 Programme

**Generated:** from $STAMP, version $VERSION

Where the library is going, and the proposals currently under review. The
master plan comes first for context; the 3.0.0 scope and its two feature
proposals follow.

The release has two spines. The first is **determinism across every GPU path** —
a path that consumes randomness, fails, and falls back to the CPU returns a
different answer under a seed that promised otherwise. The second is **the
marketing leg**, proposed here. Both are instances of the same theme: the
library declining to answer where it cannot answer honestly.

HEADER
for f in "$ROOT/project/master_plan.md" \
         "$ROOT/project/plans/upcoming/v3.0.0_SCOPE.md" \
         "$ROOT/project/plans/proposals/MarketingLeg.md" \
         "$ROOT/project/plans/proposals/NetworkAnalysis.md" \
         "$ROOT/project/plans/proposals/GPUAttemptSeedContract.md" \
         "$ROOT/project/plans/TrustPlan.md" \
         "$ROOT/HANDOFF.md"; do
  append "$F" "" "$f"
done

# =============================================================================
echo "Wrote to $OUT:"
for f in "$OUT"/*.md; do
  printf '  %-46s %8s words  %6s\n' "$(basename "$f")" "$(wc -w < "$f" | tr -d ' ')" "$(du -h "$f" | cut -f1)"
done
