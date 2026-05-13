# Web前端开发操作文档

> 基于 spec-kit 产研协同工作流的 Web 前端开发指南，涵盖从需求评审到上线验收的完整流程。

---

## 目录

1. [开发环境准备](#开发环境准备)
2. [协作流程概览](#协作流程概览)
3. [需求阶段](#需求阶段)
4. [功能设计与开发](#功能设计与开发)
5. [前后端联调](#前后端联调)
6. [测试与验收](#测试与验收)
7. [代码审查与提交](#代码审查与提交)
8. [进度透明化](#进度透明化)

---

## 开发环境准备

### 技能安装

在 Qoder 中执行以下命令，安装前端开发相关技能：

```bash
# 安装全套技能
npx skills add http://172.16.100.5/root/spec-kit.git --skill using-spec -a qoder

# 安装开发相关技能
npx skills add http://172.16.100.5/root/spec-kit.git --skill document-init -a qoder
npx skills add http://172.16.100.5/root/spec-kit.git --skill document-dev -a qoder
npx skills add http://172.16.100.5/root/spec-kit.git --skill rap2 -a qoder
```

![技能安装](assets/image16.png)
![技能安装成功](assets/image17.png)

### 项目初始化

```bash
# 初始化 .sonli-spec-doc/ 目录结构
/document-init plan '2026年5月月度计划', doc git 'http://172.16.100.5/root/spec-doc.git', token 'your-token'
```

![项目初始化](assets/image14.png)
![初始化成功](assets/image15.png)

---

## 协作流程概览

```
需求评审 → UI设计规范沟通 → 功能设计 → 开发实施 → 前后端联调 → 自测 → Code Review → QA验收 → 冒烟测试
```

### 前端协作流程

1. 参与产品 PRD 需求评审
2. 参与 UI 设计规范沟通，协作制定项目 DESIGN.md
3. 根据产品 PRD、原型、设计稿开发前端代码并生成设计文档
4. 根据后端上传的 API 接口文档完成前后端联调
5. 根据测试上传的冒烟用例完成 Web 端集成测试并生成测试报告
6. 每天把实现的任务提交 PR（含 code-review）
7. 每天提交开发过程中产生的 Spec Doc
8. 提交测试后每天跟进解决项目过程产生的 bug
9. 参与产品发布前的冒烟测试与验收

---

## 需求阶段

### 参与 PRD 评审

### 协作制定设计规范

```bash
# 与设计团队协作制定 DESIGN.md
# 包含但不限于：
# - 色彩体系
# - 字体规范
# - 组件设计规范
# - 交互规范
```

---

## 功能设计与开发

### 生成技术设计文档

```bash
# 读取 PRD → 生成功能设计文档（含架构、接口、数据结构）
/document-dev 创建 <需求名> 设计文档
```

![功能设计文档](assets/image1.png)

### 实施计划拆解

```bash
# 使用 writing-plans 进行任务拆解
/writing-plans
```

### 实施计划拆解后提交

```bash
# 阶段性提交 Spec Doc
/document-dev 提交开发计划文档
```

![提交开发计划](assets/image2.png)

### 并行执行开发任务

```bash
# 使用 subagent-driven-development 并行执行独立任务
/subagent-driven-development
```

### 阶段性提交

```bash
# 提交开发计划文档
/document-dev 提交开发计划文档

# 提交测试报告文档
/document-dev 提交测试报告 --paths dogfood-output
```

![提交测试报告](assets/image5.png)

---

## 前后端联调

### 获取接口文档

```bash
# 查询 RAP2 接口文档
/rap2 查询接口

# 获取接口 Mock 数据（前端可脱离后端开发）
/rap2 Mock 数据
```

### 生成联调代码

```bash
# 生成 axios 前端调用代码
/rap2 生成axios联调代码
```

![提交API接口文档](assets/image3.png)

![API接口文档提交成功](assets/image4.png)

### 联调问题排查

```bash
# 定位集成问题根因
/investigate
```

---

## 测试与验收

### 开发自测

根据测试上传的冒烟用例以及产品文档完成 Web 端集成测试。

### 自动化 QA 测试

```bash
# 开发完成后触发自动化 QA 测试
/qa

# 快速冒烟测试（仅 critical + high 级别问题）
/qa --quick

# 仅出报告不自动修复
/qa-only

# 基于历史基线做回归测试
/qa --regression .gstack/qa-reports/baseline.json
```

![自动化QA测试](assets/image10.png)

**QA 流程**：浏览器自动化探索 → 每页截图 + Console 检查 → 发现 bug → 原子化 git commit 修复 → 回验 → 输出健康度报告。

**关键特性**：
- **Diff-aware 模式**：自动分析分支变更，仅测试受影响的页面
- **三层覆盖**：Quick（关键+高优）、Standard（+中优）、Exhaustive（+低优/样式）
- **自愈修复**：发现 bug 后自动定位源码 → 最小化修复 → atomic commit → re-test 验证
- **健康度评分**：Console / 链接 / 视觉 / 功能 / UX / 性能 / 可访问性 7 维度量化

---

## 代码审查与提交

### 请求代码审查

```bash
# 完成每个 Task 后触发代码审查
/requesting-code-review
```

### 接收审查意见

```bash
# 收到审查意见后理性评估（禁止盲目同意，需技术验证）
/receiving-code-review
```

### 提交 PR

每天把实现的任务提交 PR（包含 code-review）。

---

## 常见开发场景

### 新功能开发 (New Feature)

- 新产品功能开发（从 PRD 到上线全流程）
- 使用 `/document-dev` 生成技术设计文档和实施计划
- 使用 `/subagent-driven-development` 并行执行独立任务
- 使用 `/qa` 进行自动化测试与 bug 修复
- 使用 `/requesting-code-review` 完成代码审查后提交 PR

### 紧急修复 (Hot Fix)

- 线上紧急 bug 修复
- 使用 `/using-git-worktrees` 创建隔离分支环境，避免影响主开发流程
- 使用 `/investigate` 进行根因分析与问题定位
- 使用 `/systematic-debugging` 解决复杂技术问题
- 快速修复 → 本地验证 → 提交 PR → 紧急发布
- 修复后使用 `/document-compound` 沉淀问题模式与解决方案

### 重构与优化 (Refactor & Optimization)

- 代码重构与性能优化
- 使用 `/health` 检查代码质量基线
- 使用 `/design-review` 优化 UI 一致性与用户体验
- 使用 `/qa` 验证重构后功能完整性
- 性能优化使用 `/benchmark` 建立性能基线与对比

### 组件开发 (Component Development)

- 通用组件/组件库开发
- 使用 `/design-consultation` 建立设计规范
- 使用 `/design-html` 生成生产级 UI 实现
- 组件文档与使用示例编写
- 使用 `/qa` 进行跨浏览器兼容性测试

### 集成与调试 (Integration & Debugging)

- 第三方服务集成（API 对接、SDK 接入）
- 前后端联调与接口问题排查
- 使用 `/rap2` 查询与管理接口文档
- 使用 `/qa` 进行端到端功能验证
- 使用 `/investigate` 定位集成问题根因

---

## 进度透明化

```bash
# 项目健康度评估
/document-overview 健康度
```

![项目健康度](assets/image11.png)
