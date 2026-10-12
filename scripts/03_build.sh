#!/bin/bash
# 步骤3: 复制源码 -> 打补丁 -> 编译翻译 -> 静态自检 -> PyInstaller 打包
set -uo pipefail
R=/opt/kylin-arm64
SRC=/mnt/c/Users/Administrator/WorkBuddy/2026-10-12-17-09-29/keymousego_src
W=/mnt/c/Users/Administrator/WorkBuddy/2026-10-12-17-09-29/kmg-build

APP="$R/build/kmg/app"

echo "===== 清理并复制源码 ====="
rm -rf "$APP"
mkdir -p "$APP"
# 排除 .git / archived(死代码) / 构建产物
(cd "$SRC" && tar cf - --exclude='.git' --exclude='archived' --exclude='__pycache__' \
    --exclude='.github' --exclude='*.pro' .) | (cd "$APP" && tar xf -)
# 去掉可能的 CRLF（上游文件为 LF，这里仅防御）
find "$APP" -type f \( -name '*.py' -o -name '*.txt' -o -name '*.json5' \) -exec sed -i 's/\r$//' {} +
echo "文件数: $(find "$APP" -type f | wc -l)"
echo "版本: $(grep -o 'KeymouseGo v[0-9.]*' "$APP/UIView.ui" | head -1)"

echo
echo "===== [A][B][C] 应用源码补丁 ====="
cp "$W/scripts/patch.py" "$R/build/kmg/patch.py"
chroot "$R" /bin/bash -c "python3 /build/kmg/patch.py /build/kmg/app" || exit 1

echo
echo "===== [B2] 补齐中文/繁体翻译条目 ====="
cp "$W/scripts/i18n_patch.py" "$R/build/kmg/i18n_patch.py"
chroot "$R" /bin/bash -c "python3 /build/kmg/i18n_patch.py /build/kmg/app" || exit 1

echo
echo "===== 重新编译 .qm 翻译文件 ====="
chroot "$R" /bin/bash -c "
cd /build/kmg/app/assets/i18n
for L in zh-cn zh-tw en; do
  pyside6-lrelease \$L.ts -qm \$L.qm 2>&1 | sed 's/^/  /'
done
echo '--- 编译结果 ---'
ls -l *.qm
"

echo
echo "===== 静态语法自检 ====="
chroot "$R" /bin/bash -c "
cd /build/kmg/app
python3 -m compileall -q . 2>&1 | head -20
echo 'compileall rc='\$?
echo '--- 关键改动落地校验 ---'
grep -c \"AUTHOR_INFO\" UIFunc.py
grep -c \"QCoreApplication.translate\" UIFunc.py Util/RunScriptClass.py
"

echo
echo "===== 翻译生效校验（zh-cn.qm 反编译抽查） ====="
chroot "$R" /bin/bash -c "
cd /build/kmg/app/assets/i18n
python3 - <<'PY'
from PySide6.QtCore import QTranslator, QCoreApplication
import sys
app = QCoreApplication(sys.argv)
for lang in ('zh-cn', 'zh-tw', 'en'):
    t = QTranslator()
    ok = t.load('/build/kmg/app/assets/i18n/' + lang, 'i18n')
    app.installTranslator(t)
    out = []
    for s in ('Ready...', 'Cursor Position:', 'finished', 'Looptimes',
              'broken', 'record paused', '%d actions recorded', 'Hotkeys'):
        out.append('%s=%s' % (s, t.translate('UIView', s)))
    print('  [%s] load=%s' % (lang, ok))
    print('     ' + ' | '.join(out))
    app.removeTranslator(t)
PY
"

echo
echo "===== PyInstaller 打包 ====="
chroot "$R" /bin/bash -c "
cd /build/kmg/app
rm -rf /build/kmg/dist /build/kmg/pybuild
python3 -m PyInstaller --noconfirm --clean --windowed \
  --name KeymouseGo \
  --distpath /build/kmg/dist \
  --workpath /build/kmg/pybuild \
  --specpath /build/kmg \
  --add-data '/build/kmg/app/assets:assets' \
  --collect-data qt_material \
  --hidden-import pynput.keyboard._xorg \
  --hidden-import pynput.mouse._xorg \
  --hidden-import pynput.keyboard._uinput \
  --hidden-import pynput.mouse._uinput \
  --exclude-module tkinter \
  --exclude-module mouseinfo \
  --exclude-module pygetwindow \
  --exclude-module cv2 \
  --exclude-module numpy \
  --exclude-module pytest \
  KeymouseGo.py 2>&1 | tail -25
"

echo
echo "===== 产物 ====="
ls -la "$R/build/kmg/dist/KeymouseGo/" 2>/dev/null | head -12
du -sh "$R/build/kmg/dist/KeymouseGo" 2>/dev/null
echo "--- 打包后的 qm ---"
ls -l "$R/build/kmg/dist/KeymouseGo/_internal/assets/i18n/" 2>/dev/null
echo "EXIT=$?"
