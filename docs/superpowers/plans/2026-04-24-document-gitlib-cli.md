Document技能GitLab CLI操作优化方案
一、问题分析
1.1 现状问题
重复代码：多个技能中重复的GitLab CLI环境检查、认证验证
维护困难：相同逻辑分散在6个独立技能中
错误处理不一致：不同技能的错误处理策略不同
缺乏标准化：路径处理、版本生成等操作未统一
1.2 重复操作识别（8类）
GitLab CLI环境检查 - 每个技能都需要验证glab安装
认证状态验证 - 每个上传操作都需要检查认证状态
Wiki路径规范化 - URL解析和路径构建重复逻辑
文档上传/更新 - 核心操作模式相同
错误处理和重试 - 网络问题处理逻辑重复
版本号生成 - PRD版本管理逻辑相似
目录结构验证 - 上传前检查逻辑重复
日志记录 - 操作审计功能分散
二、优化方案设计
2.1 核心脚本库结构

scripts/
├── gitlab/                    # GitLab核心库
│   ├── common.sh             # 公共函数：环境检查、路径处理
│   ├── auth.sh               # 认证管理：登录、验证、令牌
│   ├── wiki.sh               # Wiki操作：创建、更新、查看、删除
│   ├── utils.sh              # 工具函数：版本生成、日志、错误处理
│   ├── config.sh             # 配置管理：读取、验证、更新
│   └── README.md             # 使用文档
├── document/                 # 文档操作封装
│   ├── init.sh              # 文档库初始化
│   ├── upload.sh            # 通用上传脚本
│   ├── templates/           # 模板管理
│   └── helpers/             # 辅助脚本
└── test/                    # 测试脚本
    ├── test-gitlab.sh       # 脚本功能测试
    └── integration.sh       # 集成测试
2.2 核心函数设计
2.2.1 gitlab/common.sh

# GitLab CLI环境检查
check_glab_installed() {
    if ! command -v glab &> /dev/null; then
        echo "错误：GitLab CLI未安装"
        echo "安装命令: brew install glab"
        return 1
    fi
    return 0
}

# 认证状态检查
check_auth_status() {
    glab auth status &> /dev/null
    return $?
}

# 路径规范化
normalize_wiki_path() {
    local url="$1"
    local repo_path="${url#*://}"
    repo_path="${repo_path%.git}"
    repo_path="${repo_path%.wiki}"
    echo "$repo_path"
}

# 版本号生成
generate_version() {
    local prefix="${1:-v}"
    local date_suffix=$(date +%Y%m%d)
    local counter=1
    local version="${prefix}1.0.0"
    
    # 版本号生成逻辑
    echo "$version"
}
2.2.2 gitlab/wiki.sh

# Wiki页面创建
wiki_create() {
    local path="$1"
    local content="$2"
    local title="${3:-${path##*/}}"
    
    glab repo wiki create "$path" \
        --title "$title" \
        --content "$content" \
        --format markdown
}

# Wiki页面更新
wiki_update() {
    local path="$1"
    local content="$2"
    
    glab repo wiki update "$path" \
        --content "$content"
}

