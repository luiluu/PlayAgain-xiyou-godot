# 交付：claude/bajie-monster-book

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_54）
- 状态：可合并

## 变更记录草稿

## 2026-10-23 【Claude·八戒_54·未经Codex检验】怪物图鉴接入；人物图鉴说明卡浅拷贝修正（dev.待定）

- **怪物图鉴**（新 `modes/xiyou/ui/enemy_book.gd` XEnemyBookPage、`core/enemy_book.gd` XEnemyBook，照冻结 v0.28 的 AB_EnemyBook v1.36＋Star 改版，只做启用分支）：
  - 目录窗 (0,0,426,720)：图鉴里的全部 823 只敌人（有名字、无 `<book:no>`），「序号＋名字」，没登记的写「？？？？？？」，左右键翻页，本次运行内记住上次光标。
  - 状态窗 (426,0,854,720)：名字、种族、出没于（地图名或「无记录」）、SV 图（侧视图角色图走待机动画）；右栏击败数、八项能力、命中／回避／暴击／暴击闪避／魔法闪避／魔法反射／反击、`<EnemyNote>` 备注；左栏弱化／抗性属性图标（图标上写百分比）、行动表前 10 条（按技能品质从低到高，「技能名   条件  权重:N」）。没登记的敌人状态窗全空。所有文字照 EnemyNameColorByDifficulty 改难度色。
  - 目录确定：已登记的打开掉落列表（品质从高到低，品质 0 不列，「名字   掉率%」或「【绝对掉落】」，法宝图标上写等级），说明卡跟在选中行右下；没登记的提示「未解锁」。掉落列表盖住状态窗（MV WindowLayer 挖空，同原版）。达成率窗原版压在目录窗下看不见，不画。
- **登记规则**（ResisterTiming=2）：开战时出现着的成员、战斗中 335 出现、336 变身的敌人记进本场名单，战斗结束（胜、逃、败）时全部登记；倒下的成员各记一次击败数；地图载入时把遇敌表敌群成员、开战时把本场敌群成员记上当前地图显示名（「出没于」）。新存档字段 `XState.enemy_book`（`enemyBook`：flags／defeat／maps），旧档读入为空。
- **入口**：主菜单「怪物图鉴」开放，照原版是公共事件 2（Menu 83 Ext），走 XState 预约槽；公共事件 2 的插件指令 `EnemyBook open` 由地图宿主打开图鉴。`EnemyBook complete`（大厅 Map004 事件 55、兑换大厅 Map137「打开所有图鉴」）全登记，另接 add／remove／clear。
- **改到的非独占文件**（各几行，合并时留意与悟空、沙僧车道冲突）：`core/mv_event_core.gd`（356 先问 `_host_plugin`，再在插件指令里认 `EnemyBook`）、`map/mv_interpreter.gd`（`_host_plugin` 覆盖与宿主指令 356）、`map/map_scene.gd`（`open_enemy_book()`，`load_map` 一行记出没地图）、`battle/battle_scene.gd`（开战、出现／变身、三处结束前各一行登记；没动 `battle_logic.gd`）、`core/xstate.gd`（存档字段三行）、`core/map_transfer.gd`（`drops()` 加可选 dropItemRate 参数，传送预览不变）。
- **人物图鉴**（八戒_52 未提交改动，唐僧_15 代存 734ba18d，本分支 cherry-pick）：技能详情说明卡按技能浅拷贝取内容，伤害技能不插「伤害属性」行（同原版）；`xiyou_actor_book` 补断言 `help_skill_copy_no_element_row`。
- **参照与测试**：`tests/fixtures/enemy_book_oracle.json`（冻结 v0.28 浏览器参照：新局队伍 1/8/9/10、难度 2，全目录名、115 只状态窗全部绘制、6 只掉落列表、3 只强制神话）；新专项 `xiyou_enemy_book` 34 项：逐只对照状态窗与掉落、神话（原版模式）、操作流程、登记规则、存读档、解释器路径、主菜单入口。`xiyou_panels` 灰显名单 6→5 项。
- **与原版不同（O-待定，总装分配编号）**：原版本想在图鉴里关掉神话（`Star.EliteEnemy.Morpho_EliteEnemy_Switch`），但该插件参数读成 NaN 没关上，每次打开图鉴都按 50% 随机把敌人显示成「【神话】」（能力 ×3.5、掉率 ×5，同一只每次打开不一样）。重制固定按普通敌人显示；`XEnemyBookPage.BOOK_FIXED_NORMAL` 设 false 恢复原版随机（参照里强制神话的 3 只已对照通过）。同 O-013（传送预览，用户已定保留）的理由。
- **原版差一点的地方**：击败数在战斗结束时按倒下的成员计，同一只敌人倒下、被复活、再倒下只记一次（原版每次 die 都 +1）。

