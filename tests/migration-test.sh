#!/usr/bin/env bash
# migration-test.sh — 验证gstack→superpowers迁移
# 禁用严格模式以调试
# set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUPERPOWERS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ADAPTER_DIR="$SUPERPOWERS_ROOT/gstack-adapter/bin"

echo "=== GSTACK → SUPERPOWERS MIGRATION TEST ==="
echo ""

PASSED=0
FAILED=0

# 测试函数
test_case() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" == *"$expected"* ]]; then
    echo "✅ $name"
    ((PASSED++))
  else
    echo "❌ $name"
    echo "   Expected: $expected"
    echo "   Got: $actual"
    ((FAILED++))
  fi
}

# 测试适配器
echo "### Testing Adapters ###"

# Test gstack-config
echo "Testing gstack-config..."
CONFIG_OUTPUT=$("$ADAPTER_DIR/gstack-config" get proactive 2>/dev/null || echo "error")
test_case "gstack-config get proactive" "true" "$CONFIG_OUTPUT"

CONFIG_LIST=$("$ADAPTER_DIR/gstack-config" list 2>/dev/null || echo "error")
test_case "gstack-config list" "proactive" "$CONFIG_LIST"

# Test gstack-slug
echo "Testing gstack-slug..."
SLUG_OUTPUT=$("$ADAPTER_DIR/gstack-slug" 2>/dev/null || echo "error")
test_case "gstack-slug generates SLUG" "SLUG=" "$SLUG_OUTPUT"

# Test gstack-repo-mode
echo "Testing gstack-repo-mode..."
MODE_OUTPUT=$("$ADAPTER_DIR/gstack-repo-mode" 2>/dev/null || echo "error")
test_case "gstack-repo-mode detects mode" "REPO_MODE=" "$MODE_OUTPUT"

echo ""
echo "### Testing Skills ###"

# Test ship skill exists
echo "Testing ship skill..."
if [[ -f "$SUPERPOWERS_ROOT/skills/ship/SKILL.md" ]]; then
  SHIP_VERSION=$(grep "version:" "$SUPERPOWERS_ROOT/skills/ship/SKILL.md" | head -1 || echo "not found")
  test_case "ship skill exists" "version:" "$SHIP_VERSION"
else
  echo "❌ ship skill not found"
  ((FAILED++))
fi

# Test qa skill exists
echo "Testing qa skill..."
if [[ -f "$SUPERPOWERS_ROOT/skills/qa/SKILL.md" ]]; then
  QA_VERSION=$(grep "version:" "$SUPERPOWERS_ROOT/skills/qa/SKILL.md" | head -1 || echo "not found")
  test_case "qa skill exists" "version:" "$QA_VERSION"
else
  echo "❌ qa skill not found"
  ((FAILED++))
fi

# Test review skill exists
echo "Testing review skill..."
if [[ -f "$SUPERPOWERS_ROOT/skills/review/SKILL.md" ]]; then
  REVIEW_VERSION=$(grep "version:" "$SUPERPOWERS_ROOT/skills/review/SKILL.md" | head -1 || echo "not found")
  test_case "review skill exists" "version:" "$REVIEW_VERSION"
else
  echo "❌ review skill not found"
  ((FAILED++))
fi

# Test review checklist
echo "Testing review checklist..."
if [[ -f "$SUPERPOWERS_ROOT/skills/review/checklist.md" ]]; then
  CHECKLIST_CONTENT=$(head -10 "$SUPERPOWERS_ROOT/skills/review/checklist.md")
  test_case "review checklist exists" "CRITICAL" "$CHECKLIST_CONTENT"
else
  echo "❌ review checklist not found"
  ((FAILED++))
fi

echo ""
echo "=== TEST SUMMARY ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ $FAILED -eq 0 ]]; then
  echo ""
  echo "✅ All migration tests passed!"
  exit 0
else
  echo ""
  echo "❌ Some tests failed. Review the output above."
  exit 1
fi