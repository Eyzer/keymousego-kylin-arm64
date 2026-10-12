#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
界面文案探针：在真实 X(display) 下实例化主窗口，直接读取控件文本。

用途 —— 把「界面是否中文」「底部作者信息是否就位」「语言选择是否被记住」
        变成可断言的字符串，而不是靠肉眼看截图。

用法:
  probe_ui.py                         # 打印当前默认语言下的全部控件文本
  probe_ui.py --set-lang 简体中文      # 切换语言并落盘，供下一次进程验证持久化
输出形如 KEY=VALUE，便于 grep 断言。
"""
import io
import os
import sys

HOME_DIR = os.environ.get('KEYMOUSEGO_HOME') or '/tmp/kmg_probe_home'
os.environ['KEYMOUSEGO_HOME'] = HOME_DIR

# 必须让 get_assets_path() 找到 assets/
APP_DIR = os.environ.get('KM_PROBE_APPDIR') or os.getcwd()
os.chdir(APP_DIR)
sys.path.insert(0, APP_DIR)

from PySide6.QtWidgets import QApplication          # noqa: E402

import UIFunc                                        # noqa: E402


def dump(ui, tag):
    rows = [
        ('TAG', tag),
        ('AUTHOR', ui.label_author.text()),
        ('AUTHOR_OBJNAME', ui.label_author.objectName()),
        ('LANG', ui.choice_language.currentText()),
        ('GROUP_HOTKEYS', ui.groupBox.title()),
        ('GROUP_CONFIG', ui.groupBox_2.title()),
        ('BT_RECORD', ui.btrecord.text()),
        ('BT_RUN', ui.btrun.text()),
        ('BT_PAUSE', ui.btpauserecord.text()),
        ('LABEL_START', ui.label_start_key.text()),
        ('LABEL_RECORD', ui.label_record.text()),
        ('LABEL_STOP', ui.label_stop.text()),
        ('LABEL_LANG', ui.label_language.text()),
        ('LABEL_SCRIPT', ui.label_script.text()),
        ('LABEL_RUNTIMES', ui.label_run_times.text()),
        ('LABEL_PRECISION', ui.label_execute_interval.text()),
        ('LABEL_THEME', ui.label_theme.text()),
        ('LABEL_VOLUME', ui.label_volume.text()),
        ('STATUS', ui.tnumrd.text()),
        ('CURSOR_LABEL', ui.label_cursor_pos.text()),
        ('WINDOW_TITLE', ui.windowTitle()),
    ]
    for k, v in rows:
        print('%s=%s' % (k, v))
    # 状态栏里是否真的有这个常驻控件
    bar = ui.statusbar
    names = [c.objectName() for c in bar.findChildren(type(ui.label_author))]
    print('STATUSBAR_CHILDREN=%s' % ','.join(names))


def main():
    argv = list(sys.argv[1:])
    set_lang = None
    if '--set-lang' in argv:
        i = argv.index('--set-lang')
        set_lang = argv[i + 1] if i + 1 < len(argv) else None

    app = QApplication(['probe_ui'])
    ui = UIFunc.UIFunc(app)

    if set_lang:
        ui.choice_language.setCurrentText(set_lang)
        # currentTextChanged -> onchangelang -> config.setValue
        ui.config.sync()
        print('SET_LANG=%s' % set_lang)
        print('CONFIG_FILE=%s' % UIFunc.to_abs_path('config.ini'))
        with io.open(UIFunc.to_abs_path('config.ini'), 'r', encoding='utf-8') as f:
            for line in f:
                if line.strip().startswith('Language'):
                    print('CONFIG_LINE=%s' % line.strip())
        dump(ui, 'after-set')
    else:
        dump(ui, 'default')

    ui.config.sync()
    try:
        UIFunc.Recorder.dispose()
    except Exception:
        pass
    return 0


if __name__ == '__main__':
    sys.exit(main())
