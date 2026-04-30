---
name: qa
version: 3.0.0
description: |
  QA workflow with Test→Fix→Verify loop. Three tiers (Quick/Standard/Exhaustive),
  atomic fix commits, auto-generated regression tests, WTF-likelihood self-regulation,
  diff-aware mode on feature branches. Use when asked to "qa", "test", "find bugs",
  "test and fix", or "verify this works".
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
triggers:
  - qa
  - test and fix
  - find bugs
  - verify this works
---

# /qa: Test → Fix → Verify

你同时是 QA 工程师和 bug 修复工程师。以真实用户视角系统性地测试代码变更：运行测试套件、
点击关键流程、检查报错。发现 bug 就原子化提交修复，重测验证，并自动写回归测试。
最终产出带有前后 Health Score 对比的 Ship-Readiness 报告。

**三级 tier 决定修什么：**
- **Quick** — 只修 critical + high
- **Standard**（默认）— + medium
- **Exhaustive** — + low / cosmetic

**浏览器 UI 测试** — 需要真实 Chromium 点击交互时，请改用平台级 `agent-browser` 或
`dogfood` 技能，本技能不直接驱动浏览器（保持零依赖）。

---

## Setup

### 解析用户请求

| 参数 | 默认值 | 用户 override 示例 |
|---|---|---|
| Target | 自动（当前 repo / 当前分支） | `--url http://localhost:3000`、`--path src/api/` |
| Tier | Standard | `--quick`、`--exhaustive` |
| Mode | full | `--regression .qa-reports/baseline.json`、`--diff` |
| Output dir | `.qa-reports/` | `--out /tmp/qa` |
| Scope | 全量或 diff | `Focus on 登录流程` |

### 预检：干净工作树

```bash
if [[ -n $(git status --porcelain) ]]; then
  # 使用 AskUserQuestion 提供三选项：
  #   A) 先 commit 当前改动（推荐）
  #   B) git stash，QA 结束后 pop
  #   C) 用户手动清理，中止
  echo "WORKING_TREE_DIRTY=true"
fi
```

**必须干净工作树** — QA 每个修复会产生独立 commit，脏树会把用户改动和修复混在一起。

### 预检：Git 上下文

```bash
CURRENT_BRANCH=$(git branch --show-current)
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|^refs/remotes/origin/||' || echo "main")
MERGE_BASE=$(git merge-base HEAD "$BASE_BRANCH" 2>/dev/null || echo "")
echo "BRANCH=$CURRENT_BRANCH BASE=$BASE_BRANCH MERGE_BASE=$MERGE_BASE"
```

若 `CURRENT_BRANCH` 不是 `main/master` 且未显式给 `--url / --path` → 自动进入 **Diff-aware 模式**（见 Phase 4）。

### 输出目录

```bash
mkdir -p .qa-reports/evidence
```

---

## Phase 1: 识别测试手段

探测项目的测试框架与运行命令：

```bash
PROJECT_TYPE="unknown"
TEST_COMMAND=""
TEST_FRAMEWORK="unknown"

if [[ -f "package.json" ]]; then
  PROJECT_TYPE="node"
  if grep -q '"test"' package.json; then
    TEST_COMMAND=$(node -e "try { const pkg = JSON.parse(require('fs').readFileSync('package.json', 'utf8')); console.log(pkg.scripts?.test || ''); } catch(e) { console.log(''); }")
  fi
  # 检测具体框架
  grep -q '"jest"' package.json && TEST_FRAMEWORK="jest"
  grep -q '"vitest"' package.json && TEST_FRAMEWORK="vitest"
  grep -q '"mocha"' package.json && TEST_FRAMEWORK="mocha"
elif [[ -f "Gemfile" ]]; then
  PROJECT_TYPE="ruby"
  TEST_COMMAND="bundle exec rspec"
  TEST_FRAMEWORK="rspec"
elif [[ -f "requirements.txt" || -f "pyproject.toml" ]]; then
  PROJECT_TYPE="python"
  if [[ -f "pytest.ini" || -f "pyproject.toml" ]]; then
    TEST_COMMAND="pytest"
    TEST_FRAMEWORK="pytest"
  else
    TEST_COMMAND="python -m unittest discover"
    TEST_FRAMEWORK="unittest"
  fi
elif [[ -f "go.mod" ]]; then
  PROJECT_TYPE="go"
  TEST_COMMAND="go test ./..."
  TEST_FRAMEWORK="go-test"
elif [[ -f "Cargo.toml" ]]; then
  PROJECT_TYPE="rust"
  TEST_COMMAND="cargo test"
  TEST_FRAMEWORK="cargo-test"
elif [[ -f "composer.json" ]]; then
  PROJECT_TYPE="php"
  TEST_COMMAND="vendor/bin/phpunit"
  TEST_FRAMEWORK="phpunit"
elif [[ -f "Makefile" ]] && grep -q "^test:" Makefile; then
  PROJECT_TYPE="make"
  TEST_COMMAND="make test"
fi

# Node.js 回退
if [[ -z "$TEST_COMMAND" && "$PROJECT_TYPE" == "node" ]]; then
  if command -v bun &>/dev/null; then TEST_COMMAND="bun test"
  elif [[ -f "yarn.lock" ]] && command -v yarn &>/dev/null; then TEST_COMMAND="yarn test"
  elif command -v npm &>/dev/null; then TEST_COMMAND="npm test"
  fi
fi

echo "PROJECT_TYPE=$PROJECT_TYPE  TEST_FRAMEWORK=$TEST_FRAMEWORK  TEST_COMMAND=${TEST_COMMAND:-NONE}"
```

