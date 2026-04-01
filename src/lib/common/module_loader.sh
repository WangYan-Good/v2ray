#!/bin/bash
# module_loader.sh - 模块加载器
# 实现模块依赖解析、加载和循环依赖检测

# =============================================================================
# 模块加载器配置
# =============================================================================

# 模块依赖字典（关联数组）
declare -A MODULE_DEPENDS
declare -A MODULE_PROVIDES
declare -A MODULE_LOADED

# 模块搜索路径
MODULE_SEARCH_PATH=()

# =============================================================================#
# 内部辅助函数
# =============================================================================#

##
## 获取文件名（不带路径）
## @param: filepath 文件完整路径
## @return: 文件名
##
_get_filename() {
    local filepath="$1"
    echo "${filepath##*/}"
}

##
## 获取文件名（不带扩展名）
## @param: filename 文件名
## @return: 不带扩展名的文件名
##
_get_basename() {
    local filename="$1"
    echo "${filename%.*}"
}

##
## 检查模块是否已加载
## @param: module_name 模块名
## @return: 0 已加载, 1 未加载
##
_is_module_loaded() {
    local module_name="$1"
    [[ "${MODULE_LOADED[$module_name]}" == "true" ]]
}

##
## 标记模块为已加载
## @param: module_name 模块名
##
_mark_module_loaded() {
    local module_name="$1"
    MODULE_LOADED[$module_name]="true"
}

# =============================================================================#
# 依赖解析
# =============================================================================#

##
## 解析模块依赖声明
## 读取模块文件顶部的 DEPENDS 声明
## @param: module_path 模块文件路径
## @return: 将依赖列表存储到 MODULE_DEPENDS 数组
##
parse_module_dependencies() {
    local module_path="$1"
    local module_name="$(_get_basename "$(_get_filename "$module_path")")"
    
    # 检查文件是否存在
    if [[ ! -f "$module_path" ]]; then
        echo "ERROR: Module file not found: $module_path" >&2
        return 1
    fi
    
    # 读取文件顶部的 DEPENDS 声明
    local depends_line
    depends_line=$(head -n 10 "$module_path" | grep -E "^# DEPENDS:" | head -1)
    
    if [[ -n "$depends_line" ]]; then
        # 提取依赖列表（去掉 "# DEPENDS:" 前缀）
        local deps="${depends_line#*DEPENDS:}"
        # 分割依赖项
        local -a dep_array
        IFS=' ' read -ra dep_array <<< "$deps"
        
        # 存储依赖列表
        MODULE_DEPENDS[$module_name]="${dep_array[*]}"
        
        # 解析 PROVIDES 声明
        local provides_line
        provides_line=$(head -n 10 "$module_path" | grep -E "^# PROVIDES:" | head -1)
        if [[ -n "$provides_line" ]]; then
            local provides="${provides_line#*PROVIDES:}"
            MODULE_PROVIDES[$module_name]="$provides"
        else
            MODULE_PROVIDES[$module_name]="$module_name"
        fi
        
        return 0
    else
        # 没有 DEPENDS 声明，使用默认值
        MODULE_DEPENDS[$module_name]=""
        MODULE_PROVIDES[$module_name]="$module_name"
        return 0
    fi
}

##
## 解析所有模块的依赖
## @param: module_dir 模块目录
## @param: module_type 模块类型（可选，默认为空）
## @return: 解析所有模块的依赖信息
##
parse_all_dependencies() {
    local module_dir="$1"
    local module_type="${2:-}"
    local -a all_modules=()
    
    # 收集所有 .sh 文件
    while IFS= read -r -d '' file; do
        all_modules+=("$file")
    done < <(find "$module_dir" -name "*.sh" -type f -print0 2>/dev/null)
    
    # 解析每个模块的依赖
    local status=0
    for module_file in "${all_modules[@]}"; do
        if ! parse_module_dependencies "$module_file"; then
            status=1
        fi
    done
    
    return $status
}

# =============================================================================#
# 循环依赖检测
# =============================================================================#

# 当前依赖路径（用于检测循环依赖）
declare -a DEPENDENCY_PATH

##
## 检查是否存在循环依赖
## @param: module_name 模块名
## @return: 0 无循环依赖, 1 存在循环依赖
##
check_circular_dependency() {
    local module_name="$1"
    
    # 检查模块名是否已在依赖路径中
    for dep in "${DEPENDENCY_PATH[@]}"; do
        if [[ "$dep" == "$module_name" ]]; then
            # 构建循环依赖链
            local chain=""
            for d in "${DEPENDENCY_PATH[@]}"; do
                chain+="$d -> "
            done
            chain+="$module_name"
            echo "ERROR: Circular dependency detected: $chain" >&2
            return 1
        fi
    done
    
    return 0
}

##
## 添加模块到依赖路径
## @param: module_name 模块名
##
push_dependency_path() {
    local module_name="$1"
    DEPENDENCY_PATH+=("$module_name")
}

