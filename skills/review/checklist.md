# Pre-Landing Review Checklist

## 两遍审查法

**Pass 1 (CRITICAL - 最高优先级):**
- SQL & Data Safety
- Race Conditions & Concurrency
- LLM Output Trust Boundary
- Shell Injection

**Pass 2 (INFORMATIONAL - 次要优先级):**
- Code Quality
- Testing Gaps
- Documentation

---

## Pass 1 — CRITICAL

### SQL & Data Safety
- [ ] 字符串插值SQL（使用参数化查询）
- [ ] TOCTOU竞态条件（check-then-set应改为原子操作）
- [ ] 绕过模型验证直接写数据库
- [ ] N+1查询（缺少eager loading）

### Race Conditions & Concurrency
- [ ] read-check-write无唯一约束或错误处理
- [ ] find-or-create无唯一索引
- [ ] 状态转换未使用原子WHERE条件

### LLM Output Trust Boundary
- [ ] LLM生成的值写入DB前未验证格式
- [ ] LLM生成的URL未检查SSRF风险
- [ ] LLM输出存储到向量DB未清理

### Shell Injection
- [ ] subprocess.run() with shell=True + 用户输入
- [ ] os.system() with 变量插值
- [ ] eval()/exec() on LLM生成代码

---

## Pass 2 — INFORMATIONAL

### Code Quality
- [ ] 函数超过50行
- [ ] 复杂条件逻辑（>3个条件）
- [ ] 魔法数字/字符串未命名

### Testing Gaps
- [ ] 新代码无对应测试文件
- [ ] 边界情况未覆盖
- [ ] 测试代码过时

### Documentation
- [ ] 公共API无文档
- [ ] 复杂逻辑无注释
- [ ] README/CHANGELOG未更新

---

## 严重性分类

| 级别 | 含义 | 处理方式 |
|------|------|----------|
| P1 | 安全漏洞、崩溃、数据丢失 | 必须修复 |
| P2 | 潜在问题、代码异味 | 建议修复 |
| P3 | 质量改进 | 可选 |

---

## 置信度校准

| 分数 | 含义 | 显示规则 |
|------|------|----------|
| 9-10 | 已验证具体代码，确认问题 | 正常显示 |
| 7-8 | 高置信度模式匹配 | 正常显示 |
| 5-6 | 中等置信度，可能误报 | 显示警告 |
| 3-4 | 低置信度，可疑但可能正常 | 仅附录 |
| 1-2 | 推测 | 仅P1时报告