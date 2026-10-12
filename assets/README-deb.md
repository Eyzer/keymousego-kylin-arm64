# KeymouseGo —— 银河麒麟 / Linux aarch64 版

本包是 [KeymouseGo](https://github.com/taojy123/KeymouseGo) v5.2.1 的 **arm64 (aarch64) 重新打包版本**，
面向银河麒麟桌面操作系统 V10 等基于 Ubuntu 20.04 基线的国产 ARM64 Linux 发行版。

KeymouseGo 的功能是**录制鼠标键盘操作并自动回放**：你先手工做一遍，之后交给程序重复执行，
适合操作简单但单调重复的工作。可以理解为精简绿色版的「按键精灵」。

---

## 一、安装

```bash
sudo dpkg -i keymousego_5.2.1-1_arm64.deb
```

如果提示缺依赖：

```bash
sudo apt-get -f install
```

安装后不会覆盖系统里可能已存在的 `xdotool` 等任何命令。

## 二、启动

**图形菜单**：开始菜单 → 搜索「KeymouseGo」。

**命令行**：

```bash
keymousego                    # 启动图形界面
keymousego script.json5       # 直接执行脚本（无界面，命令行模式）
keymousego script.json5 -rt 3 # 执行脚本 3 次（-rt 0 表示无限循环）
```

## 三、使用

### 图形界面

| 按钮 | 作用 |
| --- | --- |
| Record | 开始录制（再点一次暂停/继续） |
| Launch | 执行当前选中的脚本（再点一次暂停/继续） |
| Pause Record | 暂停录制 |
| Terminate | 终止执行/录制 |

### 默认全局热键

| 热键 | 作用 |
| --- | --- |
| `F10` | 开始录制 / 暂停录制 |
| `F6`  | 开始执行 / 暂停执行 |
| `F9`  | 终止执行，或**结束录制并保存脚本** |

热键在界面右侧 Hotkeys 区域可以改成任意按键，改完立即生效。

> 注意：录制结束要按 **F9**（保存脚本），F10 只是暂停。

### 脚本

脚本保存在 `~/.local/share/keymousego/scripts/`，格式为 JSON5，可以直接用文本编辑器改。
界面右侧 Script 下拉框用来切换当前脚本。

## 四、文件位置

| 路径 | 说明 |
| --- | --- |
| `/opt/keymousego/` | 程序本体（含独立 Python 解释器与 Qt6 运行库），**只读** |
| `/usr/bin/keymousego` | 启动器 |
| `~/.local/share/keymousego/` | **用户数据**：`scripts/`（脚本）、`logs/`（日志）、`plugins/`（插件）、`config.ini`（配置） |

用户数据按 XDG 规范放在每个用户自己的家目录下，多用户互不干扰，卸载程序不会删除。

如果需要把数据放到别处，设置环境变量即可：

```bash
KEYMOUSEGO_HOME=/data/keymousego keymousego
```

## 五、系统要求

- CPU 架构：**aarch64 / arm64**
- 系统基线：**glibc ≥ 2.31**（Ubuntu 20.04 / 银河麒麟 V10 SP2、SP3 及更新版本）
- 桌面会话：**必须是 X11**
- 依赖：Qt6 所需的基础图形库（已写入包依赖，apt 会自动装齐）

### 必须使用 X11 会话

KeymouseGo 依赖 `pynput` 捕获全局鼠标键盘事件，在 Wayland 下无权限、无法工作。
查看当前会话类型：

```bash
echo $XDG_SESSION_TYPE     # 期望输出 x11
```

如果是 `wayland`，请注销后在登录界面的会话选择里切到「X11」/「UKUI on Xorg」再登录。
启动器检测到 Wayland 会话时会在终端打印提示（图形菜单启动看不到终端，属于正常现象）。

## 六、与上游的差异

本包**只做打包适配，不改动任何功能逻辑**。唯一的源码改动是数据目录定位：

上游用 `sys.argv[0]` 所在目录存放 `scripts/`、`logs/`、`plugins/`、`config.ini`。
装成 deb 后程序位于只读的 `/opt/keymousego`，普通用户启动时创建 `scripts/`
目录会因权限不足导致程序崩溃。因此 `to_abs_path()` 增加了一个环境变量兜底：

```python
base = os.environ.get('KEYMOUSEGO_HOME') \
    or os.path.dirname(os.path.realpath(sys.argv[0]))
```

未设置该变量时行为与上游完全一致。启动器 `/usr/bin/keymousego` 会把它指向
`~/.local/share/keymousego`。

另外，PyInstaller 打包时排除了 Linux 下用不到的 Windows 专属模块（`mouseinfo`、
`pygetwindow`、`tkinter`、`cv2`、`numpy`），这些模块在上游代码里都是 `try/except`
可选导入，缺失不影响任何功能。

## 七、卸载

```bash
sudo dpkg -r keymousego
```

`~/.local/share/keymousego/` 里的脚本和配置属于用户私有数据，卸载时**不会被删除**，
如需彻底清理请自行手动删除该目录。

## 八、许可

上游 KeymouseGo 采用 **GPL-2.0+** 许可，版权归 taojy123 所有，详见
`/usr/share/doc/keymousego/LICENSE.txt`。

本包内还包含 CPython（PSF-2.0）、Qt 6 / PySide6（LGPL-3.0）等第三方组件，
各自遵循其原始许可。