若 `TEST_COMMAND` 为空：**STOP** → AskUserQuestion 请用户提供测试命令，或中止。

---

## Phase 2: 基线运行（baseline）

```bash
BASELINE_LOG=".qa-reports/baseline-$(date +%Y%m%d-%H%M%S).log"
eval "$TEST_COMMAND" 2>&1 | tee "$BASELINE_LOG"
BASELINE_EXIT=${PIPESTATUS[0]}
echo "BASELINE_EXIT=$BASELINE_EXIT  LOG=$BASELINE_LOG"
```

---

## Phase 3: 解析结果

### 计数与失败提取

```bash
TEST_OUTPUT=$(cat "$BASELINE_LOG")
PASS_COUNT=$(echo "$TEST_OUTPUT" | grep -cE "passed|✓|PASS\b" || echo "0")
FAIL_COUNT=$(echo "$TEST_OUTPUT" | grep -cE "failed|✗|FAIL\b|ERROR" || echo "0")
SKIP_COUNT=$(echo "$TEST_OUTPUT" | grep -cE "skipped|pending" || echo "0")

echo "Results: pass=$PASS_COUNT fail=$FAIL_COUNT skip=$SKIP_COUNT exit=$BASELINE_EXIT"

if [[ $FAIL_COUNT -gt 0 ]]; then
  echo "=== 失败摘要 ==="
  echo "$TEST_OUTPUT" | grep -A 3 -B 1 -iE "FAIL|ERROR|✗" | head -60
fi
```

### 失败模式识别（triage 预分类提示）

```bash
PATTERNS_FOUND=()
echo "$TEST_OUTPUT" | grep -qE "SyntaxError|ParseError" && PATTERNS_FOUND+=("syntax")
echo "$TEST_OUTPUT" | grep -qE "ImportError|ModuleNotFoundError|Cannot find module" && PATTERNS_FOUND+=("import")
echo "$TEST_OUTPUT" | grep -qE "AssertionError|expect\(" && PATTERNS_FOUND+=("assertion")
echo "$TEST_OUTPUT" | grep -qiE "timeout|timed out" && PATTERNS_FOUND+=("timeout")
echo "$TEST_OUTPUT" | grep -qE "panic:|nil pointer|segfault" && PATTERNS_FOUND+=("crash")
echo "Patterns: ${PATTERNS_FOUND[*]:-none}"
```

### Health Score（基线）

```bash
SCORE_TESTS=$([[ $BASELINE_EXIT -eq 0 ]] && echo 100 || echo $(( 100 - FAIL_COUNT * 10 )))
[[ $SCORE_TESTS -lt 0 ]] && SCORE_TESTS=0
SCORE_CONSOLE=100    # 本技能无浏览器，默认满分；浏览器场景由 agent-browser 补
SCORE_LINKS=100      # 同上
HEALTH_BASELINE=$(( (SCORE_TESTS + SCORE_CONSOLE + SCORE_LINKS) / 3 ))
echo "HEALTH_BASELINE=$HEALTH_BASELINE"
```

---

## Phase 4: Diff-aware 模式（仅在 feature 分支触发）

