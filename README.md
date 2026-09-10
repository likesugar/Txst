# 自用· Termux 禁止使用
国内源加速，无需梯子。

## 一条命令安装

打开 Termux，粘贴回车：

```bash
curl -O https://raw.githubusercontent.com/likesugar/termux-sillytavern/main/st.sh && bash st.sh
```
国内代理
```bash
curl -O https://gh-proxy.com/https://raw.githubusercontent.com/likesugar/termux-sillytavern/main/st.sh && bash st.sh
```
## 功能

首次运行自动安装，之后每次打开 Termux 进入控制面板：

```
    ═══ 管理 ═══
  [1] 启动  [2] 停止  [3] 重启
  [4] 扩展管理  [5] 推荐配置

  ═══ 维护 ═══
  [6] 更新  [7] 日志  [8] 版本回退/切换
  [9] 清理残余文件  [10]  Foxium 工具箱

  ═══ 数据 ═══
  [11] 备份  [12] 恢复  [13] 重装依赖

  ═══ 局域网 ═══
  [y] 开启  [n] 已关闭 [m] 密码验证: 未开启

  ═══ 其他 ═══
  [99] 卸载  [0] 退出
```
## Termux 保活

玩酒馆期间 Termux 必须保持后台运行：

- 耗电管理，允许完全后台行为
- 挂小窗模式
- 系统设置 → 省电策略 → 无限制
- 长按卡片 → 锁定

## 数据目录

用 MT 管理器授权 Termux 后：

| 路径 | 说明 |
|------|------|
| `SillyTavern/data/default-user` | 用户数据（角色卡/聊天/设置） |
| `SillyTavern_Backups` | 备份文件 |
## 许可证

MIT License
