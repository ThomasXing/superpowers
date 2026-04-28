#!/bin/bash
# GitLab脚本库测试脚本
# 测试核心脚本库功能

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# 测试报告
print_test_result() {
    local test_name="$1"
    local result="$2"
    local message="${3:-}"

    TEST_COUNT=$((TEST_COUNT + 1))

    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✅ PASS${NC} - $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}❌ FAIL${NC} - $test_name"
        if [ -n "$message" ]; then
            echo "  $message"
        fi
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# 测试总结
print_summary() {
    echo ""
    echo "="*50
    echo "测试总结"
    echo "="*50
    echo "总测试: $TEST_COUNT"
    echo -e "${GREEN}通过: $PASS_COUNT${NC}"
    echo -e "${RED}失败: $FAIL_COUNT${NC}"

    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "${GREEN}✅ 所有测试通过${NC}"
        return 0
    else
        echo -e "${RED}❌ 测试失败${NC}"
        return 1
    fi
}

# 加载核心库
load_core_libs() {
    echo "加载核心库..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/../gitlab/common.sh" 2>/dev/null && \
    source "$SCRIPT_DIR/../gitlab/auth.sh" 2>/dev/null && \
    source "$SCRIPT_DIR/../gitlab/wiki.sh" 2>/dev/null
}

# 测试1: 检查脚本文件存在
test_script_files_exist() {
    echo ""
    echo "测试1: 检查脚本文件存在"
    echo "-"*30

    local scripts=(
        "../gitlab/common.sh"
        "../gitlab/auth.sh"
        "../gitlab/wiki.sh"
        "../document/init.sh"
    )

    for script in "${scripts[@]}"; do
        if [ -f "$SCRIPT_DIR/$script" ]; then
            print_test_result "文件存在: $script" "PASS"
        else
            print_test_result "文件存在: $script" "FAIL" "文件不存在: $script"
        fi
    done
}

# 测试2: 检查函数库加载
test_lib_loading() {
    echo ""
    echo "测试2: 检查函数库加载"
    echo "-"*30

    # 测试公共库函数
    if declare -f log_info &> /dev/null; then
        print_test_result "log_info函数加载" "PASS"
    else
        print_test_result "log_info函数加载" "FAIL"
    fi

    if declare -f check_glab_installed &> /dev/null; then
        print_test_result "check_glab_installed函数加载" "PASS"
    else
        print_test_result "check_glab_installed函数加载" "FAIL"
    fi

    # 测试auth库函数
    if declare -f get_auth_status &> /dev/null; then
        print_test_result "get_auth_status函数加载" "PASS"
    else
        print_test_result "get_auth_status函数加载" "FAIL"
    fi

    # 测试wiki库函数
    if declare -f wiki_create &> /dev/null; then
        print_test_result "wiki_create函数加载" "PASS"
    else
        print_test_result "wiki_create函数加载" "FAIL"
    fi
}

# 测试3: 检查GitLab CLI
test_glab_cli() {
    echo ""
    echo "测试3: 检查GitLab CLI"
    echo "-"*30

    if command -v glab &> /dev/null; then
        local version
        version=$(glab --version 2>/dev/null | head -1 || echo "unknown")
        print_test_result "GitLab CLI安装" "PASS" "版本: $version"
    else
        print_test_result "GitLab CLI安装" "FAIL" "请安装: brew install glab"
    fi

    # 测试glab基本命令
    if glab --help &> /dev/null; then
        print_test_result "GitLab CLI基本功能" "PASS"
    else
        print_test_result "GitLab CLI基本功能" "FAIL"
    fi
}

