#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  模块 7 · 维护
#  职责：清理 / 更新 / 回退
#  依赖：0_core.sh（瘦身/清理）、1_service.sh（fn_start/fn_stop）、3_deps.sh（重装依赖）
#==========================================================================

# ======================================
# 清理残余文件
# ======================================
fn_clean() {
    if ! check_installed; then
        echo -e "${RED}未安装${NC}"
        return
    fi

    fn_stop 2>/dev/null || true
    cd "$INSTALL_DIR" || return

    echo -e "${CYAN}${BOLD}═══════ 🧹 清理残余文件 ═══════${NC}"
    echo ""

    local cleaned=0

    # ---- apt / pkg 缓存 ----
    if command_exists apt; then
        apt clean 2>/dev/null && echo -e "${GREEN}✓ 已清理 apt 缓存${NC}" && cleaned=1
    fi
    if command_exists pkg; then
        pkg clean 2>/dev/null && echo -e "${GREEN}✓ 已清理 pkg 缓存${NC}" && cleaned=1
    fi

    # ---- /tmp ----
    if [ -d "$PREFIX/tmp" ] && [ "$(ls -A "$PREFIX/tmp" 2>/dev/null)" ]; then
        rm -rf "$PREFIX/tmp"/* 2>/dev/null
        echo -e "${GREEN}✓ 已清理 $PREFIX/tmp${NC}"
        cleaned=1
    fi

    # ---- Node 全局缓存 ----
    if [ -d "$PREFIX/lib/node_modules/npm/node_modules" ]; then
        rm -rf "$PREFIX/lib/node_modules/npm/node_modules/.cache" 2>/dev/null
    fi

    if [ -d "node_modules/.cache" ]; then
        rm -rf node_modules/.cache 2>/dev/null
        echo -e "${GREEN}✓ 已清理 node_modules/.cache${NC}"
        cleaned=1
    fi

    # ---- npm 缓存 ----
    if [ -d "$HOME/.npm" ]; then
        local npm_cache_size
        npm_cache_size=$(du -sh "$HOME/.npm" 2>/dev/null | cut -f1)
        clean_npm_cache
        echo -e "${GREEN}✓ 已清理 ~/.npm 缓存（${npm_cache_size}）${NC}"
        cleaned=1
    fi

    if [ -f "npm-debug.log" ]; then
        rm -f npm-debug.log 2>/dev/null
        echo -e "${GREEN}✓ 已清理 npm-debug.log${NC}"
        cleaned=1
    fi

    if [ -f ".git/index.lock" ]; then
        rm -f .git/index.lock 2>/dev/null
        echo -e "${GREEN}✓ 已清理 .git/index.lock${NC}"
        cleaned=1
    fi

    if [ -d "node_modules" ]; then
        slim_node_modules
        echo -e "${GREEN}✓ 已清理 node_modules 中的文档/测试文件${NC}"
        cleaned=1
    fi

    if [ -d "public/scripts" ]; then
        local map_count
        map_count=$(find public/scripts -name "*.map" 2>/dev/null | wc -l)
        if [ "$map_count" -gt 0 ]; then
            find public/scripts -name "*.map" -delete 2>/dev/null
            echo -e "${GREEN}✓ 已清理 ${map_count} 个 source map 文件${NC}"
            cleaned=1
        fi
    fi

    if [ -d "public/locales" ]; then
        local locale_count=0
        for d in public/locales/*; do
            if [ -d "$d" ]; then
                local bn
                bn=$(basename "$d")
                case "$bn" in
                    en|zh|zh-cn|zh-CN|zh-tw|zh-TW) ;;
                    *)
                        rm -rf "$d" 2>/dev/null
                        locale_count=$((locale_count+1))
                        ;;
                esac
            fi
        done
        if [ "$locale_count" -gt 0 ]; then
            echo -e "${GREEN}✓ 已清理 ${locale_count} 个非必要语言包${NC}"
            cleaned=1
        fi
    fi

    if [ -d "data/default-user/backups" ]; then
        local bak_count
        bak_count=$(ls -1 data/default-user/backups/*.jsonl 2>/dev/null | wc -l)
        if [ "$bak_count" -gt 5 ]; then
            ls -1t data/default-user/backups/*.jsonl 2>/dev/null | tail -n +6 | while read -r f; do
                rm -f "$f" 2>/dev/null
            done
            echo -e "${GREEN}✓ 已清理旧聊天备份（保留最近5个）${NC}"
            cleaned=1
        fi
    fi

    if command_exists npm; then
        npm cache clean --force 2>/dev/null
        echo -e "${GREEN}✓ 已清理 npm 全局缓存${NC}"
        cleaned=1
    fi

    slim_git_node
    cleaned=1

    echo ""

    if [ -d "node_modules" ]; then
        local nm_size
        nm_size=$(du -sh node_modules 2>/dev/null | cut -f1)
        echo -e "${CYAN}  node_modules 大小: ${nm_size}${NC}"
    fi
    if [ -d "public/scripts/extensions" ]; then
        local ext_size
        ext_size=$(du -sh public/scripts/extensions 2>/dev/null | cut -f1)
        echo -e "${CYAN}  扩展目录大小: ${ext_size}${NC}"
    fi

    if [ "$cleaned" = "0" ]; then
        echo -e "${YELLOW}  没有需要清理的残余文件${NC}"
    else
        echo -e "${GREEN}✅ 清理完成${NC}"
    fi

    echo ""
    printf "按回车返回..."
    read -r _
}

# ======================================
# 统一：Tag 选择
# ======================================
choose_tag() {
    local tags=()
    while IFS= read -r tag; do
        tags+=("$tag")
    done < <(git tag --sort=-creatordate 2>/dev/null | head -n 10)

    [ ${#tags[@]} -eq 0 ] && return 1

    {
        echo -e "${YELLOW}最近的 ${#tags[@]} 个版本号：${NC}"
        for i in "${!tags[@]}"; do
            printf "  ${GREEN}[%d]${NC} %s\n" $((i+1)) "${tags[$i]}"
        done
        echo ""
    } >&2

    while true; do
        printf "请输入版本序号 (1-%d) 或直接输入版本号: " ${#tags[@]} >&2
        read -r IN
        IN=$(echo "$IN" | xargs)
        [ -z "$IN" ] && return 1

        if [[ "$IN" =~ ^[0-9]+$ ]]; then
            if [ "$IN" -ge 1 ] && [ "$IN" -le ${#tags[@]} ]; then
                echo "${tags[$((IN-1))]}"
                return 0
            else
                echo -e "${RED}序号超出范围。${NC}" >&2
                continue
            fi
        else
            if git rev-parse -q --verify "refs/tags/$IN" >/dev/null 2>&1; then
                echo "$IN"
                return 0
            else
                echo -e "${RED}未找到名为 '$IN' 的 Tag。${NC}" >&2
                continue
            fi
        fi
    done
}

# ======================================
# 统一：应用 Git Ref 并重装依赖
# ======================================
apply_ref_and_reinstall() {
    local target_ref="$1"
    local action_desc="$2"
    local fail_msg="$3"

    echo -e "${CYAN}正在${action_desc} ${target_ref} ...${NC}"
    if git reset --hard "$target_ref" 2>/dev/null; then
        echo -e "${GREEN}代码${action_desc}成功，正在更新依赖...${NC}"
        clean_and_reinstall_deps --quiet --label "依赖" || return
        echo -e "${GREEN}操作完成！${NC}"
        printf "是否启动？[Y/n] "
        read -r YN
        [ "$YN" != "n" ] && [ "$YN" != "N" ] && fn_start
    else
        echo -e "${RED}${fail_msg}${NC}"
    fi
    printf "按回车继续..."
    read -r _
}

# ======================================
# 更新（子菜单）
# ======================================
fn_update() {
    if ! check_installed; then
        echo -e "${RED}SillyTavern 未安装，请先安装。${NC}"
        return
    fi

    while true; do
        clear
        echo -e "${CYAN}${BOLD}═══════ 🔄 更新管理 ═══════${NC}"
        echo ""

        cd "$INSTALL_DIR" || return

        # ---- 显示当前版本 ----
        local current_branch current_tag current_commit
        current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        [ "$current_branch" = "HEAD" ] && current_branch="detached (HEAD)"
        current_tag=$(git describe --tags --exact-match 2>/dev/null || echo "")
        current_commit=$(git rev-parse --short HEAD 2>/dev/null)

        echo -e "  ${BLUE}当前分支: ${YELLOW}$current_branch${NC}"
        if [ -n "$current_tag" ]; then
            echo -e "  ${BLUE}当前版本: ${YELLOW}$current_tag${NC}"
        else
            echo -e "  ${BLUE}当前版本: ${YELLOW}未关联 Tag (commit $current_commit)${NC}"
        fi
        echo ""

        echo -e "  ${BOLD}请选择操作：${NC}"
        echo -e "  ${GREEN}[1]${NC} 更新到 release 分支 (推荐)"
        echo -e "  ${GREEN}[2]${NC} 更新到 main 分支"
        echo -e "  ${GREEN}[3]${NC} 更新到指定 Tag"
        echo -e "  ${CYAN}[4]${NC} 仅拉取代码 (不重装依赖)"
        echo ""
        echo -e "  ${RED}[0]${NC} 返回"
        echo ""
        printf "选择: "
        read -r UP_CHOICE

        case "$UP_CHOICE" in
            1)
                fn_stop 2>/dev/null || true
                git fetch --all --tags 2>/dev/null
                apply_ref_and_reinstall "origin/release" "更新到" "更新失败，请检查网络"
                ;;
            2)
                fn_stop 2>/dev/null || true
                git fetch --all --tags 2>/dev/null
                apply_ref_and_reinstall "origin/main" "更新到" "更新失败，请检查网络"
                ;;
            3)
                fn_stop 2>/dev/null || true
                git fetch --all --tags 2>/dev/null
                local tag
                tag=$(choose_tag) || { echo -e "${RED}操作取消。${NC}"; sleep 1; continue; }
                apply_ref_and_reinstall "tags/$tag" "更新到" "更新失败，请检查版本号"
                ;;
            4)
                echo -e "${CYAN}正在拉取代码...${NC}"
                git fetch --all --tags 2>/dev/null
                echo -e "${GREEN}✓ 代码已拉取，未重装依赖${NC}"
                printf "按回车继续..."
                read -r _
                ;;
            0) return ;;
            *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
        esac
    done
}

# ======================================
# 版本回退（子菜单）
# ======================================
fn_rollback() {
    if ! check_installed; then
        echo -e "${RED}SillyTavern 未安装，请先安装。${NC}"
        return
    fi

    while true; do
        clear
        echo -e "${CYAN}${BOLD}═══════ ⏪ 版本回退 / 切换 ═══════${NC}"
        echo ""

        cd "$INSTALL_DIR" || return

        # ---- 显示当前版本 ----
        local current_branch current_tag current_commit
        current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        [ "$current_branch" = "HEAD" ] && current_branch="detached (HEAD)"
        current_tag=$(git describe --tags --exact-match 2>/dev/null || echo "")
        current_commit=$(git rev-parse --short HEAD 2>/dev/null)

        echo -e "  ${BLUE}当前分支: ${YELLOW}$current_branch${NC}"
        if [ -n "$current_tag" ]; then
            echo -e "  ${BLUE}当前版本: ${YELLOW}$current_tag${NC}"
        else
            echo -e "  ${BLUE}当前版本: ${YELLOW}未关联 Tag (commit $current_commit)${NC}"
        fi
        echo ""

        echo -e "  ${BOLD}请选择操作：${NC}"
        echo -e "  ${GREEN}[1]${NC} 按版本号 (Tag) 切换"
        echo -e "  ${GREEN}[2]${NC} 按 Commit Hash 回退"
        echo -e "  ${CYAN}[3]${NC} 查看最近 10 个 Tag"
        echo -e "  ${CYAN}[4]${NC} 查看最近 10 个提交"
        echo ""
        echo -e "  ${RED}[0]${NC} 返回"
        echo ""
        printf "选择: "
        read -r RB_CHOICE

        case "$RB_CHOICE" in
            1)
                fn_stop 2>/dev/null || true
                git fetch --all --tags 2>/dev/null
                local tag
                tag=$(choose_tag) || { echo -e "${RED}操作取消。${NC}"; sleep 1; continue; }
                apply_ref_and_reinstall "tags/$tag" "切换到" "切换失败，请检查版本号"
                ;;
            2)
                fn_stop 2>/dev/null || true
                git fetch --all --tags 2>/dev/null
                echo -e "${YELLOW}最近的 10 个提交记录：${NC}"
                git log -n 10 --oneline
                echo ""
                printf "请输入 Commit Hash: "
                read -r target
                [ -z "$target" ] && { echo -e "${RED}输入为空${NC}"; sleep 1; continue; }
                apply_ref_and_reinstall "$target" "切换到" "切换失败，请检查输入"
                ;;
            3)
                echo ""
                git tag --sort=-creatordate 2>/dev/null | head -n 10 | sed 's/^/    /'
                echo ""
                printf "按回车继续..."
                read -r _
                ;;
            4)
                echo ""
                git log -n 10 --oneline | sed 's/^/    /'
                echo ""
                printf "按回车继续..."
                read -r _
                ;;
            0) return ;;
            *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
        esac
    done
}