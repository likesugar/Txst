#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  模块 5 · 扩展
#  职责：扩展管理（安装/批量/自定义 URL）
#  依赖：0_core.sh（颜色/工具函数）
#==========================================================================

# ======================================
# 扩展元数据（数组定义）
# ======================================
EXT_URLS=(
    "https://github.com/zonde306/ST-Prompt-Template"
    "https://github.com/uhhhh15/QR.git"
    "https://github.com/N0VI028/JS-Slash-Runner"
    "https://github.com/uhhhh15/hide.git"
)
EXT_NAMES=(
    "ST-Prompt-Template"
    "QR"
    "JS-Slash-Runner"
    "hide"
)
EXT_DISPLAYS=(
    "📋 提示词模板"
    "🤖 QR助手"
    "⚡ 酒馆助手"
    "🫥 隐藏助手"
)
EXT_BRANCHES=(
    ""
    ""
    ""
    ""
    ""
)

# ======================================
# 扩展管理（子菜单）
# ======================================
fn_install_extension() {
    if ! check_installed; then
        echo -e "${RED}未安装${NC}"
        return
    fi

    while true; do
        clear
        echo -e "${CYAN}${BOLD}═══════ 🧸 扩展管理 ═══════${NC}"
        echo ""

        echo -e "  ${YELLOW}✨ 可用的扩展:${NC}"
        for ((i=0; i<${#EXT_URLS[@]}; i++)); do
            if [ -n "${EXT_BRANCHES[$i]}" ]; then
                echo -e "  ${GREEN}[$((i+1))]${NC} ${EXT_DISPLAYS[$i]} ${CYAN}(${EXT_BRANCHES[$i]})${NC}"
            else
                echo -e "  ${GREEN}[$((i+1))]${NC} ${EXT_DISPLAYS[$i]}"
            fi
        done
        echo ""
        echo -e "  ${BOLD}批量/自定义：${NC}"
        echo -e "  ${GREEN}[6]${NC} 🚀 安装全部扩展"
        echo -e "  ${GREEN}[7]${NC} 🌟 自定义 URL 安装"
        echo ""
        echo -e "  ${CYAN}[8]${NC} 查看已安装扩展"
        echo -e "  ${CYAN}[9]${NC} 删除扩展"
        echo ""
        echo -e "  ${RED}[0]${NC} 返回"
        echo ""
        printf "选择: "
        read -r EXT_CHOICE

        case "$EXT_CHOICE" in
            1) _install_extension_by_index 0 ;;
            2) _install_extension_by_index 1 ;;
            3) _install_extension_by_index 2 ;;
            4) _install_extension_by_index 3 ;;
            5) _install_extension_by_index 4 ;;
            6) _install_all_extensions ;;
            7) _install_custom_extension ;;
            8) _list_installed_extensions ;;
            9) _delete_extension ;;
            0) return ;;
            *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
        esac
    done
}

# 按序号安装
_install_extension_by_index() {
    local idx="$1"
    install_one "${EXT_URLS[$idx]}" "${EXT_NAMES[$idx]}" "${EXT_DISPLAYS[$idx]}" "no" "${EXT_BRANCHES[$idx]}"
    echo ""
    printf "按回车继续..."
    read -r _
}

