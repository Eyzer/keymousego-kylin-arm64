#!/bin/bash
D=/opt/kylin-arm64/build/kmg/dist/KeymouseGo/_internal
echo "=== _internal 全部条目数: $(ls "$D" | wc -l) ==="
echo
echo "=== xcb / xkb / wayland 相关 ==="
ls "$D" | grep -iE 'xcb|xkb|x11|wayland|xkeyboard' 
echo
echo "=== Qt platforms 插件 ==="
ls "$D/PySide6/Qt/plugins/platforms"
echo "=== Qt multimedia 插件 ==="
ls -R "$D/PySide6/Qt/plugins/multimedia" 2>/dev/null | head
echo
echo "=== 未打包但动态链接依赖(抽样) ==="
echo "--- main exe ---"
readelf -d "$D/../KeymouseGo" 2>/dev/null | grep NEEDED
echo "--- Qt6Gui ---"
readelf -d "$D/PySide6/Qt/lib/libQt6Gui.so.6" 2>/dev/null | grep NEEDED
echo "--- libQt6XcbQpa ---"
readelf -d "$D/PySide6/Qt/lib/libQt6XcbQpa.so.6" 2>/dev/null | grep NEEDED
