#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  淡蓝酒馆 · 安装器
#==========================================================================

set -e

SCRIPT_DIR="${TMP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
ST_HOME="$HOME/st"
LIB_DIR="$ST_HOME/lib"
LAUNCHER="$HOME/st.sh"

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
# 1. 存储权限
# ======================================
check_storage() {
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
                    sleep 1; WAIT=$((WAIT + 1))
                done
                [ ! -d "$STORAGE_DIR" ] && { echo -e "${RED}✗ 授权超时${NC}"; exit 1; }
                echo -e "${GREEN}✓ 存储权限已获取${NC}"
                ;;
            *) echo -e "${RED}✗ 未授权，退出${NC}"; exit 1 ;;
        esac
    else
        echo -e "${GREEN}✓ 存储权限已就绪${NC}"
    fi
}

# ======================================
# 2. 确保运行环境（关键：已装则跳过）
# ======================================
ensure_runtime() {
    echo ""
    echo -e "${CYAN}[1/4] 检查运行环境...${NC}"

    # ---- 核心：已装则跳过 ----
    if command -v git >/dev/null 2>&1 && \
       command -v node >/dev/null 2>&1 && \
       command -v npm >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 运行环境已就绪（Node.js $(node -v)）${NC}"
        return 0
    fi

    # ---- 未装则装 ----
    echo -e "${YELLOW}未检测到完整运行环境，正在安装...${NC}"
    echo -e "${CYAN}（约 1-2 分钟）${NC}"
    echo ""

    if [ -f "$PREFIX/etc/apt/sources.list" ]; then
        cp "$PREFIX/etc/apt/sources.list" "$PREFIX/etc/apt/sources.list.bak" 2>/dev/null || true
        sed -i 's@packages.termux.dev@mirrors.tuna.tsinghua.edu.cn/termux@' "$PREFIX/etc/apt/sources.list" 2>/dev/null || true
    fi
    pkg update -y 2>/dev/null || pkg update -y
    pkg install -y git nodejs-lts net-tools 2>&1 | tail -5

    # ---- 独立验证 ----
    local missing=()
    command -v git  >/dev/null 2>&1 || missing+=("git")
    command -v node >/dev/null 2>&1 || missing+=("nodejs-lts")
    command -v npm  >/dev/null 2>&1 || missing+=("npm")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}✗ 环境安装失败，缺少：${missing[*]}${NC}"
        echo -e "${YELLOW}请手动执行：pkg install -y git nodejs-lts net-tools${NC}"
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
    echo ""
    echo -e "${CYAN}[2/4] 安装模块到 $LIB_DIR ...${NC}"

    mkdir -p "$LIB_DIR"

    local SRC_LIB=""
    if [ -d "$SCRIPT_DIR/lib" ]; then
        SRC_LIB="$SCRIPT_DIR/lib"
    elif [ -d "$SCRIPT_DIR" ] && ls "$SCRIPT_DIR"/*_*.sh >/dev/null 2>&1; then
        SRC_LIB="$SCRIPT_DIR"
    else
        echo -e "${RED}✗ 未找到模块目录${NC}"
        echo -e "${YELLOW}  SCRIPT_DIR = $SCRIPT_DIR${NC}"
        exit 1
    fi

    echo -e "  源目录：${CYAN}$SRC_LIB${NC}"

    if [ "$SRC_LIB" = "$LIB_DIR" ]; then
        echo -e "  ${YELLOW}源目录与目标目录相同，跳过复制${NC}"
    else
        cp -f "$SRC_LIB"/*.sh "$LIB_DIR/" 2>/dev/null || true
    fi

    chmod +x "$LIB_DIR/"*.sh 2>/dev/null || true

    echo -e "${GREEN}✓ 已安装模块：${NC}"
    ls -1 "$LIB_DIR" | sort -V | sed 's/^/    /'
}

# ======================================
# 4. 创建启动器
# ======================================
create_launcher() {
    echo ""
    echo -e "${CYAN}[3/4] 创建启动器 $LAUNCHER ...${NC}"

    cat > "$LAUNCHER" << 'LAUNCHER_EOF'
#!/data/data/com.termux/files/usr/bin/bash
ST_HOME="$HOME/st"
LIB_DIR="$ST_HOME/lib"
[ ! -d "$LIB_DIR" ] && { echo "错误：未找到 $LIB_DIR"; exit 1; }
while IFS= read -r module; do
    [ -f "$module" ] || continue
    source "$module"
done < <(ls -1 "$LIB_DIR"/*.sh 2>/dev/null | sort -V)
main_loop
LAUNCHER_EOF

    chmod +x "$LAUNCHER"
    echo -e "${GREEN}✓ 启动器已创建${NC}"
}

# ======================================
# 5. 自动菜单
# ======================================
setup_auto_menu() {
    echo ""
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
ensure_runtime
install_modules
create_launcher
setup_auto_menu

echo ""
echo -e "${GREEN}${BOLD}✅ 安装完成！${NC}"
echo ""
echo -e "  ${CYAN}启动方式：${NC}"
echo -e "    ${GREEN}bash ~/st.sh${NC}   （或重开 Termux 自动弹出）"
echo ""
echo -e "${CYAN}正在启动控制面板...${NC}"
sleep 1

if [ -f "$LAUNCHER" ]; then
    bash "$LAUNCHER"
else
    echo -e "${RED}✗ 启动器不存在，请手动运行 bash ~/st.sh${NC}"
fi