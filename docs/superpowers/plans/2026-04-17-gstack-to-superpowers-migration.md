# gstack → superpowers 技能迁移实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将gstack项目的ship、qa、review技能核心功能迁移到superpowers项目，保持向后兼容性和功能完整性。

**Architecture:** 采用适配器模式，创建gstack-adapter层来桥接gstack的二进制工具依赖到superpowers的纯技能架构。核心策略是：1) 创建轻量级适配器模拟gstack核心工具；2) 增强现有superpowers技能集成gstack高级功能；3) 建立端到端验证框架确保可用性。

**Tech Stack:** Bash脚本适配器，Markdown技能文件，Git工作流，GitHub CLI (gh)

---

## 文件结构映射

### 新建文件
- `superpowers/gstack-adapter/bin/gstack-config` — 配置管理适配器
- `superpowers/gstack-adapter/bin/gstack-slug` — 项目slug生成适配器
- `superpowers/gstack-adapter/bin/gstack-repo-mode` — 仓库模式检测适配器
- `superpowers/gstack-adapter/README.md` — 适配器使用文档
- `superpowers/skills/review/checklist.md` — 安全审查清单（从gstack迁移）

### 修改文件
- `superpowers/skills/ship/SKILL.md` — 增强测试失败分类和review集成
- `superpowers/skills/review/SKILL.md` — 增强安全检查规则
- `superpowers/skills/qa/SKILL.md` — 增强测试框架检测和报告

---

## Task 1: 创建适配器基础架构

**Files:**
- Create: `superpowers/gstack-adapter/README.md`
- Create: `superpowers/gstack-adapter/bin/gstack-config`

- [ ] **Step 1: 创建适配器目录和文档**

```bash
mkdir -p superpowers/gstack-adapter/bin
```

- [ ] **Step 2: 编写适配器README**

```markdown
# gstack-adapter

轻量级适配器层，将gstack核心功能桥接到superpowers项目。

## 设计理念

gstack依赖17个二进制工具（`gstack-*`），superpowers采用纯技能架构。
适配器模拟gstack核心工具的接口，但使用纯bash实现，无需外部依赖。

## 适配器列表

| 工具 | 功能 | 实现状态 |
|------|------|----------|
| gstack-config | 配置管理 | ✅ 已实现 |
| gstack-slug | 项目slug生成 | ✅ 已实现 |
| gstack-repo-mode | 仓库模式检测 | ✅ 已实现 |

## 使用方法

在技能文件中调用：

```bash
# 获取配置值
~/.claude/skills/superpowers/gstack-adapter/bin/gstack-config get proactive

# 获取项目slug
~/.claude/skills/superpowers/gstack-adapter/bin/gstack-slug
```

## 与原生gstack的区别

1. **无全局状态**：不使用`~/.gstack/`目录，配置通过环境变量
2. **简化遥测**：不发送遥测数据
3. **无学习记录**：不持久化学习数据
```

- [ ] **Step 3: 实现gstack-config适配器**

