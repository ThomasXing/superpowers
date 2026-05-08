---
name: document-compound
description: Use when a problem has just been solved, a lesson learned, or a reusable pattern identified — capture it before context fades. Also use when summarizing development cycle experience for knowledge precipitation
---

# Document-Compound — 开发知识复利技能

> 每一次经验沉淀，都在为未来加速。第一次解决问题花30分钟研究，记录下来，下次2分钟。

**核心使命：问题解决后立即捕获，将实践经验转化为可复用的知识资产。**

## 概述

`document-compound` 是松立研发文档系统的知识复利模块，负责在问题解决后即时捕获经验、沉淀知识、识别模式。与传统的"周期总结"不同，本技能强调**即时性**——问题刚解决时上下文最完整，此时捕获的成本最低、质量最高。

## ⛳ 初始化配置前置检查（强制）

**执行任何 `/document-compound` 子命令前，必须先完成初始化检查**。未初始化时立即中止当前操作，引导用户执行 `/document-init`，严禁绕过。

### 必检项

- [ ] 当前处于 Git 仓库（`git rev-parse --show-toplevel` 可成功）
- [ ] `.sonli-spec-doc/config.yaml` 存在
- [ ] `storage.mode == git_repo`
- [ ] `directories.active_plan` 已设置（非空）
- [ ] `.sonli-spec-doc/knowledge-base/compound/` 目录存在

### 检查脚本（AI 执行此逻辑）

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "❌ 当前不在 Git 仓库"; exit 1; }
cd "$REPO_ROOT"

CONFIG=".sonli-spec-doc/config.yaml"
[ -f "$CONFIG" ] || { echo "❌ 未检测到 $CONFIG，请先执行 /document-init '<月度计划名>'"; exit 1; }

ACTIVE_PLAN=$(grep -E '^[[:space:]]*active_plan:' "$CONFIG" | head -1 | cut -d: -f2- | cut -d'#' -f1 | tr -d '"' | tr -d "'" | xargs)
[ -n "$ACTIVE_PLAN" ] || { echo "❌ active_plan 未设置，请执行 /document-init plan '<月度计划名>'"; exit 1; }

[ -d ".sonli-spec-doc/knowledge-base/compound" ] || { echo "❌ 知识库目录缺失：.sonli-spec-doc/knowledge-base/compound，请重新执行 /document-init '$ACTIVE_PLAN'"; exit 1; }

echo "✅ Compound 初始化配置检查通过（活跃计划：$ACTIVE_PLAN）"
```

### 未通过时的统一响应

```
⚠️ 未检测到文档初始化配置（或知识库目录缺失）
原因：<config.yaml 缺失 | active_plan 未配置 | compound 目录缺失>
建议：
  1. /document-init '2026年5月月度计划'   ← 首次初始化
  2. /document-init plan '2026年5月月度计划' ← 仅切换活跃计划
完成后请重新执行本命令。
```

### 理性化防护

| 漏洞 | 防护 |
|------|------|
| "经验总结丢到任意位置" | 禁止：必须进 `.sonli-spec-doc/knowledge-base/compound/` |
| "手动创建 config.yaml 绕过检查" | 禁止：必须通过 `/document-init` 保证 git commit 闭环 |
| "跨计划遥控总结，跳过当前 active_plan" | 禁止：经验总结输入必须关联当前 `active_plan` |

## 执行策略

使用平台的阻塞式提问工具向用户展示两种模式：`AskUserQuestion`

```
1. Full（推荐）— 完整的复利工作流。研究、交叉引用、审查你的解决方案，
   产出能复利团队知识的文档。

2. Lightweight — 同样的文档，单次扫描。更快、更省 token，
   但不会检测重复或交叉引用已有文档。适合简单修复或长会话接近上下文极限时。
