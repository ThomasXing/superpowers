#!/bin/bash
# GitLab 认证管理库
# 提供GitLab认证的标准化管理

set -euo pipefail

# 加载公共库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 获取认证状态详情
get_auth_status() {
    log_info "检查GitLab认证状态..."

    if ! command -v glab &> /dev/null; then
        log_error "GitLab CLI未安装"
        return 1
    fi

    # 尝试获取认证状态
    local status_output
    status_output=$(glab auth status 2>&1)

    if echo "$status_output" | grep -q "Logged in to"; then
        local user_info
        user_info=$(echo "$status_output" | grep "Logged in to")
        log_info "$user_info"
        return 0
    else
        log_warn "未认证或认证已过期"
        echo "$status_output"
        return 1
    fi
}

# 交互式认证流程
glab_auth_interactive() {
    log_info "开始GitLab交互式认证流程..."

    # 检查glab是否安装
    check_glab_installed || return 1

    # 显示当前状态
    get_auth_status

    echo ""
    log_info "请选择认证方式:"
    echo "1) 浏览器认证（推荐）"
    echo "2) 令牌认证"
    echo "3) 环境变量配置"
    echo "4) 退出"
    echo ""

    read -r -p "请选择 [1-4]: " auth_choice

    case $auth_choice in
        1)
            log_info "使用浏览器认证..."
            glab auth login --web
            ;;
        2)
            log_info "使用令牌认证..."
            read -r -p "请输入GitLab主机（默认: gitlab.com）: " glab_host
            glab_host=${glab_host:-gitlab.com}

            read -r -p "请输入访问令牌: " glab_token
            if [ -n "$glab_token" ]; then
                glab auth login --host "$glab_host" --token "$glab_token"
            else
                log_error "令牌不能为空"
                return 1
            fi
            ;;
        3)
            log_info "配置环境变量..."
            read -r -p "请输入GITLAB_TOKEN: " gitlab_token
            read -r -p "请输入GITLAB_HOST（默认: gitlab.com）: " gitlab_host
            gitlab_host=${gitlab_host:-gitlab.com}

            if [ -n "$gitlab_token" ]; then
                export GITLAB_TOKEN="$gitlab_token"
                export GITLAB_HOST="$gitlab_host"
                log_info "环境变量已设置"
                log_info "GITLAB_TOKEN: ${gitlab_token:0:10}..."
                log_info "GITLAB_HOST: $gitlab_host"

                # 测试认证
                if glab auth status &> /dev/null; then
                    log_info "认证成功"
                else
                    log_warn "认证测试失败，请检查令牌权限"
                fi
            else
                log_error "GITLAB_TOKEN不能为空"
                return 1
            fi
            ;;
        4)
            log_info "退出认证流程"
            return 0
            ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac

    # 验证认证结果
    if get_auth_status; then
        log_info "✅ GitLab认证成功"
        return 0
    else
        log_error "❌ GitLab认证失败"
        return 1
    fi
}

# 自动认证（尝试已有认证，失败则引导）
glab_auth_auto() {
    log_info "尝试自动认证..."

    # 首先检查环境变量
    if [ -n "${GITLAB_TOKEN:-}" ]; then
        log_info "使用环境变量GITLAB_TOKEN认证"
        export GITLAB_TOKEN="$GITLAB_TOKEN"
        export GITLAB_HOST="${GITLAB_HOST:-gitlab.com}"

        if glab auth status &> /dev/null; then
            log_info "环境变量认证成功"
            return 0
        fi
    fi

    # 检查已有的glab认证
    if get_auth_status; then
        log_info "已有认证有效"
        return 0
    fi

    # 认证失败，需要交互式认证
    log_warn "自动认证失败，需要交互式认证"
    glab_auth_interactive
}

