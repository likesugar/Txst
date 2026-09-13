#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  40_config.sh — 推荐配置 / 局域网开关 / 密码验证 / 白名单
#==========================================================================

fn_config() {
    if ! check_installed; then
        err "${RED}未安装${NC}"
        return
    fi

    info "${CYAN}${BOLD}═══════ ⚙️ 推荐配置 ═══════${NC}"
    echo ""

    if [ -f "$INSTALL_DIR/config.yaml" ]; then
        warn "${YELLOW}⚠️ config.yaml 已存在，将执行「增量合并」：${NC}"
        warn "${YELLOW}   已存在的键会被更新为推荐值，其他自定义配置保持不变。${NC}"
        echo ""
        printf "是否继续？[y/N]: "
        read -r OVERWRITE
        if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
            warn "${YELLOW}取消${NC}"
            pause
            return
        fi
        cp "$INSTALL_DIR/config.yaml" "$INSTALL_DIR/config.yaml.bak"
        info "${CYAN}✓ 已备份旧配置为 config.yaml.bak${NC}"
    fi

    info "${CYAN}💙 合并推荐配置（保留已有其他项）...${NC}"

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

    echo ""
    if check_installed; then
        ok "${GREEN}✓ 推荐配置已应用${NC}"
        echo ""
        warn "${YELLOW}📋 当前关键配置：${NC}"
        echo -e "    ${CYAN}端口：${NC}$(read_config_key port)"
        echo -e "    ${CYAN}密码验证：${NC}$(get_password_status)"
        echo -e "    ${CYAN}局域网 listen：${NC}$(read_config_key listen)"
        echo ""
        warn "${YELLOW}💡 按 m 可设置密码验证${NC}"
        warn "${YELLOW}💡 按 y 可开启局域网访问${NC}"
    else
        err "${RED}✗ 配置生成失败${NC}"
    fi

    echo ""
    pause
}

toggle_whitelist_mode() {
    local cfg="$INSTALL_DIR/config.yaml"
    [ -f "$cfg" ] || { err "${RED}config.yaml 不存在${NC}"; return 1; }

    local cur
    cur=$(read_config_key "whitelistMode")
    local new

    if [ "$cur" = "true" ]; then
        new="false"
    else
        new="true"
    fi

    set_config_key "whitelistMode" "$new"

    if [ "$new" = "true" ]; then
        ok "${GREEN}✓ 白名单模式已开启${NC}"
        warn "${YELLOW}  只有 whitelist 列表中的 IP 能访问${NC}"
        info "${CYAN}  当前白名单条目:${NC}"
        awk '
            /^whitelist:/ {inblk=1; next}
            inblk && /^[^[:space:]]/ {inblk=0}
            inblk && /^[[:space:]]*-/ {print "    " $0}
        ' "$cfg"
    else
        ok "${GREEN}✓ 白名单模式已关闭${NC}"
        err "${RED}  ⚠️ 任何 IP 都能访问，请务必开启密码验证！${NC}"
        if [ "$(read_config_key basicAuthMode)" != "true" ]; then
            err "${RED}  ⚠️ 当前密码验证未开启，强烈建议按 [1] 设置${NC}"
        fi
    fi
}