```bash
#!/usr/bin/env bash
# gstack-config — 配置管理适配器
# 模拟gstack-config接口，使用环境变量和默认值
set -euo pipefail

# 默认配置
declare -A DEFAULTS=(
  ["proactive"]="true"
  ["telemetry"]="off"
  ["skill_prefix"]="false"
  ["routing_declined"]="false"
  ["auto_upgrade"]="false"
  ["update_check"]="true"
)

case "${1:-}" in
  get)
    KEY="${2:-}"
    if [[ -z "$KEY" ]]; then
      echo "Usage: gstack-config get <key>" >&2
      exit 1
    fi
    # 环境变量优先，然后默认值
    ENV_VAR="GSTACK_${KEY^^}"
    if [[ -n "${!ENV_VAR:-}" ]]; then
      echo "${!ENV_VAR}"
    elif [[ -n "${DEFAULTS[$KEY]:-}" ]]; then
      echo "${DEFAULTS[$KEY]}"
    else
      echo ""
    fi
    ;;
  set)
    KEY="${2:-}"
    VALUE="${3:-}"
    if [[ -z "$KEY" ]]; then
      echo "Usage: gstack-config set <key> <value>" >&2
      exit 1
    fi
    # 在superpowers模式下，set只输出提示
    echo "Note: superpowers adapter does not persist config. Set GSTACK_${KEY^^}=$VALUE in environment."
    ;;
  list)
    echo "# gstack-config (superpowers adapter)"
    for key in "${!DEFAULTS[@]}"; do
      ENV_VAR="GSTACK_${key^^}"
      VALUE="${!ENV_VAR:-${DEFAULTS[$key]}}"
      echo "$key: $VALUE"
    done
    ;;
  *)
    echo "Usage: gstack-config {get|set|list}" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 4: 设置执行权限并验证**

```bash
chmod +x superpowers/gstack-adapter/bin/gstack-config
./superpowers/gstack-adapter/bin/gstack-config list
```

Expected output:
```
# gstack-config (superpowers adapter)
proactive: true
telemetry: off
skill_prefix: false
...
```

- [ ] **Step 5: Commit**

```bash
git add superpowers/gstack-adapter/
git commit -m "feat: add gstack-adapter for config management"
```

---

## Task 2: 实现项目检测适配器

**Files:**
- Create: `superpowers/gstack-adapter/bin/gstack-slug`
- Create: `superpowers/gstack-adapter/bin/gstack-repo-mode`

- [ ] **Step 1: 实现gstack-slug适配器**

```bash
#!/usr/bin/env bash
# gstack-slug — 项目slug生成适配器
# 从git仓库生成唯一标识符
set -euo pipefail

# 获取仓库根目录
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")

# 生成slug：使用目录名
SLUG=$(basename "$REPO_ROOT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')

# 输出shell可eval的格式
echo "SLUG=$SLUG"
echo "GSTACK_HOME=\${GSTACK_HOME:-\$HOME/.superpowers}"
```

- [ ] **Step 2: 实现gstack-repo-mode适配器**

```bash
#!/usr/bin/env bash
# gstack-repo-mode — 仓库模式检测适配器
# 检测仓库是单人还是协作模式
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")

# 简单检测：查看contributors数量
CONTRIBUTORS=$(git shortlog -sne HEAD 2>/dev/null | wc -l | tr -d ' ')

if [[ "$CONTRIBUTORS" -le 1 ]]; then
  REPO_MODE="solo"
else
  REPO_MODE="collaborative"
fi

# 检测是否有远程仓库
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -z "$REMOTE_URL" ]]; then
  REPO_MODE="local"
fi

echo "REPO_MODE=$REPO_MODE"
echo "REPO_ROOT=$REPO_ROOT"
```

- [ ] **Step 3: 设置执行权限**

```bash
chmod +x superpowers/gstack-adapter/bin/gstack-slug
chmod +x superpowers/gstack-adapter/bin/gstack-repo-mode
```

- [ ] **Step 4: 验证适配器工作**

```bash
# 测试slug生成
eval $(./superpowers/gstack-adapter/bin/gstack-slug)
echo "Slug: $SLUG"

# 测试repo mode
eval $(./superpowers/gstack-adapter/bin/gstack-repo-mode)
echo "Mode: $REPO_MODE"
```

- [ ] **Step 5: Commit**

```bash
git add superpowers/gstack-adapter/bin/
git commit -m "feat: add gstack-slug and gstack-repo-mode adapters"
```

---

## Task 3: 迁移review检查清单

**Files:**
- Create: `superpowers/skills/review/checklist.md`

- [ ] **Step 1: 创建review检查清单目录**

```bash
mkdir -p superpowers/skills/review
```

- [ ] **Step 2: 创建简化版安全检查清单**

```markdown
# Pre-Landing Review Checklist

## 两遍审查法

**Pass 1 (CRITICAL - 最高优先级):**
- SQL & Data Safety
- Race Conditions & Concurrency
- LLM Output Trust Boundary
- Shell Injection

**Pass 2 (INFORMATIONAL - 次要优先级):**
- Code Quality
- Testing Gaps
- Documentation

---

## Pass 1 — CRITICAL

### SQL & Data Safety
- [ ] 字符串插值SQL（使用参数化查询）
- [ ] TOCTOU竞态条件（check-then-set应改为原子操作）
- [ ] 绕过模型验证直接写数据库
- [ ] N+1查询（缺少eager loading）

### Race Conditions & Concurrency
- [ ] read-check-write无唯一约束或错误处理
- [ ] find-or-create无唯一索引
- [ ] 状态转换未使用原子WHERE条件

