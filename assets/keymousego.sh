#!/bin/sh
# KeymouseGo 启动器
#  程序本体放在只读的 /opt/keymousego，
#  用户数据（脚本/日志/插件/配置）放 ~/.local/share/keymousego。
#  程序内通过 KEYMOUSEGO_HOME 环境变量获知可写目录（见 deb 说明文档）。
set -e

APPDIR=/opt/keymousego

if [ -n "${KEYMOUSEGO_HOME:-}" ]; then
    DATA="$KEYMOUSEGO_HOME"
else
    DATA="${XDG_DATA_HOME:-$HOME/.local/share}/keymousego"
fi

mkdir -p "$DATA/scripts" "$DATA/logs" "$DATA/plugins" 2>/dev/null || true
export KEYMOUSEGO_HOME="$DATA"

# Wayland 会话下 pynput 无法捕获全局键鼠事件（需 root + uinput），给出明确提示
if [ "${XDG_SESSION_TYPE:-}" = "wayland" ] && [ "${KEYMOUSEGO_IGNORE_WAYLAND:-}" != "1" ]; then
    cat >&2 <<'MSG'
KeymouseGo: 检测到当前是 Wayland 会话，无法捕获全局鼠标键盘事件。
            请在登录界面切换到 "X11" / "UKUI on Xorg" 会话后重新启动。
            （如确需继续启动，可设置 KEYMOUSEGO_IGNORE_WAYLAND=1）
MSG
fi

exec "$APPDIR/KeymouseGo" "$@"
