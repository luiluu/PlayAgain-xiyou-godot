# 交付：cc/tianqi-rewards

- 车道／工作者：天启篇·己 奖励／cc（Mac 本机，项目线程「完成再刷西游Godot引擎重制」里的己车道）
- 状态：可合并（排在下面「合并顺序」之后）

## 合并顺序（重要）

本分支的底是四个还没进 main 的分支合起来的（分支里带着这几次合并提交）：

1. `claude/project-thread-bjkwzm`（饥荒线，内含战争线、四骑士、31～36 层重做）：**已合 main（dev.475）**
2. `claude/project-thread-yzaqle`（PR #30，装备栏第二批）
3. `claude/project-thread-rp542v`（PR #31，词条文字，内含 PR #26 fxqj11）
4. 本分支

要求：先合 #30、#31，最后合本分支（`交付自检.py` 对 main 53879fc21 试合并无冲突）。合并 #30、#31 时 `03_转换工具/天启篇数据校验.py` 两边都在 `CHECKS` 末尾加一项、都在文件尾加一段，会冲突：两边都留（本分支 fcb004361、3369fec2b 是现成的解法，可以照抄）。

**死亡线 `38nism`、瘟疫线 `o0m34i` 和饥荒线底子冲突很大（tianqi_line、tianqi_horsemen、tianqi_summit、battle_logic 等 7 个文件），本分支没合它们。** 这两条线合进 main 后，要补两处挂钩（见下「未做」第 1 条），派给死亡／瘟疫线车道或本车道续做。

## 变更记录草稿

## 2026-11-12 【cc·己·未经审查】天启篇奖励：净印装备、骑士遗物、终焉异化核、生存战额外奖励、骑士徽记（dev.待定）

- 依据：设计仓库《天启篇_四线剧情与关卡设计稿 v0.4》第 6、7 节（Kyo 11-11 09:41 第 8 节全定：奖励方向定、数值阶段再定；跨存档选乙）、《四线异化与异化装备重构 v0.8》第 4.1、4.2 节、车道戊口径（35 层影子掉半强度遗物、通关后再挑战＝终焉试炼、骑士徽记只做外观）。
- 新数据表 `modes/xiyou/tianqi_data/rewards.json`（`draft: true`，数字都是测试参数，避开 4）；新模块 `modes/xiyou/core/tianqi_rewards.gd`（`XTianqiRewards`）。全部只在天启篇存档生效（`XTianqiLine.open_for`：发行构建里还要 `XTianqi.RELEASE_OPEN`），开关 `XTianqiRewards.ENABLED`。
- **奖励装备**＝普通装备实例多一个 `tq_reward` 字段 {kind, line, tier, half}：借底子那件的图标和栏位（净印借 151 塑料吊坠＝项链；遗物借 4537 禁锢之皇冕＝类型 17），属性、特性、词缀、备注、价格清空，名字和说明换成奖励的。不改原版数据库，存档照装备实例存。`XTianqiGear.allows` 让神器栏收带标记的遗物（不进原神武白名单）。
- **净印装备**（项链，每线三档）：天外裂打完（输赢都给）第一档；10、20、30 层使徒打赢各一件（cc 读法：10 层二档、20 层三档、30 层再一件三档给第二个人穿）。只对本档走的线生效（30 层前换线：旧线的净印留着不生效）。
  - 存粮（饥荒）：饥饿让技能消耗变多、回复变少的幅度减轻 10／15／20%，按穿的人算（`XTianqiFamineAlien.cost`、`hp_cost`、`gain`、`regen` 四处）。
  - 止戈（战争）：敌方火花每次增加有 11／22／33% 几率不加，上场的人里取最好一件（战争线异化 `after_action`、骑士本体每次行动 +火花那行）。
  - 清心（瘟疫）：病弱每个减益 3% → 2／2／1%（骑士本体 `actor_param` 那行）。
  - 长明（死亡）：被挂死期时 11／22／33% 几率改成损失一半当前生命，终焉无效（骑士本体、影子不算，开场生存战算；`_death_turn_start`）。
