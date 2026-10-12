#!/bin/bash
# 用 sdist 探测 pyautogui 及其依赖的模块级 import
set -uo pipefail
cd /tmp && rm -rf probe4 && mkdir -p probe4 && cd probe4

grab_src() {
  local pkg="$1"
  local url
  url=$(curl -s "https://pypi.org/pypi/$pkg/json" | python3 -c "
import sys,json
d=json.load(sys.stdin)
c=[u for u in d['urls'] if u['packagetype']=='sdist']
print(c[0]['url'] if c else '')
")
  [ -z "$url" ] && { echo "!! $pkg 无 sdist"; return; }
  curl -sLO "$url"
  tar xzf "$(basename "$url")"
  echo "  ok: $(basename "$url")"
}

for p in pyautogui pyscreeze pytweening pygetwindow mouseinfo; do
  echo "=== $p ==="
  grab_src "$p"
done

echo
echo "########## pyautogui/__init__.py 的 import 语句 ##########"
grep -nE "^\s*(import|from)\s" pyautogui-*/pyautogui/__init__.py | head -40

echo
echo "########## pymsgbox 是否模块级 import tkinter ##########"
grep -nE "import (Tkinter|tkinter)|^import|^from" pymsgbox-*/pymsgbox/__init__.py | head -20

echo
echo "########## pyscreeze 顶层 import ##########"
grep -nE "^\s*(import|from)\s" pyscreeze-*/pyscreeze/__init__.py | head -20

echo
echo "########## pygetwindow 是否为 Windows-only stub ##########"
grep -nE "^\s*(import|from)\s|NotImplementedError|sys.platform" pygetwindow-*/pygetwindow/__init__.py | head -20

echo
echo "########## pyautogui _pyautogui_x11 依赖 ##########"
grep -nE "^\s*(import|from)\s" pyautogui-*/pyautogui/_pyautogui_x11.py | head -20
