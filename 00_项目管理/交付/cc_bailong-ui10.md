# 交付：cc/bailong-ui10

- 车道／工作者：B 界面／白龙（cc，ui10）
- 状态：可合并

> 本分支开工时合进了 `cc/bailong-ui9`（ui9 当时可合并、还没进 main，本期要改它的 `XMenu`）。总装先合 ui9 再合本分支最省事；先合本分支也行，ui9 的提交和交付单 `cc_bailong-ui9.md` 会一起进来，按 ui9 自己的交付单归并。

## 变更记录草稿

## 2026-11-05 【cc·白龙·未经审查】装备页、状态页换角色键 Q／E；地图气泡停留照 SSEP 改 3 帧；状态 overlay 原版实测 ui10（dev.待定）

**换角色键**（ui9 待核①）：装备指令窗写的是 Q 上一位、W 下一位，状态页（`actor_page.gd`，状态页的基类）也是 Q／W。正式版运行时 `Input.keyMapper` 是 Q＝pageup、W＝up、E＝pagedown（`generated/oracle/party.json` 的 keys，ui9 已据此做列表翻页），装备指令窗（`YEP_EquipCore` setHandler pageup／pagedown）、状态页（`JAH_StatusMenuCore`）的 pageup／pagedown 是换角色，所以下一位应是 E。两处都改成 Q／E（加 PageUp／PageDown 不变），按住不连发（原版 `isTriggered`；状态页原来按住会连发）。判断收进 `XMenu.actor_key`。全工程 `rg KEY_W`：别处 W 都是「上」（地图行走、整队页），没有别处把 W 当翻页或换角色。这是向原版对齐的错键修正，没有开关、没占 O 号。

**地图气泡**（ui8b 待核 #7）：`Sprite_Balloon.waitTime` 在正式版被 `SSEP_BattleSpeedUp_v2`（启用）覆写成 Balloon÷BattleSpeed(Default)，再按 OkayKeyBoost 分支除一次 Default＝12÷2÷2＝**3**（不只战斗，地图气泡也走这里）；重制照 MV 默认用 12，每个气泡多停 9 帧（76 帧对 67 帧），事件「显示气泡并等待」也跟着多等 9 帧。改成从插件参数算出 3；QuickMode（SSEP 战斗加速开关）重制没有，恒为普通档。顺带两处照 `rpg_sprites.js` 改：气泡精灵加在角色精灵的父节点上，**透明或不透明度 0 的角色照样画气泡**（原来不画，是旧版气泡还画在角色 `_draw` 里时留下的条件）；setup 那一帧还没 `updateFrame`，帧号算出 −1 时不画（原来会取到图外 −48 的格子）。回退开关 `MVCharacter.BALLOON_SSEP = false` 回到 12。

**快捷栏**（ui8b 待核 #7）：`MKR_MapItemSlot` 在冻结 v0.28 的 `plugins.js` 里没装载，原版地图上根本没有快捷栏（`itemslot` 插件指令、CE478 的 `openItemSlotMenu` 原版都是无操作，dev.329 已按此做成无操作，`xiyou_script_gaps` 的 unloaded 例在测）。重制同样没有，无差异，关闭。

**状态 overlay**（gaps5 低优先「待核」）：用 `ui_reference` 的战斗夹具实测（无头 Chrome、静音，给敌人 0 加睡眠＋中毒）：原版敌人头上画 `States.png` 的 overlay（截图里是「ZZZ」），**重制整块没做**（工程里没有用到 `States.png` 的地方）。读数与规则整理在下面「下一期」，本期没改代码。

## 下一期（状态 overlay，派单第 3 项「战斗画面零星项」里最确定的一项）

原版读数（冻结 v0.28，战斗夹具 4 人、敌群 2，2026-11-05）：

