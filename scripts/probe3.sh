#!/bin/bash
# 探测 pyautogui 及其隐式依赖的真实 import 行为（是否在模块级 import tkinter 等）
set -uo pipefail
cd /tmp && rm -rf probe3 && mkdir -p probe3 && cd probe3

grab() {
  local pkg="$1"
  local url
  url=$(curl -s "https://pypi.org/pypi/$pkg/json" | python3 -c "
import sys,json
d=json.load(sys.stdin)
ws=[u for u in d['urls'] if u['filename'].endswith('-py3-none-any.whl')]
if not ws:
    ws=[u for u in d['urls'] if u['filename'].endswith('.whl')]
print(ws[0]['url'] if ws else '')
")
  if [ -z "$url" ]; then echo "!! $pkg 无 wheel"; return; fi
  curl -sLO "$url"
  echo "  下载: $(basename "$url")"
}

for p in pyautogui pymsgbox pytweening pygetwindow pyscreeze mouseinfo; do
  echo "=== $p ==="
  grab "$p"
done
ls -la

echo
echo "########## pyautogui 模块级 import ##########"
python3 - <<'PY'
import zipfile, glob, re
for whl in sorted(glob.glob('pyautogui-*.whl')):
    z = zipfile.ZipFile(whl)
    src = z.read('pyautogui/__init__.py').decode('utf-8', 'replace')
    for i, line in enumerate(src.splitlines(), 1):
        if re.match(r'\s*(import|from)\s+py(screeze|msgbox|tweening|getwindow)|mouseinfo|^import tkinter|\btkinter\b', line):
            print(f'{i:4d}: {line}')
PY

echo
echo "########## pymsgbox 模块级 import ##########"
python3 - <<'PY'
import zipfile, glob
for whl in sorted(glob.glob('pymsgbox-*.whl')):
    z = zipfile.ZipFile(whl)
    src = z.read('pymsgbox/__init__.py').decode('utf-8', 'replace')
    for i, line in enumerate(src.splitlines()[:40], 1):
        print(f'{i:4d}: {line}')
PY

echo
echo "########## pyscreeze 顶层 import ##########"
python3 - <<'PY'
import zipfile, glob
for whl in sorted(glob.glob('pyscreeze-*.whl')):
    z = zipfile.ZipFile(whl)
    src = z.read('pyscreeze/__init__.py').decode('utf-8', 'replace')
    for i, line in enumerate(src.splitlines()[:40], 1):
        print(f'{i:4d}: {line}')
PY
