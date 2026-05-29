# Boopa

[English](README.md) | [简体中文](README.zh-CN.md)

Boopa 会在屏幕四周亮起一圈呼吸光圈,提醒你「AI agent 需要你关注了」——并自带一个
`boopa` 命令行,让 agent 能直接在 hook 里触发它。当你趁 Claude Code 或 Cursor 跑长任务
时切去做别的事,屏幕边缘会一直呼吸般地发红,直到你回来;一旦你把焦点切回终端,光圈就
自动熄灭。

它以一个轻量的菜单栏 app 运行(没有 Dock 图标),命令行工具和 app 是同一个可执行文件。

## 效果图

| 屏幕边缘光圈 |
| :---: |
| ![屏幕边缘光圈模式](docs/images/glow.png)  |

|刘海红绿灯 |
| :---: |
| ![刘海红绿灯模式](docs/images/traffic-light.png) |

## 特性

- **屏幕边缘光圈**,覆盖每一块显示器——透明、可穿透点击的浮层,只在边缘绘制,完全不挡
  下面的内容。
- **两种光圈模式**:一次性 `flash`(亮一下自动淡出),以及持续的 `attention` 信标(亮到
  被清除为止)。
- **红绿灯信标**:`boopa light <red|yellow|green …>` 会从刘海里(没有刘海则从屏幕顶部
  正中)缓缓拉出一个横排红绿灯。一眼可读的状态信号——比如绿=完成、红=阻塞、黄=进行中
  ——亮哪几盏由你指定。与边缘光圈相互独立,互不影响。
- **聚焦自动熄灭**:切换到你的终端/编辑器时光圈自动消失——你已经在看了,它就不再打扰。
- **主题与动画**:`breathe`、`pulse`、`comet`、`blink`、`solid`;颜色、边缘、粗细、柔化、
  亮度、速度都可按主题或按次调节。
- **命令行优先**:一切都能从 shell 驱动,天然适合 agent hook。命令行在 agent 没运行时会
  自动把它拉起来。
- **菜单栏设置**:聚焦熄灭应用选择器、登录自启开关。
- **本地化**:英文与简体中文。

## 安装

### Homebrew(推荐)

```bash
brew install --cask Eilgnaw/tap/boopa
```

cask 会安装 `Boopa.app` 并把 `boopa` 命令行放到 PATH 上。发布版本经过 Developer ID 签名
和 Apple 公证,打开时不会有 Gatekeeper 警告。

### 从源码构建

需要 macOS 15+、Xcode 和 [mise](https://mise.jdx.dev)。

```bash
git clone https://github.com/Eilgnaw/boopa.git
cd boopa
make setup          # 用 mise 安装 Tuist、解析依赖、生成工程
open Boopa.xcworkspace   # 然后运行(⌘R)
```

运行起来后,把命令行链接到 PATH:

```bash
"$(mdfind -name Boopa.app | head -1)/Contents/MacOS/Boopa" install
# 或者直接运行构建产物里的:  Boopa install
```

## 使用

```bash
boopa attention                       # 持续光圈,直到被清除
boopa flash                           # 一次性脉冲,自动淡出
boopa clear                           # 熄灭当前光圈

boopa flash --color blue --edges top  # 仅顶部、蓝色
boopa attention --theme warn          # 使用配置里的命名主题
boopa flash --animation comet --speed 2 --duration 4
```

样式参数(覆盖所选主题):`--theme --color --edges --thickness --blur --animation
--speed --intensity --duration`。

### 红绿灯信标

一个从刘海里垂下来的横排红黄绿灯;传入要点亮的灯(默认 `red`)。默认一直亮到 `boopa
clear`,除非你指定了持续时间。

```bash
boopa light green                     # 放行 / 完成
boopa light red                       # 阻塞 / 需要你
boopa light yellow                    # 进行中 / 思考中
boopa light red yellow                # 同时点亮两盏
boopa light green --oneshot --duration 3   # 自动淡出
boopa light red --size 220            # 覆盖灯条宽度(默认等于刘海宽度)
```

参数:`--size`(灯条宽度,单位 pt,默认等于刘海宽度)、`--duration`、`--oneshot`。
用 `boopa clear` 熄灭(和清除光圈是同一个命令)。

管理命令:

```bash
boopa themes        # 列出已配置的主题
boopa status        # agent 是否在运行?当前配置 / clear_on_focus?
boopa install       # 把 boopa 链接到 PATH
boopa uninstall     # 移除链接
boopa quit          # 退出 agent
```

不需要先手动开 app——`flash`/`attention` 会按需把菜单栏 agent 拉起来。在菜单栏勾上
**登录时启动**,首次调用就没有启动延迟了。

## 配置

配置文件在 `~/.config/boopa/config.toml`(首次 `install` 时会写入一份起始模板):

```toml
default_theme = "attention"
auto_clear_seconds = 0       # 持续光圈的兜底超时;0 = 永不

# 切换焦点到这些应用时,熄灭持续光圈。
clear_on_focus = [
  "com.googlecode.iterm2",
  "com.microsoft.VSCode",
]

[themes.attention]
color     = "#FF3B30"   # 十六进制,或 red / green / blue 等名称
edges     = ["all"]     # all | top | bottom | left | right
thickness = 6.0
blur      = 24.0
animation = "breathe"   # breathe | pulse | comet | blink | solid
speed     = 1.0         # 每秒周期数
intensity = 0.9         # 0..1
mode      = "persistent"
flashes   = 3

[themes.success]
color = "#34C759"
animation = "pulse"
mode = "oneshot"
flashes = 2
```

用 `osascript -e 'id of app "Terminal"'` 查某个应用的 bundle id。你也可以在菜单栏的
**聚焦时自动熄灭…** 窗口里管理这个列表——用复选框勾选应用,改动即时保存。

## 接入 AI agent

Boopa 是中立的命令行,任何能跑 shell 命令的工具都能驱动它。见 [`examples/`](examples/):

- [`examples/claude-code.md`](examples/claude-code.md) —— 把 `boopa` 接到 Claude Code 的
  hook(`Notification` → 亮灯,`Stop` → 闪一下,`UserPromptSubmit` → 熄灭)。
- [`examples/cursor.md`](examples/cursor.md) —— Cursor 及基于规则的接法。
- [`examples/generic.sh`](examples/generic.sh) —— `boopa-run <命令>`,任意命令结束时按
  成功/失败闪绿/橙。

Claude Code 快速配置(`~/.claude/settings.json`):

```json
{
  "hooks": {
    "Notification": [{ "hooks": [{ "type": "command", "command": "boopa attention" }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "boopa flash --theme success" }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "boopa clear" }] }]
  }
}
```

## 开发

Boopa 用 [Tuist](https://tuist.dev)(版本由 mise 固定)生成 Xcode 工程,`.xcodeproj`
不入库。

```bash
make setup      # 安装工具、解析依赖、生成工程
make generate   # 改完 Project.swift 后重新生成
make clean      # 清理 Tuist 产物
```

## 友链

- **[Linux.do](https://linux.do)** — 学 AI，上 L 站