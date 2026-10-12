#!/bin/bash
O=/mnt/c/Users/Administrator/WorkBuddy/2026-10-12-17-09-29/kmg-build
rm -f "$O/out/shots/"*.png
cp /opt/kylin-arm64/build/kmg/shots/*.png "$O/out/shots/"
cp /tmp/kmg_verify4.log "$O/out/验证日志.txt"
cp "$O/使用说明.md" "$O/out/使用说明.md"
cp "$O/out/keymousego_5.2.1-1_arm64.deb" "$O/out/" 2>/dev/null
ls -l "$O/out"
echo "--- shots ---"
ls -l "$O/out/shots"
echo "--- md5 ---"
md5sum "$O/out/shots/"*.png
echo "--- deb 信息 ---"
dpkg-deb -I "$O/out/keymousego_5.2.1-1_arm64.deb" | head -12
