# 交付：luiluu/t511

- 车道／工作者：西游异化挂件美术／小o（gpt-6.2-sol＋high，P7）
- 状态：可合并

## 变更记录草稿

## 2026-11-27 【co·未经审查】T511 西游档异化挂件逐外观校准（dev.待定）

- 按 T504 清单的 404 条「需单独锚点」记录，合并共用外观后，在西游档真实敌群中查看 210 个外观键、共 246 个化形场景。先看神牛、深渊、守层者、首领和精英，再看普通怪与战中变身。每场由原有异化入口给目标上级，保留实际站位、相邻敌人和界面。
- 在 `content/monsters/rift/overrides.json` 新增 152 个外观覆盖，另调撼地神牛共用外观。按体形将根点落到肩背、躯干或甲壳，给遮脸、悬空的外观收紧前件或后件，给超边的后肢留出画内余量。工程差异仅此一份西游异化外观数据。
- 撼地神牛之影、撼地神牛的化形左肢从约裁 23、44 像素改为距左边界约 114、93 像素。用同一外观的魔王宠物、熔岩魔牛也复拍，最左端分别距边界约 38、9 像素。
- 在 1280×720 战斗画面中按后件贴图可见像素和实际屏幕变换量边界。修改前观察到 69 场后件越界，修改后同一批场景逐场复拍通过。32 张原尺寸前后对照，共 16 组，见下。
- 玩家可见：西游档的部分异化怪，骨刺和长肢更贴身体，撼地神牛和它的影子的化形长肢能完整显示。

## 交接板

- 下一步：请协调安排换家核查，随下一次西游修复补丁收录。
- 用户试玩说明：在西游档漩涡里看化形的撼地神牛之影、撼地神牛，留意身体左侧骨肢和眼睛。
- 需要用户决定：无。

## 进度账

- 西游档异化外观：T504 标「需」的 404 条记录，按战斗使用的 210 个外观键逐一查看；有覆盖变更的战斗场景复拍 182 场。

## 可优化（流程／工具／效率）

- 无。

## 动了的共用函数和开关

- 无。

## 实战复拍

- 246 场包含 237 个首领独站或有邻怪的常规样本、2 场指定神牛战、1 场同模熔岩魔牛和 6 场变身。变身样本在原敌群里走游戏事件使用的换怪和换图入口，覆盖智甚·怒目金刚、天道·魔神（女娲和伏羲两场）、天道·混沌至高、瑞丁真身。
- 逐场查看化形，妖精公主、风精灵侍从、古龙普拉顿与深渊噩梦之影额外抽看侵染、蚀骨。复拍核基准画布、原站位和待机画面；未逐帧量完每只怪的全部技能、飞行与镜头状态。
- 哈耳庇厄有原有高飞姿势会让本体出画，附加件复查记录仍采用实际战斗画面。本单也保留 T505 已定稿的三套参考外观作为原位对照。
- 截图中提高了测试队伍生命，保证停在可观察的战斗阶段。截图取自隔离测试状态，本机直接启动 Godot 时均带 `--audio-driver Dummy`。

## 原尺寸截图（1280×720）