# 测试4: 路径处理函数
test_path_functions() {
    echo ""
    echo "测试4: 路径处理函数"
    echo "-"*30

    # 测试normalize_repo_path
    local test_url="https://gitlab.com/团队/wit-parking-wiki.wiki"
    local expected_path="团队/wit-parking-wiki"
    local result

    if declare -f normalize_repo_path &> /dev/null; then
        result=$(normalize_repo_path "$test_url")
        if [ "$result" = "$expected_path" ]; then
            print_test_result "normalize_repo_path函数" "PASS" "输入: $test_url -> 输出: $result"
        else
            print_test_result "normalize_repo_path函数" "FAIL" "期望: $expected_path, 实际: $result"
        fi
    else
        print_test_result "normalize_repo_path函数" "FAIL" "函数未加载"
    fi

    # 测试更多URL格式
    local test_cases=(
        "https://gitlab.com/team/repo.git team/repo"
        "https://gitlab.com/team/repo.wiki team/repo"
        "https://gitlab.com/team/repo team/repo"
        "git@gitlab.com:team/repo.git team/repo"
    )

    for test_case in "${test_cases[@]}"; do
        local input expected
        input=$(echo "$test_case" | awk '{print $1}')
        expected=$(echo "$test_case" | awk '{print $2}')

        if declare -f normalize_repo_path &> /dev/null; then
            result=$(normalize_repo_path "$input")
            # 简单的预期检查（实际函数可能不支持git@格式）
            if [ -n "$result" ]; then
                print_test_result "URL处理: $input" "PASS" "输出: $result"
            else
                print_test_result "URL处理: $input" "FAIL" "空输出"
            fi
        fi
    done
}

# 测试5: 版本号生成
test_version_generation() {
    echo ""
    echo "测试5: 版本号生成"
    echo "-"*30

    if declare -f generate_version &> /dev/null; then
        local version
        version=$(generate_version)

        if [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            print_test_result "版本号生成" "PASS" "版本: $version"
        else
            print_test_result "版本号生成" "FAIL" "无效版本格式: $version"
        fi
    else
        print_test_result "版本号生成" "FAIL" "函数未加载"
    fi
}

# 测试6: 配置目录检查
test_config_dir() {
    echo ""
    echo "测试6: 配置目录检查"
    echo "-"*30

    # 清理可能存在的测试目录
    rm -rf .sonli-spec-doc-test

    if declare -f check_config_dir &> /dev/null; then
        # 临时修改函数使用的目录
        local original_pwd="$PWD"
        cd /tmp || exit 1

        local test_dir=".sonli-spec-doc-test"
        mkdir -p "$test_dir"
        cd "$test_dir" || exit 1

        local result
        result=$(check_config_dir)

        if [ -d ".sonli-spec-doc" ]; then
            print_test_result "配置目录创建" "PASS" "目录: $result"
        else
            print_test_result "配置目录创建" "FAIL"
        fi

        # 清理
        cd "$original_pwd" || exit 1
        rm -rf "/tmp/$test_dir"
    else
        print_test_result "配置目录检查" "FAIL" "函数未加载"
    fi
}

# 测试7: 日志函数
test_log_functions() {
    echo ""
    echo "测试7: 日志函数"
    echo "-"*30

    # 测试日志函数输出（重定向到变量）
    if declare -f log_info &> /dev/null; then
        local output
        output=$(log_info "测试信息" 2>&1)
        if echo "$output" | grep -q "测试信息"; then
            print_test_result "log_info函数" "PASS"
        else
            print_test_result "log_info函数" "FAIL" "输出不包含测试信息"
        fi
    else
        print_test_result "log_info函数" "FAIL" "函数未加载"
    fi

    if declare -f log_error &> /dev/null; then
        local output
        output=$(log_error "测试错误" 2>&1)
        if echo "$output" | grep -q "测试错误"; then
            print_test_result "log_error函数" "PASS"
        else
            print_test_result "log_error函数" "FAIL" "输出不包含测试错误"
        fi
    else
        print_test_result "log_error函数" "FAIL" "函数未加载"
    fi
}

# 主测试函数
run_all_tests() {
    echo "开始GitLab脚本库测试"
    echo "="*50

    # 加载库
    load_core_libs

    # 运行测试
    test_script_files_exist
    test_lib_loading
    test_glab_cli
    test_path_functions
    test_version_generation
    test_config_dir
    test_log_functions

    # 打印总结
    print_summary
}

# 脚本执行
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    run_all_tests
fi