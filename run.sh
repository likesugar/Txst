#!/data/data/com.termux/files/usr/bin/bash
set -e

REPO="https://github.com/likesugar/Txst.git"
TMP="$HOME/.st-manager-src"

# 依赖检查
for cmd in git node npm; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "✗ 缺少 $cmd，请先执行: pkg install git nodejs-lts"
        exit 1
    }
done

echo "→ 拉取仓库..."
rm -rf "$TMP"
git clone --depth=1 "$REPO" "$TMP"

echo "→ 安装模块..."
cd "$TMP"
bash install.sh

echo "→ 清理临时文件..."
cd "$HOME"
rm -rf "$TMP"

echo "→ 启动面板..."
bash "$HOME/st.sh"
