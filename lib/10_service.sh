#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  10_service.sh — 启动 / 停止 / 重启 / 日志 / 状态与访问地址
#==========================================================================

get_lan_ip() {
    local ifconfig_cmd=""
    if command_exists ifconfig; then
        ifconfig_cmd="ifconfig"
    elif [ -x "/system/bin/ifconfig" ]; then
        ifconfig_cmd="/system/bin/ifconfig"
    elif [ -x "$PREFIX/bin/ifconfig" ]; then
        ifconfig_cmd="$PREFIX/bin/ifconfig"
    else
        echo ""
        return
    fi
    $ifconfig_cmd 2>/dev/null | grep -E "inet " | grep -v "127.0.0.1" | grep -E "192\.168|10\." | awk '{print $2}' | head -1
}

get_current_port() {
    local port=$(read_config_key "port")
    echo "${port:-8000}"
}

get_password_status() {
    if [ ! -f "$INSTALL_DIR/config.yaml" ]; then
        echo "未配置"
        return
    fi
    local auth_mode=$(read_config_key "basicAuthMode")
    if [ "$auth_mode" = "true" ]; then
        echo "开启"
    else
        echo "关闭"
    fi
}

get_whitelist_mode() {
    local v
    v=$(read_config_key "whitelistMode")
    if [ -z "$v" ]; then
        echo "未设置"
    else
        echo "$v"
    fi
}

print_access_url() {
    local PORT=$(get_current_port)
    if [ -f "$LAN_FLAG" ]; then
        local IP=$(get_lan_ip)
        if [ -n "$IP" ]; then
            ok "🟢 运行中 → http://${IP}:${PORT} "
        else
            ok "🟢 运行中 → 端口 ${PORT} "
        fi
    else
        ok "🟢 运行中 → http://127.0.0.1:${PORT}"
    fi
}

status_text() {
    if is_running; then
        print_access_url
    else
        warn "🔴 未运行"
    fi
}

random_port() {
    echo $((10000 + RANDOM % 39152))
}

fn_start() {
    if ! check_installed; then
        err "${RED}未安装${NC}"
        return
    fi
    if is_running; then
        ok "${GREEN}已在运行${NC}"
        return
    fi

    info "${GREEN}启动中...${NC}"
    cd "$INSTALL_DIR"
    nohup bash start.sh > "$INSTALL_DIR/nohup.out" 2>&1 &

    local i=0
    printf "  等待服务就绪"
    while [ $i -lt 30 ]; do
        if is_running; then
            break
        fi
        printf "."
        sleep 1
        i=$((i + 1))
    done
    echo ""

    if is_running; then
        ok "${GREEN}✓ 已启动${NC}"
        print_access_url
    else
        err "${RED}✗ 启动超时，查看日志：${NC}"
        warn "${YELLOW}  tail -30 $INSTALL_DIR/nohup.out${NC}"
    fi
}

fn_stop() {
    if ! is_running; then
        ok "未在运行"
        return 0
    fi
    pkill -f "node.*server.js" 2>/dev/null || true
    sleep 1
    pkill -9 -f "node.*server.js" 2>/dev/null || true
    ok "${GREEN}✓ 已停止${NC}"
}

fn_restart() {
    fn_stop
    sleep 1
    fn_start
}

fn_logs() {
    if ! check_installed; then err "${RED}未安装${NC}"; return; fi
    info "${CYAN}=== 最近 30 行 ===${NC}"
    if [ -f "$INSTALL_DIR/nohup.out" ]; then
        tail -30 "$INSTALL_DIR/nohup.out"
    else
        echo "(无日志)"
    fi
    echo ""
    pause
}
