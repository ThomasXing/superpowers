---
name: document-init
description: Use when setting up the doc directory structure in the repository for the first time, or when switching to a new monthly plan period
---

# Document-Init - 仓库文档目录初始化与管理

> 文档存入 `.sonli-spec-doc/` 工作区，通过远程文档中心仓库独立版本管理，与代码仓库分离。

**存储策略**：所有文档以 `.md` 文件形式存入 `.sonli-spec-doc/{月度计划名称}/` 目录，通过 `sync-to-remote.sh` 同步到远程文档中心仓库进行版本管理。`.sonli-spec-doc/` 不入代码仓库（已在 .gitignore 中排除）。

## 核心功能

### 1. 仓库文档目录初始化
- **格式**：`/document-init '<月度计划名称>'`
- **功能**：在当前仓库创建标准化 `.sonli-spec-doc/` 目录结构，并配置远程文档中心仓库
- **配置存储**：创建 / 更新 `.sonli-spec-doc/config.yaml`（含远程文档中心仓库地址）
- **兼容性**：同时支持 `/document init '<月度计划名称>'` 格式

### 2. 月度计划管理
- **格式**：`/document-init plan '<计划名称>'`
- **功能**：配置或切换当前活跃的月度计划
- **原理**：所有 document 子技能的文件路径自动拼接 `.sonli-spec-doc/活跃月度计划` 前缀
- **多计划共存**：支持注册多个月度计划，通过切换活跃计划在不同计划间无缝切换

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

#### 计划管理命令
```bash
# 初始化时直接指定月度计划（推荐）
/document-init '2026年5月月度计划'

# 后续配置 / 切换计划
/document-init plan '2026年6月月度计划'

# 列出所有已注册计划
/document-init plan list

# 查看当前活跃计划
/document-init plan current
```

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

## 配置完整性检查表

- [ ] Git 仓库检查：`git rev-parse --git-dir` 成功
- [ ] 配置文件创建：`.sonli-spec-doc/config.yaml` 已存在，`storage.mode: git_repo`
- [ ] **★ 远程文档中心仓库**：`doc_center.ssh_url` 已配置
- [ ] **★ 月度计划配置**：`directories.active_plan` 已设置
- [ ] 目录结构创建：`.sonli-spec-doc/<计划>/pm/prd/` 等子目录已建立
- [ ] `dev/api` 子目录已创建（新增）
- [ ] 同步脚本可用：`.sonli-spec-doc/scripts/sync-to-remote.sh` 存在且可执行

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

## 常见的理性化漏洞及防护

| 漏洞 | 防护措施 |
|------|----------|
| "不用初始化，手动建文件夹就行" | **必须初始化**：只有初始化才能保证目录结构标准化 |
| "切换计划太麻烦，先混着放" | **一键切换**：文档路径自动变更，不能混放 |
| "不用配置远程仓库，本地就行" | **必须配置**：文档需要同步到远程文档中心仓库供团队共享 |

---
**子智能体标识**：document-init-agent
**版本**：4.0.0
**存储模式**：git_repo + doc_center_remote
**状态**：就绪
