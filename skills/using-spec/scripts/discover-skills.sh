#!/bin/bash
# using-spec技能发现脚本
# 此脚本由using-spec技能使用，用于动态发现项目中的可用技能

set -euo pipefail

echo "=== Qoder IDE 技能发现工具 ==="
echo "扫描时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 获取当前目录
CURRENT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$CURRENT_DIR")"

# 检测Qoder IDE环境
if [ ! -d ".qoder" ]; then
    echo "❌ 错误：当前目录不是Qoder IDE项目"
    echo "请确保在Qoder IDE项目根目录中运行此脚本"
    exit 1
fi

echo "✅ 检测到Qoder IDE项目: $PROJECT_NAME"
echo ""

# 通用技能扫描函数 - 结果存入 _SCAN_COUNT 全局变量
_SCAN_COUNT=0
scan_skills_in_dir() {
    local dir="$1"
    _SCAN_COUNT=0
    if [ -d "$dir" ]; then
        while IFS= read -r skill_dir; do
            skill_name="$(basename "$skill_dir")"
            skill_file="$skill_dir/SKILL.md"

            # 检查文件是否存在，处理符号链接情况
            skill_file_to_check="$skill_file"
            if [ -L "$skill_dir" ]; then
                real_path=$(readlink -f "$skill_dir" 2>/dev/null || echo "$skill_dir")
                skill_file_to_check="$real_path/SKILL.md"
            fi

            if [ -f "$skill_file_to_check" ]; then
                skill_metadata=$(grep -E "^(name|description):" "$skill_file_to_check" | head -2)
                skill_name_clean=$(echo "$skill_metadata" | grep "name:" | sed 's/name: //')
                skill_desc=$(echo "$skill_metadata" | grep "description:" | sed 's/description: //')

                # 如果没有 name 字段，使用目录名
                if [ -z "$skill_name_clean" ]; then
                    skill_name_clean="$skill_name"
                fi

                echo "🔹 $skill_name_clean"
                if [ -n "$skill_desc" ]; then
                    echo "   描述: $skill_desc"
                fi
                echo "   路径: $skill_dir"
                echo ""

                _SCAN_COUNT=$((_SCAN_COUNT + 1))
            fi
        done < <(find "$dir" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) 2>/dev/null | sort)
    fi
}

# 发现根目录 superpowers 技能
ROOT_SKILLS_FOUND=0
if [ -d "skills" ]; then
    echo "📁 Superpowers 核心技能 (skills/):"
    echo "--------------------------------"
    scan_skills_in_dir "skills"
    ROOT_SKILLS_FOUND=$_SCAN_COUNT
    if [ "$ROOT_SKILLS_FOUND" -eq 0 ]; then
        echo "   (未发现核心技能)"
    fi
    echo ""
fi

# 发现当前项目技能
echo "📁 项目自定义技能 (.qoder/skills/):"
echo "--------------------------------"

scan_skills_in_dir ".qoder/skills"
SKILLS_FOUND=$_SCAN_COUNT

if [ "$SKILLS_FOUND" -eq 0 ]; then
    echo "   (未发现项目自定义技能)"
fi

# 发现父目录共享技能
echo "📁 共享技能 (父目录):"
echo "--------------------------------"

SHARED_SKILLS_FOUND=0
PARENT_DIR="$(dirname "$CURRENT_DIR")"
while IFS= read -r qoder_dir; do
    if [ "$qoder_dir" != "$CURRENT_DIR/.qoder" ]; then
        project_name="$(basename "$(dirname "$qoder_dir")")"
        echo "   来自项目: $project_name"

        while IFS= read -r skill_dir; do
            skill_name="$(basename "$skill_dir")"
            skill_file="$skill_dir/SKILL.md"

            # 检查文件是否存在，处理符号链接情况
            skill_file_to_check="$skill_file"
            if [ -L "$skill_dir" ]; then
                # 如果是符号链接，获取实际路径
            real_path=$(readlink "$skill_dir")
            # 解析相对路径
            if [[ "$real_path" == ../* ]]; then
                # 假设所有superpowers技能都在skills/目录下
                skill_name=$(basename "$real_path")
                real_path="skills/$skill_name"
            fi
            skill_file_to_check="$real_path/SKILL.md"
            fi

            if [ -f "$skill_file_to_check" ]; then
                skill_metadata=$(grep -E "^(name|description):" "$skill_file_to_check" | head -2)
                skill_name_clean=$(echo "$skill_metadata" | grep "name:" | sed 's/name: //')

                echo "      └─ $skill_name_clean"
                SHARED_SKILLS_FOUND=$((SHARED_SKILLS_FOUND + 1))
            fi
        done < <(find "$qoder_dir/skills" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) 2>/dev/null 2>/dev/null)
    fi
done < <(find "$PARENT_DIR" -name ".qoder" -type d 2>/dev/null)

if [ "$SHARED_SKILLS_FOUND" -eq 0 ]; then
    echo "   (未发现共享技能)"
fi

# 技能使用统计
echo ""
echo "📊 技能统计:"
echo "--------------------------------"
echo "Superpowers核心技能: $ROOT_SKILLS_FOUND 个"
echo "项目自定义技能: $SKILLS_FOUND 个"
echo "共享技能: $SHARED_SKILLS_FOUND 个"
TOTAL_SKILLS=$((ROOT_SKILLS_FOUND + SKILLS_FOUND + SHARED_SKILLS_FOUND))
echo "总计: $TOTAL_SKILLS 个可用技能"

# 生成技能使用建议
echo ""
echo "💡 使用建议:"
echo "--------------------------------"
if [ $SKILLS_FOUND -gt 0 ]; then
    echo "1. 项目特定技能优先使用"
    echo "2. 使用命令调用: qoder skill <技能名称>"
    echo "3. 查看技能详情: cat .qoder/skills/<技能名称>/SKILL.md"
fi

if [ $SHARED_SKILLS_FOUND -gt 0 ]; then
    echo "4. 共享技能需要确认项目兼容性"
fi

# 生成技能快速参考
echo ""
echo "🚀 快速开始:"
echo "--------------------------------"
echo "要使用某个技能，请查看其SKILL.md文件获取详细使用方法。"

# 记录使用日志
LOG_FILE=".qoder/skills-usage.log"
mkdir -p "$(dirname "$LOG_FILE")"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 技能发现执行 - 发现${ROOT_SKILLS_FOUND}核心技能 + ${SKILLS_FOUND}项目技能 + ${SHARED_SKILLS_FOUND}共享技能" >> "$LOG_FILE" 2>/dev/null

exit 0