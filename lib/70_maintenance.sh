#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  70_maintenance.sh — 清理残余 / 更新 / 回退版本
#==========================================================================

# ======================================
# 统一：node_modules 瘦身
# 保留：图片处理(jimp)、向量化、TTS，删除开发/构建/浏览器依赖
# ======================================
slim_node_modules() {
    local dir="${1:-$INSTALL_DIR/node_modules}"
    [ -d "$dir" ] || return 0

    local before after
    before=$(du -sm "$dir" 2>/dev/null | cut -f1)

    # ---- 1) 文档 / 测试 / 示例（原有逻辑）----
    find "$dir" -type f \( \
        -name "README*" -o -name "CHANGELOG*" -o -name "LICENSE*" \
        -o -name "AUTHORS*" -o -name "*.md" -o -name "*.map" \
        -o -name ".travis.yml" -o -name ".eslintrc*" \
        -o -name ".prettierrc*" -o -name ".editorconfig" \) \
        -delete 2>/dev/null

    find "$dir" -type d \( \
        -name "test" -o -name "tests" -o -name "__tests__" \
        -o -name "docs" -o -name "examples" -o -name "benchmark" \
        -o -name ".github" -o -name ".circleci" \
        -o -name ".vscode" -o -name ".idea" \) \
        -exec rm -rf {} + 2>/dev/null

    rm -rf "$dir/.cache" "$dir/.bin" 2>/dev/null

    # ---- 2) 纯开发 / 构建 / 类型（运行时无用）----
    rm -rf \
        "$dir/typescript" \
        "$dir/esbuild" "$dir/@esbuild" \
        "$dir/rollup" "$dir/rollup-"* "$dir/@rollup" \
        "$dir/webpack" "$dir/webpack-"* "$dir/@webpack" \
        "$dir/vite" "$dir/@vitejs" \
        2>/dev/null

    find "$dir" -type d -name "@types" -exec rm -rf {} + 2>/dev/null
    find "$dir" -name "*.d.ts" -delete 2>/dev/null

    # ---- 3) 无头浏览器（Termux 上跑不起来）----
    rm -rf \
        "$dir"/puppeteer* "$dir"/@puppeteer \
        "$dir"/playwright* "$dir"/@playwright \
        "$dir"/chromium* \
        2>/dev/null

    after=$(du -sm "$dir" 2>/dev/null | cut -f1)
    echo -e "${GREEN}✓ node_modules: ${before}MB → ${after}MB${NC}"
}

