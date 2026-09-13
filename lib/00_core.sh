#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  00_core.sh — 常量 / 颜色 / 通用工具 / YAML 读写 / 缓存瘦身
#==========================================================================

# ---- 常量 ----
INSTALL_DIR="$HOME/SillyTavern"
BACKUP_DIR="$HOME/SillyTavern_Backups"
LAN_FLAG="$HOME/.sillytavern_lan"
SCRIPT_PATH="$HOME/st.sh"

# ---- 颜色 ----
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BLUE=''; BOLD=''; NC=''
fi

# ---- 通用输出助手（替代重复的 echo -e 模式）----
ok()   { echo -e "${GREEN}$*${NC}"; }
warn() { echo -e "${YELLOW}$*${NC}"; }
err()  { echo -e "${RED}$*${NC}" >&2; }
info() { echo -e "${CYAN}$*${NC}"; }
pause(){ printf "按回车返回..."; read -r _; }

# ---- 基础检查 ----
check_installed() { [ -f "$INSTALL_DIR/start.sh" ]; }
is_running()      { pgrep -f "node.*server.js" >/dev/null 2>&1; }
command_exists()  { command -v "$1" >/dev/null 2>&1; }

# ======================================
# 读取 config.yaml 配置项
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
# 设置/更新 YAML 键值（不覆盖整个文件）
# 用法: set_config_key <key> <value> [indent]
#   indent=0 → 顶层键；indent=1 → basicAuthUser 下的二级键
#   已存在则替换，不存在则追加
# ======================================
set_config_key() {
    local key="$1"
    local value="$2"
    local indent="${3:-0}"
    local cfg="$INSTALL_DIR/config.yaml"
    touch "$cfg"

    if [ "$indent" = "1" ]; then
        # ---------- 在 basicAuthUser 块内写 key ----------
        # 1) 如果 basicAuthUser 块不存在，先创建
        if ! grep -q "^basicAuthUser:" "$cfg"; then
            printf 'basicAuthUser:\n  %s: %s\n' "$key" "$value" >> "$cfg"
            return 0
        fi

        # 2) 找到块范围
        local block_line block_end total i line
        block_line=$(grep -n "^basicAuthUser:" "$cfg" | head -n1 | cut -d: -f1)
        total=$(wc -l < "$cfg")
        block_end=$total
        i=$((block_line + 1))
        while [ "$i" -le "$total" ]; do
            line=$(sed -n "${i}p" "$cfg")
            if [ -n "$line" ] && [[ ! "$line" =~ ^[[:space:]] ]]; then
                block_end=$((i - 1))
                break
            fi
            i=$((i + 1))
        done

        # 3) 在块内查找 key（只看缩进行，key 后跟冒号）
        local key_line=""
        local j
        for j in $(seq $((block_line + 1)) "$block_end"); do
            line=$(sed -n "${j}p" "$cfg")
            if [[ "$line" =~ ^[[:space:]]+${key}: ]]; then
                key_line=$j
                break
            fi
        done

        # 4) 替换 or 追加
        if [ -n "$key_line" ]; then
            sed -i "${key_line}s|.*|  ${key}: ${value}|" "$cfg"
        else
            sed -i "${block_end}a\\  ${key}: ${value}" "$cfg"
        fi
    else
        # ---------- 顶层 key ----------
        if grep -q "^${key}:" "$cfg"; then
            sed -i "s|^${key}:.*|${key}: ${value}|" "$cfg"
        else
            echo "${key}: ${value}" >> "$cfg"
        fi
    fi
}

# ======================================
# 仅当顶层键不存在时，追加一段 YAML 块
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
# 向 whitelist 追加一个网段（已存在则跳过）
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
# 日志轮转（8MB，保留 2 份历史）
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
}

