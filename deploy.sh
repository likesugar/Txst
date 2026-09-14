#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  淡蓝酒馆 · 一键部署
#  用法：bash <(curl -sL https://raw.githubusercontent.com/likesugar/Txst/main/deploy.sh)
#==========================================================================

set -e

REPO="https://github.com/likesugar/Txst.git"
REPO_MIRROR="https://gh-proxy.com/https://github.com/likesugar/Txst.git"
REPO_MIRROR2="https://gh.xiu2.xyz/https://github.com/likesugar/Txst.git"
TMP_DIR="$HOME/.st-manager-tmp"

# ---- 颜色 ----
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║      淡蓝酒馆 · 一键部署             ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"

# ---- 检查 git ----
if ! command -v git >/dev/null 2>&1; then
    echo -e "${YELLOW}未检测到 git，正在安装...${NC}"
    pkg install -y git
fi

# ---- 克隆仓库（多镜像回退）----
echo -e "${CYAN}正在下载部署包...${NC}"
rm -rf "$TMP_DIR"

CLONED=0
for URL in "$REPO_MIRROR" "$REPO_MIRROR2" "$REPO"; do
    echo -e "  → 尝试: $(echo "$URL" | cut -d'/' -f3)"
    if git clone --depth 1 "$URL" "$TMP_DIR" 2>/dev/null; then
        CLONED=1
        break
    fi
    rm -rf "$TMP_DIR"
done

if [ "$CLONED" != "1" ]; then
    echo -e "${RED}✗ 下载失败，请检查网络${NC}"
    echo -e "${YELLOW}💡 可手动执行：${NC}"
    echo -e "  ${CYAN}git clone $REPO_MIRROR ~/.st-manager-tmp && bash ~/.st-manager-tmp/install.sh${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 下载完成${NC}"
echo ""

# ---- 执行安装 ----
if [ ! -f "$TMP_DIR/install.sh" ]; then
    echo -e "${RED}✗ 未找到 install.sh，仓库结构可能不正确${NC}"
    exit 1
fi

bash "$TMP_DIR/install.sh"

# ---- 清理临时目录 ----
rm -rf "$TMP_DIR"

echo ""
echo -e "${GREEN}${BOLD}✅ 部署完成！${NC}"
echo ""
echo -e "  ${CYAN}启动方式：${NC}"
echo -e "    ${GREEN}bash ~/st.sh${NC}   （或重开 Termux 自动弹出）"
echo ""