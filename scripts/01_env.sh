#!/bin/bash
# 步骤1: 在 arm64 chroot 内准备 Python + Qt6 运行/构建依赖
set -uo pipefail
R=/opt/kylin-arm64

echo "===== 挂载伪文件系统 ====="
for d in proc sys dev dev/pts; do
  mkdir -p "$R/$d"
  if ! mountpoint -q "$R/$d"; then
    mount --bind "/$d" "$R/$d" 2>/dev/null && echo "mounted /$d"
  else
    echo "/$d already mounted"
  fi
done
mkdir -p "$R/build"

echo "===== 查看 /build 情况 ====="
ls -ld "$R/build"; df -h "$R/build" | tail -1

echo "===== apt-get update ====="
chroot "$R" /bin/bash -c "
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C
apt-get update 2>&1 | tail -5
"

echo "===== 安装构建/运行依赖 ====="
chroot "$R" /bin/bash -c "
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends \
  python3 python3-dev python3-pip python3-setuptools python3-wheel python3-tk \
  build-essential pkg-config ca-certificates \
  libgl1 libglx0 libegl1 libopengl0 libgles2 libglu1-mesa \
  libglib2.0-0 libfontconfig1 libfreetype6 libdbus-1-3 libexpat1 libuuid1 \
  libx11-6 libxext6 libxrender1 libxi6 libxtst6 libxcursor1 libxfixes3 libxrandr2 \
  libxkbcommon0 libxkbcommon-x11-0 libxcomposite1 libxdamage1 libxshmfence1 \
  libxcb1 libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 \
  libxcb-render-util0 libxcb-shape0 libxcb-xinerama0 libxcb-xkb1 libxcb-util1 \
  libxcb-sync1 libxcb-xfixes0 libxcb-glx0 \
  libasound2 libnss3 libnspr4 \
  xvfb x11-utils x11-apps xauth xclip \
  file binutils patchelf 2>&1 | tail -8
echo '--- 结果 ---'
python3 -V
python3 -m pip --version
gcc --version | head -1
which Xvfb xev xdpyinfo xclip
"

echo "EXIT=$?"