## 优化登记

- O-待定 | 怪物图鉴的敌人显示（XEnemyBookPage） | 每次打开图鉴新建 Game_Enemy，EliteEnemy 按 50% 抽神话（图鉴本想关掉但开关参数读成 NaN），同一只敌人随机显示成「【神话】」、能力 ×3.5、掉率 ×5 | 固定按普通敌人显示 | 图鉴数值稳定可比，不会误以为基础能力或掉率翻倍；与 O-013 同理 | `XEnemyBookPage.BOOK_FIXED_NORMAL` 设 false | Claude（八戒_54） | 待用户决定

## 交接板

- 下一步：怪物图鉴期二（可砍）：战斗内「怪物信息」「图鉴」两个队伍指令（ShowCommandInBattle／ShowAllBookCommandInBattle，战斗中打开当前敌群或全图鉴，要改战斗指令窗）与 shift 快捷键；原版的「检查」类技能（`<checkEnemyStatus>`、`<addToEnemyBook>`）正式数据里没有，不做。主菜单其余灰显按盘点顺序：种族祝福菜单（随种族规则）→ 制作 → 异化工坊 → 宠物。
- 待沙僧（P3，`battler.gd` 独占）：`XBattler.additive_rate` 的求和写成 `sum += v - 1.0`，原版 installDamageElementRuntime 是 `reduce((s,v)=>s+v-1, 1)`，即 `(s+v)-1`；两种次序浮点末位不同（怪物图鉴参照里 68 处属性百分比如 89.99999999999999% 对 90%，`xiyou_enemy_book` 暂按 1e-9 容差比较并打印条数）。改成 `sum = sum + v - 1.0` 即与原版一致，可能影响战斗属性倍率的末位取整，改时跑战斗对照。
- 待查（P3）：CP_MagicWeapon 的 drawItemName 在法宝图标上写等级（16 号、textColor 12），重制只在怪物图鉴掉落列表画了；物品页、装备页、商店等列表里的法宝也该有，属各页面车道。
- 用户试玩说明：主菜单「怪物图鉴」可以打开了：左边是全部怪物目录（打过的才显示名字），右边是它的能力、属性弱点与抗性、出没地图、击败数和会用的技能；对打过的怪物按确定看掉落列表和每件掉落的说明。战斗结束后新遇到的怪物会登记进图鉴。
- 需要用户决定：怪物图鉴原版每次打开会随机把一半怪物显示成「神话」（数值 ×3.5、掉率 ×5），重制改成固定显示普通怪物（O-待定），要不要恢复原版的随机？（默认保留重制做法，同传送预览 O-013）

## 进度账

- 养成与周边系统：14% → 15%，怪物图鉴主菜单页与战斗登记接入（两个图鉴都已接入；八戒估，待沙僧复核）

## 本分支提交

- 142fa9e7 人物图鉴技能详情说明卡按技能浅拷贝（唐僧_15 代存八戒_52 改动）
- 710a9bbd 人物图鉴说明卡浅拷贝补断言
- c7aef560 怪物图鉴原版浏览器参照
- 5366ec76 怪物图鉴 XEnemyBook／XEnemyBookPage、登记、存档字段、主菜单入口与专项
- c58e171a 掉落列表盖住状态窗、法宝等级角标、解释器路径与截图断言；主菜单灰显 6→5
- （本提交）交付单，合 main

## 验证

- 相关专项（`并行测试.py`，16 个全过）：`xiyou_enemy_book` 34/34（新）、`xiyou_actor_book` 22/22、`xiyou_help_card` 970/970、`xiyou_panels` 35/35、`xiyou_interp_review` 13/13、`xiyou_event_compare` 5/5、`xiyou_battle_events` 108/108、`xiyou_battle_ui` 68/68、`xiyou_troop_events` 3839/3839、`xiyou_troop_events_b` 3862/3862、`xiyou_transfer` 38/38、`xiyou_drop_dh` 12/12、`xiyou_drop_record` 26/26、`xiyou_save_page` 40/40、`xiyou_battleback_save` 5/5、`xiyou_review135` 84/84。合进来的 main 两条只改交接板，不重跑。
- 截图对照：`xiyou_enemy_book -- --out=<目录>` 窗口模式存目录首屏与掉落列表，与原版 `__refShot` 截图版面一致（说明卡里「装备战力」行随战力设置）。
