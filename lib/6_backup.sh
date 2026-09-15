#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  模块 6 · 备份
#  职责：备份 / 恢复 / 导出
#  依赖：0_core.sh（常量/颜色）、1_service.sh（fn_start/fn_stop）
#==========================================================================

# ======================================
# 备份管理菜单
# ======================================
fn_backup() {
    if ! check_installed; then
        echo -e "${RED}未安装${NC}"
        return
    fi
    mkdir -p "$BACKUP_DIR"

    while true; do
        clear
        echo -e "${CYAN}${BOLD}═══════ 💾 备份管理 ═══════${NC}"
        echo ""
        echo -e "  ${BOLD}创建备份：${NC}"
        echo -e "  ${GREEN}[1]${NC} 仅数据 (data/)              ${CYAN}最小体积${NC}"
        echo -e "  ${GREEN}[2]${NC} 数据 + 配置 (data/ + config.yaml)"
        echo -e "  ${GREEN}[3]${NC} 完整备份 (+ 第三方扩展)"
        echo ""
        echo -e "  ${BOLD}管理备份：${NC}"
        echo -e "  ${YELLOW}[4]${NC} 查看备份列表"
        echo -e "  ${YELLOW}[5]${NC} 删除备份"
        echo -e "  ${YELLOW}[6]${NC} 清理旧备份 (保留最近 N 个)"
        echo -e "  ${YELLOW}[7]${NC} 导出到共享存储"
        echo ""
        echo -e "  ${RED}[0]${NC} 返回"
        echo ""
        printf "选择: "
        read -r BK_CHOICE

        case "$BK_CHOICE" in
            1) do_backup "data" ;;
            2) do_backup "data_config" ;;
            3) do_backup "full" ;;
            4) list_backups ;;
            5) delete_backup ;;
            6) clean_old_backups ;;
            7) export_backup ;;
            0) return ;;
            *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
        esac

        echo ""
        printf "按回车继续..."
        read -r _
    done
}

# ======================================
# 执行备份
# ======================================
do_backup() {
    local mode="$1"
    local DATE_STR
    DATE_STR=$(date +"%Y%m%d_%H%M%S")
    local NAME=""
    local TARGETS=""
    local DESC=""

    case "$mode" in
        data)
            NAME="ST-${DATE_STR}-仅数据.tar.gz"
            TARGETS="data/"
            DESC="仅数据"
            ;;
        data_config)
            NAME="ST-${DATE_STR}-数据配置.tar.gz"
            TARGETS="data/ config.yaml"
            DESC="数据 + 配置"
            ;;
        full)
            NAME="ST-${DATE_STR}-完整备份.tar.gz"
            TARGETS="data/ config.yaml public/scripts/extensions/third-party/"
            DESC="完整备份"
            ;;
    esac

    echo ""
    echo -e "${CYAN}📦 正在创建备份 (${DESC})...${NC}"
    cd "$INSTALL_DIR" || return

    local VALID_TARGETS=""
    for t in $TARGETS; do
        [ -e "$t" ] && VALID_TARGETS="$VALID_TARGETS $t"
    done

    if [ -z "$VALID_TARGETS" ]; then
        echo -e "${RED}✗ 没有可备份的内容${NC}"
        return 1
    fi

    if tar czf "$BACKUP_DIR/$NAME" $VALID_TARGETS 2>/dev/null; then
        local SIZE
        SIZE=$(du -h "$BACKUP_DIR/$NAME" 2>/dev/null | cut -f1)
        echo -e "${GREEN}✅ 备份完成：$NAME (${SIZE})${NC}"
        echo -e "${CYAN}   📁 $BACKUP_DIR/$NAME${NC}"
    else
        echo -e "${RED}✗ 备份失败${NC}"
        rm -f "$BACKUP_DIR/$NAME" 2>/dev/null
        return 1
    fi
}

