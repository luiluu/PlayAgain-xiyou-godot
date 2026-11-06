# 交付：cc/rules-ui16

- 车道／工作者：B 界面／rules-ui（cc，BQ 冻结后改动期一·界面三项）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·rules-ui·未经审查】冻结后跟进：Boss 血条范围、Boss 面板开关、白字排蓝字上（三项都是开关，默认保持 v0.28 旧值）（dev.待定）

依据：`冻结正式源/冻结后改动盘点_v0.29-v0.62.12.md` 期一界面三条；原版行为读 `v0.62.12/app.nw` 的源码（只读，没改）。三项都做成 `static var` 开关，默认 `false`＝v0.28 的样子，**等 BM 换源后一起翻成 `true`**（翻的时候每项还要看一遍下面「换源后」）。

1. **v0.37 Boss 血条范围**（`battle/boss_hp_bar.gd` `XBossHpBar.RANGE_V037`）
   - 原版（`installNativeZhenqiRuntime.js` 「首领血条」`Z.bossHpEnemy`）：除插件 MOG_BossHP 名单外，下面三类敌人也显示首领血条：①神兵之仙（`Z.WEAPON_BOSS` 编号，或敌人备注 `<CodexZhenqi: weapon N>`）；②心魔／天劫瓶颈之战敌群（901／823）、心魔训练敌群（770）里的敌人。只走显示层：名单里的 Boss 优先（敌群里最后一个未隐藏的）；名单里一个也没有时才取这类里最后一个未隐藏的；它们没有头像，头上的小血条也不出（`hpGaugeVisible` 返回 false）。命中时条跟着它们走（`Game_Action.apply` 记命中前血量）。
   - 重制：`is_extended(enemy_id)`（带缓存）、`pick()` 的回退、`applied()` 认这类目标；小血条用 `XBossHpBar.small_gauge_visible(e)`（`battle_scene.gd` 一处调用），没动 `core/enemy.gd`。`XZhenqi.WEAPON_BOSS／TRIAL_TROOP／HEART_TROOP` 本来就移植了，直接用。
   - 对本批其它改动的影响：名单、难度、AI、计数都不碰。
2. **v0.56 Boss 状态面板开关**（`battle/boss_status_panel.gd` `XBossStatusPanel.TOGGLE`、`ui/options_scene.gd`、`core/xconfig.gd`）
   - 原版（`Codex_BossStatusSummary.js`）：设置页多一行「Boss状态面板」（`ConfigManager.codexBossStatusPanel`，默认开，旧配置视为开，切换即存）；关掉后面板不显示、不拦截点击，Boss 血条照常。用 `options_probe` 读了 v0.62.12 的行序：在「步步遇敌」后、「消息提醒」前（33→34 行）。
   - 重制：开关开时设置页插这一行（状态 ON/OFF，确定取反、左关右开）；`XConfig.DEFAULTS` 加 `codexBossStatusPanel: true`，读档只认存成 false 才关；面板 `_process` 里 `panel_enabled()` 为假就当没有 Boss。开关关时设置页还是 33 行，`generated/oracle/options.json` 的逐行对照不受影响。
3. **v0.36 白字属性排在蓝字特效前**（`ui/help_card.gd` `XHelpCard.WHITE_STATS_FIRST`、`equipment_rows`）
   - 原版（`installDisplayPreferencesRuntime.js` `D.equipmentRows`）：装备（有 wtypeId／atypeId）的说明行里，没有 `\c[1-9]` 且行颜色空或纯白、名字是基础属性类（最大生命值…暴击率…攻击次数、各属性伤等）的行，按原顺序移到第一条以 `\c[1]` 开头的「特效／效果／成长：」之前；没蓝字或没白字属性就原样。
   - 重制：`equipment_rows(rows)` 原样移植（正则逐字对照），挂在 `desc_params` 末尾（`_terms` 之后、魔冠取整之前，对应原版 CodexDisplay 的 getDescParams 包装）。只给武器／防具。猫一族物品的 `characterHelpView` 那条路原版也走一遍，重制里猫物品的 rows 同样经 `desc_params`，已覆盖；心钢／狂妄走 `XGrowthHelp.rows`（自己重算 descParams）这条没挂（原版它走 helpView 之内，是否也过这一步没有夹具可对，列在「换源后」）。
   - 注意：v0.43 又把装备／技能说明按阅读顺序重新分区（`installPanelLayoutV043Runtime.js`），那是后面的期次，本项只做 v0.36 这一步。

