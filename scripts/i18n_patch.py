#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
KeymouseGo 中文/繁体翻译补齐（第二次源码改动）

背景：上游 assets/i18n/*.ts 覆盖面不全 ——
      'Ready...' / 'Cursor Position:' 等条目要么缺失、要么 <translation> 为空。
      Qt 遇到「Empty translation」会回落到英文 source，于是即便选择「简体中文」，
      界面右下角仍会显示 Ready... / Cursor Position: 等英文。

本脚本把程序运行时用到的全部可见文案补进 UIView context，
随后由 pyside6-lrelease 重新编译 .qm。

只改 zh-cn.ts / zh-tw.ts；en.ts 无需改动 —— 英文下 Qt 会直接回落到 source 原文。
"""
import io
import os
import re
import sys

# (source, 简体中文, 繁體中文)
ENTRIES = [
    ('Ready...', '就绪...', '就緒...'),
    ('Cursor Position:', '光标位置：', '游標位置：'),
    ('Cursor pos:', '光标位置：', '游標位置：'),
    ('broken', '已中断', '已中斷'),
    ('record paused', '录制已暂停', '錄製已暫停'),
    ('finished', '已完成', '已完成'),
    ('%d actions recorded', '已记录 %d 个动作', '已記錄 %d 個動作'),
    ('running', '运行中', '執行中'),
    ('recorded', '已记录', '已記錄'),
    ('%s running..', '%s 运行中..', '%s 執行中..'),
    ('Looptimes', '循环次数', '循環次數'),
    ('script not found, please record first!', '未找到脚本，请先录制！', '未找到腳本，請先錄製！'),
    ('An error occurred during execution! Please check logs!',
     '执行过程中发生错误！请检查日志！', '執行過程中發生錯誤！請檢查日誌！'),
    ('An error occurred while parsing script', '解析脚本时发生错误', '解析腳本時發生錯誤'),
    ('An error occurred during runtime', '运行时发生错误', '執行時發生錯誤'),
    ('script run failed, please check your log file',
     '脚本执行失败，请检查日志文件', '腳本執行失敗，請檢查日誌檔案'),
    ('An error occurred while calling %s, please check log file',
     '调用 %s 时发生错误，请检查程序日志', '呼叫 %s 時發生錯誤，請檢查程式日誌'),
]

CONTEXT = 'UIView'


def xml_escape(s):
    return (s.replace('&', '&amp;')
             .replace('<', '&lt;')
             .replace('>', '&gt;'))


def contains_source(text, source):
    return re.search(
        r'<source>%s</source>' % re.escape(xml_escape(source)), text) is not None


def set_translation(text, source, translation):
    """已有 <source> 条目 -> 就地填充 <translation>；返回 (新文本, 是否命中)"""
    pat = re.compile(
        r'(<source>%s</source>\s*)(<translation[^>]*>.*?</translation>)'
        % re.escape(xml_escape(source)),
        re.S)
    m = pat.search(text)
    if not m:
        return text, False
    new = pat.sub(lambda mm: mm.group(1) + '<translation>%s</translation>'
                  % xml_escape(translation), text, count=1)
    return new, True


def append_message(text, source, translation):
    """把新 <message> 追加到 UIView context 的 </context> 之前"""
    marker = '<name>%s</name>' % CONTEXT
    i = text.find(marker)
    if i < 0:
        raise RuntimeError('未找到 <name>%s</name> 上下文' % CONTEXT)
    j = text.find('</context>', i)
    if j < 0:
        raise RuntimeError('UIView context 未闭合')
    block = ('    <message>\n'
             '        <source>%s</source>\n'
             '        <translatorcomment>%s</translatorcomment>\n'
             '        <translation>%s</translation>\n'
             '    </message>\n'
             % (xml_escape(source), xml_escape(translation), xml_escape(translation)))
    return text[:j] + block + text[j:]


def patch_ts(path, idx):
    with io.open(path, 'r', encoding='utf-8') as f:
        src = f.read()
    added = updated = 0
    for entry in ENTRIES:
        source, translation = entry[0], entry[idx]
        if contains_source(src, source):
            src, hit = set_translation(src, source, translation)
            if hit:
                updated += 1
        else:
            src = append_message(src, source, translation)
            added += 1
    with io.open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(src)
    print('  [ok] %-12s 新增 %d 条, 填充 %d 条'
          % (os.path.basename(path), added, updated))
    return 0


def main(root):
    base = os.path.join(root, 'assets', 'i18n')
    if not os.path.isdir(base):
        print('  [FAIL] 找不到 %s' % base)
        return 1
    patch_ts(os.path.join(base, 'zh-cn.ts'), 1)
    patch_ts(os.path.join(base, 'zh-tw.ts'), 2)

    # 校验：所有条目都应已落地
    with io.open(os.path.join(base, 'zh-cn.ts'), 'r', encoding='utf-8') as f:
        cn = f.read()
    missing = [e[0] for e in ENTRIES if not contains_source(cn, e[0])]
    if missing:
        print('  [FAIL] 简体缺条目: %s' % missing)
        return 1
    print('  [ok] 校验通过，共 %d 条词条' % len(ENTRIES))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else '.'))
