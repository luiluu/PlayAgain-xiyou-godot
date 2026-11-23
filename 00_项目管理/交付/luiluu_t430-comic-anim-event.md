# 交付：luiluu/t430-comic-anim-event

- 车道／工作者：三阶漫画动画⑤／小A（T430）
- 状态：可合并

## 变更记录草稿

## 2026-11-23 【小A·事件·未经审查】T430 三阶漫画动画⑤：事件整段替换接线与双测试（dev.待定）

- 依据：私密仓 `重制设定/二阶到三阶_徐凤年回归动画_分镜_v0.5.md`（沿用 v0.4 定案，私密仓 `b220f6e0`）第 4.2 节、第 8 节拆卡 5。
- 代码改动：
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/rift.gd`：
    - 新增回退开关 `XRift.RIFT3_ANIM := true`（`false`＋`clear_cache()` 生成与 T412 逐条一致的原像素过场指令表）。
    - `_whisper_pages` 保留调用方显式缩进以支持 `111`/`411`/`412` 条件分支；拆出 `_rift3_pixel_body(indent)` 复用 T412 原像素过场指令体。
    - `_rift3_event()` 在 `RIFT3_ANIM=true` 时改为整段替换＋缺资源回退双支：`CodexWhisper.mark('rift3');` → `111 [12, "CodexRift3.available()"]` 成立支仅 `CodexRift3.play();` 与 `CodexRift3.replayMissed();`（不含 `MOB_EV`/`XUFENG_EV` 移动、`SLASH_ANIM` 23、静态 `401` 对话）→ `411` Else 支完整包裹原 `rift.gd:304-342` 像素过场（`indent=1`）→ `412` → `123 ["A", 0]`；保持 `EV205` 第 1 页并行查 `RIFT3_CONDITION` 与第 3 页自开关 A 不变。
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/mv_script.gd`：
    - `MVScript.run` 新增 `CodexRift3.play();`（调用 `await interp.host.play_rift3_anim()`）与 `CodexRift3.replayMissed();`（`_replay_rift3_missed` 按 `XRift3Anim.missed_lines` 顺序逐句调用 `await interp.host.show_message(msg)`，`whisper`/`sense`/`hint`/`follow`/`after` 的 `face`/`index`/`background`/`position` 与原文严格对齐 `rift.gd:306-341`，播完清空 `missed_lines`）。
    - `MVScript.eval_expr` 白名单新增 `CodexRift3.available()` → `"true" if XRift3Anim.available() else "false"`。
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/map_scene.gd`：
    - 新增地图宿主回调 `play_rift3_anim(allow_placeholder := false)`：暂停大厅 BGM（记录原位置）并停止 `lobby_fx` 低鸣／滴水／氛围小字（非 `EV205` 直接调用时同步暂停 `lobby_fx` 处理），非无头模式下截取当前视口冻结帧传给 `XRift3Anim.play(...)` 并 `await anim.finished`，结束后不摆 `XUFENG_EV` 上地图、通过 `XAudio.fade_in(bgm)` 恢复大厅 BGM 并返回解释器。
- 专项与验证：
  - 保全旧测 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_xufeng.gd`：入口仅增 1 行 `XRift.RIFT3_ANIM = false`，全套既有断言零改动，本机 `--headless --audio-driver Dummy` **53/53 通过**。
  - 新增专项 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim.tscn`（含 `.gd` 与 `.gd.uid`）：本机 `--headless --audio-driver Dummy` **70/70 通过**，覆盖 `EV205` `111`/`411`/`412` 成立支与 Else 支指令结构、`eval_expr` 与三层开关／缺资源守卫、`replayMissed()` 5 句参数精确对照、真开 `Map004` 自然播满 26.0s 零弹窗直接自由移动（含 `Engine.time_scale=1.6`、BGM 暂停/恢复、`lobby_fx` 让路、不摆 `XUFENG_EV`、再进不重播）、`t=1.0s`/`10.0s`/`23.0s` 跳过精确补播 5/4/2 句且播完清空 `missed_lines`、缺资源走 `411` Else 支实机回退原像素过场、`RIFT3_ANIM=false` 开关关闭回退、以及 `STAGE3=false` 回二阶。
  - 本机相关回归（`--headless --audio-driver Dummy`）：`tests/xiyou_rift3_anim_player.tscn` **59/59**、`tests/xiyou_rift2_canglong.tscn` **85/85**、`tests/xiyou_script.tscn` **40/40**、`tests/xiyou_lobby_corruption.tscn` **45/45**。
  - 静态与工具检查：`语法检查.py`（1191 个 `.gd` 0 问题）、`发行空壳.py check`（81 个脚本 782 个函数全过，退出码 0）、`工具回归.py`（23 项全部通过）。
  - 云端选测（提交 `42ce858d7f`，基准 `ee7cd3b85942a3da36b45d969a61079217c6fc28`）：**通过**（8 片 205 个场景全绿，最长一片 10.0 分钟），Run 链接：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45223934767 。

## 交接板

- 下一步：合并 `luiluu/t430-comic-anim-event` 后，事件整段替换接线与三层回退双测试已就绪；待拆卡 3（T428 Shader／劈页粒子／残格视觉增强）与拆卡 4（Muse 合成 `.ogv`＋WebP 入仓）齐备后，`XRift3Anim.available()` 将自动转为 `true` 切入漫画过场，无须再改事件层。
- 用户试玩说明：无玩家可见变化（T427 漫画视频与贴图素材尚未入仓，`XRift3Anim.available()` 运行时返回 `false`，进大厅触发 `rift3` 自动走 `411` Else 支无缝回退原 T412 像素过场）。
- 需要用户决定：无。

## 进度账

- 西游／三阶过场漫画动画：完成拆卡 5 事件命令层整段替换接线与双测试（`tests/xiyou_rift3_xufeng.gd`＋`tests/xiyou_rift3_anim.gd`），主表百分比不变。

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XRift._whisper_pages` | 1 处（`git grep -nE '[^[:alnum:]_]_whisper_pages[[:space:]]*\(' -- '*.gd'`） | 调用方 1 处逐处结论：仅 `modes/xiyou/core/rift.gd:368` 的 `_rift3_event()` 调用；去掉原强制 `c.indent = 0` 循环后，调用方显式传缩进，开关关时仍全为 `0`、开关开时保住 `111`/`411`/`412` 缩进 `1`，不影响任何其他事件 |
| `XRift._rift3_event` | 1 处（`git grep -nE '[^[:alnum:]_]_rift3_event[[:space:]]*\(' -- '*.gd'`） | 调用方 1 处逐处结论：仅 `modes/xiyou/core/rift.gd:140` 的 `patch_map()` 在 `STAGE3` 开启时调用；`RIFT3_ANIM=false` 产出与原版逐条一致指令，`RIFT3_ANIM=true` 产出双支并在缺资源时经 `411` Else 支完整回退原像素过场，双专项 53/53 与 70/70 均过 |
| `XRift.RIFT3_ANIM`（新增开关） | 0 处旧调用方（`git grep -nE '\bRIFT3_ANIM\b' -- '*.gd'` 仅本单 `rift.gd`／双测试与 `rift3_anim.gd` 动态读取） | 调用方 0 处旧代码受影响，新增开关默认 `true`、置 `false`＋`clear_cache()` 可一键回退 T412 原像素过场 |

## 云端选测与独占范围

- 云端选测（提交 `42ce858d7f`，基准 `ee7cd3b85942a3da36b45d969a61079217c6fc28`）：**通过**（8 片 205 个场景全绿，最长一片 10.0 分钟），Run 链接：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45223934767
- 截图：不涉及（本单为事件命令层接线与双测试，T427 正式美术素材尚未入仓，运行时缺资源自动回退原像素过场，测试通过资源存在性覆写走程序占位跑通全链路）。
- 本单改动文件（严格在拆卡 5 独占范围内）：
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/rift.gd`
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/mv_script.gd`
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/map_scene.gd`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_xufeng.gd`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim.gd`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim.gd.uid`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim.tscn`
  - `00_项目管理/交付/luiluu_t430-comic-anim-event.md`

## 本分支提交

- `42ce858d7` T430 三阶漫画动画⑤：事件整段替换接线与双测试（按分镜 v0.5 拆卡 5）