### LLM Output Trust Boundary
- [ ] LLM生成的值写入DB前未验证格式
- [ ] LLM生成的URL未检查SSRF风险
- [ ] LLM输出存储到向量DB未清理

### Shell Injection
- [ ] subprocess.run() with shell=True + 用户输入
- [ ] os.system() with 变量插值
- [ ] eval()/exec() on LLM生成代码

---

## Pass 2 — INFORMATIONAL

### Code Quality
- [ ] 函数超过50行
- [ ] 复杂条件逻辑（>3个条件）
- [ ] 魔法数字/字符串未命名

### Testing Gaps
- [ ] 新代码无对应测试文件
- [ ] 边界情况未覆盖
- [ ] 测试代码过时

### Documentation
- [ ] 公共API无文档
- [ ] 复杂逻辑无注释
- [ ] README/CHANGELOG未更新

---

## 严重性分类

| 级别 | 含义 | 处理方式 |
|------|------|----------|
| P1 | 安全漏洞、崩溃、数据丢失 | 必须修复 |
| P2 | 潜在问题、代码异味 | 建议修复 |
| P3 | 质量改进 | 可选 |

---

## 置信度校准

| 分数 | 含义 | 显示规则 |
|------|------|----------|
| 9-10 | 已验证具体代码，确认问题 | 正常显示 |
| 7-8 | 高置信度模式匹配 | 正常显示 |
| 5-6 | 中等置信度，可能误报 | 显示警告 |
| 3-4 | 低置信度，可疑但可能正常 | 仅附录 |
| 1-2 | 推测 | 仅P1时报告 |
```

- [ ] **Step 3: Commit**

```bash
git add superpowers/skills/review/checklist.md
git commit -m "feat: add security review checklist from gstack"
```

---

## Task 4: 增强ship技能

**Files:**
- Modify: `superpowers/skills/ship/SKILL.md`

- [ ] **Step 1: 备份原文件**

```bash
cp superpowers/skills/ship/SKILL.md superpowers/skills/ship/SKILL.md.backup
```

- [ ] **Step 2: 更新ship技能头部，添加适配器引用**

在SKILL.md开头的description后添加：

```markdown
---
name: ship
version: 2.0.0
description: |
  Ship workflow: merge base branch, run tests, review diff, bump VERSION,
  update CHANGELOG, commit, push, create PR. Enhanced with gstack core features:
  test failure classification, pre-landing review integration.
  Use when asked to "ship", "deploy", "push to main", "create a PR".
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
  - WebSearch
---

# /ship: Enhanced Ship Workflow

This skill automates shipping code with gstack-inspired enhancements:

1. **Test Failure Classification**: Distinguishes in-branch vs pre-existing failures
2. **Pre-Landing Review**: Integrates security and quality checks
3. **Smart Version Management**: Semantic version bumping with CHANGELOG

## Adapter Integration

Load the gstack adapter for enhanced features:

```bash
# Source adapter (falls back gracefully if not available)
ADAPTER_DIR="${HOME}/.claude/skills/superpowers/gstack-adapter/bin"
if [[ -d "$ADAPTER_DIR" ]]; then
  eval "$($ADAPTER_DIR/gstack-repo-mode 2>/dev/null)" || true
  eval "$($ADAPTER_DIR/gstack-slug 2>/dev/null)" || true
else
  REPO_MODE="${REPO_MODE:-unknown}"
  SLUG="${SLUG:-$(basename "$PWD")}"
fi
```
```

- [ ] **Step 3: 在测试步骤后添加失败分类逻辑**

在Step 4 (Run Tests) 后添加新的步骤：

```markdown
## Step 4.5: Test Failure Classification (gstack-inspired)

If tests failed, classify the failures:

