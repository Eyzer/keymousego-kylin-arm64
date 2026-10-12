import io
import os
import sys
import xml.etree.ElementTree as ET

root = sys.argv[1] if len(sys.argv) > 1 else '.'
ok = True

print('=== 1. .ts XML 合法性 ===')
for f in ('zh-cn.ts', 'zh-tw.ts', 'en.ts'):
    p = os.path.join(root, 'assets', 'i18n', f)
    try:
        r = ET.parse(p).getroot()
        n = sum(1 for _ in r.iter('message'))
        empty = []
        for m in r.iter('message'):
            src = m.findtext('source')
            tr = m.findtext('translation')
            if src and not (tr or '').strip():
                empty.append(src)
        print('  %-12s OK  messages=%-3d 空译文=%s' % (f, n, empty))
    except Exception as e:
        ok = False
        print('  %-12s FAIL %s' % (f, e))

print('=== 2. 新增词条抽查 (zh-cn) ===')
txt = io.open(os.path.join(root, 'assets', 'i18n', 'zh-cn.ts'), encoding='utf-8').read()
for s in ('Ready...', 'Cursor Position:', 'Cursor pos:', 'broken', 'record paused',
          'finished', 'Looptimes', '%d actions recorded', 'running', 'recorded',
          '%s running..', 'script not found, please record first!'):
    i = txt.find('<source>%s</source>' % s)
    if i < 0:
        ok = False
        print('  缺失: %s' % s)
        continue
    j = txt.find('</message>', i)
    seg = txt[i:j]
    tr = seg.split('<translation>')[-1].split('</translation>')[0] if '<translation>' in seg else '(无)'
    print('  %-38s -> %s' % (s, tr))

print('=== 3. 守卫子串关系校验 ===')
# recordMethod 用 translate('running') / translate('recorded') 做子串匹配，
# 必须真的出现在运行时文案里
run_msg = 'demo.json5 ' + '运行中..'          # %s running.. 的 zh-cn 译文拼出来
rec_msg = '已记录 3 个动作'                    # %d actions recorded 的 zh-cn 译文拼出来
for name, marker, target in (('running', '运行中', run_msg), ('recorded', '已记录', rec_msg)):
    hit = marker in target
    print('  %-9s marker=%s 在 %r 中: %s' % (name, marker, target, hit))
    ok = ok and hit

print('=== 4. Python 语法 ===')
import py_compile
for rel in ('UIFunc.py', 'Util/RunScriptClass.py', 'KeymouseGo.py', 'Plugin/Manager.py'):
    try:
        py_compile.compile(os.path.join(root, rel), doraise=True,
                           cfile=os.path.join(root, '__pyc_check__.pyc'))
        print('  %-24s OK' % rel)
    except Exception as e:
        ok = False
        print('  %-24s FAIL %s' % (rel, e))
try:
    os.remove(os.path.join(root, '__pyc_check__.pyc'))
except OSError:
    pass

print('=== 5. 关键改动落地 ===')
u = io.open(os.path.join(root, 'UIFunc.py'), encoding='utf-8').read()
r = io.open(os.path.join(root, 'Util', 'RunScriptClass.py'), encoding='utf-8').read()
checks = [
    ('UIFunc AUTHOR_INFO 定义', "AUTHOR_INFO = u'作者：Eyzer" in u),
    ('UIFunc 状态栏挂载', 'self.statusbar.addWidget(self.label_author, 1)' in u),
    ('UIFunc LANG_LABELS 定义', "LANG_LABELS = {'zh-cn': '简体中文'" in u),
    ('UIFunc LANG_CODES 反向映射', 'LANG_CODES = {v: k for k, v in LANG_LABELS.items()}' in u),
    ('UIFunc 默认简体中文', "LANG_LABELS.get(_lang, '简体中文')" in u),
    ('UIFunc 语言持久化用标签查代码', 'LANG_CODES.get(' in u),
    ('UIFunc 不再依赖 locale 判定', 'getdefaultlocale' not in u),
    ('UIFunc 无残留英文状态串', "'finished'" not in u.split('def onconfigchange')[0].split('get_script_list_from_dir')[-1]),
    ('RunScriptClass 导入 QCoreApplication',
     'from PySide6.QtCore import' in r and 'QCoreApplication' in r.split('class ')[0]),
    ('RunScriptClass 译文 running', "translate('UIView', '%s running..')" in r),
    ('RunScriptClass 译文 Looptimes', "translate('UIView', 'Looptimes')" in r),
]
for name, cond in checks:
    print('  %-34s %s' % (name, 'OK' if cond else 'FAIL'))
    ok = ok and cond

print()
print('RESULT=' + ('ALL_PASS' if ok else 'FAILED'))
sys.exit(0 if ok else 1)
