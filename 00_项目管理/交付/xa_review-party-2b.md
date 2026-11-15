# 交付：xa/review-party-2b

- 车道／工作者：乙档核查＋文字审（小A / ag，工作树 `review-party-2b`）
- 状态：可合并
- 派单：`task_af5239ea2b96` / `ctx_8ff8f8d0150f`（只读代码，不改游戏工程，结论写入本交付单并提交）

---

## 一、核查范围与验证口径分层

### 1. 本轮前台实跑（已通过，耗时数秒～二十余秒）
- `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：`931 个 .gd，0 个问题`（通过）
- `xiyou_party_formation.tscn`：`74/74` 全通过（站位表、三档阵型点位、开关关闭回退、`XConfig` 存盘与坏值清洗、`XOptionsScene` 选项展示与左右切换、战斗实例落位）
- `xiyou_ui_skin_battle.tscn`：`58/58` 全通过（含 2A 指令环夹边与 `30483b649` 环心断言）
- `xiyou_hangup_options.tscn`：`57/57` 全通过（原版设置页与挂机选项）
- `xiyou_ui_skin_5c.tscn`：`79/79` 全通过（第 5C 批设置页新布局）
- `xiyou_ui_skin_hud.tscn`：`104/104` 全通过（含 2B 侧栏、顺序条、首领血弧、状态弹窗）

### 2. 本轮只看代码／历史提交核对（未另跑全量截图或战斗对照）
- `c4bf3eb75`、`30483b649`（合入 2A/5C 冲突解决）、`35cd2f289`（dev.614 收尾）
- `3105b6abc`、`8b5c092a7`（dev.610 `cc_ui-skin-2b.md` 与 `modes/xiyou/ui/skin/` 2B 全部文件）
- `ba1f7edd923ec7d9114de4398a434b46750b45b8`（私密设计仓 `xiyou-design-docs/champion-fest/文字审_小A.md`）
- 原版战斗／面板脚本：`party_formation.gd`、`battle_scene.gd`、`battle_logic.gd`、`xstate.gd`、`xconfig.gd`、`options_scene.gd`、`side_status.gd`、`otb_bar.gd`、`boss_status_panel.gd`、`party_status_panel.gd`、`skin_options_page.gd`、`skin_battle_ring.gd`、`skin_side_status.gd`、`skin_otb_bar.gd`

### 3. 本轮未核到（按派单不跑长测试，留给总装）
- **截图未见**：`03_再刷重制_Godot/04_验证/本地结果/party_formation/` 未入库（`main` 与本工作树均无该目录，本地结果被 gitignore），遮挡与位置分析仅按代码坐标核对，**未看到实际渲染截图**。
- **未重跑的长测试／专项**：
  - `xiyou_battle_ui`、`xiyou_battle_pixel`、`xiyou_costume_battle`、`xiyou_sequence_visual`（`c4bf3eb75` 改用了 `XPartyFormation.ENABLED = false`）
  - `xiyou_xuan_tusu_art`
  - 2B 字库覆盖自检（`charset_hei`／`charset_song`）、`皮肤关闭对照.py`、236 场景 `选测.py`、窗口化截图核查

---

## 二、`cc/party-formation` 乙档核查＋文字审（dev.614，`c4bf3eb75` / `30483b649`）

### 总结论：**功能本身通过；带 2 项 P2（需派修新界面设置漏接＋待定指令窗位置调优）、3 项 P3，无 P1。**

### 问题分级清单

- **P1**：无。

- **P2-1（新界面设置页漏接「战斗站位」分类与说明）**【只看代码核对】
  - 位置：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/skin/skin_options_page.gd:15-17, 25-60`
  - 事实：`XOptionsScene._build_list()` 已加入 `codexPartyFormation`，但天启篇第 5C 批新设置页 `XSkinOptionsPage` 的 `CATS["battle"]` 与 `DESC` 均未登记 `"codexPartyFormation"`。
  - 玩家侧后果：在天启篇新界面设置页中，「战斗站位」不会归入「战斗」分类，而是被 `XSkinOptionsPage` 自动兜底塞进第 7 个「其他」分类，且右侧详情牌说明文字显示为空串 `""`。（`xiyou_ui_skin_5c` 因只断言 `cats.size() >= 5` 而未报错。）
  - 建议：派修将 `"codexPartyFormation"` 加入 `CATS` 的 `"battle"` 类，并在 `DESC` 补上说明（建议文案见下文文字审）。

