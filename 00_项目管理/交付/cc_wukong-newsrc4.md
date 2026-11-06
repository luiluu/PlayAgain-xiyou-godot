# 交付：cc/wukong-newsrc4

- 车道／工作者：CQ C 规则·装备说明卡＋难度真气玄 Boss（cc，悟空）
- 状态：第一批交付，合回集成分支 `cc/newsrc-switch`（**不标可合并**，不进 main）
- 基线：从 `cc/newsrc-switch`（cc69f998，已含 newsrc3）切出，11-06 合过一次 31d0628a（含 rules growth 乘区）。本树 `冻结正式源/app.nw` 指向 v0.62.12，产物是新源同步的克隆；跑测试和探针都要 `XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`（转换器默认路径写死了主工作区的 v0.28，不设会把产物转回旧源）。

## 变更记录草稿

## 2026-11-06 【cc·悟空·未经审查】换源集成：装备说明卡＋难度真气玄 Boss 第一批追平 v0.62.12（dev.待定）

- 22 个场景里 10 个在新源上追平：物品使用、法宝等级、玄战斗、装备公式、公式其余、装备准入、挑战被动、难度敌人、难度敌群、渡鸦法宝。
- 夹具在新源上重出（猫帮助、难度传承、公式其余、法宝成长帮助、法宝等级、玄战斗、敌人读装备公式、装备准入）；后两份原来没留探针，补了 `formula_equipment_enemy_probe.cjs`、`equipment_admission_probe.cjs`（旧夹具的 24／4 例逐条复现，再出新源的 27／4 例）。
- 数量随新源：可用物品 1029→1037、读装备等级的公式 24→27 个技能（336→378 例）、公式其余 31→34 个技能（135→147 例）。
- 难度敌人／敌群第 6 项比 `cnt`：探针读的是 v0.35 起夹到 0～1 的 `cnt`，测试原来比没夹的 `xparam(6)`。
- 挑战被动：新源参照开战读数已含状态特性，不再补加（`ADD_STATE_TRAITS` 开关留着回旧源）。
- 渡鸦专属法宝跟 v0.29 生命／魔法对调：固定 100／350，另加那份从生命改到魔法（`XRaven.artifact_mp_bonus`）。

## 交接板

- 下一步：见下「分类表」二、三类；新增机制等协调者／Kyo 定了再做。
- 用户试玩说明：无（集成分支，不进正式版）。
- 需要用户决定：深渊异化 v0.58 全部隐藏跟不跟（见二类）。

## 进度账

- 无变化（集成分支追平，不动完成度）。

## 分类表（22 个）

### 一、换号／数值：已追平（10）

| 场景 | 原因 | 做法 |
|---|---|---|
| item_use | 新源可用物品 1037 件 | 改数 |
| magic_weapon_level | 新源多 1 件法宝，旧夹具 221 | 重出夹具 |
| xuan_battle | 夹具来源＋净化次数新值 | 重出夹具 |
| formula_equipment | 24→27 个技能；敌人夹具来源 | 改数、补探针重出 |
| formula_rest | 31／135→34／147 | 重出夹具、改数 |
| equipment_admission | 夹具来源 | 补探针重出（4 例与旧夹具相同） |
| challenge_passives | 新源参照已含状态特性 | 测试不再补加（开关） |
| difficulty_enemy、difficulty_troop | 测试比的是没夹的 xparam(6) | 第 6 项比 cnt |
| raven_artifact | v0.29 法宝生命／魔法对调 | 改 `raven.gd` |

### 二、新源新增机制（先报计划，未做）

