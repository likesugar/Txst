#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  淡蓝酒馆 · 安装器
#  职责：把模块复制到 ~/st/lib，创建 ~/st.sh 启动器
#==========================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ST_HOME="$HOME/st"
LIB_DIR="$ST_HOME/lib"
LAUNCHER="$HOME/st.sh"

# ---- 颜色 ----
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi
# ---- 输出辅助函数 ----
info()    { echo -e "${CYAN}$*${NC}"; }
success() { echo -e "${GREEN}$*${NC}"; }
warn()    { echo -e "${YELLOW}$*${NC}"; }
err()     { echo -e "${RED}$*${NC}" >&2; }
ok()      { echo -e "${GREEN}$*${NC}"; }
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║      淡蓝酒馆 · 安装器               ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"

# ---- 1. 检查存储权限 ----
check_storage() {
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
}

# ---- 2. 复制模块 ----
install_modules() {
    echo -e "${CYAN}[1/3] 安装模块到 $LIB_DIR ...${NC}"

    mkdir -p "$LIB_DIR"

    if [ ! -d "$SCRIPT_DIR/lib" ]; then
        echo -e "${RED}✗ 未找到 lib 目录: $SCRIPT_DIR/lib${NC}"
        exit 1
    fi

    cp -f "$SCRIPT_DIR/lib/"*.sh "$LIB_DIR/"
    chmod +x "$LIB_DIR/"*.sh

    echo -e "${GREEN}✓ 已安装模块：${NC}"
    ls -1 "$LIB_DIR" | sort -V | sed 's/^/    /'
}

# ---- 3. 创建启动器 ----
create_launcher() {
    echo -e "${CYAN}[2/3] 创建启动器 $LAUNCHER ...${NC}"

    cat > "$LAUNCHER" << 'LAUNCHER_EOF'
#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  淡蓝酒馆 · 启动器
#  加载 ~/st/lib 下的模块并进入面板
#==========================================================================

ST_HOME="$HOME/st"
LIB_DIR="$ST_HOME/lib"

if [ ! -d "$LIB_DIR" ]; then
    echo "错误：未找到模块目录 $LIB_DIR，请先运行 install.sh"
    exit 1
fi

# 按版本号顺序加载模块
while IFS= read -r module; do
    [ -f "$module" ] || continue
    # shellcheck source=/dev/null
    source "$module"
done < <(ls -1 "$LIB_DIR"/*.sh 2>/dev/null | sort -V)

# 进入主循环
main_loop
LAUNCHER_EOF

    chmod +x "$LAUNCHER"
    echo -e "${GREEN}✓ 启动器已创建${NC}"
}

# ---- 4. 配置自动菜单 ----
setup_auto_menu() {
    echo -e "${CYAN}[3/3] 配置 Termux 自动菜单 ...${NC}"

    if ! grep -q "st.sh" "$HOME/.bashrc" 2>/dev/null; then
        {
            echo ""
            echo '# 淡蓝酒馆自动菜单'
            echo 'if [ -f "$HOME/st.sh" ] && [[ $- == *i* ]]; then bash "$HOME/st.sh"; fi'
        } >> "$HOME/.bashrc"
        echo -e "${GREEN}✓ 已写入 ~/.bashrc${NC}"
    else
        echo -e "${YELLOW}  已存在自动菜单配置，跳过${NC}"
    fi
}

# ---- 主流程 ----
check_storage
install_modules
create_launcher
setup_auto_menu

echo ""
echo -e "${GREEN}${BOLD}✅ 安装完成！${NC}"
echo ""
echo -e "  ${CYAN}启动方式：${NC}"
echo -e "    ${GREEN}bash ~/st.sh${NC}   （或重开 Termux 自动弹出）"
echo ""
echo -e "  ${CYAN}模块目录：${NC}"
echo -e "    ${YELLOW}$LIB_DIR${NC}"
echo ""