- **P2-2（指令窗／指令环在两排与菱形站位下遮挡状态栏／顺序条，截图缺失仅代码确认）**【只看代码核对；截图未见】
  - **(a) 两排错开时盖住右侧状态栏（含米拉 TP）**：
    - 旧界面：`XPartyFormation.WINDOW_ANCHOR` 固定 `x = 851`（`party_formation.gd:36`），`XActorCommandWindow.CMD_W = 220`（`battle_scene.gd` 侧右边缘达 `851 + 220 = 1071`）。右侧原版状态栏 `XSideStatus` 的 `HOME_X = 1080`，轮到当前角色时左移 `MOVE_ACTIVE = 48` 到 `1032`（选人态左移 `24` 到 `1056`），且状态图标格在左偏 `-36`（`996`／`1044`）。`1071 > 1032` 必然盖住当前行动角色的左半状态条（立绘左缘／血蓝／TP／状态格）。
    - 新界面（2A + 2B）：两排后排 `ROW_BACK_X = 819`（`party_formation.gd:26`），`XSkinBattleRing.place_for_actor()` 以脚底 `+ (0, -32)` 为环心，默认半径 `~139.1` 加球半宽 `41` 与边距 `10` 得半宽 `~190`，右缘达 `819 + 190 = 1009`（指令多时上限 `MAX_RADIUS = 230`，右缘可达 `1087`）；而 2B 右侧角色条 `XSkinSideStatus.panel_x() = 1280 - 16 - 290 = 974`，至少重叠 `35px`（多指令时超 `110px`）。
  - **(b) 菱形时指令窗／指令环压底部顺序条**：
    - 旧界面：菱形 4／5 人 3 号位在 `(699, 580)`（`party_formation.gd:79`），`window_anchor` 仅按底边 `<= 658` 限到 `y = 462`，6 行指令窗（`cmd_h = 196`）底边 `658`（7 行以上达 `687+`）。原版底部顺序条 `XOTBBar` 在 `(58, 618)` 宽 `830`（`x: 58..888, y >= 618`），与指令窗 `[851..888, 618..658]` 重叠。
    - 新界面（2A + 2B）：菱形 3 号位 `(699, 580)` 环心 `548`，`548 + 190 = 738 > 712` 被夹到 `y = 522`，环底达 `712`、`x` 跨 `509..889`；2B 底部顺序条 `XSkinOTBBar` 在 `(15, 627)` 宽 `550`（`x: 15..565, y >= 627`），左下角指令球落在 `[509..565, 627..712]`，压住顺序条右端（若 1 号位 `(579, 430)` 下移或大环亦会侵占顺序条上方）。
  - **位置建议**（供 Kyo 定方案参考，未改代码）：
    1. **旧界面**：`WINDOW_ANCHOR` 若固定右置，建议按 `x <= 1032 - 220 - 8 = 804`（再左移或按当前角色脚位左侧 `actor.x - 32 - 220` 弹出）、`y <= 618 - cmd_h - 8`（`618` 为 `XOTBBar` 顶边）夹边，避免硬塞进 `[851, 462]` 撞 `XSideStatus`（`1032`）和 `XOTBBar`（`618`）。
    2. **新界面（2A+2B）**：可二选一或组合——（i）把 `XSkinBattleRing` 的夹边安全框右侧收紧到 `XSkinSideStatus.panel_x() - 12`（`962`）、底边在横向与 `XSkinOTBBar` 重叠区收紧到 `618`，并把 `OFFSET` 略往左上移（如 `(-44, -52)`）；（ii）将我方 `ROWS`／`DIAMOND` 整体再左移约 `40～50px`（`xiyou_party_formation.gd` 数据显示 95% 敌群右缘 `<= 406`，目前菱形最左 `579`、环左 `389`，若阵型左移需同时核对 1 号位环左缘与前排大体型 Boss 的间距）。

