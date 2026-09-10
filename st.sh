#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
# 🌀 淡蓝酒馆 · Termux 一键部署与管理 v2.7
# 全国内源加速 · 无需梯子 · 打开 Termux 自动弹出菜单
# 功能：局域网访问 + 密码验证 + 随机端口 + 推荐配置 + 扩展管理 + 清理
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

# ---- 工具函数 ----
check_installed() { [ -f "$INSTALL_DIR/start.sh" ]; }
is_running()      { pgrep -f "node.*server.js" >/dev/null 2>&1; }
command_exists()  { command -v "$1" >/dev/null 2>&1; }

# ---- git / node / npm 瘦身 ----
slim_git_node() {
    # ===== git 瘦身 =====
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

    # ===== node / npm 瘦身 =====
    if command_exists npm; then
        rm -rf "$PREFIX"/lib/node_modules/npm/docs \
               "$PREFIX"/lib/node_modules/npm/man \
               "$PREFIX"/lib/node_modules/npm/html \
               "$PREFIX"/lib/node_modules/corepack \
               "$PREFIX"/share/man/man1/node* \
               "$PREFIX"/share/man/man1/npm* \
               "$PREFIX"/share/doc/node* 2>/dev/null
        npm cache clean --force 2>/dev/null
        rm -rf "$HOME/.npm" 2>/dev/null
        echo -e "  ${GREEN}✓ node/npm 已瘦身（删除 docs/man/corepack/缓存）${NC}"
    fi
}

# ======================================
# 公共函数：清理并重装依赖
# 用法: clean_and_reinstall_deps [--clean-cache] [--no-slim] [--quiet] [--label TEXT]
# ======================================
clean_and_reinstall_deps() {
    local clean_cache=0 do_slim=1 quiet=0 label="依赖"
    while [ $# -gt 0 ]; do
        case "$1" in
            --clean-cache) clean_cache=1 ;;
            --no-slim)     do_slim=0 ;;
            --quiet)       quiet=1 ;;
            --label)       label="$2"; shift ;;
        esac
        shift
    done
    log() { [ "$quiet" = "1" ] || echo -e "$@"; }

    [ -d "$INSTALL_DIR" ] || {
        echo -e "${RED}✗ 安装目录不存在: $INSTALL_DIR${NC}"
        return 1
    }

    if is_running; then
        log "${CYAN}正在停止运行中的酒馆...${NC}"
        fn_stop 2>/dev/null || true
        sleep 1
    fi

    (
        cd "$INSTALL_DIR" || exit 1

        log "${CYAN}🧹 清理${label}...${NC}"
        if [ -d node_modules ]; then
            rm -rf node_modules
            log "  ${GREEN}✓ node_modules${NC}"
        fi
        if [ -f package-lock.json ]; then
            rm -f package-lock.json
            log "  ${GREEN}✓ package-lock.json${NC}"
        fi
        if [ "$clean_cache" = "1" ]; then
            npm cache clean --force 2>/dev/null
            rm -rf "$HOME/.npm" 2>/dev/null
            log "  ${GREEN}✓ npm 缓存${NC}"
        fi

        log "${CYAN}📦 安装${label}（淘宝镜像加速）...${NC}"
        npm config set registry https://registry.npmmirror.com 2>/dev/null || true

        if ! npm install --omit=dev --ignore-scripts --no-audit --no-fund 2>/dev/null; then
            log "${YELLOW}⚠️ 快速安装失败，尝试完整安装...${NC}"
            if ! npm install --omit=dev --no-audit --no-fund 2>/dev/null; then
                echo -e "${RED}❌ ${label}安装失败${NC}"
                echo -e "${YELLOW}💡 手动执行: cd $INSTALL_DIR && npm install${NC}"
                exit 1
            fi
        fi
        log "  ${GREEN}✓ ${label}安装完成${NC}"

        if [ "$do_slim" = "1" ]; then
            log "${CYAN}🧹 瘦身...${NC}"
            find node_modules -type f \( \
                -name "README*" -o -name "CHANGELOG*" -o -name "LICENSE*" \
                -o -name "AUTHORS*" -o -name "*.md" -o -name "*.map" \
                -o -name ".travis.yml" -o -name ".eslintrc*" \
                -o -name ".prettierrc*" -o -name ".editorconfig" \) \
                -delete 2>/dev/null
            find node_modules -type d \( \
                -name "test" -o -name "tests" -o -name "__tests__" \
                -o -name "docs" -o -name "examples" -o -name "benchmark" \
                -o -name ".github" -o -name ".circleci" \
                -o -name ".vscode" -o -name ".idea" \) \
                -exec rm -rf {} + 2>/dev/null
            rm -rf node_modules/.cache 2>/dev/null
            log "  ${GREEN}✓ 瘦身完成${NC}"
        fi
    )
}

# ---- 自动检测并关闭局域网（启动时执行，静默模式） ----
auto_disable_lan_on_start() {
    if [ -f "$LAN_FLAG" ] && ! is_running; then
        rm -f "$LAN_FLAG"
        if [ -f "$INSTALL_DIR/config.yaml" ]; then
            sed -i 's/^listen:.*/listen: false/' "$INSTALL_DIR/config.yaml" 2>/dev/null
            sed -i 's/^port:.*/port: 8000/' "$INSTALL_DIR/config.yaml" 2>/dev/null
        fi
    fi
}

# ---- 获取局域网 IP（仅使用 ifconfig） ----
get_lan_ip() {
    local ifconfig_cmd=""
    if command_exists ifconfig; then
        ifconfig_cmd="ifconfig"
    elif [ -x "/system/bin/ifconfig" ]; then
        ifconfig_cmd="/system/bin/ifconfig"
    elif [ -x "$PREFIX/bin/ifconfig" ]; then
        ifconfig_cmd="$PREFIX/bin/ifconfig"
    else
        echo ""
        return
    fi
    $ifconfig_cmd 2>/dev/null | grep -E "inet " | grep -v "127.0.0.1" | grep -E "192\.168|10\." | awk '{print $2}' | head -1
}

# ---- 获取当前端口 ----
get_current_port() {
    if [ -f "$INSTALL_DIR/config.yaml" ]; then
        local port=$(grep "^port:" "$INSTALL_DIR/config.yaml" 2>/dev/null | awk '{print $2}')
        echo "${port:-8000}"
    else
        echo "8000"
    fi
}

# ---- 获取密码状态 ----
get_password_status() {
    if [ ! -f "$INSTALL_DIR/config.yaml" ]; then
        echo "未配置"
        return
    fi
    local auth_mode=$(grep "^basicAuthMode:" "$INSTALL_DIR/config.yaml" 2>/dev/null | awk '{print $2}')
    local username=$(grep "^  username:" "$INSTALL_DIR/config.yaml" 2>/dev/null | awk '{print $2}' | tr -d '"')
    if [ "$auth_mode" = "true" ] && [ -n "$username" ] && [ "$username" != '""' ]; then
        echo "已开启 (账号: $username)"
    elif [ "$auth_mode" = "true" ]; then
        echo "已开启 (未设账号)"
    else
        echo "未开启"
    fi
}

# ---- 状态显示 ----
status_text() {
    if is_running; then
        local PORT=$(get_current_port)
        if [ -f "$LAN_FLAG" ]; then
            local IP=$(get_lan_ip)
            if [ -n "$IP" ]; then
                echo -e "${GREEN}🟢 运行中 → http://${IP}:${PORT} (局域网)${NC}"
            else
                echo -e "${GREEN}🟢 运行中 → 端口 ${PORT} (局域网模式)${NC}"
            fi
        else
            echo -e "${GREEN}🟢 运行中 → http://127.0.0.1:${PORT}${NC}"
        fi
    else
        echo -e "${YELLOW}🔴 未运行${NC}"
    fi
}