```

**不要预选模式。不要跳过此提示。等待用户选择后再继续。**

**如果用户选择了 Full 模式**，继续询问一个后续问题：

```
是否也搜索当前会话历史中与该问题相关的知识？
这会增加时间和 token 用量。
```

如果用户选择是，在 Phase 1 中调度 Session Historian。如果否，跳过。Lightweight 模式下不问此问题。

---

### Full Mode

<critical_requirement>
**主要输出是一个文件 — 最终的知识文档。**

Phase 1 子智能体返回文本数据给协调者。它们不得使用 Write、Edit 或创建任何文件。只有协调者写文件：Phase 2 中的知识文档，以及 — 如果可发现性检查发现缺口 — 对项目指令文件的小编辑（AGENTS.md 或 CLAUDE.md）。指令文件编辑是维护，不是第二个交付物；它确保未来的智能体可以发现知识库。
</critical_requirement>

### Phase 0.5: Auto Memory 扫描

在启动 Phase 1 子智能体之前，检查注入到系统提示中的 auto-memory 块中是否有与当前文档化问题相关的笔记。

1. 查找标记为"user's auto-memory"的块（仅 Claude Code）— MEMORY.md 的条目已在其中内联
2. 如果该块不存在、为空、或者这是非 Claude Code 平台，跳过此步骤，继续 Phase 1
3. 扫描条目，寻找与当前文档化问题相关的内容 — 使用语义判断，不是关键词匹配
4. 如果找到相关条目，准备一个标注摘录块：

```
## 来自 auto memory 的补充笔记
作为额外上下文处理，不是主要证据。对话历史和代码库发现优先于这些笔记。