# ======================================
# 列出备份
# ======================================
list_backups() {
    echo ""
    echo -e "${CYAN}${BOLD}📋 备份列表${NC}"
    echo ""

    local FILES
    FILES=$(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null)

    if [ -z "$FILES" ]; then
        echo -e "${YELLOW}  (无备份)${NC}"
        return
    fi

    local i=1
    while IFS= read -r f; do
        local size
        size=$(du -h "$f" 2>/dev/null | cut -f1)
        local date
        date=$(stat -c '%y' "$f" 2>/dev/null | cut -d'.' -f1)
        [ -z "$date" ] && date=$(date -r "$f" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
        printf "  ${GREEN}[%2d]${NC} %-40s ${CYAN}%6s${NC}  %s\n" \
            "$i" "$(basename "$f")" "$size" "$date"
        i=$((i+1))
    done <<< "$FILES"

    echo ""
    local count
    count=$(echo "$FILES" | wc -l)
    local total
    total=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    echo -e "  ${YELLOW}共 ${count} 个备份，合计 ${total}${NC}"
}

# ======================================
# 删除备份
# ======================================
delete_backup() {
    local FILES
    FILES=$(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null)

    if [ -z "$FILES" ]; then
        echo -e "${YELLOW}无备份可删除${NC}"
        return
    fi

    echo ""
    echo -e "${CYAN}选择要删除的备份：${NC}"
    local i=1
    while IFS= read -r f; do
        printf "  ${GREEN}[%2d]${NC} %s\n" "$i" "$(basename "$f")"
        i=$((i+1))
    done <<< "$FILES"
    echo -e "  ${RED}[a]${NC} 删除全部"
    echo -e "  ${RED}[0]${NC} 取消"
    echo ""

    printf "输入序号 (可多选，如 1 3 5): "
    read -r SEL

    [ "$SEL" = "0" ] && return
    [ -z "$SEL" ] && return

    if [ "$SEL" = "a" ] || [ "$SEL" = "A" ]; then
        printf "${RED}确认删除全部备份？[y/N]${NC} "
        read -r CF
        if [ "$CF" = "y" ] || [ "$CF" = "Y" ]; then
            rm -f "$BACKUP_DIR"/*.tar.gz 2>/dev/null
            echo -e "${GREEN}✓ 已删除全部备份${NC}"
        fi
        return
    fi

    local total
    total=$(echo "$FILES" | wc -l)
    local deleted=0

    for n in $SEL; do
        if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "$total" ]; then
            local FILE
            FILE=$(echo "$FILES" | sed -n "${n}p")
            if [ -f "$FILE" ]; then
                rm -f "$FILE"
                echo -e "${GREEN}✓ 已删除: $(basename "$FILE")${NC}"
                deleted=$((deleted+1))
            fi
        fi
    done

    [ "$deleted" = "0" ] && echo -e "${YELLOW}未删除任何文件${NC}"
}

# ======================================
# 清理旧备份
# ======================================
clean_old_backups() {
    local FILES
    FILES=$(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null)

    if [ -z "$FILES" ]; then
        echo -e "${YELLOW}无备份${NC}"
        return
    fi

    local total
    total=$(echo "$FILES" | wc -l)

    echo ""
    echo -e "当前共 ${CYAN}${total}${NC} 个备份"
    printf "保留最近几个？(默认 5): "
    read -r KEEP
    KEEP=${KEEP:-5}

    if ! [[ "$KEEP" =~ ^[0-9]+$ ]] || [ "$KEEP" -lt 1 ]; then
        echo -e "${RED}无效数字${NC}"
        return
    fi

    if [ "$KEEP" -ge "$total" ]; then
        echo -e "${YELLOW}无需清理${NC}"
        return
    fi

    local to_delete=$((total - KEEP))
    echo -e "${YELLOW}将删除 ${to_delete} 个较旧的备份${NC}"
    printf "确认？[y/N] "
    read -r CF
    [ "$CF" != "y" ] && [ "$CF" != "Y" ] && return

    echo "$FILES" | tail -n +$((KEEP+1)) | while IFS= read -r f; do
        rm -f "$f"
        echo -e "${GREEN}✓ 已删除: $(basename "$f")${NC}"
    done
}

# ======================================
# 导出到共享存储
# ======================================
export_backup() {
    local SHARED="/sdcard/Download/ST_Backups"

    if [ ! -d "/sdcard" ]; then
        echo -e "${RED}未检测到共享存储权限${NC}"
        echo -e "${YELLOW}请先运行 termux-setup-storage${NC}"
        return
    fi

    local FILES
    FILES=$(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null)

    if [ -z "$FILES" ]; then
        echo -e "${YELLOW}无备份可导出${NC}"
        return
    fi

    echo ""
    echo -e "${CYAN}选择要导出的备份：${NC}"
    local i=1
    while IFS= read -r f; do
        printf "  ${GREEN}[%2d]${NC} %s\n" "$i" "$(basename "$f")"
        i=$((i+1))
    done <<< "$FILES"
    echo -e "  ${GREEN}[a]${NC} 导出全部"
    echo -e "  ${RED}[0]${NC} 取消"
    echo ""

    printf "选择: "
    read -r SEL

    [ "$SEL" = "0" ] && return
    [ -z "$SEL" ] && return

    mkdir -p "$SHARED"

    if [ "$SEL" = "a" ] || [ "$SEL" = "A" ]; then
        cp "$BACKUP_DIR"/*.tar.gz "$SHARED/" 2>/dev/null
        echo -e "${GREEN}✅ 已导出全部到：${NC}"
        echo -e "${CYAN}   $SHARED${NC}"
        return
    fi

    local total
    total=$(echo "$FILES" | wc -l)
    for n in $SEL; do
        if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "$total" ]; then
            local FILE
            FILE=$(echo "$FILES" | sed -n "${n}p")
            if [ -f "$FILE" ]; then
                cp "$FILE" "$SHARED/" 2>/dev/null && \
                    echo -e "${GREEN}✓ 已导出: $(basename "$FILE")${NC}"
            fi
        fi
    done

    echo ""
    echo -e "${CYAN}📁 导出位置: $SHARED${NC}"
}

# ======================================
# 恢复备份（增强版）
# ======================================
fn_restore() {
    if ! check_installed; then
        echo -e "${RED}未安装${NC}"
        return
    fi

    local FILES
    FILES=$(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null || true)

    local SHARED="/sdcard/Download/ST_Backups"
    local SHARED_FILES=""
    [ -d "$SHARED" ] && SHARED_FILES=$(ls -1t "$SHARED"/*.tar.gz 2>/dev/null)

    if [ -z "$FILES" ] && [ -z "$SHARED_FILES" ]; then
        echo -e "${RED}无备份文件${NC}"
        echo -e "${YELLOW}请将 .tar.gz 放到 $BACKUP_DIR${NC}"
        echo -e "${YELLOW}或 $SHARED${NC}"
        printf "按回车返回..."
        read -r _
        return
    fi

    echo ""
    echo -e "${CYAN}${BOLD}📥 恢复备份${NC}"
    echo ""

    local ALL_FILES=""
    local i=1

    if [ -n "$FILES" ]; then
        echo -e "  ${BOLD}本地备份 ($BACKUP_DIR):${NC}"
        while IFS= read -r f; do
            local size
            size=$(du -h "$f" 2>/dev/null | cut -f1)
            printf "  ${GREEN}[%2d]${NC} %-40s ${CYAN}%6s${NC}\n" \
                "$i" "$(basename "$f")" "$size"
            ALL_FILES="${ALL_FILES}${f}\n"
            i=$((i+1))
        done <<< "$FILES"
    fi

    if [ -n "$SHARED_FILES" ]; then
        echo ""
        echo -e "  ${BOLD}共享存储 ($SHARED):${NC}"
        while IFS= read -r f; do
            local size
            size=$(du -h "$f" 2>/dev/null | cut -f1)
            printf "  ${GREEN}[%2d]${NC} %-40s ${CYAN}%6s${NC}\n" \
                "$i" "$(basename "$f")" "$size"
            ALL_FILES="${ALL_FILES}${f}\n"
            i=$((i+1))
        done <<< "$SHARED_FILES"
    fi

    echo ""
    echo -e "  ${RED}[0]${NC} 取消"
    echo ""

    printf "选择要恢复的备份: "
    read -r N

    [ "$N" = "0" ] && return
    [ -z "$N" ] && return

    if ! [[ "$N" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}无效输入${NC}"
        return
    fi

    local FILE
    FILE=$(printf "%b" "$ALL_FILES" | sed -n "${N}p")

    if [ ! -f "$FILE" ]; then
        echo -e "${RED}无效选择${NC}"
        return
    fi

    echo ""
    echo -e "${CYAN}已选择: $(basename "$FILE")${NC}"

    local TMP_LIST
    TMP_LIST=$(mktemp)

    tar tzf "$FILE" > "$TMP_LIST" 2>/dev/null

    echo -e "${CYAN}📋 备份内容:${NC}"
    head -n 15 "$TMP_LIST" | sed 's/^/    /'
    local total_items
    total_items=$(wc -l < "$TMP_LIST")
    [ "$total_items" -gt 15 ] && echo -e "    ${YELLOW}... (共 ${total_items} 项)${NC}"
    echo ""

    echo -e "${BOLD}恢复方式：${NC}"
    echo -e "  ${GREEN}[1]${NC} 覆盖恢复 (先自动备份当前数据)"
    echo -e "  ${GREEN}[2]${NC} 覆盖恢复 (不备份，直接覆盖)"
    echo -e "  ${RED}[0]${NC} 取消"
    echo ""
    printf "选择: "
    read -r RMODE

    case "$RMODE" in
        1)
            echo -e "${CYAN}正在自动备份当前数据...${NC}"
            local AUTO_NAME="ST_auto_before_restore_$(date +%Y%m%d_%H%M%S).tar.gz"
            cd "$INSTALL_DIR" || return
            if tar czf "$BACKUP_DIR/$AUTO_NAME" data/ config.yaml 2>/dev/null; then
                echo -e "${GREEN}✓ 已自动备份: $AUTO_NAME${NC}"
            else
                echo -e "${YELLOW}⚠️ 自动备份失败，继续恢复...${NC}"
            fi
            ;;
        2)
            echo -e "${YELLOW}⚠️ 将直接覆盖，当前数据不可恢复${NC}"
            printf "确认？[y/N] "
            read -r CF
            [ "$CF" != "y" ] && [ "$CF" != "Y" ] && { rm -f "$TMP_LIST"; return; }
            ;;
        0|*) rm -f "$TMP_LIST"; return ;;
    esac

    echo ""
    echo -e "${CYAN}🔄 正在停止酒馆...${NC}"
    fn_stop 2>/dev/null || true
    sleep 1

    cd "$INSTALL_DIR" || { rm -f "$TMP_LIST"; return; }

    echo -e "${CYAN}📦 正在恢复...${NC}"

    local HAS_DATA=0 HAS_CONFIG=0 HAS_EXT=0
    grep -q "^data/" "$TMP_LIST" && HAS_DATA=1
    grep -q "^config.yaml" "$TMP_LIST" && HAS_CONFIG=1
    grep -q "^public/scripts/extensions" "$TMP_LIST" && HAS_EXT=1

    [ "$HAS_DATA" = "1" ] && rm -rf data
    [ "$HAS_CONFIG" = "1" ] && rm -f config.yaml
    [ "$HAS_EXT" = "1" ] && rm -rf public/scripts/extensions/third-party

    if tar xzf "$FILE" 2>/dev/null; then
        echo -e "${GREEN}✅ 恢复完成${NC}"

        echo -e "${CYAN}🧹 清理缓存...${NC}"
        rm -rf data/default-user/backups/*.jsonl 2>/dev/null
        rm -rf node_modules/.cache 2>/dev/null

        echo ""
        printf "是否立即启动酒馆？[Y/n] "
        read -r START_NOW
        if [ "$START_NOW" != "n" ] && [ "$START_NOW" != "N" ]; then
            fn_start
        fi
    else
        echo -e "${RED}✗ 恢复失败${NC}"
        echo -e "${YELLOW}💡 可从自动备份恢复${NC}"
    fi

    rm -f "$TMP_LIST"

    printf "按回车返回..."
    read -r _
}