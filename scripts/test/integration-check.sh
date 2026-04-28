#!/bin/bash
# GitLab CLI技能集成检查脚本
# 验证所有document技能是否正确集成了GitLab CLI脚本库

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# 检查项计数器
TOTAL_CHECKS=0
PASS_CHECKS=0
FAIL_CHECKS=0

# 检查结果记录
check_result() {
    local check_name="$1"
    local result="$2"
    local message="${3:-}"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✅ PASS${NC} - $check_name"
        PASS_CHECKS=$((PASS_CHECKS + 1))
    else
        echo -e "${RED}❌ FAIL${NC} - $check_name"
        if [ -n "$message" ]; then
            echo "  $message"
        fi
        FAIL_CHECKS=$((FAIL_CHECKS + 1))
    fi
}

# 打印总结
print_summary() {
    echo ""
    echo "="*60
    echo "GitLab CLI技能集成检查总结"
    echo "="*60
    echo "总检查项: $TOTAL_CHECKS"
    echo -e "${GREEN}通过: $PASS_CHECKS${NC}"
    echo -e "${RED}失败: $FAIL_CHECKS${NC}"

    if [ $FAIL_CHECKS -eq 0 ]; then
        echo -e "${GREEN}✅ 所有检查通过${NC}"
        return 0
    else
        echo -e "${RED}❌ 发现集成问题${NC}"
        return 1
    fi
}

# 检查1: 脚本库文件存在性
check_script_library() {
    echo ""
    echo "检查1: 脚本库文件存在性"
    echo "-"*40

    local scripts=(
        "scripts/gitlab/common.sh"
        "scripts/gitlab/auth.sh"
        "scripts/gitlab/wiki.sh"
        "scripts/document/init.sh"
        "scripts/document/document-pm-wrapper.sh"
        "scripts/document/document-dev-wrapper.sh"
        "scripts/document/document-test-wrapper.sh"
        "scripts/document/document-overview-wrapper.sh"
        "scripts/document/document-compound-wrapper.sh"
    )

    for script in "${scripts[@]}"; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            check_result "脚本文件: $script" "PASS"
        else
            check_result "脚本文件: $script" "FAIL" "文件不存在或不可执行"
        fi
    done
}

# 检查2: 技能文档集成完整性
check_skill_integration() {
    echo ""
    echo "检查2: 技能文档集成完整性"
    echo "-"*40

    local skills=(
        "document-init"
        "document-pm"
        "document-dev"
        "document-test"
        "document-overview"
        "document-compound"
    )

    for skill in "${skills[@]}"; do
        local skill_file="skills/$skill/SKILL.md"

        if [ ! -f "$skill_file" ]; then
            check_result "技能文件: $skill" "FAIL" "技能文件不存在"
            continue
        fi

        # 检查是否包含脚本库章节
        if grep -q "脚本库集成使用" "$skill_file"; then
            check_result "脚本库章节: $skill" "PASS"
        else
            check_result "脚本库章节: $skill" "FAIL" "缺少脚本库集成章节"
        fi

        # 检查是否引用wrapper脚本
        if [[ "$skill" == "document-init" ]]; then
            if grep -q "init.sh" "$skill_file"; then
                check_result "wrapper引用: $skill" "PASS"
            else
                check_result "wrapper引用: $skill" "FAIL" "未引用init.sh"
            fi
        else
            local wrapper_name="document-${skill#document-}-wrapper.sh"
            if grep -q "$wrapper_name" "$skill_file"; then
                check_result "wrapper引用: $skill" "PASS"
            else
                check_result "wrapper引用: $skill" "FAIL" "未引用$wrapper_name"
            fi
        fi

        # 检查是否引用脚本库函数
        if grep -q "check_glab_installed\|check_auth_status" "$skill_file"; then
            check_result "函数引用: $skill" "PASS"
        else
            check_result "函数引用: $skill" "FAIL" "未引用脚本库核心函数"
        fi
    done
}