- **P3-1（重制版玩家可见性与默认值行为记录）**【已实跑验证 `xiyou_party_formation` + 读代码 `options_scene.gd`、`xconfig.gd`】
  - 见下方逐项第 3 条：重制版玩家**能看到**「战斗站位」选项，且新旧存档默认均为 `0`（「两排错开」），**不再默认原版竖排**。若需老玩家／原版界面默认仍走「原版竖排」，需总装／Kyo 明确（当前按默认设计实现无代码 Bug）。

- **P3-2（注释编号占位未替换）**【只看代码核对】
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/scene/options_scene.gd:55` 注释仍留着 `dev.614` 的占位优化号未替换为正式 O 号（如 `O-473`）。

- **P3-3（4 个回退原版站位的已有测试与长测试未复跑）**【未核到】
  - `c4bf3eb75` 在 `xiyou_battle_ui`、`xiyou_battle_pixel`、`xiyou_costume_battle`、`xiyou_sequence_visual` 中显式关闭了 `XPartyFormation.ENABLED = false`，本轮按规则未跑长测试，待总装统一覆盖。

---

### 逐项核查明细（`cc/party-formation`）

#### 1）编队位置和阵型点对应（1～5 人）【已实跑验证 + 读代码】
- 编队取位链路：`XBattleLogic.setup` 读取 `s.battle_members()`（即 `XState.battle_slots` 编队顺位 `0..n-1`，`xstate.gd` / `battle_logic.gd`），`XBattleScene._spawn_actors` (`battle_scene.gd:440-445`) 按 `XPartyFormation.points(actors.size())` 逐一赋值 `s.home = points[i]`，不做按体型重排。
- `ROWS`（两排错开，`ROW_FRONT_X=669, ROW_BACK_X=819, ROW_Y=[280,380,480,580]`，`party_formation.gd:26-34, 65-75`）：
  - 1 人：`[(744, 430)]`（居中）
  - 2 人：`[(669, 330), (669, 530)]`（前上、前下）
  - 3 人：`[(669, 300), (669, 540), (819, 420)]`（1 前上、2 前下、3 后中）
  - 4 人：`[(669, 280), (669, 480), (819, 380), (819, 580)]`（1 前上、2 前下、3 后上、4 后下）
  - 5 人：`[(669, 280), (669, 480), (819, 355), (819, 505), (669, 430)]`（1～4 保持前2后2语义，5 号补前排中央）
- `DIAMOND`（菱形，`CX=699, CY=430, DX=120, DY=150`，`party_formation.gd:21-24, 77-86`）：
  - 1 人：`[(699, 430)]`
  - 2 人：`[(619, 355), (779, 505)]`（前上、后下斜对）
  - 3 人：`[(579, 430), (729, 300), (729, 560)]`（前尖、后上、后下三角）
  - 4 人：`[(579, 430), (699, 280), (699, 580), (819, 430)]`（1 前尖、2 上角、3 下角、4 后尖）
  - 5 人：在 4 人基础上追加 5 号中心 `(699, 430)`
- `> 5` 人（`party_formation.gd:60-61`）：直接回退 `XBattleScene.party_layout(n)`。
- 遮挡渲染顺序与换人：`XBattleScene._sort_actor_sprites()`（`battle_scene.gd:458-464`）只收集 `mine` 现有子节点索引槽位，按 `home.y` 升序回填（下排角色画在上排前面，不打乱非角色节点如敌方或特效层级）；`_tianqi_swap`（`battle_scene.gd:1173`）新角直接继承 `old.get_index()` 与 `old.home`。已通过 `xiyou_party_formation` 74/74 实跑验证。

#### 2）原版竖排档与开关关闭回退【已实跑验证 + 读代码】
- 当 `XPartyFormation.ENABLED = false` 时：
  - `current()` 直接返回 `COLUMN (2)`；
  - `points(n)` 直接返回 `XBattleScene.party_layout(n)`；
  - `window_anchor(pos, _cmd_h)` 原样返回 `pos`；
  - `XOptionsScene._build_list()` 不插入 `FORMATION_OPTION`。
- 当选择「原版竖排」(`COLUMN = 2`) 或开关关闭时：`party_layout(1..5)` 的 `y` 坐标严格单调递增，`_sort_actor_sprites` 保持原子节点顺序不变，与原版完全一致。

#### 3）设置项存盘键、坏值回默认、重制版可见性与默认值【已实跑验证 + 读代码】
- **存盘键**：`XConfig.DEFAULTS["codexPartyFormation"] = XPartyFormation.DEFAULT`（即 `0`，对应「两排错开」；`xconfig.gd:55`）。未放入 `set_flag`，不按开关类型写布尔值。
- **坏值处理**：`XConfig.ensure_loaded()`（`xconfig.gd:118-119`）对 `"codexPartyFormation"` 调用 `XPartyFormation.sanitize(v)`（`party_formation.gd:90-94`）：
  - `v is int or v is float` → `clampi(int(v), 0, 2)`（如 `-3 -> 0`、`99 -> 2`）
  - 非数值（字符串、null、数组等）或缺失键 → 回默认 `0`（「两排错开」）
  - `XConfig.party_formation()` 读取时同样走 `sanitize` 兜底（`xconfig.gd:268-269`）。
- **重制版（原版界面）玩家能否看到 & 默认值**：
  - `options_scene.gd:118` 仅判断 `if XPartyFormation.ENABLED:`，**没有**判断 `XUiSkin.on()` 或天启线开关。
  - 因此：**重制版（关闭新皮肤）玩家也能在系统设置里看到「战斗站位」选项；且新旧存档未写该键时默认均为 `0`（「两排错开」）**（重制版老玩家若想保持 1:1 竖排需自己在设置中切到「原版竖排」）。

#### 4）截图里的遮挡与位置建议【未见截图；只看代码核对】
- `03_再刷重制_Godot/04_验证/本地结果/party_formation/` 在 `main` 与本工作树均不存在（已在上面 P2-2 写明缺失情况、原版/新界面冲突坐标与建议方案）。

#### 5）文字审（party-formation）【只看代码核对】
- 设置项名：`战斗站位` —— 清晰直观，与原版设置项命名风格一致。
- 三档选项名：`两排错开`、`菱形`、`原版竖排` —— 无错别字、无超长截断风险，档位含义一眼明确。
- `SLOT_NAMES`（`party_formation.gd:14`）：`["两排错开", "菱形", "原版竖排"]`；`options_scene.gd:315` 下拉／循环状态显示正常。
- **新增建议说明文字**（供补入 `skin_options_page.gd` 的 `DESC["codexPartyFormation"]`）：
  - `"设置我方战斗中的站位阵型，按编队顺序站位。下一场战斗生效。"`

#### 6）三处合并冲突（`30483b649`）与 `xiyou_ui_skin_battle.gd` 环心断言核查【已实跑验证 `58/58` + 读 diff】
- `battle_scene.gd:1291-1299`：`if _cmd_window.has_method("place_for_actor"):` 走 2A 指令环 `place_for_actor(actor_sprite)`；`else:` 走旧指令窗 `XPartyFormation.window_anchor(pos, _cmd_window.size.y)`。两边互斥分支干净，互不破坏。
- `xconfig.gd`：`DEFAULTS`、`ensure_loaded`、`party_formation()` 与 5C 的 `codexUiSkin` / `codexUiMotion`（及 `ui_skin` / `ui_motion` 方法）各自独立，无键名冲突或类型错乱。
- `options_scene.gd`：`SKIN_OPTION`／`MOTION_OPTION` 与 `FORMATION_OPTION` 在列表构造、切换与刷新逻辑中均按 `item.symbol` 分派，互不干扰。
- `tests/xiyou_ui_skin_battle.gd:152-157`：环心夹边断言与 `XSkinBattleRing.place_for_actor` 实际中心计算（含 `_origin` 偏移及 `XSkinBattleRing.MARGIN + ORB_HALF` 边界夹取）以及中心点 `x` 对齐角色逻辑一致，且 `xiyou_ui_skin_battle.tscn` 实跑 `58/58` 通过。

---

## 三、`cc/ui-skin-2b` 文字审（dev.610，`main` 只读核对）

对照对象：
- 设计口径：`xiyou-design-docs/champion-fest/文字审_小A.md`（提交 `ba1f7edd923ec7d9114de4398a434b46750b45b8`）
- `main` 上的 2B 交付清单：`3105b6abc:00_项目管理/交付/cc_ui-skin-2b.md`「新增可见文字」表
- `main` 上 2B 全部源码文件（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/skin/`）：
  - `skin_battle.gd`
  - `skin_side_status.gd`
  - `skin_otb_bar.gd`
  - `skin_boss_arc.gd`
  - `skin_boss_status.gd`
  - `skin_party_status.gd`
  - 另对照原版参照：`boss_status_panel.gd`、`party_status_panel.gd`、`boss_status.gd`、`power_panel.gd`

