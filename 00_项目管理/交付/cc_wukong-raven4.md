# 交付：cc/wukong-raven4

- 车道／工作者：悟空（cc），渡鸦养成遗留第四期
- 基线：总装十派单，从 c4d21a62（battlelog3 末端）切出，合了 battlelog3 的交付单更正 70329789。battlelog3 进 main 后再按总装通知合一次 main。
- 状态：可合并

## 盘点

原版以 `js/codex/runtime/installNativeRavenRuntime.js` 为准（`js/plugins/Codex_Raven.js` 不在 plugins.js 里，没启用，数值不同，别再照它）。

| 项 | 原版（冻结 v0.28） | 本期 |
| --- | --- | --- |
| 法宝 4001 每级成长、上限 | `ARTIFACT_LEVEL_GROWTH` [35,12,0,20,45,20,45,12]、上限取 CP_MagicWeapon 参数 888，原型与独立法宝的 paramPlusPerLevel 都是它 | 重制本来就对（备注的 per Level 与 <Max Level: 888> 一致），探针 module 例核过 |
| 法宝装备加成 | `Game_Actor.paramPlus` 包装：装着 4001 加固定 [350,100,0,80,150,80,90,35]；魔攻另加 ⌊阶×50＋魂×(0.02＋阶×0.006)⌋；生命另加 ⌊阶×400＋魂×(0.04＋阶×0.008)⌋ | 做了：`XRaven.param_plus`（经 `XActorModules.param_plus`） |
| 全队掉率 | `R.teamDropRateFactor`：套装＋出战成员 passiveIRUP 连乘之后，出战成员里有渡鸦学了亡魂汲取 10129 再 +1；dropItemRate、人物状态页「全队掉率」、地图详情都用它 | 做了：`XMapTransfer.team_drop_factor`（怪物图鉴、地图详情、异化掉落用）加上 10129 |
| 战斗里的实际掉落 | 同上，Game_Enemy.dropItemRate × teamDropRateFactor | **没做，列出**：`battle_logic._roll_drops` 自己算（出战成员 passiveIRUP 取最大值、×(1＋v/100)×套装），没走 team_drop_factor，也没有 10129。是战斗核心掉落公式，要先用掉落探针确认原版战斗里真走哪条，建议派规则车道 |
| 残响 10132／狩猎 10133 计数、神话续期 | gainSoulFrom 里加残响、满 3 进狩猎，神话不到 5 回合 +1 | 重制已有（第三期 `on_enemy_death`），`xiyou_raven_battle` 覆盖 |
| 商店价格与限购 | 号角 2902 itemBuyPrice {188:10}、法宝 4001 variableBuyPrice {213:30}，两件 shopStockCountMax 1 | 重制已有：转换器从运行时记录导出了这些字段，`XShopStock`／`XItemMarks` 读 |
| 插件指令 RavenAdd／渡鸦加入 | pluginCommand 调 recruit | 不做：冻结数据里没有事件用到 |
| 熟练度上限（变量 8） | 运行时技能的 masteryMaxLevel | 不做：重制没有熟练度 |

## 变更记录草稿

## 2026-11-01 【cc·悟空·未经审查】渡鸦法宝冥河断罪镰的装备加成、亡魂汲取的全队掉率（dev.待定）

- `core/raven.gd` `param_plus`：装着 4001 时 paramPlus 加固定 [350,100,0,80,150,80,90,35]，魔攻与生命另按进阶与灵魂加（`artifact_mat_bonus`／`artifact_hp_bonus`）；`core/actor_modules.gd` 接进 paramPlus 包装。
- `core/map_transfer.gd` `team_drop_factor`：出战成员里有渡鸦学会亡魂汲取 10129 时全队掉率 +1（怪物图鉴、地图详情、异化掉落用）。
- 新探针 `mv_oracle/raven_artifact_probe.cjs`（登记进 `同步正式西游.py` PROBES，产物 raven_artifact.json）与专项 `tests/xiyou_raven_artifact`。
- 渡鸦注释的「未移植」改正（灵魂进度行、神话形态图、技能分类已做；商店价格已由转换器导出）。

## 验证

- 探针 `raven_artifact_probe.cjs` 9 例无错；`同步正式西游.py --accept-additions` 跑完「测量不变」（产物先手工放进了 generated/oracle，同步核过与沙盒一致），留了指纹。
- 选测（CHECK_JOBS=3）：`xiyou_raven_artifact`（新）、`xiyou_raven_battle`、`xiyou_raven_soul`、`xiyou_actor_p0`、`xiyou_actor_modules`、`xiyou_help_card`、`xiyou_transfer`、`xiyou_map132_shop`、`xiyou_battle_log`、`xiyou_jingliu2`、`xiyou_actor_looks`、`xiyou_enemy_book`、`xiyou_alien_battle` 13 场景全过（日志 `04_验证/本地结果/并行测试/20261101_064021_65r_zauf/`）；`RULES_ONLY_ACTORS=167` 下 `xiyou_rules*` 24 场景全过（`20261101_064422_3nh7azkh/`，part0 各 3783～3785 项）。无偶发。
- 反向：把 `XActorModules.param_plus` 里的 `XRaven.param_plus` 去掉，`xiyou_raven_artifact` 的 worn_plus／worn_param 全部失败（如 1 级只剩每级成长 [35,12,0,20,45,20,45,12]，参照 [385,112,0,100,195,100,135,47]），恢复后通过。亡魂汲取那行没单独反向跑：drop.l1 与 drop.l30 只差学没学 10129，参照差正好 1，去掉那行 l30 必失败。
- `语法检查.py` 通过。

## 交接板

- 下一步：战斗里实际掉落是否走全队掉率（含亡魂汲取 +100%），先用掉落探针确认，派规则车道；「渡鸦遗留」里的法宝成长与上限、商店价格、残响／狩猎计数、神话续期可以划掉，掉率图鉴改成「战斗实际掉落待核」。
- 用户试玩说明：渡鸦装上冥河断罪镰后，人物页的生命、魔攻等照原版多出固定加成，生命与魔攻还随进阶和灵魂数涨；渡鸦学会亡魂汲取并出战时，怪物图鉴与地图详情里的掉率翻一倍（加 100%）。
- 需要用户决定：无。

## 进度账

- 渡鸦养成遗留：法宝装备加成、图鉴掉率完成；战斗实际掉落待核；其余项确认已有或不适用。

## 可优化（流程／工具／效率）

- 已做（文档）：盘点表开头写明渡鸦以 installNativeRavenRuntime 为准。建议：在 `mv_oracle/README.md` 或角色模块注释里列一张「没启用的旧插件」名单（Codex_Raven.js 这类），免得下一个车道再读错文件；归哪条车道：哪吒（工具）。

## 本分支提交

- 70329789 交付单更正（从 battlelog3 合进来）
- WIP：渡鸦法宝 4001 装备加成
- WIP：全队掉率加亡魂汲取
- WIP：渡鸦注释更新
- 交付单（本提交）