| 批次 | 样本 | 调整前 | 调整后 |
| --- | --- | --- | --- |
| 神牛 | 撼地神牛之影 | `00_项目管理/交付截图/luiluu_t511/01_behemoth_shadow_before.png` | `00_项目管理/交付截图/luiluu_t511/01_behemoth_shadow_after.png` |
| 神牛 | 撼地神牛 | `00_项目管理/交付截图/luiluu_t511/01_behemoth_before.png` | `00_项目管理/交付截图/luiluu_t511/01_behemoth_after.png` |
| 神牛 | 魔王宠物 | `00_项目管理/交付截图/luiluu_t511/01_behemoth_pet_before.png` | `00_项目管理/交付截图/luiluu_t511/01_behemoth_pet_after.png` |
| 守层者 | 妖精公主 | `00_项目管理/交付截图/luiluu_t511/02_guard_fairy_before.png` | `00_项目管理/交付截图/luiluu_t511/02_guard_fairy_after.png` |
| 守层者敌群 | 驯龙伙伴 | `00_项目管理/交付截图/luiluu_t511/02_guard_mount_before.png` | `00_项目管理/交付截图/luiluu_t511/02_guard_mount_after.png` |
| 精英 | 风精灵侍从 | `00_项目管理/交付截图/luiluu_t511/03_elite_spirit_before.png` | `00_项目管理/交付截图/luiluu_t511/03_elite_spirit_after.png` |
| 精英 | 恶魔训犬 | `00_项目管理/交付截图/luiluu_t511/03_elite_hound_before.png` | `00_项目管理/交付截图/luiluu_t511/03_elite_hound_after.png` |
| 首领 | 捕猎者 | `00_项目管理/交付截图/luiluu_t511/04_boss_hunter_before.png` | `00_项目管理/交付截图/luiluu_t511/04_boss_hunter_after.png` |
| 首领 | 古龙普拉顿 | `00_项目管理/交付截图/luiluu_t511/04_boss_dragon_before.png` | `00_项目管理/交付截图/luiluu_t511/04_boss_dragon_after.png` |
| 首领 | 尼古拉斯熊一 | `00_项目管理/交付截图/luiluu_t511/04_boss_bear_before.png` | `00_项目管理/交付截图/luiluu_t511/04_boss_bear_after.png` |
| 深渊与外界 | 深渊噩梦之影 | `00_项目管理/交付截图/luiluu_t511/05_abyss_crocodile_before.png` | `00_项目管理/交付截图/luiluu_t511/05_abyss_crocodile_after.png` |
| 深渊与外界 | 阿尼耶古加之影 | `00_项目管理/交付截图/luiluu_t511/05_outer_spider_before.png` | `00_项目管理/交付截图/luiluu_t511/05_outer_spider_after.png` |
| 其他 | 祸乱之源 | `00_项目管理/交付截图/luiluu_t511/06_other_eye_before.png` | `00_项目管理/交付截图/luiluu_t511/06_other_eye_after.png` |
| 其他 | 哈耳庇厄 | `00_项目管理/交付截图/luiluu_t511/06_other_harpy_before.png` | `00_项目管理/交付截图/luiluu_t511/06_other_harpy_after.png` |
| 战中变身 | 智甚·怒目金刚 | `00_项目管理/交付截图/luiluu_t511/07_transform_monk_before.png` | `00_项目管理/交付截图/luiluu_t511/07_transform_monk_after.png` |
| 战中变身 | 天道·魔神 | `00_项目管理/交付截图/luiluu_t511/07_transform_demon_before.png` | `00_项目管理/交付截图/luiluu_t511/07_transform_demon_after.png` |

## 验证

- 本机 `xiyou_rift_alien_parts` 41/41，工具快速回归 24/24，`西游异化模板映射.py --check` 和 `发行空壳.py check` 通过。
- 自动选测对这份外观覆盖表回退到全量。按车道专项口径，最终数据提交 `e7202ae8c` 云端指定 6 个相关场景，全部通过（495/495 项断言）。[云端运行 45908183415](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45908183415)
- 最终云端明细：`xiyou_rift_alien_parts` 41/41、`xiyou_rift_alien` 150/150、`xiyou_battle_layout` 78/78、`xiyou_battle_pixel` 28/28、`xiyou_battle_ui` 182/182、`xiyou_battle_lag` 16/16。

## 本分支提交

- `fc1c8f937` 神牛左肢和两场首领战对照。
- `eecd7d865` 按外观键校准共用模板摆放。
- `6fb049301` 分批原尺寸截图。
- `e7202ae8c` 变身后外观与神牛同模最左站位复拍。
