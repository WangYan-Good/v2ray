#!/bin/bash
# rollback-arch.sh - 架构回滚脚本
# 用于将 V2Ray 从新架构回滚到旧架构

# =============================================================================
# 配置
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(dirname "$SCRIPT_DIR")"

# 新架构路径
NEW_LIB_DIR="$WORK_DIR/src/lib"
NEW_BIN_DIR="$WORK_DIR/src/bin"
NEW_COMMON_DIR="$NEW_LIB_DIR/common"
NEW_CORE_DIR="$NEW_LIB_DIR/core"
NEW_UTILS_DIR="$NEW_LIB_DIR/utils"

# 旧架构路径
OLD_SRC_DIR="$WORK_DIR/src"

# 备份目录
BACKUP_DIR="$WORK_DIR/.arch_backup_$(date +%Y%m%d_%H%M%S)"

# =============================================================================
# 颜色输出
# =============================================================================

RED='\e[31m'
GREEN='\e[92m'
YELLOW='\e[33m'
BLUE='\e[94m'
NONE='\e[0m'

_red() { echo -e "${RED}$*${NONE}"; }
_green() { echo -e "${GREEN}$*${NONE}"; }
_yellow() { echo -e "${YELLOW}$*${NONE}"; }
_blue() { echo -e "${BLUE}$*${NONE}"; }

# =============================================================================
# 辅助函数
# =============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        _red "ERROR: This script must be run as root" >&2
        exit 1
    fi
}

