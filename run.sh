#!/data/data/com.termux/files/usr/bin/bash
set -e

REPO="https://github.com/likesugar/Txst.git"
TMP="$HOME/.st-manager-src"

# 先确保有 git（没有就装），否则无法 clone
if ! command -v git >/dev/null 2>&1; then
    echo "→ 首次运行，安装 git..."
    pkg install -y git
fi

echo "→ 拉取仓库..."
rm -rf "$TMP"
git clone --depth=1 "$REPO" "$TMP"

echo "→ 安装模块..."
cd "$TMP"
bash install.sh

echo "→ 启动面板..."
bash "$HOME/st.sh"
