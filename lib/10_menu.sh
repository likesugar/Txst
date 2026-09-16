#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  模块 10 · 菜单
#  职责：面板显示与主循环
#  依赖：所有前置模块（0~9）
#  说明：本模块必须最后加载，因为它调用其他模块的函数
#==========================================================================

# ======================================
# 页头
# ======================================
header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║      淡蓝酒馆 · Termux 控制面板      ║"
    echo "  ╚══════════════════════════════════════╝"
    printf '\033[0m'
    status_text
}

# ======================================
# 主菜单
# ======================================
show_menu() {
    echo -e "  ${BOLD}═══ 管理 ═══${NC}"
    echo -e "  ${GREEN}[1]${NC} 启动  ${GREEN}[2]${NC} 停止  ${GREEN}[3]${NC} 重启  ${GREEN}[4]${NC} 安装"
    echo -e "  ${GREEN}[5]${NC}⭐️扩展管理⭐️${GREEN}[6]${NC}✨️推荐配置✨️"
    echo ""
    echo -e "  ${BOLD}═══ 维护 ═══${NC}"
    echo -e "  ${BLUE}[7]${NC} 清理残余文件  ${BLUE}[8]${NC} Foxium工具箱"
    echo -e "  ${BLUE}[9]${NC} 更新  ${BLUE}[10]${NC} 日志  ${BLUE}[11]${NC} 版本回退/切换"
    echo ""
    echo -e "  ${BOLD}═══ 数据 ═══${NC}"
    echo -e "  ${YELLOW}[12]${NC} 备份  ${YELLOW}[13]${NC} 恢复  ${YELLOW}[14]${NC} 重装依赖"
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

# ======================================
# 自动菜单安装
# ======================================
setup_auto_menu() {
    if [ ! -f "$SCRIPT_PATH" ] || [ "$(readlink -f "$0")" != "$SCRIPT_PATH" ]; then
        cp "$0" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
    fi

    if ! grep -q "st.sh" "$HOME/.bashrc" 2>/dev/null; then
        {
            echo ""
            echo '# 淡蓝酒馆自动菜单'
            echo 'if [ -f "$HOME/st.sh" ] && [[ $- == *i* ]]; then bash "$HOME/st.sh"; fi'
        } >> "$HOME/.bashrc"
    fi
}

# ======================================
# 入口初始化（不再自动安装）
# ======================================
init() {
    setup_auto_menu
    rm -f "$LAN_FLAG" 2>/dev/null
    rotate_logs
    header
    show_menu
}

# ======================================
# 主循环
# ======================================
main_loop() {
    init

    while true; do
        printf "请输入选项 : "
        read -r CHOICE
        rotate_logs
        case "$CHOICE" in
            1)  fn_start;   header; show_menu ;;
            2)  fn_stop;    header; show_menu ;;
            3)  fn_restart; header; show_menu ;;
            4)  fn_install_tavern; header; show_menu ;;
            5)  fn_install_extension; header; show_menu ;;
            6)  fn_config;  header; show_menu ;;
            7)  fn_clean;   header; show_menu ;;
            8)  fn_foxium;  header; show_menu ;;
            9)  fn_update;  header; show_menu ;;
            10) fn_logs;    header; show_menu ;;
            11) fn_rollback; header; show_menu ;;
            12) fn_backup;  header; show_menu ;;
            13) fn_restore; header; show_menu ;;
            14) fn_reinstall_deps; header; show_menu ;;
            y|Y) fn_lan_on;  header; show_menu ;;
            n|N) fn_lan_off; header; show_menu ;;
            m|M) fn_set_password; header; show_menu ;;
            99) fn_uninstall; header; show_menu ;;
            0)  echo "👋 再见~"; exit 0 ;;
            *)
                echo -e "${RED}无效选项: $CHOICE${NC}"
                echo -e "${YELLOW}提示：请直接输入数字或字母，不要按方向键${NC}"
                printf "按回车键继续..."
                read -r _
                header
                show_menu
                ;;
        esac
    done
}