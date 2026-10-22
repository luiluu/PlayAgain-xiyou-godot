# 交付：claude/qiyu-163

- 车道／工作者：A 内容·角色／悟空（Claude，悟空_36）
- 状态：可合并

## 变更记录草稿

## 2026-10-22 【Claude·悟空·未经Codex检验】163 琦玉专属模块并加回；154 夏娜、158 炮姐加回；167～178 专属模块预检（dev.待定）

- 做了什么：
  - **原版查清**：`installQiyuDimensionRuntime.js`（6 KB）大半是旧档迁移，新游戏里真正生效的只有两条：① 163 用**技能**（DataManager.isSkill，物品不算）时 itemHit＝1、itemEva／itemCnt／itemMrf＝0，即必中、不被反击、不被魔法反射；② `Game_Actor.addState` 挡掉 163 的 2626（数据里没有任何东西加 2626，只防旧档）。法宝 124「一拳」的 normalizeRelic 对新生成实例实测是空操作（数据库原件已是新数值，只打修订标记）；读档迁移 Q.sync（去 10264、学 10169）按「不迁移 MV 旧存档」不移植。伤害结算 ×0.001 原本就在 XImportedBalance。
  - **参照**：新探针 `03_转换工具/mv_oracle/qiyu_probe.cjs`（44 例，产物 `qiyu.json`，已登记同步探针表与只增接受键）：163／164（对照）／162（50 级起有全局必中被动）× 普攻 1、9934、9938、9939 与测试物理物品，对无状态与带闪避／反击／反射测试状态的敌人量四个比率；真实 BattleManager 行动打反射／反击敌人；2626；新生成的法宝 124 实例与装给 163（30 级）后法宝 1／5 级的能力值。
  - **实现**：新增 `core/qiyu.gd`（XQiyu）。挂钩两处：`battle_logic.gd` 的 `certain_hit()` 加一行 `if XQiyu.certain_skill(u, skill): return true`（唐僧同意；`item_hit` 与 `_invoke` 的反射／反击都读它，别处没动，合并时请与沙僧 state-effects-2 对照这一处）；`actor.gd` 的 `add_state` 开头挡 2626。
  - **测试**：新 `xiyou_qiyu` 231 项；把挂钩临时关掉时 5 项失败（163 普攻被反射、9934 被反击、命中 0.3），证明测得出。
  - **加回**：163 琦玉（CE2523）、154 夏娜（CE2514）、158 炮姐（CE2518，八戒 attack-element 已修空手普攻属性）加回切片 `actors` 与 `xiyou_actor_p0` RECRUIT_7。
  - **帮助卡**：163 学的 10169「欢迎来到异次元」在 characterHelpTarget 段（10122～10299），原版 characterHelpView 对技能去掉与描述相同的行，Godot 多显示了一行「被动／效果…」；`help_card.gd` 把 10169 与 10264 一样按普通视图显示并去掉描述行。
  - **二期（只出文档）**：[167～178 专属模块只读预检表](../协助预检_专属模块167-178_20261022.md)：各人模块文件与大小、挂点数与落在哪些 Godot 文件、公式调模块条数、招募入口、建议顺序与分期（建议先 178 哈基米，再 168 米拉→167 渡鸦，174 云裳最后）。
- 验证（车道不跑全量，只跑相关专项）：第一轮只加 163 时在工作树跑 `同步正式西游.py --accept-additions`（只增用例，新跑 slice 六段、actor_passive、help、power、wtype、custom_params、formula_program／equipment 与 qiyu，已接受）；合 main（attack-element dev.123、codex/state-effects-2）并加回 154／158 后 `新建工作树.sh --补齐`、再同步一轮（只增用例、已接受），最后再合一次 main 后同步测量不变、核对 0 问题、留指纹。`内容覆盖检查.py` 无新增、无消解，基线未改。专项（最终合 main 后）全过、无偶发：`xiyou_rules` 12 段（每段 126255～126328 项）、`xiyou_actor_p0` 3190、`xiyou_wtype` 15658、`xiyou_attack_element` 66、`xiyou_qiyu` 231、`xiyou_imported_balance` 273、`xiyou_help_card` 965、`xiyou_power` 137、`xiyou_state_effects` 60、`xiyou_combat` 34、`xiyou_magic_weapon` 43。
- 未完成／已知问题：
  - 物品（非技能）由 163 使用时照常算命中／反击／反射，与原版一致（参照 rates.a163.item*）。
  - 帮助卡 10122～10299 段其余技能的角色专用说明仍未做（原样显示），本次只放行 10169。

## 交接板

- 下一步：0d 条「导入角色剩余」改为：163 琦玉（XQiyu）、154 夏娜、158 炮姐已加回，导入角色 141～166 除禁用 5 人外全部接入；成就徽章只剩名牌渐变。167～178 专属模块按[预检表](../协助预检_专属模块167-178_20261022.md)排期。
- 用户试玩说明：琦玉可以招募，他的技能必中、不会被反击或魔法反射（物品照常）；夏娜、炮姐可以招募。
- 需要用户决定：无

## 进度账

- 角色：导入角色再加 3 人（163、154、158），粗估 +0.1 点，交沙僧复核

## 本分支提交

- 08a95bc 琦玉 163 专属模块：XQiyu、qiyu_probe 参照 44 例、xiyou_qiyu 231 项
- 9fff1f4 163 琦玉加回切片与招募表
- c77cd43 二期：167～178 专属模块只读预检表
- c7a6d2a 帮助卡：10169 去掉与描述相同的行
- e9da75c 合并 main（attack-element 已合）
- 3ccf4fb 154／158 加回切片与招募表
- 22c42db 交付单草稿；e54d6be 再合 main
