#!/bin/bash
# 步骤2: 安装 pip 依赖（含 pyautogui 的隐式依赖）
set -uo pipefail
R=/opt/kylin-arm64

echo "===== 补充安装测试工具 ====="
chroot "$R" /bin/bash -c "
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends imagemagick xdotool x11-utils libpulse0 2>&1 | tail -4
which import xdotool xdpyinfo
"

echo
echo "===== 升级 pip/setuptools/wheel ====="
chroot "$R" /bin/bash -c "
python3 -m pip install --no-warn-script-location --upgrade \
  'pip==23.3.2' 'setuptools==68.2.2' 'wheel==0.42.0' 2>&1 | tail -5
python3 -m pip --version
"

echo
echo "===== 安装 requirements-universal.txt ====="
mkdir -p "$R/build/kmg"
cp /mnt/c/Users/Administrator/WorkBuddy/2026-10-12-17-09-29/keymousego_src/requirements-universal.txt "$R/build/kmg/"
chroot "$R" /bin/bash -c "
cd /build/kmg
python3 -m pip install --no-warn-script-location -r requirements-universal.txt 2>&1 | tail -25
"

echo
echo "===== 安装 pyautogui 的隐式依赖 ====="
chroot "$R" /bin/bash -c "
python3 -m pip install --no-warn-script-location \
  pyscreeze pymsgbox pytweening 'Pillow<11' 2>&1 | tail -10
"

echo
echo "===== 安装 pyinstaller ====="
chroot "$R" /bin/bash -c "
python3 -m pip install --no-warn-script-location 'pyinstaller==6.3.0' 2>&1 | tail -8
"

echo
echo "===== 依赖清单核对 ====="
chroot "$R" /bin/bash -c "
python3 -m pip list 2>/dev/null | grep -iE 'pyside|shiboken|qt-material|pynput|pyautogui|pyscreeze|pillow|loguru|json5|future|evdev|python-xlib|pyinstaller|six|pymsgbox|pytweening|pyperclip'
"

echo "EXIT=$?"
