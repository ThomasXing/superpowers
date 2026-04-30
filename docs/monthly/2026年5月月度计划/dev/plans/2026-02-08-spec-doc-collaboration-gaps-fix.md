# Spec Doc 协作逻辑缺口修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 打通 Spec Doc 产研协同链路中 8 个协作逻辑缺口，使文档体系（PRD→设计→测试→概览→经验）与执行体系（brainstorm→plans→subagent→review）形成闭环。

**Architecture:** 通过修改关键技能的 SKILL.md 文件（brainstorming、subagent-driven-development、requesting-code-review、verification-before-completion），增加 Spec Doc 文档感知和自动提交能力；补充 document-dev 对 PRD 的自动读取逻辑；统一 writing-plans 与 document-dev 的计划存储路径。

**Tech Stack:** Bash scripts、SKILL.md (Markdown)、Git commit hooks、YAML config

**深度分析文档:** 参见对话记录中的 "Spec Doc 产研协同方案：协作逻辑缺口深度分析"

---

## 文件映射

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `skills/brainstorming/SKILL.md` | Modify: L32, L66 | 第9步增加 Spec Doc 模式分支 |
| `skills/subagent-driven-development/spec-reviewer-prompt.md` | Modify | 增加 PRD/设计文档约束检查 |
| `skills/subagent-driven-development/SKILL.md` | Modify: L274 | 增加 Spec Doc 文档作为 subagent 输入 |
| `skills/writing-plans/SKILL.md` | Modify: L18 | 统一计划存储路径 |
| `skills/document-dev/SKILL.md` | Modify | 增强 PRD 自动读取 + 增加 test-report 回写 |
| `skills/requesting-code-review/SKILL.md` | Modify | 增加审查结果自动提交到 review-report |
| `skills/verification-before-completion/SKILL.md` | Modify | 增加验证结果自动提交到 test-report |
| `skills/document-compound/SKILL.md` | Modify: L32-36 | 明确功能级/月度级两种触发模式 |
| `scripts/document/document-dev-wrapper.sh` | Create | document-dev 的 git-based 封装脚本 |
| `scripts/document/document-test-wrapper.sh` | Create | document-test 的 git-based 封装脚本 |
| `hooks/post-commit-doc-overview` | Create | document-overview 自动更新 hook |

---

### Task 1: brainstorming 终态增加 Spec Doc 模式感知

**Files:**
- Modify: `skills/brainstorming/SKILL.md:32-33`
- Modify: `skills/brainstorming/SKILL.md:66`

**Context:** brainstorming 目前第9步写死调用 writing-plans，需要增加 `.sonli-spec-doc/config.yaml` 检测分支。

- [ ] **Step 1: 读取当前 brainstorming/SKILL.md 第9步和流程图内容**

读取第 32-33 行（Checklist 第9步）和第 66 行（终态声明）。

- [ ] **Step 2: 修改 Checklist 第9步**

将第9步从：
```
9. **Transition to implementation** — invoke writing-plans skill to create implementation plan
```
改为：
```
9. **Transition to implementation** — Check for `.sonli-spec-doc/config.yaml`:
   - If exists (Spec Doc mode): invoke `document-pm` skill, passing the design doc as input context
   - If absent (pure dev mode): invoke `writing-plans` skill to create implementation plan
```

- [ ] **Step 3: 修改流程图终态声明**

将第 66 行从：
```
The terminal state is invoking writing-plans. Do NOT invoke frontend-design, mcp-builder, or any other implementation skill. The ONLY skill you invoke after brainstorming is writing-plans.
```
改为：
```
The terminal state depends on the project mode. Check for `.sonli-spec-doc/config.yaml`:
- If it exists (Spec Doc team mode): the ONLY skill you invoke is `document-pm` (pass the design doc as context for PRD generation).
- If it does not exist (individual dev mode): the ONLY skill you invoke is `writing-plans`.
Never invoke frontend-design, mcp-builder, or any other implementation skill directly after brainstorming.
```

- [ ] **Step 4: 更新流程图**

修改第 48 行流程图终态节点：
```dot
"Invoke writing-plans skill" [shape=doublecircle];
```
改为：
```dot
"Check .sonli-spec-doc/config.yaml?" [shape=diamond];
"Invoke document-pm skill" [shape=doublecircle];
"Invoke writing-plans skill" [shape=doublecircle];
```
并更新对应的连线。

- [ ] **Step 5: 提交**

```bash
git add skills/brainstorming/SKILL.md
git commit -m "fix(spec-kit): add Spec Doc mode branch to brainstorming transition (P0 gap #1)"
```

