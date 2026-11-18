# 交付：luiluu/t194

- 车道／工作者：T194 D204 大型变身放大档位样张（cc）；交付单由总装合并时补写（车道未写）
- 状态：可合并

依据：D204 B；T188 交付单「需要用户决定」大型变身高度一条。

## 变更记录草稿

## 2026-11-18 【cc·天启篇·未经审查】T194 大型变身单独身高常量 BIG_FORM_H（默认 99，行为不变）＋五档样张（dev.待定）

- `modes/xiyou/battle/battle_layout.gd`：新 `XBattleLayout.BIG_FORM_H`（默认 99＝TARGET_H，行为不变）与 `BIG_FORM_KEYS`（RavenMythic、MiraDragon）；`fit_height` 加 `big_form` 参数，大型变身（米拉黑龙、渡鸦神话）按 BIG_FORM_H÷可见高算倍数；TARGET_H＝0 时不起作用（回 T174）。`battler_sprite.gd` 按外观键传入。
- 样张脚本 `tests/xiyou_big_form_sizes`（继承 xiyou_battle_actor_size）：BIG_FORM_H＝99／115／130／150／170 各出首领战、小怪战原尺寸截图，记录是否压队伍栏、叠队友、出屏（只记录不断言）。附图与 `样张记录.json` 在 `00_项目管理/归档/交付截图/luiluu_t194/`。
- Kyo 挑档（D206）后另开小卡改默认值；回退即保持 BIG_FORM_H＝TARGET_H（现默认）。
- 专项：xiyou_big_form_sizes 20/20、xiyou_battle_actor_size 160/160。
- 玩家可见：无（默认值不变）。

## 交接板

- 下一步：等 Kyo 挑 D206 档位。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 测试

- xiyou_big_form_sizes 20/20；xiyou_battle_actor_size 160/160（车道报）。
