# 交付：cc/platform-crash1

- 车道／工作者：平台（cc，项目线程「完成再刷西游Godot引擎重制」；DK 单）
- 状态：可合并
- 基于：`main` b42b974f（dev.380，含 input-crash 修复）
- 开关：无新开关（加的是工具和只在命令行带参数时才挂上的冒烟钩子，不改游戏行为）

## 变更记录草稿

## 2026-11-06 【cc·平台·未经审查】发行包按键冒烟、切场景后取视口的静态扫描（dev.待定）

- 背景：11-06 天启篇标题按空格/J 闪退（SIGSEGV 0x450），是发行模板才有的空指针：调试版只报错，现有测试和只跑无头、不按键的 发行入口冒烟.py 都看不到。
- **按键冒烟**：游戏带 `-- --smoke-keys=<序列>` 时由 GameApp 挂上 `XKeySmoke`（`core/key_smoke.gd`），用 `Input.parse_input_event` 注入按键（和真按键一样经 Input → 窗口 → 视口），每步往 stderr 打 `SMOKE_KEY=… scene=…`，按完打 `SMOKE_DONE` 并退出 0；不带参数时不挂、不改任何行为。`发行入口冒烟.py --keys` 在导出的发行包里跑四组（各一个新进程、新临时 HOME）：标题按空格／J／回车开新游戏，以及一串取消、方向、确认键进地图后再按确认、取消开关菜单；查退出码 0、按完、新游戏那几组最后在地图、`~/Library/Logs/DiagnosticReports` 没多出本包的崩溃报告（系统事后写，有进程被信号结束时最多等 40 秒）。`--keys-only --zip <包>`／`--app <.app>` 只做按键冒烟。
- **复现与修后**：用回退开关 `XKeyMap.SAFE_HANDLED = false` 临时导出的发行包（等同未修），四组全部退出码 -11，第四组按到第 6 步（Z）才崩，系统写出 3 份崩溃报告，签名和 Kyo 15:55 那几份一样（EXC_BAD_ACCESS、KERN_INVALID_ADDRESS at 0x450）；开关恢复后的包 10/10 通过。Windows：导出「Windows 发行」，用同名 macOS 发行模板跑 Windows 的 .pck 做同样四组，9/9 通过。
- **静态扫描** `07_开发环境/切场景后调用扫描.py`：找「切场景／摘下树之后，同一函数里还取 `get_viewport()`、`get_tree()`、`get_window()`、`get_parent()`、`create_tween()`、`/root` 节点」的写法，顺着本文件调用、存成 Callable 再 `.call()`、信号（按名字配）往上追，`return`、别的分支、`is_inside_tree()` 判过的不算。在修复前的 846a9358 上抓到 2 处：`entry.gd:222`（就是 11-06 这条：命令表 Callable → `_new_game` 切场景）和 `save_scene.gd:310`（读档页确认 → `loaded` → 标题的 lambda 切场景）；现在的 main 是 0 处。`queue_free()` 不算：帧末才摘下树。
- **接进检查**：扫描 `--check` 进 检查.sh 的 guards（行尾写 `# 离树后安全：理由` 可豁免）；其离线回归 `测试切场景后调用扫描.py` 进 tools 和 工具回归.py 门禁；按键冒烟要导出发行包（约 1～2 分钟），默认不跑，`检查.sh --release-keys` 或 `CHECK_RELEASE_KEYS=1` 打开，手动单跑 `python3 03_再刷重制_Godot/07_开发环境/发行入口冒烟.py --keys`。
- 测试 `xiyou_key_smoke`（7 项）：序列解析、认步、J／K 映射到确认／取消、不带参数不挂。

## 静态扫描清单（② 交付）

| 位置 | 触发路径 | 现状 |
| --- | --- | --- |
| `modes/xiyou/entry.gd:222`（846a9358） | `_unhandled_input` 确认 → `_activate` → 命令表 Callable `_new_game` → `change_scene_to_file` → 下一行 `get_viewport()` | 已由 input-crash（O-212，`XKeyMap.handled`）修掉 |
| `modes/xiyou/ui/save_scene.gd:310`（846a9358） | 读档页 `_unhandled_input` 确认 → `ok()` → `_perform("load")` → `loaded.emit()` → 标题里 `page.loaded.connect(func(): change_scene_to_file)` → 回来 `get_viewport()` | 同上，已修 |
| 现 main（b42b974f＋本分支） | — | 0 处 |

人工看过的切场景点（非 tests）：`game_app.gd`（autoload，自己不离树）、`entry_menu.gd:53`（按钮信号，引擎调用，后面无 GDScript）、`entry.gd:347／364`、`menu.gd:533`（deferred）、`menu.gd:548`（`to_title.emit()` 后 `_choose` 直接结束）、`map_scene.gd:1274`（deferred）、`mv_animation.gd:205`（`remove_child(self)` 后只 `queue_free()`）。没找到需要再改的；八戒 DJ 修的地图解释器 await 恢复那条（`mv_interpreter.gd`、`bulk_pills.gd`）不在本扫描范围，没碰。
扫描已知漏：跨文件直接调别的类的方法（非信号）、await 之后恢复（归解释器 host_alive）。

## 交接板

- 下一步：无（DK 完成）；以后导出正式包前可加跑 `发行入口冒烟.py --keys`。
- 用户试玩说明：无（游戏行为不变）。
- 需要用户决定：无。

## 进度账

- 无（工具与验证）

## 可优化（流程／工具／效率）

- 已做：按键冒烟和静态扫描（见上）；不想要时删 检查.sh 里两行、工具回归.py 一行即可。
- 建议：导出正式版（`~/Applications/再刷一把：天启篇.app`）的流程里默认带 `--keys`（多 1 分钟左右），归总装／导出流程。
- 安卓：发行包是 .apk，Mac 上跑不了，按键冒烟没做；钩子是 GDScript，`adb shell am start … -e` 传用户参数可以复用，要真机或模拟器（归平台车道）。Windows 只验了 .pck 的 GDScript（用 macOS 模板跑），没在真 Windows 上跑 exe。
- 注意：Kyo 同时在玩正式版时若正好闪退，同名崩溃报告会让 `keys_no_new_crash_report` 误报。

## 验证

- 发行包：`发行入口冒烟.py --keys` 10/10；`--platform windows --keys` 9/9；未修包（SAFE_HANDLED=false 临时导出）`--keys-only` 0/5、退出码 -11、3 份新崩溃报告（0x450）。
- 选测（选测.py main --list：ui_smoke、xiyou_event_compare）＋相关：`xiyou_key_smoke xiyou_entry_release xiyou_input_handled xiyou_flow`，6 个全部通过（544 秒）。
- `语法检查.py` 通过；`工具回归.py` 全部通过（含新项）；`测试选测.py CheckerTests CheckerStubParseTests` 32/32（`test_default_runs_everything` 加 `--release-keys` 让冒烟脚本也被调用到）；`测试切场景后调用扫描.py` 8 项通过。

## 待交叉核查

- `core/key_smoke.gd`、`core/game_app.gd`（挂钩子）、`tests/xiyou_key_smoke.*`、`07_开发环境/发行入口冒烟.py`、`切场景后调用扫描.py`、`测试切场景后调用扫描.py`、`检查.sh`、`工具回归.py`、`测试选测.py`。

## 本分支提交

- 29cbd5a2 切场景后调用扫描.py
- fbbb95a0 发行入口冒烟.py --keys、检查.sh --release-keys、门禁
- 220e2dbc XKeySmoke 钩子
- 7cb3504e 测试 xiyou_key_smoke；交付单
