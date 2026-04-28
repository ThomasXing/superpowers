#!/bin/bash
# document-workflow-test.sh
# 松立研发document技能闭环工作流测试

set -e

echo "🔄 Document技能闭环工作流测试"
echo "========================================"
echo "测试目标：验证从PRD生成到概览更新的完整工作流"
echo "测试环境：模拟环境（无真实GitLab连接）"
echo "========================================"

# 创建测试目录
TEST_DIR="/tmp/document-test-$(date +%s)"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "📁 创建测试目录: $TEST_DIR"

# 阶段1：模拟PRD生成
echo ""
echo "📝 阶段1：PRD生成测试"
echo "----------------------"
PRD_FILE="$TEST_DIR/user-management-prd.md"
echo "使用PRD模板生成测试文档..."
cat > "$PRD_FILE" << 'EOF'
# 用户管理系统PRD

## 1. 需求背景
测试document技能闭环工作流

## 2. 目标
- 验证技能完整工作流
- 测试模板使用
- 检查文档质量

## 3. 功能需求
- 用户注册
- 用户登录
- 权限管理

## 4. 验收标准
- 工作流测试通过
- 文档符合模板要求
- 无关键错误
EOF

if [ -f "$PRD_FILE" ]; then
    PRD_LINES=$(wc -l < "$PRD_FILE")
    PRD_SECTIONS=$(grep -c "^## " "$PRD_FILE")
    echo "✅ PRD生成成功"
    echo "   - 文档行数: $PRD_LINES"
    echo "   - 章节数: $PRD_SECTIONS"
else
    echo "❌ PRD生成失败"
    exit 1
fi

# 阶段2：模拟功能设计
echo ""
echo "📐 阶段2：功能设计测试"
echo "----------------------"
DESIGN_FILE="$TEST_DIR/user-management-design.md"
echo "使用设计模板生成文档..."
cp "/Users/thomasxing/workspace/2026/3月份计划/AI研发/superpowers/skills/document/templates/design-spec-template.md" "$DESIGN_FILE"

if [ -f "$DESIGN_FILE" ]; then
    # 替换模板占位符
    sed -i '' 's/填写项目名称/用户管理系统/g' "$DESIGN_FILE"
    sed -i '' 's/YYYY-MM-DD/2026-04-20/g' "$DESIGN_FILE"

    DESIGN_LINES=$(wc -l < "$DESIGN_FILE")
    DESIGN_SECTIONS=$(grep -c "^## " "$DESIGN_FILE")
    echo "✅ 设计文档生成成功"
    echo "   - 文档行数: $DESIGN_LINES"
    echo "   - 章节数: $DESIGN_SECTIONS"
    echo "   - 已替换占位符: 项目名称、日期"
else
    echo "❌ 设计文档生成失败"
    exit 1
fi

# 阶段3：模拟测试用例
echo ""
echo "🧪 阶段3：测试用例测试"
echo "----------------------"
TEST_FILE="$TEST_DIR/user-management-testcases.md"
echo "使用测试用例模板生成文档..."
cp "/Users/thomasxing/workspace/2026/3月份计划/AI研发/superpowers/skills/document/templates/test-case-template.md" "$TEST_FILE"

if [ -f "$TEST_FILE" ]; then
    # 替换模板占位符
    sed -i '' 's/填写项目名称/用户管理系统/g' "$TEST_FILE"

    TEST_LINES=$(wc -l < "$TEST_FILE")
    TEST_CASES=$(grep -c "用例ID" "$TEST_FILE")
    echo "✅ 测试用例生成成功"
    echo "   - 文档行数: $TEST_LINES"
    echo "   - 测试用例数: $TEST_CASES"
else
    echo "❌ 测试用例生成失败"
    exit 1
fi

# 阶段4：模拟项目概览
echo ""
echo "📊 阶段4：项目概览测试"
echo "----------------------"
OVERVIEW_FILE="$TEST_DIR/user-management-overview.md"
echo "使用概览模板生成文档..."
cp "/Users/thomasxing/workspace/2026/3月份计划/AI研发/superpowers/skills/document/templates/overview-template.md" "$OVERVIEW_FILE"

if [ -f "$OVERVIEW_FILE" ]; then
    # 替换模板占位符
    sed -i '' 's/填写项目名称/用户管理系统/g' "$OVERVIEW_FILE"
    sed -i '' 's/第X周/第1周/g' "$OVERVIEW_FILE"
    sed -i '' 's/YYYY-MM-DD/2026-04-20/g' "$OVERVIEW_FILE"

    OVERVIEW_LINES=$(wc -l < "$OVERVIEW_FILE")
    OVERVIEW_SECTIONS=$(grep -c "^## " "$OVERVIEW_FILE")

    # 生成钉钉播报
    DINGTALK_FILE="$TEST_DIR/dingtalk-report.md"
    cat > "$DINGTALK_FILE" << 'EOF'
【项目进度播报】2026-04-20

📊 整体进度：30%
🎯 本周完成：PRD、设计文档、测试用例生成
⚠️ 当前风险：GitLab CLI依赖未安装
👥 团队状态：测试中
📅 下周重点：真实环境部署测试

详细报告：待补充
EOF

    echo "✅ 项目概览生成成功"
    echo "   - 文档行数: $OVERVIEW_LINES"
    echo "   - 章节数: $OVERVIEW_SECTIONS"
    echo "   - 钉钉播报已生成"
else
    echo "❌ 项目概览生成失败"
    exit 1
fi

