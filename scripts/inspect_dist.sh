#!/bin/bash
D=/build/kmg/dist/KeymouseGo
echo "=== 顶层 ==="
ls -la "$D"
echo
echo "=== _internal 顶层 ==="
ls "$D/_internal" | head -40
echo
echo "=== PySide6 目录 ==="
ls "$D/_internal/PySide6" 2>/dev/null
echo "--- Qt/lib ---"
ls "$D/_internal/PySide6/Qt/lib" 2>/dev/null | head -30
echo "--- Qt/plugins ---"
ls "$D/_internal/PySide6/Qt/plugins" 2>/dev/null
echo
echo "=== assets ==="
find "$D/_internal/assets" -type f 2>/dev/null
echo
echo "=== 各子项体积 (top 12) ==="
du -sh "$D/_internal"/* 2>/dev/null | sort -hr | head -12
echo
echo "=== 是否混进 tkinter / numpy / cv2 ==="
find "$D/_internal" -iname '*tkinter*' -o -iname '*numpy*' -o -iname '*cv2*' 2>/dev/null | head
echo "(以上为空即已排除)"
