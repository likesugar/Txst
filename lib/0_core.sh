#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  模块 0 · 核心
#  职责：常量 / 颜色 / 工具函数 / YAML 读写 / 瘦身 / 日志轮转
#==========================================================================

# ======================================
# 常量
# ======================================
INSTALL_DIR="$HOME/SillyTavern"
BACKUP_DIR="$HOME/SillyTavern_Backups"
LAN_FLAG="$HOME/.sillytavern_lan"
SCRIPT_PATH="$HOME/st.sh"

# ======================================
# 颜色
# ======================================
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BLUE=''; BOLD=''; NC=''
fi

# ======================================
# 基础工具函数
# ======================================
check_installed() { [ -f "$INSTALL_DIR/start.sh" ]; }
is_running()      { pgrep -f "node.*server.js" >/dev/null 2>&1; }
command_exists()  { command -v "$1" >/dev/null 2>&1; }

# ======================================
# 统一：读取 config.yaml 配置项
# 用法: read_config_key <key> [indent]
# ======================================
read_config_key() {
    local key="$1"
    local indent="${2:-0}"
    [ -f "$INSTALL_DIR/config.yaml" ] || { echo ""; return; }

    if [ "$indent" = "1" ]; then
        grep "^[[:space:]]*${key}:" "$INSTALL_DIR/config.yaml" 2>/dev/null | awk '{print $2}' | tr -d '"'
    else
        grep "^${key}:" "$INSTALL_DIR/config.yaml" 2>/dev/null | awk '{print $2}' | tr -d '"'
    fi
}

# ======================================
# 统一：设置/更新 YAML 顶层键值（不覆盖整个文件）
# 用法: set_config_key <key> <value> [indent]
#   indent=0 → 顶层键；indent=1 → 二级键（basicAuthUser 下）
# ======================================
set_config_key() {
    local key="$1"
    local value="$2"
    local indent="${3:-0}"
    local cfg="$INSTALL_DIR/config.yaml"

    touch "$cfg"

    if [ "$indent" = "1" ]; then
        if awk '
            /^basicAuthUser:/ {inblk=1; next}
            inblk && /^[^[:space:]]/ {inblk=0}
            inblk && $0 ~ "^  '"${key}"':" {found=1}
            END {exit !found}
        ' "$cfg"; then
            awk -v k="$key" -v v="$value" '
                /^basicAuthUser:/ {inblk=1; print; next}
                inblk && /^[^[:space:]]/ {inblk=0}
                inblk && $0 ~ "^  "k":" {print "  "k": "v; next}
                {print}
            ' "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
        else
            if ! grep -q "^basicAuthUser:" "$cfg" 2>/dev/null; then
                echo "basicAuthUser:" >> "$cfg"
            fi
            awk -v k="$key" -v v="$value" '
                /^basicAuthUser:/ {print; print "  "k": "v; next}
                {print}
            ' "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
        fi
    else
        if grep -q "^${key}:" "$cfg" 2>/dev/null; then
            sed -i "s|^${key}:.*|${key}: ${value}|" "$cfg"
        else
            echo "${key}: ${value}" >> "$cfg"
        fi
    fi
}

# ======================================
# 统一：仅当顶层键不存在时，追加一段 YAML 块
# 用法: append_yaml_block_if_missing <key> <<'EOF' ... EOF
# ======================================
append_yaml_block_if_missing() {
    local key="$1"
    local cfg="$INSTALL_DIR/config.yaml"
    touch "$cfg"
    if ! grep -q "^${key}:" "$cfg" 2>/dev/null; then
        cat >> "$cfg"
    fi
}

