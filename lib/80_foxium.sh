#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  80_foxium.sh — Foxium 工具箱下载与启动
#==========================================================================

FOXIUM_URLS=(
    "https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
    "https://gh-proxy.com/https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
    "https://ghproxy.net/https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
    "https://ghfast.top/https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh"
)

download_foxium() {
    local dest="${1:-$HOME/ffss.sh}"
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

fn_foxium() {
    info "${CYAN}${BOLD}═══════ 🦊 Foxium 工具箱 ═══════${NC}"
    echo ""

    cd "$HOME" || return

    if [ -f "$HOME/ffss.sh" ] && [ -s "$HOME/ffss.sh" ]; then
        ok "${GREEN}✅ 已安装 Foxium 工具箱${NC}"
        echo ""
        info "${CYAN}正在启动 Foxium 工具箱...${NC}"
        echo ""
        bash "$HOME/ffss.sh"
    else
        warn "${YELLOW}未安装 Foxium 工具箱${NC}"
        echo ""
        printf "是否现在下载？[Y/n]: "
        read -r DL_NOW
        if [[ "$DL_NOW" != "n" && "$DL_NOW" != "N" ]]; then
            if ! command_exists node; then
                err "${RED}未安装 Node.js，无法下载${NC}"
                pause
                return
            fi
            echo -e "${CYAN}📥 正在下载 Foxium 工具箱...${NC}"
            if download_foxium "$HOME/ffss.sh"; then
                ok "${GREEN}✅ 下载完成${NC}"
                info "${CYAN}正在启动...${NC}"
                bash "$HOME/ffss.sh"
            else
                err "${RED}❌ 所有下载源均失败，请检查网络${NC}"
                echo ""
                info "${CYAN}可手动执行:${NC}"
                info "${CYAN}curl -L https://raw.githubusercontent.com/likesugar/Txst/main/ffss.sh -o ~/ffss.sh && bash ~/ffss.sh${NC}"
            fi
        fi
    fi

    echo ""
    pause
}
