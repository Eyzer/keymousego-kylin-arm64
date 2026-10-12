#!/bin/bash
# 步骤4: 在 arm64 环境安装 deb 并做真实功能验证
#  1) dpkg 安装 / 文件落位 / 依赖检查
#  2) 以【普通用户】启动 GUI（验证只读安装目录 + 可写数据目录的补丁是否生效）
#  3) 全局热键 F10 录制 -> 注入事件 -> F9 停止，检查脚本落盘
#  4) CLI 模式回放脚本，用 xev 交叉确认键鼠注入真的到达 X 服务器
set -uo pipefail
export LC_ALL=C.UTF-8

SHOTS=/build/kmg/shots
mkdir -p "$SHOTS"

echo "################ 1/6 安装 deb ################"
dpkg -i /build/kmg/out/keymousego_5.2.1-1_arm64.deb 2>&1 | tail -6
echo "--- dpkg 状态 ---"
dpkg -l keymousego | tail -2
echo "--- 关键文件 ---"
ls -l /usr/bin/keymousego /usr/share/applications/keymousego.desktop 2>&1
ls /usr/share/icons/hicolor/*/apps/keymousego.png 2>&1
du -sh /opt/keymousego 2>&1
echo "--- 主程序动态依赖 ---"
ldd /opt/keymousego/KeymouseGo 2>&1 | head -12
echo "--- 主程序缺失依赖检查 ---"
ldd /opt/keymousego/KeymouseGo 2>&1 | grep -i 'not found' || echo "  (无缺失)"

echo
echo "################ 2/6 准备测试用户 ################"
id kmgtest >/dev/null 2>&1 || useradd -m -s /bin/bash kmgtest
echo 'kmgtest:kmgtest' | chpasswd
rm -rf /home/kmgtest/.local/share/keymousego
mkdir -p /home/kmgtest/.local/share /home/kmgtest/test
chown -R kmgtest:kmgtest /home/kmgtest
echo "kmgtest uid=$(id -u kmgtest)"

echo
echo "################ 3/6 启动 Xvfb ################"
pkill -f 'Xvfb :99' 2>/dev/null; sleep 1
Xvfb :99 -screen 0 1280x900x24 -nolisten tcp -ac >/build/kmg/xvfb.log 2>&1 &
sleep 5
export DISPLAY=:99
xdpyinfo | grep -E 'dimensions:' 
echo "--- 关键扩展 ---"
xdpyinfo | grep -iE 'XTEST|RECORD|XInputExtension' | head -5

echo
echo "################ 4/6 以普通用户启动 GUI ################"
cat > /build/kmg/run_gui.sh <<'EOS'
#!/bin/sh
export DISPLAY=:99
exec keymousego
EOS
chmod 755 /build/kmg/run_gui.sh

setsid su - kmgtest -c '/build/kmg/run_gui.sh' </dev/null >/tmp/kmg_gui.log 2>&1 &
sleep 45

echo "--- 进程 ---"
pgrep -af KeymouseGo | head -3
echo "--- 用户数据目录（补丁是否生效） ---"
find /home/kmgtest/.local/share/keymousego 2>/dev/null | head -12
echo "--- GUI 日志（尾部） ---"
tail -15 /tmp/kmg_gui.log

WID=$(xdotool search --name 'KeymouseGo' 2>/dev/null | head -1)
echo "--- 窗口 id = $WID ---"
if [ -n "$WID" ]; then
  xdotool getwindowgeometry "$WID"
  xdotool getwindowname "$WID"
fi
import -window root "$SHOTS/01_gui_start.png" 2>/dev/null && echo "已截图 01_gui_start.png"

echo
echo "################ 5/6 全局热键录制 ################"
# 目标窗口：用来确认注入事件
xev -geometry 300x200+700+200 >/build/kmg/xev1.log 2>&1 &
sleep 3
XEV=$(xdotool search --name 'xev' 2>/dev/null | head -1)
echo "xev WID=$XEV"

xdotool key F10; sleep 3
import -window root "$SHOTS/02_recording.png" 2>/dev/null && echo "已截图 02_recording.png"
echo "--- 注入操作 ---"
xdotool mousemove --sync 400 250; sleep 0.7
xdotool mousemove --sync 900 500; sleep 0.7
xdotool click 1;                 sleep 0.7
xdotool key a;                   sleep 0.7
xdotool key F9;                  sleep 4

echo "--- 录制产物 ---"
ls -l /home/kmgtest/.local/share/keymousego/scripts/ 2>&1
for f in /home/kmgtest/.local/share/keymousego/scripts/*.json5; do
  [ -f "$f" ] && { echo "=== $f ==="; cat "$f"; }
done
import -window root "$SHOTS/03_after_record.png" 2>/dev/null

echo
echo "################ 6/6 CLI 模式回放 ################"
cat > /home/kmgtest/test/demo.json5 <<'EOS'
{
  scripts: [
    {type: 'event', event_type: 'EM', action_type: 'mouse move',     action: [640, 450], delay: 400},
    {type: 'event', event_type: 'EM', action_type: 'mouse left down', action: [640, 450], delay: 200},
    {type: 'event', event_type: 'EM', action_type: 'mouse left up',   action: [640, 450], delay: 200},
    {type: 'event', event_type: 'EK', action_type: 'key down',        action: [0, 'a', 0], delay: 300},
    {type: 'event', event_type: 'EK', action_type: 'key up',          action: [0, 'a', 0], delay: 200},
    {type: 'event', event_type: 'EK', action_type: 'key down',        action: [0, 'b', 0], delay: 200},
    {type: 'event', event_type: 'EK', action_type: 'key up',          action: [0, 'b', 0], delay: 200}
  ]
}
EOS
chown -R kmgtest:kmgtest /home/kmgtest/test

pkill xev 2>/dev/null; sleep 1
xev -geometry 300x200+700+200 >/build/kmg/xev2.log 2>&1 &
sleep 3
XEV2=$(xdotool search --name 'xev' 2>/dev/null | head -1)
echo "xev2 WID=$XEV2"
xdotool windowactivate "$XEV2" 2>/dev/null || xdotool windowfocus "$XEV2" 2>/dev/null || true
: > /build/kmg/xev2.log
sleep 1

echo "--- 执行前鼠标位置 ---"
xdotool getmouselocation

echo "--- 运行 CLI 回放 ---"
su - kmgtest -c 'DISPLAY=:99 keymousego /home/kmgtest/test/demo.json5 -rt 1' >/build/kmg/cli.log 2>&1
echo "rc=$?"
tail -20 /build/kmg/cli.log

echo "--- 执行后鼠标位置 ---"
xdotool getmouselocation
sleep 2

echo "--- xev 收到的事件计数 ---"
for k in KeyPress KeyRelease ButtonPress ButtonRelease MotionNotify; do
  printf '  %-14s %s\n' "$k" "$(grep -c "$k" /build/kmg/xev2.log 2>/dev/null)"
done
echo "--- xev 中的按键细节 ---"
grep -A1 'KeyPress' /build/kmg/xev2.log 2>/dev/null | head -12

echo
echo "################ 完成 ################"
ls -l "$SHOTS"