# ======================================
# 统一：向 whitelist 追加一个网段（已存在则跳过）
# 用法: add_whitelist_entry <cidr>
# ======================================
add_whitelist_entry() {
    local entry="$1"
    local cfg="$INSTALL_DIR/config.yaml"
    touch "$cfg"

    if ! grep -q "^whitelist:" "$cfg" 2>/dev/null; then
        {
            echo "whitelist:"
            echo "  - ::1"
            echo "  - 127.0.0.1"
            echo "  - ${entry}"
        } >> "$cfg"
        return
    fi

    if awk '
        /^whitelist:/ {inblk=1; next}
        inblk && /^[^[:space:]]/ {inblk=0}
        inblk && $0 ~ /^[[:space:]]*-[[:space:]]*/ {
            line=$0
            sub(/^[[:space:]]*-[[:space:]]*/, "", line)
            if (line == "'"${entry}"'") {found=1}
        }
        END {exit !found}
    ' "$cfg"; then
        return 0
    fi

    awk -v e="$entry" '
        /^whitelist:/ {inblk=1; print; next}
        inblk && /^[^[:space:]]/ {
            if (!done) {print "  - " e; done=1}
            inblk=0
        }
        {print}
        END {if (inblk && !done) print "  - " e}
    ' "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
}

# ======================================
# 统一：读取 whitelistMode 状态
# 返回: true / false / 未设置
# ======================================
get_whitelist_mode() {
    local v
    v=$(read_config_key "whitelistMode")
    if [ -z "$v" ]; then
        echo "未设置"
    else
        echo "$v"
    fi
}

# ======================================
# 统一：切换 whitelistMode
# 用法: toggle_whitelist_mode
# ======================================
toggle_whitelist_mode() {
    local cfg="$INSTALL_DIR/config.yaml"
    [ -f "$cfg" ] || { echo -e "${RED}config.yaml 不存在${NC}"; return 1; }

    local cur
    cur=$(read_config_key "whitelistMode")
    local new

    if [ "$cur" = "true" ]; then
        new="false"
    else
        new="true"
    fi

    set_config_key "whitelistMode" "$new"

    if [ "$new" = "true" ]; then
        echo -e "${GREEN}✓ 白名单模式已开启${NC}"
        echo -e "${YELLOW}  只有 whitelist 列表中的 IP 能访问${NC}"
        echo -e "${CYAN}  当前白名单条目:${NC}"
        awk '
            /^whitelist:/ {inblk=1; next}
            inblk && /^[^[:space:]]/ {inblk=0}
            inblk && /^[[:space:]]*-/ {print "    " $0}
        ' "$cfg"
    else
        echo -e "${GREEN}✓ 白名单模式已关闭${NC}"
        echo -e "${RED}  ⚠️ 任何 IP 都能访问，请务必开启密码验证！${NC}"
        if [ "$(read_config_key basicAuthMode)" != "true" ]; then
            echo -e "${RED}  ⚠️ 当前密码验证未开启，强烈建议按 [1] 设置${NC}"
        fi
    fi
}

# ======================================
# 统一：node_modules 瘦身
# 保留：图片处理(jimp)、向量化、TTS，删除开发/构建/浏览器依赖
# ======================================
slim_node_modules() {
    local dir="${1:-$INSTALL_DIR/node_modules}"
    [ -d "$dir" ] || return 0

    local before after
    before=$(du -sm "$dir" 2>/dev/null | cut -f1)

    # ---- 1) 文档 / 测试 / 示例 ----
    find "$dir" -type f \( \
        -name "README*" -o -name "CHANGELOG*" -o -name "LICENSE*" \
        -o -name "AUTHORS*" -o -name "*.md" -o -name "*.map" \
        -o -name ".travis.yml" -o -name ".eslintrc*" \
        -o -name ".prettierrc*" -o -name ".editorconfig" \) \
        -delete 2>/dev/null

    find "$dir" -type d \( \
        -name "test" -o -name "tests" -o -name "__tests__" \
        -o -name "docs" -o -name "examples" -o -name "benchmark" \
        -o -name ".github" -o -name ".circleci" \
        -o -name ".vscode" -o -name ".idea" \) \
        -exec rm -rf {} + 2>/dev/null

    rm -rf "$dir/.cache" "$dir/.bin" 2>/dev/null

    # ---- 2) 纯开发 / 构建 / 类型（运行时无用）----
    rm -rf \
        "$dir/typescript" \
        "$dir/esbuild" "$dir/@esbuild" \
        "$dir/rollup" "$dir/rollup-"* "$dir/@rollup" \
        "$dir/webpack" "$dir/webpack-"* "$dir/@webpack" \
        "$dir/vite" "$dir/@vitejs" \
        2>/dev/null

    find "$dir" -type d -name "@types" -exec rm -rf {} + 2>/dev/null
    find "$dir" -name "*.d.ts" -delete 2>/dev/null

    # ---- 3) 无头浏览器（Termux 上跑不起来）----
    rm -rf \
        "$dir"/puppeteer* "$dir"/@puppeteer \
        "$dir"/playwright* "$dir"/@playwright \
        "$dir"/chromium* \
        2>/dev/null

    after=$(du -sm "$dir" 2>/dev/null | cut -f1)
    echo -e "${GREEN}✓ node_modules: ${before}MB → ${after}MB${NC}"
}

