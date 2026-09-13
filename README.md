# 淡蓝酒馆管理器 v1.0（模块化版）
```bash
curl -O https://raw.githubusercontent.com/likesugar/Txst/main/st.sh && bash st.sh
```
国内代理
```bash
curl -O https://gh-proxy.com/https://raw.githubusercontent.com/likesugar/Txst/main/st.sh && bash st.sh
```
## 目录结构

```
st-manager/
├── install.sh        # 安装器：把模块复制到 ~/st/lib，创建 ~/st.sh
├── st.sh             # 启动器（加载模块并进入面板）
└── lib/
    ├── 00_core.sh         # 常量/颜色/工具函数/YAML读写/瘦身/日志轮转
    ├── 10_service.sh      # 启动/停止/重启/日志/访问地址
    ├── 20_install.sh      # 首次安装
    ├── 30_deps.sh         # 重装依赖 (Fix npm)
    ├── 40_config.sh       # 推荐配置/局域网/密码/白名单
    ├── 50_extensions.sh   # 扩展管理
    ├── 60_backup.sh       # 备份/恢复/导出
    ├── 70_maintenance.sh  # 清理/更新/回退
    ├── 80_foxium.sh       # Foxium 工具箱
    ├── 90_uninstall.sh    # 系统级清除
    └── 99_menu.sh         # 面板显示与主循环
```

## 安装（Termux 中执行）

```bash
# 解压后进入本目录
bash install.sh
```

安装后：重开 Termux 自动弹面板，或随时输入 `st.sh`。

## 模块化说明

- `st.sh` 按序号加载 `~/st/lib/*.sh`（00 核心最先、99 菜单最后）
- 改某个功能只需编辑对应模块文件，不用再翻两千行大文件
- 新增功能：在 lib/ 里加一个 `xx_功能.sh`，重跑 install.sh 即生效
## 更新管理器

以后改了模块，重新执行一次 `bash install.sh` 即可同步到 `~/st/lib`。
## Termux 保活

玩酒馆期间 Termux 必须保持后台运行：

- 耗电管理，允许完全后台行为
- 挂小窗模式
- 系统设置 → 省电策略 → 无限制
- 长按卡片 → 锁定