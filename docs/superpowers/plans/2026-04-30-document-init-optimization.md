# Document-Init 技能优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 document 系统的文档目录从 `docs/monthly/` 迁移到 `.sonli-spec-doc/{计划名称}/`，并实现"本地项目文档 → .sonli-spec-doc/ → 远程文档中心仓库"的两阶段同步上传链路。

**Architecture:** `.sonli-spec-doc/` 成为统一的本地文档工作区（不入代码仓库），所有 document 子技能读写该目录。上传时先将用户指定源文件拷贝到 `.sonli-spec-doc/{计划名称}/` 对应子目录，再通过 git clone/push 同步到远程文档中心仓库。远程文档中心仓库地址在 init 时由用户输入。

**Tech Stack:** Shell 脚本、Markdown 技能文件、Git

---

## 文件变更清单

| 操作 | 文件路径 | 职责 |
|------|----------|------|
| **修改** | `skills/document-init/SKILL.md` | 核心：目录路径迁移、新增 dev/api、远程仓库地址交互、两阶段同步逻辑 |
| **修改** | `skills/document-pm/SKILL.md` | 路径前缀 `docs/monthly/` → `.sonli-spec-doc/`，上传改为两阶段 |
| **修改** | `skills/document-dev/SKILL.md` | 路径前缀变更，新增 dev/api 检查，上传支持指定源+目标子目录 |
| **修改** | `skills/document-test/SKILL.md` | 路径前缀变更，上传改为两阶段 |
| **修改** | `skills/document-overview/SKILL.md` | 路径前缀变更，上传改为两阶段 |
| **修改** | `skills/document-compound/SKILL.md` | 路径前缀变更（knowledge-base 也迁入 .sonli-spec-doc） |
| **修改** | `skills/document/SKILL.md` | 路由层目录结构文档更新 |
| **修改** | `.sonli-spec-doc/config.yaml` | `docs_root` 更新、新增 `doc_center` 配置块 |
| **新增** | `.sonli-spec-doc/scripts/sync-to-remote.sh` | 同步脚本：本地文档 → 远程文档中心仓库 |

---

### Task 1: 更新 config.yaml 配置结构

**Files:**
- Modify: `.sonli-spec-doc/config.yaml`

- [ ] **Step 1: 更新 `storage.docs_root` 并新增 `doc_center` 配置块**

在 `config.yaml` 中：
1. 将 `storage.docs_root` 从 `docs/monthly` 改为 `.sonli-spec-doc`
2. 新增 `doc_center` 配置块，包含远程文档中心仓库地址
3. `directories.dev_subdirectories` 中新增 `api`

修改内容如下（定位到现有 `storage:` 块和 `directories:` 块）：

```yaml
# storage 块 - 修改 docs_root
storage:
  mode: "git_repo"
  docs_root: ".sonli-spec-doc"          # 从 docs/monthly 改为 .sonli-spec-doc
  knowledge_base: ".sonli-spec-doc/knowledge-base"  # 从 docs/knowledge-base 改为 .sonli-spec-doc/knowledge-base
  commit_author: "spec-kit-agent"
  auto_push: true
```

在 `gitlab:` 块之后、`directories:` 块之前插入 `doc_center` 配置：

```yaml
# 远程文档中心仓库（独立于代码仓库）
doc_center:
  ssh_url: ""                           # ★ 由 /document-init 时用户输入
  hostname: ""                          # 自动从 ssh_url 解析
  repository_path: ""                   # 自动从 ssh_url 解析
  sync_strategy: "two_phase"            # local → .sonli-spec-doc → doc_center
```

`directories.dev_subdirectories` 修改：

```yaml
  dev_subdirectories:
    - "plans"
    - "api"                             # ★ 新增
    - "tasks"
    - "test-report"
    - "review-report"
```

- [ ] **Step 2: 验证 config.yaml 语法正确**

运行：`python3 -c "import yaml; yaml.safe_load(open('.sonli-spec-doc/config.yaml'))"` （如 PyYAML 可用）
或手动检查缩进一致性。

---

### Task 2: 新增 sync-to-remote.sh 同步脚本

**Files:**
- Create: `.sonli-spec-doc/scripts/sync-to-remote.sh`

- [ ] **Step 1: 创建同步脚本**

