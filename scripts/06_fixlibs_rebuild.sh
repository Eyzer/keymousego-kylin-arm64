#!/bin/bash
# 补齐 chroot 里被 PyInstaller 漏掉的系统运行库，然后重新打包 + 复查
set -uo pipefail
R=/opt/kylin-arm64
W=/mnt/c/Users/Administrator/WorkBuddy/2026-10-12-17-09-29/kmg-build

echo "########## 1. 补齐缺失的系统库 ##########"
chroot "$R" /bin/bash -c "
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends \
    libbrotlidec1 libbrotlicommon1 \
    libwayland-cursor0 libwayland-egl1 \
    libwebpdemux2 libwebp7 2>&1 | tail -8
echo '--- 安装结果 ---'
ls -l /usr/lib/aarch64-linux-gnu/libbrotlidec.so.1 \
      /usr/lib/aarch64-linux-gnu/libbrotlicommon.so.1 \
      /usr/lib/aarch64-linux-gnu/libwayland-cursor.so.0 \
      /usr/lib/aarch64-linux-gnu/libwebpdemux.so.2 2>&1
"

echo
echo "########## 2. 重新打包（PyInstaller） ##########"
sed -i 's/\r$//' "$W/scripts/03_build.sh"
bash "$W/scripts/03_build.sh" 2>&1 | tail -20

echo
echo "########## 3. 复查缺失动态库 ##########"
cp "$W/scripts/scan_missing.sh" "$R/build/kmg/"
chroot "$R" /bin/bash /build/kmg/scan_missing.sh 2>&1 | head -40