# 检查3: 脚本库函数完整性
check_library_functions() {
    echo ""
    echo "检查3: 脚本库函数完整性"
    echo "-"*40

    # 检查common.sh函数
    local common_functions=(
        "check_glab_installed"
        "check_auth_status"
        "normalize_repo_path"
        "check_network"
        "read_config"
        "write_config"
    )

    for func in "${common_functions[@]}"; do
        if grep -q "$func()" "scripts/gitlab/common.sh"; then
            check_result "common函数: $func" "PASS"
        else
            check_result "common函数: $func" "FAIL" "函数未定义"
        fi
    done

    # 检查auth.sh函数
    local auth_functions=(
        "glab_auth_interactive"
    )

    for func in "${auth_functions[@]}"; do
        if grep -q "$func()" "scripts/gitlab/auth.sh"; then
            check_result "auth函数: $func" "PASS"
        else
            check_result "auth函数: $func" "FAIL" "函数未定义"
        fi
    done

    # 检查wiki.sh函数
    local wiki_functions=(
        "wiki_create"
        "wiki_update"
        "wiki_view"
        "wiki_batch_upload"
    )

    for func in "${wiki_functions[@]}"; do
        if grep -q "$func()" "scripts/gitlab/wiki.sh"; then
            check_result "wiki函数: $func" "PASS"
        else
            check_result "wiki函数: $func" "FAIL" "函数未定义"
        fi
    done
}

# 检查4: 测试脚本可用性
check_test_scripts() {
    echo ""
    echo "检查4: 测试脚本可用性"
    echo "-"*40

    local test_script="scripts/test/test-gitlab.sh"

    if [ -f "$test_script" ] && [ -x "$test_script" ]; then
        check_result "测试脚本存在" "PASS"

        # 运行基本测试（不依赖实际GitLab环境）
        if bash "$test_script" 2>&1 | grep -q "测试总结"; then
            check_result "测试脚本基本功能" "PASS"
        else
            check_result "测试脚本基本功能" "FAIL" "测试脚本执行异常"
        fi
    else
        check_result "测试脚本存在" "FAIL" "测试脚本不存在"
    fi
}

# 检查5: 配置管理一致性
check_config_consistency() {
    echo ""
    echo "检查5: 配置管理一致性"
    echo "-"*40

    # 检查配置目录引用
    local config_dir=".sonli-spec-doc"
    local config_file="$config_dir/config.json"

    # 检查common.sh中的配置函数
    if grep -q "check_config_dir\|read_config\|write_config" "scripts/gitlab/common.sh"; then
        check_result "配置函数定义" "PASS"
    else
        check_result "配置函数定义" "FAIL" "缺少配置管理函数"
    fi

    # 检查技能文档中的配置引用
    local config_skills=("document-init" "document-pm" "document-dev" "document-test")
    for skill in "${config_skills[@]}"; do
        if grep -q "$config_dir\|$config_file" "skills/$skill/SKILL.md"; then
            check_result "配置引用: $skill" "PASS"
        else
            check_result "配置引用: $skill" "FAIL" "未引用标准配置"
        fi
    done
}

# 主检查函数
main() {
    log_info "开始GitLab CLI技能集成检查..."
    echo ""

    # 运行所有检查
    check_script_library
    check_skill_integration
    check_library_functions
    check_test_scripts
    check_config_consistency

    # 打印总结
    print_summary

    # 如果有失败，提供修复建议
    if [ $FAIL_CHECKS -gt 0 ]; then
        echo ""
        echo "修复建议:"
        echo "1. 运行测试脚本: bash scripts/test/test-gitlab.sh"
        echo "2. 检查缺失的wrapper脚本"
        echo "3. 更新技能文档中的引用"
        echo "4. 验证脚本库函数定义"
    fi
}

# 脚本执行
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    main "$@"
fi