当 `MERGE_BASE` 非空且用户未指定 scope：

```bash
CHANGED_FILES=$(git diff --name-only "$MERGE_BASE"..HEAD)
echo "Changed files vs $BASE_BRANCH:"
echo "$CHANGED_FILES"
```

**测试范围收敛原则：**
1. 若检测到支持按文件过滤的框架（如 `pytest <file>`、`go test ./pkg/...`、`jest <pattern>`），仅对变更相关的测试文件/包运行。
2. 否则回退到全量 `$TEST_COMMAND`。
3. 同时从以下来源查找测试计划上下文，作为 fix 阶段的优先判断依据：
   - `docs/superpowers/plans/*.md` 中与当前分支名匹配的最新 plan
   - 当前会话中最近一次 `/write-plan` 的输出

**不匹配时降级：** 若变更全部是文档/配置文件，提示用户 "无代码变更，是否要跑全量 QA?" 并 AskUserQuestion。

---

## Phase 5: Triage

按 severity 排序所有发现的问题（定义见 [references/issue-taxonomy.md](references/issue-taxonomy.md)），
按 tier 决定修复范围：

| Tier | 会修 | 会 defer（仅记录） |
|---|---|---|
| Quick | critical + high | medium + low |
| Standard | critical + high + medium | low |
| Exhaustive | 全部 | — |

**无条件 defer 的类型：**
- 第三方库/基础设施问题（非本 repo 可改）
- 需要产品决策的文案/UX 问题
- 与当前变更无关的历史遗留（diff-aware 模式下）

输出 `ISSUES[]` 数组，每项含 `id / severity / category / title / repro / source_hint / action`。

---

## Phase 6: Fix Loop

对每个待修复 issue，按 severity 降序执行完整 6 步流程。完整操作清单见
[references/fix-loop-checklist.md](references/fix-loop-checklist.md)。

关键约束：
1. **原子提交** — 一个 issue 一个 commit，commit message 格式 `fix(qa): ISSUE-NNN — <desc>`
2. **最小变更** — 只改直接导致 bug 的文件
3. **验证后分类** — verified / best-effort / reverted / deferred
4. **异常终止** — 任一 fix 引发测试回归 → 立即 `git revert HEAD` → 该 issue 转 deferred

### 子步骤摘要

| 子步骤 | 动作 | 关键输出 |
|---|---|---|
| 6a. Locate source | `grep/glob` 定位抛错文件 | `source_files[]` |
| 6b. Fix | 读码 → 最小修改 | diff |
| 6c. Commit | 原子提交（单 issue） | commit SHA |
| 6d. Re-test | 重跑该 issue 相关测试 | pass/fail |
| 6e. Classify | verified / best-effort / reverted | status |
| 6e.5. 回归测试 | 见 Phase 7 | test file |
| 6f. Self-regulate | 见 Phase 8 | WTF% |

---

## Phase 7: 回归测试生成（每个 verified fix 触发）

**skip 条件（任一满足则跳过）：**
- 6e 分类不是 `verified`
- 修复纯 CSS / 纯文案（无行为变更）
- 项目无测试框架且用户拒绝 bootstrap

**步骤：**

1. **对齐项目现有测试风格**
   - 读取与 fix 最近的 2-3 个测试文件（同目录/同类型）
   - 匹配命名、import、assertion 风格、describe/it 嵌套、setup/teardown 模式
   - 回归测试必须"看起来是同一位作者写的"

2. **追踪 bug 的 codepath**
   - 什么输入/状态触发了 bug？（精确前置条件）
   - 走了哪条分支？
   - 在哪一行断开？
   - 邻近还有哪些同路径 edge case？（null / 空数组 / 边界值）

3. **生成测试**，必须包含：
   - 触发 bug 的前置状态
   - 暴露 bug 的操作
   - 断言**正确行为**（禁止 "it renders" / "doesn't throw" 这类空断言）
   - 归因注释：

     ```
     // Regression: ISSUE-NNN — <bug 描述>
     // Found by /qa on YYYY-MM-DD
     // Report: .qa-reports/qa-report-<scope>-<date>.md
     ```

4. **命名避冲突**：`{name}.regression-{auto-inc}.test.{ext}`

5. **运行新测试文件**（仅跑这一个）
   - 通过 → `git commit -m "test(qa): regression test for ISSUE-NNN — <desc>"`
   - 一次失败 → 修一次；仍失败 → 删除该测试，issue 标 `deferred`
   - 超过 2 分钟探索 → 跳过，defer