header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║   🌀 淡蓝酒馆 · Termux 控制面板      ║"
    echo "  ╚══════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    status_text
    echo ""
}

show_menu() {
    echo -e "  ${BOLD}═══ 管理 ═══${NC}"
    echo -e "  ${GREEN}[1]${NC} 启动  ${GREEN}[2]${NC} 停止  ${GREEN}[3]${NC} 重启"
    echo -e "  ${GREEN}[4]${NC}⭐️扩展管理⭐️${GREEN}[5]${NC}✨️推荐配置✨️"
    echo ""
    echo -e "  ${BOLD}═══ 维护 ═══${NC}"
    echo -e "  ${BLUE}[6]${NC} 更新  ${BLUE}[7]${NC} 日志  ${BLUE}[8]${NC} 版本回退/切换"
    echo -e "  ${BLUE}[9]${NC} 清理残余文件  ${BLUE}[10]${NC} Foxium工具箱"
    echo ""
    echo -e "  ${BOLD}═══ 数据 ═══${NC}"
    echo -e "  ${YELLOW}[11]${NC} 备份  ${YELLOW}[12]${NC} 恢复  ${YELLOW}[13]${NC} 重装依赖"
    echo ""
    echo -e "  ${BOLD}═══ 局域网 ═══${NC}"
    if [ -f "$LAN_FLAG" ]; then
        echo -e "  ${GREEN}[y]${NC} 开启中 ${YELLOW}[n]${NC} 关闭 ${CYAN}[m]${NC} 密码验证: $(get_password_status)"
    else
        echo -e "  ${YELLOW}[y]${NC} 开启  ${GREEN}[n]${NC} 已关闭 ${CYAN}[m]${NC}密码验证: $(get_password_status)"
    fi
    echo ""
    echo -e "  ${BOLD}═══ 其他 ═══${NC}"
    echo -e "  ${RED}[99]${NC} 卸载  ${RED}[0]${NC} 退出"
    echo ""
}

# ---- 生成随机端口 (10000-49151) ----
random_port() {
    echo $((10000 + RANDOM % 39152))
}

# ======================================
# 首次安装
# ======================================
do_install() {
    # ===== 存储权限交互式检测 =====
    local STORAGE_DIR="$HOME/storage/shared"

    if [ ! -d "$STORAGE_DIR" ]; then
        clear
        echo -e "${YELLOW}⚠️ 未检测到存储权限（目录 $STORAGE_DIR 不存在）${NC}"
        echo -e "${YELLOW}   Termux 需要访问外部存储才能保存角色卡、聊天记录等数据。${NC}"
        echo ""
        echo -e "  是否现在运行 ${CYAN}termux-setup-storage${NC} 授权？"
        echo -e "  （会弹出系统权限请求，请点击"允许"）"
        printf "  输入 ${GREEN}[y]${NC} 立即授权，${RED}[n]${NC} 退出安装: "
        read -r PERM_CHOICE

        case "$PERM_CHOICE" in
            y|Y)
                echo -e "${CYAN}正在请求存储权限...${NC}"
                termux-setup-storage
                echo -e "${CYAN}等待授权完成（最多10秒）...${NC}"
                local WAIT=0
                while [ ! -d "$STORAGE_DIR" ] && [ $WAIT -lt 10 ]; do
                    sleep 1
                    WAIT=$((WAIT + 1))
                done
                if [ ! -d "$STORAGE_DIR" ]; then
                    echo -e "${RED}✗ 授权超时或未成功，请手动运行 termux-setup-storage 后重试。${NC}"
                    exit 1
                else
                    echo -e "${GREEN}✓ 存储权限已获取${NC}"
                fi
                ;;
            *)
                echo -e "${RED}✗ 未授权存储权限，无法继续安装。${NC}"
                echo -e "${YELLOW}请稍后手动运行 termux-setup-storage，再重新执行本脚本。${NC}"
                exit 1
                ;;
        esac
    else
        echo -e "${GREEN}✓ 存储权限已就绪${NC}"
    fi

    clear
    echo "  🌀 淡蓝酒馆 · 首次安装"
    echo "  ========================"
    echo ""

    # [1/6] 换清华源
    echo "[1/6] 配置国内镜像..."
    if [ -f "$PREFIX/etc/apt/sources.list" ]; then
        cp "$PREFIX/etc/apt/sources.list" "$PREFIX/etc/apt/sources.list.bak" 2>/dev/null || true
        sed -i 's@packages.termux.dev@mirrors.tuna.tsinghua.edu.cn/termux@' "$PREFIX/etc/apt/sources.list" 2>/dev/null || true
    fi
    pkg update -y 2>/dev/null || pkg update -y
    echo "  ✓ Termux → 清华镜像"

    # [2/6] 装 git + nodejs + 网络工具
    echo "[2/6] 安装运行环境..."
    pkg install -y git nodejs-lts net-tools 2>/dev/null || { echo -e "${RED}  ✗ 依赖安装失败${NC}"; return 1; }
    echo "  ✓ Node.js $(node -v)"
    echo "  ✓ ifconfig 已安装"

    # [3/6] 配置 npm 加速
    echo "[3/6] 配置 npm 加速..."
    npm config set registry https://registry.npmmirror.com
    export NPM_CONFIG_REGISTRY=https://registry.npmmirror.com
    export NODE_OPTIONS="--max-old-space-size=512"
    echo "  ✓ npm → 淘宝镜像"

    # [4/6] 克隆酒馆（多代理轮换）
    echo "[4/6] 下载酒馆源码..."
    cd ~
    MIRRORS="