# 批量上传
wiki_batch_upload() {
    local base_dir="$1"
    local target_path="$2"
    
    for file in "$base_dir"/*.md; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            local wiki_path="$target_path/$filename"
            echo "上传: $wiki_path"
            wiki_create "$wiki_path" "$(cat "$file")"
        fi
    done
}
2.3 技能集成方式
2.3.1 技能脚本示例 (document-pm)

#!/bin/bash
# document-pm技能脚本

# 加载核心库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/gitlab/common.sh"
source "$SCRIPT_DIR/../../scripts/gitlab/wiki.sh"
source "$SCRIPT_DIR/../../scripts/gitlab/auth.sh"

# 环境检查
check_glab_installed || {
    echo "请先安装GitLab CLI"
    exit 1
}

# 认证检查
if ! check_auth_status; then
    echo "需要GitLab认证"
    glab_auth_interactive
fi

# PRD上传功能
upload_prd() {
    local prd_file="$1"
    local version="$2"
    
    # 生成Wiki路径
    local wiki_path="pm/prd/$version"
    
    # 上传PRD
    wiki_create "$wiki_path" "$(cat "$prd_file")" "PRD $version"
    
    # 更新索引
    update_prd_index "$version"
}
2.3.2 配置驱动

// .sonli-spec-doc/config.json
{
  "gitlab": {
    "host": "gitlab.com",
    "token_env": "GITLAB_TOKEN",
    "repo": "团队/wit-parking-wiki",
    "timeout": 30
  },
  "directories": {
    "prd": "pm/prd",
    "design": "dev",
    "test": "test",
    "overview": "overview.md",
    "compound": "knowledge-base/compound"
  },
  "templates": {
    "prd": "templates/prd-template.md",
    "design": "templates/design-template.md",
    "test": "templates/test-template.md"
  },
  "versioning": {
    "format": "v{MAJOR}.{MINOR}.{PATCH}",
    "auto_increment": true
  }
}
2.4 现有脚本优化策略
2.4.1 提取重复逻辑
将 gitlab-cli-usage.md 中的脚本逻辑提取：

初始化脚本 → scripts/document/init.sh
PRD上传脚本 → scripts/document/upload.sh + scripts/gitlab/wiki.sh
概览更新脚本 → scripts/document/overview.sh
2.4.2 保持向后兼容

# 兼容层：保持原有接口
legacy_document_init() {
    # 调用新的模块化脚本
    source scripts/gitlab/common.sh
    source scripts/document/init.sh
    
    document_init "$@"
}
2.4.3 错误处理标准化

# 统一错误处理
handle_gitlab_error() {
    local error_code="$1"
    local operation="$2"
    
    case $error_code in
        1) echo "认证失败：请检查GitLab令牌" ;;
        2) echo "权限不足：请检查仓库访问权限" ;;
        3) echo "网络错误：请检查网络连接" ;;
        4) echo "仓库不存在：请检查URL是否正确" ;;
        *) echo "$operation 失败 (错误码: $error_code)" ;;
    esac
    
    return $error_code
}
三、实施计划
3.1 第一阶段：核心库创建 (1-2天)
创建 scripts/gitlab/ 目录结构
实现 common.sh、auth.sh、wiki.sh 核心函数
编写单元测试 test/test-gitlab.sh
验证基本功能
3.2 第二阶段：技能集成 (2-3天)
为每个独立技能创建封装脚本
更新技能调用方式
测试集成兼容性
文档更新
3.3 第三阶段：优化完善 (1-2天)
错误处理优化
性能优化（缓存、批量操作）
监控和日志增强
最终测试验证
四、预期收益
Update Todos

分析document技能GitLab CLI操作的重复模式

识别可脚本化的重复操作（认证、上传、目录创建等）

设计脚本模块化方案（核心脚本库+技能集成）

验证脚本可行性和兼容性

创建优化方案报告
（续上报告）

4.1 可维护性提升
代码复用率：从6份重复代码减少到1份核心库，复用率提升83%
修改影响范围：GitLab CLI相关修改只需在核心库中进行，不影响技能业务逻辑
测试覆盖：核心功能可单独测试，提高测试效率
4.2 可靠性增强
错误处理统一：标准化错误处理，提高系统稳定性
认证管理集中：统一认证流程，减少认证相关错误
重试机制：统一的网络重试策略，提高上传成功率
4.3 开发效率提升
新技能开发：新技能只需关注业务逻辑，GitLab集成直接调用核心库
调试效率：核心问题集中在核心库，调试更简单
文档一致性：统一的操作接口，文档维护更简单
4.4 运维监控
统一日志：所有GitLab操作有统一的日志格式
性能监控：核心操作可添加性能监控点
审计追踪：统一的操作审计，便于安全审查
五、风险评估与缓解
5.1 兼容性风险
风险：现有技能依赖现有脚本，改动可能破坏兼容性
缓解：分阶段实施，先创建兼容层，逐步迁移
5.2 学习曲线
风险：开发人员需要学习新的脚本库使用方式
缓解：提供详细文档和示例，创建迁移指南
5.3 性能影响
风险：脚本调用层次增加可能影响性能
缓解：优化函数设计，避免不必要的函数调用
六、下一步行动计划
6.1 立即行动项
创建核心脚本库骨架


mkdir -p scripts/gitlab scripts/document scripts/test
touch scripts/gitlab/{common.sh,auth.sh,wiki.sh,utils.sh,config.sh}
实现关键函数

check_glab_installed() - GitLab CLI检查
wiki_create() - Wiki页面创建
normalize_wiki_path() - 路径规范化
创建测试脚本

scripts/test/test-gitlab.sh - 基础功能测试
scripts/test/integration.sh - 集成测试
6.2 短期目标（1周内）
完成核心库基本功能
为1-2个技能创建封装示例
验证兼容性
更新相关文档
6.3 中期目标（2-3周）
完成所有6个技能的集成
优化错误处理和重试机制
添加性能监控和日志
创建完整的测试套件
七、技术细节
7.1 配置管理设计

# 配置读取函数
read_config() {
    local config_file=".sonli-spec-doc/config.json"
    if [ -f "$config_file" ]; then
        jq -r ".$1" "$config_file" 2>/dev/null || echo ""
    fi
}

# 配置验证
validate_config() {
    local required_fields=("gitlab.host" "gitlab.repo")
    
    for field in "${required_fields[@]}"; do
        if [ -z "$(read_config "$field")" ]; then
            echo "配置缺失: $field"
            return 1
        fi
    done
    return 0
}
7.2 错误处理设计

# 错误处理框架
set -e  # 严格错误处理

# 错误处理钩子
trap 'handle_error $? $LINENO' ERR

handle_error() {
    local error_code="$1"
    local line_no="$2"
    
    echo "错误发生在第 $line_no 行，错误码: $error_code"
    
    # 根据错误类型处理
    case $error_code in
        126) echo "权限错误：脚本不可执行" ;;
        127) echo "命令未找到：检查依赖" ;;
        *)   echo "未知错误" ;;
    esac
    
    # 清理资源
    cleanup_resources
    
    exit $error_code
}
7.3 性能优化设计

# 缓存机制
CACHE_DIR=".sonli-spec-doc/cache"
mkdir -p "$CACHE_DIR"

# 缓存认证状态
cache_auth_status() {
    local cache_file="$CACHE_DIR/auth_status"
    local cache_ttl=300  # 5分钟
    
    if [ -f "$cache_file" ]; then
        local cache_time=$(stat -f %m "$cache_file")
        local current_time=$(date +%s)
        
        if [ $((current_time - cache_time)) -lt $cache_ttl ]; then
            cat "$cache_file"
            return 0
        fi
    fi
    
    # 重新检查并缓存
    glab auth status > "$cache_file"
    cat "$cache_file"
}
八、结论
[🟠 阿里味] 底层逻辑清晰：通过脚本模块化解决重复代码问题。抓手明确：创建5个核心脚本模块。闭环完整：从分析到设计到实施计划。

优化方案价值：

代码质量：消除重复，提高可维护性
开发效率：新技能开发更快，关注业务逻辑
系统可靠性：统一错误处理，提高稳定性
运维监控：统一日志和监控，便于问题排查
实施建议：

采用渐进式实施，先创建核心库，逐步迁移技能
保持向后兼容，确保现有功能不受影响
加强测试验证，确保每个阶段的质量
最终交付： 一个标准化、可复用、易维护的GitLab CLI脚本库，提升整个document技能体系的开发效率和运行稳定性。