# 交付：claude/project-thread-z5fkq9

- 车道／工作者：养成·种族与异化战斗接线／云端（Claude，云端项目线程）；本机收尾 木吒（Claude）
- 状态：可合并

## 变更记录草稿

## 2026-10-25 【Claude·云端·未经Codex检验】怪物图鉴死亡钩子、种族祝福与异化接进战斗（dev.待定）

- **怪物图鉴死亡钩子**（原版 `PH_MonsterBook` 在 `Game_BattlerBase.die` 计击败）：`XBattler._add_state(1)` 与 `XResourceContext` 刷新时的阵亡分支都调 `XEnemyBook.note_death`；只认本场开战登记的敌人（`_battle_enemies`，按同一对象比较），伤害预演的克隆、战后、外来敌人都不计。去掉了战斗结束时补计阵亡的兜底（原版不在战斗结束时计）；复活后再阵亡照原版再计一次。专项 `xiyou_enemy_book` 59/59，参照 `enemy_book_defeat.json` 不变。
- **种族祝福接进战斗**（原版 `installRaceRuntime`，新模块 `modes/xiyou/core/race_battle.gd`／`XRaceBattle`）：
  - 能力值：人族八项×1.03、鬼族最大法力×(1＋q)、蛮族最大生命×(1＋q)（再按 Math.round）；灵族按武器本体值（扣宝珠镶嵌附加行）×q/2 给 paramPlus；鬼族技能 MP／TP 消耗 max(1, ceil(n(1−q/2)))。
  - 行动根（begin／activate／finish）：神族魔法加成与每回合首次魔法破防、妖族猎物（按预演伤害选、≤30% 再加成）、人族毒鸡汤（回合末结算）与 996 额外行动（插进行动顺序）、魔族物理加成与血契（付最大生命 3%）、鬼族残响（上一组与本组）、灵族匹配兵器、蛮族每回合首个敌方行动根的受伤上限与 ≥10% 反攻。
  - 伤害管线钩子 `race-blessings`（damage.before，order 41），伤害预演用 `raceProbe`，正式行动带 `raceAction`。
  - 生命损失经 `limit_loss`（蛮族上限）；TP 照原值。
  - 创建角色时（`XState.actor`）按原版补建种族存档项。
  - 参照探针 `mv_oracle/race_battle_probe.cjs`（31 例：七族×1／4／7 阶能力值与消耗、九场战斗逐步记录），同步脚本已登记；专项 `xiyou_race_battle` 436/436。
- **种族未移植（照原版有，后续再做）**：战力预览的种族修正（powerAdjust 等）、手动指定猎物、战斗指令里的血契开关、R.status 文字、敌人窗毒量信息、种族补给（bossReward）、learnSkill 改种族、旧式道具与商店；人族 996 追加行动的提示文字没发。
- **异化接进战斗**（原版 `installAlienationRuntime` 的战斗侧，新模块 `modes/xiyou/core/alien_battle.gd`／`XAlienBattle`）：
  - 遭遇（Game_Troop.setup 包装）：Boss 来源按敌人、地图、敌群（未知存在另看来源地图）匹配，几率 min(1%, Σ掉率×0.2)、按掉率加权选本体、随机变体；否则小怪来源（地图 29／30／32／33 的指定敌群）随机选一个非 Boss 敌人、1%、转换表等权选本体。命中即 `XAlienation.create` 出奖励装备（不进背包）。`alienation.json` 补 bossSources／mobSources／transition 与变体说明。
  - 敌人变体：最大生命 ×1.5（小怪 ×1.25）、名字【异化·X】／【异化】；烈变／小怪主动伤害 +15%／+10%；蜕壳开场 10% 护盾；蚀能偶数回合末吸 MP 回血；灾疫每回合首个伤害技能附加腐蚀 2652（每回合末 2% 最大生命、到期自然消失）；镜骸每回合第一次被角色主动打中时行动结束反噬 min(5% 扣血, 8% 最大生命)。
  - 开战冻结出战角色的异化装备（`XAlienation.for_actor` 战斗中读冻结的那份）；胜利且异化敌人倒下时发奖励、记最近掉落、提示。
  - 新存档字段 `XState.unknown_origin`（键 `unknownOrigin`，未知存在 Map152／176 的来源地图，`map_scene` 进图时记）。
  - 参照探针 `mv_oracle/alien_battle_probe.cjs`（19 例：遭遇 10 例、变体战斗 8 例、锁队），同步脚本已登记；专项 `xiyou_alien_battle` 330/330。
  - 未移植：异化词条效果（installAlienationAffixes／Advanced，下一批）、行动外的 gainHp／setHp（公式副作用）的增伤与镜骸记账、敌人偏色与特效画面、战斗中换装限制（工坊侧已有）。奖励词条随机走 `XAlienation.choose`（不是本场规则随机数）。