fn_set_password() {
    if ! check_installed; then
        err "${RED}未安装${NC}"
        return
    fi

    clear
    info "${CYAN}${BOLD}═══════ 🔐 密码与访问控制 ═══════${NC}"
    echo ""

    local CURRENT_AUTH=$(read_config_key "basicAuthMode")
    local CURRENT_USER=$(read_config_key "username" 1)
    local CURRENT_PASS=$(read_config_key "password" 1)
    local CURRENT_WL=$(get_whitelist_mode)

    warn "${YELLOW}📋 当前状态：${NC}"

    if [ "$CURRENT_AUTH" = "true" ] && [ -n "$CURRENT_USER" ] && [ "$CURRENT_USER" != '""' ]; then
        ok "${GREEN}  密码验证：✅ 已开启${NC}"
        echo -e "    ${CYAN}账号：${CURRENT_USER}${NC}"
        if [ -n "$CURRENT_PASS" ] && [ "$CURRENT_PASS" != '""' ]; then
            echo -e "    ${CYAN}密码：${CURRENT_PASS}${NC}"
        else
            warn "${YELLOW}    密码：未设置${NC}"
        fi
    else
        err "${RED}  密码验证：❌ 未开启${NC}"
    fi

    case "$CURRENT_WL" in
        true)  ok "${GREEN}  白名单模式：✅ 已开启${NC}" ;;
        false) err "${RED}  白名单模式：❌ 已关闭${NC}" ;;
        *)     warn "${YELLOW}  白名单模式：未设置${NC}" ;;
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
                err "${RED}账号不能为空，取消设置${NC}"
                pause
                return
            fi

            printf "请输入密码 (不能为空): "
            read -r NEW_PASSWORD
            if [ -z "$NEW_PASSWORD" ]; then
                err "${RED}密码不能为空，取消设置${NC}"
                pause
                return
            fi

            cp "$INSTALL_DIR/config.yaml" "$INSTALL_DIR/config.yaml.bak"

            set_config_key "basicAuthMode" "true"
            set_config_key "username" "\"${NEW_USER}\"" 1
            set_config_key "password" "\"${NEW_PASSWORD}\"" 1

            echo ""
            ok "${GREEN}✓ 密码验证已设置${NC}"
            echo -e "  ${CYAN}账号: ${NEW_USER}${NC}"
            ;;
        2)
            echo ""
            if [ "$(read_config_key basicAuthMode)" = "true" ]; then
                set_config_key "basicAuthMode" "false"
                ok "${GREEN}✓ 密码认证已关闭${NC}"
            else
                warn "${YELLOW}密码认证未开启${NC}"
            fi
            ;;
        3)
            echo ""
            if [ ! -f "$LAN_FLAG" ]; then
                warn "${YELLOW}⚠️ 局域网未开启，无需随机端口${NC}"
                pause
                return
            fi

            local NEW_PORT=$(random_port)
            set_config_key "port" "${NEW_PORT}"

            ok "${GREEN}✓ 端口已更换为: ${NEW_PORT}${NC}"
            ;;
        4)
            echo ""
            toggle_whitelist_mode
            ;;
        0) return ;;
        *) err "${RED}无效选项${NC}" ;;
    esac

    if is_running; then
        warn "${YELLOW}  ⚠️ 需要重启酒馆才能生效${NC}"
    fi

    echo ""
    pause
}

fn_lan_on() {
    if ! check_installed; then
        err "${RED}未安装${NC}"
        return
    fi

    touch "$LAN_FLAG"

    if [ "$(read_config_key 'whitelistMode')" != "true" ]; then
        local RANDOM_PORT=$(random_port)
        set_config_key "listen" "true"
        set_config_key "port" "${RANDOM_PORT}"

        add_whitelist_entry "192.168.0.0/16"
    fi

    local IP=$(get_lan_ip)
    local PORT=$(get_current_port)

    ok "${GREEN}✓ 局域网访问已开启${NC}"
    info "${CYAN}🌐 访问地址: http://${IP:-<IP>}:${PORT}${NC}"
    info "${CYAN}  随机端口: ${PORT} (避免冲突)${NC}"

    # [修复 v3.0] 原版逻辑写反：状态为「开启」时才应该提醒设置密码
    local PASS_STATUS=$(get_password_status)
    if [[ "$PASS_STATUS" != "开启" ]]; then
        warn "${YELLOW}⚠️ 密码验证未开启，局域网内任何人都能访问${NC}"
        warn "${YELLOW}  建议按 m 设置密码验证${NC}"
    fi

    info "${CYAN}🔄 正在自动重启酒馆以应用配置...${NC}"
    fn_stop
    sleep 2
    fn_start
    ok "${GREEN}✅ 配置已应用并重启完成${NC}"
}

fn_lan_off() {
    rm -f "$LAN_FLAG"

    if [ -f "$INSTALL_DIR/config.yaml" ]; then
        set_config_key "listen" "false"
        set_config_key "port" "8000"
    fi

    ok "${GREEN}✓ 局域网访问已关闭${NC}"
    warn "${YELLOW}  端口恢复: 8000 (仅本机)${NC}"

    if is_running; then
        warn "${YELLOW}  正在自动重启酒馆以应用更改...${NC}"
        fn_stop
        sleep 1
        fn_start
    fi
}