[相关条目内容]
```

5. 将此块作为额外上下文传递给 Phase 1 中的 Context Analyzer 和 Solution Extractor。如果任何 memory 笔记最终出现在最终文档中（例如，作为调查步骤或根因分析的一部分），用 "(auto memory [claude])" 标记其来源。

如果没有找到相关条目，直接进入 Phase 1，不传递 memory 上下文。

### Phase 1: 研究

启动研究子智能体。每个子智能体返回文本数据给协调者。

**调度顺序：**
- 并行启动（后台）`Context Analyzer`、`Solution Extractor` 和 `Related Docs Finder`
- 然后在前台调度 `Session Historian` — 它读取工作目录之外的会话文件，后台智能体可能无权访问
- 前台调度在后台智能体工作的同时运行，不增加墙钟时间

<parallel_tasks>

#### 1. **Context Analyzer**
   - 从对话历史中提取上下文
   - 读取 `references/schema.yaml` 获取枚举验证和**轨道分类**
   - 从 problem_type 确定轨道（bug 或 knowledge）
   - 识别问题类型、组件和轨道相应字段：
     - **Bug 轨道**: symptoms, root_cause, resolution_type
     - **Knowledge 轨道**: applies_when（symptoms/root_cause/resolution_type 可选）
   - 整合 auto memory 摘录（如果协调者提供）作为补充证据
   - 读取 `references/yaml-schema.md` 获取 `.sonli-spec-doc/knowledge-base/compound/` 中的分类映射
   - 使用模式 `[sanitized-problem-slug]-[date].md` 建议文件名
   - 返回：YAML frontmatter 骨架（必须包含 `category:` 字段从 problem_type 映射），分类目录路径，建议文件名，以及适用哪个轨道
   - 不得从记忆中发明枚举值、分类或 frontmatter 字段；读取上述 schema 和映射文件
   - 不得将 bug 轨道字段强行用于 knowledge 轨道学习，反之亦然

#### 2. **Solution Extractor**
   - 读取 `references/schema.yaml` 获取轨道分类（bug vs knowledge）
   - 根据 problem_type 轨道调整输出结构
   - 整合 auto memory 摘录（如果协调者提供）作为补充证据 — 对话历史和已验证的修复优先；如果 memory 笔记与对话矛盾，将矛盾标注为警示上下文

   **Bug 轨道输出章节：**

   - **Problem**: 1-2 句问题描述
   - **Symptoms**: 可观察的症状（错误信息、行为）
   - **What Didn't Work**: 失败的调查尝试及其原因
   - **Solution**: 实际修复及代码示例（适用时包含 before/after）
   - **Why This Works**: 根因解释及为何解决方案解决了它
   - **Prevention**: 避免复发的策略、最佳实践和测试用例。适用时包含具体代码示例

   **Knowledge 轨道输出章节：**

   - **Context**: 什么情况、差距或摩擦促成了此指导
   - **Guidance**: 实践、模式或建议，适用时含代码示例
   - **Why This Matters**: 遵循或不遵循此指导的理由和影响
   - **When to Apply**: 此指导适用的条件或情况
   - **Examples**: 具体的 before/after 或使用示例

#### 3. **Related Docs Finder**
   - 搜索 `.sonli-spec-doc/knowledge-base/compound/` 中的相关文档
   - 识别交叉引用和链接
   - 发现相关的 GitLab issues
   - 标记任何可能已过时、矛盾或过于宽泛的相关学习或模式文档
   - **评估重叠**：跨五个维度评估与新文档的重叠：问题陈述、根因、解决方案方法、引用文件和预防规则。评分：
     - **High**: 4-5 维度匹配 — 本质上是同一个问题再次被解决
     - **Moderate**: 2-3 维度匹配 — 同一领域但不同角度或解决方案
     - **Low**: 0-1 维度匹配 — 相关但不同
   - 返回：链接、关系、刷新候选和重叠评估（分数 + 哪些维度匹配）

   **搜索策略（grep-first 过滤提高效率）：**

   1. 从问题上下文提取关键词：模块名、技术术语、错误信息、组件类型
   2. 如果问题分类明确，将搜索范围缩小到匹配的 `.sonli-spec-doc/knowledge-base/compound/<category>/` 目录
   3. 使用原生内容搜索工具预过滤候选文件，然后读取内容。并行运行多个搜索，不区分大小写：
      - `title:.*<keyword>`
      - `tags:.*(<keyword1>|<keyword2>)`
      - `module:.*<module name>`
      - `component:.*<component>`
   4. 如果搜索返回 >25 个候选，使用更具体的模式重跑。如果 <3，扩展到全文搜索
   5. 仅读取候选文件的 frontmatter（前30行）来评分相关性
   6. 仅完整读取强/中等匹配
   7. 返回提炼后的链接和关系，不返回原始文件内容

</parallel_tasks>

#### 4. **Session Historian**（前台，在上述启动之后 — 仅当用户选择时）
   - **完全跳过**如果用户在后续问题中拒绝了会话历史
   - 在**前台**调度 — 此智能体读取工作目录之外的会话文件
   - 省略 `mode` 参数，使用用户配置的权限设置

   **调度提示 — 保持简洁。** 冗长、关键词密集的提示会让智能体不断扩大搜索范围。使用此结构：

   - **预解析上下文**（仅当上面的值干净解析时；否则省略让智能体在运行时推导）：仓库名、当前 git 分支
   - **时间窗口**：明确的 `7 days`，除非文档化的问题明显跨越更长时间
   - **问题主题**：一句话命名具体问题 — 错误信息、模块名、什么坏了以及如何修复的。不是一段话；不是相关主题的要点列表
   - **过滤规则（一行）**："仅返回与此具体问题直接相关的发现。忽略同一会话或分支中的无关工作。"
   - **输出 schema**：

     ```
     使用以下章节构建响应（无发现时省略该章节）：
     - 之前尝试过的
     - 什么没起作用
     - 关键决策
     - 相关上下文
     ```

   - 返回：先前会话发现的结构化摘要，或"无相关先前会话"

### Phase 2: 组装与写入

<sequential_tasks>

**等待所有 Phase 1 子智能体完成后再继续。**

协调智能体（主对话）执行以下步骤：

1. 收集 Phase 1 子智能体的所有文本结果
2. **检查重叠评估**：在决定写什么之前，检查 Related Docs Finder 的结果：

   | 重叠 | 动作 |
   |------|------|
   | **High** — 现有文档涵盖了相同的问题、根因和解决方案 | **更新现有文档**，注入更新的上下文（新代码示例、更新引用、额外预防提示），而不是创建重复。现有文档的路径和结构保持不变。 |
   | **Moderate** — 同一问题领域但不同角度、根因或解决方案 | **正常创建新文档**。标记重叠供 Phase 2.5 建议合并审查。 |
   | **Low 或无** | **正常创建新文档**。 |

   更新而非创建的原因：两份描述相同问题和解决方案的文档不可避免地会产生偏差。更新的上下文更可靠，因此将其融入现有文档而不是创建第二份立即需要合并的文档。

   更新现有文档时，保留其文件路径和 frontmatter 结构。更新解决方案、代码示例、预防提示和任何过时引用。添加 `last_updated: YYYY-MM-DD` 字段到 frontmatter。除非问题框架有实质性变化，否则不更改标题。

3. **整合会话历史发现**（如果可用）：
   - 将调查死胡同和失败方法折叠到 **What Didn't Work** 章节（bug 轨道）或 **Context** 章节（knowledge 轨道）
   - 使用跨会话模式丰富 **Prevention** 或 **Why This Matters** 章节
   - 用 "(session history)" 标记会话来源内容
   - 如果发现稀疏或"无相关先前会话"，不使用会话上下文继续
4. 从收集的部分组装完整 markdown 文件，读取 `assets/resolution-template.md` 获取新文档的章节结构
5. 根据 `references/schema.yaml` 验证 YAML frontmatter，包括数组项的 YAML 安全引用规则（见 `references/yaml-schema.md` > YAML Safety Rules）
6. 如有需要创建目录：`mkdir -p .sonli-spec-doc/knowledge-base/compound/[category]/`
7. 写入文件：更新现有文档或新的 `.sonli-spec-doc/knowledge-base/compound/[category]/[filename].md`
8. **运行 `python3 scripts/validate-frontmatter.py <output-path>`** 捕获散文规则未覆盖的静默损坏解析安全问题：格式错误的 `---` 分隔行、标量值中未引用的 ` #`（静默注释截断）和未引用的 `: `（静默映射混淆）。退出码 0 表示文档解析安全；退出码 1 表示脚本的 stderr 指出了有问题的字段和修复方法 — 引用值，重写文档，重新运行直到退出码 0。在验证失败时不得声明成功。

