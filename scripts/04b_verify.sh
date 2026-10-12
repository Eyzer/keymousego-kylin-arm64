#!/bin/bash
# 最终端到端验证（可独立重跑，产出交付截图与断言结果）
#
# 验证目标：
#   A) deb 安装 + 普通用户可启动（只读 /opt + 可写 ~/.local/share 的补丁）
#   B) GUI 渲染正常
#   C) 全局热键 F10 录制 -> F9 保存脚本（pynput/XRecord 录制链路）
#   D) GUI 热键 F6 回放刚录制的脚本（断言鼠标落到录制坐标）
#   E) CLI 模式回放 + 用 xev 交叉确认键鼠事件真的注入到了 X 服务器
set -uo pipefail
export LC_ALL=C.UTF-8

SHOTS=/build/kmg/shots
DATA=/home/kmgtest/.local/share/keymousego
PASS=0; FAIL=0
ok()   { echo "  [PASS] $1"; PASS=$((PASS+1)); }
bad()  { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
# 注意：不要写 `cmd | grep -q x`，pipefail + SIGPIPE 会把成功误判为失败
has()  { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
mouse_x() { echo "$1" | sed -n 's/.*x:\([0-9]*\).*/\1/p'; }
mouse_y() { echo "$1" | sed -n 's/.*y:\([0-9]*\).*/\1/p'; }

rm -rf "$SHOTS"; mkdir -p "$SHOTS"

echo "################ 0. 清理环境 ################"
pkill -f 'KeymouseGo' 2>/dev/null
pkill xev 2>/dev/null
pkill -f 'Xvfb :99' 2>/dev/null
sleep 2

echo
echo "################ 1. 安装 deb ################"
dpkg -i /build/kmg/out/keymousego_5.2.1-1_arm64.deb 2>&1 | tail -3
dpkg -l keymousego | tail -1
for p in /usr/bin/keymousego /usr/share/applications/keymousego.desktop /opt/keymousego/KeymouseGo; do
    [ -e "$p" ] && ok "$p 存在" || bad "$p 缺失"
done
echo "  安装体积: $(du -sh /opt/keymousego | cut -f1)"
ls /usr/share/icons/hicolor/*/apps/keymousego.png >/dev/null 2>&1 \
    && ok "图标已安装 $(ls /usr/share/icons/hicolor/*/apps/keymousego.png | wc -l) 个尺寸" \
    || bad "图标缺失"

echo
echo "################ 2. 准备测试用户与 Xvfb ################"
id kmgtest >/dev/null 2>&1 || useradd -m -s /bin/bash kmgtest
echo 'kmgtest:kmgtest' | chpasswd
rm -rf /home/kmgtest/.local/share/keymousego /home/kmgtest/test
mkdir -p /home/kmgtest/test
chown -R kmgtest:kmgtest /home/kmgtest

Xvfb :99 -screen 0 1280x900x24 -nolisten tcp -ac >/build/kmg/xvfb.log 2>&1 &
sleep 6
export DISPLAY=:99
xdpyinfo > /build/kmg/xdpyinfo.txt 2>&1
XINFO=$(cat /build/kmg/xdpyinfo.txt)
has "$XINFO" "XTEST"  && ok "Xvfb :99 启动，XTEST 扩展可用" || bad "XTEST 不可用（鼠标注入会失败）"
has "$XINFO" "RECORD" && ok "Xvfb :99 RECORD 扩展可用"       || bad "RECORD 不可用（录制会失败）"
has "$XINFO" "dimensions:    1280x900" && ok "屏幕分辨率 1280x900" || bad "分辨率不符"

echo
echo "################ 3. 启动目标窗口 xev + GUI ################"
# xev 放在 (700,200)-(1000,400)；回放目标点 (850,300) 正好落在它内部，
# 这样无窗口管理器（PointerRoot 焦点）时键盘事件也会投递给 xev。
xev -geometry 300x200+700+200 >/build/kmg/xev.log 2>&1 &
sleep 3
pgrep xev >/dev/null && ok "xev 目标窗口已启动" || bad "xev 未启动"

cat > /build/kmg/run_gui.sh <<'EOS'
#!/bin/sh
export DISPLAY=:99
exec keymousego
EOS
chmod 755 /build/kmg/run_gui.sh

setsid su - kmgtest -c '/build/kmg/run_gui.sh' </dev/null >/tmp/kmg_gui.log 2>&1 &
echo "  等待 GUI 启动（qemu 模拟下较慢）..."
sleep 45

if pgrep -f '/opt/keymousego/KeymouseGo' >/dev/null; then
    ok "GUI 进程存活（普通用户 kmgtest，非 root）"
else
    bad "GUI 进程未存活"; tail -20 /tmp/kmg_gui.log
fi

gui_wid=$(xdotool search --name 'KeymouseGo' 2>/dev/null | head -1)
[ -n "$gui_wid" ] && ok "KeymouseGo 窗口已创建 id=$gui_wid" || bad "未找到 KeymouseGo 窗口"
[ -f "$DATA/config.ini" ] && ok "数据目录补丁生效：$DATA/config.ini 已生成" || bad "config.ini 未生成（补丁失效）"
[ -d "$DATA/logs" ] && ok "日志目录已生成" || bad "日志目录未生成"
ls "$DATA"/logs/*.log >/dev/null 2>&1 && ok "应用日志已写入用户目录" || bad "应用日志缺失"
import -window root "$SHOTS/01_gui_start.png" && echo "  截图: 01_gui_start.png"

echo
echo "################ 3.5 中文化 + 底部作者信息 ################"
# 思路：不去 OCR 截图，而是用探针在真实 X 下实例化主窗口、直接读控件文本。
PROBE_HOME=/home/kmgtest/probe_home
rm -rf "$PROBE_HOME"; mkdir -p "$PROBE_HOME"
cp /build/kmg/probe_ui.py /home/kmgtest/probe_ui.py
chown -R kmgtest:kmgtest "$PROBE_HOME" /home/kmgtest/probe_ui.py

probe() {   # $1 = 传给探针的额外参数（可为空）
    timeout 120 su - kmgtest -c "cd /build/kmg/app \
        && DISPLAY=:99 KEYMOUSEGO_HOME=$PROBE_HOME KM_PROBE_APPDIR=/build/kmg/app \
        /usr/bin/python3 /home/kmgtest/probe_ui.py $1" 2>&1
}
getv() { echo "$1" | sed -n "s/^$2=//p" | head -1; }

P1=$(probe '')
echo "$P1" | sed 's/^/    /'
echo "  ---- 断言：首次启动即为全中文界面 ----"
expect() {  # $1=键 $2=期望值（比对的是一开始的 P1 输出）
    local got; got=$(getv "$P1" "$1")
    if [ "$got" = "$2" ]; then ok "$1 = $2"; else bad "$1 期望 [$2] 实际 [$got]"; fi
}
expect LANG          '简体中文'
expect GROUP_HOTKEYS '热键'
expect GROUP_CONFIG  '配置'
expect BT_RECORD     '开始录制'
expect BT_RUN        '启动'
expect BT_PAUSE      '暂停录制'
expect LABEL_START   '开始/暂停执行'
expect LABEL_RECORD  '开始/暂停录制'
expect LABEL_STOP    '终止录制/执行'
expect LABEL_LANG    '语言'
expect LABEL_SCRIPT  '脚本'
expect LABEL_RUNTIMES '执行次数'
expect LABEL_PRECISION '鼠标精度'
expect LABEL_THEME   '主题'
expect LABEL_VOLUME  '音量'
expect STATUS        '就绪...'
expect CURSOR_LABEL  '光标位置：'

AUTHOR=$(getv "$P1" AUTHOR)
echo "  作者信息栏文本: $AUTHOR"
has "$AUTHOR" 'Eyzer'      && ok "底部信息栏含作者 Eyzer"        || bad "底部信息栏缺少作者"
has "$AUTHOR" 'KeymouseGo' && ok "底部信息栏含来源项目 KeymouseGo" || bad "底部信息栏缺少来源项目"
has "$AUTHOR" '二次开发自'  && ok "底部信息栏标明二次开发来源"      || bad "底部信息栏未标明来源"
has "$(getv "$P1" STATUSBAR_CHILDREN)" 'label_author' \
    && ok "作者信息栏确实挂在状态栏（界面底部）" || bad "作者信息栏未挂载到状态栏"
has "$(getv "$P1" AUTHOR_OBJNAME)" 'label_author' && ok "控件命名 label_author" || bad "控件命名异常"
# 中文下不应再出现任何英文字面量
for kv in 'GROUP_HOTKEYS:Hotkeys' 'BT_RUN:Launch' 'LABEL_THEME:Theme' 'STATUS:Ready...'; do
    k=${kv%%:*}; v=${kv##*:}
    [ "$(getv "$P1" "$k")" = "$v" ] && bad "$k 仍是英文 $v" || ok "$k 已中文化（非 $v）"
done

echo "  ---- 断言：语言选择被记住（config.ini 往返） ----"
probe '--set-lang English' >/tmp/probe_en.txt 2>&1
has "$(cat /tmp/probe_en.txt)" 'CONFIG_LINE=Language=en' \
    && ok "切到 English 后 config.ini 记为 Language=en" || bad "英文选择未落盘"
expect_from() {  # $1=探针输出 $2=键 $3=期望
    local got; got=$(getv "$1" "$2")
    if [ "$got" = "$3" ]; then ok "$2 = $3"; else bad "$2 期望 [$3] 实际 [$got]"; fi
}
P2=$(probe '')
expect_from "$P2" LANG 'English'
expect_from "$P2" GROUP_HOTKEYS 'Hotkeys'
probe '--set-lang 简体中文' >/tmp/probe_cn.txt 2>&1
has "$(cat /tmp/probe_cn.txt)" 'CONFIG_LINE=Language=zh-cn' \
    && ok "切回简体中文后 config.ini 记为 Language=zh-cn" || bad "中文选择未落盘"
P3=$(probe '')
expect_from "$P3" LANG '简体中文'
expect_from "$P3" STATUS '就绪...'
echo "  ---- 断言：打包产物内确实带上了中文资源与作者串 ----"
[ -s /opt/keymousego/_internal/assets/i18n/zh-cn.qm ] \
    && ok "产物内含 zh-cn.qm ($(stat -c%s /opt/keymousego/_internal/assets/i18n/zh-cn.qm) 字节)" \
    || bad "产物内缺少 zh-cn.qm"
# 冻结产物里模块是 zlib 压缩的，grep 明文永远为空，必须走归档提取
FROZEN=$(/usr/bin/python3 /build/kmg/check_frozen.py /opt/keymousego/KeymouseGo 2>&1)
echo "$FROZEN" | grep -v '^RESULT=' | sed 's/^/  /'
has "$FROZEN" 'RESULT=PASS' \
    && ok "冻结可执行文件内确认包含作者串与来源串" \
    || bad "冻结可执行文件内未找到作者串/来源串"

echo
echo "################ 4. 全局热键录制 (F10 -> 注入 -> F9) ################"
xdotool key F10; sleep 3
xdotool mousemove --sync 850 300; sleep 0.7
xdotool click 1;                  sleep 0.7
xdotool key a;                    sleep 0.7
xdotool key F9;                   sleep 4
import -window root "$SHOTS/02_after_record.png" && echo "  截图: 02_after_record.png"

script=$(ls "$DATA"/scripts/*.json5 2>/dev/null | head -1)
if [ -n "$script" ]; then
    ok "录制脚本已落盘: $(basename "$script")"
    echo "  ---- 脚本内容 ----"
    sed 's/^/    /' "$script"
    has "$(cat "$script")" 'mouse left down' && ok "录制到鼠标按下事件" || bad "未录制到鼠标事件"
    has "$(cat "$script")" '"a"'             && ok "录制到键盘 a 事件"   || bad "未录制到键盘事件"
else
    bad "未生成录制脚本"
fi

echo
echo "################ 5. GUI 热键回放 (F6) ################"
xdotool mousemove --sync 200 800; sleep 1
echo "  回放前鼠标: $(xdotool getmouselocation)"
log_before=$(ls -t "$DATA"/logs/*.log | head -1)
xdotool key F6; sleep 3
import -window root "$SHOTS/03_gui_replay_running.png" && echo "  截图: 03_gui_replay_running.png（回放执行中）"
sleep 9
after=$(xdotool getmouselocation)
echo "  回放后鼠标: $after"
import -window root "$SHOTS/04_gui_replay_done.png" && echo "  截图: 04_gui_replay_done.png"
ax=$(mouse_x "$after"); ay=$(mouse_y "$after")
if [ "$ax" -ge 848 ] && [ "$ax" -le 852 ] && [ "$ay" -ge 298 ] && [ "$ay" -le 302 ]; then
    ok "GUI 热键回放生效：鼠标落到录制坐标 ($ax,$ay)"
else
    bad "GUI 回放未把鼠标移到录制坐标（实际 $ax,$ay，期望 850,300）"
fi
has "$(cat "$log_before")" "Script run finish" && ok "应用日志记录到脚本执行完成" \
                                              || echo "  [注意] 日志中未见 run finish"

echo
echo "################ 6. CLI 模式回放 + xev 交叉验证 ################"
cat > /home/kmgtest/test/demo.json5 <<'EOS'
{
  scripts: [
    {type: 'event', event_type: 'EM', action_type: 'mouse move',      action: [850, 300], delay: 400},
    {type: 'event', event_type: 'EM', action_type: 'mouse left down', action: [850, 300], delay: 200},
    {type: 'event', event_type: 'EM', action_type: 'mouse left up',   action: [850, 300], delay: 200},
    {type: 'event', event_type: 'EK', action_type: 'key down',        action: [0, 'a', 0], delay: 300},
    {type: 'event', event_type: 'EK', action_type: 'key up',          action: [0, 'a', 0], delay: 200},
    {type: 'event', event_type: 'EK', action_type: 'key down',        action: [0, 'b', 0], delay: 200},
    {type: 'event', event_type: 'EK', action_type: 'key up',          action: [0, 'b', 0], delay: 200}
  ]
}
EOS
chown kmgtest:kmgtest /home/kmgtest/test/demo.json5

pkill xev 2>/dev/null; sleep 2
xev -geometry 300x200+700+200 >/build/kmg/xev_cli.log 2>&1 &
sleep 4
pgrep xev >/dev/null && ok "xev 目标窗口就绪（CLI 测试）" || bad "xev 未启动"

xdotool mousemove --sync 100 100; sleep 1
echo "  执行前鼠标: $(xdotool getmouselocation)"
su - kmgtest -c 'DISPLAY=:99 keymousego /home/kmgtest/test/demo.json5 -rt 1' >/build/kmg/cli.log 2>&1
rc=$?
echo "  CLI 退出码 = $rc"
[ "$rc" -eq 0 ] && ok "CLI 模式执行成功" || bad "CLI 模式执行失败"
after2=$(xdotool getmouselocation)
echo "  执行后鼠标: $after2"
[ "$(mouse_x "$after2")" = "850" ] && ok "回放把鼠标移动到 (850,*)" || bad "鼠标未到达目标"

sleep 3
echo "  ---- xev 捕获到的注入事件（xev 自身日志） ----"
for k in MotionNotify ButtonPress ButtonRelease KeyPress KeyRelease; do
    printf '    %-14s %s\n' "$k" "$(grep -c "$k" /build/kmg/xev_cli.log 2>/dev/null)"
done
nkey=$(grep -c 'KeyPress' /build/kmg/xev_cli.log 2>/dev/null)
nbtn=$(grep -c 'ButtonPress' /build/kmg/xev_cli.log 2>/dev/null)
nmot=$(grep -c 'MotionNotify' /build/kmg/xev_cli.log 2>/dev/null)
[ "$nmot" -gt 0 ] && ok "xev 收到鼠标移动 MotionNotify x$nmot" || bad "xev 未收到鼠标移动"
[ "$nbtn" -gt 0 ] && ok "xev 收到鼠标点击 ButtonPress x$nbtn" || bad "xev 未收到鼠标点击"
[ "$nkey" -gt 0 ] && ok "xev 收到键盘按键 KeyPress x$nkey"    || bad "xev 未收到键盘按键"
echo "  ---- 事件投递目标窗口 & 按键明细（取自 xev 日志） ----"
grep -E 'KeyPress event|keysym' /build/kmg/xev_cli.log 2>/dev/null | head -6 | sed 's/^/    /'
xev_target=$(sed -n 's/.*KeyPress event.*window \(0x[0-9a-f]*\).*/\1/p' /build/kmg/xev_cli.log | head -1)
[ -n "$xev_target" ] && ok "键盘事件确实投递到 xev 窗口 $xev_target" || echo "  [注意] 未能从日志解析目标窗口"
has "$(grep -o 'keysym 0x61, a' /build/kmg/xev_cli.log)" "keysym 0x61, a" \
    && ok "xev 收到键 a" || bad "xev 未收到键 a"
has "$(grep -o 'keysym 0x62, b' /build/kmg/xev_cli.log)" "keysym 0x62, b" \
    && ok "xev 收到键 b" || bad "xev 未收到键 b"

echo
echo "################ 7. 收尾 ################"
pkill -f '/opt/keymousego/KeymouseGo' 2>/dev/null
pkill xev 2>/dev/null
echo "  应用日志尾部："
tail -5 "$(ls -t "$DATA"/logs/*.log | head -1)" | sed 's/^/    /'
ls -l "$SHOTS"

echo
echo "################ 结果汇总 ################"
echo "  PASS=$PASS  FAIL=$FAIL"
