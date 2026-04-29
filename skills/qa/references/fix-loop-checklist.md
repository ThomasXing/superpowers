# Fix Loop Checklist（Phase 6 执行清单）

每个 fixable issue 按 severity 降序，**严格**执行以下 6 步。

---

## 6a. Locate source

- `grep -rn "<error message>"` 定位抛错位置
- `glob` 定位功能相关文件
- **禁止**修改与 issue 无关的文件
- 记录候选文件到 `source_files[]`

示例：
```bash
grep -rn "Cannot read properties of undefined" src/ --include="*.ts" | head -10
git log -5 --oneline -- src/auth/
```

---

## 6b. Fix（最小变更）

- 读源码，理解上下文（前后 20 行以上）
- 只做**最小修改** —— 不重构、不加功能、不"顺手改进"无关代码
- 若有多种修法，选"改动最少的那种"
- 如果修法要改 >3 个文件，停下来反思 —— 很可能抽象设计有问题，该 defer 并单开 plan

**禁止行为：**
- ❌ "顺便"修格式 / 重命名变量 / 整理 import
- ❌ 在同一 fix 里加新测试（回归测试是 Phase 7 的独立 commit）
- ❌ 跨 issue 合并修复

---

## 6c. Commit（原子化）

```bash
git add <仅-改动的文件>
git commit -m "fix(qa): ISSUE-NNN — <一句话描述>"
```

规则：
- **一个 issue = 一个 commit**，严禁打包
- Message 格式固定：`fix(qa): ISSUE-NNN — <desc>`
- `git add -A` 被禁止 —— 必须列出具体文件
- Body（可选）里写 "Before/After" 一句话与 repro URL

---

## 6d. Re-test（验证）

- 重跑**该 issue 相关**的测试（而非全量）
  - Jest / Vitest: `npx jest <file> -t "<test name>"`
  - Pytest: `pytest tests/path/test_x.py::test_name -v`
  - Go: `go test -run TestX ./pkg/...`
- 若是运行时报错，复现原触发路径（日志里的 stack trace 对应的操作序列）
- 记录重测输出到 `.qa-reports/evidence/issue-NNN-retest.log`

---

## 6e. Classify

根据 6d 的结果给 issue 分类：

| 分类 | 判定条件 | 后续动作 |
|---|---|---|
| `verified` | 重测通过，无新错误，无 console 新增异常 | → Phase 7 写回归测试 |
| `best-effort` | 改了但无法完全验证（如需要外部服务、仅 staging 能触发） | 报告里标注"待真机验证" |
| `reverted` | 发现回归（其他测试由绿变红） | **立即** `git revert HEAD` → 转 `deferred` |
| `deferred` | 超出本次 QA 能力（第三方 / 需产品决策 / 改动>3 文件） | 在报告记录 + 建议下一步 |

---

## 6e.5. 自动回归测试

详见 SKILL.md `## Phase 7`。

**skip 条件：**
- 分类不是 `verified`
- 纯 CSS / 纯文案
- 无测试框架且用户拒绝 bootstrap

---

## 6f. Self-Regulation

详见 SKILL.md `## Phase 8`。

**强制检查节点：**
- 每完成 5 个 fix 必算一次 WTF%
- 每发生一次 revert 立刻重算
- `WTF > 20%` → STOP + AskUserQuestion
- `已完成 fix 数 ≥ 50` → 硬停

---

## 常见陷阱与红线

| 红线 | 后果 | 正确做法 |
|---|---|---|
| 把多个 issue 压到一个 commit | 报告里 `fix commit SHA` 无法一对一 | 每个 issue 单独 add + commit |
| 修复时顺手改了无关文件 | WTF% 立刻 +20% | 改完无关文件单独 commit，或撤销 |
| 跳过重测直接进下一个 | 可能隐藏回归 | 必须 6d 产出 retest log |
| 回归测试断言 "it renders" | 等于没写 | 断言**触发 bug 的具体行为的正确结果** |
| 改到 >5 个文件仍不 defer | 很可能是设计问题伪装成 bug | defer + 单开 plan 讨论 |