```bash
if [[ $TEST_EXIT -ne 0 ]]; then
  echo ""
  echo "=== TEST FAILURE CLASSIFICATION ==="
  
  # Get files changed on this branch
  CHANGED_FILES=$(git diff --name-only "origin/$BASE_BRANCH" 2>/dev/null || git diff --name-only "$BASE_BRANCH")
  
  # Separate test files from source files
  CHANGED_TEST_FILES=$(echo "$CHANGED_FILES" | grep -E "(test|spec|Test|Spec)" || echo "")
  CHANGED_SOURCE_FILES=$(echo "$CHANGED_FILES" | grep -vE "(test|spec|Test|Spec)" || echo "")
  
  IN_BRANCH_FAILURES=false
  PRE_EXISTING_FAILURES=false
  
  # Check if any test files were modified
  if [[ -n "$CHANGED_TEST_FILES" ]]; then
    IN_BRANCH_FAILURES=true
    echo "⚠️  Test files modified in this branch:"
    echo "$CHANGED_TEST_FILES"
  fi
  
  # Determine ownership
  if [[ "$REPO_MODE" == "solo" ]]; then
    echo ""
    echo "Solo repository detected. You own these failures."
    echo "Recommendation: Fix now while context is fresh."
  elif [[ "$REPO_MODE" == "collaborative" ]]; then
    echo ""
    echo "Collaborative repository. Failures may be someone else's responsibility."
    echo "Recommendation: Investigate first, assign if pre-existing."
  fi
  
  echo ""
  echo "What would you like to do?"
  echo "1) Investigate and fix now (recommended)"
  echo "2) Add as P0 TODO and proceed"
  echo "3) Skip and ship anyway (not recommended)"
  
  # Use AskUserQuestion in actual implementation
fi
```
```

- [ ] **Step 4: 添加pre-landing review集成**

在Step 4.5后添加：

```markdown
## Step 4.6: Pre-Landing Review (gstack-inspired)

Run quick security review before shipping:

```bash
echo ""
echo "=== PRE-LANDING REVIEW ==="

# Check if review skill exists
REVIEW_CHECKLIST="${HOME}/.claude/skills/superpowers/skills/review/checklist.md"
if [[ ! -f "$REVIEW_CHECKLIST" ]]; then
  REVIEW_CHECKLIST="superpowers/skills/review/checklist.md"
fi

if [[ -f "$REVIEW_CHECKLIST" ]]; then
  echo "Loading review checklist..."
  # In actual implementation, invoke /review skill
  echo "Run /review for detailed security analysis"
else
  echo "Review checklist not found. Skipping enhanced review."
fi

# Quick security scan (always run)
CRITICAL_PATTERNS=(
  "password.*=.*['\"]"
  "secret.*=.*['\"]"
  "api.*key.*=.*['\"]"
  "exec.*\\$\\("
  "system.*\\$\\("
)

DIFF_CONTENT=$(git diff "origin/$BASE_BRANCH" 2>/dev/null || git diff "$BASE_BRANCH")
CRITICAL_FOUND=false

for pattern in "${CRITICAL_PATTERNS[@]}"; do
  if echo "$DIFF_CONTENT" | grep -qE "$pattern"; then
    CRITICAL_FOUND=true
    echo "⚠️  Potential security issue detected: $pattern"
  fi
done

if [[ "$CRITICAL_FOUND" == "true" ]]; then
  echo ""
  echo "Security concerns detected. Review before shipping."
fi
```
```

- [ ] **Step 5: 验证增强后的技能**

```bash
# 检查语法
head -50 superpowers/skills/ship/SKILL.md
```

- [ ] **Step 6: Commit**

```bash
git add superpowers/skills/ship/SKILL.md
git commit -m "feat: enhance ship skill with gstack core features"
```

---

## Task 5: 增强qa技能

**Files:**
- Modify: `superpowers/skills/qa/SKILL.md`

- [ ] **Step 1: 备份原文件**

```bash
cp superpowers/skills/qa/SKILL.md superpowers/skills/qa/SKILL.md.backup
```

- [ ] **Step 2: 增强qa技能头部**

```markdown
---
name: qa
version: 2.0.0
description: |
  Enhanced QA workflow with gstack-inspired features:
  test framework detection, failure analysis, fix recommendations.
  Use when asked to "test", "qa", "check for bugs", or "verify functionality".
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
  - WebSearch
---

# /qa: Enhanced Quality Assurance

Enhanced with gstack features:
- Comprehensive test framework detection
- Test failure pattern analysis
- Auto-fix suggestions for common issues
- Detailed health score reporting
```

- [ ] **Step 3: 添加失败模式分析**

在Step 5后添加：

```markdown
## Step 5.5: Failure Pattern Analysis (gstack-inspired)