### 逐文件文字核查结果【只看代码核对】
1. **`skin_party_status.gd:204`**：cc Sonnet 代核时已从 `"当前没有状态"` 改为 `"当前没有%s状态"`（分类为「异常」「增益」「常驻」时显示 `"当前没有异常状态"`／`"当前没有增益状态"`／`"当前没有常驻状态"`，「全部」时 `%s` 为 `""` 显示 `"当前没有状态"`），与 `skin_boss_status.gd:205` 完全一致，符合 `ba1f7ed` 口径。
2. **`skin_party_status.gd` 其余可见字**：`人物属性`、`详情 ▾`／`收起 ▴`、`异常 N`／`增益 N`／`常驻 N`／`全部 N`、`↑ / ↓ 选状态`、`← / → 换分类`、`Q / E 换人`、`取消 返回战斗`、`4 回合`／`2 层`（`spaced()`）、`%s · %d 回合`、`%s · %d 层`、`Lv %d`、`盾 %s`、`%s / %s`（`当前 / 上限`）、`查看时暂停战斗，关闭后继续。`——均简明无错字，符合 `ba1f7ed` 标点与空格口径。
3. **`skin_boss_status.gd`**：`敌人属性：%s`、`异常 N`／`增益 N`／`全部 N`、`‹ 上一页`／`下一页 ›`／`返回列表`、`%s · 状态详情`、`查看时暂停战斗，关闭后继续。`、`当前没有%s状态`——全部合规。
4. **`skin_side_status.gd`**：`黑暗 4 回合`（缩写＋数字＋回合，符合 `ba1f7ed` 空格规范）、`+3`、`详情 ▾`、状态省略提示等——全部合规。
5. **`skin_otb_bar.gd`**：`下回合`（10 字内简标，未用英文字母或冗余前缀）、行动顺序数字——符合 `ba1f7ed` 与 `xiyou_ui_skin_hud` 测试。
6. **`skin_boss_arc.gd`**：首领名、HP/护盾数字（`%s / %s`）、状态胶囊文字——全部合规。
7. **`skin_battle.gd`**：`返回战斗`（查看状态弹窗顶部／底提示）——全部合规。