创建新文档时，保留 `assets/resolution-template.md` 的章节顺序，除非用户明确要求不同结构。

</sequential_tasks>

### Phase 2.5: 选择性刷新检查

写入新学习后，决定此新解决方案是否是旧文档需要刷新的证据。

这不是默认的后续步骤。仅在新学习暗示旧学习或模式文档可能不再准确时选择性地使用。

适合调用刷新检查的情况：

1. 相关学习或模式文档推荐的方法被新修复所矛盾
2. 新修复明确取代了旧的文档化解决方案
3. 当前工作涉及重构、迁移、重命名或依赖升级，可能使旧文档中的引用失效
4. 模式文档现在看起来过于宽泛、过时或不再被刷新的现实支持
5. Related Docs Finder 发现同一问题空间中的高置信度刷新候选
6. Related Docs Finder 报告与现有文档的**中等重叠** — 可能有合并审查的机会

不适合刷新的情况：

1. 没有找到相关文档
2. 相关文档与新学习仍然一致
3. 重叠是表面的，不改变先前指导
4. 刷新需要广泛的历史审查且证据薄弱

使用这些规则：

- 如果有**一个明显的过时候选**，在新学习写入后调用刷新，范围窄
- 如果有**同一领域的多个候选**，询问用户是否对该模块、分类或模式集运行定向刷新
- 如果上下文已经很紧张或处于 lightweight 模式，不自动扩展到广泛刷新；改为建议下一步运行刷新

### 可发现性检查

在学习写入并做出刷新决策后，检查项目的指令文件是否会引导智能体在文档化领域开始工作之前发现并搜索 `.sonli-spec-doc/knowledge-base/compound/`。每次都运行 — 知识库只有在智能体能找到它时才产生复利价值。

1. 识别存在哪些根级指令文件（AGENTS.md, CLAUDE.md, 或两者）。读取文件并确定哪个包含实质内容 — 一个文件可能只是一个 shim，`@` 包含另一个。实质文件是评估和编辑目标；忽略 shim。如果两个文件都不存在，完全跳过此检查。
2. 评估读取指令文件的智能体是否会学到三件事：
   - 存在一个可搜索的已文档化解决方案的知识库
   - 足够了解其结构以有效搜索（分类组织、YAML frontmatter 字段如 `module`、`tags`、`problem_type`）
   - 何时搜索它（在实现功能、调试问题或在文档化领域做决策之前）

   这是语义评估，不是字符串匹配。信息可以是架构部分中的一行、注意事项部分中的一个项目、分散在多个地方，或者从不使用确切路径 `.sonli-spec-doc/knowledge-base/compound/` 来表达。使用判断力 — 如果智能体在读取文件后合理地会发现和使用知识库，检查通过。

