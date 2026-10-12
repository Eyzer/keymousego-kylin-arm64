#!/bin/bash
D=/build/kmg/dist/KeymouseGo/_internal
echo "############ 1) 系统里的 brotli ############"
ls -l /usr/lib/aarch64-linux-gnu/libbrotli* 2>&1
echo "--- 哪个包提供 ---"
dpkg -S /usr/lib/aarch64-linux-gnu/libbrotlidec.so.1 2>&1 | head -3

echo
echo "############ 2) _internal 里的 brotli ############"
ls -l "$D"/libbrotli* 2>&1

echo
echo "############ 3) 谁 NEEDED libbrotlidec.so.1 ############"
for f in "$D"/lib*.so* "$D"/PySide6/Qt/lib/*.so* "$D"/PySide6/*.so "$D"/PIL/*.so; do
  [ -f "$f" ] || continue
  if readelf -d "$f" 2>/dev/null | grep -q 'libbrotlidec'; then
    echo "  $f"
    readelf -d "$f" 2>/dev/null | grep 'NEEDED' | grep -i brotli | sed 's/^/     /'
  fi
done

echo
echo "############ 4) _internal/libfreetype.so.6 的 NEEDED ############"
readelf -d "$D/libfreetype.so.6" 2>/dev/null | grep NEEDED
echo "--- 系统 libfreetype.so.6 的 NEEDED ---"
readelf -d /usr/lib/aarch64-linux-gnu/libfreetype.so.6 2>/dev/null | grep NEEDED

echo
echo "############ 5) Pillow 私有库 references ############"
for f in "$D"/libbrotlicommon-*.so* "$D"/libbrotlidec-*.so*; do
  [ -f "$f" ] || continue
  echo "--- $f"
  readelf -d "$f" 2>/dev/null | grep NEEDED
done

echo
echo "############ 6) ldd 检查关键库缺失 ############"
for f in "$D/PySide6/Qt/lib/libQt6Gui.so.6" "$D/libfreetype.so.6" "$D/PIL/_imaging.cpython-38-aarch64-linux-gnu.so"; do
  echo "--- $f"
  env LD_LIBRARY_PATH="$D:$D/PySide6/Qt/lib" ldd "$f" 2>&1 | grep -i 'not found' || echo "   (无缺失)"
done

echo
echo "############ 7) 直接跑主程序看缺什么 ############"
env LD_LIBRARY_PATH="$D" ldd "$D/../KeymouseGo" 2>&1 | grep -i 'not found' || echo "   (主程序无缺失)"