##
## 从依赖路径移除模块
##
pop_dependency_path() {
    unset 'DEPENDENCY_PATH[-1]'
}

# =============================================================================#
# 模块加载
# =============================================================================#

##
## 加载单个模块
## @param: module_name 模块名（不带扩展名）
## @param: module_dir 模块目录
## @return: 0 加载成功, 1 加载失败
##
load_single_module() {
    local module_name="$1"
    local module_dir="$2"
    local module_file="$module_dir/${module_name}.sh"
    
    # 检查模块是否已加载
    if _is_module_loaded "$module_name"; then
        return 0
    fi
    
    # 检查文件是否存在
    if [[ ! -f "$module_file" ]]; then
        echo "ERROR: Module file not found: $module_file" >&2
        return 1
    fi
    
    # 检查循环依赖
    if ! check_circular_dependency "$module_name"; then
        return 1
    fi
    
    # 将模块添加到依赖路径
    push_dependency_path "$module_name"
    
    # 加载依赖
    local deps="${MODULE_DEPENDS[$module_name]}"
    if [[ -n "$deps" ]]; then
        for dep in $deps; do
            local depbasename="$(_get_basename "$dep")"
            # 确保依赖模块被加载
            if ! load_single_module "$depbasename" "$module_dir"; then
                echo "ERROR: Failed to load dependency: $dep" >&2
                pop_dependency_path
                return 1
            fi
        done
    fi
    
    # 加载模块文件
    echo "Loading module: $module_name"
    # shellcheck source=/dev/null
    if ! source "$module_file"; then
        echo "ERROR: Failed to source module: $module_file" >&2
        pop_dependency_path
        return 1
    fi
    
    # 标记模块为已加载
    _mark_module_loaded "$module_name"
    
    # 从依赖路径移除
    pop_dependency_path
    
    return 0
}

##
## 加载多个模块
## @param: module_names 模块名列表（空格分隔）
## @param: module_dir 模块目录
## @return: 加载所有模块
##
load_modules() {
    local module_dir="$1"
    shift
    local -a module_names=("$@")
    
    local status=0
    for module_name in "${module_names[@]}"; do
        if ! load_single_module "$module_name" "$module_dir"; then
            status=1
        fi
    done
    
    return $status
}

# =============================================================================#
# 模块系统初始化
# =============================================================================#

##
## 初始化模块加载器
## @param: search_paths 搜索路径列表（冒号分隔）
## @return: 初始化模块加载器
##
init_module_loader() {
    local search_paths="$1"
    
    # 解析搜索路径
    IFS=':' read -ra MODULE_SEARCH_PATH <<< "$search_paths"
    
    # 解析所有模块的依赖
    for search_path in "${MODULE_SEARCH_PATH[@]}"; do
        if [[ -d "$search_path" ]]; then
            echo "Parsing dependencies in: $search_path"
            parse_all_dependencies "$search_path"
        else
            echo "WARNING: Module search path not found: $search_path" >&2
        fi
    done
    
    return 0
}

##
## 注册模块目录
## @param: module_dir 模块目录
## @return: 0 成功, 1 失败
##
register_module_directory() {
    local module_dir="$1"
    
    if [[ ! -d "$module_dir" ]]; then
        echo "ERROR: Module directory not found: $module_dir" >&2
        return 1
    fi
    
    MODULE_SEARCH_PATH+=("$module_dir")
    
    # 解析该目录下的依赖
    parse_all_dependencies "$module_dir"
    
    return 0
}

# =============================================================================#
# 高级功能
# =============================================================================#

##
## 获取模块的依赖列表
## @param: module_name 模块名
## @return: 依赖列表（空格分隔）
##
get_module_dependencies() {
    local module_name="$1"
    echo "${MODULE_DEPENDS[$module_name]:-}"
}

##
## 获取模块提供的功能
## @param: module_name 模块名
## @return: 提供的功能名
##
get_module_provides() {
    local module_name="$1"
    echo "${MODULE_PROVIDES[$module_name]:-$module_name}"
}

##
## 检查模块是否已加载
## @param: module_name 模块名
## @return: 0 已加载, 1 未加载
##
check_module_loaded() {
    local module_name="$1"
    _is_module_loaded "$module_name"
}

##
## 获取已加载模块列表
## @return: 已加载模块列表
##
get_loaded_modules() {
    for module in "${!MODULE_LOADED[@]}"; do
        if [[ "${MODULE_LOADED[$module]}" == "true" ]]; then
            echo "$module"
        fi
    done
}

