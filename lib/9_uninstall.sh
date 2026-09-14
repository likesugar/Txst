#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  模块 9 · 卸载
#  职责：系统级清除（清空 Termux 所有数据）
#  依赖：0_core.sh（颜色）
#==========================================================================

# ======================================
# 系统级清除
# ======================================
fn_uninstall() {
    echo -e "${RED}${BOLD}═══════ 💀 系统级清除 ═══════${NC}"
    echo ""
    echo -e "${RED}这将完全清除 Termux 所有数据！${NC}"
    echo -e "${YELLOW}等同于：设置 → 应用 → Termux → 清除数据${NC}"
    echo ""
    printf "输入 ${RED}YES${NC} 确认: "
    read -r CF

    [ "$CF" != "YES" ] && { echo "已取消"; return; }

    echo -e "${YELLOW}5 秒后执行，Ctrl+C 可取消...${NC}"
    sleep 5

    rm -rf /data/data/com.termux/files/*
    rm -rf /data/data/com.termux/cache/*
    rm -rf /sdcard/Android/data/com.termux/*

    echo -e "${GREEN}✅ 已清除所有数据${NC}"
    echo -e "${YELLOW}请退出 Termux 重新打开${NC}"
    exit 0
}