```bash
#!/bin/bash
# 松立研发文档系统 - 远程同步脚本
# 功能: 将 .sonli-spec-doc/{计划名称}/ 同步到远程文档中心仓库
# 用法: ./sync-to-remote.sh <月度计划名称> [--dry-run]

set -e

PLAN_NAME="$1"
DRY_RUN=false
[ "$2" = "--dry-run" ] && DRY_RUN=true

if [ -z "$PLAN_NAME" ]; then
    echo "用法: $0 <月度计划名称> [--dry-run]"
    echo "示例: $0 '2026年5月月度计划'"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.sonli-spec-doc/config.yaml"
DOC_DIR="$PROJECT_ROOT/.sonli-spec-doc/$PLAN_NAME"
KB_DIR="$PROJECT_ROOT/.sonli-spec-doc/knowledge-base"

echo "┌─────────────────────────────────────────┐"
echo "│   文档远程同步                          │"
echo "├─────────────────────────────────────────┤"
echo "│ 计划: $PLAN_NAME                        │"
echo "│ 模式: $([ "$DRY_RUN" = true ] && echo '试运行' || echo '正式同步') │"
echo "└─────────────────────────────────────────┘"

# 1. 读取远程文档中心仓库地址
DOC_CENTER_URL=$(grep -A5 '^doc_center:' "$CONFIG_FILE" | grep 'ssh_url:' | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)
if [ -z "$DOC_CENTER_URL" ]; then
    echo "❌ 未配置远程文档中心仓库地址 (doc_center.ssh_url)"
    echo "   请执行 /document-init '<月度计划名称>' 并输入文档中心仓库地址"
    exit 1
fi
echo "📡 远程仓库: $DOC_CENTER_URL"

# 2. 检查本地文档目录
if [ ! -d "$DOC_DIR" ]; then
    echo "❌ 本地文档目录不存在: $DOC_DIR"
    exit 1
fi
echo "📁 本地文档: $DOC_DIR"

# 3. 准备临时目录
TEMP_DIR="/tmp/sonli-doc-sync-$(date +%s)"
echo "🔄 准备临时工作区: $TEMP_DIR"

# 4. 克隆远程文档中心仓库
echo "📥 克隆远程仓库..."
git clone "$DOC_CENTER_URL" "$TEMP_DIR" 2>/dev/null || {
    echo "⚠️  克隆失败，尝试初始化为新仓库..."
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    git init
    git remote add origin "$DOC_CENTER_URL"
}

cd "$TEMP_DIR"

# 5. 同步文档
echo "📤 同步文档到临时仓库..."

# 同步月度计划文档
if [ -d "$DOC_DIR" ]; then
    mkdir -p "$(dirname "$TEMP_DIR/$PLAN_NAME")"
    rsync -av --delete "$DOC_DIR/" "$TEMP_DIR/$PLAN_NAME/" 2>/dev/null || \
        cp -r "$DOC_DIR/"* "$TEMP_DIR/$PLAN_NAME/" 2>/dev/null || true
    echo "  ✅ $PLAN_NAME/"
fi

# 同步知识库
if [ -d "$KB_DIR" ]; then
    mkdir -p "$TEMP_DIR/knowledge-base"
    rsync -av --delete "$KB_DIR/" "$TEMP_DIR/knowledge-base/" 2>/dev/null || \
        cp -r "$KB_DIR/"* "$TEMP_DIR/knowledge-base/" 2>/dev/null || true
    echo "  ✅ knowledge-base/"
fi

# 6. 提交并推送
cd "$TEMP_DIR"
if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "🔍 [试运行] 将要同步的文件:"
    git status --short
    echo ""
    echo "🔍 [试运行] 完成。未实际推送。"
else
    git add .
    if git diff --cached --quiet; then
        echo "📭 没有需要同步的变更"
    else
        git commit -m "docs: sync $PLAN_NAME - $(date +%Y-%m-%d)"
        git push -u origin main 2>/dev/null || git push -u origin master 2>/dev/null || {
            echo "⚠️  推送失败，请检查远程仓库权限和分支"
            exit 1
        }
        echo "✅ 同步完成"
    fi
fi

# 7. 清理
rm -rf "$TEMP_DIR"
echo "🧹 临时文件已清理"
```

- [ ] **Step 2: 设置脚本可执行权限**