- **骑士遗物**（神器栏）：35 层影子第一次赢给半强度版（名字带「（残）」），36 层第一次赢骑士给完整版。效果（`battle_logic` 新挂 6 处：setup、end_battle、executeHpDamage、itemCri、行动之后、makeTargets；`actor.gd` param 链在四骑士外面一层）：
  - 替身的钥匙串：每回合第一次放技能（不是普攻、防御、道具）后追加一次普攻（完整 100%、半强度 50% 几率）；暴击率 ×0（半强度 ×0.5）。
  - 最后一枚雷火弹：每次行动攒 1 点，满 10 点对敌全体轰炸（普攻伤害 ×1.5，半强度 ×0.75）；受伤 +15%（半强度 +8%）。
  - 没写完的卷子：技能击倒敌人攒资历，每 10 层全属性 +3%（半强度 +1.5%），最多 30 层；受到的回复 −33%（半强度 −16%）。
  - 混子之盾（碎）：第 1 回合敌人只打你（嘲讽）；物防、魔防 +33%（半强度 +16%）；自己出伤 −22%（半强度 −11%）。
- **终焉词条**：骑士（36 层）、35 层影子、34 层鸿钧每赢一场掉 1 颗本线终焉级「异化核」（本线 4 条里随机），含大厅再挑战（终焉试炼，只给核不给遗物）。核记在 `flags.tianqi.rewards.cores` [{line, affix, level: zhongyan, from}]；12 条老词条用 alienation.json 的原键（血铠 hollow、救赎 prayer…），4 条新词条用新键（临终 dying、再动 again、节俭 thrift、带毒 venom）。
- **生存战额外奖励**：天外裂撑过 6 回合（只一次）：异化石 ×3、5000 金钱（设计稿只写「额外奖励」，内容是 cc 定的测试参数）。
- **骑士徽记**：36 层第一次赢本线骑士点亮，记全局配置 `codexTianqiBadges`（`XConfig.tianqi_badges／tianqi_badge_mark`，跨存档只带外观）；选线画面的剪影点亮归画面（庚）读。
- 发奖时在对话框里说「得到了 …」。发奖进度 `flags.tianqi.rewards.got`，同一来源只发一次。
- 新专项 `xiyou_tianqi_rewards`（78 项）；`03_转换工具/天启篇数据校验.py` 加 rewards 检查；反向验证清单 `04_验证/反向验证清单/xiyou_tianqi_rewards.json`（9 处全咬住）。
- 玩家可见：天启篇存档（发行版要 RELEASE_OPEN）打完开场、使徒、35／36 层后背包里多出净印项链、骑士遗物，34～36 层每赢一场得一颗终焉异化核（暂时只记在存档里，看不到、用不了，见「未做」）。

## 未做（交接）

1. **死亡线、瘟疫线的异化怪**：`tianqi_death_alien.gd`、`tianqi_plague_alien.gd` 不在本分支。合进来后补两处：死亡线异化怪挂死期的地方调 `XTianqiRewards.doom_spared(logic, a, false)`（返回 true 就不挂、已扣一半血）；瘟疫线病弱每减益的比例过 `XTianqiRewards.frail_per(a, per)`。骑士本体战已经接了。
2. **异化核的用法**：取核、刻印、终焉级数值、核的界面是异化装备那一步（v0.8 第 4.1 节），本车道只发核、存存档。31～33 层旧守层者等终焉异化做好后把敌群号填进 `rewards.json` 的 `finale.boss_troops` 就会掉核（挂钩已在地图战斗收尾）。
3. 钥匙串的「独有技能」先按「不是普攻、防御、道具的技能」算；追加普攻不掷命中（照骑士战的直接结算 `horseman_strike`）。雷火弹轰炸同样。设计稿要改成只认角色专属技能的话再定口径。
4. 骑士的专属坐骑（设计稿：等骑士能入队时一起出）不在本批。

## 交接板

- 下一步：死亡、瘟疫线合进 main 后补净印挂钩（未做 1）；异化装备车道接异化核的刻印（未做 2）；庚（画面）读 `XTianqiRewards.badges()` 点亮选线剪影。
- 用户试玩说明：天启篇新开一局 → 选饥荒或战争线 → 打完开场三节，背包项链栏多一件「净印·…（一）」；穿上进饥荒线异化战，技能消耗比不穿时少一点。35、36 层赢了背包多遗物，装到神器栏。
- 需要用户决定（按测试参数继续，不停工）：
  1. 净印四个来源对三档：cc 读成「开场一档、10 层二档、20／30 层各一件三档」，要不要改。
  2. 生存战额外奖励：现在是异化石 ×3＋5000 金钱，设计稿没写内容。
  3. 遗物半强度＝收益和代价都约减半（数见上），要不要只减收益。
  4. 钥匙串「独有技能」怎么算（未做 3）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·天启篇奖励 | `modes/xiyou/core/tianqi_rewards.gd` `XTianqiRewards.ENABLED` | 原版没有净印、骑士遗物、终焉异化核、生存战奖励、骑士徽记 | 天启篇存档按 rewards.json 发奖并生效 | 四线剧情与关卡设计稿 v0.4 第 6 节（Kyo 11-11 定方向） | `XTianqiRewards.ENABLED = false`（不发奖，已有的奖励装备不生效） | cc（己） | 已接受（Kyo 11-11 优化直接接受） |