# 配置认证到文件
save_auth_config() {
    local config_file="${1:-.sonli-spec-doc/gitlab-auth.json}"

    log_info "保存认证配置到: $config_file"

    # 确保目录存在
    mkdir -p "$(dirname "$config_file")"

    # 获取当前认证信息
    local auth_status
    auth_status=$(glab auth status 2>/dev/null || echo "{}")

    # 提取关键信息
    local host
    host=$(echo "$auth_status" | grep "Hostname:" | awk '{print $2}' || echo "")
    local user
    user=$(echo "$auth_status" | grep "Username:" | awk '{print $2}' || echo "")

    # 创建配置JSON
    local config_json="{
        \"host\": \"$host\",
        \"user\": \"$user\",
        \"configured_at\": \"$(date -Iseconds)\",
        \"auth_method\": \"glab_cli\"
    }"

    echo "$config_json" | jq . > "$config_file"

    if [ -f "$config_file" ]; then
        log_info "认证配置保存成功"
        return 0
    else
        log_error "认证配置保存失败"
        return 1
    fi
}

# 加载认证配置
load_auth_config() {
    local config_file="${1:-.sonli-spec-doc/gitlab-auth.json}"

    if [ ! -f "$config_file" ]; then
        log_warn "认证配置文件不存在: $config_file"
        return 1
    fi

    log_info "加载认证配置: $config_file"

    local host
    host=$(jq -r '.host // ""' "$config_file")
    local user
    user=$(jq -r '.user // ""' "$config_file")
    local configured_at
    configured_at=$(jq -r '.configured_at // ""' "$config_file")

    if [ -n "$host" ] && [ -n "$user" ]; then
        log_info "认证配置: $user@$host (配置于: $configured_at)"
        return 0
    else
        log_warn "认证配置不完整"
        return 1
    fi
}

# 清除认证
clear_auth() {
    log_warn "清除GitLab认证..."

    echo "这将清除所有GitLab认证信息，包括:"
    echo "1. glab CLI认证"
    echo "2. 环境变量"
    echo "3. 本地配置文件"
    echo ""

    read -r -p "确认清除？[y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # 清除glab认证
        glab auth logout --all 2>/dev/null || true

        # 清除环境变量（当前会话）
        unset GITLAB_TOKEN
        unset GITLAB_HOST

        # 删除本地配置文件
        rm -f .sonli-spec-doc/gitlab-auth.json

        log_info "认证已清除"
        return 0
    else
        log_info "取消清除操作"
        return 0
    fi
}

# 测试认证连接
test_auth_connection() {
    log_info "测试GitLab认证连接..."

    # 检查glab安装
    check_glab_installed || return 1

    # 检查认证状态
    if ! get_auth_status; then
        log_error "认证状态检查失败"
        return 1
    fi

    # 测试API连接
    log_info "测试API连接..."
    if glab api /user &> /dev/null; then
        log_info "API连接测试成功"
    else
        log_error "API连接测试失败"
        return 1
    fi

    # 测试仓库访问（如果有配置）
    local repo
    repo=$(read_config "gitlab.repo")
    if [ -n "$repo" ]; then
        log_info "测试仓库访问: $repo"
        if glab repo view "$repo" --json &> /dev/null; then
            log_info "仓库访问测试成功"
        else
            log_warn "仓库访问测试失败（可能权限不足）"
        fi
    fi

    log_info "✅ 认证连接测试完成"
    return 0
}

# 获取令牌信息
get_token_info() {
    log_info "获取令牌信息..."

    # 尝试从环境变量获取
    if [ -n "${GITLAB_TOKEN:-}" ]; then
        local token_prefix="${GITLAB_TOKEN:0:10}"
        log_info "环境变量令牌: ${token_prefix}..."
    fi

    # 尝试从glab配置获取
    if command -v glab &> /dev/null; then
        local glab_token
        glab_token=$(glab config get token 2>/dev/null || echo "")
        if [ -n "$glab_token" ]; then
            local token_prefix="${glab_token:0:10}"
            log_info "glab配置令牌: ${token_prefix}..."
        fi
    fi

    # 检查令牌权限（通过API）
    log_info "检查令牌权限..."
    if glab api /user &> /dev/null; then
        local user_info
        user_info=$(glab api /user | jq -r '.name // .username // "unknown"')
        log_info "令牌用户: $user_info"
        return 0
    else
        log_warn "无法获取令牌用户信息"
        return 1
    fi
}