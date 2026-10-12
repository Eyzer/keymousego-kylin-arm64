#!/bin/bash
# 确定性补齐 PyInstaller 产物中缺失的动态库
#
# 背景：在 qemu-aarch64 用户态模拟下 `ldd` 会 SIGSEGV
#       （构建日志里可见 "ldd: exited with unknown exit code (139)"），
#       PyInstaller 的依赖闭包因此不完整：libQt6Network 依赖的系统
#       libbrotlidec.so.1 没被收进来，运行时直接 ImportError。
#
# 做法：不依赖 ldd，直接解析每个 ELF 的 DT_NEEDED。凡 _internal 内没有、
#       且不属于「由系统提供」白名单的库，就从 chroot 的同基线系统库目录
#       拷进产物。迭代到收敛。
#
# 白名单原则：
#   * glibc 家族 —— 必须与目标机同源，不能打包；
#   * X11 / GL / DRM 图形栈 —— 与目标机显卡驱动强耦合，必须用系统自带的，
#     这些依赖已在 deb 的 Depends 里显式声明（libgl1/libegl1/libxcb1 等）。
set -uo pipefail

D=/build/kmg/dist/KeymouseGo
INT="$D/_internal"
SEARCH="/usr/lib/aarch64-linux-gnu /lib/aarch64-linux-gnu /usr/lib /lib"
REPORT=/build/kmg/depreport

SKIP_GLIBC="ld-linux-aarch64.so.1 libc.so.6 libm.so.6 libpthread.so.0 libdl.so.2 librt.so.1 libresolv.so.2 libutil.so.1 libnsl.so.1 libanl.so.1 linux-vdso.so.1"

SKIP_SYSTEM="libxcb.so.1 libX11.so.6 libX11-xcb.so.1 libXext.so.6 libXrender.so.1 libXfixes.so.3 libXrandr.so.2 libXi.so.6 libXtst.so.6 libXcursor.so.1 libXinerama.so.1 libXcomposite.so.1 libXdamage.so.1 libXshmfence.so.1 libXau.so.6 libXdmcp.so.6 libGL.so.1 libEGL.so.1 libGLX.so.0 libGLdispatch.so.0 libOpenGL.so.0 libdrm.so.2 libgbm.so.1"

SKIP="$SKIP_GLIBC $SKIP_SYSTEM"

needed() { readelf -d "$1" 2>/dev/null | sed -n 's/.*(NEEDED)[^[]*\[\([^]]*\)\].*/\1/p'; }
iself()  { file -b "$1" 2>/dev/null | grep -q '^ELF'; }

mkdir -p "$REPORT"

collect_elfs() {
    find "$INT" -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do
        iself "$f" && printf '%s\n' "$f"
    done
}

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

# ---------------------------------------------------------------- 清掉上一版误收集的图形栈
for lib in libxcb.so.1 libGL.so.1 libEGL.so.1 libGLX.so.0 libGLdispatch.so.0 libdrm.so.2; do
    if [ -e "$INT/$lib" ]; then
        rm -f "$INT/$lib"
        echo "  [-] 移除 $lib（改由系统提供）"
    fi
done

# ---------------------------------------------------------------- 迭代补齐
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
echo "===== 报告 A：由系统提供（已在 deb Depends 声明） ====="
{
    mapfile -t files < <(collect_elfs)
    files+=("$D/KeymouseGo")
    for f in "${files[@]}"; do
        while IFS= read -r lib; do
            [ -z "$lib" ] && continue
            case " $SKIP_SYSTEM " in *" $lib "*) printf '  [sys] %s\n' "$lib" ;; esac
        done < <(needed "$f")
    done
} | sort -u

echo
echo "===== 报告 B：未满足的可选插件依赖（X11 下不会被加载） ====="
{
    mapfile -t files < <(collect_elfs)
    files+=("$D/KeymouseGo")
    for f in "${files[@]}"; do
        while IFS= read -r lib; do
            [ -z "$lib" ] && continue
            case " $SKIP " in *" $lib "*) continue ;; esac
            in_bundle "$lib" && continue
            sys_lookup "$lib" >/dev/null && continue
            printf '  [opt] %s\n' "$lib"
        done < <(needed "$f")
    done
} | sort -u | tee "$REPORT/unresolved.txt"

echo
echo "===== 校验：用 ldd 全量扫描（空 = 全部满足） ====="
export LD_LIBRARY_PATH="$INT:$INT/PySide6/Qt/lib"
{
    mapfile -t files < <(collect_elfs)
    for f in "${files[@]}"; do
        ldd "$f" 2>/dev/null | grep 'not found' | awk '{print $1}'
    done
    ldd "$D/KeymouseGo" 2>/dev/null | grep 'not found' | awk '{print $1}'
} | sort | uniq -c | sort -rn
