#!/bin/bash
# 修正版：定位解包后的实际路径再检查
set -uo pipefail
cd /tmp/probe4 || exit 1
ls -d */

echo
echo "########## pyautogui 模块级 import ##########"
f=$(find . -path "*/pyautogui/__init__.py" | head -1); echo "file=$f"
grep -nE "^[[:space:]]*(import|from)[[:space:]]" "$f" | head -40

echo
echo "########## pyautogui/__init__.py 中 pygetwindow/pymsgbox/pytweening 出现位置 ##########"
grep -n "pygetwindow\|pymsgbox\|pytweening\|pyscreeze\|tkinter" "$f" | head -20

echo
echo "########## pyscreeze 中 pygetwindow import 上下文 (40-60行) ##########"
f2=$(find . -path "*/pyscreeze/__init__.py" | head -1)
sed -n '24,60p' "$f2"

echo
echo "########## pygetwindow 顶层 ##########"
f3=$(find . -path "*/pygetwindow/__init__.py" | head -1); echo "file=$f3"
head -25 "$f3"

echo
echo "########## pyautogui _pyautogui_x11 ##########"
f4=$(find . -path "*_pyautogui_x11.py" | head -1); echo "file=$f4"
grep -nE "^[[:space:]]*(import|from)[[:space:]]" "$f4" | head -20

echo
echo "########## mouseinfo 顶层 ##########"
f5=$(find . -path "*/mouseinfo/__init__.py" | head -1); echo "file=$f5"
grep -nE "^[[:space:]]*(import|from)[[:space:]]" "$f5" | head -15

echo
echo "########## 已下载包：pymsgbox / pytweening 是否有模块级 tkinter ##########"
f6=$(find . -path "*/pymsgbox/__init__.py" | head -1); echo "pymsgbox file=$f6"
[ -n "$f6" ] && grep -n "tkinter\|Tkinter" "$f6" | head -10
