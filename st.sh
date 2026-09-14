#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  淡蓝酒馆 · 启动器
#  职责：加载 ~/st/lib 下所有模块，进入主循环
#  说明：使用 sort -V 排序，确保 10_menu.sh 排在 9_uninstall.sh 之后
#==========================================================================

# ---- 定位模块目录 ----
if [ -d "$HOME/st/lib" ]; then
    LIB_DIR="$HOME/st/lib"
elif [ -d "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib" ]; then
    LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
else
    echo "错误：未找到模块目录 lib，请先运行 install.sh"
    exit 1
fi

# ---- 按版本号顺序加载模块 ----
while IFS= read -r module; do
    [ -f "$module" ] || continue
    # shellcheck source=/dev/null
    source "$module"
done < <(ls -1 "$LIB_DIR"/*.sh 2>/dev/null | sort -V)

# ---- 进入主循环 ----
main_loop