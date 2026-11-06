# 交付：cc/platform-android6

- 车道／工作者：平台（cc，项目线程「完成再刷西游Godot引擎重制」；DT 单）
- 状态：可合并
- 基于：`cc/platform-cross2` 头 29465e46（DK→DP→DQ→DS 都还没进 main），排在它们后面合；交付前合过一次 main（无冲突）。

## 变更记录草稿

## 2026-11-06 【cc·平台·未经审查】安卓切后台自动存档：存到单独的自动存档，标题页可「继续」，不碰手动存档位（O-待定，dev.待定）

- 起因：DS 交付单「要 Kyo」第一条（手机切出去被系统杀掉会丢掉上次存档后的进度），派单定做、存到自动存档位、不碰手动存档位。
- `modes/xiyou/core/auto_save.gd`（新，`XAutoSave`）：切后台时 `on_pause(map, 毫秒)` 先看能不能存，不能就记 `skip:<原因>`：桌面（`XPlatform.is_mobile()` 为假）、开关关了、不在地图、没有游戏状态、战斗中（`_in_battle`）、事件在跑（`busy`，商店、对话等事件里开的页面都在这里面）、主菜单开着（`_menu_open`）、传送页开着（`transfer_page`）。都满足才存；`DEDUP_MSEC`（3 秒）之内的重复通知只写一次；写失败只 `push_warning`，不弹窗、不改状态。
- `core/platform.gd`：新加 `XPlatform.pause_hook`。`APPLICATION_PAUSED` 时在原有的 `on_paused` 末尾调它；手机上的 `APPLICATION_FOCUS_OUT` 也调它，桌面切窗口不调（安卓切后台两个通知都会来，先后不定，靠去重只写一次）。核心层不认识西游，钩子由地图挂。
- `map/map_scene.gd`：`_ready` 挂 `pause_hook = _on_app_pause`，`_exit_tree` 摘掉，离开地图后切后台什么都不做。
- `core/xsave.gd`：自动存档是单独的 `save_auto.json`（`save_auto`／`exists_auto`／`remove_auto`／`load_auto`／`auto_summary`），不占 1～30 号存档位。存的时候不加保存次数、不改 `current_slot`（一键存档还是存回玩家自己那格），文件里记下当时的档位 `autoFromSlot`，读回来接着用那格。任何一次手动存档成功（含挂机定时存、事件 Autosave）就删掉自动存档，因为它已经比手动档旧。写盘那段抽成 `_write`，读档后处理抽成 `_load_data`，手动存读档行为不变。
- `entry.gd`：标题页有自动存档时，左上角（让开刘海）多一个「继续（切后台时自动存的档）」按钮，点开写着存档时间和一句说明，可「读取」或「取消」。
- 回退：`XAutoSave.ON_PAUSE = false`，切后台只暂停，跟原版一样。已登进优化登记（O-待定·安卓切后台存档）。
- 测试：新专项 `xiyou_pause_save` 24 项，桌面上用 `XPlatform.force_mobile` 当成手机，用真的地图场景：地图上存（手动档位、保存次数、最近档位都不动）、FOCUS_OUT 去重、PAUSED 再来去重、过了窗口照常存、只有 FOCUS_OUT 也存、战斗／事件／主菜单／传送页不存、开关关不存、桌面不存、写失败不弹窗、标题页按钮有和没有、读自动存档回到原档位、手动存档后作废、离开地图钩子失效。旧代码上跑会挂（没有 `XAutoSave`，解析失败）；另用反向验证把 9 处判断逐一改坏，全被测出来。

## 安卓真机验收（给 Kyo，接在 DP 交付单「Kyo 真机测试清单」第 8 步后面）

