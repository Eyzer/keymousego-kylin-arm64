#!/bin/bash
echo "=== pynput 1.7.6 requires_dist ==="
curl -s https://pypi.org/pypi/pynput/1.7.6/json | python3 -c "
import sys,json; d=json.load(sys.stdin)
for r in d['info'].get('requires_dist') or []: print('  ', r)
"
echo
echo "=== pyautogui 0.9.53 requires_dist ==="
curl -s https://pypi.org/pypi/pyautogui/0.9.53/json | python3 -c "
import sys,json; d=json.load(sys.stdin)
for r in d['info'].get('requires_dist') or []: print('  ', r)
"
echo
echo "=== pyscreeze 0.1.30 requires_dist ==="
curl -s https://pypi.org/pypi/pyscreeze/0.1.30/json | python3 -c "
import sys,json; d=json.load(sys.stdin)
for r in d['info'].get('requires_dist') or []: print('  ', r)
"
echo
echo "=== PySide6 6.5.3 requires_dist ==="
curl -s https://pypi.org/pypi/PySide6/6.5.3/json | python3 -c "
import sys,json; d=json.load(sys.stdin)
for r in d['info'].get('requires_dist') or []: print('  ', r)
"
