# 淡蓝酒馆管理器 v1.0（模块化版）
```bash
bash <(curl -sL https://gh-proxy.com/https://raw.githubusercontent.com/likesugar/Txst/main/deploy.sh)
```
国内代理，单文件
```bash
curl -O https://gh-proxy.com/https://raw.githubusercontent.com/likesugar/Txst/main/st单文件.sh && bash st单文件.sh
```
## 目录结构

```
~/
├── st.sh                          # 启动器（install.sh 创建）
├── st/
│   └── lib/                       # 模块目录（install.sh 复制）
│       ├── 0_core.sh
│       ├── 1_service.sh
│       ├── 2_install.sh
│       ├── 3_deps.sh
│       ├── 4_config.sh
│       ├── 5_extensions.sh
│       ├── 6_backup.sh
│       ├── 7_maintenance.sh
│       ├── 8_foxium.sh
│       ├── 9_uninstall.sh
│       └── 10_menu.sh
├── storage/                       # Termux 存储权限目录
│   └── shared/（软链接）
│       └── Download/
│           └── ST_Backups/        # 备份导出位置
├── SillyTavern/                   # 酒馆本体
├── SillyTavern_Backups/           # 备份目录
└── .bashrc                        # 自动菜单入口
```
```
💡 关于 ~/storage/shared
首次安装会检测该目录是否存在。若不存在，会引导执行 termux-setup-storage 申请存储权限。
授权后 ~/storage/shared/ 即为手机内部存储的软链接，可访问 /sdcard/。
备份导出功能会将 .tar.gz 复制到 ~/storage/shared/Download/ST_Backups/。
```
## 安装（Termux 中执行）

```bash
# 解压后进入本目录
bash install.sh
```

安装后：重开 Termux 自动弹面板，或随时输入 `st.sh`。

## 模块化说明

· st.sh 按序号加载 ~/st/lib/*.sh（0 核心最先、10 菜单最后）
· 改某个功能只需编辑对应模块文件，不用再翻两千行大文件
· 新增功能：在 lib/ 里加一个 xx_功能.sh，重跑 install.sh 即生效
## 更新管理器

以后改了模块，重新执行一次 `bash install.sh` 即可同步到 `~/st/lib`。
## Termux 保活

玩酒馆期间 Termux 必须保持后台运行：

- 耗电管理，允许完全后台行为
- 挂小窗模式
- 系统设置 → 省电策略 → 无限制
- 长按卡片 → 锁定