https://gh-proxy.com/https://github.com/SillyTavern/SillyTavern
https://gh.xiu2.xyz/https://github.com/SillyTavern/SillyTavern
https://github.com/SillyTavern/SillyTavern
"
    OK=0
    for URL in $MIRRORS; do
        echo "  → $URL"
        if git clone "$URL" -b release "$INSTALL_DIR" --depth 1 2>/dev/null; then
            echo "  ✓ release 分支"; OK=1; break
        fi
        if git clone "$URL" -b staging "$INSTALL_DIR" --depth 1 2>/dev/null; then
            echo "  ✓ staging 分支"; OK=1; break
        fi
    done
    if [ "$OK" != "1" ]; then
        echo -e "${RED}  ✗ 克隆失败，请检查网络后重试${NC}"
        return 1
    fi
    cd "$INSTALL_DIR"
    git remote set-url origin https://github.com/SillyTavern/SillyTavern 2>/dev/null || true

    # [5/6] 强制彻底重置依赖（公共函数）
    echo "[5/6] 清理旧依赖并重新安装（约 1-2 分钟）..."
    clean_and_reinstall_deps --clean-cache --label "依赖" || return 1

    # [5.5/6] 自动清理残余文件
    echo "[5.5/6] 自动清理残余文件..."
    cd "$INSTALL_DIR"
    rm -rf "$HOME/.npm" 2>/dev/null
    rm -f .*.tmp .*.swp .*.swo .*~ *~ 2>/dev/null
    echo "  ✓ 清理完成"

    # [5.6/6] git / node / npm 系统级瘦身
    echo "[5.6/6] git / node 瘦身..."
    slim_git_node

    # 创建备份目录
    mkdir -p "$BACKUP_DIR"

    # ===== 预安装 Foxium 工具箱 =====
    echo ""
    echo -e "${CYAN}🦊 正在预安装 Foxium 工具箱...${NC}"

    local FOXIUM_URLS=(
        "https://gh-proxy.com/https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
        "https://mirror.ghproxy.com/https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
        "https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
    )
    local FOX_OK=0
    for URL in "${FOXIUM_URLS[@]}"; do
        echo -e "  → 尝试下载: $(echo "$URL" | cut -d'/' -f3)"
        if curl -L "$URL" -o "$HOME/ffss.sh" --connect-timeout 10 --max-time 30 --retry 1 2>/dev/null; then
            if [ -s "$HOME/ffss.sh" ]; then
                chmod +x "$HOME/ffss.sh"
                echo -e "${GREEN}✅ Foxium 工具箱已预安装到 ~/ffss.sh${NC}"
                FOX_OK=1
                break
            fi
        fi
        rm -f "$HOME/ffss.sh" 2>/dev/null
    done

    if [ "$FOX_OK" != "1" ]; then
        echo -e "${YELLOW}⚠️ Foxium 预安装失败，可在菜单中按 [10] 重新下载${NC}"
    fi

    echo ""
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║   🌀 安装完成！                     ║"
    echo "  ╚══════════════════════════════════════╝"
    echo ""
    echo "  💡 现在输入 1 启动酒馆"
    echo "  💡 输入 y 开启局域网访问"
    echo "  💡 输入 m 设置密码验证"
    echo "  💡 输入 5 查看推荐配置"
    echo "  💡 输入 10 使用 Foxium 工具箱"
    echo ""

    if [ "$FOX_OK" = "1" ]; then
        echo -e "${CYAN}🦊 Foxium 工具箱已准备就绪！${NC}"
        echo -e "${YELLOW}是否现在启动 Foxium 工具箱？${NC}"
        echo -e "  ${GREEN}[y]${NC} 立即启动"
        echo -e "  ${RED}[n]${NC} 稍后手动启动（菜单选 10）"
        printf "选择 [y/N]: "
        read -r RUN_FOX

        if [ "$RUN_FOX" = "y" ] || [ "$RUN_FOX" = "Y" ]; then
            echo ""
            echo -e "${CYAN}正在启动 Foxium 工具箱...${NC}"
            echo ""
            sleep 1
            bash "$HOME/ffss.sh"
        else
            echo -e "${GREEN}✓ 已跳过，可在菜单中按 [10] 启动${NC}"
            sleep 1
        fi
    else
        echo -e "${YELLOW}💡 Foxium 工具箱未预安装成功，可在菜单中按 [10] 重新下载${NC}"
        sleep 2
    fi
}

# ======================================
# 扩展管理
# ======================================
fn_install_extension() {
    if ! check_installed; then
        echo -e "${RED}未安装${NC}"
        return
    fi

    EXT_URLS=(
        "https://github.com/RT15548/LittleWhiteBox"
        "https://github.com/zonde306/ST-Prompt-Template"
        "https://github.com/uhhhh15/QR.git"
        "https://github.com/N0VI028/JS-Slash-Runner"
        "https://github.com/uhhhh15/hide.git"
    )
    EXT_NAMES=(
        "LittleWhiteBox"
        "ST-Prompt-Template"
        "QR"
        "JS-Slash-Runner"
        "hide"
    )
    EXT_DISPLAYS=(
        "🧸 小白助手"
        "📋 Prompt Template（提示词模板）"
        "🤖 QR助手"
        "⚡ 酒馆助手"
        "🫥 隐藏助手"
    )
    EXT_BRANCHES=(
        "v3.0.6"
        ""
        ""
        ""
        ""
    )

    local total=${#EXT_URLS[@]}

    echo -e "${CYAN}${BOLD}═══════ 🧸 扩展管理 ═══════${NC}"
    echo ""
    echo -e "  ${YELLOW}✨ 可用的扩展:${NC}"
    for ((i=0; i<total; i++)); do
        if [ -n "${EXT_BRANCHES[$i]}" ]; then
            echo -e "  ${GREEN}[$((i+1))]${NC} ${EXT_DISPLAYS[$i]} ${CYAN}(${EXT_BRANCHES[$i]})${NC}"
        else
            echo -e "  ${GREEN}[$((i+1))]${NC} ${EXT_DISPLAYS[$i]}"
        fi
    done
    echo -e "  ${GREEN}[6]${NC} 🚀 安装全部扩展"
    echo -e "  ${GREEN}[7]${NC} 🌟 自定义URL安装"
    echo -e "  ${RED}[0]${NC} 🔙 返回"
    echo ""
    printf "选择: "
    read -r EXT_CHOICE

    case "$EXT_CHOICE" in
        [1-5])
            idx=$((EXT_CHOICE - 1))
            install_one "${EXT_URLS[$idx]}" "${EXT_NAMES[$idx]}" "${EXT_DISPLAYS[$idx]}" "no" "${EXT_BRANCHES[$idx]}"
            ;;
        6)
            echo ""
            echo -e "${YELLOW}即将安装全部 ${total} 个扩展。${NC}"
            printf "是否覆盖已存在的扩展？[y/N] (选择 y 则全部覆盖): "
            read -r FORCE_ALL
            FORCE_FLAG="no"
            if [ "$FORCE_ALL" = "y" ] || [ "$FORCE_ALL" = "Y" ]; then
                FORCE_FLAG="yes"
            fi
            for ((i=0; i<total; i++)); do
                echo ""
                echo -e "${CYAN}--- 安装 [$((i+1))] ${EXT_DISPLAYS[$i]} ---${NC}"
                install_one "${EXT_URLS[$i]}" "${EXT_NAMES[$i]}" "${EXT_DISPLAYS[$i]}" "$FORCE_FLAG" "${EXT_BRANCHES[$i]}"
            done
            echo ""
            echo -e "${GREEN}✅ 批量安装完成${NC}"
            ;;
        7)
            printf "请输入Git仓库URL: "
            read -r CUSTOM_URL
            if [ -z "$CUSTOM_URL" ]; then
                echo -e "${YELLOW}取消安装${NC}"
                return
            fi
            printf "请输入扩展名称(用于目录名): "
            read -r CUSTOM_NAME
            EXT_NAME="${CUSTOM_NAME:-custom-extension}"
            EXT_DISPLAY="🌟 $CUSTOM_NAME"
            install_one "$CUSTOM_URL" "$EXT_NAME" "$EXT_DISPLAY" "no" ""
            ;;
        0) return ;;
        *) echo -e "${RED}无效选项${NC}"; return ;;
    esac

    echo ""
    printf "按回车返回..."
    read -r _
}