confirm() {
    local prompt="${1:-Are you sure?}"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi
    
    read -p "$prompt" -n 1 -r
    echo
    
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

backup_files() {
    _blue "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # 备份新架构文件
    if [[ -d "$NEW_LIB_DIR" ]]; then
        _yellow "Backing up new architecture files..."
        cp -rf "$NEW_LIB_DIR" "$BACKUP_DIR/"
    fi
    
    if [[ -d "$NEW_BIN_DIR" ]]; then
        _yellow "Backing up new bin files..."
        cp -rf "$NEW_BIN_DIR" "$BACKUP_DIR/"
    fi
}

restore_files() {
    _blue "Restoring old architecture files..."
    
    # 恢复公共模块
    if [[ -d "$BACKUP_DIR/lib/common" ]]; then
        cp -rf "$BACKUP_DIR/lib/common/init.sh" "$OLD_SRC_DIR/"
        cp -rf "$BACKUP_DIR/lib/common/log.sh" "$OLD_SRC_DIR/"
        cp -rf "$BACKUP_DIR/lib/common/error.sh" "$OLD_SRC_DIR/"
        _green "  ✓ Restored common modules"
    fi
    
    # 恢复核心模块
    if [[ -d "$BACKUP_DIR/lib/core" ]]; then
        cp -rf "$BACKUP_DIR/lib/core/core.sh" "$OLD_SRC_DIR/core/"
        cp -rf "$BACKUP_DIR/lib/core/dns.sh" "$OLD_SRC_DIR/core/"
        cp -rf "$BACKUP_DIR/lib/core/systemd.sh" "$OLD_SRC_DIR/core/"
        cp -rf "$BACKUP_DIR/lib/core/bbr.sh" "$OLD_SRC_DIR/core/"
        _green "  ✓ Restored core modules"
    fi
    
    # 恢复工具模块
    if [[ -d "$BACKUP_DIR/lib/utils" ]]; then
        cp -rf "$BACKUP_DIR/lib/utils/error_handler.sh" "$OLD_SRC_DIR/utils/"
        cp -rf "$BACKUP_DIR/lib/utils/error.sh" "$OLD_SRC_DIR/utils/"
        cp -rf "$BACKUP_DIR/lib/utils/log.sh" "$OLD_SRC_DIR/utils/"
        _green "  ✓ Restored utility modules"
    fi
}

remove_new_files() {
    _yellow "Removing new architecture files..."
    
    # 移除 lib 目录
    if [[ -d "$NEW_LIB_DIR" ]]; then
        rm -rf "$NEW_LIB_DIR"
        _green "  ✓ Removed lib directory"
    fi
    
    # 移除 bin 目录
    if [[ -d "$NEW_BIN_DIR" ]]; then
        rm -rf "$NEW_BIN_DIR"
        _green "  ✓ Removed bin directory"
    fi
    
    # 移除回退脚本
    local rollback_script="$WORK_DIR/scripts/rollback-arch.sh"
    if [[ -f "$rollback_script" ]]; then
        rm -rf "$rollback_script"
        _green "  ✓ Removed rollback script"
    fi
}

verify_rollback() {
    _blue "Verifying rollback..."
    local success=true
    
    # 检查旧架构文件是否存在
    for file in "$OLD_SRC_DIR/init.sh" "$OLD_SRC_DIR/log.sh" "$OLD_SRC_DIR/error.sh" \
                "$OLD_SRC_DIR/core/core.sh" "$OLD_SRC_DIR/core/dns.sh" "$OLD_SRC_DIR/core/systemd.sh" \
                "$OLD_SRC_DIR/core/bbr.sh" "$OLD_SRC_DIR/utils/error_handler.sh"; do
        if [[ ! -f "$file" ]]; then
            _red "  ✗ Missing file: $file" >&2
            success=false
        fi
    done
    
    # 检查新架构文件已被移除
    for dir in "$NEW_LIB_DIR" "$NEW_BIN_DIR"; do
        if [[ -d "$dir" ]]; then
            _red "  ✗ Directory still exists: $dir" >&2
            success=false
        fi
    done
    
    if [[ "$success" == "true" ]]; then
        _green "Rollback verification successful!"
        return 0
    else
        _red "Rollback verification failed!" >&2
        return 1
    fi
}

print_usage() {
    cat << EOF
V2Ray 架构回滚脚本

用法: $0 [选项]

选项:
    -y, --yes       非交互模式，自动确认
    -n, --no        非交互模式，不执行回滚
    -v, --verify    仅验证回滚状态
    -h, --help      显示帮助信息
    --status        显示当前架构状态

示例:
    $0              交互式回滚
    $0 -y           非交互式回滚
    $0 --status     显示当前架构状态

注意:
    - 回滚前会自动备份文件到 $BACKUP_DIR
    - 回滚后无法恢复，请谨慎操作
EOF
}

show_status() {
    _blue "当前架构状态："
    echo ""
    
    # 检查新架构
    if [[ -d "$NEW_LIB_DIR" && -d "$NEW_BIN_DIR" ]]; then
        _green "✓ New architecture is active"
        echo "  - lib directory: $NEW_LIB_DIR"
        echo "  - bin directory: $NEW_BIN_DIR"
    else
        _red "✗ New architecture is NOT active"
    fi
    
    # 检查旧架构
    if [[ -d "$OLD_SRC_DIR" && -f "$OLD_SRC_DIR/init.sh" ]]; then
        _green "✓ Old architecture is available"
        echo "  - src directory: $OLD_SRC_DIR"
    else
        _red "✗ Old architecture is NOT available"
    fi
    
    # 检查兼容性 stub
    if [[ -f "$WORK_DIR/scripts/v2ray.sh" ]]; then
        _green "✓ Compatibility stub exists"
        local stub_content
        stub_content=$(head -n 20 "$WORK_DIR/scripts/v2ray.sh")
        if echo "$stub_content" | grep -q "src/bin/v2ray"; then
            echo "  - Uses new entry point"
        else
            echo "  - Uses legacy entry point"
        fi
    else
        _red "✗ Compatibility stub NOT found"
    fi
}

# =============================================================================
# 主逻辑
# =============================================================================

main() {
    local interactive=true
    local action="rollback"
    local force=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes)
                force=true
                interactive=false
                shift
                ;;
            -n|--no)
                action="cancel"
                interactive=false
                shift
                ;;
            -v|--verify)
                action="verify"
                interactive=false
                shift
                ;;
            --status)
                action="status"
                interactive=false
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                _red "Unknown option: $1" >&2
                print_usage
                exit 1
                ;;
        esac
    done
    
    # 执行操作
    case "$action" in
        status)
            show_status
            exit 0
            ;;
        verify)
            verify_rollback
            exit $?
            ;;
        rollback)
            _red "========================================"
            _red "WARNING: This will rollback to old architecture"
            _red "========================================"
            echo ""
            
            # 显示当前状态
            show_status
            echo ""
            
            # 确认操作
            if [[ "$interactive" == "true" ]]; then
                if ! confirm "是否继续回滚?"; then
                    _yellow "Rollback cancelled"
                    exit 0
                fi
            fi
            
            if [[ "$force" != "true" ]]; then
                if ! confirm "确定要继续吗? 建议先备份!"; then
                    _yellow "Rollback cancelled"
                    exit 0
                fi
            fi
            
            # 执行回滚
            _blue "Starting rollback..."
            
            # 创建备份
            backup_files
            
            # 恢复旧架构文件
            restore_files
            
            # 移除新架构文件
            remove_new_files
            
            # 验证回滚
            if verify_rollback; then
                _green "========================================"
                _green "Rollback completed successfully!"
                _green "========================================"
                echo ""
                _yellow "Note: You may need to update your scripts"
                _yellow "      to use the old architecture paths."
                exit 0
            else
                _red "========================================"
                _red "Rollback completed with warnings!"
                _red "========================================"
                exit 1
            fi
            ;;
        cancel)
            _yellow "Rollback cancelled"
            exit 0
            ;;
    esac
}

# =============================================================================
# 入口点
# =============================================================================

main "$@"
