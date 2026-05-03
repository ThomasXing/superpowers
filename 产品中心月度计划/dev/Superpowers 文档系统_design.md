# Superpowers AI 插件系统 - 功能设计文档

## 1. 设计目标
- **解决什么问题**：为 AI 编码代理提供结构化开发工作流程的插件系统，解决技能复用、测试标准化和多代理协作问题
- **达到什么效果**：通过统一的技能架构和测试框架，提高 AI 代理的开发效率和质量，确保跨项目的一致性

## 2. 系统架构
- **模块划分**：
  - **Skills模块**：`/skills/` 目录，包含 20+ 核心技能（brainstorming, subagent-driven-development 等）
  - **Tests模块**：`/tests/claude-code/` 集成测试，验证真实 Claude Code 会话
  - **Docs模块**：`/docs/superpowers/` 架构文档和规范（specs + plans）
  - **Hooks模块**：`/hooks/` 会话生命周期自动化

- **数据流图**：
  ```
  用户需求 → Skills 技能处理 → Subagents 子代理 → 测试验证 → 文档沉淀
  ```

- **接口设计**：
  - **技能接口**：所有技能遵循统一的 SKILL.md 格式
  - **测试接口**：集成测试使用 `.jsonl` 会话文件验证
  - **文档接口**：specs 定义设计，plans 指导实施

## 3. 详细设计
- **关键算法**：
  - 技能加载机制：基于文件结构自动加载 `/skills/<skill-name>/SKILL.md`
  - 子代理驱动开发：协调 plan 加载、完整任务描述、自我审查、独立验证
  - 集成测试验证：解析 `.jsonl` 会话文件，验证技能调用和子代理调度

- **数据结构**：
  ```yaml
  Skill:
    name: "技能名称"
    description: "触发条件"
    directory: "/skills/技能名称/"
    tests: ["/tests/claude-code/test-*.sh"]
  
  TestSession:
    transcript: "*.jsonl"
    tool_calls: ["技能调用序列"]
    success_criteria: ["验证条件"]
  ```

- **状态流转**：
  ```
  技能开发 → 压力测试 → 集成验证 → 文档沉淀 → 版本发布
  ```

## 4. 接口规范
- **API设计**：
  - 技能加载 API：基于目录结构的自动发现机制
  - 子代理调度 API：统一的 Agent tool 调用协议
  - 测试验证 API：真实 Claude Code 会话的回放和验证

- **数据格式**：
  - 技能文档：Markdown + YAML frontmatter
  - 测试脚本：Bash + Python 分析脚本
  - 会话文件：JSON Lines 格式

- **错误处理**：
  - 技能加载失败：回退到基础功能，记录错误日志
  - 测试验证失败：提供详细的问题分析和修复建议
  - 子代理调度失败：重试机制和优雅降级

## 5. 部署方案
- **环境要求**：
  - Claude Code CLI 工具
  - Git 版本控制
  - Bash/Python 测试环境

- **部署步骤**：
  1. 克隆 superpowers 仓库
  2. 配置本地插件：`~/.claude/settings.json`
  3. 运行集成测试：`./tests/claude-code/test-*.sh`
  4. 验证技能加载：使用 `/技能名称` 命令测试

- **监控指标**：
  - 技能调用成功率
  - 测试通过率
  - 子代理执行效率
  - 会话 token 使用分析
  
## 6. 现有文档概览
基于 `docs/superpowers/` 目录分析：

### 规格文档（Specs）
- `2026-01-22-document-review-system-design.md` - 文档审查系统
- `2026-02-19-visual-brainstorming-refactor-design.md` - 可视化脑图重构
- `2026-03-11-zero-dep-brainstorm-server-design.md` - 零依赖脑暴服务器
- `2026-03-23-codex-app-compatibility-design.md` - Codex 应用兼容性

### 实施计划（Plans）
- `2026-01-22-document-review-system.md` - 文档审查系统实施
- `2026-02-19-visual-brainstorming-refactor.md` - 可视化脑图重构实施
- `2026-03-11-zero-dep-brainstorm-server.md` - 零依赖脑暴服务器实施
- `2026-04-17-gstack-to-superpowers-migration.md` - GStack 迁移计划

## 7. 开发工作流
1. **需求分析**：使用 `superpowers:brainstorming` 技能澄清需求
2. **规格设计**：创建 spec 文档，定义架构和接口
3. **实施计划**：编写 plan 文档，拆解为可执行任务
4. **技能开发**：使用 `superpowers:writing-skills` 技能开发实现
5. **测试验证**：运行集成测试，验证真实会话
6. **文档沉淀**：更新项目文档，形成知识闭环