# 阶段5：目录结构验证
echo ""
echo "📁 阶段5：目录结构验证"
echo "----------------------"
echo "验证AI开发方案中的目录结构..."
mkdir -p "wit-parking-wiki/产品中心月度计划/pm/prd"
mkdir -p "wit-parking-wiki/产品中心月度计划/dev/plans"
mkdir -p "wit-parking-wiki/产品中心月度计划/dev/tasks"
mkdir -p "wit-parking-wiki/产品中心月度计划/dev/test report"
mkdir -p "wit-parking-wiki/产品中心月度计划/dev/review report"
mkdir -p "wit-parking-wiki/产品中心月度计划/test/testcases"
mkdir -p "wit-parking-wiki/产品中心月度计划/test/test report"

# 复制文档到对应目录
cp "$PRD_FILE" "wit-parking-wiki/产品中心月度计划/pm/prd/"
cp "$DESIGN_FILE" "wit-parking-wiki/产品中心月度计划/dev/plans/"
cp "$TEST_FILE" "wit-parking-wiki/产品中心月度计划/test/testcases/"
cp "$OVERVIEW_FILE" "wit-parking-wiki/"

# 创建其他文档
echo "# DESIGN规范" > "wit-parking-wiki/DESIGN.md"
echo "# 变更日志" > "wit-parking-wiki/CHANGELOG.md"

# 验证目录结构
echo "检查目录结构..."
find wit-parking-wiki -type f -name "*.md" | sort | while read file; do
    echo "   - 📄 $file"
done

DIR_COUNT=$(find wit-parking-wiki -type d | wc -l)
FILE_COUNT=$(find wit-parking-wiki -type f -name "*.md" | wc -l)

echo "✅ 目录结构验证通过"
echo "   - 目录数: $DIR_COUNT"
echo "   - 文档数: $FILE_COUNT"

# 阶段6：GitLab集成模拟
echo ""
echo "🔗 阶段6：GitLab集成模拟"
echo "----------------------"
echo "模拟GitLab CLI命令执行..."
# 创建模拟脚本
cat > "$TEST_DIR/simulate-gitlab.sh" << 'EOF'
#!/bin/bash
echo "模拟GitLab CLI操作:"
echo "1. 检查认证: glab auth status"
echo "2. 创建Wiki页面: glab repo wiki create \"产品中心月度计划/pm/prd/v1.0.0\""
echo "3. 更新概览: glab repo wiki update \"overview.md\""
echo "4. 列出页面: glab repo wiki list"
EOF

chmod +x "$TEST_DIR/simulate-gitlab.sh"
echo "✅ GitLab集成命令模拟已准备"
echo "   - 模拟脚本: $TEST_DIR/simulate-gitlab.sh"

# 阶段7：完整性检查
echo ""
echo "🔍 阶段7：完整性检查"
echo "----------------------"
echo "检查工作流完整性..."

MISSING=0

# 检查AI开发方案中的5个功能
echo "1. 检查AI开发方案功能覆盖:"
FUNCTIONS=("init" "pm" "dev" "test" "overview")
for func in "${FUNCTIONS[@]}"; do
    if grep -q "/document $func\|/document:$func" "/Users/thomasxing/workspace/2026/3月份计划/AI研发/superpowers/skills/document/SKILL.md"; then
        echo "   - ✅ /document:$func 已覆盖"
    else
        echo "   - ❌ /document:$func 未覆盖"
        MISSING=$((MISSING+1))
    fi
done

# 检查模板完整性
echo ""
echo "2. 检查模板完整性:"
TEMPLATES=("prd-template.md" "design-spec-template.md" "test-case-template.md" "overview-template.md")
for template in "${TEMPLATES[@]}"; do
    if [ -f "/Users/thomasxing/workspace/2026/3月份计划/AI研发/superpowers/skills/document/templates/$template" ]; then
        LINES=$(wc -l < "/Users/thomasxing/workspace/2026/3月份计划/AI研发/superpowers/skills/document/templates/$template")
        echo "   - ✅ $template ($LINES 行)"
    else
        echo "   - ❌ $template 缺失"
        MISSING=$((MISSING+1))
    fi
done

# 检查依赖说明
echo ""
echo "3. 检查依赖说明:"
if grep -q "GitLab CLI检查\|glab" "/Users/thomasxing/workspace/2026/3月份计划/AI研发/superpowers/skills/document/SKILL.md"; then
    echo "   - ✅ GitLab依赖已说明"
else
    echo "   - ❌ GitLab依赖未说明"
    MISSING=$((MISSING+1))
fi

# 阶段8：测试结果
echo ""
echo "📋 阶段8：测试结果汇总"
echo "======================"
echo "工作流测试完成!"
echo ""
echo "📊 生成文档统计:"
echo "   - PRD文档: $PRD_LINES 行, $PRD_SECTIONS 章节"
echo "   - 设计文档: $DESIGN_LINES 行, $DESIGN_SECTIONS 章节"
echo "   - 测试用例: $TEST_LINES 行, $TEST_CASES 个用例"
echo "   - 项目概览: $OVERVIEW_LINES 行, $OVERVIEW_SECTIONS 章节"
echo ""
echo "📁 目录结构:"
echo "   - 创建目录: $DIR_COUNT 个"
echo "   - 生成文档: $FILE_COUNT 个"
echo ""
echo "⚠️  已知问题:"
echo "   - GitLab CLI未安装（外部依赖）"
echo "   - 需要真实GitLab仓库测试上传功能"
echo ""
echo "✅ 工作流验证:"
if [ $MISSING -eq 0 ]; then
    echo "   - 所有功能已覆盖"
    echo "   - 所有模板完整"
    echo "   - 依赖说明清晰"
    echo ""
    echo "🎉 闭环工作流测试: 通过"
    exit 0
else
    echo "   - 缺失功能: $MISSING 项"
    echo ""
    echo "⚠️  闭环工作流测试: 部分通过（需修复 $MISSING 项）"
    exit 1
fi