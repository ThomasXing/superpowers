# QA 技能 gstack 方法论集成改造计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 gstack `/qa` 的核心方法论（Test→Fix→Verify 循环、三级 tier、自监管、回归测试自动生成、diff-aware 模式）移植到本项目 [skills/qa/SKILL.md](../../../skills/qa/SKILL.md)，保持零依赖、不引入 `$B` 浏览器子系统。

**Architecture:** 只改一个 SKILL.md（约 440 行 → 约 500 行）+ 补齐 references。**不**移植 gstack 的 preamble 基础设施（telemetry/learnings/routing/auto-update）。**不**移植 `$B browse` 二进制调用 — 浏览器场景在文末指向已存在的 `agent-browser` / `dogfood` 平台技能。CLI 测试运行器（npm/pytest/go 等）作为本技能的默认实测手段。

**Tech Stack:** Bash / Markdown / Git。无新增运行时依赖。

**参考依据:**
- 源方法论: [gstack qa/SKILL.md.tmpl](https://github.com/garrytan/gstack/blob/main/qa/SKILL.md.tmpl)
- 目标文件: [skills/qa/SKILL.md](../../../skills/qa/SKILL.md)
- 已存在的资产: [references/issue-taxonomy.md](../../../skills/qa/references/issue-taxonomy.md) · [templates/qa-report-template.md](../../../skills/qa/templates/qa-report-template.md)
- 项目原则: [CLAUDE.md](../../../CLAUDE.md)（零依赖、通用技能、单一职责 PR）

---

## 改造范围界定（Scope Fence）

| 采纳 | 不采纳 |
|---|---|
| Setup 阶段参数解析（URL / Tier / Mode / Scope / Auth） | gstack preamble（update-check / telemetry / config / slug / timeline / learnings） |
| Three Tiers：Quick / Standard / Exhaustive | `$B` / browse 二进制（`goto` / `screenshot` / `console` / `snapshot`） |
| Clean working tree 预检（commit / stash / abort 三选项） | CDP 真实浏览器模式检测 |
| Test → Fix → Verify 循环（Phase 8a-8f） | GBrain 上下文加载、模型 overlay |
| 回归测试自动生成（Phase 8e.5，带归因注释） | Plan Mode / Skill Invocation 元说明（本项目由 Qoder 平台接管） |
| WTF-likelihood 自监管 + 50 fix 硬上限 | `~/.gstack/projects/` 路径，改写为本项目相对路径 |
| Diff-aware 模式（feature 分支自动定位变更文件） | OpenClaw / 多 AI agent 多宿主适配（由本项目多平台方案接管） |
| Health Score 前后对比 + Ship Readiness |  |
| 报告双写（本地 `.qa-reports/` + plan 目录）|  |

---

## File Structure

**仅改动 3 个文件：**
- 修改：`skills/qa/SKILL.md`（完整重写主体，保留 frontmatter 并升版本号到 `3.0.0`）
- 修改：`skills/qa/references/issue-taxonomy.md`（补一个 Browser QA 的适配说明）
- 新增：`skills/qa/references/fix-loop-checklist.md`（抽取 Phase 8 的操作清单，供 SKILL.md 引用）

**不改动：**
- `skills/qa/templates/qa-report-template.md`（当前已对齐 gstack，保留）
- `skills/qa/SKILL.md.backup`（保留作为回滚依据）

---

## Task 1: 备份与前置验证

**Files:**
- 读取：`skills/qa/SKILL.md`（确认当前版本 2.0.0，441 行）
- 读取：`skills/qa/SKILL.md.backup`（确认可回滚）

- [ ] **Step 1: 确认基线**

```bash
cd /Users/thomasxing/workspace/2026/3月份计划/AI研发/spec-kit
wc -l skills/qa/SKILL.md skills/qa/SKILL.md.backup
diff skills/qa/SKILL.md skills/qa/SKILL.md.backup | head -5
```

Expected: 当前 SKILL.md 与 .backup 有差异（backup 是 v1）；两者都存在。

- [ ] **Step 2: 当前 SKILL.md 中提交改造前快照**

```bash
git add skills/qa/SKILL.md
git commit -m "chore(qa): snapshot before gstack v3 integration"
```

Expected: 得到干净工作树，便于逐 task 原子提交。

---

## Task 2: 重写 frontmatter + 顶部文档说明

**Files:**
- Modify: `skills/qa/SKILL.md:1-27`

- [ ] **Step 1: 升级 frontmatter**

将原 frontmatter 替换为：

```yaml
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
```

- [ ] **Step 2: 重写顶部 overview 段**

替换 `# /qa: Enhanced Quality Assurance` 到第一个 `## Step 0` 之前的所有段落为：

```markdown
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
```

- [ ] **Step 3: 提交**

```bash
git add skills/qa/SKILL.md
git commit -m "feat(qa): bump to v3.0.0, rewrite overview for gstack methodology"
```

---

## Task 3: Setup 阶段（参数解析 + 预检）

**Files:**
- Modify: `skills/qa/SKILL.md`（替换原 Step 0-1）

- [ ] **Step 1: 插入 Setup 段**

在 overview 之后插入：

````markdown
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
````

- [ ] **Step 2: 提交**

```bash
git add skills/qa/SKILL.md
git commit -m "feat(qa): add Setup phase with tier/mode/clean-tree preflight"
```

---

## Task 4: Phase 1-3（测试框架检测 + 基线运行 + 结果分析）

**Files:**
- Modify: `skills/qa/SKILL.md`（保留原有的测试框架检测代码，重构为 Phase 结构）

- [ ] **Step 1: Phase 1 测试框架检测**

把原 Step 1（第 49-112 行）改造为 `## Phase 1: 识别测试手段`，保留 node/ruby/python/go/rust/php/make 检测逻辑，**修复原文件中 bash heredoc 缩进错误**（原 Step 5 有残缺的 `elif` 分支）。

输出约定变量：`PROJECT_TYPE` / `TEST_COMMAND` / `TEST_FRAMEWORK`。

- [ ] **Step 2: Phase 2 基线运行**

把原 Step 2 改造为 `## Phase 2: 基线运行（baseline）`：

```bash
BASELINE_LOG=".qa-reports/baseline-$(date +%Y%m%d-%H%M%S).log"
eval "$TEST_COMMAND" 2>&1 | tee "$BASELINE_LOG"
BASELINE_EXIT=${PIPESTATUS[0]}
```

- [ ] **Step 3: Phase 3 解析结果 + 计算基线 Health Score**

把原 Step 3 改造为 `## Phase 3: 解析结果`，追加 Health Score 计算骨架：

```bash
# 维度分（每项 0-100，加权平均）
SCORE_TESTS=$([[ $BASELINE_EXIT -eq 0 ]] && echo 100 || echo $(( 100 - FAIL_COUNT * 10 )))
SCORE_CONSOLE=100    # 本技能无浏览器，默认满分；浏览器场景由 agent-browser 补
SCORE_LINKS=100      # 同上
HEALTH_BASELINE=$(( (SCORE_TESTS + SCORE_CONSOLE + SCORE_LINKS) / 3 ))
echo "HEALTH_BASELINE=$HEALTH_BASELINE"
```

- [ ] **Step 4: 修复原文件残缺的 elif 分支**

原第 286-293 行存在重复/悬空 `elif` 块，必须删除。

- [ ] **Step 5: 提交**

```bash
git add skills/qa/SKILL.md
git commit -m "feat(qa): restructure framework detection into Phase 1-3, fix stray elif"
```

---

## Task 5: Phase 4 Diff-aware 模式

**Files:**
- Modify: `skills/qa/SKILL.md`（新增 Phase 4）

- [ ] **Step 1: 插入 Phase 4**

````markdown
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
````

- [ ] **Step 2: 提交**

```bash
git add skills/qa/SKILL.md
git commit -m "feat(qa): add Phase 4 diff-aware mode for feature branches"
```

---

## Task 6: Phase 5 Triage（按 tier 决定要修什么）

**Files:**
- Modify: `skills/qa/SKILL.md`（替换原 Step 4 Determine Action）

- [ ] **Step 1: 插入 Phase 5**

````markdown
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
````

- [ ] **Step 2: 提交**

```bash
git add skills/qa/SKILL.md
git commit -m "feat(qa): add Phase 5 triage with tier-based fix selection"
```

---

## Task 7: Phase 6 Fix Loop（8a-8f 原子修复）

**Files:**
- Create: `skills/qa/references/fix-loop-checklist.md`
- Modify: `skills/qa/SKILL.md`（替换原 Step 5 Analyze and Fix）

- [ ] **Step 1: 创建 fix-loop-checklist.md**

````markdown
# Fix Loop Checklist（Phase 6 执行清单）

每个 fixable issue 按 severity 降序，**严格**执行以下 6 步：

## 6a. Locate source
- `grep -rn "<error message>"` 定位抛错位置
- `glob` 定位功能相关文件
- **禁止**修改与 issue 无关的文件

## 6b. Fix（最小变更）
- 读源码，理解上下文
- 只做最小修改 —— 不重构、不加功能、不"顺手改进"无关代码

## 6c. Commit（原子化）
```bash
git add <仅-改动的文件>
git commit -m "fix(qa): ISSUE-NNN — <一句话描述>"
```
**一个 issue = 一个 commit**，严禁打包。

## 6d. Re-test（验证）
- 重跑该 issue 相关测试（非全量）
- 若是运行时报错，复现原触发路径

## 6e. Classify
- `verified` — 重测通过，无新错误
- `best-effort` — 改了但无法完全验证（如需要外部服务）
- `reverted` — 发现回归 → `git revert HEAD` → 转 deferred

## 6e.5. 自动回归测试（skip 条件见 SKILL.md Phase 7）
见下节。

## 6f. Self-Regulation
见 SKILL.md Phase 8。
````

- [ ] **Step 2: SKILL.md 中插入 Phase 6**

````markdown
## Phase 6: Fix Loop

对每个待修复 issue，按 severity 降序执行完整 6 步流程。操作清单见
[references/fix-loop-checklist.md](references/fix-loop-checklist.md)。

关键约束：
1. **原子提交** — 一个 issue 一个 commit，commit message 格式 `fix(qa): ISSUE-NNN — <desc>`
2. **最小变更** — 只改直接导致 bug 的文件
3. **验证后分类** — verified / best-effort / reverted / deferred
4. **异常终止** — 任一 fix 引发测试回归 → 立即 `git revert HEAD` → 该 issue 转 deferred
````

- [ ] **Step 3: 提交**

```bash
git add skills/qa/references/fix-loop-checklist.md skills/qa/SKILL.md
git commit -m "feat(qa): add Phase 6 atomic fix loop with checklist reference"
```

---

## Task 8: Phase 7 回归测试自动生成

**Files:**
- Modify: `skills/qa/SKILL.md`（新增 Phase 7）

- [ ] **Step 1: 插入 Phase 7**

````markdown
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
````

- [ ] **Step 2: 提交**

```bash
git add skills/qa/SKILL.md
git commit -m "feat(qa): add Phase 7 auto-generated regression tests with attribution"
```

---

## Task 9: Phase 8 自监管（WTF-likelihood）

**Files:**
- Modify: `skills/qa/SKILL.md`（新增 Phase 8）

- [ ] **Step 1: 插入 Phase 8**

````markdown
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
````

- [ ] **Step 2: 提交**

```bash
git add skills/qa/SKILL.md
git commit -m "feat(qa): add Phase 8 WTF-likelihood self-regulation with hard cap 50"
```

---

## Task 10: Phase 9-10 最终 QA + 报告生成

**Files:**
- Modify: `skills/qa/SKILL.md`（替换原 Step 6-7）

- [ ] **Step 1: 插入 Phase 9**

````markdown
## Phase 9: Final QA

所有修复完成后：
1. 重跑受影响范围的测试（Standard/Exhaustive tier 下重跑全量）
2. 计算 `HEALTH_FINAL`（维度同 Phase 3）
3. **若 `HEALTH_FINAL < HEALTH_BASELINE`** → 在报告顶部用 `⚠️ REGRESSION` 明显告警
````

- [ ] **Step 2: 插入 Phase 10**

````markdown
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
````

- [ ] **Step 3: 删除原 Step 6-7 的残留代码**

- [ ] **Step 4: 提交**

```bash
git add skills/qa/SKILL.md
git commit -m "feat(qa): add Phase 9-10 final QA verification and report generation"
```

---

## Task 11: 更新 references + 末尾 Usage Notes

**Files:**
- Modify: `skills/qa/references/issue-taxonomy.md`
- Modify: `skills/qa/SKILL.md`（末尾）

- [ ] **Step 1: issue-taxonomy.md 追加一节**

在文件末尾追加：

````markdown
---

## CLI QA vs Browser QA 适配

本项目 `/qa` 默认走 CLI 测试框架路径（无真实浏览器）：
- **适用**：Console/Errors、Functional（代码逻辑）、Performance（单测可覆盖部分）
- **不适用**：Visual/UI、UX 流程、Accessibility（需真实 DOM）

遇到**必须真实浏览器**的场景时：
1. 本技能只负责单测/集成测试层
2. 浏览器实测请调用平台级 `agent-browser` 或 `dogfood` 技能
3. 回归测试可以是"headless + 断言行为"，不必追求像素级
````

- [ ] **Step 2: SKILL.md 末尾替换 Usage Notes**

````markdown
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
````

- [ ] **Step 3: 提交**

```bash
git add skills/qa/references/issue-taxonomy.md skills/qa/SKILL.md
git commit -m "docs(qa): document CLI vs Browser QA boundary and related skills"
```

---

## Task 12: 端到端自检

**Files:**
- Read: `skills/qa/SKILL.md`（最终版）

- [ ] **Step 1: 结构自检**

```bash
grep -n "^## " skills/qa/SKILL.md
```

Expected（顺序必须严格）：
```
## Setup
## Phase 1: 识别测试手段
## Phase 2: 基线运行（baseline）
## Phase 3: 解析结果
## Phase 4: Diff-aware 模式
## Phase 5: Triage
## Phase 6: Fix Loop
## Phase 7: 回归测试生成
## Phase 8: Self-Regulation
## Phase 9: Final QA
## Phase 10: Report
## Usage Notes
## 与相关技能的关系
```

- [ ] **Step 2: frontmatter 验证**

```bash
head -20 skills/qa/SKILL.md | grep -E "version:|name:"
```

Expected: `version: 3.0.0` 和 `name: qa`

- [ ] **Step 3: 禁用词扫描（防残留）**

```bash
grep -nE "gstack-config|gstack-update-check|gstack-slug|gstack-learnings|\\\$B goto|\\\$B screenshot|CDP_MODE|OPENCLAW_SESSION" skills/qa/SKILL.md
```

Expected: 无输出（这些 gstack 私有基础设施不应残留）。

- [ ] **Step 4: 引用完整性**

```bash
ls skills/qa/references/issue-taxonomy.md skills/qa/references/fix-loop-checklist.md skills/qa/templates/qa-report-template.md
```

Expected: 三个文件都存在。

- [ ] **Step 5: git log 验收**

```bash
git log --oneline skills/qa/ | head -15
```

Expected: 看到 Task 1-11 对应的 11 个原子 commit，顺序清晰。

- [ ] **Step 6: 最终 commit**

```bash
git add -A skills/qa/
# 若有遗漏统一收尾
git diff --cached --stat
# 仅在有未提交内容时：
git commit -m "chore(qa): final polish after gstack v3 integration" || true
```

---

## 成功标准（Acceptance Criteria）

- [x] `skills/qa/SKILL.md` 版本升至 3.0.0，保留原 frontmatter 风格
- [x] 10 个 Phase 结构齐全（Setup + Phase 1-10）
- [x] 支持三级 tier、WTF-likelihood 50-fix 硬上限、回归测试自动生成、diff-aware
- [x] **零新增依赖**：不引入 `$B` / bin/gstack-* / telemetry
- [x] 浏览器场景明确指向 `agent-browser` / `dogfood`
- [x] 11 个原子 commit 可逆（失败可按任意粒度回滚）
- [x] `SKILL.md.backup` 保留，作为 v1 回滚兜底
- [x] Task 12 所有自检通过

---

## 风险与缓解

| 风险 | 缓解 |
|---|---|
| 重写后行文过长超出 Skill 加载阈值 | 把 Phase 6 细节抽到 fix-loop-checklist.md；控制主文件 ≤ 500 行 |
| WTF-likelihood 阈值过于激进导致频繁打断 | 首版保持 gstack 原值（20% / 50 fix），观察一周后再调 |
| Diff-aware 在 monorepo / 大变更下覆盖不足 | 回退到全量 `$TEST_COMMAND`，并在报告中标注 "fallback to full" |
| 用户期望真实浏览器场景 | SKILL.md 明确指引 + Usage Notes 说明边界 |

---

## 执行交接

计划已保存至 `docs/superpowers/plans/2026-04-29-qa-skill-gstack-integration.md`。两种执行方式：

**1. Subagent-Driven（推荐）** —— 每个 Task 派发独立 subagent，任务间 review
**2. Inline Execution** —— 当前会话按 Task 顺序执行，每个 Task 完成后 checkpoint

请告诉我采用哪种方式，我就按对应 sub-skill 开始执行。