运行：`chmod +x .sonli-spec-doc/scripts/sync-to-remote.sh`

- [ ] **Step 3: 测试脚本 --dry-run 模式**

运行：`.sonli-spec-doc/scripts/sync-to-remote.sh '2026年5月月度计划' --dry-run`
预期：输出将要同步的文件列表但未实际推送

---

### Task 3: 重写 document-init/SKILL.md

**Files:**
- Modify: `skills/document-init/SKILL.md`

这是核心变更，需要修改：
1. 目录路径从 `docs/monthly/` → `.sonli-spec-doc/`
2. 新增 `dev/api` 子目录
3. 初始化时询问远程文档中心仓库地址
4. 初始化脚本更新
5. 目录结构规范更新
6. 配置完整性检查表更新

- [ ] **Step 1: 修改技能元信息和存储策略描述**

将开头的描述和存储策略部分更新为新的路径体系。原文件第 1-13 行替换为：

```markdown
---
name: document-init
description: Use when setting up the doc directory structure in the repository for the first time, or when switching to a new monthly plan period
---

# Document-Init - 仓库文档目录初始化与管理

> 文档存入 `.sonli-spec-doc/` 工作区，通过远程文档中心仓库独立版本管理，与代码仓库分离。

**存储策略**：所有文档以 `.md` 文件形式存入 `.sonli-spec-doc/{月度计划名称}/` 目录，通过 `sync-to-remote.sh` 同步到远程文档中心仓库进行版本管理。`.sonli-spec-doc/` 不入代码仓库（已在 .gitignore 中排除）。
```

- [ ] **Step 2: 更新目录路径层级图**

原文件第 26-40 行替换为：

```
.sonli-spec-doc/ 目录路径层级:
  .sonli-spec-doc/                  ← 本地文档工作区（不入代码仓库）
  ├── config.yaml                   ← 配置（含远程文档中心仓库地址）
  ├── templates/                    ← 文档模板
  ├── scripts/
  │   └── sync-to-remote.sh         ← 同步到远程文档中心仓库
  ├── 2026年5月月度计划/              ← 活跃计划（directories.active_plan）
  │   ├── pm/prd/                   ← PRD 文档
  │   ├── dev/plans/                ← 设计文档
  │   ├── dev/api/                  ← ★ API 接口文档（新增）
  │   ├── dev/tasks/
  │   ├── dev/review-report/
  │   ├── dev/test-report/
  │   ├── test/testcases/           ← 测试用例
  │   ├── test/test-report/         ← 测试报告
  │   └── overview.md               ← 项目进度概览
  ├── 2026年6月月度计划/              ← 可切换至此
  └── knowledge-base/
      └── compound/                  ← 迭代经验沉淀
```

- [ ] **Step 3: 更新计划管理命令描述**

原文件第 42-55 行保持不变（命令格式不变）。

- [ ] **Step 4: 重写初始化执行步骤**

原文件第 57-100 行替换为：

```markdown
## 初始化执行步骤

### 阶段一：信息收集

1. **Git 环境检查**：确认当前目录是 Git 仓库（`git rev-parse --git-dir`）
2. **★ 询问远程文档中心仓库地址**（仅首次初始化）：
   ```
   📡 请输入远程文档中心仓库的 Git SSH 地址：
   示例：git@172.16.100.5:root/docs-center.git
   
   该仓库用于独立管理所有月度计划文档，与代码仓库分离。
   如不确定，可稍后在 .sonli-spec-doc/config.yaml 中手动配置 doc_center.ssh_url。
   ```
3. **验证远程仓库可达性**（可选）：`git ls-remote <用户输入的SSH地址>`

### 阶段二：配置写入

4. **配置写入（本地，不入库）**：
   - 创建 / 更新 `.sonli-spec-doc/config.yaml`
   - 写入 `storage.mode: git_repo`、`storage.docs_root: .sonli-spec-doc`
   - 写入 `doc_center.ssh_url: <用户输入的地址>`
   - 写入 `directories.active_plan` 和 `directories.plans`
   - 确保 `dev_subdirectories` 包含 `api`

### 阶段三：目录创建

5. **目录创建**：在 `.sonli-spec-doc/<活跃计划>/` 下创建完整目录结构
6. **`.gitkeep` 文件**：在每个空目录放置 `.gitkeep` 保证结构完整
7. **不再执行 git commit**：`.sonli-spec-doc/` 整体不入代码仓库

### 阶段四：首次同步（可选）

8. **首次同步提示**：
   ```
   ✅ 本地文档目录结构已创建。
   📡 远程文档中心仓库：<用户输入的地址>
   
   后续使用 document-* 子技能（pm/dev/test/overview/compound）生成/上传文档后，
   系统会自动将文档同步到远程文档中心仓库。
   
   也可以手动执行同步：
   ./.sonli-spec-doc/scripts/sync-to-remote.sh '<月度计划名称>'
   ```

### ❗ 配置文件安全原则（重要）

**`.sonli-spec-doc/` 必须被 `.gitignore` 排除，绝不入版本库**，原因：

- 可能包含 **内网 IP / GitLab hostname**
- 可能包含 **个人账号名 / commit_author**
- 包含 **远程文档中心仓库地址**
- 未来可能写入 **glab PAT / API token / SSH key 路径**
- 初始化时间戳、本机路径等是机器相关状态

**团队同步方式**：每个团队成员在自己的工作区独立执行 `/document-init '<同一计划名>'` 并输入相同的文档中心仓库地址，而不是共享 config.yaml。
```