### 2B 文字必改清单（`文件:行｜原字｜改成`）
- **无**（cc Sonnet 代核修正 `skin_party_status.gd:204` 后，未发现新的必改文字问题）。

---

## 变更记录草稿

## 2026-11-15 【ag·小A·未经审查】乙档核查 cc/party-formation 与 2B 文字审（dev.待定）
- 核查结论：`cc/party-formation`（`dev.614`）功能本身通过，已实跑 `xiyou_party_formation`（74/74）、`xiyou_ui_skin_battle`（58/58）、`xiyou_hangup_options`（57/57）、`xiyou_ui_skin_5c`（79/79）、`xiyou_ui_skin_hud`（104/104）及 `语法检查.py`（931 文件 0 问题）；`cc/ui-skin-2b`（`dev.610`）对照 `ba1f7ed` 复核无新增必改文字（`skin_party_status.gd:204` 已改好）。
- 发现问题与现场修复：
  - （已修）P2-1：`modes/xiyou/ui/skin/skin_options_page.gd` 的 `CATS["battle"]` 已补 `codexPartyFormation`，`DESC` 已补说明「设置我方战斗中的站位阵型，按编队顺序站位。下一场战斗生效。」（不再落入「其他」或空说明；见提交 `a03f45787`）。
  - （待定）P2-2：代码坐标核对确认两排错开时旧指令窗（右缘 `1071 > 1032`）与新指令环（右缘 `1009+ > 974`）压右侧状态栏、菱形 3 号位时旧指令窗（底 `658+ > 618`）与新指令环左下（`509..565, 627..712`）压底部顺序条（截图目录未入库，未见实拍图；等 Kyo 定指令位置，本轮未改）。