- **本机收尾（木吒）**：种族钩子进了标准注册表后，`xiyou_module_hooks` 默认宿主的 trace 多出 `race-blessings`（order 41，无祝福时 ops 为空）；原版对每次伤害都跑它的 build（参照 trace 有这一项），改了测试期望，1310/1310。删掉云端提交误带的 macOS 资源分叉文件 `modes/xiyou/._generated`、`冻结正式源/._app.nw`（它们让选测退成整轮）。
- **已知差异（不在本车道）**：宠物捕获时原版先 `die()` 再 `refresh()`，图鉴记 2 次；Godot `pet_capture.gd` 的 `_vanish` 只记 1 次。`pet_capture.gd` 属八戒宠物来源车道，未改，交给该车道对照。
- 验证（本机，2026-10-26，木吒；合并 main 至 91a2283f）：
  - 两个新探针单跑：`race_battle_probe` 31 例、`alien_battle_probe` 19 例，均无错误，产物放进 generated/oracle。
  - 交付单 37 个场景（含 main 新增 battle_common_events 共 38 个）`并行测试.py --jobs 4`：38/38 通过（xiyou_race_battle 436/436、xiyou_alien_battle 330/330、xiyou_enemy_book 59/59、xiyou_rules 难度 1 四段全过）。
  - `检查.sh --affected main`：选测判成整轮（`alienation.json`、`._` 文件拿不准，`xstate.gd` 本身就选 157 个），187 个场景 186 过，唯一失败 `xiyou_module_hooks`（cat.default_host_handlers，见上「本机收尾」），改期望后单跑 1310/1310；文档、登记、Python 工具回归全过。
  - 补跑：查出那次「整轮」其实只跑了 187/193（选测判整轮时仍把选中的场景传给 并行测试.py，见「可优化」已做的第 3 条），漏的 6 个（ui_smoke、xiyou_achievement_badge、xiyou_choice_window、xiyou_formulas、xiyou_gear_query_cache、xiyou_review_fixes）补跑全过，本分支整轮 193/193。
  - 合并 main（91a2283f，-3 测试提速）后：选测（同上 38 个＋module_hooks＋json_cache）40/40 通过（共用槽排队后实跑约 14 分钟）。

## 交接板

- 下一步：异化词条效果（installAlienationAffixes／Advanced，20 条）；种族与异化战斗的未移植项（见上）。
- 用户试玩说明：有种族祝福的角色在战斗中按种族生效（能力值、消耗、猎物、毒鸡汤、血契、回响、匹配兵器、蛮族受伤上限与反攻）；怪物图鉴的击败数在敌人倒下时就计；十三层等小怪图与无垠虚空等 Boss 图有约 1% 遇到异化敌人，打赢必得异化装备。
- 需要用户决定：无

## 进度账

- 养成与周边系统：25.8% → 待沙僧核算（建议种族战斗＋1.5 点、异化战斗与掉落＋1.5 点、图鉴死亡钩子＋0.5 点），依据：原版种族运行时与异化运行时战斗侧已逐例对照参照。

## 可优化（流程／工具／效率）

用户 2026-10-26 接受，已在本分支做（4db349f，`测试选测.py` 25/25，`检查.sh --affected b7ee1c9b` 通过）：
- `.gitignore` 加 `._*`（macOS AppleDouble 资源分叉文件，云端、exFAT 或网络盘提交会带进来）；`.gitignore` 改动在选测里归开发工具组。
- 选测对照新组 mode_data：`modes/xiyou/*.json` 手写数据（`generated/` 除外）跑直接引用它的测试，加上测试引用了「按文件名加载它的模块」class_name 的专项＋事件对照，找不到才整轮。`alienation.json` 由整轮降为 4 个场景。
- **顺带修的缺陷**：`选测.py --shell` 判成整轮时仍输出选中的场景表，`检查.sh` 把它原样传给 `并行测试.py`，「整轮」就只跑选中的那些。现在整轮时场景表置空。2026-10-26 前用 `--affected` 判成整轮的检查可能漏跑零星场景（本分支漏 6 个，已补跑）。

## 本分支提交

- f6ee0c6 怪物图鉴死亡钩子
- 58b3279 种族祝福能力值与战斗效果、参照探针与专项
- 5de2318 异化战斗侧、参照探针与专项
- a520f46 module_hooks 默认宿主期望补 race-blessings；删误提交的 ._ 文件（木吒）
- b7ee1c9 交付单验证结果（木吒）
- 4db349f 选测：手写数据按引用与加载模块选专项、整轮不给场景表；.gitignore 忽略 ._*（木吒）