# ======================================
# 安装单个扩展（静默代理模式）
# ======================================
install_one() {
    local repo="$1"
    local name="$2"
    local display="$3"
    local force="$4"
    local branch="$5"

    local EXT_DIR="$INSTALL_DIR/public/scripts/extensions/third-party/$name"
    if [ -d "$EXT_DIR" ]; then
        if [ "$force" != "yes" ]; then
            echo -e "${YELLOW}⚠️ 扩展已存在: $display${NC}"
            printf "是否覆盖安装? [y/N]: "
            read -r OVERWRITE
            if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
                echo -e "${YELLOW}跳过 $display${NC}"
                return 0
            fi
        fi
        rm -rf "$EXT_DIR"
    fi

    mkdir -p "$INSTALL_DIR/public/scripts/extensions/third-party"
    echo -e "${CYAN}💙 安装 $display ...${NC}"
    if [ -n "$branch" ]; then
        echo -e "  ${CYAN}📌 指定分支/Tag: ${branch}${NC}"
    fi

    local cloned=0

    if [[ "$repo" =~ github\.com ]]; then
        local repo_path="${repo#https://github.com/}"
        repo_path="${repo_path#http://github.com/}"
        repo_path="${repo_path#git@github.com:}"
        repo_path="${repo_path%.git}"

        local PROXY_PREFIXES=(
            "https://gh-proxy.com/https://github.com/"
            "https://gh.xiu2.xyz/https://github.com/"
            "https://ghfast.top/https://github.com/"
            "https://ghproxy.net/https://github.com/"
            "https://github.com/"
        )

        echo -e "  ${CYAN}⏳ 正在下载...${NC}"
        for PROXY in "${PROXY_PREFIXES[@]}"; do
            local PROXY_URL="${PROXY}${repo_path}"
            if [ -n "$branch" ]; then
                if git clone "$PROXY_URL" "$EXT_DIR" --branch "$branch" --depth 1 2>/dev/null; then
                    echo -e "${GREEN}✅ 安装成功: $display (${branch})${NC}"
                    cloned=1
                    break
                fi
            else
                if git clone "$PROXY_URL" "$EXT_DIR" --depth 1 2>/dev/null; then
                    echo -e "${GREEN}✅ 安装成功: $display${NC}"
                    cloned=1
                    break
                fi
            fi
        done
    else
        echo -e "  ${CYAN}⏳ 正在下载...${NC}"
        if [ -n "$branch" ]; then
            if git clone "$repo" "$EXT_DIR" --branch "$branch" --depth 1 2>/dev/null; then
                echo -e "${GREEN}✅ 安装成功: $display (${branch})${NC}"
                cloned=1
            fi
        else
            if git clone "$repo" "$EXT_DIR" --depth 1 2>/dev/null; then
                echo -e "${GREEN}✅ 安装成功: $display${NC}"
                cloned=1
            fi
        fi
    fi

    if [ "$cloned" != "1" ]; then
        echo -e "${RED}❌ 安装失败: $display${NC}"
        if [ -n "$branch" ]; then
            echo -e "${YELLOW}💡 提示: 分支/Tag '${branch}' 可能不存在，请检查仓库${NC}"
        fi
        return 1
    fi
    return 0
}

# ======================================
# 推荐配置
# ======================================
fn_config() {
    if ! check_installed; then
        echo -e "${RED}未安装${NC}"
        return
    fi

    echo -e "${CYAN}${BOLD}═══════ ⚙️ 推荐配置 ═══════${NC}"
    echo ""

    if [ -f "$INSTALL_DIR/config.yaml" ]; then
        echo -e "${YELLOW}⚠️ config.yaml 已存在${NC}"
        printf "是否覆盖为推荐配置？[y/N]: "
        read -r OVERWRITE
        if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
            echo -e "${YELLOW}取消${NC}"
            printf "按回车返回..."
            read -r _
            return
        fi
        cp "$INSTALL_DIR/config.yaml" "$INSTALL_DIR/config.yaml.bak"
        echo -e "${CYAN}✓ 已备份旧配置为 config.yaml.bak${NC}"
    fi

    echo -e "${CYAN}💙 生成推荐配置...${NC}"
    cat > "$INSTALL_DIR/config.yaml" << 'EOF'
listen: false
port: 8000
whitelist:
  - ::1
  - 127.0.0.1
  - 192.168.0.0/16
basicAuthMode: false
basicAuthUser:
  username: ""
  password: ""
rateLimiting:
  accountsResetMaxAttempts: 5
performance:
  lazyLoadCharacters: true
EOF

    if [ -f "$INSTALL_DIR/config.yaml" ]; then
        echo -e "${GREEN}✓ 推荐配置已生成${NC}"
        echo ""
        echo -e "  ${YELLOW}📋 配置内容：${NC}"
        echo -e "    ${CYAN}端口：${NC}8000"
        echo -e "    ${CYAN}密码验证：${NC}关闭"
        echo -e "    ${CYAN}懒加载角色：${NC}开启"
        echo -e "    ${CYAN}局域网白名单：${NC}已配置"
        echo ""
        echo -e "${YELLOW}💡 按 m 可设置密码验证${NC}"
        echo -e "${YELLOW}💡 按 y 可开启局域网访问${NC}"
    else
        echo -e "${RED}✗ 配置生成失败${NC}"
    fi

    echo ""
    printf "按回车返回..."
    read -r _
}

# ======================================
# 重装依赖 (Fix npm) - 使用公共函数
# ======================================
fn_reinstall_deps() {
    if ! check_installed; then
        echo -e "${RED}SillyTavern 未安装，请先安装。${NC}"
        return
    fi

    echo -e "${CYAN}${BOLD}═══════ 🔧 重装依赖 (Fix npm) ═══════${NC}"
    echo ""
    echo -e "${YELLOW}此操作将重新下载并安装 SillyTavern 的运行依赖。${NC}"
    echo -e "${YELLOW}安装完成后会自动进行极致瘦身，删除文档、测试文件等。${NC}"
    echo ""

    if [ -d "$INSTALL_DIR/node_modules" ]; then
        local current_size=$(du -sh "$INSTALL_DIR/node_modules" 2>/dev/null | cut -f1)
        echo -e "${CYAN}当前 node_modules 大小: ${current_size}${NC}"
        echo ""
    fi

    printf "确认继续吗? [y/N]: "
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}操作已取消。${NC}"
        printf "按回车返回..."
        read -r _
        return
    fi

    if clean_and_reinstall_deps --clean-cache --label "依赖"; then
        fn_clean
        if [ -d "$INSTALL_DIR/node_modules" ]; then
            local final_size=$(du -sh "$INSTALL_DIR/node_modules" 2>/dev/null | cut -f1)
            echo ""
            echo -e "${CYAN}📊 最终 node_modules 大小: ${final_size}${NC}"
        fi
        echo ""
        echo -e "${YELLOW}💡 建议重启酒馆以应用更改。${NC}"
        echo ""
        printf "是否立即启动酒馆？[Y/n]: "
        read -r START_NOW
        if [[ "$START_NOW" != "n" && "$START_NOW" != "N" ]]; then
            fn_start
        fi
    fi

    echo ""
    printf "按回车返回..."
    read -r _
}