- 交付记录：见交付单 `xa_review-party-2b.md`（分支 `xa/review-party-2b`）。

---

## 交接板

- 下一步：
  1. 结合 Kyo 指令位置定稿调整两排／菱形指令窗（旧版 `WINDOW_ANCHOR`）与指令环（`XSkinBattleRing`）安全框或站位坐标，并补复跑 `xiyou_battle_ui`、`xiyou_battle_pixel`、`xiyou_costume_battle`、`xiyou_sequence_visual`、`xiyou_xuan_tusu_art` 及 2B 字库／236 场景 `选测.py`。
- 用户试玩说明：无（核查＋设置分类补登）。
- 需要用户决定：无（指令窗／指令环遮挡位置方案已附坐标建议，供 Kyo 拍板）。

## 进度账

- 无工程进度变更。

## 可优化（流程／工具／效率）

- 建议：`XSkinOptionsPage` 的设置分类／说明漏项可在 `xiyou_ui_skin_5c.gd` 中加一条断言（检查所有 `XOptionsScene._build_list()` 中非隐藏条目均已归类进 `CATS` 且有非空 `DESC`），避免后续新加设置项静默掉进「其他」分类（预计 5 分钟，可回退，归新界面／测试车道）。

## 本分支提交

- `6ace5ae4e` 核查：cc/party-formation 乙档核查与 cc/ui-skin-2b 文字审
- `a03f45787` 修复：新界面设置页战斗分类补 codexPartyFormation 与说明（P2-1）
- （本修复记录追加提交，见 `git log -1`）

---

## 修复

- **派单**：`task_eb43908ad10a` / `ctx_c2e156cd5692`（在 `xa/review-party-2b` 续修 P2-1 与 P3-2，不动 P2-2 指令窗位置）。
- **1）P2-1 已修**（提交 `a03f45787`）：
  - 文件：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/skin/skin_options_page.gd`
  - 改动：`CATS["battle"]` 列表（位于 `"codexBattleAutoDefault"` 之后）加入 `"codexPartyFormation"`；`DESC` 新增 `"codexPartyFormation": "设置我方战斗中的站位阵型，按编队顺序站位。下一场战斗生效。"`（照 `ba1f7ed` 简明口径及同组战斗项风格定稿）。
- **2）P3-2 复核（无需改动）**：
  - 核对 `main` 现行 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/options_scene.gd:47`（及 `modes/xiyou/battle/party_formation.gd:3`），合并收尾提交 `35cd2f289` 已将原本的占位编号替换为正式号 **`O-473`**（`## 重制新增：战斗站位（O-473，XPartyFormation）：...`）；全文件检索无残留占位，前面报告误记行号 `55` 系核查旧提交 `c4bf3eb75` 所致，故 `options_scene.gd` 无需再改。
- **3）P2-2 未动**：指令窗／指令环遮挡位置按派单等 Kyo 定稿，未改动。
- **4）修后前台验证（全通过）**：
  - `./03_再刷重制_Godot/07_开发环境/godot --headless --path 03_再刷重制_Godot/01_Godot工程 res://tests/xiyou_party_formation.tscn`：`74/74`
  - `./03_再刷重制_Godot/07_开发环境/godot --headless --path 03_再刷重制_Godot/01_Godot工程 res://tests/xiyou_ui_skin_5c.tscn`：`79/79`
  - `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：`931 个 .gd，0 个问题`

