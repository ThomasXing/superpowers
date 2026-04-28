---
name: document-init
description: Use when setting up the doc directory structure in the repository for the first time, or when switching to a new monthly plan period
---

# Document-Init - 仓库文档目录初始化与管理

> 文档存在仓库内，和代码一起提交、一起 Review、一起追溯。

**存储策略**：所有文档以 `.md` 文件形式存入仓库 `docs/` 目录，通过 `git commit + push` 历史管理，不使用 GitLab Wiki。

## 核心功能

### 1. 仓库文档目录初始化
- **格式**：`/document-init '<月度计划名称>'`
- **功能**：在当前仓库创建标准化 `docs/` 目录结构
- **配置存储**：创建 / 更新 `.sonli-spec-doc/config.yaml`
- **兼容性**：同时支持 `/document init '<月度计划名称>'` 格式

### 2. 月度计划管理
- **格式**：`/document-init plan '<计划名称>'`
- **功能**：配置或切换当前活跃的月度计划
- **原理**：所有 document 子技能的文件路径自动拼接 `docs/monthly/活跃月度计划` 前缀
- **多计划共存**：支持注册多个月度计划，通过切换活跃计划在不同计划间无缝切换

```
docs/ 目录路径层级:
  docs/monthly/                  ← 一切月度计划的根目录
  ├── 2026年4月月度计划/          ← 活跃计划（directories.active_plan）
  │   ├── pm/prd/                ← PRD 文档自动存入此目录
  │   ├── dev/plans/             ← 设计文档自动存入此目录
  │   ├── dev/tasks/
  │   ├── dev/review-report/
  │   ├── test/testcases/        ← 测试用例自动存入此目录
  │   ├── test/test-report/
  │   └── overview.md            ← 项目进度概览
  └── 2026年5月月度计划/          ← 可切换至此
  docs/knowledge-base/
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

1. **Git 环境检查**：确认当前目录是 Git 仓库（`git rev-parse --git-dir`）
2. **配置写入**：创建 / 更新 `.sonli-spec-doc/config.yaml`，写入 `storage.mode: git_repo` 和月度计划
3. **目录创建**：创建 `docs/monthly/<活跃计划>/` 下的完整目录结构
4. **`.gitkeep` 文件**：在每个空目录放置 `.gitkeep` 保证 Git 跟踪
5. **初始提交**：`git add docs/ .sonli-spec-doc/ && git commit -m "docs: init monthly plan structure for <计划名>"`

```bash
# 初始化脚本示例（AI 执行此逻辑）
PLAN="2026年5月月度计划"
DOCS_ROOT="docs/monthly/${PLAN}"

mkdir -p "${DOCS_ROOT}/pm/prd"
mkdir -p "${DOCS_ROOT}/dev/plans"
mkdir -p "${DOCS_ROOT}/dev/tasks"
mkdir -p "${DOCS_ROOT}/dev/review-report"
mkdir -p "${DOCS_ROOT}/dev/test-report"
mkdir -p "${DOCS_ROOT}/test/testcases"
mkdir -p "${DOCS_ROOT}/test/test-report"
mkdir -p "docs/knowledge-base/compound"

# 占位文件
find docs -type d -empty -exec touch {}/.gitkeep \;

git add docs/ .sonli-spec-doc/
git commit -m "docs: init monthly plan structure for ${PLAN}"
git push
```

## 配置完整性检查表

- [ ] Git 仓库检查：`git rev-parse --git-dir` 成功
- [ ] 配置文件创建：`.sonli-spec-doc/config.yaml` 已存在，`storage.mode: git_repo`
- [ ] **★ 月度计划配置**：`directories.active_plan` 已设置
- [ ] 目录结构创建：`docs/monthly/<计划>/pm/prd/` 等子目录已建立
- [ ] 初始提交完成：`git log --oneline -1` 显示 init 记录

## 目录结构规范

初始化后在仓库内创建的目录结构：
```
docs/
├── monthly/
│   └── 2026年4月月度计划/         # ★ 活跃月度计划
│       ├── pm/
│       │   └── prd/               # PRD 文档
│       ├── dev/
│       │   ├── plans/             # 需求拆解
│       │   ├── tasks/             # 任务分配
│       │   ├── test-report/       # 测试验收报告
│       │   └── review-report/     # 代码审查报告
│       ├── test/
│       │   ├── testcases/         # 测试用例
│       │   └── test-report/       # 测试报告
│       └── overview.md            # 项目进度报告
└── knowledge-base/
    └── compound/                  # 开发经验总结
```

## 常见的理性化漏洞及防护

| 漏洞 | 防护措施 |
|------|----------|
| "不用初始化，手动建文件夹就行" | **必须初始化**：只有初始化才能保证目录结构标准化且有初始 commit |
| "切换计划太麻烦，先混着放" | **一键切换**：文档路径自动变更，不能混放 |
| "不用 push，本地就行" | **必须 push**：团队成员需要拉取最新文档结构 |

---
**子智能体标识**：document-init-agent
**版本**：3.0.0
**存储模式**：git_repo
**状态**：就绪
