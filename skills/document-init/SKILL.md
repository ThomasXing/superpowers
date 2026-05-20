---
name: document-init
description: Use when setting up the doc directory structure in the repository for the first time, or when switching to a new monthly plan period
---

# Document-Init - 仓库文档目录初始化与管理

> 文档本地工作区 `.sonli-spec-doc/` → 同步脚本 → 独立 Spec Doc GitLab 远程仓库。主项目仓库与文档仓库分离，配置文件不入版本库，团队成员各自执行初始化。

**存储架构**：
- **本地工作区**：`.sonli-spec-doc/<活跃计划名称>/`，被 `.gitignore` 排除不入主项目仓库
- **远程文档仓库**：独立的 GitLab Spec Doc 仓库（如 `git@172.16.100.5:root/spec-doc.git`），通过 sync 脚本推送/拉取
- **团队同步**：每个成员独立执行 `/document-init '<同一计划名>'`，文档通过 Spec Doc 远程仓库共享

## 核心功能

### 1. 仓库文档目录初始化
- **格式**：`/document-init '<月度计划名称>' [Spec Doc 仓库地址]`
- **功能**：在当前仓库的 `.sonli-spec-doc/<活跃计划名称>/` 下创建标准化目录结构，配置 Spec Doc 远程 GitLab 仓库连接和鉴权 Token
- **配置存储**：创建 / 更新 `.sonli-spec-doc/config.yaml`（含 gitlab 远程仓库信息 + token + active_plan）
- **兼容性**：同时支持 `/document init '<月度计划名称>'` 格式

### 2. 月度计划管理
- **格式**：`/document-init plan '<计划名称>'`
- **功能**：配置或切换当前活跃的月度计划
- **原理**：所有 document 子技能的文件路径自动拼接 `.sonli-spec-doc/<活跃月度计划>` 前缀
- **多计划共存**：支持注册多个月度计划，通过切换活跃计划在不同计划间无缝切换

```
.sonli-spec-doc/ 目录路径层级:
  .sonli-spec-doc/               ← 文档工作区根目录（.gitignore 排除，不入主项目仓库）
  ├── config.yaml                ← 全局配置（gitlab 远程仓库 + token + active_plan）
  ├── 2026年4月月度计划/          ← 活跃计划（directories.active_plan）
  │   ├── pm/prd/                ← PRD 文档自动存入此目录
  │   ├── dev/plans/             ← 设计文档自动存入此目录
  │   ├── dev/tasks/
  │   ├── dev/review-report/
  │   ├── test/testcases/        ← 测试用例自动存入此目录
  │   ├── test/test-report/
  │   └── overview.md            ← 项目进度概览
  ├── 2026年5月月度计划/          ← 可切换至此
  ├── scripts/                   ← sync-to-remote.sh / sync-from-remote.sh
  └── knowledge-base/
      └── compound/              ← 迭代经验沉淀
```

#### 计划管理命令
```bash
# 初始化时指定月度计划和 Spec Doc 仓库地址
/document-init '2026年5月月度计划' git@172.16.100.5:root/spec-doc.git

# 仅初始化（Spec Doc 仓库已在 config.yaml 中配置）
/document-init '2026年5月月度计划'

# 后续配置 / 切换计划
/document-init plan '2026年6月月度计划'

# 列出所有已注册计划
/document-init plan list

# 查看当前活跃计划
/document-init plan current

# 更新技能（skill 源 → 运行时 + 脚本部署，一键同步）
/document-init update

# 强制覆盖（即使版本号相同）
/document-init update --force
```

## 初始化执行步骤

1. **主项目环境检查**：
   - 确认当前目录是主项目 Git 仓库（`git rev-parse --git-dir`）
   - 检查 `.gitignore` 中已包含 `.sonli-spec-doc/` 排除规则

2. **Spec Doc 远程仓库配置**：
   - 提示用户输入 Spec Doc GitLab 仓库 SSH 地址（如 `git@172.16.100.5:root/spec-doc.git`）
   - 提取 hostname，验证 SSH 可达性（`ssh -T -o StrictHostKeyChecking=no -o ConnectTimeout=5 git@<hostname>`）

3. **GitLab Token 配置与验证**：
   - 提示用户输入 GitLab Personal Access Token（需 `api` + `read_repository` + `write_repository` 权限）
   - 验证 Token 有效性：`curl -s --header "PRIVATE-TOKEN: <token>" "http://<hostname>/api/v4/user"`
   - Token 仅写入本地 `.sonli-spec-doc/config.yaml`（.gitignore 排除），绝不提交到主项目仓库

4. **配置写入（本地，不入主项目仓库）**：创建 / 更新 `.sonli-spec-doc/config.yaml`，写入 `gitlab` 远程仓库信息 + token + `directories.active_plan`

