#!/bin/bash
# 探测 PySide6 6.5.3 系列在 aarch64 上的 wheel 标签
for p in PySide6 PySide6-Essentials PySide6-Addons shiboken6; do
  echo "=== $p 6.5.3 ==="
  curl -s "https://pypi.org/pypi/$p/6.5.3/json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception as e:
    print('ERR', e); sys.exit()
for u in d.get('urls', []):
    f = u['filename']
    if 'aarch64' in f or 'arm64' in f:
        print(f)
"
done
echo "=== 其它相关包 aarch64 情况 ==="
for spec in "pynput/1.7.6" "pyautogui/0.9.53" "Pillow/9.5.0" "python-xlib/0.33" "pyinstaller/6.3.0"; do
  echo "--- $spec ---"
  curl -s "https://pypi.org/pypi/${spec}/json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
names = [u['filename'] for u in d.get('urls', [])]
aa = [n for n in names if 'aarch64' in n]
print('total wheels:', len(names), '| aarch64:', aa[:3] if aa else 'NONE(pure-python?)')
"
done