- [ ] **Step 5: 更新初始化脚本示例**

原文件第 76-100 行的脚本示例替换为：

```bash
# 初始化脚本示例（AI 执行此逻辑）
PLAN="2026年5月月度计划"
DOCS_ROOT=".sonli-spec-doc/${PLAN}"

# ★ 首先询问用户远程文档中心仓库地址
# AI 向用户提问并获取 DOC_CENTER_SSH_URL

# 写入配置
# ... 更新 config.yaml ...

# 创建目录结构
mkdir -p "${DOCS_ROOT}/pm/prd"
mkdir -p "${DOCS_ROOT}/dev/plans"
mkdir -p "${DOCS_ROOT}/dev/api"          # ★ 新增
mkdir -p "${DOCS_ROOT}/dev/tasks"
mkdir -p "${DOCS_ROOT}/dev/review-report"
mkdir -p "${DOCS_ROOT}/dev/test-report"
mkdir -p "${DOCS_ROOT}/test/testcases"
mkdir -p "${DOCS_ROOT}/test/test-report"
mkdir -p ".sonli-spec-doc/knowledge-base/compound"

# 占位文件
find .sonli-spec-doc -type d -empty -exec touch {}/.gitkeep \; 2>/dev/null || true

# ❗ 注意：.sonli-spec-doc/ 已被 .gitignore 排除，不会进入代码仓库
#   文档的版本控制通过远程文档中心仓库管理
#   团队同步：每个成员自己执行 /document-init '<同名计划>' 并输入相同文档中心仓库地址
```

- [ ] **Step 6: 更新配置完整性检查表**

原文件第 102-109 行替换为：

```markdown
## 配置完整性检查表

- [ ] Git 仓库检查：`git rev-parse --git-dir` 成功
- [ ] 配置文件创建：`.sonli-spec-doc/config.yaml` 已存在，`storage.mode: git_repo`
- [ ] **★ 远程文档中心仓库**：`doc_center.ssh_url` 已配置
- [ ] **★ 月度计划配置**：`directories.active_plan` 已设置
- [ ] 目录结构创建：`.sonli-spec-doc/<计划>/pm/prd/` 等子目录已建立
- [ ] `dev/api` 子目录已创建（新增）
- [ ] 同步脚本可用：`.sonli-spec-doc/scripts/sync-to-remote.sh` 存在且可执行
```

- [ ] **Step 7: 更新与子技能的契约表**

原文件第 110-120 行替换为：