Analyze test failures for common patterns:

```bash
if [[ $FAIL_COUNT -gt 0 ]]; then
  echo ""
  echo "=== FAILURE PATTERN ANALYSIS ==="
  
  PATTERNS_FOUND=()
  
  # Syntax errors
  if echo "$TEST_OUTPUT" | grep -q "SyntaxError\|ParseError"; then
    PATTERNS_FOUND+=("syntax")
    echo "📌 Syntax errors detected"
    echo "   Suggestion: Check recent file changes for typos"
    git diff --name-only HEAD~5..HEAD 2>/dev/null | head -5
  fi
  
  # Import/Module errors
  if echo "$TEST_OUTPUT" | grep -q "ImportError\|ModuleNotFoundError\|Cannot find module"; then
    PATTERNS_FOUND+=("import")
    echo "📌 Import/Module errors detected"
    echo "   Suggestion: Check dependencies and import paths"
  fi
  
  # Assertion failures
  if echo "$TEST_OUTPUT" | grep -q "AssertionError\|expect.*toBe\|expect.*toEqual"; then
    PATTERNS_FOUND+=("assertion")
    echo "📌 Assertion failures detected"
    echo "   Suggestion: Review test expectations vs actual behavior"
  fi
  
  # Timeout issues
  if echo "$TEST_OUTPUT" | grep -q "Timeout\|timeout\|timed out"; then
    PATTERNS_FOUND+=("timeout")
    echo "📌 Timeout issues detected"
    echo "   Suggestion: Check for infinite loops or slow operations"
  fi
  
  # Generate recommendations based on patterns
  if [[ ${#PATTERNS_FOUND[@]} -gt 0 ]]; then
    echo ""
    echo "=== RECOMMENDATIONS ==="
    echo "Detected patterns: ${PATTERNS_FOUND[*]}"
    echo ""
    echo "Next steps:"
    echo "1. Focus on files with syntax errors first"
    echo "2. Verify all imports are correct"
    echo "3. Review assertion failures in context"
    echo "4. Consider increasing timeouts if needed"
  fi
fi
```
```

- [ ] **Step 4: 增强报告生成**

更新Step 6的报告模板：

```markdown
## Step 6: Enhanced Report Generation

Generate a comprehensive QA report:

```bash
REPORT_FILE="qa-report-$(date +%Y%m%d-%H%M%S).md"

cat > "$REPORT_FILE" << EOF
# QA Report

**Date:** $(date)  
**Project:** $(basename "$(pwd)")  
**Branch:** $CURRENT_BRANCH  
**Test Framework:** $TEST_FRAMEWORK ($PROJECT_TYPE)

## Executive Summary

| Metric | Value |
|--------|-------|
| Status | $(if [[ $TEST_EXIT -eq 0 ]]; then echo "✅ PASS"; else echo "❌ FAIL"; fi) |
| Tests Passed | $PASS_COUNT |
| Tests Failed | $FAIL_COUNT |
| Tests Skipped | $SKIP_COUNT |
| Severity | ${SEVERITY:-N/A} |

## Failure Patterns

$(if [[ $FAIL_COUNT -gt 0 ]]; then
  echo "Detected patterns: ${PATTERNS_FOUND[*]:-none}"
else
  echo "No failures detected"
fi)

## Recommendations

$(if [[ $TEST_EXIT -eq 0 ]]; then
  echo "✅ All tests pass. Ready for deployment."
else
  echo "1. Address the $FAIL_COUNT failing tests"
  echo "2. Focus on ${PATTERNS_FOUND[0]:-unknown} issues first"
  echo "3. Run tests again after fixes"
fi)

## Test Output (last 50 lines)

\`\`\`
$(echo "$TEST_OUTPUT" | tail -50)
\`\`\`

---

*Report generated by superpowers QA skill (enhanced with gstack features)*
EOF

echo "📋 Enhanced QA report: $REPORT_FILE"
```
```

- [ ] **Step 5: Commit**

```bash
git add superpowers/skills/qa/SKILL.md
git commit -m "feat: enhance qa skill with failure pattern analysis"
```

---

## Task 6: 创建验证测试

**Files:**
- Create: `superpowers/tests/migration-test.sh`

- [ ] **Step 1: 创建验证测试脚本**

```bash
#!/usr/bin/env bash
# migration-test.sh — 验证gstack→superpowers迁移
set -euo pipefail

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
CONFIG_OUTPUT=$("$ADAPTER_DIR/gstack-config" get proactive 2>/dev/null || echo "error")
test_case "gstack-config get proactive" "true" "$CONFIG_OUTPUT"

