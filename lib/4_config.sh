#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  模块 4 · 配置
#  职责：推荐配置 / 局域网 / 密码 / 白名单
#  依赖：0_core.sh（YAML 读写、白名单）、1_service.sh（fn_start/fn_stop、IP/端口）
#==========================================================================

# ======================================
# 推荐配置（增量合并，不再整体覆盖）
# ======================================
fn_config() {
    if ! check_installed; then
        echo -e "${RED}未安装${NC}"
        return
    fi

    echo -e "${CYAN}${BOLD}═══════ ⚙️ 推荐配置 ═══════${NC}"
    echo ""

    if [ -f "$INSTALL_DIR/config.yaml" ]; then
        echo -e "${YELLOW}⚠️ config.yaml 已存在，将执行「增量合并」：${NC}"
        echo -e "${YELLOW}   已存在的键会被更新为推荐值，其他自定义配置保持不变。${NC}"
        echo ""
        printf "是否继续？[y/N]: "
        read -r OVERWRITE
        if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
            echo -e "${YELLOW}取消${NC}"
            printf "按回车返回..."
            read -r _
            return
        fi
        cp "$INSTALL_DIR/config.yaml" "$INSTALL_DIR/config.yaml.bak"
        echo -e "${CYAN}✓ 已备份旧配置为 config.yaml.bak${NC}"
    fi

    echo -e "${CYAN}💙 合并推荐配置（保留已有其他项）...${NC}"

    set_config_key "listen" "false"
    set_config_key "port" "8000"
    set_config_key "basicAuthMode" "false"

    append_yaml_block_if_missing "whitelist" << 'EOF'
whitelist:
  - ::1
  - 127.0.0.1
  - 192.168.0.0/16
EOF

    append_yaml_block_if_missing "performance" << 'EOF'
performance:
  lazyLoadCharacters: true
EOF

    append_yaml_block_if_missing "rateLimiting" << 'EOF'
rateLimiting:
  accountsResetMaxAttempts: 5
EOF

    append_yaml_block_if_missing "basicAuthUser" << 'EOF'
basicAuthUser:
  username: ""
  password: ""
EOF

    if [ -f "$INSTALL_DIR/config.yaml" ]; then
        echo -e "${GREEN}✓ 推荐配置已合并${NC}"
        echo ""
        echo -e "  ${YELLOW}📋 当前关键配置：${NC}"
        echo -e "    ${CYAN}端口：${NC}$(read_config_key port)"
        echo -e "    ${CYAN}密码验证：${NC}$(get_password_status)"
        echo -e "    ${CYAN}局域网 listen：${NC}$(read_config_key listen)"
        echo ""
        echo -e "${YELLOW}💡 按 m 可设置密码验证${NC}"
        echo -e "${YELLOW}💡 按 y 可开启局域网访问${NC}"
    else
        echo -e "${RED}✗ 配置生成失败${NC}"
    fi

    echo ""
    printf "按回车返回..."
    read -r _
}

# ======================================
# 局域网：开启
# ======================================
fn_lan_on() {
    touch "$LAN_FLAG"

    if [ -f "$INSTALL_DIR/config.yaml" ]; then
        set_config_key "listen" "true"

        local RANDOM_PORT
        RANDOM_PORT=$(random_port)
        set_config_key "port" "${RANDOM_PORT}"

        add_whitelist_entry "192.168.0.0/16"
    fi

    local IP
    IP=$(get_lan_ip)
    local PORT
    PORT=$(get_current_port)

    echo -e "${GREEN}✓ 局域网访问已开启${NC}"
    echo -e "${CYAN}🌐 访问地址: http://${IP:-<IP>}:${PORT}${NC}"
    echo -e "${CYAN}  随机端口: ${PORT} (避免冲突)${NC}"

    local PASS_STATUS
    PASS_STATUS=$(get_password_status)
    if [[ "$PASS_STATUS" == "关闭" ]]; then
        echo -e "${YELLOW}⚠️ 密码验证未开启，局域网内任何人都能访问${NC}"
        echo -e "${YELLOW}  建议按 m 设置密码验证${NC}"
    fi

    echo -e "${CYAN}🔄 正在自动重启酒馆以应用配置...${NC}"
    fn_stop
    sleep 2
    fn_start
    echo -e "${GREEN}✅ 配置已应用并重启完成${NC}"
}

# ======================================
# 局域网：关闭
# ======================================
fn_lan_off() {
    rm -f "$LAN_FLAG"

    if [ -f "$INSTALL_DIR/config.yaml" ]; then
        set_config_key "listen" "false"
        set_config_key "port" "8000"
    fi

    echo -e "${GREEN}✓ 局域网访问已关闭${NC}"
    echo -e "${YELLOW}  端口恢复: 8000 (仅本机)${NC}"

    if is_running; then
        echo -e "${YELLOW}  正在自动重启酒馆以应用更改...${NC}"
        fn_stop
        sleep 1
        fn_start
    fi
}

# ======================================
# 生成随机端口
# ======================================
random_port() {
    echo $((10000 + RANDOM % 39152))
}