6. **注意：** 回归测试 commit **不计入** Phase 8 的 WTF-likelihood。

---

## Phase 8: Self-Regulation（STOP AND EVALUATE）

每 5 个 fix 或任一次 revert 后，计算 WTF-likelihood：

```
WTF_LIKELIHOOD:
  起始:                      0%
  每次 revert:              +15%
  单次 fix 改动 >3 文件:    +5%
  第 15 个 fix 之后:        每多一个 +1%
  剩余全是 low severity:    +10%
  改到无关文件:             +20%
```

**触发条件：**
- `WTF > 20%` → **立即 STOP**，用 AskUserQuestion 展示已完成清单，让用户决定继续 / 回滚 / 收尾
- **硬上限：50 个 fix**，达到后无论剩多少都停止

**目的：** 防止"修着修着跑偏"成为无限 loop。每一次自监管触发都要在最终报告中留痕。

---

## Phase 9: Final QA

所有修复完成后：
1. 重跑受影响范围的测试（Standard/Exhaustive tier 下重跑全量）
2. 计算 `HEALTH_FINAL`（维度同 Phase 3）
3. **若 `HEALTH_FINAL < HEALTH_BASELINE`** → 在报告顶部用 `⚠️ REGRESSION` 明显告警

```bash
FINAL_LOG=".qa-reports/final-$(date +%Y%m%d-%H%M%S).log"
eval "$TEST_COMMAND" 2>&1 | tee "$FINAL_LOG"
FINAL_EXIT=${PIPESTATUS[0]}

F_PASS=$(grep -cE "passed|✓|PASS\b" "$FINAL_LOG" || echo 0)
F_FAIL=$(grep -cE "failed|✗|FAIL\b|ERROR" "$FINAL_LOG" || echo 0)
SCORE_TESTS_FINAL=$([[ $FINAL_EXIT -eq 0 ]] && echo 100 || echo $(( 100 - F_FAIL * 10 )))
[[ $SCORE_TESTS_FINAL -lt 0 ]] && SCORE_TESTS_FINAL=0
HEALTH_FINAL=$(( (SCORE_TESTS_FINAL + 100 + 100) / 3 ))
echo "HEALTH_FINAL=$HEALTH_FINAL  (baseline=$HEALTH_BASELINE)"

if [[ $HEALTH_FINAL -lt $HEALTH_BASELINE ]]; then
  echo "⚠️ REGRESSION: health dropped $HEALTH_BASELINE → $HEALTH_FINAL"
fi
```

---

## Phase 10: Report

报告双写：

1. **本地**：`.qa-reports/qa-report-<scope>-<YYYY-MM-DD>.md`
2. **项目级**（可选）：`docs/superpowers/plans/` 下有对应 plan 时，追加 QA 小节到该 plan

**模板：** 使用 [templates/qa-report-template.md](templates/qa-report-template.md)，填入：
- Branch / Commit / Tier / Scope / Duration
- Health Score 前后对比表（带 delta）
- Top 3 Things to Fix
- 每个 issue：severity / category / repro / fix commit SHA / 分类 / 回归测试文件
- Deferred 清单（含"为什么 defer"）
- Ship Readiness 一句话总结，例如：
  > "QA 发现 8 个问题，修复 6 个（verified 5 / best-effort 1），health score 72 → 91，已加 6 个回归测试。可以 ship。"

**写完报告后：** 若 Setup 阶段 stash 了用户改动，`git stash pop`。

---

## Usage Notes

- `/qa` — Standard tier，自动 diff-aware（若在 feature 分支）
- `/qa --quick` — 只修 critical + high
- `/qa --exhaustive` — 修所有 severity
- `/qa --regression .qa-reports/baseline.json` — 对比模式
- `/qa --url https://staging.myapp.com` — **提示**：触发浏览器场景，建议改用 `agent-browser` 或 `dogfood`

## 与相关技能的关系

| 场景 | 推荐技能 |
|---|---|
| 写测试**之前**设计 | test-driven-development |
| 发现 bug 后**诊断**根因 | systematic-debugging |
| 代码 review（非 QA） | requesting-code-review |
| 真实浏览器 UI 探索 | agent-browser / dogfood（平台级） |
| 本技能 | **运行测试 + 自动修复 + 回归保护** |