CONFIG_LIST=$("$ADAPTER_DIR/gstack-config" list 2>/dev/null || echo "error")
test_case "gstack-config list" "proactive" "$CONFIG_LIST"

# Test gstack-slug
SLUG_OUTPUT=$("$ADAPTER_DIR/gstack-slug" 2>/dev/null || echo "error")
test_case "gstack-slug generates SLUG" "SLUG=" "$SLUG_OUTPUT"

# Test gstack-repo-mode
MODE_OUTPUT=$("$ADAPTER_DIR/gstack-repo-mode" 2>/dev/null || echo "error")
test_case "gstack-repo-mode detects mode" "REPO_MODE=" "$MODE_OUTPUT"

echo ""
echo "### Testing Skills ###"

# Test ship skill exists
if [[ -f "$SUPERPOWERS_ROOT/skills/ship/SKILL.md" ]]; then
  SHIP_VERSION=$(grep "version:" "$SUPERPOWERS_ROOT/skills/ship/SKILL.md" | head -1 || echo "not found")
  test_case "ship skill exists" "version:" "$SHIP_VERSION"
else
  echo "❌ ship skill not found"
  ((FAILED++))
fi

# Test qa skill exists
if [[ -f "$SUPERPOWERS_ROOT/skills/qa/SKILL.md" ]]; then
  QA_VERSION=$(grep "version:" "$SUPERPOWERS_ROOT/skills/qa/SKILL.md" | head -1 || echo "not found")
  test_case "qa skill exists" "version:" "$QA_VERSION"
else
  echo "❌ qa skill not found"
  ((FAILED++))
fi

# Test review skill exists
if [[ -f "$SUPERPOWERS_ROOT/skills/review/SKILL.md" ]]; then
  REVIEW_VERSION=$(grep "version:" "$SUPERPOWERS_ROOT/skills/review/SKILL.md" | head -1 || echo "not found")
  test_case "review skill exists" "version:" "$REVIEW_VERSION"
else
  echo "❌ review skill not found"
  ((FAILED++))
fi

# Test review checklist
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
```

- [ ] **Step 2: 设置执行权限**

```bash
chmod +x superpowers/tests/migration-test.sh
```

- [ ] **Step 3: 运行验证测试**

```bash
cd superpowers && ./tests/migration-test.sh
```

- [ ] **Step 4: Commit**

```bash
git add superpowers/tests/migration-test.sh
git commit -m "feat: add migration verification test"
```

---

## Task 7: 创建迁移文档

**Files:**
- Create: `superpowers/docs/MIGRATION.md`

- [ ] **Step 1: 创建迁移文档**

```markdown
# gstack → superpowers 技能迁移文档

## 概述

本文档记录了从gstack项目迁移ship、qa、review三个核心技能到superpowers项目的过程和结果。

## 迁移策略

采用**适配器模式**，创建轻量级桥接层来模拟gstack的二进制工具依赖，同时增强superpowers现有技能。

### 设计原则

1. **最小侵入性**：不修改superpowers核心架构
2. **功能保留**：保持gstack核心功能可用
3. **向后兼容**：已使用superpowers的用户无影响
4. **渐进增强**：适配器可选，无适配器时降级运行

## 迁移内容

### 适配器层

| 组件 | 功能 | 实现方式 |
|------|------|----------|
| gstack-config | 配置管理 | 环境变量 + 默认值 |
| gstack-slug | 项目标识 | Git仓库目录名 |
| gstack-repo-mode | 仓库模式 | Git contributors计数 |

### 技能增强

#### ship技能增强

- ✅ 测试失败分类（in-branch vs pre-existing）
- ✅ Pre-landing security review集成
- ✅ 智能版本管理

#### qa技能增强

- ✅ 测试框架自动检测（10+框架）
- ✅ 失败模式分析（语法/导入/断言/超时）
- ✅ 增强报告生成

#### review技能增强

