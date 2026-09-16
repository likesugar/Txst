#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  淡蓝酒馆 · 安装器
#  职责：
#    1. 检查并安装运行环境（git / nodejs-lts / net-tools）
#    2. 复制模块到 ~/st/lib
#    3. 创建 ~/st.sh 启动器
#    4. 写入 ~/.bashrc 自动菜单
#    5. 启动控制面板
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

echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║      淡蓝酒馆 · 安装器               ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"

# ======================================
# 1. 存储权限检查
# ======================================
check_storage() {
    local STORAGE_DIR="$HOME/storage/shared"

    if [ ! -d "$STORAGE_DIR" ]; then
        echo -e "${YELLOW}⚠️ 未检测到存储权限${NC}"
        printf "  是否现在运行 termux-setup-storage？[y/N]: "
        read -r PERM_CHOICE

        case "$PERM_CHOICE" in
            y|Y)
                echo -e "${CYAN}正在请求存储权限...${NC}"
                termux-setup-storage
                local WAIT=0
                while [ ! -d "$STORAGE_DIR" ] && [ $WAIT -lt 10 ]; do
                    sleep 1
                    WAIT=$((WAIT + 1))
                done
                if [ ! -d "$STORAGE_DIR" ]; then
                    echo -e "${RED}✗ 授权超时，请手动运行 termux-setup-storage 后重试${NC}"
                    exit 1
                fi
                echo -e "${GREEN}✓ 存储权限已获取${NC}"
                ;;
            *)
                echo -e "${RED}✗ 未授权存储权限，无法继续${NC}"
                exit 1
                ;;
        esac
    else
        echo -e "${GREEN}✓ 存储权限已就绪${NC}"
    fi
}

# ======================================
# 2. 安装运行环境（git / node / npm）
# ======================================
install_runtime() {
    echo -e "${CYAN}[1/4] 检查运行环境...${NC}"

    local need_install=0
    command -v git  >/dev/null 2>&1 || need_install=1
    command -v node >/dev/null 2>&1 || need_install=1
    command -v npm  >/dev/null 2>&1 || need_install=1

    if [ "$need_install" = "0" ]; then
        echo -e "${GREEN}✓ 运行环境已就绪${NC}"
        echo -e "    Node.js $(node -v)"
        return 0
    fi

    echo -e "${YELLOW}未检测到完整运行环境，正在安装...${NC}"
    echo -e "${CYAN}（约 1-2 分钟）${NC}"
    echo ""

    # ---- 配置清华源 ----
    if [ -f "$PREFIX/etc/apt/sources.list" ]; then
        cp "$PREFIX/etc/apt/sources.list" "$PREFIX/etc/apt/sources.list.bak" 2>/dev/null || true
        sed -i 's@packages.termux.dev@mirrors.tuna.tsinghua.edu.cn/termux@' "$PREFIX/etc/apt/sources.list" 2>/dev/null || true
    fi
    pkg update -y 2>/dev/null || pkg update -y

    # ---- 装包 ----
    pkg install -y git nodejs-lts net-tools 2>&1 | tail -5

    # ---- 独立验证 ----
    local missing=()
    command -v git  >/dev/null 2>&1 || missing+=("git")
    command -v node >/dev/null 2>&1 || missing+=("nodejs-lts")
    command -v npm  >/dev/null 2>&1 || missing+=("npm")

    if [ ${#missing[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}✗ 环境安装失败，缺少：${missing[*]}${NC}"
        echo -e "${YELLOW}请手动执行：${NC}"
        echo -e "  ${CYAN}pkg install -y git nodejs-lts net-tools${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ 运行环境安装完成${NC}"
    echo -e "    Node.js $(node -v)"
    echo -e "    npm $(npm -v)"
}

# ======================================
# 3. 复制模块
# ======================================
install_modules() {
    echo -e "${CYAN}[2/4] 安装模块到 $LIB_DIR ...${NC}"

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

# ======================================
# 4. 创建启动器
# ======================================
create_launcher() {
    echo -e "${CYAN}[3/4] 创建启动器 $LAUNCHER ...${NC}"

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

while IFS= read -r module; do
    [ -f "$module" ] || continue
    # shellcheck source=/dev/null
    source "$module"
done < <(ls -1 "$LIB_DIR"/*.sh 2>/dev/null | sort -V)

main_loop
LAUNCHER_EOF

    chmod +x "$LAUNCHER"
    echo -e "${GREEN}✓ 启动器已创建${NC}"
}

# ======================================
# 5. 配置自动菜单
# ======================================
setup_auto_menu() {
    echo -e "${CYAN}[4/4] 配置 Termux 自动菜单 ...${NC}"

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

# ======================================
# 主流程
# ======================================
check_storage
install_runtime
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
echo -e "${CYAN}正在启动控制面板...${NC}"
sleep 1

# 自动进入面板
if [ -f "$LAUNCHER" ]; then
    bash "$LAUNCHER"
else
    echo -e "${RED}✗ 启动器不存在，请手动运行 bash ~/st.sh${NC}"
fi