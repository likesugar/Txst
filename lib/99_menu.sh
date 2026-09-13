#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  99_menu.sh — 面板显示 / 自动菜单 / 主入口
#==========================================================================

header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║      淡蓝酒馆 · Termux 控制面板      ║"
    echo "  ╚══════════════════════════════════════╝"
    printf '\033'
    status_text
}

show_menu() {
    echo -e "  ${BOLD}═══ 管理 ═══${NC}"
    echo -e "  ${GREEN}[1]${NC} 启动  ${GREEN}[2]${NC} 停止  ${GREEN}[3]${NC} 重启"
    echo -e "  ${GREEN}[4]${NC}⭐️扩展管理⭐️${GREEN}[5]${NC}✨️推荐配置✨️"
    echo ""
    echo -e "  ${BOLD}═══ 维护 ═══${NC}"
    echo -e "  ${BLUE}[6]${NC} 清理残余文件  ${BLUE}[7]${NC} Foxium工具箱"
    echo -e "  ${BLUE}[8]${NC} 更新  ${BLUE}[9]${NC} 日志  ${BLUE}[10]${NC} 版本回退/切换"
    echo ""
    echo -e "  ${BOLD}═══ 数据 ═══${NC}"
    echo -e "  ${YELLOW}[11]${NC} 备份  ${YELLOW}[12]${NC} 恢复  ${YELLOW}[13]${NC} 重装依赖"
    echo ""
    echo -e "  ${BOLD}═══ 局域网 ═══${NC}"
    if [ -f "$LAN_FLAG" ]; then
        echo -e "  ${GREEN}[y]${NC} 开启中 ${YELLOW}[n]${NC} 关闭 ${CYAN}[m]${NC} 密码验证: $(get_password_status)"
    else
        echo -e "  ${YELLOW}[y]${NC} 开启  ${GREEN}[n]${NC} 已关闭 ${CYAN}[m]${NC}密码验证: $(get_password_status)"
    fi
    echo ""
    echo -e "  ${BOLD}═══ 其他 ═══${NC}"
    echo -e "  ${RED}[99]${NC} 卸载  ${RED}[0]${NC} 退出"
    echo ""
}


# 确保 .bashrc 里有自动菜单入口（模块文件由 install.sh 安装）
setup_auto_menu() {
    if ! grep -q "st.sh" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo '# 淡蓝酒馆自动菜单' >> "$HOME/.bashrc"
        echo 'if [ -f "$HOME/st.sh" ] && [[ $- == *i* ]]; then bash "$HOME/st.sh"; fi' >> "$HOME/.bashrc"
    fi
}

main() {
    cd "$HOME" || exit 1

    if ! check_installed; then
        do_install
        setup_auto_menu
        rotate_logs
        header
        show_menu
    else
        setup_auto_menu

        # 每次打开面板时，默认关闭局域网（安全基线：回到仅本机访问）
        rm -f "$LAN_FLAG" 2>/dev/null
        if [ -f "$INSTALL_DIR/config.yaml" ]; then
            sed -i 's/^listen:.*/listen: false/' "$INSTALL_DIR/config.yaml" 2>/dev/null
            sed -i 's/^port:.*/port: 8000/' "$INSTALL_DIR/config.yaml" 2>/dev/null
        fi

        rotate_logs
        header
        show_menu
    fi

    # ---- 主循环 ----
    while true; do
        printf "请输入选项: "
        read -r CHOICE

        case "$CHOICE" in
            1)  fn_start;   header; show_menu ;;
            2)  fn_stop;    header; show_menu ;;
            3)  fn_restart; header; show_menu ;;
            4)  fn_install_extension; header; show_menu ;;
            5)  fn_config;  header; show_menu ;;
            6)  fn_clean;   header; show_menu ;;
            7)  fn_foxium;  header; show_menu ;;
            8)  fn_update;  header; show_menu ;;
            9)  fn_logs;    header; show_menu ;;
            10) fn_rollback; header; show_menu ;;
            11) fn_backup;   header; show_menu ;;
            12) fn_restore;  header; show_menu ;;
            13) fn_reinstall_deps; header; show_menu ;;
            y|Y) fn_lan_on;  header; show_menu ;;
            n|N) fn_lan_off; header; show_menu ;;
            m|M) fn_set_password; header; show_menu ;;
            99) fn_uninstall ;;
            0) echo "👋 再见~"; exit 0 ;;
            *)
                err "${RED}无效选项: $CHOICE${NC}"
                warn "${YELLOW}提示：请直接输入数字或字母，不要按方向键${NC}"
                printf "按回车键继续..."
                read -r _
                header
                show_menu
                ;;
        esac
    done
}