# ======================================
# 清理残余文件
# ======================================
fn_clean() {
    if ! check_installed; then
        echo -e "${RED}未安装${NC}"
        return
    fi

    fn_stop 2>/dev/null || true
    cd "$INSTALL_DIR" || return

    echo -e "${CYAN}${BOLD}═══════ 🧹 清理残余文件 ═══════${NC}"
    echo ""

    local cleaned=0

    if [ -d "node_modules/.cache" ]; then
        rm -rf node_modules/.cache 2>/dev/null
        echo -e "${GREEN}✓ 已清理 node_modules/.cache${NC}"
        cleaned=1
    fi

    if [ -d "$HOME/.npm" ]; then
        local npm_cache_size
        npm_cache_size=$(du -sh "$HOME/.npm" 2>/dev/null | cut -f1)
        rm -rf "$HOME/.npm" 2>/dev/null
        echo -e "${GREEN}✓ 已清理 ~/.npm 缓存（${npm_cache_size}）${NC}"
        cleaned=1
    fi

    if [ -f "npm-debug.log" ]; then
        rm -f npm-debug.log 2>/dev/null
        echo -e "${GREEN}✓ 已清理 npm-debug.log${NC}"
        cleaned=1
    fi

    if [ -f ".git/index.lock" ]; then
        rm -f .git/index.lock 2>/dev/null
        echo -e "${GREEN}✓ 已清理 .git/index.lock${NC}"
        cleaned=1
    fi

    if [ -d "node_modules" ]; then
        find node_modules -type f \( -name "README*" -o -name "CHANGELOG*" -o -name "LICENSE*" -o -name "AUTHORS*" -o -name "*.md" -o -name "*.map" -o -name ".travis.yml" -o -name ".eslintrc*" -o -name ".prettierrc*" -o -name ".editorconfig" \) -delete 2>/dev/null
        find node_modules -type d \( -name "test" -o -name "tests" -o -name "__tests__" -o -name "docs" -o -name "examples" -o -name "benchmark" \) -exec rm -rf {} + 2>/dev/null
        find node_modules -type d \( -name ".github" -o -name ".circleci" -o -name ".vscode" -o -name ".idea" \) -exec rm -rf {} + 2>/dev/null
        echo -e "${GREEN}✓ 已清理 node_modules 中的文档/测试文件${NC}"
        cleaned=1
    fi

    if [ -d "public/scripts" ]; then
        local map_count
        map_count=$(find public/scripts -name "*.map" 2>/dev/null | wc -l)
        if [ "$map_count" -gt 0 ]; then
            find public/scripts -name "*.map" -delete 2>/dev/null
            echo -e "${GREEN}✓ 已清理 ${map_count} 个 source map 文件${NC}"
            cleaned=1
        fi
    fi

    if [ -d "public/locales" ]; then
        local locale_count=0
        for d in public/locales/*; do
            if [ -d "$d" ]; then
                local bn
                bn=$(basename "$d")
                case "$bn" in
                    en|zh|zh-cn|zh-CN|zh-tw|zh-TW) ;;
                    *)
                        rm -rf "$d" 2>/dev/null
                        locale_count=$((locale_count+1))
                        ;;
                esac
            fi
        done
        if [ "$locale_count" -gt 0 ]; then
            echo -e "${GREEN}✓ 已清理 ${locale_count} 个非必要语言包${NC}"
            cleaned=1
        fi
    fi

    if [ -d "data/default-user/backups" ]; then
        local bak_count
        bak_count=$(ls -1 data/default-user/backups/*.jsonl 2>/dev/null | wc -l)
        if [ "$bak_count" -gt 5 ]; then
            ls -1t data/default-user/backups/*.jsonl 2>/dev/null | tail -n +6 | while read -r f; do
                rm -f "$f" 2>/dev/null
            done
            echo -e "${GREEN}✓ 已清理旧聊天备份（保留最近5个）${NC}"
            cleaned=1
        fi
    fi

    if command_exists npm; then
        npm cache clean --force 2>/dev/null
        echo -e "${GREEN}✓ 已清理 npm 全局缓存${NC}"
        cleaned=1
    fi

    slim_git_node
    cleaned=1

    echo ""

    if [ -d "node_modules" ]; then
        local nm_size
        nm_size=$(du -sh node_modules 2>/dev/null | cut -f1)
        echo -e "${CYAN}  node_modules 大小: ${nm_size}${NC}"
    fi
    if [ -d "public/scripts/extensions" ]; then
        local ext_size
        ext_size=$(du -sh public/scripts/extensions 2>/dev/null | cut -f1)
        echo -e "${CYAN}  扩展目录大小: ${ext_size}${NC}"
    fi

    if [ "$cleaned" = "0" ]; then
        echo -e "${YELLOW}  没有需要清理的残余文件${NC}"
    else
        echo -e "${GREEN}✅ 清理完成${NC}"
    fi

    echo ""
    printf "按回车返回..."
    read -r _
}

# ======================================
# Foxium 工具箱（增强版 - 带版本检查）
# ======================================
fn_foxium() {
    echo -e "${CYAN}${BOLD}═══════ 🦊 Foxium 工具箱 ═══════${NC}"
    echo ""

    cd "$HOME" || return

    if [ -f "$HOME/ffss.sh" ] && [ -s "$HOME/ffss.sh" ]; then
        echo -e "${GREEN}✅ 已安装 Foxium 工具箱${NC}"
        echo -e "${CYAN}正在检查更新...${NC}"
        local REMOTE_VERSION=""
        local TEMP_FILE=$(mktemp)

        for URL in "https://raw.githubusercontent.com/likesugar/Txst/main/version.txt" \
                    "https://gh-proxy.com/https://raw.githubusercontent.com/likesugar/Txst/main/version.txt"; do
            if curl -L "$URL" -o "$TEMP_FILE" --connect-timeout 5 2>/dev/null && [ -s "$TEMP_FILE" ]; then
                REMOTE_VERSION=$(cat "$TEMP_FILE" | head -1)
                break
            fi
        done
        rm -f "$TEMP_FILE"

        if [ -n "$REMOTE_VERSION" ]; then
            local LOCAL_VERSION=$(grep "^# Version:" "$HOME/ffss.sh" 2>/dev/null | head -1 | cut -d':' -f2 | xargs)
            if [ -n "$LOCAL_VERSION" ] && [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
                echo -e "${YELLOW}⚠️ 发现新版本: $REMOTE_VERSION (当前: $LOCAL_VERSION)${NC}"
                printf "是否更新？[y/N]: "
                read -r UPDATE_FOX
                if [ "$UPDATE_FOX" = "y" ] || [ "$UPDATE_FOX" = "Y" ]; then
                    echo -e "${CYAN}正在更新...${NC}"
                    rm -f "$HOME/ffss.sh"
                    local FOXIUM_URLS=(
                        "https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
                        "https://gh-proxy.com/https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
                        "https://ghproxy.net/https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
                        "https://ghfast.top/https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
                    )
                    for URL in "${FOXIUM_URLS[@]}"; do
                        if curl -L "$URL" -o "$HOME/ffss.sh" --connect-timeout 10 2>/dev/null && [ -s "$HOME/ffss.sh" ]; then
                            chmod +x "$HOME/ffss.sh"
                            echo -e "${GREEN}✅ 更新完成${NC}"
                            break
                        fi
                    done
                fi
            else
                echo -e "${GREEN}✓ 已是最新版本${NC}"
            fi
        fi

        echo ""
        echo -e "${CYAN}正在启动 Foxium 工具箱...${NC}"
        echo ""
        bash "$HOME/ffss.sh"
        return
    fi

    echo -e "${CYAN}正在下载 Foxium 工具箱...${NC}"

    local FOXIUM_URLS=(
        "https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
        "https://gh-proxy.com/https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
        "https://ghproxy.net/https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
        "https://ghfast.top/https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
    )

    local OK=0
    for URL in "${FOXIUM_URLS[@]}"; do
        echo -e "  → 尝试下载..."
        if curl -L "$URL" -o ffss.sh --connect-timeout 10 2>/dev/null; then
            if [ -s ffss.sh ]; then
                echo -e "${GREEN}✅ 下载成功${NC}"
                OK=1
                break
            fi
        fi
    done

    if [ "$OK" != "1" ]; then
        echo -e "${RED}❌ 下载失败，请检查网络连接${NC}"
        echo -e "${YELLOW}💡 可尝试手动执行:${NC}"
        echo -e "  ${CYAN}curl -L https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh -o ~/ffss.sh && bash ~/ffss.sh${NC}"
        printf "\n按回车返回..."
        read -r _
        return
    fi

    chmod +x ffss.sh
    echo -e "${GREEN}✅ Foxium 工具箱已安装到 ~/ffss.sh${NC}"
    echo -e "${CYAN}正在启动...${NC}"
    echo ""
    bash ffss.sh
}

# ======================================
# 局域网功能
# ======================================
fn_lan_on() {
    touch "$LAN_FLAG"

    if [ -f "$INSTALL_DIR/config.yaml" ]; then
        if grep -q "^listen:" "$INSTALL_DIR/config.yaml" 2>/dev/null; then
            sed -i 's/^listen:.*/listen: true/' "$INSTALL_DIR/config.yaml"
        else
            echo "listen: true" >> "$INSTALL_DIR/config.yaml"
        fi

        local RANDOM_PORT=$(random_port)
        if grep -q "^port:" "$INSTALL_DIR/config.yaml" 2>/dev/null; then
            sed -i "s/^port:.*/port: ${RANDOM_PORT}/" "$INSTALL_DIR/config.yaml"
        else
            echo "port: ${RANDOM_PORT}" >> "$INSTALL_DIR/config.yaml"
        fi

        if ! grep -q "^whitelist:" "$INSTALL_DIR/config.yaml" 2>/dev/null; then
            echo "whitelist:" >> "$INSTALL_DIR/config.yaml"
            echo "  - ::1" >> "$INSTALL_DIR/config.yaml"
            echo "  - 127.0.0.1" >> "$INSTALL_DIR/config.yaml"
            echo "  - 192.168.0.0/16" >> "$INSTALL_DIR/config.yaml"
        fi
    fi

    local IP=$(get_lan_ip)
    local PORT=$(get_current_port)

    echo -e "${GREEN}✓ 局域网访问已开启${NC}"
    echo -e "${CYAN}🌐 访问地址: http://${IP:-<IP>}:${PORT}${NC}"
    echo -e "${CYAN}  随机端口: ${PORT} (避免冲突)${NC}"

    local PASS_STATUS=$(get_password_status)
    if [[ "$PASS_STATUS" == "未开启" ]]; then
        echo -e "${YELLOW}⚠️ 密码验证未开启，局域网内任何人都能访问${NC}"
        echo -e "${YELLOW}  建议按 m 设置密码验证${NC}"
    fi

    echo -e "${CYAN}🔄 正在自动重启酒馆以应用配置...${NC}"
    fn_stop
    sleep 2
    fn_start
    echo -e "${GREEN}✅ 配置已应用并重启完成${NC}"
}

