# 交付单：cc/nezha-parammax1（哪吒_12，角色能力末尾夹值）

- 状态：可合并
- 执行者：cc（哪吒_12）；从 rollback3 末端 836fd916 切出，**须在 rollback3 之后合**。已合最新 main（9b82e1a6，无冲突；甚尔已在 main），补齐重跑过。
- 起因：八戒 toji2 报的。原版云裳的包装对所有角色最后夹一次 paramMax，重制没有这一层，专属模块乘完超过 99999999 时不夹。

## 原版怎么夹（量过）

- 位置：`js/codex/runtime/installNativeYunshangRuntime.js` 的 Game_Actor.param 包装，对**所有角色**（不只云裳）最后 `Math.round(Math.max(id===0?1:0, Math.min(this.paramMax(id), v)))`。它是 codex 模块表（modules.json）第 30 个，排在米拉 1、黄泉 8、甚尔 9、心钢 14、傲慢 16、宿傩 17、饿狼 18、导入平衡 19 之后，异化 32～35、种族 52 之前。所以专属模块乘出来的值在这里压回上限，异化和种族在它外面另算。
- 上限：普通角色 99999999（YEP_CoreEngine）；饿狼 173 的 paramMax 包装是 999999999999（dev.235 悟空做过）。其余角色没有单独的上限。
- 新探针 `03_转换工具/mv_oracle/param_max_probe.cjs` → `tests/fixtures/param_max_oracle.json`（拷进来，不接全量同步），5 个用例：
  - 甚尔 171 99 级学暴君 10205、各项加值 9e7：生命、物攻、速度被压回 99999999（暴君 ×(1+等级×0.1)，不夹的话约 9.8 亿）。
  - 同配置不学暴君（对照）、加值 1e5（远低于上限）。
  - 饿狼 加值 9e11：900000000001，上限 999999999999。
  - 角色 1 加值 2e8：全部 99999999。

## 改了什么

- `modes/xiyou/core/actor.gd` 只动一处：`param_before_alien`（第 664 行）把 `XActorModules.param(...)` 的结果先过 `final_clamp`，再交给 `XCat.param`；新加 `FINAL_CLAMP` 开关和 `final_clamp`（第 666～672 行）。`final_clamp` 用的是已有的 `param_max(i)`，所以饿狼上限和测试用的 `test_param_max` 都照旧生效。别的行没动。
  - 小猫剑圣的包装自己也夹到 param_max 并取整，放在它前面还是后面结果一样，所以夹值放在它前面。
  - 回退：`XActor.FINAL_CLAMP = false`，回到没有这一层。
- 新专项 `tests/xiyou_param_max.gd`／`.tscn`：5 个用例逐项对参照（八项能力＋上限），另核回退支：不夹时甚尔暴君的生命、物攻、速度都超过上限。

## 验证

- `语法检查.py` 通过（427 个 .gd）。
- 新专项 xiyou_param_max 12/12。
- 直接相关的专项全过：xiyou_battle_gaps 1023、xiyou_toji 71、xiyou_garou_progress 178、xiyou_sukuna_battle 700、xiyou_mira_battle 287、xiyou_yomi_battle 142、xiyou_cat 994、xiyou_alien_affix 2117、xiyou_power 137、xiyou_actor_modules 56、xiyou_actor_p0 3366、xiyou_imported_balance 273、xiyou_param_cache 61、xiyou_param_states 582、xiyou_race_battle 653、xiyou_raven_soul 97、xiyou_trait_stack 214、xiyou_transform_params 249。
- xiyou_rules 全段没跑：actor.gd 是核心，选测会很大，按派单留给合并时跑。

## 待交叉核查

- 改了核心文件 `actor.gd`（只有第 664～672 行）。八戒 toji3 可能也在改 actor.gd，合并时留意这几行。

## 变更记录草稿

## 2026-10-31 【cc·哪吒·未经审查】角色能力末尾夹值：补上云裳包装那一层（八戒 toji2 报，dev.待定）

- 原版 `installNativeYunshangRuntime` 对所有角色的能力最后夹一次 `[HP?1:0, paramMax]` 并取整，位置在专属模块（米拉、黄泉、甚尔、宿傩、饿狼、导入平衡）之后、异化与种族之前。重制缺这一层，甚尔暴君这类专属倍率乘过 99999999 后不夹。
- `XActor.param_before_alien` 在专属模块和小猫剑圣之间加 `final_clamp`；上限沿用 `param_max`（普通 99999999，饿狼 999999999999）。回退：`XActor.FINAL_CLAMP = false`。
- 新参照 `param_max_probe`（5 例），新专项 `xiyou_param_max`。

## 交接板

- 无。

## 可优化

- 无。

## 本分支提交

- 5bd4df24（WIP）、合并 main，以及本交付提交