9. 在地图上随便走到一个地方（别在对话、战斗、菜单里），按 Home 键回桌面，再从「最近任务」把游戏划掉。重新打开：标题左上角应该有「继续（切后台时自动存的档）」，点进去读取，回到刚才那个地方。
10. 在对话框还开着（或者战斗中、主菜单开着）的时候切到桌面、划掉游戏，再打开：不应该有「继续」按钮（或者按钮里的时间还是上一次在地图上切出去的时间）。
11. 有「继续」按钮时，读进去以后正常存一次档，回标题：按钮应该没了；「旧的回忆」里你原来那格存档是刚才存的进度，别的格没变。
12. 切出去再马上切回来（不划掉）：游戏接着玩，不卡、不弹任何存档提示。

## 交接板

- 下一步：等 Kyo 真机按上面 9～12 步试；试过再定 O-待定·安卓切后台存档留不留。
- 用户试玩说明：安卓上在地图里切到后台会自动存一份；被系统关掉后，标题左上角点「继续」能接着玩。手动存档位不受影响。
- 需要用户决定：O-待定·安卓切后台存档的默认值（现在开着）。

## 进度账

- 无（扩展账「安卓·生命周期」行交审查 51 核定：从「跟原版一致」改成「切后台自动存一份，没上真机」）

## 可优化（流程／工具／效率）

- 无

## 验证

- 新专项 `xiyou_pause_save` 24／24 通过。
- 反向验证（`反向验证.py`）9 项全咬住：去掉战斗、事件、菜单、开关、桌面判断，去掉去重，不接 FOCUS_OUT，手动存档不删自动存档，自动存档改掉档位。
- `选测.py main --list` 因为改了 `entry.gd` 给的是「整轮」；车道不跑整轮，选了跟存档、地图、标题、平台相关的 17 个场景（并行，合 main 之后跑），全部通过：xiyou_pause_save、xiyou_platform、xiyou_entry_release、xiyou_autosave、xiyou_save_events、xiyou_save_page、xiyou_hangup、xiyou_hangup_options、xiyou_demon_crown、xiyou_yunshang、xiyou_flow、ui_smoke、xiyou_input_handled、xiyou_mac_export、xiyou_battleback_save、xiyou_determinism、xiyou_key_smoke。整轮请总装合并时按影响面跑。
- `语法检查.py` 通过（598 个 .gd，0 个问题）；`工具回归.py` 全部通过（含回退开关覆盖）；`事件空绿扫描.py --check` 通过（空绿 55 例均在基线内）。
- 没上真机。

## 待交叉核查

- 改了 `core/xsave.gd`（存档核心，甲档）：`save` 拆出 `_write`、`load_slot` 拆出 `_load_data`，请重点核手动存读档没变；新加的自动存档不加保存次数。

## 本分支提交

- 2d4eba29 WIP：XAutoSave＋专项 xiyou_pause_save
- WIP：专项改写失败用例、优化登记 O-待定
- 合并 main（交付前）
- 交付单 cc_platform-android6（本提交）

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 安卓切后台自动存档（`modes/xiyou/core/auto_save.gd` `XAutoSave.ON_PAUSE`；`XSave.save_auto`、标题页「继续（切后台时自动存的档）」） | 切后台只暂停、不存档；手机把游戏杀掉就丢掉上次存档之后的进度 | 收到切后台通知（APPLICATION_PAUSED，或手机上先到的 FOCUS_OUT）时，只在地图上、事件不在跑（含商店等事件里开的页面）、不在战斗／主菜单／传送页时，存一份到单独的 `save_auto.json`：不占手动存档位 1～30，不加保存次数、不改「最近用过的档位」；3 秒内的重复通知只写一次；写失败只记日志不弹窗；桌面不触发。标题页有这份就多一个「继续」按钮，读回后档位还是原来那格；任何一次手动存档（含挂机定时存、事件 Autosave）之后这份作废删除 | 手机切出去被系统回收不丢进度（Kyo 要；DS 交付单「要 Kyo」第一条，派单定存到单独的自动存档位）；测试 `xiyou_pause_save` switch_off_no_save 覆盖回退 | `XAutoSave.ON_PAUSE = false`（切后台只暂停，同原版） | cc（平台 DT） | 待用户决定 |
