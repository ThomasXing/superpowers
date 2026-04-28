# oh-my-qoder

> 基于 superpowers、gstack、
compound 定制开发，打造团队围绕 Spec Doc 的产研协同工作流。

---

## 目录

1. [安装](#安装)
2. [整体协作流程](#整体协作流程)
3. [第一步：项目初始化](#第一步项目初始化)
4. [角色分工与技能对应](#角色分工与技能对应)
5. [完整使用步骤](#完整使用步骤)
6. [协作逻辑缺口与优化建议](#协作逻辑缺口与优化建议)
7. [命令速查卡](#命令速查卡)

---

## 安装

在 Qoder 中执行以下命令，安装全部 spec-kit 技能：

```bash
npx skills add https://github.com/ThomasXing/superpowers --skill using-spec -a qoder
```

安装后，Qoder 会自动扫描 `.qoder/skills/` 目录，所有技能在对话中通过 `/` 前缀触发。

---

## 整体协作流程

```
需求孵化            规格文档阶段                  研发执行阶段              收尾阶段
──────────    ────────────────────────    ──────────────────────    ─────────────
/brainstorm → /document-pm 生成          → /writing-plans           → /document-compound
     ↓              ↓                           ↓                        生成 & 上传
  设计文档      PRD 提交到仓库           → /subagent-driven-development
                    ↓                           ↓
              /document-dev 生成          /requesting-code-review
                    ↓                           ↓
              /document-test 生成         /verification-before-completion
                    ↓
              /document-overview 生成（全程持续更新）
```

技能间依赖关系：

```
document-init
    └── document-pm
            └── document-dev
                    └── document-test
                            └── document-overview
                                        └── document-compound
```

---

## 第一步：项目初始化

**由基础设施 Owner 执行，每个项目只做一次。**  
初始化后所有成员共享同一仓库配置，无需重复配置。

```bash
# 初始化仓库 docs/ 目录结构，同时指定当前月度计划
/document-init '2026年5月月度计划'

# 月份结束后切换到新月度计划（所有子技能路径自动更新）
/document-init plan '2026年6月月度计划'

# 查看当前活跃计划
/document-init plan current
```

仓库目录结构：

```
docs/
├── monthly/
│   ├── 2026年5月月度计划/
│   │   ├── pm/prd/              ← PRD 文档（git commit 管理版本）
│   │   ├── dev/plans/           ← 需求拆解
│   │   ├── dev/tasks/           ← 任务分配
│   │   ├── dev/review-report/   ← 代码审查报告
│   │   ├── test/testcases/      ← 测试用例
│   │   ├── test/test-report/    ← 测试报告
│   │   └── overview.md          ← 项目进度概览
│   └── 2026年6月月度计划/    ← 切换后自动使用此目录
└── knowledge-base/
    └── compound/            ← 跨迭代经验沉淠
```

---

## 角色分工与技能对应

| 角色 | 负责技能 | 核心命令 |
|------|----------|----------|
| 产品经理 | document-pm | `/document-pm 生成 "需求描述"` |
| 技术负责人 / 架构师 | brainstorming、document-dev | `/brainstorm`、`/document-dev 生成 "功能描述"` |
| 开发工程师 | writing-plans、subagent-driven-development | `/writing-plans`、`/subagent-driven-development` |
| 测试工程师 | document-test | `/document-test 生成 "测试场景"` |
| 项目经理 | document-overview | `/document-overview 生成` |
| 知识管理负责人 | document-compound | `/document-compound 生成` |

---

## 完整使用步骤

### 阶段 1：需求澄清（PM + 技术负责人）

```bash
# 对话式澄清需求，产出本地设计文档
/brainstorm
```

流程：探索项目上下文 → 逐一提问 → 提出 2-3 个方案 → 确认设计 → 写设计文档

产出：`docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`

> **注意**：`/brainstorm` 完成后，在 Spec Doc 协作模式下，下一步应调用 `/document-pm` 而非直接 `/writing-plans`。

---

### 阶段 2：PRD 生成（PM）

```bash
# 基于需求淥清结果生成正式 PRD
/document-pm 生成 "停车场智能调度功能"

# PRD 质量自检（完整性评分）
/document-pm 评估

# 提交到仓库 docs/ 目录
/document-pm 提交
```

PRD 必须包含：需求背景、目标与范围、功能需求（颗粒度到函数级）、非功能需求、验收标准、交付计划。

---

### 阶段 3：功能设计（技术负责人）

```bash
# 读取 PRD → 生成功能设计文档（含架构、接口、数据结构）
/document-dev 生成 "调度算法模块"

# 设计评审
/document-dev 评审

# 提交到仓库 docs/…/dev/ 目录
/document-dev 提交
```

功能设计必须包含：设计目标对齐、系统架构、接口规范、详细设计、部署方案、性能/安全设计。

---

### 阶段 4：测试用例设计（测试工程师）

```bash
# 基于功能设计生成测试用例（强制 TDD：测试先行）
/document-test 生成 "调度算法功能验证"

# 编制测试计划
/document-test 计划 "智能调度项目"

# 提交到仓库 docs/…/test/ 目录
/document-test 提交
```

---

### 阶段 5：实现计划 & 开发（开发工程师）

```bash
# 基于功能设计文档编写 bite-sized 实现计划
/writing-plans
# 产出：docs/superpowers/plans/YYYY-MM-DD-<feature>.md

# 用子代理驱动开发执行计划
# 每个 Task：实现子代理 → Spec 合规审查 → 代码质量审查 → 标记完成
/subagent-driven-development
```

---

### 阶段 6：代码审查（开发工程师）

```bash
# 完成每个 Task 后触发代码审查子代理
/requesting-code-review

# 收到审查意见后理性评估（禁止盲目同意，需技术验证）
/receiving-code-review
```

---

### 阶段 7：进度透明化（项目经理，全程持续）

```bash
# 每日生成/更新进度报告
/document-overview 生成
/document-overview 更新

# 生成钉钉播报（日报 / 晨会简报）
/document-overview 播报 简洁
/document-overview 播报 详细

# 项目健康度评估（多维度：进度/质量/风险/团队）
/document-overview 健康度
```

---

### 阶段 8：迭代经验沉淀（每个迭代结束后）

```bash
# 自动收集所有文档，智能分析经验教训与可复用模式
/document-compound 生成

# 生成详细总结报告
/document-compound 总结 详细

# 提交到知识库（docs/knowledge-base/compound/ 目录）
/document-compound 提交
```



## 命令速查卡

```
────────────────────────────────────────────────────────
初始化           /document-init '<月度计划名>'
切换月度计划     /document-init plan '<新计划名>'
────────────────────────────────────────────────────────
需求淥清         /brainstorm
生成 PRD         /document-pm 生成 "<需求描述>"
评估 PRD         /document-pm 评估
提交 PRD         /document-pm 提交
────────────────────────────────────────────────────────
生成功能设计     /document-dev 生成 "<功能描述>"
设计评审         /document-dev 评审
提交设计文档     /document-dev 提交
────────────────────────────────────────────────────────
生成测试用例     /document-test 生成 "<测试场景>"
编制测试计划     /document-test 计划 "<项目名>"
提交测试文档     /document-test 提交
────────────────────────────────────────────────────────
生成进度报告     /document-overview 生成
更新进度报告     /document-overview 更新
钉钉播报         /document-overview 播报 简洁
项目健康度       /document-overview 健康度
────────────────────────────────────────────────────────
编写实现计划     /writing-plans
执行实现计划     /subagent-driven-development
请求代码审查     /requesting-code-review
接收代码审查     /receiving-code-review
────────────────────────────────────────────────────────
迭代经验总结     /document-compound 生成
提交知识库       /document-compound 提交
────────────────────────────────────────────────────────
```