fn_lan_off() {
    rm -f "$LAN_FLAG"

    if [ -f "$INSTALL_DIR/config.yaml" ]; then
        sed -i 's/^listen:.*/listen: false/' "$INSTALL_DIR/config.yaml"
        sed -i 's/^port:.*/port: 8000/' "$INSTALL_DIR/config.yaml"
    fi

    echo -e "${GREEN}✓ 局域网访问已关闭${NC}"
    echo -e "${YELLOW}  端口恢复: 8000 (仅本机)${NC}"

    if is_running; then
        echo -e "${YELLOW}  正在自动重启酒馆以应用更改...${NC}"
        fn_stop
        sleep 1
        fn_start
    fi
}

# ---- 设置密码验证 ----
fn_set_password() {
    if ! check_installed; then
        echo -e "${RED}未安装${NC}"
        return
    fi
    if [ ! -f "$INSTALL_DIR/config.yaml" ]; then
        echo -e "${RED}config.yaml 不存在${NC}"
        return
    fi

    echo ""
    echo -e "${CYAN}${BOLD}═══════ 密码验证设置 ═══════${NC}"
    echo ""

    if [ -f "$LAN_FLAG" ]; then
        local IP=$(get_lan_ip)
        local PORT=$(get_current_port)
        echo -e "${CYAN}🌐 局域网状态: 已开启${NC}"
        echo -e "${CYAN}   访问地址: http://${IP:-<IP>}:${PORT}${NC}"
        echo -e "${CYAN}   当前端口: ${PORT}${NC}"
    else
        echo -e "${YELLOW}🌐 局域网状态: 已关闭 (仅本机访问)${NC}"
    fi
    echo ""

    local CURRENT_AUTH=$(grep "^basicAuthMode:" "$INSTALL_DIR/config.yaml" 2>/dev/null | awk '{print $2}')
    local CURRENT_USER=$(grep "^  username:" "$INSTALL_DIR/config.yaml" 2>/dev/null | awk '{print $2}' | tr -d '"')
    local CURRENT_PASS=$(grep "^  password:" "$INSTALL_DIR/config.yaml" 2>/dev/null | awk '{print $2}' | tr -d '"')

    echo -e "${YELLOW}📋 密码验证状态：${NC}"
    if [ "$CURRENT_AUTH" = "true" ] && [ -n "$CURRENT_USER" ] && [ "$CURRENT_USER" != '""' ]; then
        echo -e "  ${GREEN}状态：✅ 已开启${NC}"
        echo -e "  ${CYAN}账号：${CURRENT_USER}${NC}"
        if [ -n "$CURRENT_PASS" ] && [ "$CURRENT_PASS" != '""' ]; then
            echo -e "  ${CYAN}密码：${CURRENT_PASS}${NC}"
        else
            echo -e "  ${YELLOW}密码：未设置${NC}"
        fi
    else
        echo -e "  ${RED}状态：❌ 未开启${NC}"
    fi
    echo ""

    echo -e "  ${GREEN}[1]${NC} 设置/修改账号密码"
    echo -e "  ${YELLOW}[2]${NC} 关闭密码认证"
    echo -e "  ${GREEN}[3]${NC} 重新生成随机端口"
    echo -e "  ${RED}[0]${NC} 返回"
    echo ""

    printf "请选择: "
    read -r PASS_CHOICE

    case "$PASS_CHOICE" in
        1)
            echo ""
            printf "请输入账号 (不能为空): "
            read -r NEW_USER
            if [ -z "$NEW_USER" ]; then
                echo -e "${RED}账号不能为空，取消设置${NC}"
                printf "按回车返回..."
                read -r _
                return
            fi

            printf "请输入密码 (不能为空): "
            read -r NEW_PASSWORD
            if [ -z "$NEW_PASSWORD" ]; then
                echo -e "${RED}密码不能为空，取消设置${NC}"
                printf "按回车返回..."
                read -r _
                return
            fi

            cp "$INSTALL_DIR/config.yaml" "$INSTALL_DIR/config.yaml.bak"

            if grep -q "^basicAuthMode:" "$INSTALL_DIR/config.yaml" 2>/dev/null; then
                sed -i 's/^basicAuthMode:.*/basicAuthMode: true/' "$INSTALL_DIR/config.yaml"
            else
                echo "basicAuthMode: true" >> "$INSTALL_DIR/config.yaml"
            fi

            if grep -q "^basicAuthUser:" "$INSTALL_DIR/config.yaml" 2>/dev/null; then
                sed -i "s/^  username:.*/  username: \"${NEW_USER}\"/" "$INSTALL_DIR/config.yaml"
                sed -i "s/^  password:.*/  password: \"${NEW_PASSWORD}\"/" "$INSTALL_DIR/config.yaml"
            else
                echo "basicAuthUser:" >> "$INSTALL_DIR/config.yaml"
                echo "  username: \"${NEW_USER}\"" >> "$INSTALL_DIR/config.yaml"
                echo "  password: \"${NEW_PASSWORD}\"" >> "$INSTALL_DIR/config.yaml"
            fi

            echo ""
            echo -e "${GREEN}✓ 密码验证已设置${NC}"
            echo -e "  ${CYAN}账号: ${NEW_USER}${NC}"

            if is_running; then
                echo -e "${YELLOW}  ⚠️ 需要重启酒馆才能生效${NC}"
            fi
            ;;
        2)
            echo ""
            if grep -q "^basicAuthMode:" "$INSTALL_DIR/config.yaml" 2>/dev/null; then
                sed -i 's/^basicAuthMode:.*/basicAuthMode: false/' "$INSTALL_DIR/config.yaml"
                echo -e "${GREEN}✓ 密码认证已关闭${NC}"
            else
                echo -e "${YELLOW}密码认证未开启${NC}"
            fi
            if is_running; then
                echo -e "${YELLOW}  ⚠️ 需要重启酒馆才能生效)${NC}"
            fi
            ;;
        3)
            echo ""
            if [ ! -f "$LAN_FLAG" ]; then
                echo -e "${YELLOW}⚠️ 局域网未开启，无需随机端口${NC}"
                printf "按回车返回..."
                read -r _
                return
            fi

            local NEW_PORT=$(random_port)
            if grep -q "^port:" "$INSTALL_DIR/config.yaml" 2>/dev/null; then
                sed -i "s/^port:.*/port: ${NEW_PORT}/" "$INSTALL_DIR/config.yaml"
            else
                echo "port: ${NEW_PORT}" >> "$INSTALL_DIR/config.yaml"
            fi

            echo -e "${GREEN}✓ 端口已更换为: ${NEW_PORT}${NC}"

            if is_running; then
                echo -e "${YELLOW}  ⚠️ 需要重启酒馆才能生效${NC}"
            fi
            ;;
        0) return ;;
        *) echo -e "${RED}无效选项${NC}" ;;
    esac

    echo ""
    printf "按回车返回..."
    read -r _
}