# ======================================
# 统一：npm 缓存清理
# ======================================
clean_npm_cache() {
    command_exists npm && npm cache clean --force 2>/dev/null
    rm -rf "$HOME/.npm" 2>/dev/null
}

# ======================================
# 统一：日志轮转（8MB，保留 2 份历史）
# ======================================
rotate_logs() {
    local max_size=$((8 * 1024 * 1024))
    local log_file="$INSTALL_DIR/nohup.out"
    local max_backups=2

    [ -f "$log_file" ] || return 0

    local current_size
    current_size=$(stat -c '%s' "$log_file" 2>/dev/null || echo 0)

    [ "$current_size" -lt "$max_size" ] && return 0

    local i=$max_backups
    while [ $i -gt 1 ]; do
        local prev=$((i - 1))
        [ -f "${log_file}.${prev}" ] && mv -f "${log_file}.${prev}" "${log_file}.${i}" 2>/dev/null
        i=$((i - 1))
    done

    mv -f "$log_file" "${log_file}.1" 2>/dev/null
    : > "$log_file"

    local j=$((max_backups + 1))
    while [ -f "${log_file}.${j}" ]; do
        rm -f "${log_file}.${j}" 2>/dev/null
        j=$((j + 1))
    done

    echo -e "${CYAN}📜 日志已轮转（超过 8MB，保留 2 份）${NC}"
}

# ======================================
# git / node / npm 瘦身
# ======================================
slim_git_node() {
    if command_exists git; then
        rm -rf "$PREFIX"/share/doc/git* \
               "$PREFIX"/share/man/man1/git* \
               "$PREFIX"/share/man/man5/git* \
               "$PREFIX"/share/man/man7/git* \
               "$PREFIX"/share/locale/*/LC_MESSAGES/git.mo \
               "$PREFIX"/share/git-core/templates \
               "$PREFIX"/libexec/git-core/git-gui \
               "$PREFIX"/libexec/git-core/gitk \
               "$PREFIX"/libexec/git-core/git-citool 2>/dev/null
        echo -e "  ${GREEN}✓ git 已瘦身（删除文档/man/templates/gui）${NC}"
    fi

    if command_exists npm; then
        rm -rf "$PREFIX"/lib/node_modules/npm/docs \
               "$PREFIX"/lib/node_modules/npm/man \
               "$PREFIX"/lib/node_modules/npm/html \
               "$PREFIX"/lib/node_modules/corepack \
               "$PREFIX"/share/man/man1/node* \
               "$PREFIX"/share/man/man1/npm* \
               "$PREFIX"/share/doc/node* 2>/dev/null
        clean_npm_cache
        echo -e "  ${GREEN}✓ node/npm 已瘦身（删除 docs/man/corepack/缓存）${NC}"
    fi
}