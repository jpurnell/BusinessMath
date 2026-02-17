#!/bin/bash
#
# update_readme.sh
# BusinessMath
#
# Regenerates all project metrics and updates README.md with current statistics.
#
# Usage:
#   ./scripts/update_readme.sh           # Regenerate metrics + update README
#   ./scripts/update_readme.sh --dry-run  # Show changes without applying them
#
# Metrics sourced from:
#   - Instruction Set/05_SUMMARIES/generate_library_metrics.swift → library_metrics.json
#   - Instruction Set/05_SUMMARIES/analyzers/doc_gap_analyzer.swift → data/doc_gaps.json
#   - swift test --list-tests (test case count)
#   - wc on Sources/BusinessMath/BusinessMath.docc/*.md (guide and line counts)

set -e

# ── Paths ────────────────────────────────────────────────────────────────────
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUMMARIES_DIR="$PROJECT_ROOT/Instruction Set/05_SUMMARIES"
METRICS_JSON="$SUMMARIES_DIR/library_metrics.json"
DOC_GAPS_JSON="$SUMMARIES_DIR/data/doc_gaps.json"
DOCC_DIR="$PROJECT_ROOT/Sources/BusinessMath/BusinessMath.docc"
README="$PROJECT_ROOT/README.md"
DRY_RUN=false

[[ "${1}" == "--dry-run" ]] && DRY_RUN=true

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  BusinessMath README Metrics Updater"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Step 1: Regenerate metrics ────────────────────────────────────────────────
echo "📊 Regenerating library metrics..."
swift "$SUMMARIES_DIR/generate_library_metrics.swift" > /dev/null 2>&1
echo "   ✓ library_metrics.json updated"

echo "📖 Regenerating documentation gap analysis..."
swift "$SUMMARIES_DIR/analyzers/doc_gap_analyzer.swift" > /dev/null 2>&1
echo "   ✓ doc_gaps.json updated"
echo ""

# ── Step 2: Collect metrics ───────────────────────────────────────────────────
echo "📏 Collecting metrics..."

