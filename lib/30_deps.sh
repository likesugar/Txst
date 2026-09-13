#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  30_deps.sh — 依赖重装（Fix npm）
#==========================================================================

fn_reinstall_deps() {
    if ! check_installed; then
        err "${RED}SillyTavern 未安装，请先安装。${NC}"
        return
    fi

    info "${CYAN}${BOLD}═══════ 🔧 重装依赖 (Fix npm) ═══════${NC}"
    echo ""
    warn "${YELLOW}此操作将重新下载并安装 SillyTavern 的运行依赖。${NC}"
    warn "${YELLOW}安装完成后会自动进行极致瘦身，删除文档、测试文件等。${NC}"
    echo ""

    if [ -d "$INSTALL_DIR/node_modules" ]; then
        local current_size=$(du -sh "$INSTALL_DIR/node_modules" 2>/dev/null | cut -f1)
        info "${CYAN}当前 node_modules 大小: ${current_size}${NC}"
        echo ""
    fi

    printf "确认继续吗? [y/N]: "
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        warn "${YELLOW}操作已取消。${NC}"
        pause
        return
    fi

    if clean_and_reinstall_deps --clean-cache --label "依赖"; then
        fn_clean
        if [ -d "$INSTALL_DIR/node_modules" ]; then
            local final_size=$(du -sh "$INSTALL_DIR/node_modules" 2>/dev/null | cut -f1)
            echo ""
            info "${CYAN}📊 最终 node_modules 大小: ${final_size}${NC}"
        fi
        echo ""
        warn "${YELLOW}💡 建议重启酒馆以应用更改。${NC}"
        echo ""
        printf "是否立即启动酒馆？[Y/n]: "
        read -r START_NOW
        if [[ "$START_NOW" != "n" && "$START_NOW" != "N" ]]; then
            fn_start
        fi
    fi

    echo ""
    pause
}
