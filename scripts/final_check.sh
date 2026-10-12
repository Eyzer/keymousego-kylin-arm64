#!/bin/bash
echo "=== 交付包一致性校验（chroot 内构建产物 vs 工作区副本）==="
md5sum /opt/kylin-arm64/build/kmg/out/keymousego_5.2.1-1_arm64.deb
md5sum /mnt/c/Users/Administrator/WorkBuddy/2026-10-12-17-09-29/kmg-build/out/keymousego_5.2.1-1_arm64.deb

echo
echo "=== deb 完整性（dpkg-deb 自检）==="
dpkg-deb --info /opt/kylin-arm64/build/kmg/out/keymousego_5.2.1-1_arm64.deb > /dev/null && echo "control 解析正常"
dpkg-deb --contents /opt/kylin-arm64/build/kmg/out/keymousego_5.2.1-1_arm64.deb > /dev/null && echo "data 归档完整"

echo
echo "=== 包内关键路径 ==="
for p in ./usr/bin/keymousego ./usr/share/applications/keymousego.desktop \
         ./opt/keymousego/KeymouseGo ./usr/share/icons/hicolor/256x256/apps/keymousego.png \
         ./usr/share/doc/keymousego/copyright ./usr/share/doc/keymousego/README.md \
         ./usr/share/doc/keymousego/LICENSE.txt; do
    dpkg-deb --contents /opt/kylin-arm64/build/kmg/out/keymousego_5.2.1-1_arm64.deb \
      | grep -q -- "$p" && echo "  ok  $p" || echo "  !!  缺 $p"
done

echo
echo "=== 打包进产物的私有运行库 ==="
ls /opt/kylin-arm64/build/kmg/dist/KeymouseGo/_internal/ | grep -E 'brotli|wayland-cursor|wayland-egl|webpdemux'

echo
echo "=== 工作区交付目录 ==="
ls -lh /mnt/c/Users/Administrator/WorkBuddy/2026-10-12-17-09-29/kmg-build/out/
echo "--- shots ---"
ls -lh /mnt/c/Users/Administrator/WorkBuddy/2026-10-12-17-09-29/kmg-build/out/shots/
