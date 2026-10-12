#!/bin/bash
# 全量扫描产物中所有 ELF 的缺失动态库
D=/build/kmg/dist/KeymouseGo/_internal
export LD_LIBRARY_PATH="$D:$D/PySide6/Qt/lib:$D/PySide6"

echo "########## A) 构建日志里的缺失库告警 ##########"
grep -iE 'not found|cannot find|WARNING.*librar|missing' /tmp/kmg_build.log 2>/dev/null | sort -u | head -30

echo
echo "########## B) 逐个 ELF 做 ldd，收集 'not found' ##########"
find "$D" -type f \( -name '*.so' -o -name '*.so.*' -o -name '*.abi3.so' -o -name '*.cpython-38*' \) -print0 2>/dev/null \
| while IFS= read -r -d '' f; do
    out=$(ldd "$f" 2>/dev/null | grep 'not found' | awk '{print $1}')
    [ -n "$out" ] && for lib in $out; do echo "$lib"; done
done | sort | uniq -c | sort -rn

echo
echo "########## C) 主程序 ##########"
ldd "$D/../KeymouseGo" 2>&1 | grep 'not found' | head

echo
echo "########## D) 结论 ##########"
echo "(B 段列出的库 = 需要补进 chroot 并重新打包)"
