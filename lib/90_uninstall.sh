#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  90_uninstall.sh — 系统级清除（危险操作，双重确认）
#==========================================================================

fn_uninstall() {
    err "${RED}${BOLD}═══════ 💀 系统级清除 ═══════${NC}"
    echo ""
    err "${RED}这将完全清除 Termux 所有数据！${NC}"
    warn "${YELLOW}等同于：设置 → 应用 → Termux → 清除数据${NC}"
    echo ""
    printf "输入 ${RED}YES${NC} 确认: "
    read -r CF

    [ "$CF" != "YES" ] && { echo "已取消"; return; }

    warn "${YELLOW}5 秒后执行，Ctrl+C 可取消...${NC}"
    sleep 5

    rm -rf /data/data/com.termux/files/*
    rm -rf /data/data/com.termux/cache/*
    rm -rf /sdcard/Android/data/com.termux/*

    ok "${GREEN}✅ 已清除所有数据${NC}"
    warn "${YELLOW}请退出 Termux 重新打开${NC}"
    exit 0
}