##
## 查找模块路径
## @param: module_name 模块名（不带扩展名）
## @param: base_dir 模块基础目录（默认为 $IS_SH_DIR/lib）
## @return: 模块文件完整路径
##
find_module_path() {
    local module_name="$1"
    local base_dir="${2:-$IS_SH_DIR/lib}"
    local module_file="$base_dir/${module_name}.sh"
    
    if [[ -f "$module_file" ]]; then
        echo "$module_file"
        return 0
    fi
    
    # 在 MODULE_SEARCH_PATH 中查找
    local search_path
    for search_path in "${MODULE_SEARCH_PATH[@]}"; do
        if [[ -f "$search_path/${module_name}.sh" ]]; then
            echo "$search_path/${module_name}.sh"
            return 0
        fi
    done
    
    # 在 base_dir 的子目录中查找
    if [[ -d "$base_dir" ]]; then
        local subdir
        for subdir in "$base_dir"/*; do
            if [[ -d "$subdir" ]] && [[ -f "$subdir/${module_name}.sh" ]]; then
                echo "$subdir/${module_name}.sh"
                return 0
            fi
        done
    fi
    
    return 1
}

##
## 安全加载单个模块（支持依赖解析和错误处理）
## @param: module_name 模块名（不带扩展名）
## @param: base_dir 模块基础目录
## @return: 0 加载成功, 非0 加载失败
##
safe_load_module() {
    local module_name="$1"
    local base_dir="${2:-$IS_SH_DIR/lib}"
    
    # 检查是否已加载
    if _is_module_loaded "$module_name"; then
        return 0
    fi
    
    # 构建模块路径
    local module_path
    module_path=$(find_module_path "$module_name" "$base_dir")
    
    if [[ -z "$module_path" ]] || [[ ! -f "$module_path" ]]; then
        log_error "Module '$module_name' not found"
        return $ERR_MODULE_NOT_FOUND
    fi
    
    # 解析并加载依赖
    local dependencies
    dependencies=$(parse_module_dependencies "$module_path")
    
    for dep in $dependencies; do
        if ! _is_module_loaded "$dep"; then
            if ! safe_load_module "$dep" "$base_dir"; then
                log_error "Failed to load dependency '$dep' for module '$module_name'"
                return $ERR_DEPENDENCY
            fi
        fi
    done
    
    # 加载当前模块
    if ! . "$module_path"; then
        log_error "Failed to load module '$module_name'"
        return $ERR_MODULE_LOAD
    fi
    
    # 标记模块已加载
    _mark_module_loaded "$module_name"
    
    return 0
}

# =============================================================================#
# 示例和测试
# =============================================================================#

##
## 运行模块加载器自测试
##
module_loader_test() {
    echo "=== Module Loader Self-Test ==="
    
    # 创建测试环境
    local test_dir="/tmp/module_loader_test_$$"
    mkdir -p "$test_dir"
    
    # 创建测试模块
    cat > "$test_dir/a.sh" << 'EOF'
#!/bin/bash
# DEPENDS: b.sh c.sh
# PROVIDES: a
echo "Loaded module: a"
EOF
    
    cat > "$test_dir/b.sh" << 'EOF'
#!/bin/bash
# DEPENDS: c.sh
# PROVIDES: b
echo "Loaded module: b"
EOF
    
    cat > "$test_dir/c.sh" << 'EOF'
#!/bin/bash
# PROVIDES: c
echo "Loaded module: c"
EOF
    
    # 初始化模块加载器
    register_module_directory "$test_dir"
    
    # 测试模块加载
    echo "Loading modules: a b c"
    load_modules "$test_dir" a b c
    
    # 清理测试环境
    rm -rf "$test_dir"
    
    echo "=== Test Complete ==="
}

# =============================================================================#
# 全局初始化
# =============================================================================#

# 自动初始化模块加载器
_init_module_loader() {
    # 初始化已加载模块列表
    if ! declare -p MODULE_LOADED &>/dev/null || [[ $(declare -p MODULE_LOADED) != *"declare -A"* ]]; then
        declare -gA MODULE_LOADED=()
    else
        MODULE_LOADED=()
    fi
    
    # 确保其他关联数组也被正确初始化
    if ! declare -p MODULE_DEPENDS &>/dev/null || [[ $(declare -p MODULE_DEPENDS) != *"declare -A"* ]]; then
        declare -gA MODULE_DEPENDS=()
    fi
}

# 修改 _is_module_loaded 函数
_is_module_loaded() {
    local module_name="$1"
    if ! declare -p MODULE_LOADED &>/dev/null || [[ $(declare -p MODULE_LOADED) != *"declare -A"* ]]; then
        return 1
    fi
    [[ "${MODULE_LOADED[$module_name]+isset}" == "isset" ]] && [[ "${MODULE_LOADED[$module_name]}" == "true" ]]
}

# 修改 _mark_module_loaded 函数
_mark_module_loaded() {
    local module_name="$1"
    if ! declare -p MODULE_LOADED &>/dev/null || [[ $(declare -p MODULE_LOADED) != *"declare -A"* ]]; then
        declare -gA MODULE_LOADED=()
    fi
    MODULE_LOADED[$module_name]="true"
}

# 执行全局初始化
_init_module_loader