# Guide count: all .md files minus the 6 structural navigation files
#   BusinessMath.md, Part1-Basics.md, Part2-Analysis.md,
#   Part3-Modeling.md, Part4-Simulation.md, Part5-Optimization.md
TOTAL_MD=$(ls "$DOCC_DIR"/*.md | wc -l | tr -d ' ')
NAVIGATION_FILES=6
GUIDE_COUNT=$((TOTAL_MD - NAVIGATION_FILES))

# DocC total lines (all .md files, navigation lines negligible vs. 48k total)
DOCC_LINES_RAW=$(wc -l "$DOCC_DIR"/*.md | tail -1 | awk '{print $1}')
# Round down to nearest thousand for README display
DOCC_THOUSANDS=$(python3 -c "n=$DOCC_LINES_RAW; print(f'{(n//1000)*1000:,}')")
DOCC_DISPLAY="${DOCC_THOUSANDS}+"

# Test case count (expands parameterised tests — more accurate than counting functions)
echo "   Running swift test --list-tests (may take a moment)..."
TEST_COUNT_RAW=$(swift test --list-tests 2>/dev/null | wc -l | tr -d ' ')
# Format with comma separator
TEST_COUNT_FORMATTED=$(python3 -c "print(f'{$TEST_COUNT_RAW:,}')")
TEST_DISPLAY="${TEST_COUNT_FORMATTED}+"

# Test suite count: files containing @Suite or XCTestCase class
SUITE_COUNT=$(grep -rl "@Suite\|class.*: XCTestCase" "$PROJECT_ROOT/Tests" --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
SUITE_DISPLAY="${SUITE_COUNT}+"

# Extract values from JSON using python3 (always available on macOS)
TOTAL_APIS=$(python3 -c "
import json
with open('$DOC_GAPS_JSON') as f:
    d = json.load(f)
print(d['summary']['total_public_apis'])
")

DOC_COVERAGE=$(python3 -c "
import json
with open('$DOC_GAPS_JSON') as f:
    d = json.load(f)
pct = d['summary']['documentation_coverage_percent']
print(int(round(pct)))
")

UNDOCUMENTED=$(python3 -c "
import json
with open('$DOC_GAPS_JSON') as f:
    d = json.load(f)
print(d['summary']['undocumented'])
")

SOURCE_FILES=$(python3 -c "
import json
with open('$METRICS_JSON') as f:
    d = json.load(f)
print(d['code_metrics']['source_files'])
")

echo ""
echo "┌─────────────────────────────────────────────┐"
echo "│  Metric              Value                  │"
echo "├─────────────────────────────────────────────┤"
printf "│  Guides              %-26s│\n" "$GUIDE_COUNT (of $TOTAL_MD .md files)"
printf "│  DocC lines          %-26s│\n" "$DOCC_LINES_RAW"
printf "│  Test cases          %-26s│\n" "$TEST_COUNT_RAW"
printf "│  Test suites (files) %-26s│\n" "$SUITE_COUNT"
printf "│  Public APIs         %-26s│\n" "$TOTAL_APIS"
printf "│  Doc coverage        %-26s│\n" "${DOC_COVERAGE}% ($UNDOCUMENTED undocumented)"
printf "│  Source files        %-26s│\n" "$SOURCE_FILES"
echo "└─────────────────────────────────────────────┘"
echo ""

if $DRY_RUN; then
    echo "🔍 Dry run — no changes applied to README.md"
    echo ""
    echo "Would apply these replacements:"
    echo "  44 comprehensive guides  → $GUIDE_COUNT comprehensive guides"
    echo "  8,500+ lines of DocC     → $DOCC_DISPLAY lines of DocC"
    echo "  3,552+ Tests             → $TEST_DISPLAY Tests"
    echo "  3,552 tests              → $TEST_DISPLAY tests"
    echo "  278 test suites          → $SUITE_DISPLAY test suites"
    echo "  167 tools                → 169 tools (MCP consistency)"
    exit 0
fi

# ── Step 3: Apply README replacements ─────────────────────────────────────────
echo "✏️  Updating README.md..."

cp "$README" "${README}.bak"

# Guide count (multiple occurrences — replace all)
sed -i '' "s/44 comprehensive guides/$GUIDE_COUNT comprehensive guides/g" "$README"

# DocC line count
sed -i '' "s/8,500+ lines of DocC documentation/$DOCC_DISPLAY lines of DocC documentation/g" "$README"

# Test case count in v2.0.0 bullet (has + already: "3,552+ Tests:")
sed -i '' "s/3,552+ Tests:/${TEST_COUNT_FORMATTED}+ Tests:/g" "$README"

# Test case count in Why BusinessMath prose (no colon: "3,552+ tests,")
sed -i '' "s/3,552+ tests,/${TEST_COUNT_FORMATTED}+ tests,/g" "$README"

# Test case count in Documentation & Testing table ("3,552 tests across")
sed -i '' "s/3,552 tests across/${TEST_COUNT_FORMATTED}+ tests across/g" "$README"

# Test suite count
sed -i '' "s/278 test suites/${SUITE_DISPLAY} test suites/g" "$README"

# MCP tools consistency (fix 167 → 169 throughout)
sed -i '' "s/167 tools/169 tools/g" "$README"

echo "   ✓ Guide count updated ($GUIDE_COUNT)"
echo "   ✓ DocC lines updated ($DOCC_DISPLAY)"
echo "   ✓ Test count updated ($TEST_DISPLAY)"
echo "   ✓ Test suite count updated ($SUITE_DISPLAY)"
echo "   ✓ MCP tools count made consistent (169)"
echo ""
echo "   Backup saved to: README.md.bak"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ README.md updated successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  Manual review recommended for:"
echo "   - New features not yet listed in v2.0.0 section or What's Included"
echo "   - MCP server tool count (verify against MCP server source)"
echo "   - Version number / release notes links"
