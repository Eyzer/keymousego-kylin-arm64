#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
KeymouseGo 麒麟 deb 构建补丁

共三类改动，全部是「最小必要」的定点替换，不做结构性重写：

[A] 可写数据目录（必需）
    上游用 to_abs_path() 以 sys.argv[0] 所在目录作为运行数据根目录，
    scripts/ logs/ plugins/ config.ini 都会写到那里。装成 deb 后程序在只读的
    /opt/keymousego/，普通用户启动时 UIFunc.__init__ 里的 os.mkdir('scripts')
    会直接抛权限异常导致崩溃。
    改法：允许用环境变量 KEYMOUSEGO_HOME 覆盖数据根目录；未设置时行为与上游完全一致。
    启动器 /usr/bin/keymousego 会把它指向 ~/.local/share/keymousego。

[B] 中文化（用户需求 1）
    B1 默认语言强制为简体中文，并「读取 + 记忆」用户选择。
       上游 config.ini 里写了 Language=zh-cn，但代码从不读它，只按系统 locale 判断，
       locale 不是 zh_CN 时（C / POSIX / en_US）界面直接变英文。
    B2 上游有一批状态文案是硬编码英文、绕过了 Qt 翻译机制
       （'Ready...' 靠 .qm 但译文为空白，'finished' / 'N actions recorded' /
       'Cursor pos:' 等压根没进 .ts），选中文也照样显示英文。
       改法：统一走 QCoreApplication.translate('UIView', ...)，词条由
       i18n_patch.py 补进 zh-cn.ts / zh-tw.ts。
       注意 UIFunc.recordMethod 里有个 `'running' in status` 的字符串嗅探守卫，
       它比对的是 tnumrd 的文本，因此标记词 'running'/'recorded' 的译文必须与
       实际显示的文案保持子串关系，此处已一并处理。

[C] 底部作者信息栏（用户需求 2）
    在状态栏内挂一个居中的 QLabel，展示作者与二次开发来源。
    用 statebar 而非新增控件层，是因为 QStatusBar 本来就空着且被 QMainWindow
    托管布局，不需要动 UIView.ui 的几何尺寸，零布局风险。
"""
import io
import os
import sys

AUTHOR_INFO = u'作者：Eyzer\u3000·\u3000二次开发自：KeymouseGo v5.2.1'

RULES = []


def rule(rel, old, new):
    RULES.append((rel, old, new))


# ---------------------------------------------------------------- [A] 数据目录
_TO_ABS_OLD = """def to_abs_path(*args):
    return os.path.join(os.path.dirname(os.path.realpath(sys.argv[0])),
                        *args)"""

_TO_ABS_NEW = """def to_abs_path(*args):
    # [kylin-deb patch] 允许通过 KEYMOUSEGO_HOME 指定可写的数据目录，
    # 未设置时保持上游行为（sys.argv[0] 同级目录）。
    base = os.environ.get('KEYMOUSEGO_HOME') \\
        or os.path.dirname(os.path.realpath(sys.argv[0]))
    return os.path.join(base, *args)"""

rule('KeymouseGo.py', _TO_ABS_OLD, _TO_ABS_NEW)
rule('Plugin/Manager.py', _TO_ABS_OLD, _TO_ABS_NEW)

# ---------------------------------------------------------------- [B1] 默认语言
rule('UIFunc.py',
     """        # 获取默认的地区设置
        language = '简体中文' if locale.getdefaultlocale()[0] == 'zh_CN' else 'English'
        self.choice_language.setCurrentText(language)
        self.onchangelang()""",
     """        # [kylin-deb patch] 默认简体中文，并读取上次的语言选择。
        # 上游此处只按系统 locale 判断，且 config.ini 的 Language 项从不被读取，
        # 导致 locale 非 zh_CN 的机器（如 C / en_US）界面直接变英文。
        _lang = str(self.config.value('Config/Language') or 'zh-cn').strip().lower()
        self.choice_language.setCurrentText(LANG_LABELS.get(_lang, '简体中文'))
        self.onchangelang()""")

rule('UIFunc.py',
     """        self.retranslateUi(self)
        self.hotkey_stop.setText(self.config.value("Config/StopHotKey"))""",
     """        self.retranslateUi(self)
        # [kylin-deb patch] 记住语言选择，下次启动沿用。
        # 注意方向：这里是「界面标签 -> 语言代码」，与 __init__ 里的
        # LANG_LABELS（语言代码 -> 界面标签）相反，不能复用同一个字典。
        self.config.setValue('Config/Language', LANG_CODES.get(
            self.choice_language.currentText(), 'zh-cn'))
        self.hotkey_stop.setText(self.config.value("Config/StopHotKey"))""")

# ---------------------------------------------------------------- [C] 作者信息栏
rule('UIFunc.py',
     """        self.setupUi(self)

        self.app = app""",
     """        self.setupUi(self)

        # [kylin-deb patch] 界面底部作者信息栏（挂在状态栏内，无需改动 UIView.ui）
        self.label_author = QLabel(self)
        self.label_author.setObjectName('label_author')
        self.label_author.setAlignment(Qt.AlignCenter)
        self.label_author.setText(AUTHOR_INFO)
        self.statusbar.addWidget(self.label_author, 1)

        self.app = app""")

rule('UIFunc.py',
     """from PySide6.QtWidgets import QMainWindow, QApplication, QMessageBox""",
     """from PySide6.QtWidgets import QMainWindow, QApplication, QMessageBox, QLabel""")

rule('UIFunc.py',
     """scripts = []
scripts_map = {'current_index': 0, 'choice_language': '简体中文'}""",
     u"""scripts = []
