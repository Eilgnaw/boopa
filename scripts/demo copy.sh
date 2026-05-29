#!/usr/bin/env bash
#
# demo.sh — interactive walkthrough of Boopa's features.
# 在终端里运行,每步按回车继续,Ctrl-C 随时退出。

set -uo pipefail

# 找到 boopa:优先 PATH,其次已构建的 Boopa.app。
BOOPA="$(command -v boopa || true)"
if [ -z "$BOOPA" ]; then
  APP="$(mdfind -name Boopa.app 2>/dev/null | head -n1)"
  [ -n "$APP" ] && BOOPA="$APP/Contents/MacOS/Boopa"
fi
if [ -z "${BOOPA:-}" ] || [ ! -x "$BOOPA" ]; then
  echo "找不到 boopa。请先运行 'boopa install',或确认 Boopa.app 已构建。" >&2
  exit 1
fi

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
dim()  { printf "\033[2m%s\033[0m\n" "$1"; }
rule() { dim "────────────────────────────────────────────"; }

# 描述 + 显示命令 + 等回车 + 执行
run() {
  local desc="$1"; shift
  echo; rule; bold "▶ $desc"
  dim "  \$ boopa $*"
  read -r -p "  回车执行(Ctrl-C 退出)… " _
  local spoken="${desc%%(*}"; spoken="${spoken%%（*}"   # 去掉半角/全角括号说明,保持简短
  say "$spoken" &
  "$BOOPA" "$@" || true
}

# 只讲解,不执行命令
note() {
  echo; rule; bold "▶ $1"; shift
  for line in "$@"; do printf "  %s\n" "$line"; done
  read -r -p "  回车继续… " _
}

echo; bold "Boopa 功能演示"
dim "屏幕边缘光圈提醒。按回车一步步看,Ctrl-C 随时退出。"
read -r -p "回车开始… " _

run "一次性脉冲(flash,默认主题)" flash
run "持续光圈(attention,红色呼吸,亮到清除为止)" attention
run "熄灭光圈(clear)" clear

run "换颜色:蓝色" flash --color blue
run "换颜色:十六进制 #FF9F0A(橙)" flash --color "#FF9F0A"

run "只亮顶部边缘" flash --color purple --edges top --duration 3
run "只亮左右两条边" flash --color green --edges left right --duration 3

note "五种动画风格" \
  "breathe 呼吸 / pulse 脉冲 / comet 跑马灯 / blink 闪烁 / solid 常亮" \
  "下面每种来一下,各约 3 秒。"
run "动画:breathe 呼吸" flash --animation breathe --color "#FF3B30" --duration 3
run "动画:pulse 脉冲"   flash --animation pulse   --color "#0A84FF" --duration 3
run "动画:comet 跑马灯(沿圆角边框跑)" flash --animation comet --color purple --duration 4
run "动画:blink 闪烁"   flash --animation blink   --color "#FFD60A" --duration 3
run "动画:solid 常亮"   flash --animation solid   --color "#34C759" --duration 3

run "更粗、更柔、更亮" flash --color "#FF2D55" --thickness 18 --blur 50 --intensity 1 --duration 3
run "跑马灯转快一点(speed 2)" flash --animation comet --color "#5E5CE6" --speed 2 --duration 4

run "列出配置里的主题(themes)" themes
run "用 success 主题(绿色脉冲一下)" flash --theme success
run "用 warn 主题(橙色)" flash --theme warn

run "持续光圈 + 4 秒兜底超时" attention --duration 4

note "聚焦自动熄灭" \
  "持续光圈会在你切到终端/编辑器(clear_on_focus 列表里的 app)时自动熄灭。" \
  "试法:下一步触发 attention 后,切到别的 app(如浏览器),再切回你的终端 —— 光圈应自动消失。" \
  "也可在菜单栏 Boopa 图标 → Clear on Focus… 里管理这些 app。"
run "触发持续光圈(然后切走再切回终端试试)" attention

run "查看 agent 状态与当前配置(status)" status
run "收尾:熄灭" clear

echo; rule; bold "演示结束"
dim "菜单栏图标里还有:Test Glow / Dismiss / Launch at Login / 开源地址。"
dim "开源地址:https://github.com/Eilgnaw/boopa  (顺手点个 Star)"
