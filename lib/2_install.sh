#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  模块 2 · 首次安装
#  职责：安装 Termux 环境、克隆酒馆源码、安装依赖
#  依赖：0_core.sh（常量/颜色/工具函数）、1_service.sh（启动）、3_deps.sh（依赖安装）
#==========================================================================

# ======================================
# 首次安装
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
    echo "   淡蓝酒馆 · 首次安装"
    echo "  ========================"
    echo ""

    # ---- [1/6] 配置国内镜像 ----
    echo "[1/6] 配置国内镜像..."
    if [ -f "$PREFIX/etc/apt/sources.list" ]; then
        cp "$PREFIX/etc/apt/sources.list" "$PREFIX/etc/apt/sources.list.bak" 2>/dev/null || true
        sed -i 's@packages.termux.dev@mirrors.tuna.tsinghua.edu.cn/termux@' "$PREFIX/etc/apt/sources.list" 2>/dev/null || true
    fi
    pkg update -y 2>/dev/null || pkg update -y
    echo "  ✓ Termux → 清华镜像"

    # ---- [2/6] 安装运行环境 ----
    echo "[2/6] 安装运行环境..."
    pkg install -y git nodejs-lts net-tools 2>/dev/null || { echo -e "${RED}  ✗ 依赖安装失败${NC}"; return 1; }
    echo "  ✓ Node.js $(node -v)"
    echo "  ✓ ifconfig 已安装"

    # ---- [3/6] 配置 npm 加速 ----
    echo "[3/6] 配置 npm 加速..."
    npm config set registry https://registry.npmmirror.com
    export NPM_CONFIG_REGISTRY=https://registry.npmmirror.com
    export NODE_OPTIONS="--max-old-space-size=512"
    echo "  ✓ npm → 淘宝镜像"

    # ---- [4/6] 下载酒馆源码 ----
    echo "[4/6] 下载酒馆源码..."
    cd ~ || return 1
    local MIRRORS="
https://gh-proxy.com/https://github.com/SillyTavern/SillyTavern
https://gh.xiu2.xyz/https://github.com/SillyTavern/SillyTavern
https://github.com/SillyTavern/SillyTavern
"
    local OK=0
    local URL
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
    cd "$INSTALL_DIR" || return 1
    git remote set-url origin https://github.com/SillyTavern/SillyTavern 2>/dev/null || true

    # ---- [5/6] 清理旧依赖并重新安装 ----
    echo "[5/6] 清理旧依赖并重新安装（约 1-2 分钟）..."
    clean_and_reinstall_deps --clean-cache --label "依赖" || return 1

    # ---- [5.5/6] 自动清理残余文件 ----
    echo "[5.5/6] 自动清理残余文件..."
    cd "$INSTALL_DIR" || return 1
    rm -rf "$HOME/.npm" 2>/dev/null
    rm -f .*.tmp .*.swp .*.swo .*~ *~ 2>/dev/null
    echo "  ✓ 清理完成"

    # ---- [5.6/6] git / node 瘦身 ----
    echo "[5.6/6] git / node 瘦身..."
    slim_git_node

    mkdir -p "$BACKUP_DIR"

    # ---- Foxium 预安装 ----
    echo ""
    echo -e "${CYAN}🦊 正在预安装 Foxium 工具箱...${NC}"
    local FOX_OK=0
    if download_foxium "$HOME/ffss.sh"; then
        echo -e "${GREEN}✅ Foxium 工具箱已预安装到 ~/ffss.sh${NC}"
        FOX_OK=1
    else
        echo -e "${YELLOW}⚠️ Foxium 预安装失败，可在菜单中按 [7] 重新下载${NC}"
    fi

    echo ""
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║    安装完成！                     ║"
    echo "  ╚══════════════════════════════════════╝"
    echo ""
    echo "  💡 现在输入 1 启动酒馆"
    echo "  💡 输入 y 开启局域网访问"
    echo "  💡 输入 m 设置密码验证"
    echo "  💡 输入 5 查看推荐配置"
    echo "  💡 输入 7 使用 Foxium 工具箱"
    echo ""

    # ---- 启动 Foxium 或提示 ----
    if [ "$FOX_OK" = "1" ]; then
        echo -e "${CYAN}🦊 Foxium 工具箱已准备就绪，正在启动...${NC}"
        echo ""
        sleep 1
        bash "$HOME/ffss.sh"
    else
        echo -e "${YELLOW}💡 Foxium 工具箱未预安装成功，可在菜单中按 [7] 重新下载${NC}"
        sleep 2
    fi
}