| 机制 | 场景 | 新源出处 | 计划 | 归属 |
|---|---|---|---|---|
| 强弱分类统一读角色备注 `<KyoTier:超强者／强者>`（v0.44 `installTierTagsV044`） | difficulty_inherit、_battle、_load（各 200 条差，如 t2461 该给 5969 给了 5968）、weak_challenge `classify` | `CodexTier.nonWeakIds()` 取代公共事件 1345、1443～1445 里的写死名单；`installNativeDifficultyInheritanceRuntime` 的 `strong()` 改成 `CodexTier.isNonWeak`，167 号以后按有无标签判 | 新 `XTier`（读 Actors 备注，约 30 行），`xstate.gd` 难度传承的 `_difficulty_strong` 与 `DIFFICULTY_NEW_STRONG` 换成它；`weak_challenge.gd` 名单同改；事件里 `CodexTier.nonWeakIds()` 的脚本翻译归 A（八戒）。一处改完 4 个场景 | C（我可接） |
| 深渊异化全部隐藏（v0.58 `installAlienationHide`） | alien_battle（103 条：遭遇不发、奖励不给）、alien_affix（4 条 sethp，疑同因） | 关遭遇与奖励、菜单去工坊、6 件物品不可得、读档把异化实例恢复成普通装备（只跑一次） | 盘点期一第 171 行默认「跟，做开关，默认隐藏，代码不删」；**要 Kyo 定**。跟的话：`XAlienation.HIDDEN` 开关＋读档迁移，登记 O 号 | 等 Kyo |
| 说明卡新排版（`\lock[1]` 品质行 17 号字、品质后 4 像素空行、白字两列 `\col[50]`） | cat_help（34）、growth_help（13）、weak_challenge 说明行（4） | 帮助卡插件新版；O-205「白字排蓝字上」是其中一部分 | `ui/help_card.gd` 跟新版版式；同一改动会动所有说明卡，跟 B 的 help_card 场景一起做 | B（白龙） |
| 真气本命兵／神兵试炼可指定道法（v0.43、v0.45） | zhenqi_break（7）、zhenqi_daofa（13） | 灵根／本命兵领悟时可指定元素／武器类型、神兵幻境不发普通收益、闭关菜单多「神兵试炼」 | 先读 `installZhenqi*` 新旧差异出清单再报，估计是 `zhenqi.gd` 一批 | C（我可接） |

### 三、口径（要再查）

| 场景 | 现象 | 初判 |
|---|---|---|
| power（2） | 「命中／暴击与伤害乘区」差 3e-8～2.5e-5（总战力差 1） | 新源 `installCombatPowerRuntime` 穿透标签同键去重、全元素穿透展开；和 rules 的穿透口径同一片，等 rules 定了穿透再对 |
| equipment（13） | 随机前缀（如武器 56 抽到前缀 67）、升级与符文结果全不同 | v0.37 随机前后缀不再抽天外天专武词条、v0.62 神话词条概率随难度浮动（`installAffixDifficultyRate`）改了抽取池，随机流跟着错位；属新增机制，要读 `gear.gd` 词条池 |

## 可回退

- `xiyou_challenge_passives.gd` 的 `ADD_STATE_TRAITS`（回旧源时设 true）。其余是跟新源的必要改动，集成分支整体可弃。

## 待交叉核查

- `modes/xiyou/core/raven.gd`（法宝生命／魔法对调）、两个新探针、八份重出夹具、六个测试的改动。

## 验证

- 本机新源（`XIYOU_APP` 指 v0.62.12）跑上述 22 个场景：10 个过（见一类），其余 12 个照旧挂、原因见二、三类。
- 新探针与旧夹具逐条对：敌人读装备公式 24/24 相同、装备准入 4/4 相同。

## 可优化（流程／工具／效率）

- 建议（归工具车道）：`xiyou_export.py` 的 `DEFAULT_APP` 写死主工作区路径，车道工作树把 `冻结正式源/app.nw` 指到新源也没用，不传 `--app` 就转回旧源（本车道踩过一次，及时克隆回来了）。改成默认读本工作树的 `冻结正式源/app.nw`，或认 `XIYOU_APP`。
- 建议：没留探针的手工夹具（如这次两个）统一补探针，换源时才能一键重出。

## 本分支提交

- `git log cc/newsrc-switch..cc/wukong-newsrc4`
