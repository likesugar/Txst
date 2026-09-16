#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  模块 9 · 卸载
#  职责：分级卸载（管理器 / 酒馆 / 完全清除）
#  依赖：0_core.sh（颜色/常量）、1_service.sh（fn_stop）、6_backup.sh（do_backup）
#==========================================================================

# ======================================
# 卸载菜单
# ======================================
fn_uninstall() {
    while true; do
        clear
        echo -e "${RED}${BOLD}═══════ 💀 卸载管理 ═══════${NC}"
        echo ""
        echo -e "  ${BOLD}请选择卸载范围：${NC}"
        echo ""
        echo -e "  ${GREEN}[1]${NC} 仅卸载管理器"
        echo -e "      ${YELLOW}删除 ~/st、~/st.sh，保留酒馆和数据${NC}"
        echo ""
        echo -e "  ${YELLOW}[2]${NC} 卸载酒馆"
        echo -e "      ${YELLOW}删除 ~/SillyTavern，保留管理器、备份和配置${NC}"
        echo ""
        echo -e "  ${RED}[3]${NC} 完全清除"
        echo -e "      ${YELLOW}删除所有 + Termux 数据（等同于清除应用数据）${NC}"
        echo ""
        echo -e "  ${RED}[0]${NC} 返回"
        echo ""
        printf "选择: "
        read -r UN_CHOICE

        case "$UN_CHOICE" in
            1) uninstall_manager ;;
            2) uninstall_tavern ;;
            3) uninstall_all ;;
            0) return ;;
            *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
        esac
    done
}

# ======================================
# 检查今天是否已有备份，没有则自动备份
# 用法: ensure_today_backup
# 返回: 0 已存在或备份成功 / 1 备份失败
# ======================================
ensure_today_backup() {
    if ! check_installed; then
        return 0
    fi

    mkdir -p "$BACKUP_DIR"
    local TODAY
    TODAY=$(date +"%Y%m%d")

    if ls "$BACKUP_DIR"/ST-${TODAY}_*.tar.gz >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 今日已有备份，跳过自动备份${NC}"
        return 0
    fi

    echo ""
    echo -e "${YELLOW}⚠️ 今日还没有备份，正在自动创建...${NC}"

    if do_backup "data_config"; then
        echo -e "${GREEN}✓ 自动备份完成${NC}"
        return 0
    else
        echo -e "${RED}✗ 自动备份失败${NC}"
        printf "${YELLOW}是否继续卸载？[y/N]: ${NC}"
        read -r CF
        [ "$CF" = "y" ] || [ "$CF" = "Y" ]
        return $?
    fi
}

# ======================================
# [1] 仅卸载管理器
# ======================================
uninstall_manager() {
    echo ""
    echo -e "${RED}${BOLD}═══ 仅卸载管理器 ═══${NC}"
    echo ""
    echo -e "${YELLOW}将删除：${NC}"
    echo -e "  - ~/st/           (模块目录)"
    echo -e "  - ~/st.sh         (启动器)"
    echo ""
    echo -e "${GREEN}将保留：${NC}"
    echo -e "  - ~/SillyTavern/  (酒馆本体)"
    echo -e "  - ~/SillyTavern_Backups/  (备份)"
    echo -e "  - ~/.bashrc       (自动菜单入口会一并清理)"
    echo ""
    printf "确认？输入 ${RED}YES${NC} 继续: "
    read -r CF
    [ "$CF" != "YES" ] && { echo "已取消"; sleep 1; return; }

    echo ""
    echo -e "${CYAN}正在清理...${NC}"

    rm -rf "$HOME/st" 2>/dev/null && echo -e "${GREEN}✓ ~/st${NC}"
    rm -f  "$HOME/st.sh" 2>/dev/null && echo -e "${GREEN}✓ ~/st.sh${NC}"

    remove_bashrc_entry

    echo ""
    echo -e "${GREEN}✅ 管理器已卸载${NC}"
    echo -e "${YELLOW}酒馆本体和数据保留，可手动运行 bash ~/SillyTavern/start.sh 启动${NC}"
    echo ""
    printf "按回车返回..."
    read -r _
}