3. 如果精神已满足，无需行动 — 继续。
4. 如果不满足：
   a. 基于文件现有结构、语气和密度，找到信息自然适合的位置。在创建新章节之前，检查信息是否可以是最相关章节中的一行 — 架构树、目录列表、文档章节或约定块。添加到现有章节的一行几乎总是优于新标题章节。
   b. 起草传达三件事的最小添加。匹配文件现有的风格和密度。

      保持语气信息性，而非命令性。将时机表达为描述，而非指令 — "在文档化领域实现或调试时相关"而不是"在实现或调试前检查。"命令性指令如"总是在实现前搜索"当工作流已包含专用搜索步骤时会导致冗余读取。目标是意识：智能体了解文件夹存在和其中内容，然后自行判断何时查阅。

      校准示例（非模板 — 适应文件）：

      当存在现有目录列表或架构部分时 — 添加一行：
      ```
      .sonli-spec-doc/knowledge-base/compound/  # 已文档化的问题解决方案（bug、最佳实践、工作流模式），按分类组织，含 YAML frontmatter（module, tags, problem_type）
      ```

      当文件中没有自然适合的位置时 — 一个小标题章节是合适的：
      ```
      ## 已文档化解决方案

      `.sonli-spec-doc/knowledge-base/compound/` — 已文档化的问题解决方案（bug、最佳实践、工作流模式），按分类组织，含 YAML frontmatter（`module`、`tags`、`problem_type`）。在文档化领域实现或调试时相关。
      ```
   c. 在 full 模式中，向用户解释为什么这很重要 — 在此仓库工作的智能体（包括新会话、其他工具或没有插件的协作者）不会知道检查知识库，除非指令文件披露它。显示提议的更改和位置，然后使用平台的阻塞式提问工具获取同意后再编辑。在 lightweight 模式中，输出一行注释并继续。

### Phase 3: 可选增强

**等待 Phase 2 完成后再继续。**

<parallel_tasks>

基于问题类型，可选地调用专业智能体审查文档：

- **performance_issue** → 性能审查
- **security_issue** → 安全审查
- **database_issue** → 数据完整性审查
- 任何代码密集型问题 → 总是运行代码简洁性审查

</parallel_tasks>

---

### Lightweight Mode

<critical_requirement>
**单次扫描替代 — 同样的文档，更少的 token。**

此模式完全跳过并行子智能体。协调者在单次扫描中执行所有工作，产出相同的解决方案文档，但没有交叉引用或重复检测。
</critical_requirement>

协调者（主对话）按顺序执行以下所有步骤：

1. **从对话中提取**：从对话历史中识别问题和解决方案。同时扫描系统提示中注入的"user's auto-memory"块（如果存在，仅 Claude Code）— 使用任何相关笔记作为对话历史的补充上下文。将任何整合到最终文档中的 memory 来源内容标记为 "(auto memory [claude])"
2. **分类**：读取 `references/schema.yaml` 和 `references/yaml-schema.md`，然后确定轨道（bug vs knowledge）、分类和文件名
3. **写入最小文档**：使用 `assets/resolution-template.md` 中适当的轨道模板创建 `.sonli-spec-doc/knowledge-base/compound/[category]/[filename].md`，包含：
   - YAML frontmatter，使用轨道相应字段，应用数组项的 YAML 安全引用规则（见 `references/yaml-schema.md` > YAML Safety Rules）
   - Bug 轨道：Problem, root cause, solution 含关键代码片段，一条 prevention 提示
   - Knowledge 轨道：Context, guidance 含关键示例，一条适用性说明
4. **跳过专业智能体审查**（Phase 3）以节省上下文

**Lightweight 输出：**
```
✓ 文档完成（lightweight 模式）

文件已创建：
- .sonli-spec-doc/knowledge-base/compound/[category]/[filename].md

[如果可发现性检查发现指令文件未暴露知识库：]
提示：你的 AGENTS.md/CLAUDE.md 未向智能体暴露 .sonli-spec-doc/knowledge-base/compound/ —
简要提及可帮助所有智能体发现这些学习。

注意：此文档以 lightweight 模式创建。如需更丰富的文档
（交叉引用、详细预防策略、专业审查），
在新会话中以 Full 模式重新运行 /document-compound。
```