# ======================================
# 菜单功能
# ======================================
fn_start() {
    if ! check_installed; then
        echo -e "${RED}未安装${NC}"
        return
    fi
    if is_running; then
        echo -e "${GREEN}已在运行${NC}"
        return
    fi

    echo -e "${GREEN}启动中...${NC}"
    cd "$INSTALL_DIR"
    nohup bash start.sh > "$INSTALL_DIR/nohup.out" 2>&1 &
    sleep 3

    if is_running; then
        local PORT=$(get_current_port)
        if [ -f "$LAN_FLAG" ]; then
            local IP=$(get_lan_ip)
            if [ -n "$IP" ]; then
                echo -e "${GREEN}✓ 已启动 → http://${IP}:${PORT} (局域网)${NC}"
            else
                echo -e "${GREEN}✓ 已启动 → 端口 ${PORT} (局域网模式)${NC}"
            fi
        else
            echo -e "${GREEN}✓ 已启动 → http://127.0.0.1:${PORT}${NC}"
        fi
    else
        echo -e "${RED}✗ 启动失败${NC}"
    fi
}

fn_stop() {
    pkill -f "node.*server.js" 2>/dev/null || true
    sleep 1
    pkill -9 -f "node.*server.js" 2>/dev/null || true
    echo -e "${GREEN}✓ 已停止${NC}"
}

fn_restart() {
    fn_stop
    sleep 1
    fn_start
}

