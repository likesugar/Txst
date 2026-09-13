#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  淡蓝酒馆 · Termux 管理器 v3.0（模块化版）启动器
#  模块目录: ~/st/lib/  安装器: install.sh
#==========================================================================

ST_LIB="$HOME/st/lib"

# 未安装时，支持从脚本所在目录就地运行
if [ ! -d "$ST_LIB" ]; then
    HERE="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
    if [ -d "$HERE/lib" ]; then
        ST_LIB="$HERE/lib"
    else
        echo "✗ 未找到模块目录 ~/st/lib，请先运行 install.sh"
        exit 1
    fi
fi

# 按文件名序号加载模块（00 核心必须最先，99 菜单最后）
for _f in "$ST_LIB"/*.sh; do
    # shellcheck disable=SC1090
    . "$_f"
done
unset _f

main "$@"
