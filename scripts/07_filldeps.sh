#!/bin/bash
# 步骤7: 用正确的包名补齐系统库 -> 确定性补齐产物依赖 -> 复查
set -uo pipefail
R=/opt/kylin-arm64
W=/mnt/c/Users/Administrator/WorkBuddy/2026-10-12-17-09-29/kmg-build

echo "########## 1. 安装 tiny 运行库（focal 正确包名） ##########"
chroot "$R" /bin/bash -c "
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends \
    libbrotli1 libwayland-cursor0 libwayland-egl1 libwebpdemux2 2>&1 | tail -6
echo '--- 安装结果 ---'
for f in libbrotlidec.so.1 libbrotlicommon.so.1 libwayland-cursor.so.0 libwayland-egl.so.1 libwebpdemux.so.2; do
    p=/usr/lib/aarch64-linux-gnu/\$f
    [ -e \$p ] && echo \"  ok  \$f\" || echo \"  !!  缺 \$f\"
done
"

echo
echo "########## 2. 确定性补齐产物依赖 ##########"
cp "$W/scripts/fill_deps.sh" "$R/build/kmg/"
chroot "$R" /bin/bash /build/kmg/fill_deps.sh 2>&1 | tail -50

echo
echo "########## 3. 产物体积 ##########"
du -sh "$R/build/kmg/dist/KeymouseGo"
