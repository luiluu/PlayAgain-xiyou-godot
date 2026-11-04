# 交付：cc/bailong-visual2

- 车道／工作者：B 界面／白龙（cc）；基于 cc/bailong-visual1（8ab852ca），已合并 main
- 状态：可合并（任务一做完；任务二只核了「是否真缺」，见下）

## 变更记录草稿

## 2026-11-04 【cc·白龙·未经审查】visual2：敌人倒下改 MOG 粉碎效果（dev.待定）

**① 倒下粉碎**（`MOG_CollapseEffects` 默认死亡效果 0＝粉碎，方向 Left；新探针 `collapse_probe.cjs`→`oracle/collapse.json`，用真实 Sprite_Enemy＋插件量；新类 `battle/collapse_fx.gd`，`battler_sprite.collapse()` 改用它）
- 全库没有 `Collapse Effect`／`Collapse Animation` 备注（敌人、技能都没有），所有敌人都走这一条。
- 规则：碎块边长 floor((宽+高)/40)；每行 32 列，行起点 y＝−高＋边长，y≤0 的行满 32 列，第一条 y>0 的行只放 1 块；每块 sx∈[1,1.5)、op∈[2.5,4.5)，每帧 x −= sx（Left）、y −= sx、不透明度 −= op；最久 101～102 帧。
- 身体马上藏起来，碎块挂在身体上随缩放／镜像（SV 敌人镜像时向右上飘），神话敌人的色相材质沿用；随机只用自己的生成器，不动战斗随机数。
- 调用方等的仍是原来的 32 帧（战斗节奏不变），碎块自己继续飘；`effect_left` 改成碎块真实帧数（WAIT FOR EFFECT 等得到）。场景外观（kind scene）没有位图，仍走旧的红色淡出。
- 取图：碎块取位图左上角 (0,0) 起的格子（SV 多格图取第一格，同插件）。

## 交接板

- 下一步：任务二见下。无需用户决定。
- 用户试玩说明：打倒敌人时，敌人碎成小方块向左上飘散、逐块变透明（约 1.5 秒），不再是整只变红淡出。

## 任务二：进度核定零星项（先核是否真缺）

- **镜流图标**：不缺。6400～6403 已在 `core/quality_icons.gd` 的 `CUSTOM` 接上（dev.309 图标全接）；`yomi_jingliu.gd` 头注释过时，已改。剩「隐藏呼吸技能分类」未做（原版是分类入口，非画面）。
- **渡鸦特效**：不缺。R.Fx（ring／slash／harvest／echo）和六技能施放特效早已移植（`battle/raven_fx.gd`，dev.255、307）；`raven.gd` 头注释过时，已改。
- **渡鸦魔法反射支**：真有差异，但**没改**。读原版：反射时 YEP 把同一个 Game_Action 再 apply 到出手者自己，渡鸦的 apply 包装照样记帧；重制反射分支（`battle_logic._invoke`）不调 `XRaven.applied`。我用 raven_battle_probe 的写法量了一例（目标 itemMrf 强设 1，渡鸦五阶 60 级神话＋狩猎，施放 10122）：原版只出现一条打渡鸦自己的 hit（46588756），没出现追加的直接扣血，鸦啄回 MP 也没单独量清；与重制现状（不记帧，log 同样只有 hit）表面一致。另外渡鸦技能在数据里写「必中」，重制 `certain_hit` 为真时根本不会被反射，实际能否走到这条支没核清。结论：先不动 battle_logic，建议派一条小任务把「必中判定＋反射」在原版量全（含鸦啄回 MP、是否追加伤害）再决定。
- **饿狼 critical 0 伤**：没做。原版 `applyCritical(v)` 在 v===0 时返回 0；重制暴击是 `damage.gd` 里的乘区（基伤 0 乘暴击仍为 0，加上固定减伤也不会出正数），按你的约束不动 `damage.gd`，我没找到能让 0 伤变成非 0 的路径，暂判无可见差异，未量原版。

## 进度账 / 可优化

- 无；无。

## 待交叉核查

- 新类 `battle/collapse_fx.gd`；改了 `battler_sprite.gd`（collapse／appear／revive_visual）；新探针 `collapse_probe.cjs`（已登记 `同步正式西游.py`、`oracle_additions.py`）；注释改了 `raven.gd`、`yomi_jingliu.gd`。未碰 battle_logic／damage。

## 验证

- 新专项 `xiyou_collapse_fx`（55）通过：网格与真实插件逐尺寸对（5 种尺寸：块数、边长、首末块取图框、每行块数、起点），节点帧数 ≤102、方向、镜像、复活清理。
- 通过：xiyou_battle_events、xiyou_sve_visual、xiyou_svpngfd、xiyou_vsfx、xiyou_battle_log、xiyou_sequence_visual、xiyou_appearance、xiyou_actor_looks、xiyou_cat。
- `语法检查.py` 通过；`同步正式西游.py --accept-additions` 退出 0。
- 反向验证没跑（新断言未单独确认咬得住）。
- 选测 43 个场景（`选测.py main --list`，含战斗核心类、raven／jingliu／yomi 等）本地全跑，全部通过（未超 40 的云端线，本机跑完约 10 分钟）。

## 未做

- 没有实机截图对照（无头环境截不了战斗画面），规则由真实插件量值＋逐尺寸断言守住。
- 任务二的渡鸦反射支、饿狼 0 伤见上。