scripts_map = {'current_index': 0, 'choice_language': '简体中文'}

# [kylin-deb patch] 界面语言标签 <-> config.ini 语言代码
LANG_LABELS = {'zh-cn': '简体中文', 'en': 'English', 'zh-tw': '繁體中文'}
LANG_CODES = {v: k for k, v in LANG_LABELS.items()}

# [kylin-deb patch] 界面底部作者与来源信息
AUTHOR_INFO = u'%s'""" % AUTHOR_INFO)

# ---------------------------------------------------------------- [B2] 状态文案
rule('UIFunc.py',
     """                    self.tnumrd.setText('broken')""",
     """                    self.tnumrd.setText(QCoreApplication.translate('UIView', 'broken'))""")

rule('UIFunc.py',
     """                text = '%d actions recorded' % self.actioncount""",
     """                text = QCoreApplication.translate('UIView', '%d actions recorded') % self.actioncount""")

rule('UIFunc.py',
     """            self.tnumrd.setText('record paused')""",
     """            self.tnumrd.setText(QCoreApplication.translate('UIView', 'record paused'))""")

rule('UIFunc.py',
     """            self.tnumrd.setText('finished')""",
     """            self.tnumrd.setText(QCoreApplication.translate('UIView', 'finished'))""")

rule('UIFunc.py',
     """            status = self.tnumrd.text()
            if 'running' in status or 'recorded' in status:
                return""",
     """            status = self.tnumrd.text()
            # [kylin-deb patch] 守卫比对的是界面文案，须用译文做子串匹配
            if (QCoreApplication.translate('UIView', 'running') in status
                    or QCoreApplication.translate('UIView', 'recorded') in status):
                return""")

rule('UIFunc.py',
     """            self.tnumrd.setText('0 actions recorded')""",
     """            self.tnumrd.setText(QCoreApplication.translate('UIView', '%d actions recorded') % 0)""")

rule('UIFunc.py',
     """        self.label_cursor_pos.setText(f'Cursor pos: {pos}')""",
     """        self.label_cursor_pos.setText(
            QCoreApplication.translate('UIView', 'Cursor pos:') + ' ' + str(pos))""")

# ---------------------------------------------------------------- [B2] 执行器
rule('Util/RunScriptClass.py',
     """from PySide6.QtCore import QThread, Signal, QMutex, QWaitCondition, QDeadlineTimer, Qt, Slot""",
     """from PySide6.QtCore import QThread, Signal, QMutex, QWaitCondition, QDeadlineTimer, Qt, Slot, QCoreApplication""")

rule('Util/RunScriptClass.py',
     """            self.tnumrdSignal.emit('script not found, please record first!')""",
     """            self.tnumrdSignal.emit(QCoreApplication.translate('UIView', 'script not found, please record first!'))""")

rule('Util/RunScriptClass.py',
     """            self.logSignal.emit('An error occurred during execution! Please check logs!')""",
     """            self.logSignal.emit(QCoreApplication.translate('UIView', 'An error occurred during execution! Please check logs!'))""")

rule('Util/RunScriptClass.py',
     """            running_text = '%s running..' % script_path.split('/')[-1].split('\\\\')[-1]""",
     """            running_text = QCoreApplication.translate('UIView', '%s running..') % script_path.split('/')[-1].split('\\\\')[-1]""")

rule('Util/RunScriptClass.py',
     """                    self.logSignal.emit('==============\\nAn error occurred while parsing script')""",
     """                    self.logSignal.emit('==============\\n' + QCoreApplication.translate(
                        'UIView', 'An error occurred while parsing script'))""")

rule('Util/RunScriptClass.py',
     """                self.tnumrdSignal.emit(f'{running_text}... Looptimes [{j + 1}/{self.runtimes}]')""",
     """                self.tnumrdSignal.emit('%s... %s [%d/%d]' % (
                    running_text,
                    QCoreApplication.translate('UIView', 'Looptimes'),
                    j + 1, self.runtimes))""")

rule('Util/RunScriptClass.py',
     """                self.tnumrdSignal.emit('finished')""",
     """                self.tnumrdSignal.emit(QCoreApplication.translate('UIView', 'finished'))""")

rule('Util/RunScriptClass.py',
     """            self.logSignal.emit('==============\\nAn error occurred during runtime')""",
     """            self.logSignal.emit('==============\\n' + QCoreApplication.translate(
                'UIView', 'An error occurred during runtime'))""")

rule('Util/RunScriptClass.py',
     """            self.logSignal.emit('script run failed, please check your log file')""",
     """            self.logSignal.emit(QCoreApplication.translate('UIView', 'script run failed, please check your log file'))""")

rule('Util/RunScriptClass.py',
     """                    self.logSignal.emit(f'An error occurred while calling {attach}, please check log file')""",
     """                    self.logSignal.emit(QCoreApplication.translate(
                        'UIView', 'An error occurred while calling %s, please check log file') % attach)""")


def main(root):
    ok = True
    for rel, old, new in RULES:
        path = os.path.join(root, rel)
        with io.open(path, 'r', encoding='utf-8') as f:
            src = f.read()
        tag = new.strip().splitlines()[0][:60]
        if old not in src:
            if new in src:
                print('  [skip] %-24s 已打过' % rel)
                continue
            print('  [FAIL] %-24s 未找到待替换片段' % rel)
            ok = False
            continue
        src = src.replace(old, new, 1)
        with io.open(path, 'w', encoding='utf-8', newline='\n') as f:
            f.write(src)
        print('  [ok]   %-24s %s' % (rel, tag))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else '.'))
