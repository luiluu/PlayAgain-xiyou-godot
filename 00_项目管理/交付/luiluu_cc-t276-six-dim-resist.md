# 交付：luiluu/cc-t276-six-dim-resist

- 车道／工作者：T276 六维②韧性控制抗性（cc 车道，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·T276·未经审查】天启篇六维韧性控制抗性接入 state_rate（敌我共用、乘算不破免控）（dev.待定）

- `modes/xiyou/core/tianqi_six_dim.gd` 新增 `control_state_rate(b, id, logic)`：天启篇且 `ENABLED`、韧性不是 C、状态是控制（`XEnemy.boss_control_state`，不含死亡与霸体状态）时回 `(100 − 控制抗性) ／ 100`（E 110／100 … SSS 90／100），其余一律 1.0。
- `modes/xiyou/battle/battle_logic.gd` 只改 `state_rate` 一行（`func state_rate` 的 return）：原式「特性 × 天启词条异常抵抗」后再乘这一项。乘算，所以 `TRAIT_STATE_RATE＝0` 的免控仍是 0；四骑士 `blocks_state`、霸体、`TRAIT_STATE_RESIST`、`boss_add` 都在 add_state／效果 21 外层另拦，不受影响。异化 `forced_state` 早返回 1.0，不经这里。必中（hitType 0）的指定状态原版就不乘 state_rate，韧性同样不管。
- 关掉或西游档乘的是精确 1.0，state_rate 与原式逐位一致，随机数取数不变。
- 新专项 `tests/xiyou_tianqi_six_dim_resist`（69 条）：韧性全用测试里自设的档（T280 在重算全员分数），我方 S／C／E 三档、敌方 8 档乘数逐位相等，并用固定掷数在效果 21 真路径上测命中门槛（几率正下方中、正上方不中）；四骑士四条线、霸体首领、`TRAIT_STATE_RESIST`、`TRAIT_STATE_RATE＝0` 在韧性 E、掷 0 下都附不上；中毒、出血、削弱防御、灼伤 I、敏捷降低（残废）、死亡与霸体状态乘数 1.0（控制用「眩晕」）；满烙印韧性 E 开关开／关发作几率、发作回合、发作花样与取数一致；开关关、西游档逐位一致。反向验证：去掉 battle_logic 那一乘，8 条失败。
- 玩家可见：天启篇中，角色与敌人的「韧性」现已影响受控几率：韧性越高越难被眩晕、沉默、混乱等控制，韧性越低越易中招（幅度在 ±10% 以内，免控单位仍保持免疫）；原版西游存档无变化。（小A 定稿）

## 验证

- 专项 `xiyou_tianqi_six_dim_resist` 69/69；选测 32 个场景全过（含 xiyou_determinism、xiyou_tianqi_six_dim、xiyou_tianqi_affix_battle、xiyou_tianqi_brand、xiyou_tianqi_horsemen_battle、xiyou_tianqi_smart_ai、xiyou_smart_ai／_b／_c、xiyou_state_effects、xiyou_confusion、xiyou_stunned_turn、xiyou_xuan_battle、xiyou_yunshang、xiyou_tusu_battle、xiyou_boss_lifecycle、xiyou_boss_output、xiyou_liuying2、xiyou_tianqi_battle_seed、xiyou_tianqi_skills、xiyou_tianqi_alien_affix、xiyou_alien_battle、四骑士四条线、xiyou_cat_trial、xiyou_honghuang_curse_battle、xiyou_tianqi_qiyin_seq_kill、xiyou_combat、xiyou_battle）；语法检查通过。
- 没跑：选测.py 列出的其余约 290 个 battle 组场景（xiyou_rules_d* 等西游档）与 --oracle。西游档乘的是精确 1.0，逐位不变；按派单由总装合并时带 --oracle 跑。
- 附带影响（没改代码）：`battle/smart_ai.gd` 估算附加几率、`core/yunshang.gd` 的 `state_rate <= 0` 判断都调 `logic.state_rate`，天启篇里会看到韧性乘数；估算跟实际一致，`<= 0` 判断因乘算不变。

## 交接板

- 下一步：卡 3（敌方 AI）、卡 4／5（界面）照常；韧性数值随 T280 重算后的 six_dim.json 走，本单不用再改
- 用户试玩说明：天启篇控制命中按韧性有 ±10% 以内的乘算偏移（四骑士、霸体首领等免控单位照旧免控）
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：`XEnemy.boss_control_state` 每次调用都 `RegEx.create_from_string` 一次（原有写法）；本单已把它放在「韧性不是 C」之后才调，中性单位不多花。全库铺开后被控判定变多时可以按状态号缓存结果（预计收益小，归下一张碰 enemy.gd 的车道）。

## 本分支提交

- 见 git log
