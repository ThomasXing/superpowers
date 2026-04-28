#!/bin/bash
# document技能拆分测试脚本
# 验证6个独立技能的创建和基本功能

set -e

echo "========================================="
echo "Document技能拆分验证测试"
echo "========================================="

# 检查目录是否存在
echo "1. 检查独立技能目录..."
SKILLS=("document-init" "document-pm" "document-dev" "document-test" "document-overview" "document-compound")

for skill in "${SKILLS[@]}"; do
    if [ -d "$skill" ]; then
        echo "  ✅ $skill 目录存在"

        # 检查SKILL.md文件
        if [ -f "$skill/SKILL.md" ]; then
            echo "    ✅ $skill/SKILL.md 文件存在"

            # 检查文件内容
            if head -1 "$skill/SKILL.md" | grep -q "---"; then
                echo "    ✅ $skill/SKILL.md 格式正确（YAML frontmatter）"
            else
                echo "    ⚠️  $skill/SKILL.md 格式可能不正确"
            fi
        else
            echo "    ❌ $skill/SKILL.md 文件不存在"
        fi
    else
        echo "  ❌ $skill 目录不存在"
    fi
done

echo ""
echo "2. 检查原document技能状态..."
if [ -f "document/SKILL.md" ]; then
    echo "  ✅ 原document/SKILL.md 文件存在"

    # 检查是否为路由层
    if grep -q "路由层" "document/SKILL.md"; then
        echo "    ✅ 已转换为路由层配置"
    else
        echo "    ⚠️  可能未正确转换为路由层"
    fi

    # 检查备份文件
    if [ -f "document/SKILL.md.backup.split" ]; then
        echo "    ✅ 拆分备份文件存在"
    fi
else
    echo "  ❌ 原document/SKILL.md 文件不存在"
fi

echo ""
echo "3. 检查迁移文档..."
if [ -f "document/migration-guide.md" ]; then
    echo "  ✅ migration-guide.md 文档存在"

    # 检查内容完整性
    LINE_COUNT=$(wc -l < "document/migration-guide.md")
    if [ "$LINE_COUNT" -gt 50 ]; then
        echo "    ✅ 迁移文档内容完整（$LINE_COUNT 行）"
    else
        echo "    ⚠️  迁移文档可能内容不足"
    fi
else
    echo "  ❌ migration-guide.md 文档不存在"
fi

echo ""
echo "4. 检查模板文件..."
if [ -d "document/templates" ]; then
    TEMPLATE_FILES=$(ls document/templates/*.md 2>/dev/null | wc -l)
    echo "  ✅ templates目录存在，包含 $TEMPLATE_FILES 个模板文件"

    # 列出关键模板
    for template in "prd-template.md" "design-spec-template.md" "test-case-template.md" "overview-template.md"; do
        if [ -f "document/templates/$template" ]; then
            echo "    ✅ $template 存在"
        else
            echo "    ⚠️  $template 缺失"
        fi
    done
else
    echo "  ❌ templates目录不存在"
fi

echo ""
echo "5. 检查测试脚本..."
if [ -f "document/test-skill.sh" ]; then
    echo "  ✅ test-skill.sh 测试脚本存在"
    if [ -x "document/test-skill.sh" ]; then
        echo "    ✅ 测试脚本可执行"
    else
        echo "    ⚠️  测试脚本不可执行"
    fi
else
    echo "  ⚠️  test-skill.sh 测试脚本不存在"
fi

echo ""
echo "========================================="
echo "测试总结"
echo "========================================="

# 计算通过率
TOTAL_CHECKS=0
PASS_CHECKS=0

# 重新遍历计算
for skill in "${SKILLS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 2))  # 目录和文件
    if [ -d "$skill" ]; then
        PASS_CHECKS=$((PASS_CHECKS + 1))
    fi
    if [ -f "$skill/SKILL.md" ]; then
        PASS_CHECKS=$((PASS_CHECKS + 1))
    fi
done

# 其他检查
OTHER_CHECKS=6  # document目录、备份、迁移文档、模板、测试脚本等
TOTAL_CHECKS=$((TOTAL_CHECKS + OTHER_CHECKS))

if [ -f "document/SKILL.md" ]; then PASS_CHECKS=$((PASS_CHECKS + 1)); fi
if [ -f "document/SKILL.md.backup.split" ]; then PASS_CHECKS=$((PASS_CHECKS + 1)); fi
if [ -f "document/migration-guide.md" ]; then PASS_CHECKS=$((PASS_CHECKS + 1)); fi
if [ -d "document/templates" ]; then PASS_CHECKS=$((PASS_CHECKS + 1)); fi
if [ -f "document/test-skill.sh" ]; then PASS_CHECKS=$((PASS_CHECKS + 1)); fi
if [ -x "document/test-skill.sh" ]; then PASS_CHECKS=$((PASS_CHECKS + 1)); fi

PASS_RATE=$((PASS_CHECKS * 100 / TOTAL_CHECKS))

echo "总检查项: $TOTAL_CHECKS"
echo "通过项: $PASS_CHECKS"
echo "通过率: $PASS_RATE%"

if [ "$PASS_RATE" -ge 90 ]; then
    echo "✅ 拆分验证通过！"
    echo ""
    echo "下一步："
    echo "1. 完善各独立技能的详细功能"
    echo "2. 更新测试脚本以适应拆分"
    echo "3. 验证技能间协作"
    echo "4. 进行集成测试"
elif [ "$PASS_RATE" -ge 70 ]; then
    echo "⚠️  拆分基本完成，需要进一步完善"
else
    echo "❌ 拆分存在问题，需要修复"
fi

echo ""
echo "独立技能状态："
echo "  document-init     : GitLab Wiki仓库初始化"
echo "  document-pm       : PRD文档管理"
echo "  document-dev      : 功能设计文档管理"
echo "  document-test     : 测试用例文档管理"
echo "  document-overview : 项目概览管理"
echo "  document-compound : 开发经验总结"

echo ""
echo "使用建议："
echo "  推荐格式: /document-<子命令> <参数>"
echo "  兼容格式: /document <子命令> <参数>"

exit 0