```markdown
## 与子技能的契约（重要）

**所有 `document-*` 子技能（pm / dev / test / overview / compound）在执行前都会读取本技能创建的配置**，具体契约：

| 检查项 | 来源 | 读取者 |
|--------|------|--------|
| `.sonli-spec-doc/config.yaml` | 本技能创建 | 所有 document-* 子技能 |
| `directories.active_plan` | `/document-init '<名>'` 或 `/document-init plan '<名>'` 写入 | 所有子技能拼接文件路径 |
| `.sonli-spec-doc/<active_plan>/{pm/prd,dev/*,test/*}/` | 本技能初始化时创建 | 各子技能写入对应子目录 |
| `.sonli-spec-doc/knowledge-base/compound/` | 本技能初始化时创建 | `document-compound` 归档用 |
| `doc_center.ssh_url` | 本技能初始化时用户输入 | 同步脚本 `sync-to-remote.sh` |
| `.sonli-spec-doc/scripts/sync-to-remote.sh` | 本技能部署 | 所有子技能上传时调用 |

**如果未执行本技能**，任何 `/document-pm`、`/document-dev`、`/document-test`、`/document-overview`、`/document-compound` 都会立即报错并引导用户回到本技能完成初始化。
```

- [ ] **Step 8: 更新目录结构规范图**

原文件第 123-143 行替换为：

````markdown
## 目录结构规范

初始化后在 `.sonli-spec-doc/` 内创建的目录结构：
```
.sonli-spec-doc/
├── config.yaml
├── templates/
├── scripts/
│   └── sync-to-remote.sh              # ★ 远程同步脚本
├── 2026年4月月度计划/                   # ★ 活跃月度计划
│   ├── pm/
│   │   └── prd/                        # PRD 文档
│   ├── dev/
│   │   ├── plans/                      # 需求拆解
│   │   ├── api/                        # ★ API 接口文档
│   │   ├── tasks/                      # 任务分配
│   │   ├── test-report/                # 测试验收报告
│   │   └── review-report/              # 代码审查报告
│   ├── test/
│   │   ├── testcases/                  # 测试用例
│   │   └── test-report/                # 测试报告
│   └── overview.md                     # 项目进度报告
├── 2026年5月月度计划/                   ← 可切换
└── knowledge-base/
    └── compound/                        # 开发经验总结
```
````

- [ ] **Step 9: 更新理性化漏洞防护表（新增一条）**

原文件第 145-151 行，在防护表中新增一行：

```markdown
| 漏洞 | 防护措施 |
|------|----------|
| "不用初始化，手动建文件夹就行" | **必须初始化**：只有初始化才能保证目录结构标准化 |
| "切换计划太麻烦，先混着放" | **一键切换**：文档路径自动变更，不能混放 |
| "不用配置远程仓库，本地就行" | **必须配置**：文档需要同步到远程文档中心仓库供团队共享 |
```

- [ ] **Step 10: 更新版本号和状态**

原文件第 154-157 行替换为：

```markdown
---
**子智能体标识**：document-init-agent
**版本**：4.0.0
**存储模式**：git_repo + doc_center_remote
**状态**：就绪
```
````

---

### Task 4: 更新 document-pm/SKILL.md

**Files:**
- Modify: `skills/document-pm/SKILL.md`

- [ ] **Step 1: 更新前置检查脚本中的路径**

将所有 `docs/monthly/` 替换为 `.sonli-spec-doc/`。原文件第 26、40 行：

```bash
# 第 26 行: 目录检查路径
- [ ] `.sonli-spec-doc/<active_plan>/pm/prd/` 目录存在

# 第 40 行: 检查命令
[ -d ".sonli-spec-doc/$ACTIVE_PLAN/pm/prd" ] || { echo "❌ PRD 目录缺失：.sonli-spec-doc/$ACTIVE_PLAN/pm/prd，请重新执行 /document-init '$ACTIVE_PLAN'"; exit 1; }
```

- [ ] **Step 2: 更新 PRD 提交管理部分**

原文件第 72-82 行的"PRD 提交管理"替换为两阶段上传逻辑：

```markdown
### 2. PRD 提交管理（两阶段同步）
- **格式**: `/document-pm 上传 <项目文档路径>`
- **功能**: 将用户指定的 PRD 文档同步到文档中心仓库
- **两阶段同步流程**:
  1. **本地拷贝**：将 `<项目文档路径>` 下的 .md 文件拷贝到 `.sonli-spec-doc/<活跃计划>/pm/prd/`
  2. **远程同步**：执行 `.sonli-spec-doc/scripts/sync-to-remote.sh '<活跃计划>'`
- **命令示例**:
  ```bash
  # AI 执行此逻辑
  ACTIVE_PLAN=$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)
  cp <用户指定的源路径>/*.md ".sonli-spec-doc/${ACTIVE_PLAN}/pm/prd/"
  ./.sonli-spec-doc/scripts/sync-to-remote.sh "$ACTIVE_PLAN"
  ```
```

- [ ] **Step 3: 更新 GitLab 连接失败处理**

原文件第 106-108 行（智能降级策略表）：

```markdown
| GitLab连接失败 | 无需网络：文档直接写入本地 `.sonli-spec-doc/` 目录，网络恢复后执行 `sync-to-remote.sh` | - |
```

- [ ] **Step 4: 更新脚本库集成使用部分**

原文件第 136-149 行：

```bash
# 推荐使用方式
DOCS_PATH=".sonli-spec-doc/$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)/pm/prd"
mkdir -p "$DOCS_PATH"
# AI 将 PRD 内容写入 $DOCS_PATH/<功能名>.md

# 同步到远程文档中心仓库
./.sonli-spec-doc/scripts/sync-to-remote.sh "$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)"
```

- [ ] **Step 5: 更新理性化防护表**

替换其中一条：

```markdown
| "把 PRD 放到任意目录" | 禁止：所有 PRD 必须归属某月度计划 `.sonli-spec-doc/<plan>/pm/prd/` |
```

---

### Task 5: 更新 document-dev/SKILL.md

**Files:**
- Modify: `skills/document-dev/SKILL.md`

- [ ] **Step 1: 更新前置检查脚本中的路径和新增 dev/api 检查**

原文件第 25-44 行：

```bash
### 必检项

- [ ] 当前处于 Git 仓库（`git rev-parse --show-toplevel` 可成功）
- [ ] `.sonli-spec-doc/config.yaml` 存在
- [ ] `storage.mode == git_repo`
- [ ] `directories.active_plan` 已设置（非空）
- [ ] `.sonli-spec-doc/<active_plan>/dev/{plans,api,tasks,review-report,test-report}/` 目录存在

### 检查脚本（AI 执行此逻辑）

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "❌ 当前不在 Git 仓库"; exit 1; }
cd "$REPO_ROOT"

CONFIG=".sonli-spec-doc/config.yaml"
[ -f "$CONFIG" ] || { echo "❌ 未检测到 $CONFIG，请先执行 /document-init '<月度计划名>'"; exit 1; }

ACTIVE_PLAN=$(grep -E '^[[:space:]]*active_plan:' "$CONFIG" | head -1 | cut -d: -f2- | cut -d'#' -f1 | tr -d '"' | tr -d "'" | xargs)
[ -n "$ACTIVE_PLAN" ] || { echo "❌ active_plan 未设置，请执行 /document-init plan '<月度计划名>'"; exit 1; }

for sub in plans api tasks review-report test-report; do
  [ -d ".sonli-spec-doc/$ACTIVE_PLAN/dev/$sub" ] || { echo "❌ 设计目录缺失：.sonli-spec-doc/$ACTIVE_PLAN/dev/$sub，请重新执行 /document-init '$ACTIVE_PLAN'"; exit 1; }
done

echo "✅ Dev 初始化配置检查通过（活跃计划：$ACTIVE_PLAN）"
```
```

- [ ] **Step 2: 更新设计文档提交部分为两阶段同步**

原文件第 82-91 行替换为：

```markdown
### 3. 设计文档提交（两阶段同步）
- **格式**: `/document-dev 上传 <项目文档路径> --target <目标子目录>`
- **功能**: 将用户指定的设计文档同步到文档中心仓库
- **目标子目录**: `plans` | `api` | `tasks` | `review-report` | `test-report`
- **两阶段同步流程**:
  1. **本地拷贝**：将 `<项目文档路径>` 下的 .md 文件拷贝到 `.sonli-spec-doc/<活跃计划>/dev/<目标子目录>/`
  2. **远程同步**：执行 `.sonli-spec-doc/scripts/sync-to-remote.sh '<活跃计划>'`
- **命令示例**:
  ```bash
  # 上传设计文档到 dev/plans/
  ACTIVE_PLAN=$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)
  cp <用户指定的源路径>/*.md ".sonli-spec-doc/${ACTIVE_PLAN}/dev/plans/"
  ./.sonli-spec-doc/scripts/sync-to-remote.sh "$ACTIVE_PLAN"
  
  # 上传 API 文档到 dev/api/
  cp <用户指定的源路径>/*.md ".sonli-spec-doc/${ACTIVE_PLAN}/dev/api/"
  ./.sonli-spec-doc/scripts/sync-to-remote.sh "$ACTIVE_PLAN"
  ```
```

- [ ] **Step 3: 更新 Git 提交使用方式部分**

原文件第 248-258 行替换为：

```bash
# 生成设计文档（AI 写入对应目录）
DEV_PATH=".sonli-spec-doc/$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)/dev"

# 同步设计文档到远程文档中心仓库
./.sonli-spec-doc/scripts/sync-to-remote.sh "$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)"
```

- [ ] **Step 4: 更新理性化防护表**

```markdown
| "设计放在 PRD 同目录下" | 禁止：设计必须进 `dev/plans`，API 文档进 `dev/api`，便于评审和追溯 |
```

---

### Task 6: 更新 document-test/SKILL.md

**Files:**
- Modify: `skills/document-test/SKILL.md`

- [ ] **Step 1: 更新所有 `docs/monthly/` → `.sonli-spec-doc/`**

关键修改点：

第 26、40-42 行 - 前置检查：
```bash
- [ ] `.sonli-spec-doc/<active_plan>/test/{testcases,test-report}/` 目录存在

for sub in testcases test-report; do
  [ -d ".sonli-spec-doc/$ACTIVE_PLAN/test/$sub" ] || { echo "❌ 测试目录缺失：.sonli-spec-doc/$ACTIVE_PLAN/test/$sub，请重新执行 /document-init '$ACTIVE_PLAN'"; exit 1; }
done
```

第 117-127 行 - 文档提交管理：
```markdown
### 4. 文档提交管理（两阶段同步）
- **格式**: `/document-test 上传 <项目文档路径> --target <testcases|test-report>`
- **功能**: 将用户指定的测试文档同步到文档中心仓库
- **两阶段同步流程**:
  1. **本地拷贝**：将 `<项目文档路径>` 下的 .md 文件拷贝到 `.sonli-spec-doc/<活跃计划>/test/<目标子目录>/`
  2. **远程同步**：执行 `.sonli-spec-doc/scripts/sync-to-remote.sh '<活跃计划>'`
```

第 243-256 行 - Git 提交集成：
```bash
# 生成测试用例后
TEST_PATH=".sonli-spec-doc/$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)/test"

# 同步到远程文档中心仓库
./.sonli-spec-doc/scripts/sync-to-remote.sh "$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)"
```

第 305 行 - 调试命令：
```bash
ls -la .sonli-spec-doc/$(cat .sonli-spec-doc/config.yaml | grep active_plan | awk '{print $2}')/test/
```

---

### Task 7: 更新 document-overview/SKILL.md

**Files:**
- Modify: `skills/document-overview/SKILL.md`

- [ ] **Step 1: 更新所有 `docs/monthly/` → `.sonli-spec-doc/`**

关键修改点：

第 26、40 行 - 前置检查：
```bash
- [ ] `.sonli-spec-doc/<active_plan>/` 目录存在（用于写入 `overview.md`）

[ -d ".sonli-spec-doc/$ACTIVE_PLAN" ] || { echo "❌ .sonli-spec-doc/$ACTIVE_PLAN/ 目录缺失，请重新执行 /document-init '$ACTIVE_PLAN'"; exit 1; }
```

第 222-234 行 - Git 提交集成：
```bash
# 生成项目概览后同步到远程文档中心仓库
OVERVIEW_PATH=".sonli-spec-doc/$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)"

# 同步到远程文档中心仓库
./.sonli-spec-doc/scripts/sync-to-remote.sh "$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)"
```

---

### Task 8: 更新 document-compound/SKILL.md

**Files:**
- Modify: `skills/document-compound/SKILL.md`

- [ ] **Step 1: 更新所有 `docs/` → `.sonli-spec-doc/`**

关键修改点：

第 26-27、41-42 行 - 前置检查：
```bash
- [ ] `.sonli-spec-doc/knowledge-base/compound/` 目录存在
- [ ] `.sonli-spec-doc/<active_plan>/` 目录存在（用于读取开发周期文档）

[ -d ".sonli-spec-doc/knowledge-base/compound" ] || { echo "❌ 知识库目录缺失：.sonli-spec-doc/knowledge-base/compound，请重新执行 /document-init '$ACTIVE_PLAN'"; exit 1; }
[ -d ".sonli-spec-doc/$ACTIVE_PLAN" ] || { echo "❌ .sonli-spec-doc/$ACTIVE_PLAN/ 目录缺失，请重新执行 /document-init '$ACTIVE_PLAN'"; exit 1; }
```

第 60-64 行 - 理性化防护：
```markdown
| "经验总结丢到任意位置" | 禁止：必须进 `.sonli-spec-doc/knowledge-base/compound/`，便于团队复用 |
| "跨计划遥控总结，跳过当前 active_plan" | 禁止：经验总结输入必须来自 `.sonli-spec-doc/<active_plan>/` |
```

第 82-118 行 - Git 提交集成：
```bash
# 生成经验总结后同步到远程文档中心仓库
KB_PATH=".sonli-spec-doc/knowledge-base/compound"
./.sonli-spec-doc/scripts/sync-to-remote.sh "$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)"
```

---

### Task 9: 更新 document/SKILL.md 路由层

**Files:**
- Modify: `skills/document/SKILL.md`

- [ ] **Step 1: 更新目录结构规范部分**

原文件第 497-516 行的目录结构图替换为：

```markdown
## 目录结构规范

```
.sonli-spec-doc/                        # 本地文档工作区（不入代码仓库）
├── config.yaml                         # 配置（含远程文档中心仓库地址）
├── templates/
├── scripts/
│   └── sync-to-remote.sh               # ★ 同步到远程文档中心仓库
├── <月度计划名称>/                       # 示例：2026年5月月度计划
│   ├── pm/
│   │   └── prd/                        # 产品需求文档
│   ├── dev/
│   │   ├── plans/                      # 需求拆解
│   │   ├── api/                        # ★ API 接口文档
│   │   ├── tasks/                      # 任务分配
│   │   ├── test-report/                # 测试验收报告
│   │   └── review-report/              # 代码审查报告
│   ├── test/
│   │   ├── testcases/                  # 测试用例
│   │   └── test-report/                # 测试报告
│   └── overview.md                     # 项目进度报告
└── knowledge-base/
    └── compound/                        # 开发经验总结
```
```

- [ ] **Step 2: 更新上传说明**

在"核心功能"各节中更新上传路径描述（保持与各子技能一致）。

---

### Task 10: 最终验证

- [ ] **Step 1: 验证所有技能文件中不再出现 `docs/monthly/`**

运行：`grep -r 'docs/monthly' skills/document*/SKILL.md skills/document/SKILL.md`
预期：无输出（或仅在注释/历史说明中出现）

- [ ] **Step 2: 验证 sync-to-remote.sh 可执行**

运行：`test -x .sonli-spec-doc/scripts/sync-to-remote.sh && echo "OK" || echo "FAIL"`
预期：OK

- [ ] **Step 3: 验证 config.yaml 新字段**

运行：`grep -E 'docs_root|doc_center|api' .sonli-spec-doc/config.yaml`
预期：看到 `.sonli-spec-doc`、`doc_center:`、`api` 等

- [ ] **Step 4: 手动端到端测试（在真实会话中）**

1. 执行 `/document-init '2026年6月月度计划'` — 确认能创建正确的 `.sonli-spec-doc/` 目录结构
2. 模拟上传流程 — 确认 sync-to-remote.sh 能正确处理

---

## 上传流程总结（两阶段同步）

```
用户执行上传命令（如 /document-dev 上传 docs/my-api-doc/ --target api）
         │
         ▼
┌─────────────────────────────────────────────────────┐
│ 阶段一：本地拷贝                                      │
│ cp docs/my-api-doc/*.md                              │
│   → .sonli-spec-doc/2026年5月月度计划/dev/api/       │
└─────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│ 阶段二：远程同步                                      │
│ .sonli-spec-doc/scripts/sync-to-remote.sh             │
│   '2026年5月月度计划'                                 │
│                                                      │
│ 1. git clone doc_center.ssh_url → 临时目录            │
│ 2. rsync .sonli-spec-doc/<计划>/ → 临时目录/<计划>/   │
│ 3. git commit + git push → 远程文档中心仓库            │
│ 4. 清理临时目录                                       │
└─────────────────────────────────────────────────────┘
```