# ======================================
# [2] 卸载酒馆（保留管理器）
# ======================================
uninstall_tavern() {
    echo ""
    echo -e "${RED}${BOLD}═══ 卸载酒馆 ═══${NC}"
    echo ""

    local size=""
    [ -d "$INSTALL_DIR" ] && size=$(du -sh "$INSTALL_DIR" 2>/dev/null | cut -f1)

    echo -e "${YELLOW}将删除：${NC}"
    echo -e "  - ~/SillyTavern/  ${CYAN}(${size:-不存在})${NC}"
    echo ""
    echo -e "${GREEN}将保留：${NC}"
    echo -e "  - ~/st/、~/st.sh  (管理器菜单)"
    echo -e "  - ~/SillyTavern_Backups/  (备份)"
    echo -e "  - ~/storage/shared/Download/ST_Backups/  (导出的备份)"
    echo -e "  - ~/.bashrc       (自动菜单入口)"
    echo ""
    printf "确认？输入 ${RED}YES${NC} 继续: "
    read -r CF
    [ "$CF" != "YES" ] && { echo "已取消"; sleep 1; return; }

    # ---- 自动备份检查 ----
    ensure_today_backup || return

    echo ""
    echo -e "${CYAN}正在清理...${NC}"

    fn_stop 2>/dev/null || true

    rm -rf "$INSTALL_DIR" 2>/dev/null && echo -e "${GREEN}✓ ~/SillyTavern${NC}"

    echo ""
    echo -e "${GREEN}✅ 酒馆已卸载，管理器保留${NC}"
    echo -e "${YELLOW}备份仍在 ~/SillyTavern_Backups/${NC}"
    echo -e "${CYAN}💡 按 [4] 可重新安装酒馆${NC}"
    echo ""
    printf "按回车返回..."
    read -r _
}

# ======================================
# [3] 完全清除
# ======================================
uninstall_all() {
    echo ""
    echo -e "${RED}${BOLD}═══ 完全清除 ═══${NC}"
    echo ""
    echo -e "${RED}这将完全清除 Termux 所有数据！${NC}"
    echo -e "${YELLOW}等同于：设置 → 应用 → Termux → 清除数据${NC}"
    echo ""
    echo -e "${YELLOW}将删除：${NC}"
    echo -e "  - ~/SillyTavern/"
    echo -e "  - ~/SillyTavern_Backups/"
    echo -e "  - ~/st/、~/st.sh"
    echo -e "  - Termux 全部环境（$PREFIX）"
    echo ""
    printf "输入 ${RED}YES${NC} 确认: "
    read -r CF
    [ "$CF" != "YES" ] && { echo "已取消"; sleep 1; return; }

    # ---- 自动备份检查 ----
    ensure_today_backup || return

    # ---- 尝试导出备份到共享存储 ----
    if [ -d "$BACKUP_DIR" ]; then
        local SHARED="/sdcard/Download/ST_Backups"
        if [ -d "/sdcard" ]; then
            mkdir -p "$SHARED"
            if cp "$BACKUP_DIR"/*.tar.gz "$SHARED/" 2>/dev/null; then
                echo -e "${GREEN}✓ 备份已导出到 $SHARED${NC}"
            fi
        fi
    fi

    echo ""
    echo -e "${YELLOW}10 秒后执行，Ctrl+C 可取消...${NC}"
    sleep 10

    rm -rf /data/data/com.termux/files/*
    rm -rf /data/data/com.termux/cache/*
    rm -rf /sdcard/Android/data/com.termux/*

    echo -e "${GREEN}✅ 已清除所有数据${NC}"
    echo -e "${YELLOW}请退出 Termux 重新打开${NC}"
    exit 0
}

# ======================================
# 清理 ~/.bashrc 中的自动菜单入口
# ======================================
remove_bashrc_entry() {
    if [ -f "$HOME/.bashrc" ] && grep -q "淡蓝酒馆自动菜单" "$HOME/.bashrc" 2>/dev/null; then
        sed -i '/# 淡蓝酒馆自动菜单/,+1d' "$HOME/.bashrc" 2>/dev/null
        echo -e "${GREEN}✓ 已移除 ~/.bashrc 自动菜单${NC}"
    fi
}