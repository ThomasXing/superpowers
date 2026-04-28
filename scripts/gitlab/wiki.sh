#!/bin/bash
# GitLab Wiki 操作库
# 提供标准化的Wiki页面创建、更新、查看等功能

set -euo pipefail

# 加载公共库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Wiki页面创建
wiki_create() {
    local path="$1"
    local content="${2:-}"
    local title="${3:-${path##*/}}"
    local format="${4:-markdown}"

    # 参数检查
    if [ -z "$path" ]; then
        log_error "wiki_create: 路径不能为空"
        return 1
    fi

    # 如果内容为空，尝试从标准输入读取
    if [ -z "$content" ] && ! [ -t 0 ]; then
        content=$(cat)
    fi

    if [ -z "$content" ]; then
        log_error "wiki_create: 内容不能为空"
        return 1
    fi

    log_info "创建Wiki页面: $path"

    # 构建命令
    local cmd="glab repo wiki create \"$path\" --title \"$title\" --format \"$format\""

    # 如果内容来自文件，使用文件输入
    if [ -f "$content" ]; then
        cmd="$cmd --content \"\$(cat '$content')\""
    else
        # 对内容进行转义处理
        local escaped_content
        escaped_content=$(echo "$content" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
        cmd="$cmd --content \"$escaped_content\""
    fi

    # 执行命令
    if eval "$cmd"; then
        log_info "Wiki页面创建成功: $path"
        return 0
    else
        log_error "Wiki页面创建失败: $path"
        return 1
    fi
}

# Wiki页面更新
wiki_update() {
    local path="$1"
    local content="${2:-}"

    # 参数检查
    if [ -z "$path" ]; then
        log_error "wiki_update: 路径不能为空"
        return 1
    fi

    # 如果内容为空，尝试从标准输入读取
    if [ -z "$content" ] && ! [ -t 0 ]; then
        content=$(cat)
    fi

    if [ -z "$content" ]; then
        log_error "wiki_update: 内容不能为空"
        return 1
    fi

    log_info "更新Wiki页面: $path"

    # 构建命令
    local cmd="glab repo wiki update \"$path\""

    # 如果内容来自文件，使用文件输入
    if [ -f "$content" ]; then
        cmd="$cmd --content \"\$(cat '$content')\""
    else
        # 对内容进行转义处理
        local escaped_content
        escaped_content=$(echo "$content" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
        cmd="$cmd --content \"$escaped_content\""
    fi

    # 执行命令
    if eval "$cmd"; then
        log_info "Wiki页面更新成功: $path"
        return 0
    else
        log_error "Wiki页面更新失败: $path"
        return 1
    fi
}

# Wiki页面查看
wiki_view() {
    local path="$1"
    local raw="${2:-false}"

    # 参数检查
    if [ -z "$path" ]; then
        log_error "wiki_view: 路径不能为空"
        return 1
    fi

    log_info "查看Wiki页面: $path"

    # 构建命令
    local cmd="glab repo wiki view \"$path\""

    if [ "$raw" = "true" ]; then
        cmd="$cmd --raw"
    fi

    # 执行命令
    if eval "$cmd"; then
        return 0
    else
        log_error "无法查看Wiki页面: $path"
        return 1
    fi
}

# Wiki页面删除
wiki_delete() {
    local path="$1"
    local force="${2:-false}"

    # 参数检查
    if [ -z "$path" ]; then
        log_error "wiki_delete: 路径不能为空"
        return 1
    fi

    log_warn "删除Wiki页面: $path"

    # 构建命令
    local cmd="glab repo wiki delete \"$path\""

    if [ "$force" = "true" ]; then
        cmd="$cmd --yes"
    fi

    # 执行命令
    if eval "$cmd"; then
        log_info "Wiki页面删除成功: $path"
        return 0
    else
        log_error "Wiki页面删除失败: $path"
        return 1
    fi
}

# 列出Wiki页面
wiki_list() {
    local pattern="${1:-}"
    local format="${2:-simple}"

    log_info "列出Wiki页面..."

    # 构建命令
    local cmd="glab repo wiki list"

    if [ -n "$pattern" ]; then
        cmd="$cmd | grep -i \"$pattern\""
    fi

    # 执行命令
    if eval "$cmd"; then
        return 0
    else
        log_error "列出Wiki页面失败"
        return 1
    fi
}

# 批量上传目录
wiki_batch_upload() {
    local source_dir="$1"
    local target_path="$2"
    local pattern="${3:-*.md}"

    # 参数检查
    if [ ! -d "$source_dir" ]; then
        log_error "源目录不存在: $source_dir"
        return 1
    fi

    if [ -z "$target_path" ]; then
        log_error "目标路径不能为空"
        return 1
    fi

    log_info "批量上传: $source_dir/*.md -> $target_path"

    local success_count=0
    local fail_count=0

    # 遍历文件
    for file in "$source_dir"/$pattern; do
        if [ -f "$file" ]; then
            local filename
            filename=$(basename "$file")
            local wiki_path="$target_path/$filename"

            log_info "上传: $filename -> $wiki_path"

            if wiki_create "$wiki_path" "$file"; then
                success_count=$((success_count + 1))
            else
                fail_count=$((fail_count + 1))
            fi
        fi
    done

    log_info "批量上传完成: 成功 $success_count 个，失败 $fail_count 个"

    if [ $fail_count -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# 检查页面是否存在
wiki_exists() {
    local path="$1"

    # 尝试查看页面，但不输出内容
    if glab repo wiki view "$path" --raw &> /dev/null; then
        return 0  # 存在
    else
        return 1  # 不存在
    fi
}

# 创建目录结构
wiki_create_directory() {
    local base_path="$1"
    local subdirs="$2"

    log_info "创建Wiki目录结构: $base_path"

    # 创建README作为目录标记
    local readme_path="$base_path/README.md"
    local readme_content="# $base_path\n\n## 目录说明\n\n"

    # 添加子目录说明
    IFS=',' read -ra dir_array <<< "$subdirs"
    for subdir in "${dir_array[@]}"; do
        readme_content+="- $subdir/\n"
    done

    # 创建README
    if ! wiki_exists "$readme_path"; then
        wiki_create "$readme_path" "$readme_content" "目录索引"
    fi

    log_info "Wiki目录结构创建完成: $base_path"
    return 0
}

# 获取页面信息
wiki_get_info() {
    local path="$1"

    log_info "获取页面信息: $path"

    # 使用API获取详细信息
    local repo
    repo=$(read_config "gitlab.repo")
    local host
    host=$(read_config "gitlab.host" "gitlab.com")

    if [ -z "$repo" ]; then
        log_error "未配置GitLab仓库"
        return 1
    fi

    local api_url="https://$host/api/v4/projects/$(echo "$repo" | sed 's/\//%2F/g')/wikis/$(echo "$path" | sed 's/\//%2F/g')"

    if command -v curl &> /dev/null; then
        local token
        token=${GITLAB_TOKEN:-$(glab config get token 2>/dev/null || echo "")}

        if [ -n "$token" ]; then
            curl -s -H "Authorization: Bearer $token" "$api_url" | jq .
        else
            log_error "无法获取GitLab令牌"
            return 1
        fi
    else
        log_error "curl命令未安装"
        return 1
    fi
}