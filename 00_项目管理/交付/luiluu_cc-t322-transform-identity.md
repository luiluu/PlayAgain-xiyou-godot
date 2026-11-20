# 交付：luiluu/cc-t322-transform-identity

- 车道／工作者：T322 守层者变身后继承守层者身份（T317 核查 P2×2＋P3×2）（cc，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·天启篇·未经审查】守层者残血变身后成长、牌组、首领、抗性仍按本层守层者；破阵分类道具不借同号技能（dev.待定）

- 依据：T317 小A Neon 核查回执（11-20）P2-1、P2-2、P3-1、P3-2；D246（变身后强度＝本层）。
- **变身身份**（`XGuardianRework.TRANSFORM_IDENTITY`，默认开）：T317 只让出伤、伤害抵抗、八项能力值按本层，变身后新敌人号（入魔 538、天道·魔神 929、天道·混沌至高 930）不在守层者表里，`floor_of` 归 0，于是：成长招削弱失效（强化 +12%/层跳回原版 +25%/层，带 3 层时能力值 +28.7%）、DECK 下 929／930 走 dungeon_boss 牌组、538 空牌组且 `is_boss_enemy` 为假、一刀切抗性不折算（0.5 不折回 1）。现在 `transform_before` 记下变身前的 `guardian_floor`，`transform_after` 在「变身前是守层者、新号不是守层者」时另记 `META_TRANSFORM`；新函数 `transform_floor` 读它（开关关、不是天启篇存档为 0），`guardian_floor`、`growth_on`、`XTianqiElements.enemy_profile` 第 4 档、`XTianqiElements.is_boss_enemy` 都认它。
  - 按核查方建议不改读 `META_FLOOR`：那个记号楼层小怪（`_world`）也有，读它会把同场小怪当守层者。楼层小怪（只有 `META_FLOOR`）变身不记身份，专项有反证。
  - `growth_on` 只认守层者敌人号和变身标记，不认心魔对齐（心魔的成长招已滤掉，别的强化照原版，跟 T315 一致）。
  - 变回守层者号时清掉标记（认敌人号）。
- **破阵分类先判 stypeId**（P3-2）：`XDamage.item_mode(item, skills_only)`，`XTianqiElements.pozhen_class`（乙，默认关）传 true：道具不查技能表（威德舍利 392、冰红茶 2892／2893 跟带 mode=magical 的技能同号，命中类型不是魔法），按命中类型分。**正式结算 `_calculate` 不传、照旧**：原版 `installDamageElementRuntime.js` defaultFrame `spec=data().skills[item.id]` 也不判是不是技能，改了就跟原版不一致。
- **头注释**（P3-1）：`guardian_rework.gd` 头注释的回退清单补后来各节的开关（DOMAIN_OFF、GROWTH_NERF、TRANSFORM_ANCHOR／TRANSFORM_IDENTITY、XINMO），写明「守层者的层」统一问 `guardian_floor`、`META_FLOOR` 只给出伤和伤害抵抗；T317 那节「记下变身前的层（META_FLOOR）」改成说清只管出伤、伤害抵抗。
- 回退：`XGuardianRework.TRANSFORM_IDENTITY = false`（＝T317：变身后成长、牌组、首领、抗性照新敌人号）。西游档不记标记，不受影响。
- 测试：专项 `tests/xiyou_tianqi_pozhen_type` 加第四节（77 → 130 项）。
- 玩家可见：天启篇 30～33 层守层者残血变身后不再因为成长强化突然变强，元素弱点、抗性照本层守层者那副。

## 变身前后能力值（专项实测，天启篇艰险，开局阵容；八项各上满 3 层强化后变身；[生命, 魔法, 物攻, 物防, 魔攻, 魔防, 敏捷, 幸运]）

| 层 | 变身 | 变身前＝变身后（本单） | 牌组／首领／抗性 0.5 折后 | 回退（TRANSFORM_IDENTITY 关）变身后 | 回退牌组／首领／抗性 |
|---|---|---|---|---|---|
| 30 | 玉皇大帝→入魔 538 | 8323200, 54400, 39508, 10098, 39508, 10098, 64328, 307700 | guardian/30、是、1.0 | 10710000, 70000, 50838, 12994, 50838, 12994, 82775, 395938 | 空、否、0.5 |
| 31 | 女娲→魔神 929 | 8939733, 54400, 161364, 10806, 161364, 10806, 243848, 1021700 | guardian/31、是、1.0 | 11503333, 70000, 207637, 13905, 207637, 13905, 313775, 1314688 | dungeon_boss、是、0.5 |
| 32 | 伏羲→魔神 929 | 9610667, 54400, 466004, 11512, 466004, 11512, 651848, 3061700 | guardian/32、是、1.0 | 12366667, 70000, 599638, 14813, 599638, 14813, 838775, 3939688 | dungeon_boss、是、0.5 |
| 33 | 鸿蒙老祖→混沌至高 930 | 10317867, 54400, 1798804, 12220, 1798804, 12220, 2827848, 20061700 | guardian/33、是、1.0 | 13276667, 70000, 2314638, 15724, 2314638, 15724, 3638775, 25814688 | dungeon_boss、是、0.5 |

回退那列＝变身前 × 1.75 ÷ 1.36（+28.7%），跟核查报告的数对得上。

## 交接板

- 下一步：无新增（T317 交接板条目照旧：T012-c 标回血率与血量后评乙）。
- 用户试玩说明：天启篇 30～33 层守层者残血变身后，强化层数带过去的加成不再变大，元素弱点照本层。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：`XZhenqi.is_boss_enemy`（MOG_BossHP 名单＋名字标记）和 `XTianqiElements.is_boss_enemy` 是两套首领判定，本单只改后者；538 在前者里是什么没查，归下次碰真气／异化的车道顺手统一（收益小）。

## 验证

- 专项 `xiyou_tianqi_pozhen_type` 130/130（本机，`--audio-driver Dummy` 由并行测试统一带）。
- 本机相关专项 11 个全过：`xiyou_tianqi_pozhen_type`、`xiyou_tianqi_guardian_growth`、`xiyou_tianqi_guardian_params`、`xiyou_tianqi_guardian_domain`、`xiyou_tianqi_xinmo_align`、`xiyou_tianqi_xinmo_traits`、`xiyou_tianqi_enemy_cev`、`xiyou_tianqi_elements`、`xiyou_transform_params`、`xiyou_tianqi_enemy_ai_scene`、`xiyou_state_effects`。
- 反向验证 8/8 咬住：变身不记身份、小怪也记身份、growth_on 不认变身、guardian_floor 不认变身（抗性）、牌组不认变身、首领不认变身、item_mode 不判 stypeId、正式结算也判 stypeId。
- `语法检查.py` 过；`工具回归.py` 过。
- 云端选测 ba65171cc2（基准 b3cc3716f0）370 个场景 16 片全过（run 44783944936）。
- 合并时：改了 `damage.gd`（只给 `item_mode` 加默认 false 的参数，正式结算不变）、`guardian_rework.gd`、`tianqi_elements.gd`；不碰原版移植的数值链，不需要 `--oracle`（我判断）。
- 待交叉核查的核心文件：`damage.gd`、`guardian_rework.gd`、`tianqi_elements.gd`。

## 本分支提交

- d1434f6ae 守层者变身后继承守层者身份；破阵分类先判 stypeId；头注释
- （合并提交）合本地 main 140181bd2（含 T318 心魔特点 a1，dev.809，GitHub 还没有）：无冲突；派单写「merge github/main」，github/main 跟分支起点一样，合本地 main 是为了总装合并不卡 guardian_rework.gd。