**不启动子智能体。不并行任务。写入一个文件。**

在 lightweight 模式中，重叠检查被跳过（没有 Related Docs Finder 子智能体）。这意味着 lightweight 模式可能创建与现有文档重叠的文档。这是可接受的 — 刷新检查稍后会捕获它。仅当有明显的窄范围刷新目标时才建议刷新。不要从 lightweight 会话扩展到大型刷新扫描。

---

## 知识存储路径

**文档存储在 `.sonli-spec-doc/knowledge-base/compound/` 下，按分类组织。**

```
.sonli-spec-doc/knowledge-base/compound/
├── build-errors/           # 构建错误
├── test-failures/          # 测试失败
├── runtime-errors/         # 运行时错误
├── performance-issues/     # 性能问题
├── database-issues/        # 数据库问题
├── security-issues/        # 安全问题
├── ui-bugs/                # UI 缺陷
├── integration-issues/     # 集成问题
├── logic-errors/           # 逻辑错误
├── architecture-patterns/  # 架构模式
├── design-patterns/        # 设计模式
├── tooling-decisions/      # 工具选型决策
├── conventions/            # 团队约定
├── workflow-issues/        # 工作流问题
├── developer-experience/   # 开发体验
├── documentation-gaps/     # 文档缺口
└── best-practices/         # 最佳实践（兜底）
```

## 分类自动检测

从问题类型自动映射到分类目录：

| 轨道 | problem_type | 分类目录 |
|------|-------------|---------|
| Bug | `build_error` | `build-errors/` |
| Bug | `test_failure` | `test-failures/` |
| Bug | `runtime_error` | `runtime-errors/` |
| Bug | `performance_issue` | `performance-issues/` |
| Bug | `database_issue` | `database-issues/` |
| Bug | `security_issue` | `security-issues/` |
| Bug | `ui_bug` | `ui-bugs/` |
| Bug | `integration_issue` | `integration-issues/` |
| Bug | `logic_error` | `logic-errors/` |
| Knowledge | `developer_experience` | `developer-experience/` |
| Knowledge | `workflow_issue` | `workflow-issues/` |
| Knowledge | `best_practice` | `best-practices/` |
| Knowledge | `documentation_gap` | `documentation-gaps/` |
| Knowledge | `architecture_pattern` | `architecture-patterns/` |
| Knowledge | `design_pattern` | `design-patterns/` |
| Knowledge | `tooling_decision` | `tooling-decisions/` |
| Knowledge | `convention` | `conventions/` |

## Git 提交集成

```bash
# 知识文档写入后归档
KB_PATH=".sonli-spec-doc/knowledge-base/compound"

git add "$KB_PATH/"
git commit -m "docs(compound): add learning - <主题名称>"
```

### 与月度开发周期关联

```bash
# 关联当前活跃计划
ACTIVE_PLAN=$(grep -E '^[[:space:]]*active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | cut -d'#' -f1 | tr -d '"' | tr -d "'" | xargs)

git add ".sonli-spec-doc/knowledge-base/"
git commit -m "docs(compound): add learning for $ACTIVE_PLAN - <主题名称>"
```

## 复利哲学

**核心洞察：每次经验沉淀都在为未来加速。**

1. 第一次解决"N+1 查询" → 研究 30 分钟
2. 记录解决方案 → `.sonli-spec-doc/knowledge-base/compound/performance-issues/n-plus-one-queries.md`（5 分钟）
3. 下次类似问题出现 → 快速查找（2 分钟）
4. 知识复利 → 团队越来越聪明

```
构建 → 测试 → 发现问题 → 研究 → 改进 → 文档化 → 验证 → 部署
    ↑                                                                   ↓
    └───────────────────────────────────────────────────────────────────┘
```

**每个工程工作单元应使后续工作更容易 — 而非更难。**

## 常见错误

| ❌ 错误 | ✅ 正确 |
|---------|--------|
| 子智能体写文件如 `context-analysis.md`、`solution-draft.md` | 子智能体返回文本数据；协调者写一个最终文件 |
| 研究和组装并行运行 | 研究完成 → 然后组装运行 |
| 工作流中创建多个文件 | 一个知识文档被写入或更新：`.sonli-spec-doc/knowledge-base/compound/[category]/[filename].md`（加上可选的项目指令文件小编辑） |
| 当现有文档覆盖同一问题时创建新文档 | 检查重叠评估；高重叠时更新现有文档 |

