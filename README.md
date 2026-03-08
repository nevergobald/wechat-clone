# 绿泡泡 - macOS 微信多开脚本

在 macOS 上同时运行多个微信账号。

## 原理

macOS 通过 **Bundle ID** 唯一标识每个 App，同一 Bundle ID 只能运行一个实例。

本脚本通过四步绕过这个限制：

1. **复制** WeChat.app 得到副本
2. **修改 Bundle ID** 让系统把副本当成另一个 App
3. **重新签名** 让 macOS 允许启动修改后的 App
4. **去除隔离标记** 避免 Gatekeeper 拦截

> 本方法仅适用于 macOS，Windows 用户可直接使用微信官方多开功能。

## 安装

```bash
mkdir -p ~/bin
curl -fsSL https://raw.githubusercontent.com/nevergobald/wechat-clone/main/wechat-clone.sh \
  -o ~/bin/wechat-clone.sh
chmod +x ~/bin/wechat-clone.sh
```

## 使用

| 命令 | 说明 |
|------|------|
| `sudo ~/bin/wechat-clone.sh dual` | 双开（原版 + 绿泡泡） |
| `sudo ~/bin/wechat-clone.sh multi 3` | 同时开 3 个副本 |
| `sudo ~/bin/wechat-clone.sh rebuild` | 微信更新后重建副本 |
| `sudo ~/bin/wechat-clone.sh kill` | 关闭所有微信进程 |
| `sudo ~/bin/wechat-clone.sh list` | 查看当前所有副本 |

加 `--yes` 跳过确认提示：

```bash
sudo ~/bin/wechat-clone.sh dual --yes
```

## 常见问题

**Q：为什么需要 sudo？**
修改 `/Applications/` 目录和对 App 重签名需要管理员权限。

**Q：微信更新后副本打不开怎么办？**
运行 `rebuild` 命令，从新版微信重新生成副本。

**Q：会影响原版微信吗？**
不会，脚本只复制，不修改原版 WeChat.app。

**Q：副本和原版的聊天记录共享吗？**
不共享，Bundle ID 不同，数据目录完全隔离。

## 免责声明

本项目仅供学习研究使用，请遵守微信用户协议，合理使用。
