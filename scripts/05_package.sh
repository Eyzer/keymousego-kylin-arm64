#!/bin/bash
# 步骤5: 组装 deb 包
#  用宿主的 dpkg-deb 打包（只需归档，与目标架构无关），避免 qemu 下压缩过慢
set -uo pipefail
R=/opt/kylin-arm64
W=/mnt/c/Users/Administrator/WorkBuddy/2026-10-12-17-09-29/kmg-build
PKG="$R/build/kmg/pkg"
DIST="$R/build/kmg/dist/KeymouseGo"
OUT="$R/build/kmg/out"
VER=5.2.1-1

echo "===== 0. 准备 rsvg ====="
chroot "$R" /bin/bash -c "command -v rsvg-convert >/dev/null || apt-get install -y --no-install-recommends librsvg2-bin >/dev/null 2>&1; command -v rsvg-convert"

echo "===== 1. 清理并建立包目录 ====="
rm -rf "$PKG" "$OUT"
mkdir -p "$PKG/DEBIAN" "$PKG/opt/keymousego" "$PKG/usr/bin" \
         "$PKG/usr/share/applications" "$PKG/usr/share/pixmaps" \
         "$PKG/usr/share/doc/keymousego"

echo "===== 2. 渲染图标 ====="
# 去掉 CRLF 后拷进 chroot
sed 's/\r$//' "$W/assets/keymousego.svg" > "$R/build/kmg/keymousego.svg"
for s in 16 24 32 48 64 128 256; do
  mkdir -p "$PKG/usr/share/icons/hicolor/${s}x${s}/apps"
  chroot "$R" rsvg-convert -w "$s" -h "$s" \
      -o "/build/kmg/pkg/usr/share/icons/hicolor/${s}x${s}/apps/keymousego.png" \
      /build/kmg/keymousego.svg || echo "  !! ${s} 渲染失败"
done
cp "$PKG/usr/share/icons/hicolor/256x256/apps/keymousego.png" "$PKG/usr/share/pixmaps/keymousego.png"
ls -l "$PKG/usr/share/icons/hicolor/"*/apps/keymousego.png

echo "===== 3. 安装程序本体 ====="
cp -a "$DIST/." "$PKG/opt/keymousego/"
chmod 755 "$PKG/opt/keymousego/KeymouseGo"
# 去掉 PyInstaller 的调试符号残留，减小体积
find "$PKG/opt/keymousego" -name '*.dbg' -delete 2>/dev/null
du -sh "$PKG/opt/keymousego"

echo "===== 4. 启动器 / desktop / 文档 ====="
sed 's/\r$//' "$W/assets/keymousego.sh" > "$PKG/usr/bin/keymousego"
chmod 755 "$PKG/usr/bin/keymousego"
sed 's/\r$//' "$W/assets/keymousego.desktop" > "$PKG/usr/share/applications/keymousego.desktop"
chmod 644 "$PKG/usr/share/applications/keymousego.desktop"

# copyright（Debian 规范要求）
{
  echo "Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/"
  echo "Upstream-Name: KeymouseGo"
  echo "Source: https://github.com/taojy123/KeymouseGo"
  echo "Comment: 本包为上游 v5.2.1 (commit 49577ed) 的 arm64/银河麒麟 重新打包版本，"
  echo " 未修改任何功能逻辑，仅对数据目录定位做了打包适配（见 README.md）。"
  echo
  echo "Files: *"
  echo "Copyright: 2018-2024 taojy123 <taojy123@qq.com>"
  echo "License: GPL-2+"
  echo " This program is free software; you can redistribute it and/or modify"
  echo " it under the terms of the GNU General Public License as published by"
  echo " the Free Software Foundation; either version 2 of the License, or"
  echo " (at your option) any later version."
  echo " ."
  echo " This program is distributed in the hope that it will be useful,"
  echo " but WITHOUT ANY WARRANTY; without even the implied warranty of"
  echo " MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the"
  echo " GNU General Public License for more details."
  echo " ."
  echo " On Debian systems, the complete text of the GNU General Public"
  echo " License version 2 can be found in \"/usr/share/common-licenses/GPL-2\"."
  echo
  echo "Files: opt/keymousego/*"
  echo "Copyright: 2018-2024 taojy123 <taojy123@qq.com>"
  echo "Comment: PyInstaller 打包产物，内含 CPython 解释器 (PSF-2.0)、"
  echo " Qt 6 / PySide6 (LGPL-3.0) 及其他第三方库，各自遵循其原始许可。"
  echo "License: GPL-2+"
} > "$PKG/usr/share/doc/keymousego/copyright"

# 上游原始 LICENSE 一并保留
sed 's/\r$//' /mnt/c/Users/Administrator/WorkBuddy/2026-10-12-17-09-29/keymousego_src/LICENSE \
  > "$PKG/usr/share/doc/keymousego/LICENSE.txt"

# 中文说明
sed 's/\r$//' "$W/assets/README-deb.md" > "$PKG/usr/share/doc/keymousego/README.md"

echo "===== 5. 生成 md5sums ====="
( cd "$PKG" && find . -path ./DEBIAN -prune -o -type f -print \
    | sed 's|^\./||' | sort | xargs md5sum > DEBIAN/md5sums )
wc -l < "$PKG/DEBIAN/md5sums"

echo "===== 6. 控制文件 ====="
SIZE=$(du -sk --exclude=DEBIAN "$PKG" | cut -f1)
echo "Installed-Size=${SIZE} KB"
sed "s/@SIZE@/${SIZE}/" "$W/deb/control" > "$PKG/DEBIAN/control"
sed 's/\r$//' "$W/deb/postinst" > "$PKG/DEBIAN/postinst"; chmod 755 "$PKG/DEBIAN/postinst"
sed 's/\r$//' "$W/deb/postrm"  > "$PKG/DEBIAN/postrm";  chmod 755 "$PKG/DEBIAN/postrm"
cat "$PKG/DEBIAN/control"

echo "===== 7. 打包 ====="
mkdir -p "$OUT"
dpkg-deb --build --root-owner-group -Zxz -z6 --uniform-compression \
    "$PKG" "$OUT/keymousego_${VER}_arm64.deb"
echo "rc=$?"
ls -lh "$OUT"
echo "--- 包信息 ---"
dpkg-deb -I "$OUT/keymousego_${VER}_arm64.deb"
echo "--- 包内容(前 25) ---"
dpkg-deb -c "$OUT/keymousego_${VER}_arm64.deb" | head -25
echo "--- 包内容条目数 ---"
dpkg-deb -c "$OUT/keymousego_${VER}_arm64.deb" | wc -l