# ---- 更新 ----
fn_update() {
    if ! check_installed; then
        echo -e "${RED}SillyTavern 未安装，请先安装。${NC}"
        return
    fi

    fn_stop 2>/dev/null || true
    cd "$INSTALL_DIR" || return

    echo -e "${CYAN}正在拉取最新代码...${NC}"
    git fetch --all --tags 2>/dev/null

    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ "$current_branch" == "HEAD" ]; then
        current_branch="detached (HEAD)"
    fi
    local current_tag
    current_tag=$(git describe --tags --exact-match 2>/dev/null || echo "")
    local current_commit
    current_commit=$(git rev-parse --short HEAD 2>/dev/null)

    echo -e "${BLUE}当前分支: ${YELLOW}$current_branch${NC}"
    if [ -n "$current_tag" ]; then
        echo -e "${BLUE}当前版本 Tag: ${YELLOW}$current_tag${NC}"
    else
        echo -e "${BLUE}当前版本: ${YELLOW}未关联 Tag (commit $current_commit)${NC}"
    fi

    local -a available_tags=()
    while IFS= read -r tag; do
        available_tags+=("$tag")
    done < <(git tag --sort=-creatordate 2>/dev/null | head -n 10)

    echo ""
    echo -e "${BOLD}请选择更新目标：${NC}"
    echo -e "  ${GREEN}[1]${NC} release 分支 (推荐)"
    echo -e "  ${GREEN}[2]${NC} main 分支"
    if [ ${#available_tags[@]} -gt 0 ]; then
        echo -e "  ${GREEN}[3]${NC} 指定 Tag 版本"
    fi
    printf "请输入选项 [1-3] (默认 1): "
    read -r UPDATE_CHOICE
    UPDATE_CHOICE=${UPDATE_CHOICE:-1}

    local target_ref="origin/release"
    local target_label="release 分支"
    local selected_tag=""

    case $UPDATE_CHOICE in
        2)
            target_ref="origin/main"
            target_label="main 分支"
            ;;
        3)
            if [ ${#available_tags[@]} -eq 0 ]; then
                echo -e "${RED}未检测到 Tag。${NC}"
                return
            fi
            echo -e "${YELLOW}最近的 ${#available_tags[@]} 个版本号：${NC}"
            for i in "${!available_tags[@]}"; do
                printf "  ${GREEN}[%d]${NC} %s\n" $((i+1)) "${available_tags[$i]}"
            done
            echo ""
            while true; do
                printf "请输入版本序号 (1-%d) 或直接输入版本号: " ${#available_tags[@]}
                read -r TAG_INPUT
                TAG_INPUT=$(echo "$TAG_INPUT" | xargs)
                if [ -z "$TAG_INPUT" ]; then
                    echo -e "${RED}输入为空，操作取消。${NC}"
                    return
                fi
                if [[ "$TAG_INPUT" =~ ^[0-9]+$ ]]; then
                    if [ "$TAG_INPUT" -ge 1 ] && [ "$TAG_INPUT" -le ${#available_tags[@]} ]; then
                        selected_tag="${available_tags[$((TAG_INPUT-1))]}"
                        break
                    else
                        echo -e "${RED}序号超出范围。${NC}"
                        continue
                    fi
                else
                    if git rev-parse -q --verify "refs/tags/$TAG_INPUT" >/dev/null 2>&1; then
                        selected_tag="$TAG_INPUT"
                        break
                    else
                        echo -e "${RED}未找到名为 '$TAG_INPUT' 的 Tag。${NC}"
                        continue
                    fi
                fi
            done
            target_ref="tags/$selected_tag"
            target_label="Tag $selected_tag"
            ;;
        *)
            if ! git show-ref --verify --quiet refs/remotes/origin/release 2>/dev/null; then
                target_ref="origin/main"
                target_label="main 分支 (release 不存在)"
                echo -e "${YELLOW}未找到 release 分支，已改为 main。${NC}"
            fi
            ;;
    esac

    echo -e "${CYAN}正在更新到 ${target_label} ...${NC}"
    if git reset --hard "$target_ref" 2>/dev/null; then
        echo -e "${GREEN}代码更新成功，正在更新依赖...${NC}"
        clean_and_reinstall_deps --quiet --label "依赖" || return
        echo -e "${GREEN}更新完成！${NC}"
        printf "是否启动？[Y/n] "; read -r YN
        [ "$YN" != "n" ] && [ "$YN" != "N" ] && fn_start
    else
        echo -e "${RED}更新失败，请检查网络或版本号是否正确。${NC}"
    fi
}

fn_logs() {
    if ! check_installed; then echo -e "${RED}未安装${NC}"; return; fi
    echo -e "${CYAN}=== 最近 30 行 ===${NC}"
    if [ -f "$INSTALL_DIR/nohup.out" ]; then
        tail -30 "$INSTALL_DIR/nohup.out"
    else
        echo "(无日志)"
    fi
    printf "按回车返回..."; read -r _
}

# ---- 版本回退 ----
fn_rollback() {
    if ! check_installed; then
        echo -e "${RED}SillyTavern 未安装，请先安装。${NC}"
        return
    fi

    fn_stop 2>/dev/null || true
    cd "$INSTALL_DIR" || return
    echo -e "${CYAN}正在获取版本记录...${NC}"
    git fetch --all --tags 2>/dev/null

    echo ""
    echo -e "${BOLD}请选择回退/切换方式：${NC}"
    echo -e "  ${GREEN}[1]${NC} 按版本号 (Tag) 切换 (推荐)"
    echo -e "  ${GREEN}[2]${NC} 按 Commit Hash 回退"
    printf "请选择 [1-2]: "
    read -r RB_CHOICE

    case "$RB_CHOICE" in
        2)
            echo -e "${YELLOW}最近的 10 个提交记录：${NC}"
            git log -n 10 --oneline
            echo ""
            printf "请输入 Commit Hash: "
            read -r TARGET
            if [ -z "$TARGET" ]; then
                echo -e "${RED}输入为空，操作取消。${NC}"
                return
            fi
            ;;
        *)
            local tags=()
            while IFS= read -r tag; do
                tags+=("$tag")
            done < <(git tag --sort=-creatordate 2>/dev/null | head -n 10)

            if [ ${#tags[@]} -eq 0 ]; then
                echo -e "${RED}未检测到任何 Tag。${NC}"
                return
            fi

            echo -e "${YELLOW}最近的 ${#tags[@]} 个版本号 (Tags)：${NC}"
            for i in "${!tags[@]}"; do
                printf "  ${GREEN}[%d]${NC} %s\n" $((i+1)) "${tags[$i]}"
            done
            echo ""

            while true; do
                printf "请输入版本序号 (1-%d) 或直接输入版本号: " ${#tags[@]}
                read -r TARGET_INPUT
                TARGET_INPUT=$(echo "$TARGET_INPUT" | xargs)
                if [ -z "$TARGET_INPUT" ]; then
                    echo -e "${RED}输入为空，操作取消。${NC}"
                    return
                fi
                if [[ "$TARGET_INPUT" =~ ^[0-9]+$ ]]; then
                    if [ "$TARGET_INPUT" -ge 1 ] && [ "$TARGET_INPUT" -le ${#tags[@]} ]; then
                        TARGET="${tags[$((TARGET_INPUT-1))]}"
                        break
                    else
                        echo -e "${RED}序号超出范围。${NC}"
                        continue
                    fi
                else
                    TARGET="$TARGET_INPUT"
                    if git rev-parse -q --verify "refs/tags/$TARGET" >/dev/null 2>&1; then
                        break
                    else
                        echo -e "${RED}未找到名为 '$TARGET' 的 Tag。${NC}"
                        continue
                    fi
                fi
            done
            TARGET="tags/$TARGET"
            ;;
    esac

    echo -e "${CYAN}正在切换到 $TARGET ...${NC}"
    if git reset --hard "$TARGET" 2>/dev/null; then
        echo -e "${GREEN}切换成功！正在重新安装依赖...${NC}"
        clean_and_reinstall_deps --quiet --label "依赖" || return
        echo -e "${GREEN}操作完成！${NC}"
        printf "是否启动？[Y/n] "; read -r YN
        [ "$YN" != "n" ] && [ "$YN" != "N" ] && fn_start
    else
        echo -e "${RED}切换失败，请检查输入是否正确。${NC}"
    fi
}

fn_backup() {
    if ! check_installed; then echo -e "${RED}未安装${NC}"; return; fi
    mkdir -p "$BACKUP_DIR"
    NAME="ST_$(date +%Y%m%d_%H%M%S).tar.gz"
    echo -e "${CYAN}备份中...${NC}"
    cd "$INSTALL_DIR"
    tar czf "$BACKUP_DIR/$NAME" data/ 2>/dev/null
    echo -e "${GREEN}✓ $BACKUP_DIR/$NAME ($(du -h "$BACKUP_DIR/$NAME" | cut -f1))${NC}"
    printf "按回车返回..."; read -r _
}

fn_restore() {
    if ! check_installed; then echo -e "${RED}未安装${NC}"; return; fi
    FILES=$(ls "$BACKUP_DIR"/*.tar.gz 2>/dev/null || true)
    if [ -z "$FILES" ]; then
        echo -e "${RED}无备份文件，请将 .tar.gz 放到 SillyTavern_Backups/${NC}"
        printf "按回车返回..."; read -r _; return
    fi
    echo "可用备份:"
    i=1; for f in $FILES; do echo "  [$i] $(basename "$f")"; i=$((i+1)); done
    echo "  [0] 取消"
    printf "选择: "; read -r N
    { [ "$N" = "0" ] || [ -z "$N" ]; } && return
    FILE=$(echo "$FILES" | sed -n "${N}p")
    [ ! -f "$FILE" ] && { echo "无效"; return; }
    printf "确认覆盖当前数据？[y/N] "; read -r CF
    [ "$CF" != "y" ] && [ "$CF" != "Y" ] && return
    fn_stop 2>/dev/null || true
    cd "$INSTALL_DIR"; rm -rf data; tar xzf "$FILE"
    echo -e "${GREEN}✓ 已恢复${NC}"
}

# ---- 系统级清除 ----
fn_uninstall() {
    echo -e "${RED}${BOLD}═══════ 💀 系统级清除 ═══════${NC}"
    echo ""
    echo -e "${RED}这将完全清除 Termux 所有数据！${NC}"
    echo -e "${YELLOW}等同于：设置 → 应用 → Termux → 清除数据${NC}"
    echo ""
    printf "输入 ${RED}YES${NC} 确认: "
    read -r CF

    [ "$CF" != "YES" ] && { echo "已取消"; return; }

    echo -e "${YELLOW}5 秒后执行，Ctrl+C 可取消...${NC}"
    sleep 5

    rm -rf /data/data/com.termux/files/*
    rm -rf /data/data/com.termux/cache/*
    rm -rf /sdcard/Android/data/com.termux/*

    echo -e "${GREEN}✅ 已清除所有数据${NC}"
    echo -e "${YELLOW}请退出 Termux 重新打开${NC}"
    exit 0
}

# ======================================
# 自动菜单安装
# ======================================
setup_auto_menu() {
    if [ ! -f "$SCRIPT_PATH" ] || [ "$(readlink -f "$0")" != "$SCRIPT_PATH" ]; then
        cp "$0" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
    fi

    if ! grep -q "st.sh" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo '# 🌀 淡蓝酒馆自动菜单' >> "$HOME/.bashrc"
        echo 'if [ -f "$HOME/st.sh" ] && [[ $- == *i* ]]; then bash "$HOME/st.sh"; fi' >> "$HOME/.bashrc"
    fi
}

# ======================================
# 主入口
# ======================================
if ! check_installed; then
    do_install
    setup_auto_menu
    header
    show_menu
else
    setup_auto_menu
    auto_disable_lan_on_start
    header
    show_menu
fi

# 主循环
while true; do
    printf "请输入选项 : "
    read -r CHOICE
    case "$CHOICE" in
        1) fn_start;   header; show_menu ;;
        2) fn_stop;    header; show_menu ;;
        3) fn_restart; header; show_menu ;;
        4) fn_install_extension; header; show_menu ;;
        5) fn_config; header; show_menu ;;
        6) fn_update;  header; show_menu ;;
        7) fn_logs;    header; show_menu ;;
        8) fn_rollback; header; show_menu ;;
        9) fn_clean;   header; show_menu ;;
        10) fn_foxium; header; show_menu ;;
        11) fn_backup;  header; show_menu ;;
        12) fn_restore; header; show_menu ;;
        13) fn_reinstall_deps; header; show_menu ;;
        y|Y) fn_lan_on; header; show_menu ;;
        n|N) fn_lan_off; header; show_menu ;;
        m|M) fn_set_password; header; show_menu ;;
        99) fn_uninstall ;;
        0) echo "👋 再见~"; exit 0 ;;
        *)
            echo -e "${RED}无效选项: $CHOICE${NC}"
            echo -e "${YELLOW}提示：请直接输入数字或字母，不要按方向键${NC}"
            printf "按回车键继续..."
            read -r _
            header
            show_menu
            ;;
    esac
done