- 状态 1～1300 里 84 个带 overlay（`States.json` 的 `overlay`，1～10；中毒类多为 1、睡眠 7、混乱 5、诅咒类 9）。`stateOverlayIndex`＝`states()` 顺序里第一个 overlay>0 的（敌人睡眠＋中毒时取睡眠 7）。
- `YEP_X_VisualStateFX`（启用，Actor／Enemy State Overlay 都是 true）给角色和敌人都建 `Sprite_StateOverlay`，插在主体精灵之后；锚点 (0.5, 1)，每格 96×96，帧 `(pattern×96, (overlay−1)×96)`。
- 节拍：`SSEP` 把 `Sprite_StateOverlay.animationWait` 改成 StateOverlay÷Default＝8÷2＝**4** 帧换一格，pattern 0～7 循环，换格时才重读 overlay 号。
- 位置（`YEP_X_ActSeqPack2` 的 `updateStateSprites`）：y＝−(spriteHeight − 64×scale.y) − ceil((浮空＋跳跃＋SV 敌人浮动) × spriteHeight)。读数：静态图敌人图高 60 → y＝4（世界坐标 262,335 对精灵 262,331）；角色 y＝0。
- 侧视图敌人：`YEP_X_AnimatedSVEnemies` 的 `updateSVStateSprite` 让可见性跟 `enemy().sideviewStateOverlay`（参数 SVEOverlay／`<Sideview Show State Overlay>` 备注），要再读该参数值。
- 状态图标（`Sprite_StateIcon`）原版**不显示**：敌人的不透明度 0、角色的 visible false（读数），重制不用做。截图里敌人名右边有个「4」，没查是什么（可能是状态回合数），下一期顺手核。
- 做法建议：`battler_sprite.gd` 加一个 overlay 子节点（主体之上、跟身体同变换但不随身体缩放），专项用上面读数做断言；读数 JSON 要的话用本期的驱动脚本思路（`ui_reference/serve.py` ＋战斗夹具按钮＋`addState`）再跑一次存进 `tests/fixtures/`。

## 交接板

- 下一步：ui10 二期做战斗者状态 overlay（规格见本交付单「下一期」）；ui9 剩下的待核②③（事件选项窗、角色进阶、更衣页、图鉴掉落、训练页没接翻页）和胜利结算背景（等 Kyo 定）照旧。
- 用户试玩说明：装备页、状态页换角色改成 Q／E（和 PageUp／PageDown 一样），W 不再换角色；地图上人物头顶的气泡（感叹号、问号等）停留时间短了约 0.15 秒，和正式版一致，事件等气泡的地方也快一点。
- 需要用户决定：无。

## 进度账

- 界面页面：零散细节 +0（错键修正与核实，按惯例不加分）。
- 战斗规则与画面：仍缺新增一项「状态 overlay（84 个状态）」，建议记进画面零星项的缺口里。

## 可优化（流程／工具／效率）

- 建议：原版画面读数这次用一个几十行的无头 Chrome 驱动（打开 `serve.py` 的页面、点工具栏按钮、逐段执行页面内 JS、截图）。`review_system_pages.cjs` 等几份驱动都各自复制了同样的连接代码，可以收成 `ui_reference/` 下一个公共的 `drive.cjs <网址> <就绪表达式> <步骤文件>`，以后核一个画面只写步骤文件；小，归界面车道。
- 建议：`SSEP_BattleSpeedUp_v2` 还覆写了 `Sprite_StateIcon`／`Sprite_Weapon`／`Sprite_Actor.motionSpeed`／`Sprite_Damage` 的节拍，重制已对上武器与动作（`battler_sprite.gd` 常量），这次查出气泡漏了；可以让审查线程按该插件的覆写清单逐个核一遍有没有别处漏。

## 验证

- 新专项 `xiyou_map_balloon`（9 项）：SSEP 参数、waitTime 3、共 67 帧、setup 帧不画、逐帧帧号对独立按 `rpg_sprites.js` 算的序列、透明角色照画、回退 76 帧与 MV 默认序列。
- `xiyou_list_paging` 85 项（ui9 的 77 项＋本期 8 项：`XMenu.actor_key`、装备页 W 不换／E 下一位／按住不连发／Q 上一位、状态页 W 不换／E／Q）。
- `xiyou_review_fixes` 16 项（地图气泡独立层、隐藏标志）。
- `语法检查.py` 通过；`工具回归.py` 全部通过；`回退开关覆盖.py` 新缺口 0。
- 云端选测（基准 main a8e0e6f3，126 场景、4 片，含 ui9 的改动面）：全部通过（提交 eb37db06）

## 本分支提交

- 合并 `cc/bailong-ui9`（2b5f5321 及之前，ui9 本身）
- 83daa215 装备指令窗、状态页换角色键 Q／E，`XMenu.actor_key`，`xiyou_list_paging` 加 8 项
- eb37db06 地图气泡 waitTime 照 SSEP 改 3、透明角色照画、首帧不画；新专项 `xiyou_map_balloon`，回退 `BALLOON_SSEP`
- 本交付单
