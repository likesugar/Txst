#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  模块 1 · 服务
#  职责：启动 / 停止 / 重启 / 日志 / 访问地址
#==========================================================================

# ======================================
# 启动
# ======================================
fn_start() {
    if ! check_installed; then
        echo -e "${RED}未安装${NC}"
        return
    fi
    if is_running; then
        echo -e "${GREEN}已在运行${NC}"
        return
    fi

    echo -e "${GREEN}启动中...${NC}"
    cd "$INSTALL_DIR" || return
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
        echo -e "${GREEN}✓ 已启动${NC}"
        print_access_url
    else
        echo -e "${RED}✗ 启动超时，查看日志：${NC}"
        echo -e "${YELLOW}  tail -30 $INSTALL_DIR/nohup.out${NC}"
    fi
}

# ======================================
# 停止
# ======================================
fn_stop() {
    pkill -f "node.*server.js" 2>/dev/null || true
    sleep 1
    pkill -9 -f "node.*server.js" 2>/dev/null || true
    echo -e "${GREEN}✓ 已停止${NC}"
}

# ======================================
# 重启
# ======================================
fn_restart() {
    fn_stop
    sleep 1
    fn_start
}

# ======================================
# 获取局域网 IP
# ======================================
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

# ======================================
# 获取当前端口
# ======================================
get_current_port() {
    local port
    port=$(read_config_key "port")
    echo "${port:-8000}"
}

# ======================================
# 获取密码状态
# ======================================
get_password_status() {
    if [ ! -f "$INSTALL_DIR/config.yaml" ]; then
        echo "未配置"
        return
    fi
    local auth_mode
    auth_mode=$(read_config_key "basicAuthMode")
    if [ "$auth_mode" = "true" ]; then
        echo "开启"
    else
        echo "关闭"
    fi
}

# ======================================
# 访问地址显示
# ======================================
print_access_url() {
    local PORT
    PORT=$(get_current_port)
    if [ -f "$LAN_FLAG" ]; then
        local IP
        IP=$(get_lan_ip)
        if [ -n "$IP" ]; then
            echo -e "${GREEN}🟢 运行中 → http://${IP}:${PORT} ${NC}"
        else
            echo -e "${GREEN}🟢 运行中 → 端口 ${PORT} ${NC}"
        fi
    else
        echo -e "${GREEN}🟢 运行中 → http://127.0.0.1:${PORT}${NC}"
    fi
}

# ======================================
# 状态文本
# ======================================
status_text() {
    if is_running; then
        print_access_url
    else
        echo -e "${YELLOW}🔴 未运行${NC}"
    fi
}

# ======================================
# 日志查看
# ======================================
fn_logs() {
    if ! check_installed; then
        echo -e "${RED}未安装${NC}"
        return
    fi
    echo -e "${CYAN}=== 最近 30 行 ===${NC}"
    if [ -f "$INSTALL_DIR/nohup.out" ]; then
        tail -30 "$INSTALL_DIR/nohup.out"
    else
        echo "(无日志)"
    fi
    printf "按回车返回..."
    read -r _
}