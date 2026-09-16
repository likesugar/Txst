#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  模块 2 · 首次安装 / 酒馆安装
#  职责：环境配置（首次）+ 酒馆安装（按 [4]）
#  依赖：0_core.sh（常量/颜色/工具函数）、1_service.sh（启动）、3_deps.sh（依赖安装）
#==========================================================================

# ======================================
# 菜单入口：安装 / 重装酒馆
# ======================================
fn_install_tavern() {
    if check_installed; then
        echo ""
        echo -e "${YELLOW}⚠️ SillyTavern 已安装${NC}"
        echo ""
        echo -e "  ${CYAN}请选择：${NC}"
        echo -e "    ${GREEN}[9]${NC}  更新到最新版本"
        echo -e "    ${YELLOW}[99] → [2]${NC}  卸载后重新安装"
        echo ""
        printf "按回车返回..."
        read -r _
        return
    fi

    install_tavern_only
}

# ======================================
# 仅安装酒馆本体
# ======================================
install_tavern_only() {
    # ---- 环境检查（缺了就给提示，不自动装）----
    local missing=()
    command_exists git  || missing+=("git")
    command_exists node || missing+=("nodejs-lts")
    command_exists npm  || missing+=("npm")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}✗ 缺少运行环境：${missing[*]}${NC}"
        echo -e "${YELLOW}请先执行完整安装补齐环境${NC}"
        printf "按回车返回..."
        read -r _
        return 1
    fi

    # ---- 存储权限检查 ----
    local STORAGE_DIR="$HOME/storage/shared"
    if [ ! -d "$STORAGE_DIR" ]; then
        echo -e "${YELLOW}⚠️ 未检测到存储权限${NC}"
        printf "  是否现在运行 termux-setup-storage？[y/N]: "
        read -r PERM_CHOICE
        case "$PERM_CHOICE" in
            y|Y)
                termux-setup-storage
                local WAIT=0
                while [ ! -d "$STORAGE_DIR" ] && [ $WAIT -lt 10 ]; do
                    sleep 1
                    WAIT=$((WAIT + 1))
                done
                [ ! -d "$STORAGE_DIR" ] && { echo -e "${RED}✗ 授权超时${NC}"; return 1; }
                ;;
            *) echo -e "${RED}✗ 未授权，退出${NC}"; return 1 ;;
        esac
    fi

    # ---- 已存在检查 ----
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}⚠️ $INSTALL_DIR 已存在${NC}"
        printf "是否删除并重新安装？[y/N]: "
        read -r CF
        [ "$CF" != "y" ] && [ "$CF" != "Y" ] && return 0
        fn_stop 2>/dev/null || true
        rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}✓ 已删除旧版本${NC}"
    fi

    echo ""
    echo -e "${CYAN}${BOLD}═══════ 📦 安装 SillyTavern ═══════${NC}"
    echo ""

    # ---- [1/3] 克隆源码 ----
    echo "[1/3] 下载酒馆源码..."
    cd ~ || return 1
    local MIRRORS=(
        "https://gh-proxy.com/https://github.com/SillyTavern/SillyTavern"
        "https://gh.xiu2.xyz/https://github.com/SillyTavern/SillyTavern"
        "https://github.com/SillyTavern/SillyTavern"
    )
    local OK=0
    local URL
    for URL in "${MIRRORS[@]}"; do
        echo "  → $URL"
        if git clone "$URL" -b release "$INSTALL_DIR" --depth 1 2>/dev/null; then
            echo "  ✓ release 分支"; OK=1; break
        fi
        if git clone "$URL" -b staging "$INSTALL_DIR" --depth 1 2>/dev/null; then
            echo "  ✓ staging 分支"; OK=1; break
        fi
    done
    if [ "$OK" != "1" ]; then
        echo -e "${RED}  ✗ 克隆失败，请检查网络${NC}"
        printf "按回车返回..."
        read -r _
        return 1
    fi
    cd "$INSTALL_DIR" || return 1
    git remote set-url origin https://github.com/SillyTavern/SillyTavern 2>/dev/null || true

    # ---- [2/3] 装依赖 ----
    echo "[2/3] 安装依赖（约 1-2 分钟）..."
    clean_and_reinstall_deps --clean-cache --label "依赖" || return 1

    # ---- [3/3] 瘦身 ----
    echo "[3/3] 瘦身..."
    cd "$INSTALL_DIR" || return 1
    rm -rf "$HOME/.npm" 2>/dev/null
    rm -f .*.tmp .*.swp .*.swo .*~ *~ 2>/dev/null
    slim_git_node

    mkdir -p "$BACKUP_DIR"

    echo ""
    echo -e "${GREEN}${BOLD}✅ SillyTavern 安装完成！${NC}"
    echo ""
    echo -e "${CYAN}💡 按 [1] 启动酒馆${NC}"
    echo -e "${CYAN}💡 按 [6] 应用推荐配置${NC}"
    echo -e "${CYAN}💡 按 [y] 开启局域网访问${NC}"
    echo ""
    printf "按回车返回..."
    read -r _
}

# ======================================
# 首次环境配置（不装酒馆）
# ======================================
do_install() {
    local STORAGE_DIR="$HOME/storage/shared"

    # ---- 存储权限检查 ----
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
    echo "   淡蓝酒馆 · 环境配置"
    echo "  ========================"
    echo ""

    # ---- [1/4] 配置国内镜像 ----
    echo "[1/4] 配置国内镜像..."
    if [ -f "$PREFIX/etc/apt/sources.list" ]; then
        cp "$PREFIX/etc/apt/sources.list" "$PREFIX/etc/apt/sources.list.bak" 2>/dev/null || true
        sed -i 's@packages.termux.dev@mirrors.tuna.tsinghua.edu.cn/termux@' "$PREFIX/etc/apt/sources.list" 2>/dev/null || true
    fi
    pkg update -y 2>/dev/null || pkg update -y
    echo "  ✓ Termux → 清华镜像"

    # ---- [2/4] 安装运行环境 ----
    echo "[2/4] 安装运行环境..."
    pkg install -y git nodejs-lts net-tools 2>/dev/null || { echo -e "${RED}  ✗ 依赖安装失败${NC}"; return 1; }
    echo "  ✓ Node.js $(node -v)"
    echo "  ✓ ifconfig 已安装"

    # ---- [3/4] 配置 npm 加速 ----
    echo "[3/4] 配置 npm 加速..."
    npm config set registry https://registry.npmmirror.com
    export NPM_CONFIG_REGISTRY=https://registry.npmmirror.com
    export NODE_OPTIONS="--max-old-space-size=512"
    echo "  ✓ npm → 淘宝镜像"

    # ---- [4/4] git / node 瘦身 ----
    echo "[4/4] git / node 瘦身..."
    slim_git_node

    echo ""
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║    环境配置完成！                 ║"
    echo "  ╚══════════════════════════════════════╝"
    echo ""
    echo -e "  ${YELLOW}💡 下一步：按 [4] 安装 SillyTavern${NC}"
    echo -e "  ${CYAN}💡 安装完成后再按 [1] 启动${NC}"
    echo ""
    printf "按回车返回菜单..."
    read -r _
}