#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 校验「冻结后」的可执行文件里真的带着本次定制的内容。
#
# 为什么不能直接 grep 二进制：PyInstaller 把 Python 模块以 zlib 压缩后存进 EXE 的 PYZ，
# 明文扫不到（实测 grep -a 'Eyzer' 永远为空）。这里用 PyInstaller 自带的
# ZlibArchiveReader 取出 code object，再递归遍历 co_consts，
# 把「中文化 + 作者信息」变成可断言的字符串证据。
import sys

from PyInstaller.loader.pyimod01_archive import ZlibArchiveReader

EXE = sys.argv[1] if len(sys.argv) > 1 else '/opt/keymousego/KeymouseGo'
NEEDLES = ['Eyzer', '二次开发自', 'KeymouseGo v5.2.1', '作者：', 'zh-cn']


def walk(code, out):
    for c in getattr(code, 'co_consts', ()):
        if isinstance(c, str):
            out.append(c)
        elif isinstance(c, type(code)):
            walk(c, out)
        elif isinstance(c, (tuple, frozenset)):
            for x in c:
                if isinstance(x, str):
                    out.append(x)


def main():
    blob = open(EXE, 'rb').read()
    off = blob.find(b'PYZ\x00')
    if off < 0:
        print('RESULT=FAIL reason=no_pyz')
        return 1
    z = ZlibArchiveReader(EXE, start_offset=off)
    strs = []
    for name in z.toc:
        try:
            walk(z.extract(name), strs)
        except Exception:
            pass
    joined = '\n'.join(strs)
    ok = True
    for n in NEEDLES:
        hit = n in joined
        print('  %-22s %s' % (n, 'FOUND' if hit else 'MISSING'))
        ok = ok and hit
    print('  (扫描模块 %d 个, 提取字符串常量 %d 条)' % (len(z.toc), len(strs)))
    print('RESULT=%s' % ('PASS' if ok else 'FAIL'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