5. **目录创建**：创建 `.sonli-spec-doc/<活跃计划>/` 下的完整目录结构

6. **同步脚本部署**：从技能模板目录 `skills/document-init/templates/` 复制脚本到 `.sonli-spec-doc/scripts/`：
   - `sync-to-remote.sh`：推送本地文档至 Spec Doc 远程仓库（HTTP+Token 鉴权） — 模板：[templates/sync-to-remote.sh](file:///Users/thomasxing/workspace/2026/3月份计划/AI研发/spec-kit/skills/document-init/templates/sync-to-remote.sh)
   - `sync-from-remote.sh`：从 Spec Doc 远程仓库拉取最新文档到本地（GitLab API v4） — 模板：[templates/sync-from-remote.sh](file:///Users/thomasxing/workspace/2026/3月份计划/AI研发/spec-kit/skills/document-init/templates/sync-from-remote.sh)

7. **幂等检查**：若目录已存在则跳过目录创建，仅更新 config.yaml 中的 active_plan

8. **脚本版本自检与技能更新机制**：
   - 每个同步脚本头部内嵌 `SCRIPT_VERSION` 标记，启动时自动比对模板版本
   - 若模板版本号 > 本地脚本版本号 → 提示用户确认是否更新
   - 用户确认后自动 `cp` 模板覆盖本地脚本并 `exec` 重执行
   - `/document-init update` 一键完成全链路同步：
     1. 若 `skills/document-init/` 存在（git 源）→ 复制 SKILL.md + templates/ 到 `.qoder/skills/document-init/`（运行时）
     2. 复制 templates/*.sh → `.sonli-spec-doc/scripts/`（本地工作区）
     3. `--force` 强制覆盖，即使源与目标版本号相同

### ❗ 配置文件安全原则（重要）

**`.sonli-spec-doc/` 必须被 `.gitignore` 排除，绝不入主项目版本库**，原因：

- 包含 **内网 IP / GitLab hostname**（`gitlab.hostname`、`gitlab.ssh_url`）
- 包含 **GitLab Personal Access Token**（`gitlab.token`）— 用于 sync-to-remote.sh / sync-from-remote.sh 鉴权
- 包含 **个人账号名 / commit_author**
- 包含 **SSH key 路径**
- 初始化时间戳、本机路径等是机器相关状态

**团队同步方式**：每个团队成员在自己的工作区独立执行 `/document-init '<同一计划名>' <同一 Spec Doc 仓库地址>`，各自配置自己的 GitLab Token，而不是共享 config.yaml。

### GitLab Token 权限要求

sync-to-remote.sh 和 sync-from-remote.sh 共用 config.yaml 中的 Token，需具备以下 GitLab 权限：

| 权限 | 用途 |
|------|------|
| `api` | 调用 GitLab API（sync-from-remote.sh 拉取文件列表 + Token 有效性验证） |
| `read_repository` | 读取 Spec Doc 远程仓库（sync-from-remote.sh 下载文档） |
| `write_repository` | 推送文档到 Spec Doc 远程仓库（sync-to-remote.sh） |

```bash
# 初始化脚本示例（AI 执行此逻辑）
PLAN="2026年5月月度计划"
SPEC_DOC_REPO="git@172.16.100.5:root/spec-doc.git"  # 用户输入
BASE=".sonli-spec-doc/${PLAN}"

# ── 1. 主项目环境检查 ──
git rev-parse --git-dir || { echo "❌ 当前不是 Git 仓库"; exit 1; }
grep -q '.sonli-spec-doc/' .gitignore || echo '.sonli-spec-doc/' >> .gitignore

# ── 2. Spec Doc 远程仓库 SSH 验证 ──
HOST=$(echo "$SPEC_DOC_REPO" | sed -n 's/.*@\(.*\):.*/\1/p')
echo "验证 Spec Doc 仓库 SSH 连接: $HOST ..."
SSH_OK=false
ssh -T -o StrictHostKeyChecking=no -o ConnectTimeout=5 "git@${HOST}" 2>&1 | grep -qE 'Welcome|successfully' && SSH_OK=true
if [ "$SSH_OK" = true ]; then
  echo "✅ Spec Doc 仓库 SSH 连接成功"
else
  echo "⚠️  SSH 验证未通过，将使用 HTTP+Token 模式同步"
fi

# ── 3. GitLab Token 配置与验证 ──
echo "请输入 GitLab Personal Access Token（需要 api + read_repository + write_repository 权限）："
read -s GITLAB_TOKEN
echo ""  # 换行

# 验证 Token 有效性
HTTP_URL="http://${HOST}"
TOKEN_CHECK=$(curl -s -o /dev/null -w "%{http_code}" --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" "${HTTP_URL}/api/v4/user")
if [ "$TOKEN_CHECK" = "200" ]; then
  echo "✅ GitLab Token 验证通过"
else
  echo "❌ GitLab Token 验证失败 (HTTP ${TOKEN_CHECK})"
  echo "   请确认: 1) Token 未过期 2) 权限包含 api, read_repository, write_repository"
  exit 1
fi

# ── 4. 配置写入 ──
mkdir -p .sonli-spec-doc
cat > .sonli-spec-doc/config.yaml << YAMLEOF
version: "3.1.0"
initialized: "$(date -Iseconds)"
status: "active"
storage:
  mode: "git_repo"
  docs_root: ".sonli-spec-doc"
  knowledge_base: ".sonli-spec-doc/knowledge-base"
  auto_push: false
gitlab:
  ssh_url: "${SPEC_DOC_REPO}"
  http_url: "http://${HOST}/root/spec-doc"
  hostname: "${HOST}"
  token: "${GITLAB_TOKEN}"
directories:
  active_plan: "${PLAN}"
  plans:
    - "${PLAN}"
  pm_subpath: "pm/prd"
  dev_subpath: "dev"
  test_subpath: "test"
templates_enabled: true
YAMLEOF

# ── 5. 目录创建 ──
mkdir -p "${BASE}/pm/prd"
mkdir -p "${BASE}/dev/plans"
mkdir -p "${BASE}/dev/tasks"
mkdir -p "${BASE}/dev/review-report"
mkdir -p "${BASE}/dev/test-report"
mkdir -p "${BASE}/test/testcases"
mkdir -p "${BASE}/test/test-report"
mkdir -p ".sonli-spec-doc/knowledge-base/compound"
mkdir -p ".sonli-spec-doc/scripts"

# ── 6. 同步脚本部署 ──
# 从技能模板目录复制到 .sonli-spec-doc/scripts/
cp "$SKILL_DIR/templates/sync-to-remote.sh" .sonli-spec-doc/scripts/
cp "$SKILL_DIR/templates/sync-from-remote.sh" .sonli-spec-doc/scripts/
chmod +x .sonli-spec-doc/scripts/*.sh

echo "✅ document-init 完成 — 活跃计划: ${PLAN} | Spec Doc: ${HOST} | Token: 已验证"
```

## Spec Doc 远程仓库配置说明

### config.yaml 中的 gitlab 配置段

```yaml
gitlab:
  ssh_url: "git@172.16.100.5:root/spec-doc.git"  # SSH 地址
  http_url: "http://172.16.100.5/root/spec-doc"   # HTTP 地址（sync 脚本用）
  hostname: "172.16.100.5"                         # GitLab 主机
  token: "glpat-xxxxxxxxxxxx"                       # ★ GitLab Personal Access Token（HTTP 鉴权必需）
```

### 双重验证（初始化时强制执行）

| 验证项 | 命令 | 通过标准 |
|--------|------|----------|
| **SSH 可达性**（Spec Doc 仓库） | `ssh -T -o StrictHostKeyChecking=no -o ConnectTimeout=5 git@<hostname>` | 返回 `Welcome to GitLab` |
| **Token 有效性**（GitLab API） | `curl -s --header "PRIVATE-TOKEN: <token>" "http://<hostname>/api/v4/user"` | HTTP 200，返回用户信息 |
| HTTP 可达性 | `curl -s --head --connect-timeout 5 "http://<hostname>"` | HTTP 响应正常 |

### sync-to-remote.sh 鉴权流程

```
1. 读取 config.yaml 中的 gitlab.token
2. 若 token 非空 → 构造 oauth2 URL: http://oauth2:<token>@host/repo.git
3. git push 使用 oauth2 URL
4. 若 token 为空 → 回退 SSH 模式（git push 使用 ssh_url）
```

### sync-from-remote.sh 拉取流程

```
1. 读取 config.yaml → active_plan + token + hostname
2. 调用 /api/v4/projects/<id>/repository/tree 列出远程文档文件
3. 遍历文件列表（跳过 .gitkeep）
4. 逐个调用 /api/v4/projects/<id>/repository/files/<path>/raw 下载
5. 写入本地 .sonli-spec-doc/<active_plan>/ 对应目录
6. 已存在的文件跳过（幂等），仅拉取新文件
7.  标记：强制覆盖已有文件，用于远端文档更新后的同步
```

## 配置完整性检查表

- [ ] 主项目 Git 仓库检查：`git rev-parse --git-dir` 成功
- [ ] `.gitignore` 排除规则：`.sonli-spec-doc/` 已列入
- [ ] **★ Spec Doc 远程仓库 SSH 验证**：`ssh -T git@<hostname>` 成功或已知降级
- [ ] **★ GitLab Token 验证**：`curl --header "PRIVATE-TOKEN: <token>" "http://<hostname>/api/v4/user"` 返回 200
- [ ] 配置文件创建：`.sonli-spec-doc/config.yaml` 已存在，含 `gitlab.token` 非空
- [ ] **★ 月度计划配置**：`directories.active_plan` 已设置
- [ ] 目录结构创建：`.sonli-spec-doc/<计划>/pm/prd/` 等子目录已建立
- [ ] 同步脚本就绪：`.sonli-spec-doc/scripts/sync-to-remote.sh` 和 `sync-from-remote.sh` 可用
- [ ] 脚本版本自检：`grep SCRIPT_VERSION .sonli-spec-doc/scripts/*.sh` 确认版本标记存在

## 与子技能的契约（重要）

**所有 `document-*` 子技能（pm / dev / test / overview / compound）在执行前都会读取本技能创建的配置**，具体契约：

| 检查项 | 来源 | 读取者 |
|--------|------|--------|
| `.sonli-spec-doc/config.yaml` | 本技能创建 | 所有 document-* 子技能 |
| `gitlab.ssh_url` / `gitlab.hostname` | 初始化时用户输入 | sync-to-remote.sh / sync-from-remote.sh |
| `gitlab.token` | ★ 初始化时用户输入并验证 | sync-to-remote.sh（HTTP oauth2 鉴权）/ sync-from-remote.sh（GitLab API 鉴权） |
| `directories.active_plan` | `/document-init '<名>'` 或 `/document-init plan '<名>'` 写入 | 所有子技能拼接文件路径 |
| `.sonli-spec-doc/<active_plan>/{pm/prd,dev/*,test/*}/` | 本技能初始化时创建 | 各子技能写入对应子目录 |
| `.sonli-spec-doc/knowledge-base/compound/` | 本技能初始化时创建 | `document-compound` 归档用 |

**各子技能 pre-check 承诺**：发现本地文档为空时，自动提示执行 `sync-from-remote.sh` 从 Spec Doc 拉取最新文档。确保上游 PRD / 设计文档在本地可用。

**如果未执行本技能**，任何 `/document-pm`、`/document-dev`、`/document-test`、`/document-overview`、`/document-compound` 都会立即报错并引导用户回到本技能完成初始化。

## 目录结构规范

### 技能模板目录（skills/document-init/）

```
skills/document-init/
├── SKILL.md                       # 技能定义文档
└── templates/                     # ★ 脚本模板（初始化时复制到目标位置）
    ├── sync-to-remote.sh          # Spec Doc 远程推送脚本模板
    └── sync-from-remote.sh        # Spec Doc 远程拉取脚本模板
```

### 初始化输出（.sonli-spec-doc/，不入主项目版本库）

```
.sonli-spec-doc/
├── config.yaml                    # 全局配置（gitlab 远程仓库 + token + active_plan）
├── scripts/
│   ├── sync-to-remote.sh          # Spec Doc 远程推送脚本（从 templates/ 复制）
│   └── sync-from-remote.sh        # Spec Doc 远程拉取脚本（从 templates/ 复制）
├── 2026年4月月度计划/              # ★ 活跃月度计划
│   ├── pm/
│   │   └── prd/                   # PRD 文档
│   ├── dev/
│   │   ├── plans/                 # 需求拆解
│   │   ├── tasks/                 # 任务分配
│   │   ├── test-report/           # 测试验收报告
│   │   └── review-report/         # 代码审查报告
│   ├── test/
│   │   ├── testcases/             # 测试用例
│   │   └── test-report/           # 测试报告
│   └── overview.md                # 项目进度报告
└── knowledge-base/
    └── compound/                  # 开发经验总结
```

## 常见的理性化漏洞及防护

| 漏洞 | 防护措施 |
|------|----------|
| "不用初始化，手动建文件夹就行" | **必须初始化**：只有初始化才能保证目录结构标准化，config.yaml 被所有子技能依赖 |
| "Spec Doc 仓库后面再配，先写文档" | **必须前置**：Spec Doc 仓库地址是文档共享的基础，未配置则文档无法同步给团队 |
| "没有 Token 也可以，走 SSH 就行" | **必须配置 Token**：sync-to-remote.sh 优先 HTTP+Token 鉴权（非交互环境 SSH host key 会阻塞），sync-from-remote.sh 必须 Token 调用 API；Token 无效时禁止继续 |
| "切换计划太麻烦，先混着放" | **一键切换**：通过 `plan` 子命令切换 active_plan，文档路径自动变更，不能混放 |
| "把文档放到 docs/ 下 git 管理" | **禁止**：`.sonli-spec-doc/` 为主工作区（.gitignore 排除），文档通过 Spec Doc 远程仓库共享 |

---
**子智能体标识**：document-init-agent
**版本**：3.3.0
**存储模式**：git_repo + spec_doc_remote
**鉴权方式**：HTTP + GitLab PAT（SSH 为备用）
**双向同步**：sync-to-remote（推送）+ sync-from-remote（拉取）
**状态**：就绪