## 成功输出

```
✓ 文档完成

Auto memory: 2 个相关条目作为补充证据使用

子智能体结果：
  ✓ Context Analyzer: 识别 performance_issue in business_service, 分类: performance-issues/
  ✓ Solution Extractor: 3 个代码修复，预防策略
  ✓ Related Docs Finder: 2 个相关问题
  ✓ Session History: 3 个先前会话在同一分支，2 个失败方法被发现

文件已创建：
- .sonli-spec-doc/knowledge-base/compound/performance-issues/n-plus-one-brief-generation.md

此文档在未来 Email Processing 或 Brief System 模块出现类似问题时可搜索。

下一步？
1. 继续工作流（推荐）
2. 链接相关文档
3. 更新其他引用
4. 查看文档
5. 其他
```

**显示成功输出后，使用平台的阻塞式提问工具呈现"下一步？"选项。** 不要在用户选择之前继续工作流或结束轮次。

**替代输出（当因高重叠而更新现有文档时）：**

```
✓ 文档已更新（现有文档用当前上下文刷新）

检测到重叠：.sonli-spec-doc/knowledge-base/compound/performance-issues/n-plus-one-queries.md
  匹配维度：问题陈述、根因、解决方案、引用文件
  动作：用更新的代码示例和预防提示更新现有文档

文件已更新：
- .sonli-spec-doc/knowledge-base/compound/performance-issues/n-plus-one-queries.md (添加 last_updated: 2026-05-08)
```

## Auto-Invoke

<auto_invoke>
<trigger_phrases>
- "搞定了"
- "修好了"
- "解决了"
- "it's fixed"
- "working now"
- "problem solved"
- "成功了"
</trigger_phrases>

<manual_override>
使用 `/document-compound [上下文提示]` 立即文档化，不等待自动检测。
</manual_override>
</auto_invoke>

## 与其他技能深度集成

### 1. 与 document-pm 集成
- **需求管理经验**: 总结 PRD 管理的成功经验和失败教训
- **需求澄清模式**: 沉淀需求澄清的有效模式和方法
- **变更管理经验**: 总结需求变更管理的经验和教训

### 2. 与 document-dev 集成
- **设计模式沉淀**: 沉淀优秀的设计模式和架构方案
- **技术决策经验**: 总结技术决策的经验和教训
- **代码质量经验**: 总结代码质量管理的有效实践

### 3. 与 document-test 集成
- **测试策略经验**: 总结测试策略的成功经验和优化方向
- **缺陷预防经验**: 沉淀缺陷预防的有效方法和模式
- **质量保障经验**: 总结质量保障体系的建设经验

### 4. 与 document-overview 集成
- **进度管理经验**: 总结进度管理的成功经验和改进点
- **风险管理经验**: 沉淀风险识别和应对的有效模式

## 前置条件

<preconditions enforcement="advisory">
  <check condition="problem_solved">
    问题已解决（非进行中）
  </check>
  <check condition="solution_verified">
    解决方案已验证工作正常
  </check>
  <check condition="non_trivial">
    非平凡问题（不是简单的拼写错误或明显错误）
  </check>
</preconditions>

## 理性化防护

| 漏洞 | 防护 |
|------|------|
| "项目结束了，不用总结了" | **强制总结**：问题解决后必须文档化，不总结就是浪费 |
| "经验都记在脑子里了" | **强制沉淀**：经验必须文档化，不沉淀就丢失 |
| "这个教训大家都知道" | **强制记录**：大家都知道也要记录，防止遗忘 |
| "模式识别太复杂，算了" | **强制识别**：模式必须识别，复杂也要做 |
| "下次不会再犯同样的错" | **强制文档化**：个人记忆不可靠，文档才是保障 |

---
**子智能体标识**: document-compound-agent
**版本**: 3.0.0
**创建时间**: 2026-05-08
**依赖**: Git、/document-init、其他 document 技能文档数据
**状态**: 就绪
**owner**: 知识管理负责人/技术负责人
