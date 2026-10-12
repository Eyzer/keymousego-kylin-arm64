#!/bin/bash
# 确定性补齐 PyInstaller 产物中缺失的动态库
#
# 背景：在 qemu-aarch64 用户态模拟下 `ldd` 会 SIGSEGV
#       （构建日志里可见 "ldd: exited with unknown exit code (139)"），
#       PyInstaller 的依赖闭包因此不完整，例如 libQt6Network 依赖的
#       系统 libbrotlidec.so.1 就没有被收进来，运行时会 ImportError。
#
# 做法：不依赖 ldd，直接解析每个 ELF 的 DT_NEEDED，若 _internal 内没有
#       同名库，就从 chroot 的系统库目录里拷进来，反复迭代到闭包收敛。
#       目标机器与构建基线同为 Ubuntu 20.04，拷贝系统库不会引入兼容问题。
set -uo pipefail

D=/build/kmg/dist/KeymouseGo
INT="$D/_internal"
SEARCH="/usr/lib/aarch64-linux-gnu /lib/aarch64-linux-gnu /usr/lib /lib"
REPORT=/build/kmg/depreport

# 运行环境必定提供的基础库（也避免与目标机 glibc 版本冲突）
SKIP="ld-linux-aarch64.so.1 libc.so.6 libm.so.6 libpthread.so.0 libdl.so.2 librt.so.1 libresolv.so.2 libutil.so.1 libnsl.so.1 libanl.so.1 linux-vdso.so.1"

needed() { readelf -d "$1" 2>/dev/null | sed -n 's/.*(NEEDED)[^[]*\[\([^]]*\)\].*/\1/p'; }
iself()  { file -b "$1" 2>/dev/null | grep -q '^ELF'; }

mkdir -p "$REPORT"

collect_elfs() {
    find "$INT" -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do
        iself "$f" && printf '%s\n' "$f"
    done
}

# 该库是否已在产物内（含子目录，PySide6/Qt/lib 等靠 RPATH 生效）
in_bundle() {
    [ -e "$INT/$1" ] && return 0
    [ -n "$(find "$INT" -name "$1" -print -quit 2>/dev/null)" ] && return 0
    return 1
}

sys_lookup() {
    local lib="$1" d
    for d in $SEARCH; do
        [ -e "$d/$lib" ] && { printf '%s\n' "$d/$lib"; return 0; }
    done
    return 1
}

for pass in 1 2 3 4 5 6; do
    echo "===== 第 $pass 轮补齐 ====="
    added=0
    mapfile -t files < <(collect_elfs)
    files+=("$D/KeymouseGo")
    for f in "${files[@]}"; do
        while IFS= read -r lib; do
            [ -z "$lib" ] && continue
            case " $SKIP " in *" $lib "*) continue ;; esac
            in_bundle "$lib" && continue
            if hit=$(sys_lookup "$lib"); then
                cp -Lf "$hit" "$INT/$lib"
                chmod 644 "$INT/$lib"
                echo "  [+] $lib  <=  $hit"
                added=$((added + 1))
            fi
        done < <(needed "$f")
    done
    echo "  本轮新增 $added 个"
    [ "$added" -eq 0 ] && break
done

echo
echo "===== 剩余未满足的 NEEDED（预期只剩未安装的可选插件依赖） ====="
{
    mapfile -t files < <(collect_elfs)
    files+=("$D/KeymouseGo")
    for f in "${files[@]}"; do
        while IFS= read -r lib; do
            [ -z "$lib" ] && continue
            case " $SKIP " in *" $lib "*) continue ;; esac
            in_bundle "$lib" && continue
            sys_lookup "$lib" >/dev/null && continue
            printf '  [?] %s\n' "$lib"
        done < <(needed "$f")
    done
} | sort -u | tee "$REPORT/unresolved.txt"

echo
echo "===== 动态补齐后再次用 ldd 全量校验 ====="
export LD_LIBRARY_PATH="$INT:$INT/PySide6/Qt/lib"
{
    mapfile -t files < <(collect_elfs)
    for f in "${files[@]}"; do
        ldd "$f" 2>/dev/null | grep 'not found' | awk '{print $1}'
    done
    ldd "$D/KeymouseGo" 2>/dev/null | grep 'not found' | awk '{print $1}'
} | sort | uniq -c | sort -rn
echo "(空 = 全部满足)"