---

### Task 2: subagent spec-reviewer 增加 PRD/设计文档约束检查

**Files:**
- Modify: `skills/subagent-driven-development/spec-reviewer-prompt.md`

**Context:** spec-reviewer 当前只检查实现是否符合 writing-plans 的计划，完全不感知 PRD 和功能设计文档。这是整个 Spec Doc 体系最大的质量门禁缺失。

- [ ] **Step 1: 读取 spec-reviewer-prompt.md 当前内容**

- [ ] **Step 2: 增加 Spec Doc 约束输入章节**

在 spec-reviewer-prompt.md 的 context 输入部分增加：

```markdown
## Additional Spec Doc Constraints (if available)

Before reviewing spec compliance, read these documents if they exist:

1. **PRD Document**: `docs/monthly/*/pm/prd/*.md` (find the active plan via `.sonli-spec-doc/config.yaml` → `active_plan`)
   - Check: Does the implementation meet the functional requirements in the PRD?
   - Check: Are acceptance criteria from the PRD addressed?

2. **Design Document**: `docs/monthly/*/dev/*.md` (same active plan)
   - Check: Does the architecture match the design document?
   - Check: Are interface specifications followed?
   - Check: Are data structures as designed?

Report any violations of PRD or design constraints as separate findings from plan compliance issues.
```

- [ ] **Step 3: 增加文档读取函数**

在 prompt 开头增加读取指令：

```markdown
## Context Loading Order

1. Read the plan file provided in this dispatch (writing-plans output)
2. If `.sonli-spec-doc/config.yaml` exists:
   a. Extract `active_plan` value
   b. Read ALL files matching `docs/monthly/<active_plan>/pm/prd/*.md`
   c. Read ALL files matching `docs/monthly/<active_plan>/dev/*.md`
3. Read the code diff (BASE_SHA to HEAD_SHA)
4. Perform compliance review against all three sources
```

- [ ] **Step 4: 修改 review 输出格式**

增加新的输出分类：

```markdown
## Review Results

### Plan Compliance (from writing-plans)
- [ ] Task N: compliant / non-compliant (details)

### PRD Constraints (from document-pm)
- [ ] Requirement X: met / missing / violated (details)

### Design Constraints (from document-dev)
- [ ] Architecture Y: followed / deviated (details)
```

- [ ] **Step 5: 提交**

```bash
git add skills/subagent-driven-development/spec-reviewer-prompt.md
git commit -m "fix(spec-kit): add PRD/design doc constraints to spec reviewer (P0 gap #2)"
```

---

### Task 3: writing-plans 统一存储路径 + 读取 document-dev 计划

**Files:**
- Modify: `skills/writing-plans/SKILL.md:18-19`
- Modify: `skills/writing-plans/SKILL.md:122-132`（Self-Review 部分）

**Context:** 当前 writing-plans 存到 `docs/superpowers/plans/`，与 document-dev 的计划独立。需要统一并增加对 document-dev 计划的读取。

- [ ] **Step 1: 修改默认存储路径**

将第 18-19 行从：
```markdown
**Save plans to:** `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`
- (User preferences for plan location override this default)
```
改为：
```markdown
**Save plans to:**
- If `.sonli-spec-doc/config.yaml` exists: `docs/monthly/<active_plan>/dev/plans/YYYY-MM-DD-<feature-name>.md`
- Otherwise: `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`
```

- [ ] **Step 2: 在 Self-Review 前增加"读取 document-dev 计划"步骤**

在 Self-Review 章节前增加：

```markdown
## Design Plan Alignment (Spec Doc mode only)

If `.sonli-spec-doc/config.yaml` exists, before running self-review:

1. Extract `active_plan` from config
2. Check if `docs/monthly/<active_plan>/dev/plans/` has any documents
3. If yes: read them and ensure your implementation plan aligns with the architectural decisions documented there
4. Report any misalignment and resolve it before proceeding to self-review
```

- [ ] **Step 3: 更新 Plan Document Header**

确保生成的计划文档 header 中引用 source documents：

```markdown
> **Source Documents:**
> - PRD: `docs/monthly/<active_plan>/pm/prd/<prd-file>.md` (if available)
> - Design: `docs/monthly/<active_plan>/dev/<design-file>.md` (if available)
> - Design Plan: `docs/monthly/<active_plan>/dev/plans/<plan-file>.md` (if available)
```

- [ ] **Step 4: 提交**

```bash
git add skills/writing-plans/SKILL.md
git commit -m "fix(spec-kit): unify writing-plans storage with document-dev and add design plan alignment (P1 gap #5)"
```

---

### Task 4: document-dev 增强 PRD 自动读取 + 增加 test-report 回写指导

**Files:**
- Modify: `skills/document-dev/SKILL.md`（功能设计生成章节）
- Modify: `skills/document-dev/SKILL.md`（Git 提交使用方式章节）

**Context:** document-dev 已有 PRD 自动读取，但路径读取逻辑不完整。同时需要增加 test-report 回写指导。

- [ ] **Step 1: 增强 PRD 自动读取路径**

在"核心功能 → 功能设计生成"部分，将：
```markdown
- **输入依赖**: 自动读取相关PRD文档作为输入
```
改为：
```markdown
- **输入依赖**: 
  1. 读取 `.sonli-spec-doc/config.yaml` 获取 `active_plan`
  2. 自动读取 `docs/monthly/<active_plan>/pm/prd/` 下所有 PRD 文档
  3. 如果 PRD 不存在，提示用户先生成 PRD（/document-pm 生成）
```

- [ ] **Step 2: 增加 test-report 回写指导**

在"Git 提交使用方式"章节末尾增加：

```bash
# 验收测试通过后，将测试摘要回写到 test-report 目录
TEST_REPORT_PATH="docs/monthly/$(get_active_plan)/test/test-report"
mkdir -p "$TEST_REPORT_PATH"

# 写入测试摘要（AI 生成）
cat > "$TEST_REPORT_PATH/<功能名称>-report.md" << EOF
# 测试验收报告 - <功能名称>
## 测试执行
- 执行时间: $(date +%Y-%m-%d)
- 测试用例总数: N
- 通过数: M
- 失败数: K
- 通过率: X%
## 验证命令输出
\`\`\`
[粘贴关键测试命令输出]
\`\`\`
## 结论
[通过/不通过 + 说明]
EOF

git add "$TEST_REPORT_PATH/"
git commit -m "docs(test): add verification report - <功能名称>"
git push
```

- [ ] **Step 3: 创建 document-dev-wrapper.sh**

```bash
#!/bin/bash
# document-dev Git 仓库存储封装脚本
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/repo.sh"

SKILL_NAME="document-dev"

init_document-dev() {
    echo "[INFO] 初始化 document-dev 技能..."
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "[ERROR] 当前目录不是 git 仓库" >&2
        return 1
    fi
    local plan
    plan=$(get_active_plan)
    if [ -z "$plan" ]; then
        echo "[ERROR] 未配置活跃计划" >&2
        return 1
    fi
    echo "[INFO] 活跃计划: $plan"
    return 0
}

upload_document-dev_document() {
    local document_file="$1"
    echo "[INFO] 提交功能设计文档: $document_file"
    init_document-dev || return 1
    if [ ! -f "$document_file" ]; then
        echo "[ERROR] 文档文件不存在: $document_file" >&2
        return 1
    fi
    save_design "$document_file"
    echo "[OK] 功能设计文档已提交到仓库"
    return 0
}

main() {
    local command="${1:-help}"
    case "$command" in
        "upload") upload_document-dev_document "${@:2}" ;;
        "init") init_document-dev ;;
        "help")
            echo "使用方法: $0 <command>"
            echo "命令:"
            echo "  upload <文件> - 提交功能设计文档到仓库"
            echo "  init        - 初始化技能"
            echo "  help        - 显示帮助"
            ;;
        *) echo "未知命令: $command"; return 1 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    main "$@"
fi
```

- [ ] **Step 4: 提交**

```bash
chmod +x scripts/document/document-dev-wrapper.sh
git add skills/document-dev/SKILL.md scripts/document/document-dev-wrapper.sh
git commit -m "feat(spec-kit): enhance document-dev PRD auto-read and add test-report writeback guidance (P1 gap #3, #6)"
```

---

### Task 5: requesting-code-review 自动提交审查结果到 review-report

**Files:**
- Modify: `skills/requesting-code-review/SKILL.md`

**Context:** 当前 code review 结果只在对话中，从不落地到 `docs/monthly/<plan>/dev/review-report/`。

- [ ] **Step 1: 读取 requesting-code-review/SKILL.md 当前内容**

- [ ] **Step 2: 在 "3. Act on feedback" 后增加新步骤**

在第 47 行后增加：

```markdown
**4. Persist review results (Spec Doc mode):**

If `.sonli-spec-doc/config.yaml` exists, after acting on feedback:

```bash
# Extract active plan
ACTIVE_PLAN=$(grep 'active_plan' .sonli-spec-doc/config.yaml | awk '{print $2}' | tr -d '"')

# Create review report
REPORT_DIR="docs/monthly/${ACTIVE_PLAN}/dev/review-report"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/<feature-name>-review.md"

cat > "$REPORT_FILE" << EOF
# Code Review Report - <feature-name>
## Review Metadata
- Date: $(date +%Y-%m-%d)
- Base SHA: $BASE_SHA
- Head SHA: $HEAD_SHA
- Reviewer: superpowers:code-reviewer subagent

## Review Findings
### Strengths
[From reviewer output]

### Issues Found
- **Critical:** [list]
- **Important:** [list]
- **Minor:** [list]

## Resolution
- Issues fixed: [list]
- Remaining concerns: [list]

## Assessment
[Ready to merge / Needs further work]
EOF

git add "$REPORT_DIR/"
git commit -m "docs(review): add code review report - <feature-name>"
git push
```
```

- [ ] **Step 3: 更新 Integration with Workflows 部分**

在 "Subagent-Driven Development" 条目下增加：
```
- Review reports auto-persisted to `docs/monthly/<plan>/dev/review-report/`
```

- [ ] **Step 4: 提交**

```bash
git add skills/requesting-code-review/SKILL.md
git commit -m "feat(spec-kit): persist code review results to review-report directory (P1 gap #4)"
```

---

### Task 6: verification-before-completion 自动提交验证结果到 test-report

**Files:**
- Modify: `skills/verification-before-completion/SKILL.md`

**Context:** 验证结果只在对话中，需要自动写入 test-report 目录。

- [ ] **Step 1: 读取 verification-before-completion/SKILL.md 当前内容**

- [ ] **Step 2: 增加自动提交章节**

在 "The Bottom Line" 章节前（第 133 行前）增加：

```markdown
## Persisting Verification Results (Spec Doc mode)

After successful verification in a Spec Doc project (`.sonli-spec-doc/config.yaml` exists):

```bash
ACTIVE_PLAN=$(grep 'active_plan' .sonli-spec-doc/config.yaml | awk '{print $2}' | tr -d '"')
REPORT_DIR="docs/monthly/${ACTIVE_PLAN}/test/test-report"
mkdir -p "$REPORT_DIR"

cat > "$REPORT_DIR/verification-$(date +%Y%m%d).md" << EOF
# Verification Report
## Date: $(date +%Y-%m-%d)
## Verification Commands
[Command]: [Output summary]
## Result: PASS/FAIL
## Notes
[Any relevant observations]
EOF

git add "$REPORT_DIR/"
git commit -m "docs(test): add verification report"
git push
```

**Note:** This is a guideline for human partners or agentic workflows. The core iron law of verification (run → read → claim) still applies.
```

- [ ] **Step 3: 提交**

```bash
git add skills/verification-before-completion/SKILL.md
git commit -m "feat(spec-kit): guide persisting verification results to test-report (P1 gap #6)"
```

---

### Task 7: document-compound 明确功能级/月度级双触发模式 + 创建 document-test-wrapper

**Files:**
- Modify: `skills/document-compound/SKILL.md:32-36`
- Create: `scripts/document/document-test-wrapper.sh`

**Context:** document-compound 的触发时机不明确，需要区分功能级和月度级。同时创建 document-test-wrapper.sh。

- [ ] **Step 1: 修改 document-compound 触发模式描述**

将第 32-36 行从：
```markdown
### 3. 知识沉淀与上传
- **格式**: `/document-compound 上传`
- **知识归档**: 将经验总结归档到知识库的 `knowledge-base/compound/` 目录
```
改为：
```markdown
### 3. 知识沉淀与提交（双触发模式）
- **功能级触发**: `/document-compound 生成 功能级 "<功能名称>"`
  - 收集本次功能迭代的所有文档（PRD、设计、测试、审查报告）
  - 触发时机：`finishing-a-development-branch` 完成后自动建议
  - 归档到：`docs/knowledge-base/compound/<功能名称>-<日期>.md`
- **月度级触发**: `/document-compound 生成 月度级 "<月度计划名>"`
  - 收集整个月度计划周期的所有文档
  - 触发时机：月度计划结束、切换新计划前
  - 归档到：`docs/knowledge-base/compound/<月度计划名>-summary.md`

**自动触发建议**：在 `finishing-a-development-branch` 技能终态增加提示：
> "Branch finished. Consider running `/document-compound 生成 功能级 "<功能名称>"` to capture learnings from this feature."
```

- [ ] **Step 2: 创建 document-test-wrapper.sh**

```bash
#!/bin/bash
# document-test Git 仓库存储封装脚本
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/repo.sh"

SKILL_NAME="document-test"

init_document-test() {
    echo "[INFO] 初始化 document-test 技能..."
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "[ERROR] 当前目录不是 git 仓库" >&2
        return 1
    fi
    local plan
    plan=$(get_active_plan)
    if [ -z "$plan" ]; then
        echo "[ERROR] 未配置活跃计划" >&2
        return 1
    fi
    echo "[INFO] 活跃计划: $plan"
    return 0
}

upload_document-test_document() {
    local document_file="$1"
    local doc_type="${2:-testcases}"  # testcases | test-report
    
    echo "[INFO] 提交测试文档: $document_file (类型: $doc_type)"
    init_document-test || return 1
    
    if [ ! -f "$document_file" ]; then
        echo "[ERROR] 文档文件不存在: $document_file" >&2
        return 1
    fi
    
    if [ "$doc_type" = "testcases" ]; then
        save_testcases "$document_file"
    elif [ "$doc_type" = "test-report" ]; then
        save_test_report "$document_file"
    else
        echo "[ERROR] 未知文档类型: $doc_type" >&2
        return 1
    fi
    
    echo "[OK] 测试文档已提交到仓库"
    return 0
}

main() {
    local command="${1:-help}"
    case "$command" in
        "upload") upload_document-test_document "${@:2}" ;;
        "init") init_document-test ;;
        "help")
            echo "使用方法: $0 <command>"
            echo "命令:"
            echo "  upload <文件> [类型] - 提交测试文档 (类型: testcases|test-report)"
            echo "  init               - 初始化技能"
            echo "  help               - 显示帮助"
            ;;
        *) echo "未知命令: $command"; return 1 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    main "$@"
fi
```

- [ ] **Step 3: 创建 post-commit hook 用于 document-overview 自动更新**

```bash
#!/bin/bash
# hooks/post-commit-doc-overview
# 当 docs/monthly/ 下的文档有变更时，自动提醒更新 document-overview

# 获取本次 commit 变更的文件列表
CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r HEAD)

# 检查是否变更了 Spec Doc 月度计划目录
if echo "$CHANGED_FILES" | grep -q "docs/monthly/"; then
    ACTIVE_PLAN=$(grep 'active_plan' .sonli-spec-doc/config.yaml 2>/dev/null | awk '{print $2}' | tr -d '"')
    if [ -n "$ACTIVE_PLAN" ]; then
        echo ""
        echo "═══════════════════════════════════════════════════════"
        echo "📊 Spec Doc 文档已变更，建议更新项目概览："
        echo "   /document-overview 更新"
        echo "═══════════════════════════════════════════════════════"
        echo ""
    fi
fi
```

- [ ] **Step 4: 提交**

```bash
chmod +x scripts/document/document-test-wrapper.sh hooks/post-commit-doc-overview
git add skills/document-compound/SKILL.md scripts/document/document-test-wrapper.sh hooks/post-commit-doc-overview
git commit -m "feat(spec-kit): clarify document-compound dual trigger modes and add wrappers/hooks (P2 gap #7, #8)"
```

---

## 验收标准

所有任务完成后，验证以下闭环：

1. ✅ `/brainstorm` → 检测 Spec Doc 模式 → 调用 `document-pm`（不再直接 writing-plans）
2. ✅ `document-pm` 生成 PRD → `document-dev` 自动读取 PRD → 生成功能设计
3. ✅ `writing-plans` 读取 document-dev 计划 → 生成实现计划（存入统一路径）
4. ✅ `subagent-driven-development` 执行 → spec-reviewer 同时检查 PRD/设计/计划
5. ✅ `requesting-code-review` 完成 → 自动写入 review-report 并 git commit
6. ✅ `verification-before-completion` 通过 → 自动写入 test-report 并 git commit
7. ✅ `document-overview` 通过 hook 提醒更新
8. ✅ `finishing-a-development-branch` → 建议执行 `document-compound 生成 功能级`

---

## 回滚策略

每个任务独立提交，可按需要单独 revert：
- Task 1 revert: `git revert HEAD~6`（恢复 brainstorming 原行为）
- Task 2 revert: `git revert HEAD~5`（恢复 spec-reviewer 原行为）
- 以此类推...

每个 revert 不会影响其他任务的修复。
