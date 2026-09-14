#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  模块 3 · 依赖
#  职责：重装依赖 (Fix npm) / 清理 node_modules 并重新安装
#  依赖：0_core.sh（slim_node_modules、clean_npm_cache）、1_service.sh（fn_stop）
#==========================================================================

# ======================================
# 公共函数：清理并重装依赖
# 用法: clean_and_reinstall_deps [--clean-cache] [--no-slim] [--quiet] [--label TEXT]
# ======================================
clean_and_reinstall_deps() {
    local clean_cache=0 do_slim=1 label="依赖"

    while [ $# -gt 0 ]; do
        case "$1" in
            --clean-cache) clean_cache=1 ;;
            --no-slim)     do_slim=0 ;;
            --quiet)       ST_QUIET=1 ;;
            --label)       label="$2"; shift ;;
        esac
        shift
    done

    log() {
        [ "${ST_QUIET:-0}" = "1" ] && return 0
        echo -e "$@"
    }
    err() {
        echo -e "$@" >&2
    }

    [ -d "$INSTALL_DIR" ] || {
        err "${RED}✗ 安装目录不存在: $INSTALL_DIR${NC}"
        return 1
    }

    if is_running; then
        log "${CYAN}正在停止运行中的酒馆...${NC}"
        fn_stop >/dev/null 2>&1 || true
        sleep 1
    fi

    export ST_QUIET="${ST_QUIET:-0}"

    (
        cd "$INSTALL_DIR" || exit 1

        log "${CYAN}🧹 清理${label}...${NC}"
        if [ -d node_modules ]; then
            rm -rf node_modules
            log "  ${GREEN}✓ node_modules${NC}"
        fi
        if [ -f package-lock.json ]; then
            rm -f package-lock.json
            log "  ${GREEN}✓ package-lock.json${NC}"
        fi
        if [ "$clean_cache" = "1" ]; then
            clean_npm_cache
            log "  ${GREEN}✓ npm 缓存${NC}"
        fi

        log "${CYAN}📦 安装${label}（淘宝镜像加速）...${NC}"
        npm config set registry https://registry.npmmirror.com 2>/dev/null || true

        if ! npm install --omit=dev --ignore-scripts --no-audit --no-fund >/dev/null 2>&1; then
            log "${YELLOW}⚠️ 快速安装失败，尝试完整安装...${NC}"
            if ! npm install --omit=dev --no-audit --no-fund >/dev/null 2>&1; then
                err "${RED}❌ ${label}安装失败${NC}"
                err "${YELLOW}💡 手动执行: cd $INSTALL_DIR && npm install${NC}"
                exit 1
            fi
        fi
        log "  ${GREEN}✓ ${label}安装完成${NC}"

        if [ "$do_slim" = "1" ]; then
            log "${CYAN}🧹 瘦身...${NC}"
            slim_node_modules
            log "  ${GREEN}✓ 瘦身完成${NC}"
        fi
    )

    unset ST_QUIET
}

# ======================================
# 菜单入口：重装依赖 (Fix npm)
# ======================================
fn_reinstall_deps() {
    if ! check_installed; then
        echo -e "${RED}SillyTavern 未安装，请先安装。${NC}"
        return
    fi

    echo -e "${CYAN}${BOLD}═══════ 🔧 重装依赖 (Fix npm) ═══════${NC}"
    echo ""
    echo -e "${YELLOW}此操作将重新下载并安装 SillyTavern 的运行依赖。${NC}"
    echo -e "${YELLOW}安装完成后会自动进行极致瘦身，删除文档、测试文件等。${NC}"
    echo ""

    if [ -d "$INSTALL_DIR/node_modules" ]; then
        local current_size
        current_size=$(du -sh "$INSTALL_DIR/node_modules" 2>/dev/null | cut -f1)
        echo -e "${CYAN}当前 node_modules 大小: ${current_size}${NC}"
        echo ""
    fi

    printf "确认继续吗? [y/N]: "
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}操作已取消。${NC}"
        printf "按回车返回..."
        read -r _
        return
    fi

    if clean_and_reinstall_deps --clean-cache --label "依赖"; then
        fn_clean
        if [ -d "$INSTALL_DIR/node_modules" ]; then
            local final_size
            final_size=$(du -sh "$INSTALL_DIR/node_modules" 2>/dev/null | cut -f1)
            echo ""
            echo -e "${CYAN}📊 最终 node_modules 大小: ${final_size}${NC}"
        fi
        echo ""
        echo -e "${YELLOW}💡 建议重启酒馆以应用更改。${NC}"
        echo ""
        printf "是否立即启动酒馆？[Y/n]: "
        read -r START_NOW
        if [[ "$START_NOW" != "n" && "$START_NOW" != "N" ]]; then
            fn_start
        fi
    fi

    echo ""
    printf "按回车返回..."
    read -r _
}