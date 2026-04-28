#!/bin/bash
# GitLab CLI 公共函数库
# 提供GitLab CLI操作的标准化接口

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# GitLab CLI环境检查
check_glab_installed() {
    if ! command -v glab &> /dev/null; then
        log_error "GitLab CLI (glab) 未安装"
        log_info "安装命令:"
        echo "  macOS: brew install glab"
        echo "  Linux: curl -s https://gitlab.com/gitlab-org/cli/-/raw/main/scripts/install.sh | sudo sh"
        echo "  Windows: scoop install glab"
        return 1
    fi

    local glab_version
    glab_version=$(glab --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    log_info "GitLab CLI版本: $glab_version"
    return 0
}

# 认证状态检查
check_auth_status() {
    if glab auth status &> /dev/null; then
        log_info "GitLab认证正常"
        return 0
    else
        log_warn "GitLab认证需要配置"
        return 1
    fi
}

# 交互式认证
glab_auth_interactive() {
    log_info "开始GitLab交互式认证..."
    glab auth login
}

# 网络连接测试
check_network() {
    local host="${1:-gitlab.com}"
    log_info "测试网络连接到 $host..."

    if curl -s --head --connect-timeout 5 "https://$host" &> /dev/null; then
        log_info "网络连接正常"
        return 0
    else
        log_error "网络连接失败，无法访问 $host"
        return 1
    fi
}

# 路径规范化 - 将GitLab URL转换为仓库路径
normalize_repo_path() {
    local url="$1"
    local repo_path="${url#*://}"

    # 移除协议和主机部分（如果存在）
    # 先移除协议部分，保留完整路径
    # 如果路径以gitlab.com开头，移除gitlab.com/前缀
    if [[ "$repo_path" == gitlab.com/* ]]; then
        repo_path="${repo_path#gitlab.com/}"
    fi

    # 移除.git或.wiki后缀
    repo_path="${repo_path%.git}"
    repo_path="${repo_path%.wiki}"

    # 移除路径中的斜杠
    repo_path="${repo_path#/}"
    repo_path="${repo_path%/}"

    # 处理git@格式
    if [[ "$url" == git@* ]]; then
        repo_path="${url#*:}"
        repo_path="${repo_path%.git}"
        repo_path="${repo_path%.wiki}"
    fi

    echo "$repo_path"
}

# 版本号生成
generate_version() {
    local prefix="${1:-v}"
    local date_suffix=$(date +%Y%m%d)
    local counter=1

    # 尝试读取现有版本号
    local config_file=".sonli-spec-doc/config.json"
    if [ -f "$config_file" ]; then
        local last_version
        last_version=$(jq -r '.version.current // "v1.0.0"' "$config_file" 2>/dev/null || echo "v1.0.0")

        # 解析版本号
        if [[ $last_version =~ v([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
            local major="${BASH_REMATCH[1]}"
            local minor="${BASH_REMATCH[2]}"
            local patch="${BASH_REMATCH[3]}"

            # 小版本递增
            patch=$((patch + 1))
            if [ $patch -ge 10 ]; then
                patch=0
                minor=$((minor + 1))
            fi

            echo "v${major}.${minor}.${patch}"
            return 0
        fi
    fi

    # 默认版本号
    echo "v1.0.0"
}

# 配置目录检查
check_config_dir() {
    local config_dir=".sonli-spec-doc"

    if [ ! -d "$config_dir" ]; then
        log_info "创建配置目录: $config_dir"
        mkdir -p "$config_dir"
    fi

    echo "$config_dir"
}

# 读取配置
read_config() {
    local key="$1"
    local config_file=".sonli-spec-doc/config.json"
    local default_value="${2:-}"

    if [ ! -f "$config_file" ]; then
        log_warn "配置文件不存在: $config_file"
        echo "$default_value"
        return 1
    fi

    local value
    value=$(jq -r ".$key // \"$default_value\"" "$config_file" 2>/dev/null || echo "$default_value")

    if [ "$value" = "null" ]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

# 写入配置
write_config() {
    local key="$1"
    local value="$2"
    local config_file=".sonli-spec-doc/config.json"

    # 确保目录存在
    check_config_dir > /dev/null

    # 如果文件不存在，创建空JSON
    if [ ! -f "$config_file" ]; then
        echo '{}' > "$config_file"
    fi

    # 使用jq更新配置
    if command -v jq &> /dev/null; then
        jq ".$key = \"$value\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        log_info "配置更新: $key = $value"
    else
        log_warn "jq命令未安装，无法更新JSON配置"
    fi
}

# 写入 JSON 原生值（不额外加引号，用于数组等复杂类型）
write_config_json() {
    local key="$1"
    local json_value="$2"
    local config_file=".sonli-spec-doc/config.json"

    check_config_dir > /dev/null

    if [ ! -f "$config_file" ]; then
        echo '{}' > "$config_file"
    fi

    if command -v jq &> /dev/null; then
        jq ".$key = $json_value" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        log_info "配置更新: $key = $json_value"
    else
        log_warn "jq命令未安装，无法更新JSON配置"
    fi
}

# === 月度计划管理函数 ===

# 获取团队根命名空间（不带活跃计划前缀）
get_plan_root() {
    read_config "directories.root" "产品中心月度计划" || echo "产品中心月度计划"
}

# 获取当前活跃月度计划名称
get_active_plan() {
    read_config "directories.active_plan" "" || echo ""
}

# 获取完整 Wiki 路径前缀 = 根命名空间 / 活跃月度计划
# 如果未配置活跃计划，则仅返回根命名空间
get_wiki_prefix() {
    local root
    local active
    root=$(get_plan_root)
    active=$(get_active_plan)

    if [ -n "$active" ]; then
        echo "$root/$active"
    else
        echo "$root"
    fi
}

# 列出所有已注册的月度计划
list_plans() {
    local config_file=".sonli-spec-doc/config.json"
    if [ ! -f "$config_file" ]; then
        echo "[]"
        return 0
    fi

    if command -v jq &> /dev/null; then
        jq -r '.directories.plans[]? // empty' "$config_file" 2>/dev/null
    else
        log_warn "jq命令未安装，无法读取计划列表"
        echo ""
    fi
}

# 添加新的月度计划到列表（不切换）
add_plan() {
    local plan_name="$1"
    local config_file=".sonli-spec-doc/config.json"

    if [ ! -f "$config_file" ]; then
        echo '{}' > "$config_file"
    fi

    if command -v jq &> /dev/null; then
        # 如果 plans 数组不存在，初始化空数组
        local existing
        existing=$(jq -r '.directories.plans' "$config_file" 2>/dev/null)
        if [ "$existing" = "null" ] || [ -z "$existing" ]; then
            jq ".directories.plans = [\"$plan_name\"]" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        else
            # 检查是否已存在
            if jq -e ".directories.plans | index(\"$plan_name\")" "$config_file" > /dev/null 2>&1; then
                log_warn "计划 '$plan_name' 已存在，跳过添加"
                return 0
            fi
            jq ".directories.plans += [\"$plan_name\"]" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        fi
        log_info "✅ 月度计划已添加: $plan_name"
    else
        log_warn "jq命令未安装，无法更新计划列表"
        return 1
    fi
}

# 切换到指定月度计划
switch_plan() {
    local plan_name="$1"

    # 验证计划存在于列表中
    if command -v jq &> /dev/null; then
        local config_file=".sonli-spec-doc/config.json"
        if [ -f "$config_file" ]; then
            if ! jq -e ".directories.plans | index(\"$plan_name\")" "$config_file" > /dev/null 2>&1; then
                log_warn "计划 '$plan_name' 不在计划列表中，自动添加..."
                add_plan "$plan_name"
            fi
        else
            add_plan "$plan_name"
        fi
    fi

    write_config "directories.active_plan" "$plan_name"
    log_info "✅ 已切换到月度计划: $plan_name"
    log_info "当前 Wiki 路径前缀: $(get_wiki_prefix)"
}

# 配置当前活跃月度计划（首次初始化或切换时使用）
configure_active_plan() {
    local plan_name="$1"
    local is_first="${2:-true}"

    log_info "配置月度计划: $plan_name"

    # 确保根命名空间存在
    local existing_root
    existing_root=$(get_plan_root)
    if [ -z "$existing_root" ]; then
        write_config "directories.root" "产品中心月度计划"
    fi

    # 添加到计划列表
    add_plan "$plan_name"

    # 设为活跃计划
    write_config "directories.active_plan" "$plan_name"

    log_info "✅ 月度计划配置完成: $plan_name"
    log_info "Wiki 路径前缀: $(get_wiki_prefix)"
}

# 验证配置完整性
validate_config() {
    local required_fields=("gitlab.repo" "gitlab.host")
    local missing_fields=()

    for field in "${required_fields[@]}"; do
        local value
        value=$(read_config "$field")

        if [ -z "$value" ]; then
            missing_fields+=("$field")
        fi
    done

    # 验证月度计划配置
    local active_plan
    active_plan=$(get_active_plan)
    if [ -z "$active_plan" ]; then
        log_warn "未配置活跃月度计划，将使用根命名空间"
        log_info "建议运行: /document-init plan <计划名称>"
    else
        log_info "活跃月度计划: $active_plan"
    fi

    if [ ${#missing_fields[@]} -gt 0 ]; then
        log_error "配置缺失字段: ${missing_fields[*]}"
        return 1
    fi

    log_info "配置完整性检查通过"
    return 0
}

# 错误处理包装
run_with_error_handling() {
    local command="$1"
    local operation="${2:-执行命令}"

    log_info "开始: $operation"

    if eval "$command"; then
        log_info "完成: $operation"
        return 0
    else
        local error_code=$?
        log_error "失败: $operation (错误码: $error_code)"

        # 根据错误类型提供建议
        case $error_code in
            1)  log_info "建议: 检查命令语法和参数" ;;
            126) log_info "建议: 检查文件权限" ;;
            127) log_info "建议: 检查命令是否存在" ;;
            *)  log_info "建议: 查看详细错误信息" ;;
        esac

        return $error_code
    fi
}