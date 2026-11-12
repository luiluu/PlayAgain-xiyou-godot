# 交付：cc/tianqi-gear-affix-roll

- 车道／工作者：天启篇·普通装备掷天启篇词条、深渊商人两档货架、成就页不列宠物成就／cc（项目线程「完成再刷西游 Godot 引擎重制」）
- 状态：可合并

## 依赖与合并顺序

- 从 main（dev.499，词条战斗、宠物隐藏都已合）切出，不依赖待合的分支。

## 变更记录草稿

## 2026-11-12 【cc·天启篇·未经审查】天启篇装备掷天启篇词条、深渊商人寻宝／珍藏、成就页不列宠物成就（dev.待定）

- 按设计仓库《天启篇_词条重构设计稿 v0.3》第 3.2～3.6、7、8.2、11 节，接上词条战斗车道（cc/tianqi-affix-battle）交接板的「通用装备掉落掷词条」「深渊商人改卖指定传说词条」。只认天启篇存档（`XTianqiAffixBattle.on`）。
- 新模块 `core/tianqi_affix_roll.gd`（XTianqiAffixRoll，开关 `ENABLED`）：`XGear.roll_item` 末尾调 `apply`，天启篇存档里新生成的武器、防具（掉落、商店、事件、深渊商人都经这里）掷天启篇词条：槽数按品质（普通 0、优秀／精良 1、史诗／传说 2、不朽／神话 3）、阶按 `<req_level>`、栏位组只出对口的标签、项链先掷光环（二阶起 15%，占一槽）、每槽按难度掷层（不够格或到每件上限按表里的退路往下找）、按权重抽、成色先掷极 3% 再按品质掷上品。记在装备的 `tianqi_affixes`（`XTianqiAffixBattle` 已认），说明末尾加每条一行（原说明记在 `tianqi_desc_base`）。法宝（光环按养成分阶）、坐骑、神器栏不掷；七印装备、净印、遗物不掷。
- 原版随机词缀行在天启篇存档里不掷（几率合计不到 100 的行），必出的行照原版合进装备（`XGear.roll_item` 一行）。跳过的行不取预掷随机数，所以天启篇存档的装备随机流和原版对不上；原版档不受影响。
- 新模块 `core/tianqi_merchant.gd`（XTianqiMerchant，开关 `ENABLED`）＋价格表 `tianqi_data/abyss_shelves.json`（`draft`）：天启篇存档的深渊商人选分组后是两档——寻宝 10 点（本组能出特效的装备里挑一件，保证带一条特效词条）、珍藏 60 点（先指定一条传说词条，本体只出本路线三阶以上、不朽及以上、栏位能出这条的装备；连击、再动这两条稀有的 100 点）。沿用原版的战利品点、每轮 3 次、分组和本轮随机数。本路线没有够格装备时货架灰掉并写原因。界面在 `ui/merchant29_page.gd`（天启篇存档换成这两档和「指定传说词条」一页）。
- `XTianqiAffixRoll.ensure_affix`：保证一件带某条词条（同层到上限就换掉同层那条，有空槽就加，否则换掉一条基础词条），商人用。
- 宠物隐藏补一处（四线异化 v0.8 第 2.4 节「图鉴、成就等提到宠物的地方」）：成就页在天启篇存档里不列提到宠物的成就（61「神秘生物！」、104「宠物训练大师」，按名字、条件、说明里有宠物／捕捉／神秘生物／魔兽要诀判断），全局记录照旧（`ui/achievement_scene.gd` 一行、`XTianqiPetHide.filter_achievements`）。怪物图鉴、人物图鉴里没找到提到宠物的地方。
- 新专项 `tests/xiyou_tianqi_affix_roll`（31 项）；`xiyou_tianqi_pet_hide` 加两条（成就）。
- 玩家可见：开发版天启篇存档里新得到的装备带天启篇词条（说明里能看到「〔四阶·上品〕」这样的行），战斗里生效；深渊商人改成寻宝、珍藏两档；成就页不列宠物成就。发行版看不到（天启篇关着）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_affix_roll.gd` `XTianqiAffixRoll.ENABLED`；`core/gear.gd`（`roll_item` 两处） | 原版装备按 DreamX 词缀行随机掷词缀 | 天启篇存档的装备改掷天启篇词条（原版随机行不掷，必出行照留） | 词条重构设计稿 v0.3（Kyo 11-08、11-11 定） | `XTianqiAffixRoll.ENABLED = false`：天启篇存档也照原版掷词缀 | cc | 已接受（Kyo 11-11 优化直接接受） |
| O-待定 | `modes/xiyou/core/tianqi_merchant.gd` `XTianqiMerchant.ENABLED`；`ui/merchant29_page.gd`（天启篇货架） | 深渊商人三档（Mod／神话／混沌神话特效） | 天启篇存档改两档：寻宝（必带特效词条）、珍藏（指定传说词条） | 词条稿 v0.3 第 8.2 节（已定） | `XTianqiMerchant.ENABLED = false`：照原版三档 | cc | 已接受（Kyo 11-11 优化直接接受） |

## 交接板

- 下一步：法宝光环按养成分阶（词条稿第 7 节，法宝现在不掷）；重铸（以后重新设计）；装备本体属性量级标定（草稿第四节）。三处交叉（节俭和技能消耗共用上限、几处再动同时生效、血铠护盾按带生命词条后的最大生命）交给测算工具。
- 用户试玩说明：开发版天启篇档打几场拿装备，看装备说明末尾的天启篇词条行；进深渊路线领点遇到商人，选分组后有「寻宝」「珍藏」两档，珍藏里选一条传说词条；主菜单「成就」里没有「神秘生物！」「宠物训练大师」。
- 需要用户决定：无（价格 10／60／100 是设计稿草案）。

## 进度账

- 天启篇词条（扩展账）：掉落掷词条（通用装备）0 → 已接；深渊商人 0 → 两档货架已接；法宝光环分阶、重铸未做。不写主表。

## 可优化（流程／工具／效率）

- 建议：`天启篇数据校验.py` 加 `abyss_shelves.json`（数字避开 4、价格为正）；现在专项里没有查表（归工具车道）。

## 验证

- `xiyou_tianqi_affix_roll`：31/31；`xiyou_tianqi_pet_hide`：23/23。
- 相关专项（Mac，本工作树，`并行测试.py`，21 个场景，243 秒，全部通过）：`xiyou_tianqi_affix_roll`、`xiyou_tianqi_pet_hide`、`xiyou_achievement`、`xiyou_affix_rate`、`xiyou_cat`、`xiyou_demon_crown`、`xiyou_drop_record`、`xiyou_equipment`、`xiyou_gear_detail`、`xiyou_merchant29`、`xiyou_tianqi_affix_battle`、`xiyou_tianqi_gear`、`xiyou_tianqi_gear2`、`xiyou_tianqi_qiyin_equip`、`xiyou_tianqi_alien_gear`、`xiyou_tianqi_rewards`、`xiyou_tianqi_party`、`xiyou_yunshang_shop`、`xiyou_battle_drop`、`xiyou_determinism`、`xiyou_event_compare`（之后补的三条断言只改了本专项，单跑过）。
- 没跑的：`gear.gd` 让选测判出较多场景；本单在 `roll_item` 里两处都只在天启篇存档起作用（原版档 `plain_none`、开关 `off_none` 覆盖，原版对照的 `xiyou_affix_rate`、`xiyou_merchant29`、`xiyou_drop_record` 已过），其余请总装合并时按选测跑。
- 反向验证（`反向验证.py`）：不挂掷词条、原版行照掷、不限传说、不看品质层、同名可重、项链无光环、寻宝不保底、不扣点、稀有同价、成就不藏，10 处咬住（「不看品质层」第一版找的装备不存在，换成三阶传说武器后咬住）；「珍藏不看阶门槛」没咬住：传说词条本来就只在三阶以上能出，`layer_candidates` 已经挡住，`min_tier` 是重复的保险，行为不变。
- `语法检查.py`：通过。
- `交付自检.py`：提交后跑，见回报。

## 本分支提交

- 天启篇装备掷词条、深渊商人寻宝／珍藏、成就页不列宠物成就；专项
- 补三条断言（反向验证）；交付单