# 安装全部
_install_all_extensions() {
    local total=${#EXT_URLS[@]}
    echo ""
    echo -e "${YELLOW}即将安装全部 ${total} 个扩展。${NC}"
    printf "是否覆盖已存在的扩展？[y/N]: "
    read -r FORCE_ALL

    local FORCE_FLAG="no"
    [ "$FORCE_ALL" = "y" ] || [ "$FORCE_ALL" = "Y" ] && FORCE_FLAG="yes"

    for ((i=0; i<total; i++)); do
        echo ""
        echo -e "${CYAN}--- 安装 [$((i+1))/${total}] ${EXT_DISPLAYS[$i]} ---${NC}"
        install_one "${EXT_URLS[$i]}" "${EXT_NAMES[$i]}" "${EXT_DISPLAYS[$i]}" "$FORCE_FLAG" "${EXT_BRANCHES[$i]}"
    done

    echo ""
    echo -e "${GREEN}✅ 批量安装完成${NC}"
    printf "按回车继续..."
    read -r _
}

# 自定义 URL 安装
_install_custom_extension() {
    echo ""
    printf "请输入 Git 仓库 URL: "
    read -r CUSTOM_URL
    if [ -z "$CUSTOM_URL" ]; then
        echo -e "${YELLOW}取消安装${NC}"
        sleep 1
        return
    fi

    printf "请输入扩展名称 (用于目录名): "
    read -r CUSTOM_NAME
    local EXT_NAME="${CUSTOM_NAME:-custom-extension}"
    local EXT_DISPLAY="🌟 $CUSTOM_NAME"

    install_one "$CUSTOM_URL" "$EXT_NAME" "$EXT_DISPLAY" "no" ""
    echo ""
    printf "按回车继续..."
    read -r _
}

# 查看已安装扩展
_list_installed_extensions() {
    echo ""
    local EXT_DIR="$INSTALL_DIR/public/scripts/extensions/third-party"
    if [ ! -d "$EXT_DIR" ]; then
        echo -e "${YELLOW}  (尚未安装任何扩展)${NC}"
        printf "按回车继续..."
        read -r _
        return
    fi

    local count=0
    echo -e "${CYAN}${BOLD}📦 已安装扩展${NC}"
    echo ""
    for d in "$EXT_DIR"/*; do
        [ -d "$d" ] || continue
        local name
        name=$(basename "$d")
        local size
        size=$(du -sh "$d" 2>/dev/null | cut -f1)
        local is_git=""
        [ -d "$d/.git" ] && is_git=" ${GREEN}[git]${NC}"
        printf "  ${GREEN}•${NC} %-35s ${CYAN}%6s${NC}%s\n" "$name" "$size" "$is_git"
        count=$((count+1))
    done

    echo ""
    echo -e "  ${YELLOW}共 ${count} 个扩展${NC}"
    printf "按回车继续..."
    read -r _
}

# 删除扩展
_delete_extension() {
    local EXT_DIR="$INSTALL_DIR/public/scripts/extensions/third-party"
    if [ ! -d "$EXT_DIR" ]; then
        echo -e "${YELLOW}  (尚未安装任何扩展)${NC}"
        sleep 1
        return
    fi

    local exts=()
    for d in "$EXT_DIR"/*; do
        [ -d "$d" ] && exts+=("$(basename "$d")")
    done

    if [ ${#exts[@]} -eq 0 ]; then
        echo -e "${YELLOW}  (尚未安装任何扩展)${NC}"
        sleep 1
        return
    fi

    echo ""
    echo -e "${CYAN}选择要删除的扩展：${NC}"
    local i=1
    for e in "${exts[@]}"; do
        printf "  ${GREEN}[%2d]${NC} %s\n" "$i" "$e"
        i=$((i+1))
    done
    echo -e "  ${RED}[0]${NC} 取消"
    echo ""
    printf "输入序号 (可多选，如 1 3 5): "
    read -r SEL

    [ "$SEL" = "0" ] && return
    [ -z "$SEL" ] && return

    local deleted=0
    for n in $SEL; do
        if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le ${#exts[@]} ]; then
            local target="${exts[$((n-1))]}"
            local target_dir="$EXT_DIR/$target"
            if [ -d "$target_dir" ]; then
                rm -rf "$target_dir"
                echo -e "${GREEN}✓ 已删除: $target${NC}"
                deleted=$((deleted+1))
            fi
        fi
    done

    [ "$deleted" = "0" ] && echo -e "${YELLOW}未删除任何扩展${NC}"
    printf "按回车继续..."
    read -r _
}

# ======================================
# 安装单个扩展（带代理）
# ======================================
install_one() {
    local repo="$1"
    local name="$2"
    local display="$3"
    local force="$4"
    local branch="$5"

    local EXT_DIR="$INSTALL_DIR/public/scripts/extensions/third-party/$name"
    if [ -d "$EXT_DIR" ]; then
        if [ "$force" != "yes" ]; then
            echo -e "${YELLOW}⚠️ 扩展已存在: $display${NC}"
            printf "是否覆盖安装? [y/N]: "
            read -r OVERWRITE
            if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
                echo -e "${YELLOW}跳过 $display${NC}"
                return 0
            fi
        fi
        rm -rf "$EXT_DIR"
    fi

    mkdir -p "$INSTALL_DIR/public/scripts/extensions/third-party"
    echo -e "${CYAN}💙 安装 $display ...${NC}"
    if [ -n "$branch" ]; then
        echo -e "  ${CYAN}📌 指定分支/Tag: ${branch}${NC}"
    fi

    local cloned=0
    local branch_args=()
    [ -n "$branch" ] && branch_args=(--branch "$branch")

    if [[ "$repo" =~ github\.com ]]; then
        local repo_path="${repo#https://github.com/}"
        repo_path="${repo_path#http://github.com/}"
        repo_path="${repo_path#git@github.com:}"
        repo_path="${repo_path%.git}"

        local PROXY_PREFIXES=(
            "https://gh-proxy.com/https://github.com/"
            "https://gh.xiu2.xyz/https://github.com/"
            "https://ghfast.top/https://github.com/"
            "https://ghproxy.net/https://github.com/"
            "https://github.com/"
        )

        echo -e "  ${CYAN}⏳ 正在下载...${NC}"
        for PROXY in "${PROXY_PREFIXES[@]}"; do
            local PROXY_URL="${PROXY}${repo_path}"
            if git clone "$PROXY_URL" "$EXT_DIR" "${branch_args[@]}" --depth 1 2>/dev/null; then
                if [ -n "$branch" ]; then
                    echo -e "${GREEN}✅ 安装成功: $display (${branch})${NC}"
                else
                    echo -e "${GREEN}✅ 安装成功: $display${NC}"
                fi
                cloned=1
                break
            fi
        done
    else
        echo -e "  ${CYAN}⏳ 正在下载...${NC}"
        if git clone "$repo" "$EXT_DIR" "${branch_args[@]}" --depth 1 2>/dev/null; then
            if [ -n "$branch" ]; then
                echo -e "${GREEN}✅ 安装成功: $display (${branch})${NC}"
            else
                echo -e "${GREEN}✅ 安装成功: $display${NC}"
            fi
            cloned=1
        fi
    fi

    if [ "$cloned" != "1" ]; then
        echo -e "${RED}❌ 安装失败: $display${NC}"
        if [ -n "$branch" ]; then
            echo -e "${YELLOW}💡 提示: 分支/Tag '${branch}' 可能不存在，请检查仓库${NC}"
        fi
        return 1
    fi
    return 0
}