#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  20_install.sh — 首次安装（存储授权 → 国内镜像 → 克隆 → 依赖 → 瘦身）
#==========================================================================

do_install() {
    local STORAGE_DIR="$HOME/storage/shared"

    # ---- 存储权限 ----
    if [ ! -d "$STORAGE_DIR" ]; then
        clear
        warn "${YELLOW}⚠️ 未检测到存储权限（目录 $STORAGE_DIR 不存在）${NC}"
        warn "${YELLOW}   Termux 需要访问外部存储才能保存角色卡、聊天记录等数据。${NC}"
        echo ""
        echo -e "  是否现在运行 ${CYAN}termux-setup-storage${NC} 授权？"
        echo -e "  （会弹出系统权限请求，请点击\"允许\"）"
        printf "  输入 ${GREEN}[y]${NC} 立即授权，${RED}[n]${NC} 退出安装: "
        read -r PERM_CHOICE

        case "$PERM_CHOICE" in
            y|Y)
                info "${CYAN}正在请求存储权限...${NC}"
                termux-setup-storage
                info "${CYAN}等待授权完成（最多10秒）...${NC}"
                local WAIT=0
                while [ ! -d "$STORAGE_DIR" ] && [ $WAIT -lt 10 ]; do
                    sleep 1
                    WAIT=$((WAIT + 1))
                done
                if [ ! -d "$STORAGE_DIR" ]; then
                    err "${RED}✗ 授权超时或未成功，请手动运行 termux-setup-storage 后重试。${NC}"
                    exit 1
                else
                    ok "${GREEN}✓ 存储权限已获取${NC}"
                fi
                ;;
            *)
                err "${RED}✗ 未授权存储权限，无法继续安装。${NC}"
                warn "${YELLOW}请稍后手动运行 termux-setup-storage，再重新执行本脚本。${NC}"
                exit 1
                ;;
        esac
    else
        ok "${GREEN}✓ 存储权限已就绪${NC}"
    fi

    clear
    echo "   淡蓝酒馆 · 首次安装"
    echo "  ========================"
    echo ""

    # ---- 1. apt 镜像 ----
    echo "[1/6] 配置国内镜像..."
    if [ -f "$PREFIX/etc/apt/sources.list" ]; then
        cp "$PREFIX/etc/apt/sources.list" "$PREFIX/etc/apt/sources.list.bak" 2>/dev/null || true
        sed -i 's@packages.termux.dev@mirrors.tuna.tsinghua.edu.cn/termux@' "$PREFIX/etc/apt/sources.list" 2>/dev/null || true
    fi
    pkg update -y 2>/dev/null || pkg update -y
    ok "  ✓ Termux → 清华镜像"

    # ---- 2. 运行环境 ----
    echo "[2/6] 安装运行环境..."
    pkg install -y git nodejs-lts net-tools 2>/dev/null || { err "${RED}  ✗ 依赖安装失败${NC}"; return 1; }
    ok "  ✓ Node.js $(node -v)"
    ok "  ✓ ifconfig 已安装"

    # ---- 3. npm 加速 ----
    echo "[3/6] 配置 npm 加速..."
    npm config set registry https://registry.npmmirror.com 2>/dev/null
    ok "  ✓ npm → npmmirror"
# 关闭 npm 更新提示（避免每次 npm 操作弹版本通知）
grep -q "update-notifier=false" "$HOME/.npmrc" 2>/dev/null \
    || echo "update-notifier=false" >> "$HOME/.npmrc"
    # ---- 4. 克隆酒馆 ----
    echo "[4/6] 下载 SillyTavern（国内多源自动切换）..."
    rm -rf "$INSTALL_DIR" 2>/dev/null
    local OK=0
    local URLS=(
        "https://gh-proxy.com/https://github.com/SillyTavern/SillyTavern"
        "https://ghproxy.net/https://github.com/SillyTavern/SillyTavern"
        "https://ghfast.top/https://github.com/SillyTavern/SillyTavern"
        "https://github.com/SillyTavern/SillyTavern"
    )
    for URL in "${URLS[@]}"; do
        echo -e "  → 尝试: $(echo "$URL" | cut -d'/' -f3)"
        if git clone "$URL" -b staging "$INSTALL_DIR" --depth 1 2>/dev/null; then
            ok "  ✓ staging 分支"; OK=1; break
        fi
    done
    if [ "$OK" != "1" ]; then
        err "${RED}  ✗ 克隆失败，请检查网络后重试${NC}"
        return 1
    fi
    cd "$INSTALL_DIR"
    git remote set-url origin https://github.com/SillyTavern/SillyTavern 2>/dev/null || true

    # ---- 5. 依赖 ----
    echo "[5/6] 清理旧依赖并重新安装（约 1-2 分钟）..."
    clean_and_reinstall_deps --clean-cache --label "依赖" || return 1

    echo "[5.5/6] 自动清理残余文件..."
    cd "$INSTALL_DIR"
    rm -rf "$HOME/.npm" 2>/dev/null
    rm -f .*.tmp .*.swp .*.swo .*~ *~ 2>/dev/null
    ok "  ✓ 清理完成"

    echo "[5.6/6] git / node 瘦身..."
    slim_git_node

    mkdir -p "$BACKUP_DIR"

    # ---- 6. Foxium 预安装 ----
    echo ""
    info "${CYAN}🦊 正在预安装 Foxium 工具箱...${NC}"
    local FOX_OK=0
    if download_foxium "$HOME/ffss.sh"; then
        ok "${GREEN}✅ Foxium 工具箱已预安装到 ~/ffss.sh${NC}"
        FOX_OK=1
    else
        warn "${YELLOW}⚠️ Foxium 预安装失败，可在菜单中按 [7] 重新下载${NC}"
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

    if [ "$FOX_OK" = "1" ]; then
        info "${CYAN}🦊 Foxium 工具箱已准备就绪，正在启动...${NC}"
        echo ""
        sleep 1
        bash "$HOME/ffss.sh"
    else
        warn "${YELLOW}💡 Foxium 工具箱未预安装成功，可在菜单中按 [7] 重新下载${NC}"
        sleep 2
    fi
}