# ======================================
# node_modules 瘦身
# 保留：图片处理(jimp)、向量化、TTS，删除开发/构建/浏览器依赖
# ======================================
slim_node_modules() {
    local dir="${1:-$INSTALL_DIR/node_modules}"
    [ -d "$dir" ] || return 0

    local before
    before=$(du -sm "$dir" 2>/dev/null | cut -f1)

    # ---- 1) 缓存 ----
    rm -rf "$dir/.cache" "$dir/.bin" 2>/dev/null

    # ---- 2) 纯开发 / 构建 / 类型（运行时无用）----
    rm -rf \
        "$dir/typescript" "$dir/@types" "$dir/ts-node" "$dir/tslib" \
        "$dir/eslint" "$dir/eslint-"* "$dir/@eslint" \
        "$dir/prettier" "$dir/jest" "$dir/@jest" "$dir/babel" \
        "$dir/@babel" "$dir/postcss" "$dir/sass" "$dir/less" \
        "$dir/terser" "$dir/uglify-js" "$dir/esbuild" \
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

    local after
    after=$(du -sm "$dir" 2>/dev/null | cut -f1)
    ok "  ✓ node_modules: ${before}MB → ${after}MB"
}

# ---- npm 缓存清理 ----
clean_npm_cache() {
    command_exists npm && npm cache clean --force 2>/dev/null
    rm -rf "$HOME/.npm" 2>/dev/null
}

# ---- git / node / npm 瘦身 ----
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
        ok "  ✓ git 已瘦身（删除文档/man/templates/gui）"
    fi

    if command_exists npm; then
        rm -rf "$PREFIX"/lib/node_modules/npm/docs \
               "$PREFIX"/lib/node_modules/npm/man \
               "$PREFIX"/lib/node_modules/npm/html \
               "$PREFIX"/lib/node_modules/npm/node_modules/.cache \
               "$PREFIX"/lib/node_modules/corepack \
               "$PREFIX"/share/man/man1/node* \
               "$PREFIX"/share/man/man1/npm* \
               "$PREFIX"/share/doc/node* 2>/dev/null
        clean_npm_cache
        ok "  ✓ npm 已瘦身（删除 docs/man/html/corepack）"
    fi
}

# ======================================
# 清理依赖并重装（供安装/更新/重装依赖复用）
# 用法: clean_and_reinstall_deps [--clean-cache] [--no-slim] [--quiet] [--label 文本]
# ======================================
clean_and_reinstall_deps() {
    local clean_cache=0 do_slim=1 label="依赖"
    ST_QUIET="${ST_QUIET:-0}"

    while [ $# -gt 0 ]; do
        case "$1" in
            --clean-cache) clean_cache=1 ;;
            --no-slim)     do_slim=0 ;;
            --quiet)       ST_QUIET=1 ;;
            --label)       label="$2"; shift ;;
        esac
        shift
    done

    # 静默感知的输出助手
    log() { [ "${ST_QUIET}" = "1" ] && return 0; echo -e "$@"; }

    [ -d "$INSTALL_DIR" ] || {
        err "${RED}✗ 安装目录不存在: $INSTALL_DIR${NC}"
        return 1
    }

    if is_running; then
        log "${CYAN}正在停止运行中的酒馆...${NC}"
        fn_stop >/dev/null 2>&1 || true
        sleep 1
    fi

    (
        cd "$INSTALL_DIR" || exit 1

        log "${CYAN}🧹 清理${label}...${NC}"
        if [ -d node_modules ]; then
            rm -rf node_modules
            log "  ${GREEN}✓ node_modules${NC}"
        fi
        if [ -f package-lock.json ] && [ "$clean_cache" = "1" ]; then
            rm -f package-lock.json
            log "  ${GREEN}✓ package-lock.json${NC}"
        fi

        if [ "$clean_cache" = "1" ]; then
            log "${CYAN}🧹 清理 npm 缓存...${NC}"
            clean_npm_cache
            log "  ${GREEN}✓ npm 缓存${NC}"
        fi

        log "${CYAN}📦 安装依赖（国内镜像加速）...${NC}"
        if [ "$ST_QUIET" = "1" ]; then
            npm install --no-audit --no-fund --loglevel=error >/dev/null 2>&1
        else
            npm install --no-audit --no-fund --loglevel=error
        fi

        if [ $? -ne 0 ]; then
            echo -e "${RED}✗ 依赖安装失败${NC}" >&2
            exit 1
        fi

        if [ "$do_slim" = "1" ]; then
            log "${CYAN}✂️ 依赖瘦身...${NC}"
            slim_node_modules >/dev/null 2>&1
            log "  ${GREEN}✓ 瘦身完成${NC}"
        fi
    )

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ ${label}处理失败，请检查网络后重试${NC}" >&2
        ST_QUIET=0
        return 1
    fi

    ST_QUIET=0
    log "${GREEN}✅ ${label}就绪${NC}"
    return 0
}