fn_clean() {
    if ! check_installed; then
        err "${RED}未安装${NC}"
        return
    fi

    fn_stop 2>/dev/null || true
    cd "$INSTALL_DIR" || return

    info "${CYAN}${BOLD}═══════ 🧹 清理残余文件 ═══════${NC}"
    echo ""

    local cleaned=0

    # ---- apt / pkg 缓存 ----
    if command_exists apt; then
        apt clean 2>/dev/null && ok "${GREEN}✓ 已清理 apt 缓存${NC}" && cleaned=1
    fi
    if command_exists pkg; then
        pkg clean 2>/dev/null && ok "${GREEN}✓ 已清理 pkg 缓存${NC}" && cleaned=1
    fi

    # ---- /tmp ----
    if [ -d "$PREFIX/tmp" ] && [ "$(ls -A "$PREFIX/tmp" 2>/dev/null)" ]; then
        rm -rf "$PREFIX/tmp"/* 2>/dev/null
        ok "${GREEN}✓ 已清理 $PREFIX/tmp${NC}"
        cleaned=1
    fi

    # ---- Node 全局缓存 ----
    if [ -d "$PREFIX/lib/node_modules/npm/node_modules" ]; then
        rm -rf "$PREFIX/lib/node_modules/npm/node_modules/.cache" 2>/dev/null
    fi

    if [ -d "node_modules/.cache" ]; then
        rm -rf node_modules/.cache 2>/dev/null
        cleaned=1
    fi

    # ---- 杂项 ----
    if [ -f "npm-debug.log" ]; then
        rm -f npm-debug.log 2>/dev/null
        ok "${GREEN}✓ 已清理 npm-debug.log${NC}"
        cleaned=1
    fi

    if [ -f ".git/index.lock" ]; then
        rm -f .git/index.lock 2>/dev/null
        ok "${GREEN}✓ 已清理 .git/index.lock${NC}"
        cleaned=1
    fi

    # ---- node_modules 瘦身 ----
    if [ -d "node_modules" ]; then
        slim_node_modules
        ok "${GREEN}✓ 已清理 node_modules 中的文档/测试文件${NC}"
        cleaned=1
    fi

    # ---- source maps ----
    if [ -d "public/scripts" ]; then
        local map_count
        map_count=$(find public/scripts -name "*.map" 2>/dev/null | wc -l)
        if [ "$map_count" -gt 0 ]; then
            find public/scripts -name "*.map" -delete 2>/dev/null
            ok "${GREEN}✓ 已清理 ${map_count} 个 source map 文件${NC}"
            cleaned=1
        fi
    fi

    # ---- 多余语言包 ----
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
                        locale_count=$((locale_count + 1))
                        ;;
                esac
            fi
        done
        if [ "$locale_count" -gt 0 ]; then
            ok "${GREEN}✓ 已清理 ${locale_count} 个非中英语言包${NC}"
            cleaned=1
        fi
    fi

    # ---- 旧聊天备份（保留最近5个）----
    if [ -d "data/default-user/backups" ]; then
        local bak_count
        bak_count=$(ls -1 data/default-user/backups/*.jsonl 2>/dev/null | wc -l)
        if [ "$bak_count" -gt 5 ]; then
            ls -1t data/default-user/backups/*.jsonl 2>/dev/null | tail -n +6 | while read -r f; do
                rm -f "$f" 2>/dev/null
            done
            ok "${GREEN}✓ 已清理旧聊天备份（保留最近5个）${NC}"
            cleaned=1
        fi
    fi

    # ---- npm 全局缓存 ----
    if command_exists npm; then
        npm cache clean --force 2>/dev/null
        ok "${GREEN}✓ 已清理 npm 全局缓存${NC}"
        cleaned=1
    fi

    # ---- git / node 瘦身（[修复 v3.0] 原版无条件置 cleaned=1）----
    if command_exists git || command_exists npm; then
        slim_git_node
        cleaned=1
    fi

    echo ""

    if [ -d "node_modules" ]; then
        local nm_size
        nm_size=$(du -sh node_modules 2>/dev/null | cut -f1)
        info "${CYAN}  node_modules 大小: ${nm_size}${NC}"
    fi
    if [ -d "public/scripts/extensions" ]; then
        local ext_size
        ext_size=$(du -sh public/scripts/extensions 2>/dev/null | cut -f1)
        info "${CYAN}  扩展目录大小: ${ext_size}${NC}"
    fi

    if [ "$cleaned" = "0" ]; then
        warn "${YELLOW}  没有需要清理的残余文件${NC}"
    else
        ok "${GREEN}✅ 清理完成${NC}"
    fi

    echo ""
    pause
}

# ---- Tag 选择（输出到 stdout，交互走 stderr）----
choose_tag() {
    local tags=()
    while IFS= read -r tag; do
        tags+=("$tag")
    done < <(git tag --sort=-creatordate 2>/dev/null | head -n 10)

    if [ ${#tags[@]} -eq 0 ]; then
        echo -e "${RED}未检测到 Tag。${NC}" >&2
        return 1
    fi

    echo -e "${CYAN}最近 10 个版本：${NC}" >&2
    for i in "${!tags[@]}"; do
        printf "  ${GREEN}[%d]${NC} %s\n" $((i + 1)) "${tags[$i]}" >&2
    done
    echo "" >&2

    while true; do
        printf "请输入版本序号 (1-%d) 或直接输入版本号: " ${#tags[@]} >&2
        read -r IN
        IN=$(echo "$IN" | xargs)
        [ -z "$IN" ] && return 1

        if [[ "$IN" =~ ^[0-9]+$ ]]; then
            if [ "$IN" -ge 1 ] && [ "$IN" -le ${#tags[@]} ]; then
                echo "${tags[$((IN - 1))]}"
                return 0
            else
                err "${RED}序号超出范围。${NC}" >&2
                continue
            fi
        else
            if git rev-parse -q --verify "refs/tags/$IN" >/dev/null 2>&1; then
                echo "$IN"
                return 0
            else
                err "${RED}未找到名为 '$IN' 的 Tag。${NC}" >&2
                continue
            fi
        fi
    done
}

apply_ref_and_reinstall() {
    local target_ref="$1"
    local action_desc="$2"
    local fail_msg="$3"

    info "${CYAN}正在${action_desc} ${target_ref} ...${NC}"
    if git reset --hard "$target_ref" 2>/dev/null; then
        ok "${GREEN}代码${action_desc}成功，正在更新依赖...${NC}"
        clean_and_reinstall_deps --quiet --label "依赖" || return
        ok "${GREEN}操作完成！${NC}"
        printf "是否启动？[Y/n] "; read -r YN
        [ "$YN" != "n" ] && [ "$YN" != "N" ] && fn_start
    else
        err "${RED}${fail_msg}${NC}"
    fi
}

fn_update() {
    if ! check_installed; then
        err "${RED}SillyTavern 未安装，请先安装。${NC}"
        return
    fi

    fn_stop 2>/dev/null || true
    cd "$INSTALL_DIR" || return

    info "${CYAN}正在拉取最新代码...${NC}"
    # ---- 修改点 1：强制拉取 release 分支到本地，解决 origin/release 引用缺失的问题 ----
    git fetch origin release:release 2>/dev/null || git fetch --all --tags 2>/dev/null

    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ "$current_branch" == "HEAD" ]; then
        current_branch="detached (HEAD)"
    fi
    local current_tag
    current_tag=$(git describe --tags --exact-match 2>/dev/null || echo "")
    local current_commit
    current_commit=$(git rev-parse --short HEAD 2>/dev/null)

    echo -e "${BLUE}当前分支: ${YELLOW}$current_branch${NC}"
    if [ -n "$current_tag" ]; then
        echo -e "${BLUE}当前版本 Tag: ${YELLOW}$current_tag${NC}"
    else
        echo -e "${BLUE}当前版本: ${YELLOW}未关联 Tag (commit $current_commit)${NC}"
    fi

    local -a available_tags=()
    while IFS= read -r tag; do
        available_tags+=("$tag")
    done < <(git tag --sort=-creatordate 2>/dev/null | head -n 10)

    echo ""
    echo -e "${BOLD}请选择更新目标：${NC}"
    echo -e "  ${GREEN}[1]${NC} release 分支 (推荐)"
    echo -e "  ${GREEN}[2]${NC} main 分支"
    if [ ${#available_tags[@]} -gt 0 ]; then
        echo -e "  ${GREEN}[3]${NC} 指定 Tag 版本"
    fi
    printf "请输入选项 [1-3] (默认 1): "
    read -r UPDATE_CHOICE
    UPDATE_CHOICE=${UPDATE_CHOICE:-1}

    # ---- 修改点 2：默认目标从 origin/release 改为本地 release 分支 ----
    local target_ref="release"
    local target_label="release 分支"
    local selected_tag=""

    case $UPDATE_CHOICE in
        2)
            # ---- 修改点 3：main 分支也改用本地 main 分支，确保 fetch 后可用 ----
            git fetch origin main:main 2>/dev/null
            target_ref="main"
            target_label="main 分支"
            ;;
        3)
            if [ ${#available_tags[@]} -eq 0 ]; then
                err "${RED}未检测到 Tag。${NC}"
                return
            fi
            selected_tag=$(choose_tag) || { err "${RED}操作取消。${NC}"; return; }
            target_ref="tags/$selected_tag"
            target_label="Tag $selected_tag"
            ;;
        *)
            # ---- 修改点 4：检查本地 release 分支是否存在，而非远程 origin/release ----
            if ! git show-ref --verify --quiet refs/heads/release 2>/dev/null; then
                git fetch origin main:main 2>/dev/null
                target_ref="main"
                target_label="main 分支 (release 不存在)"
                warn "${YELLOW}未找到 release 分支，已改为 main。${NC}"
            fi
            ;;
    esac

    apply_ref_and_reinstall "$target_ref" "更新到" "更新失败，请检查网络或版本号是否正确。"
}

fn_rollback() {
    if ! check_installed; then
        err "${RED}SillyTavern 未安装，请先安装。${NC}"
        return
    fi

    info "${CYAN}${BOLD}═══════ ⏪ 版本回退 ═══════${NC}"
    echo ""
    warn "${YELLOW}回退会覆盖当前代码，但数据 (data/) 不受影响。${NC}"
    echo ""

    printf "回退方式：${GREEN}[1]${NC} 指定 Tag  ${CYAN}[2]${NC} 指定 Commit  ${RED}[0]${NC} 取消: "
    read -r RB_CHOICE

    # ⚠️【修复】先判断取消，提前返回，避免执行网络请求
    if [ "$RB_CHOICE" = "0" ]; then
        err "${RED}操作取消。${NC}"
        return
    fi

    cd "$INSTALL_DIR" || return
    git fetch --all --tags 2>/dev/null

    local TARGET=""
    case $RB_CHOICE in
        2)
            printf "请输入 Commit Hash: "
            read -r TARGET
            if [ -z "$TARGET" ]; then
                err "${RED}输入为空，操作取消。${NC}"
                return
            fi
            ;;
        1)
            TARGET=$(choose_tag) || { err "${RED}操作取消。${NC}"; return; }
            TARGET="tags/$TARGET"
            ;;
        *)
            err "${RED}无效选项。${NC}"
            return
            ;;
    esac

    apply_ref_and_reinstall "$TARGET" "切换到" "切换失败，请检查输入是否正确。"
}