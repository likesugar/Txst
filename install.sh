#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  淡蓝酒馆管理器 · 模块安装/更新脚本
#  用法: 把本文件夹放到 Termux 任意目录，执行 bash install.sh
#==========================================================================
set -e

SRC="$(cd "$(dirname "$0")" && pwd)"

[ -d "$SRC/lib" ] || { echo "✗ 未找到 lib/ 模块目录"; exit 1; }

# 1) 模块落到 ~/st/lib
mkdir -p "$HOME/st"
rm -rf "$HOME/st/lib"
cp -r "$SRC/lib" "$HOME/st/lib"
chmod +x "$HOME/st/lib"/*.sh 2>/dev/null || true

# 2) 启动器 ~/st.sh
cp "$SRC/st.sh" "$HOME/st.sh"
chmod +x "$HOME/st.sh"

# 3) .bashrc 自动弹出菜单（幂等）
if ! grep -q "st.sh" "$HOME/.bashrc" 2>/dev/null; then
    printf '\n# 淡蓝酒馆自动菜单\n' >> "$HOME/.bashrc"
    printf 'if [ -f "$HOME/st.sh" ] && [[ $- == *i* ]]; then bash "$HOME/st.sh"; fi\n' >> "$HOME/.bashrc"
fi
# 4) 创建隐藏备份目录
rm -rf ~/storage

echo "✅ 模块安装完成 → ~/st/lib"
echo "   输入 st.sh 或重开 Termux 进入控制面板"