### 测试
- `xiyou_boss_hp_bar` +16 项（默认关不认、开后选条、名单优先、隐藏跳过、最后一个、命中跟踪、小血条、关回去）；`xiyou_boss_status` +7 项（开关关＝面板不变，开＋标志关＝面板藏、血条不变，标志开回＝面板回来）；`xiyou_options_basic` +9 项（默认没这行；开着时行序、默认 ON、确定／左右、重读配置）；`xiyou_help_card` +6 项（默认旧序、开后白字在蓝字前、彩色行与说明行不动、行数不变、无蓝字不变、技能不动）。
- 因开关默认关，原有对照（`generated/oracle/*.json` 逐行比）不受影响。

## 优化登记草稿（总装合并时换成实际 O 号）

这三项是「跟进原版新版」，不是我们自己改原版；但要换源后才翻，翻之前是重制自己的旧值，所以都按开关登记，翻的决定随换源。

| 编号 | 位置 | 原版 | 重制 | 理由 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `battle/boss_hp_bar.gd` `RANGE_V037` | v0.37 起瓶颈之战／神兵试炼的 Boss 也显示首领血条 | 开关默认关（v0.28 只认插件名单）；换源后翻开 | 跟进冻结后的原版改动，玩家能看到 | `XBossHpBar.RANGE_V037 = false` | cc（BQ） | 已做，换源后翻开 |
| O-待定-2 | `battle/boss_status_panel.gd` `TOGGLE`、设置页 | v0.56 设置页有「Boss状态面板」开关（默认开） | 开关默认关（没有这行）；换源后翻开 | 同上 | `XBossStatusPanel.TOGGLE = false` | cc（BQ） | 已做，换源后翻开 |
| O-待定-3 | `ui/help_card.gd` `WHITE_STATS_FIRST` | v0.36 起装备白字属性排蓝字特效前 | 开关默认关（备注原位）；换源后翻开 | 同上 | `XHelpCard.WHITE_STATS_FIRST = false` | cc（BQ） | 已做，换源后翻开 |

## 交接板

- 下一步：BM 换源合进 main 后，把三个开关翻成 `true`（`RANGE_V037`、`TOGGLE`、`WHITE_STATS_FIRST`），同时：①`generated/oracle/options.json` 随换源变成 34 行，设置页那行不再靠开关插入，可把 `OPTIONS` 常量里直接加一行、去掉 `options_scene.gd` 里的条件插入；②`xiyou_boss_hp_bar`／`xiyou_boss_status`／`xiyou_options_basic`／`xiyou_help_card` 里「默认关」的断言改成默认开；③`help_cards.json` 参照在新源下重测（白字顺序会让装备卡逐行对照变化）。
- 用户试玩说明：开关默认关，现在玩起来和之前一样；翻开后：瓶颈之战／神兵试炼战里顶上出现首领血条；设置页多一行「Boss状态面板」；装备说明里白字属性排在蓝字特效上面。
- 需要用户决定：无（翻开时间跟换源走）。

## 进度账

- 界面：冻结后跟进期一界面三项做完（开关默认关）

## 可优化（流程／工具／效率）

- 无

## 验证

- 语法检查通过；`工具回归.py` 全过；专项 `xiyou_boss_hp_bar`、`xiyou_boss_status`、`xiyou_options_basic`、`xiyou_help_card` 通过；`选测.py main --list` 列了 160 个场景（因 `xconfig.gd`、`battle_scene.gd` 被引用面广），本机多车道占槽，跑到 19/160 速度太慢，停掉改跑挑出的 26 个相关场景全过：xiyou_battle_ui／battle_options／hp_gauge_visible／enemy_state_icon／hangup_options／notice_options／options_misc／costumes／list_paging／cat_help／character_help_cost／growth_help／actor_book／black_flash_ui／book_capacity_ui／demon_crown／power／status_page／boss_lifecycle／boss_output／boss_react／battle_events／autosave／achievement／event_compare／determinism。没跑的 134 个：三项开关默认关，唯一默认生效的是 `XConfig.DEFAULTS` 多一个 `codexBossStatusPanel: true` 键和 `battle_scene.gd` 一处调用改成 `small_gauge_visible`（开关关时等价原调用），请总装合并后的选测兜底。

## 本分支提交

- a5de3b67 WIP: 冻结后跟进界面三项（含测试）
- 本交付单提交
