#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  模块 8 · Foxium
#  职责：Foxium 工具箱下载与启动
#  依赖：0_core.sh（颜色/工具函数）
#==========================================================================

# ======================================
# Foxium 下载地址（多镜像）
# ======================================
FOXIUM_URLS=(
    "https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
    "https://gh-proxy.com/https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
    "https://ghproxy.net/https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
    "https://ghfast.top/https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
)

# ======================================
# 下载 Foxium（使用 node 内置 https，无需 curl/wget）
# 用法: download_foxium [dest]
# 返回: 0 成功 / 1 失败
# ======================================
download_foxium() {
    local dest="${1:-$HOME/ffss.sh}"
    local URL
    for URL in "${FOXIUM_URLS[@]}"; do
        echo -e "  → 尝试: $(echo "$URL" | cut -d'/' -f3)"
        if node -e '
const https = require("https");
const fs = require("fs");
const url = process.argv[1];
const dest = process.argv[2];
function get(u) {
  https.get(u, res => {
    if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
      return get(res.headers.location);
    }
    if (res.statusCode !== 200) process.exit(1);
    const f = fs.createWriteStream(dest);
    res.pipe(f);
    f.on("finish", () => { f.close(); process.exit(0); });
  }).on("error", () => process.exit(1));
}
get(url);
' "$URL" "$dest" && [ -s "$dest" ]; then
            chmod +x "$dest"
            return 0
        fi
        rm -f "$dest" 2>/dev/null
    done
    return 1
}

# ======================================
# Foxium 工具箱菜单入口
# ======================================
fn_foxium() {
    echo -e "${CYAN}${BOLD}═══════ 🦊 Foxium 工具箱 ═══════${NC}"
    echo ""

    cd "$HOME" || return

    # ---- 已安装则直接启动 ----
    if [ -f "$HOME/ffss.sh" ] && [ -s "$HOME/ffss.sh" ]; then
        echo -e "${GREEN}✅ 已安装 Foxium 工具箱${NC}"
        echo ""
        echo -e "${CYAN}正在启动 Foxium 工具箱...${NC}"
        echo ""
        bash "$HOME/ffss.sh"
        return
    fi

    # ---- 未安装则下载 ----
    echo -e "${CYAN}正在下载 Foxium 工具箱...${NC}"

    if download_foxium "$HOME/ffss.sh"; then
        echo -e "${GREEN}✅ Foxium 工具箱已安装到 ~/ffss.sh${NC}"
        echo -e "${CYAN}正在启动...${NC}"
        echo ""
        bash "$HOME/ffss.sh"
    else
        echo -e "${RED}❌ 下载失败，请检查网络连接${NC}"
        echo -e "${YELLOW}💡 可尝试手动执行:${NC}"
        echo -e "  ${CYAN}curl -L https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh -o ~/ffss.sh && bash ~/ffss.sh${NC}"
        printf "\n按回车返回..."
        read -r _
    fi
}