## 进度账

- 无（天启篇改版，不计重制完成度）

## 可优化（流程／工具／效率）

- `选测对照.json` 还没有天启篇四线／奖励的分组：改 `tianqi_*.gd`、`tianqi_data/*.json` 时选测落不到这些专项。建议加一组 `tianqi_lines`：`modes/xiyou/core/tianqi_*.gd`、`tianqi_data/*` → `xiyou_tianqi_*.tscn`（本车道没改共用文件，交总装）。
- 四条线各自的分支互相冲突（死亡、瘟疫线都从饥荒线分出、又各改了共用的 tianqi_line／horsemen／summit），后面的车道没法在一个底上干活。建议总装先把四线合成一个集成分支（或先合 main），奖励、画面这类跨线车道再基于它。

## 验证

- `语法检查.py`：728 个 .gd 0 个问题。
- 专项（Mac，本 worktree，`并行测试.py --full`）：`xiyou_tianqi_rewards` 78／78；天启篇全部 17 个专项（affix_table、affix_text、balance、famine、gear、gear2、horsemen、horsemen_battle、numbers、opening、party、summit、swap_init、title、title_flow、war、rewards）＋`xiyou_equipment` 1254／1254、`xiyou_script` 40／40 全过。`xiyou_tianqi_party` 第一次 `helper_full_exp` 挂了一次，单跑两次都过（偶发，和本分支无关：那段在发经验，本分支没碰经验）。
- 反向验证 `xiyou_tianqi_rewards.json` 9 处全咬住。
- `天启篇数据校验.py` 全部通过（含新 rewards 检查）。
- **没跑**：整轮 `检查.sh`（本分支底子是四个没合的分支，整轮请在合并后由总装按影响面选测）。改了 `battle_logic.gd`、`actor.gd`、`map_scene.gd`、`xconfig.gd`，原版档只多几个 `has_meta`／开关判断，理论上原版对照不变；建议选测加 `xiyou_battle*`、`xiyou_determinism`、`xiyou_event_compare*`、`xiyou_map*` 一组。

## 待交叉核查

- 甲档（战斗核心、存档）：
  - `modes/xiyou/battle/battle_logic.gd`：setup、end_battle、`_execute_hp_damage_ledger`、`item_cri`、`act` 末尾（`started` 时）、`make_targets` 各一行。
  - `modes/xiyou/core/actor.gd`：param 链在 `XTianqiHorsemen.actor_param` 外面加 `XTianqiRewards.actor_param`。
  - `modes/xiyou/core/tianqi_rewards.gd`（全文）；奖励装备实例的存档字段 `tq_reward`、`flags.tianqi.rewards`。
- 乙档：`core/tianqi_famine_alien.gd`（4 处）、`core/tianqi_war_alien.gd`（1 处）、`core/tianqi_horsemen.gd`（3 处）、`core/tianqi_line.gd`（4 处）、`core/tianqi_summit.gd`（2 处）、`core/tianqi_gear.gd`（1 处）、`map/map_scene.gd`（start_battle 末尾）、`core/xconfig.gd`（徽记）、`tianqi_data/rewards.json`、`tests/xiyou_tianqi_rewards.gd`。
- 丙档：`03_转换工具/天启篇数据校验.py`（rewards）、`04_验证/反向验证清单/xiyou_tianqi_rewards.json`。

## 本分支提交（除去底子的合并）

- 5e8407302／3369fec2b／fcb004361 合并 bjkwzm、#30、#31（两处数据校验冲突手解）
- a1fc45f1e 天启篇奖励：净印装备、骑士遗物、终焉异化核、生存战额外奖励、骑士徽记
- e12af3f4b 数据校验加 rewards、反向验证清单 9 处、卷子普攻用例补准
- （本交付单）