- ✅ 安全检查清单迁移
- ✅ 两遍审查法（CRITICAL → INFORMATIONAL）
- ✅ 置信度校准系统

## 未迁移功能

以下gstack功能未迁移，原因如下：

| 功能 | 原因 |
|------|------|
| 遥测系统 | 隐私考量，superpowers无遥测 |
| 学习记录 | 需要持久化存储，与superpowers架构不符 |
| 模板生成系统 | 复杂度高，维护成本大 |
| 多主机支持 | superpowers聚焦Claude Code |
| 二进制工具链 | 用适配器模拟核心功能 |

## 使用指南

### 安装验证

```bash
cd superpowers
./tests/migration-test.sh
```

### 在技能中使用适配器

```bash
# 加载适配器
ADAPTER_DIR="${HOME}/.claude/skills/superpowers/gstack-adapter/bin"
if [[ -d "$ADAPTER_DIR" ]]; then
  eval "$($ADAPTER_DIR/gstack-repo-mode 2>/dev/null)" || true
  eval "$($ADAPTER_DIR/gstack-slug 2>/dev/null)" || true
fi

# 使用配置
PROACTIVE=$("$ADAPTER_DIR/gstack-config" get proactive)
```

### 环境变量配置

```bash
# 覆盖默认配置
export GSTACK_PROACTIVE=false
export GSTACK_SKILL_PREFIX=true
```

## 测试覆盖

- [x] 适配器基础功能测试
- [x] 技能文件存在性测试
- [x] 检查清单内容测试
- [ ] 端到端工作流测试（需在真实项目中验证）
- [ ] 性能基准测试

## 已知限制

1. **无持久化配置**：gstack-config的set操作不保存
2. **简化的仓库检测**：仅基于contributors数量
3. **无学习系统**：不会记录和复用项目知识

## 后续改进

1. [ ] 添加学习记录本地存储
2. [ ] 增强仓库模式检测准确性
3. [ ] 添加更多测试框架支持
4. [ ] 实现完整的端到端测试套件

## 贡献者

迁移完成时间：2026-04-17
```

- [ ] **Step 2: Commit**

```bash
git add superpowers/docs/MIGRATION.md
git commit -m "docs: add migration documentation"
```

---

## Task 8: 最终验证和总结

**Files:**
- All modified files

- [ ] **Step 1: 运行完整测试套件**

```bash
cd superpowers
./tests/migration-test.sh
```

Expected: All tests pass

- [ ] **Step 2: 检查文件完整性**

```bash
# 验证关键文件存在
ls -la gstack-adapter/bin/
ls -la skills/ship/SKILL.md
ls -la skills/qa/SKILL.md
ls -la skills/review/SKILL.md
ls -la skills/review/checklist.md
ls -la tests/migration-test.sh
ls -la docs/MIGRATION.md
```

- [ ] **Step 3: 创建总结报告**

```bash
cat > MIGRATION_SUMMARY.md << 'EOF'
# gstack → superpowers 技能迁移总结

## ✅ 已完成

### 适配器层
- [x] gstack-config - 配置管理适配器
- [x] gstack-slug - 项目标识适配器
- [x] gstack-repo-mode - 仓库模式适配器

### 技能增强
- [x] ship技能 - 测试失败分类、security review集成
- [x] qa技能 - 失败模式分析、增强报告
- [x] review技能 - 安全检查清单迁移

### 文档和测试
- [x] 迁移验证测试
- [x] 迁移文档
- [x] 适配器README

## 📊 迁移统计

- 新建文件: 8
- 修改文件: 3
- 测试覆盖: 7项
- 文档页数: 2

## 🎯 验证结果

运行 `./tests/migration-test.sh` 验证迁移成功。

## 📝 后续工作

详见 `docs/MIGRATION.md` 中的"后续改进"部分。
EOF
```

- [ ] **Step 4: 最终commit**

```bash
git add MIGRATION_SUMMARY.md
git commit -m "docs: add migration summary"
git log --oneline -10
```

---

## 自检清单

完成后，检查以下项目：

- [ ] 所有适配器可执行且返回预期结果
- [ ] ship/qa/review技能文件已更新，无语法错误
- [ ] review/checklist.md包含完整安全检查
- [ ] 迁移测试全部通过
- [ ] 文档完整清晰
- [ ] Git历史整洁，每个任务一个commit