# ======================================
# 设置密码验证 / 访问控制
# ======================================
fn_set_password() {
    if ! check_installed; then
        echo -e "${RED}未安装${NC}"
        return
    fi
    if [ ! -f "$INSTALL_DIR/config.yaml" ]; then
        echo -e "${RED}config.yaml 不存在${NC}"
        return
    fi

    echo ""
    echo -e "${CYAN}${BOLD}═══════ 访问控制设置 ═══════${NC}"
    echo ""

    if [ -f "$LAN_FLAG" ]; then
        local IP
        IP=$(get_lan_ip)
        local PORT
        PORT=$(get_current_port)
        echo -e "${CYAN}🌐 局域网状态: 已开启${NC}"
        echo -e "${CYAN}   访问地址: http://${IP:-<IP>}:${PORT}${NC}"
        echo -e "${CYAN}   当前端口: ${PORT}${NC}"
    else
        echo -e "${YELLOW}🌐 局域网状态: 已关闭 (仅本机访问)${NC}"
    fi
    echo ""

    local CURRENT_AUTH
    CURRENT_AUTH=$(read_config_key "basicAuthMode")
    local CURRENT_USER
    CURRENT_USER=$(read_config_key "username" 1)
    local CURRENT_PASS
    CURRENT_PASS=$(read_config_key "password" 1)
    local CURRENT_WL
    CURRENT_WL=$(get_whitelist_mode)

    echo -e "${YELLOW}📋 当前状态：${NC}"

    if [ "$CURRENT_AUTH" = "true" ] && [ -n "$CURRENT_USER" ] && [ "$CURRENT_USER" != '""' ]; then
        echo -e "  ${GREEN}密码验证：✅ 已开启${NC}"
        echo -e "    ${CYAN}账号：${CURRENT_USER}${NC}"
        if [ -n "$CURRENT_PASS" ] && [ "$CURRENT_PASS" != '""' ]; then
            echo -e "    ${CYAN}密码：${CURRENT_PASS}${NC}"
        else
            echo -e "    ${YELLOW}密码：未设置${NC}"
        fi
    else
        echo -e "  ${RED}密码验证：❌ 未开启${NC}"
    fi

    case "$CURRENT_WL" in
        true)
            echo -e "  ${GREEN}白名单模式：✅ 已开启${NC}"
            ;;
        false)
            echo -e "  ${RED}白名单模式：❌ 已关闭${NC}"
            ;;
        *)
            echo -e "  ${YELLOW}白名单模式：未设置${NC}"
            ;;
    esac
    echo ""

    echo -e "  ${GREEN}[1]${NC} 设置/修改账号密码"
    echo -e "  ${YELLOW}[2]${NC} 关闭密码认证"
    echo -e "  ${GREEN}[3]${NC} 重新生成随机端口"
    echo -e "  ${CYAN}[4]${NC} 切换白名单模式 (当前: ${CURRENT_WL})"
    echo -e "  ${RED}[0]${NC} 返回"
    echo ""

    printf "请选择: "
    read -r PASS_CHOICE

    case "$PASS_CHOICE" in
        1)
            echo ""
            printf "请输入账号 (不能为空): "
            read -r NEW_USER
            if [ -z "$NEW_USER" ]; then
                echo -e "${RED}账号不能为空，取消设置${NC}"
                printf "按回车返回..."
                read -r _
                return
            fi

            printf "请输入密码 (不能为空): "
            read -r NEW_PASSWORD
            if [ -z "$NEW_PASSWORD" ]; then
                echo -e "${RED}密码不能为空，取消设置${NC}"
                printf "按回车返回..."
                read -r _
                return
            fi

            cp "$INSTALL_DIR/config.yaml" "$INSTALL_DIR/config.yaml.bak"

            set_config_key "basicAuthMode" "true"
            set_config_key "username" "\"${NEW_USER}\"" 1
            set_config_key "password" "\"${NEW_PASSWORD}\"" 1

            echo ""
            echo -e "${GREEN}✓ 密码验证已设置${NC}"
            echo -e "  ${CYAN}账号: ${NEW_USER}${NC}"

            if is_running; then
                echo -e "${YELLOW}  ⚠️ 需要重启酒馆才能生效${NC}"
            fi
            ;;
        2)
            echo ""
            if [ "$(read_config_key basicAuthMode)" = "true" ]; then
                set_config_key "basicAuthMode" "false"
                echo -e "${GREEN}✓ 密码认证已关闭${NC}"
            else
                echo -e "${YELLOW}密码认证未开启${NC}"
            fi
            if is_running; then
                echo -e "${YELLOW}  ⚠️ 需要重启酒馆才能生效${NC}"
            fi
            ;;
        3)
            echo ""
            if [ ! -f "$LAN_FLAG" ]; then
                echo -e "${YELLOW}⚠️ 局域网未开启，无需随机端口${NC}"
                printf "按回车返回..."
                read -r _
                return
            fi

            local NEW_PORT
            NEW_PORT=$(random_port)
            set_config_key "port" "${NEW_PORT}"

            echo -e "${GREEN}✓ 端口已更换为: ${NEW_PORT}${NC}"

            if is_running; then
                echo -e "${YELLOW}  ⚠️ 需要重启酒馆才能生效${NC}"
            fi
            ;;
        4)
            echo ""
            toggle_whitelist_mode
            echo ""
            if is_running; then
                echo -e "${YELLOW}  ⚠️ 需要重启酒馆才能生效${NC}"
            fi
            ;;
        0) return ;;
        *) echo -e "${RED}无效选项${NC}" ;;
    esac

    echo ""
    printf "按回车返回..."
    read -r _
}