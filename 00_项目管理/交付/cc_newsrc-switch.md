# 集成分支说明：cc/newsrc-switch（换源 v0.28 → v0.62.12）

- 车道／工作者：CL（cc，悟空）建；原分支 `cc/wukong-newsrc2` 改名而来（2026-11-06，总装二十六定「甲：main 不换源」）
- 状态：**可合并**（总装三十 2026-11-07：云端整轮 c25a86f8 464 场景全过，run 42356612660；Kyo 看过[变化摘要](../提案_换源合并_20261107.md)回「合」，25 项全收）。合并按下面「总装合并」节手做（切链接、同步带 `--accept-source-switch`）。
- 各车道追平时从本分支切自己的分支（如 `cc/rules-newsrc1`），工作树里 `XIYOU_APP` 指向新源同步，交付合回本分支，不合 main。

## 这个分支上有什么

- 旧源上也成立的四样已拆到 `cc/wukong-newsrc3`（交付单 `cc_wukong-newsrc3.md`，可合并），本分支已合进它（同内容，等它进 main 后再合一次 main 即可）。
- 只在换源时成立、留在这里的：`battler.gd` `param_state()` 按 v0.62.05 每个状态只乘自己的层数；`event_presets.json` 删掉深渊商人旧第 3 页 795 个变体、m4e69 三个变体跟到 p1；换源接受单 `04_验证/测量接受/cc_wukong-newsrc2.json`（97 组）。
- 11-06 合 main（b7d1398f）：`event_presets.json` 冲突按条目合（取 main 全部 10429 条，去掉本分支删的 772 条、m4e69 三条换到 p1，得 9657 条）；main 这段时间新加的 4678 个变体没有落在被删的页上，但它们是对着旧源量的，换源后照常要在新源上重跑事件状态探针。
- **接受单已过期**：整组摘要是对着 11-06 前的 main 基线算的，合了 main 后第一轮同步必然报「接受单对不上」，按下面「总装合并」第 3 步重出。

## 云端整轮 189 个失败场景（运行 42178820127，提交 12e11992，新源产物）

初判只看了云端摘要里每个场景的头几条 FAIL 和 rules 分片日志的前 12 条样本，没在本机逐个重跑；「建议车道」按车道须知的文件划分（A 内容／楼层、B 界面、C 规则／机制、工具）。

按车道合计：C 规则 65 片 rules＋43 个；A 内容／楼层 9（同一根因）＋19；B 界面 18；工具 35（夹具来源，同一根因）。

### 一、同一个根因、一处修完一批（35＋9 个）

| 场景 | 初判 | 建议车道 |
|---|---|---|
| airship_state、airship_view、battle_common_events、battle_gaps、battle_start_event、book_capacity、book_capacity_ui、boss_lifecycle、boss_output、boss_output_context、boss_react、boss_sequence、boss_state_origin、casino_batch、character_help_cost、death_admission、designation、enemy_warehouse、hit_warehouse、honghuang_curse_battle、item_bag、module_hooks、passive_content、power_books、power_books_boundary、power_books_menu、pushstate、random_streams、recover_permanent、start_state_walk、state_merge_context、state_operation、target_eval、xuan_auto、xuan_bind | 只挂 `source`（测试夹具 `sourceIdentity` 还是 v0.28 的 runtimeInputs），其余用例全过；在新源上重出夹具即可，重出后数值有变的再分给对应车道 | 工具（哪吒） |
| floor_abyss174、floor_abyss211、floor_reach011、floor_unknown160、floor_unknown210、floor_unknown223、unlock_chain、unlock_chain_b、unlock_chain_c | 用例全过，但跑的时候报 `SCRIPT ERROR: String 赋给 Array`（`mv_event_core.gd:222` `_execute`）：新源有事件指令的 `parameters` 是字符串，解释器要容错或转换器规整 | A 内容／楼层（八戒） |

### 二、xiyou_rules（65 片）

| 分片 | 通过／总数 | 初判 | 建议车道 |
|---|---|---|---|
| rules | 49142/61678 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1）；d1 另有抗性 MV 1.0 ≠ Godot 0.8（穿透／抗性口径） | C 规则（rules） |
| rules10 | 86/90 | 专项 86/90，日志未给样本，要本机重跑看 | C 规则（rules） |
| rules_d1b | 48978/61691 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1）；d1 另有抗性 MV 1.0 ≠ Godot 0.8（穿透／抗性口径） | C 规则（rules） |
| rules_d1c | 49065/61597 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1）；d1 另有抗性 MV 1.0 ≠ Godot 0.8（穿透／抗性口径） | C 规则（rules） |
| rules_d1d | 49039/61687 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1）；d1 另有抗性 MV 1.0 ≠ Godot 0.8（穿透／抗性口径） | C 规则（rules） |
| rules_d1e | 49207/61625 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1）；d1 另有抗性 MV 1.0 ≠ Godot 0.8（穿透／抗性口径） | C 规则（rules） |
| rules_d1f | 49099/61635 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1）；d1 另有抗性 MV 1.0 ≠ Godot 0.8（穿透／抗性口径） | C 规则（rules） |
| rules_d1g | 49142/61621 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1）；d1 另有抗性 MV 1.0 ≠ Godot 0.8（穿透／抗性口径） | C 规则（rules） |
| rules_d1h | 49119/61732 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1）；d1 另有抗性 MV 1.0 ≠ Godot 0.8（穿透／抗性口径） | C 规则（rules） |
| rules_d2 | 59908/61676 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d2b | 59848/61691 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d2c | 59878/61597 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d2d | 59885/61687 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d2e | 59921/61625 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d2f | 59815/61635 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d2g | 59891/61621 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d2h | 59924/61732 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d3 | 30010/30871 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d3b | 29924/30838 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d3c | 29955/30816 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d3d | 29974/30870 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d3e | 29954/30800 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d3f | 29887/30811 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d3g | 29968/30841 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d3h | 29931/30824 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d3i | 29898/30805 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d3j | 29924/30853 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d3k | 29923/30781 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d3l | 29911/30817 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d3m | 29967/30825 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d3n | 29928/30824 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d3o | 29923/30780 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d3p | 29993/30908 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d4 | 59910/61678 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d4b | 59848/61691 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d4c | 59878/61597 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d4d | 59885/61687 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d4e | 59921/61625 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d4f | 59815/61635 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d4g | 59891/61621 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d4h | 59924/61732 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d5 | 59908/61676 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d5b | 59848/61691 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d5c | 59878/61597 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d5d | 59885/61687 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d5e | 59921/61625 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d5f | 59815/61635 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d5g | 59891/61621 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d5h | 59924/61732 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d6 | 30010/30871 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d6b | 29924/30838 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d6c | 29955/30816 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d6d | 29974/30870 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d6e | 29954/30800 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d6f | 29887/30811 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d6g | 29968/30841 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d6h | 29931/30824 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d6i | 29898/30805 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d6j | 29924/30853 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d6k | 29923/30781 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d6l | 29911/30817 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d6m | 29967/30825 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d6n | 29928/30824 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d6o | 29923/30780 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |
| rules_d6p | 29993/30908 | 伤害行 MV 多了成长乘区 `growth`（0.82～1.04，Godot 恒 1） | C 规则（rules） |

### 三、其余按领域（80 个）

| 领域 | 场景 | 通过／总数 | 初判 | 建议车道 |
|---|---|---|---|---|
| 事件楼层脚本 | common_scripts | — | 挖宝／传送公共脚本新源提示改了 | A 内容／楼层（八戒） |
| 事件楼层脚本 | dungeon | — | 15 层门页数差一页 | A 内容／楼层（八戒） |
| 事件楼层脚本 | event_compare | 9/11 | 新源事件里 CodexTier 等脚本没翻译＋多个事件回退 | A 内容／楼层（八戒） |
| 事件楼层脚本 | floor_odds | — | CodexHeavenGaze 没翻译，213 号图事件不显示 | A 内容／楼层（八戒） |
| 事件楼层脚本 | floor_reach004 | 206/207 | 方桌大厅保留事件表新源变了 | A 内容／楼层（八戒） |
| 事件楼层脚本 | interp_review | 11/13 | 升级消息分行新源不同 | A 内容／楼层（八戒） |
| 事件楼层脚本 | opening_branches | 14/16 | 开局分支压制名单新源多了技能 | A 内容／楼层（八戒） |
| 事件楼层脚本 | review135 | 83/85 | 变量 1726 新源设置值变 | A 内容／楼层（八戒） |
| 事件楼层脚本 | script | 24/26 | 公共事件 1345/1443 名单新源多 2771 | A 内容／楼层（八戒） |
| 事件楼层脚本 | script_census | 29/31 | 新源有未登记脚本（CodexBossDifficulty 等） | A 内容／楼层（八戒） |
| 商店 | floor_abyss037 | 131/133 | 深渊商人改脚本（CodexAbyssMerchant），旧页没了 | A 内容／楼层（八戒） |
| 商店 | floor_reach107 | 58/59 | 107 层商店对话新源变了 | A 内容／楼层（八戒） |
| 商店 | floor_reach109 | — | 110 层商店 1410～1415 新源取不到 | A 内容／楼层（八戒） |
| 商店 | map132_shop | 96/102 | 132 号图商店备货表新源变了 | A 内容／楼层（八戒） |
| 商店 | shop_buy | — | 132 号图商店备货表新源变了 | A 内容／楼层（八戒） |
| 商店 | shop_stock | 44/46 | 商店库存分组口径 | A 内容／楼层（八戒） |
| 装备说明卡 | alien_affix | 2113/2117 | 异化词条（绝缘、舍身）新源数值 | C 规则（rules） |
| 装备说明卡 | alien_battle | — | 异化掉落抽取次数／概率新源口径 | C 规则（rules） |
| 装备说明卡 | cat_help | 32/35 | 技能说明新文案（穿透）＋夹具来源 | C 规则（rules） |
| 装备说明卡 | equipment | — | 武器 56 新源参数与词缀全变 | C 规则（rules） |
| 装备说明卡 | equipment_admission | 6/7 | 准入表 6/7（日志没给失败项，要本机重跑看） | C 规则（rules） |
| 装备说明卡 | formula_equipment | 2007/2014 | 装备公式夹具来源＋新源 27 块 | C 规则（rules） |
| 装备说明卡 | formula_rest | — | 公式夹具来源与取值 | C 规则（rules） |
| 装备说明卡 | growth_forge | — | 心钢锻造说明文字位置 | B 界面（白龙） |
| 装备说明卡 | growth_help | 52/53 | 法宝成长战力新源数值 | C 规则（rules） |
| 装备说明卡 | help_card | — | 技能说明卡新源加品质行 | B 界面（白龙） |
| 装备说明卡 | inlay_book | 17/19 | 镶嵌图鉴状态栏文字 | B 界面（白龙） |
| 装备说明卡 | item_marks | 107/110 | 一键标记品质档新源多了档位 | B 界面（白龙） |
| 装备说明卡 | item_use | 11/12 | 可用物品公共事件数新源 1037 | C 规则（rules） |
| 装备说明卡 | magic_weapon_level | 50/51 | 法宝目录新源多 1 件（222） | C 规则（rules） |
| 装备说明卡 | power | 137/139 | 装备战力新源数值 | C 规则（rules） |
| 装备说明卡 | raven_artifact | — | 渡鸦法器基础值新源改 | C 规则（rules） |
| 难度真气玄Boss | challenge_passives | — | 挑战层敌人命中／暴击新源倍率 | C 规则（rules） |
| 难度真气玄Boss | difficulty_actor | — | 开局脚本 CodexTier.nonWeakIds 没翻译，技能 5969/10455 缺 | A 内容／楼层（八戒） |
| 难度真气玄Boss | difficulty_enemy | — | 新源敌人 947/980 xparam 取不到 | C 规则（rules） |
| 难度真气玄Boss | difficulty_inherit | — | 难度传承技能 5968→5969（新源换号） | C 规则（rules） |
| 难度真气玄Boss | difficulty_inherit_battle | — | 同上，职业 6216 技能 | C 规则（rules） |
| 难度真气玄Boss | difficulty_inherit_load | — | 同上，读档路径 | C 规则（rules） |
| 难度真气玄Boss | difficulty_troop | 1030/1034 | 敌群 854 第 7 项 xparam 1.5→1.0 | C 规则（rules） |
| 难度真气玄Boss | honghuang_curse | — | 洪荒诅咒说明新源改写＋夹具来源 | A 内容／楼层（八戒） |
| 难度真气玄Boss | honghuang_reward | — | 洪荒奖励 CodexTier 脚本没翻译＋夹具来源 | A 内容／楼层（八戒） |
| 难度真气玄Boss | weak_challenge | 120/125 | 弱者挑战分类与说明新源改 | C 规则（rules） |
| 难度真气玄Boss | xuan_battle | 269/272 | 玄的净化次数新源数值＋夹具来源 | C 规则（rules） |
| 难度真气玄Boss | zhenqi | 175/181 | 真气页新源改版 | B 界面（白龙） |
| 难度真气玄Boss | zhenqi_break | 76/83 | 突破规则新源改 | C 规则（rules） |
| 难度真气玄Boss | zhenqi_daofa | — | 神兵名单与道法菜单新源改 | C 规则（rules） |
| 角色技能 | action_sequence | 116/117 | 新源技能条件写法「user.hp < user.mhp * 0.x」没翻译 | C 规则（rules） |
| 角色技能 | actor_advanced | 32/33 | 角色进阶表行数变了（新源 490 行） | C 规则（rules） |
| 角色技能 | actor_p0 | — | 角色 104 新源多被动技能 10455 | C 规则（rules） |
| 角色技能 | attack_element | — | 角色 154 攻击伤害差 10 倍（新源倍率） | C 规则（rules） |
| 角色技能 | attack_query | 379/381 | 角色 161 带武器 79 新源不能普攻 | C 规则（rules） |
| 角色技能 | cat | — | 心之钢连锁伤害新源数值 | C 规则（rules） |
| 角色技能 | custom_params | 158/160 | 自定义参数别名新源多了（maxhp 等） | C 规则（rules） |
| 角色技能 | element_ternary | 31/33 | 技能 10020 三元公式新源取值为空 | C 规则（rules） |
| 角色技能 | formulas | 5/7 | 技能 10020 三元公式／大数超 64 位 | C 规则（rules） |
| 角色技能 | guyu_battle | 1635/1637 | 谷雨复活／回合脚本新源数值 | C 规则（rules） |
| 角色技能 | imported_balance | — | 导入平衡倍率新源全改 1.0 | C 规则（rules） |
| 角色技能 | life_steal | 336/341 | 吸血状态 2570/2580 新源数值＋夹具来源 | C 规则（rules） |
| 角色技能 | nanoha | 285/286 | 奈叶击杀后学技能新源口径 | C 规则（rules） |
| 角色技能 | param_states | — | 状态层数（param_state 已改）还差 plus 项＋夹具来源 | C 规则（rules） |
| 角色技能 | qiyu | 229/231 | 奇遇状态 2626 新源不再生效 | C 规则（rules） |
| 角色技能 | raven_reflect | 556/561 | 渡鸦反伤层数新源数值 | C 规则（rules） |
| 角色技能 | skill_mastery | 304/306 | 熟练表新源 6983 行 | C 规则（rules） |
| 角色技能 | state_effects | — | 反击序列与状态 1451 新源口径 | C 规则（rules） |
| 角色技能 | state_effects_tp | 542/544 | 服装库存与未翻译状态数 | C 规则（rules） |
| 角色技能 | state_overlay | 17/18 | 叠加状态新源多 1 个 | C 规则（rules） |
| 角色技能 | wtype | — | 武器类型消耗新源口径＋夹具来源 | C 规则（rules） |
| 界面 | actor_book | 17/22 | 图鉴角色索引与状态面板文字随新角色变化 | B 界面（白龙） |
| 界面 | change_clothes | 31/32 | 神话角色换装表新源 65 个 | B 界面（白龙） |
| 界面 | costumes | 26/27 | 服装卡登记新源加了 68xx 敌人卡 | B 界面（白龙） |
| 界面 | enemy_book | 93/95 | 敌人图鉴索引与百分比显示 | B 界面（白龙） |
| 界面 | gear_search | 55/58 | 装备搜索战力排序（战力口径变） | B 界面（白龙） |
| 界面 | guide | 56/63 | 方桌向导地图集与里程碑新源改写 | B 界面（白龙） |
| 界面 | guyu_ui | — | 谷雨状态栏文字「生长／平时」新源改名 | B 界面（白龙） |
| 界面 | hangup_auto | 227/232 | 挂机卖出设置页新源改版 | B 界面（白龙） |
| 界面 | options_basic | — | 设置页新源加了几项（codexBossStatusPanel 等） | B 界面（白龙） |
| 界面 | status_power_panel | 10/11 | 角色 148 技能名新源改（碧天独行） | B 界面（白龙） |
| 界面 | sve_visual | 25/31 | 战斗图素材普查新源数量变 | B 界面（白龙） |
| 界面 | svpngfd | 29/30 | 战斗中卸装贴图缓存 | B 界面（白龙） |
| 界面 | vsfx | 21/22 | 状态特效普查新源多了状态 | B 界面（白龙） |

## 优化登记草稿

优化登记草稿：无

（25 条占位登记已直接写在优化登记表里，编号合并后另派一张文档单统一换成 O-231 起。）

## 变更记录草稿

## 2026-11-07 【cc·总装三十·未经审查】换源 v0.28→v0.62.12 合进 main（dev.待定）

- 冻结正式源换成 v0.62.12（`冻结正式源/app.nw` 改为指向 `v0.62.12/app.nw` 的链接，旧副本在 `v0.28/app.nw`）；集成分支 cc/newsrc-switch 的全部车道成果（规则、界面、平台、八戒、悟空、哪吒 newsrc 各期）一起进 main。
- 25 项跟进新源／修原版 bug 的开关见优化登记里待分配编号的各行与 `00_项目管理/提案_换源合并_20261107.md`，Kyo 11-07 回「合」全收。
- 验证：云端整轮 464 场景全过（c25a86f8，run 42356612660）；main 上同步带换源接受单。
- `合并车道.py` 加 `XIYOU_ACCEPT_SOURCE_SWITCH` 环境变量：设了就给同步加 `--accept-source-switch <版本>`（换源合并用）。

- 集成期间各车道的变更记录（原交付单「变更记录草稿」原文照收，交付单本身已删，见 git 历史）：

### cc_bajie-newsrc1

### 【cc·八戒·未经审查】换源追平：新源 355 字符串参数、CodexTier 名单、天道注视、深渊商人页（跟到 v0.62.12）

- **新源 355 的 `parameters` 是字符串**（表「一」第二行 9 个场景的 `mv_event_core.gd` String 赋给 Array）：只有两种，都是 355——深渊商人 32 个事件页的 `CodexAbyssMerchant.openCurrent(this);`、公共事件 1439 的 `if(window.CodexAbyssMerchant)CodexAbyssMerchant.complete(this);`。原版 `command355` 读 `parameters[0]`，对字符串只拿到第一个字符：新源参照引擎实测，前者 eval `C` 抛 ReferenceError 被 YEP_CoreEngine 的 try 吞掉，后者 eval `i`（插件漏出来的全局变量）只取值，**两条在原版都不生效**，`complete`／`openCurrent` 都没被调到。
  - 选在**转换器规整**（`xiyou_export.py` `mv_string_parameters`）：把字符串拆成逐字符数组，任意下标读到的都与原版对字符串取下标相同，行为不变；原字符串留在指令的 `mvStringParameters`，manifest 另记 `mvStringParameters`（31 处：切片里 30 个事件页＋CE1439）。不在解释器容错的理由：Godot 侧按数组读 `parameters` 的地方不止 `_execute`（地图／战斗解释器的 355、`xstate` 扫公共事件名单、`actor_book`、`casino_batch`、`bulk_pills` 等），只修一处别处照样崩，新写的读者也会再踩；规整成原版实际读到的值，一处修完。
  - `MVScript.run`：整段只有一个裸标识符时当无操作（原版 eval 它没有效果），这样 `C`／`i` 不进「认不出的脚本」。
  - 开关：`XIYOU_MV_STRING_PARAMS=keep`（转换器不拆，回到原样）、`MVScript.BARE_IDENTIFIER_NOOP = false`。O 号待总装分配。
  - **原版本身的问题（报 Kyo，不改原版）**：v0.62.12 里深渊／不朽商人因此永远不会出现（唯一调 `complete` 的就是 CE1439 这条）。
- **CodexTier.nonWeakIds()**（v0.44 起公共事件 1345、1443～1445 的名单改读角色备注 `<KyoTier:超强者|强者>`）：`XState.tier_non_weak_ids()` 按备注取（有名字、编号升序）；`MVScript.run` 把调用换成字面数组后照旧走「名单循环」写法，`XState.difficulty_native_ids` 认 `var 名单 = CodexTier.nonWeakIds()`（弱者判定 `XWeakChallenge.is_weak` 读它）。
- **一线生机与天道注视**（公共事件 1330，v0.34 起 `CodexHeavenGaze.apply(true|false)`）：有名字的角色逐个建出，弱者在 `apply(true)` 时学 6212；非弱者先 repair（会 6212 的忘掉、学 6213）再学 6213。
- **深渊商人事件页**（v0.30 起 `<CodexMerchant29>`）：第 2 页只在 `hasMerchant()` 时成立、不看页面条件。重制没跟商人运行时，`MVEvent.merchant29_present()` 恒为否（原版 v0.62.12 也走不到，见上）；开关 `MVEvent.MERCHANT29_PAGE_GATE = false` 回到只看条件。`xiyou_dungeon` 的 `page_of` 同步；`xiyou_floor_abyss037` 的商人用例改成新源行为（77／78 不开、商人页不出）。

### cc_bajie-newsrc2

### 【cc·八戒·未经审查】换源追平续：新源空绿 19 例、showRoster 新写法、洪荒诅咒分档（跟到 v0.62.12）

- **新源新增空绿 19 例**（`事件空绿扫描.py --check` 现在过，96 例都写明了理由）：
  - 补预设 `#n2` 8 个真走到效果：ce9039、ce9030、m144e15p0、m45e10p0、ce9026（四个前置技能都要）、m45e10p1、ce1438（`random_seq` 0.12 抽到 25）、ce9023。一护（148）、麒麟（142）是超强者，默认难度 `$gameParty.addActor` 被 `CodexBossDifficulty` 拦下（「超强者仅限地狱及以上难度获取」），预设要带 `difficulty: 9`；`m213e2p0#w1_857` 同样补上。
  - 收基线并写进 `事件空绿走不到.json`：藏宝图 CE117、1381～1384（只调 `RunGetFun`，要站在宝藏坐标上，预设设不了站位）；CE9028、9029、9034（条件是敌人状态，只在战斗里）；m145e11p0、m43e23p1、m45e10p2（刷孔：失去再得到同一把武器，件数不变 delta 量不出，`#n2` 预设已让它走到）。上一单收进基线的 30 个商人第 2 页也补了理由。
- **`CodexBossDifficulty.showRoster` v0.44 写法**：大厅 EV41 六页改成裸调用 `CodexBossDifficulty.showRoster('strong'|'super');`（不再 `setWaitMode`），名单是 `CodexTier` 两档（`<KyoTier>` 原地重建，不另加小猫）。`MVScript` 认这种写法，名单取 `XState.tier_ids`；旧写法照旧。两条各在一个选项分支里、后面没有别的指令，当场显示与原版看到的一样。
- **`XState.tier_ids(tiers)`**：按角色备注第一个 `<KyoTier:…>` 取（同原版 `TAG.exec`），`tier_non_weak_ids` 改成调它。悟空的 XTier（`cc/wukong-newsrc5`）进来后两处都改成调 XTier。
- **洪荒诅咒分档**（v0.52 用户重排，只改分档与显示／倍率，不改诅咒效果）：`XHonghuang.TIER` 改成 static var，默认 `TIER_V052`，回退设回 `TIER_V028`。玩家可见（选项文字的档位与奖励倍率），O 号待总装分配。

### cc_bajie-newsrc3

### 【cc·八戒·未经审查】换源追平续三：大厅漩涡过场不再挂住测试、号角店跟新源、升级文字、商店积分价

- **opening_branches 资源未释放**：原因是大厅 EV76 漩涡过场（新源，新档首次进大厅自动执行）还停在 223 色调等待（等 SceneTree 的帧）时测试就退出了；解释器和挂起的协程互相引用，宿主释放也收不回，退出时报「2 resources still in use」。试过把等帧改成等地图宿主转发的信号（宿主释放时一起断开），**没用**（Godot 4.7 里协程挂起在已断开的信号上也不释放），已撤回。改成测试等过场播完再退出（`c_rift_cutscene`：rift1 记过、EV76 独立开关 A 开、地图空闲），顺带把过场从头到尾走了一遍；不再预先记成看过。
- **其它进大厅的测试**（17 个逐个跑过，只看泄漏）：都没有「resources still in use」。但过场挡住了两个测试：`screen_fx`（色调被过场 223 改掉，tint_reached／save_kept 挂）、`floor_reach041`（过场占住地图，预约的公共事件 164 没跑，lamp_in_dungeon 挂）。两测都设了 `XConfig.path_override`，改成开头 `whisper_mark("rift1")`（只写本测的临时配置），现在全过。`platform` 退出时有 3 个 ObjectDB 泄漏警告（不是资源未释放，不算失败），没查。
- **号角店**（map132_shop 6 项）：`XItemMarks` 里另有一份旧的停用号角名单（5 个），改成直接用 `XImportedBalance.DISABLED_HORNS`（新源 10 个，多 245／274／359／456／494）；Map132 不朽号角货架（有 2788 的店）追加流萤号角 3063（installLiuyingRuntime v0.60.02，排在谷雨与云裳之间；库里 3063 名字是「伙伴号角：流萤」才加，旧源不加）。map132_shop 102/102。
- **shop_buy**（实测只挂 ui_list、ui_number0 两项，另外 3 项随停用号角名单一起好了）：界面参照是 MV 量的旧源数字，新源被动书 2230 的备注价从 1000 肝帝积分＋30 件 2201 改成 1300＋39（数据里乘了 1.3，不是 v0.41 商店规则的指定价×1.3），参照里的数字跟到新源，位置不变。8479/8479。
- **interp_review**（flush.225 两项）＋ event_compare 大厅 EV69 三例：**新源原版代码错误**。流萤运行时 `installLiuyingRuntime` 把 `Game_Actor.changeLevel` 包成 `function(level)`，316 增减等级勾的「显示升级」被丢掉，原版不再出「某某升到了 等级 N！／学会了…」（探针打桩实测 `changeExp` 收到 show=undefined；v0.28 有这段文字）。`MVEventCore.LEVEL_UP_SHOW_316`（默认 true，照旧显示）；设 false 回到新源原版。interp_review 在参照文字为空时按回退支比文字、时序用默认支比参照帧号。**O-待定·升级文字**，已登优化登记。
- **优化登记**：O-184 状态加注「只在旧源（v0.28）生效，新源原作已做活，正式源换定后可退役」；CE1370 拔剑再释放登「O-待定·拔剑再释放」（`XBattleEventRunner.O_PUSH_RECAST`）。两个 O-待定 编号合 main 时总装分。
- **事件预设**：`ce9039#n2`（麒麟 142）、`ce9026#n2`（147）加 `difficulty: 9`。原来预设加人时被「超强者仅限地狱及以上难度获取」拦下，参照多一条提示。已补跑事件状态探针（增量）。

### cc_bajie-newsrc4

### 【cc·八戒·未经审查】换源追平续四：event_compare 新源基线重出、深渊赌场二阶段跟新源换序

- **深渊赌场 1434 二阶段**（event_compare ce1434#o5_3）：新源 v0.62.10 的 `installCasinoBatchRuntime` 里有 `fixAbyssStage2`，读入公共事件时把 1434 二阶段五对「1197 = v1191～1195、再重抽那一格」换成先抽再读（原注释：旧顺序 20 连后这几格残留约 ±30000）。数据文件本身没改，所以重制照数据跑就和参照对不上。参照探针打桩实测：执行到第 45 条时跑的是「1195 = 随机」。重制在 `XDB.table("CommonEvents")` 读入时调 `XCasinoBatch.fix_abyss_stage2` 做同样的换序；开关 `XCasinoBatch.ABYSS_STAGE2_ROLL_FIRST`（默认 true，false 回到 v0.28 数据原序），登「O-待定·深渊赌场二阶段」。casino_batch 加 abyss2.raw／roll_first／o-off 三项。
- **event_compare 基线按新源重出**：15565 例，一致 15556，登记 9 例（原有 3 例＋新进 6 例，理由都写进了基线的 note）；跳过基线收进 ce1370 四条（O_PUSH_RECAST 在战斗里补，地图对照认不出）和 ce9043 一条。
- **ce9039#n2／ce9026#n2**：上一棒给预设加的 `difficulty: 9` 是对的。集成树的事件状态产物是在这条预设改动之前量的，所以参照里还留着「超强者仅限地狱及以上难度获取」。用新源单跑这两例（`XIYOU_APP=…/v0.62.12/app.nw node event_state_probe.cjs 'ce9039#n2' 'ce9026#n2'`），提示没了，结果补进本树 generated 的 event_states 后两例一致。**集成树合本分支后的同步会重量这两例**（预设变了，增量键也跟着变），不用手补。

### cc_nezha-newsrc3

#### 2026-11-06 【cc·哪吒·未经审查】新源 19 个状态的新写法翻成结构化效果；formulaGd 大数写成浮点（dev.待定）

见本交付单「结论」。旧源产物逐字节不变；新源 state_effects 1097→175 失败（剩敌人复活 173 另查）、param_states 52→1、nanoha 全过。核查：待 Codex（改了 state_effects.gd）。

### cc_nezha-newsrc4

#### 2026-11-06 【cc·哪吒·未经审查】新源 custom_params 探针改挑防具；奈叶队友击杀走适应软上限（dev.待定）

custom_params 的 mhp_mmp_eight 改挑春雷／白马等防具（新源专武不再写 mhp／mmp），装不上就直接写槽位；件数按来源比。XNanoha.finish 跟进新源 `CodexNanohaAdapt(nanoha, 0.5)`，nanoha_kill 夹具用新源重出，加了软上限例和累计次数。custom_params 160/160、nanoha 289/289；state_effects、param_states 与改前相同。核查：待审查（改了 nanoha.gd）。

### cc_nezha-newsrc5

#### 2026-11-06 【cc·哪吒·未经审查】敌人复活参照改每例独立现场；奈叶队友击杀回退开关；更新日志不进来源指纹（dev.待定）

查清新源敌人热缓存不复活是 dsPassiveSkill 缓存失效引起的原版行为，revive 探针改成每例新战斗并建被动缓存，新旧源重跑；XNanoha.ADAPT_V062（O-待定·奈叶队友击杀）；插件备注 6 个新源标签登记暂缓、death_admission 关五乘区；转换器读更新日志不记进 manifest.inputs。核查：待审查（改了 nanoha.gd、转换器）。

### cc_nezha-newsrc6

#### 2026-11-06 【cc·哪吒·未经审查】v0.62.12 新增 15 个状态翻成结构化效果；余辉、绑定 gainHp 遮蔽参照（dev.待定）

转换器把 2720～2777 共 27 个 Effect 块译成 effect_program／换装操作，超赛多形态回落（costume_form_remove）与超蓝还原后倒下（costume_restore addState）进 Godot；state_effects 探针加 effect3.blocks、newsrc6.blocks 两例原版参照；新探针 gainhp_shadow 量出回光溢出给角色不发余辉护盾、非璇附身者在敌方行动中照掉脚本扣血（都是 krz Game_Actor.gainHp 遮住包装）。核查：待审查（改了 state_effects.gd、转换器）。

### cc_platform-newsrc-pause1

#### 2026-11-07 【cc·平台·未经审查】集成分支 xiyou_pause_save 修夹具：新源方桌大厅的自动执行字幕事件（dev.待定）

- 场景 `xiyou_pause_save` → 用例 map_saves、no_popup、dedup_focus_out、dedup_paused_again、after_window_saves、focus_out_saves（run 42343228257 shard-3，全是 `skip:event`）→ 根因：不是并行事件。新源（v0.62.12）方桌大厅 Map004 多了事件 76「时空漩涡_字幕1」，第 0 页无条件自动执行（47 条：字幕、等待、`CodexWhisper.mark('rift1')`，最后开独立开关 A）。测试进图后只等 4 帧，演出还在跑、地图 busy，切后台照规矩跳过。集成分支（3948463f）的地图场景根本没有跑并行页（trigger 4）的代码，所以「并行页一直算 busy」不成立。→ 修法：测试夹具跟 20 号一样先开 76 的独立开关 A；加前提断言 map_idle_after_setup，以后再有新的自动执行事件会直接报在这一项。游戏代码不动：演出在跑时跳过切后台存档是对的。
- main 上：v0.28 的 Map004 没有 76 号事件，main 也没有跑并行页的代码，不受影响，不用另开分支。

### cc_rules-newsrc1

#### 2026-11-06 【cc·rules·未经审查】新源伤害规则追平：穿透打抗性、导入角色解除缩放、属性转换攻守分算、反击概率封顶（dev.待定）

见本交付单「结论」四条；`xiyou_rules` d1 第 0 份 49142 → 61678/61678。云端集成分支 189 失败表里 rules 那行「成长乘区」的初判更正为上面四条。核查：待 Codex。

#### 2026-11-06 【cc·rules·未经审查】新源补单：专武·特效吸取开局学、治疗挂状态只给友方、角色掉血绕过护盾账本做成可撤回开关 O-待定·角色HP包装（dev.待定）

见本交付单「第二轮」表。O-待定·角色HP包装 待 Kyo 确认（默认照旧源：角色持续伤害／行动序列扣血先扣璃壁等护盾）。核查：待 Codex。

### cc_rules-newsrc2

#### 2026-11-06 【cc·rules·未经审查】新源补单：导入角色都挡 2626、三份来源夹具与熟练度表在 v0.62.12 重出（dev.待定）

见本交付单「做了什么」。核查：待 Codex。

### cc_rules-newsrc3

#### 2026-11-06 【cc·rules·未经审查】新源补单二：敌人被动缓存按状态重建、谷雨替倒 setHp 开关、w93 解放测试（dev.待定）

见本交付单「做了什么」。核查：待审查。

### cc_rules-newsrc4

#### 2026-11-06 【cc·rules·未经审查】新源补单三：穿透说明卡与战力去重、角色被动缓存按状态重建、O-待定·角色HP包装 并成一个开关（dev.待定）

见本交付单「做了什么」。核查：待审查。

### cc_rules-newsrc6

#### 2026-11-07 【cc·规则·未经审查】新源：敌人反击跟在挨打之后、换装断言随新源（dev.待定）

- 新源 v0.35 起，敌人判中反击时先挨这一下再反击（`XBattleLogic.COUNTER_AFTER_HIT`），角色照旧；state_effects 2792 序列对上。
- 换装 226／66 的断言改为新源行为（battlerName 退回数据库的图）。
- param_states 1768.self 翻倍：根因是新源死亡时 states 缓存成空表（同 O-待定·热缓存复活）。默认照常加两次；回退支 addParam 不再标脏，照参照只加一次。

### cc_rules-newsrc7

#### 2026-11-07 【cc·规则·未经审查】新源反击时机：反击致死画面逐帧、测试两头测（dev.待定）

- 新源敌人先挨打再反击时，日志外层只一对 pushBaseLine／popBaseLine（YEP invokeAction）。s104 反击致死在 v0.62.12 重量，逐帧对上（SHOW BATTLE HUD 69 帧）。
- xiyou_combat、xiyou_qiyu、xiyou_sequence_visual 的反击用例改成两头测（默认新源，回退支旧源）。魔法反射没坏，是反射用的敌人被新源先挨打的三段打死了。

### cc_ui-newsrc1

#### 2026-11-07 【cc·界面·未经审查】换源集成：修行·详细页高阶词条概率段照作者本意显示；四个界面测试改正前提（dev.待定）

- 原版 v0.62 的「高阶词条概率」包装装晚了，修行·详细页从来不显示这一段；重制照本意显示，开关 `XAffixRate.DETAIL_SHOWN`（O-待定）可回原版。
- item_bag、hangup 的测试要先把大厅首次漩涡过场记成看过（云端全新配置会播过场、占住地图）；hangup_options 的行数随 Boss状态面板开关。

### cc_ui-newsrc2

#### 2026-11-06 【cc·界面·未经审查】换源追平界面第三段：修行拆两页、安全出售、怪物图鉴／战力覆盖参照重取（dev.待定）

- **② 修行两页**（O-待定·修行两页，`XGuide.PANEL_V062`，默认开；关＝v0.28 一页写法）：跟 `installNativeGuidanceRuntime` v0.62 版。第 4 页「修行」照 `G.panelRows`（路线·层数、挑战评估、境界与真气伤害、突破条件／下一境所需、待选奖励、天道加持、结算伤害、必备属性四项、建议前两条、「详细数据见第二页」）；新增第 5 页「修行·详细」照 `G.detailRows`（真气、难度对照四列＝难度影响／不含难度／实际、结算伤害三行）。「战力构成」一段是 CodexZones 五乘区预算，照 O-044 不移植（整段连同段后空行不显示）。面板专用格式 `pct0／dmg_pct／stat_pct／mult1／big_panel`、建议 `panel_suggestions`（秘境抽奖被动书下一本、丹药）、`challenge` 照原版。状态页按 maxCols＝页数排成 5 列（项宽 240、间距 252），表头／滚动与第 4 页同一套 drawPanelRows。原版第 4 页按安卓虚拟按键缩进（CodexV019.padRects），重制暂不缩进（桌面同原版）。区段表 `guide_atlas.json` 换成新源抽出（a 段多被动书一句，d／g 段文字指向「修行·详细」）；里程碑 d 段的改写跟着指向「修行·详细」，g 段同时去掉「战力构成和」。`zhenqi_probe.cjs` 的 page.* 多记 `detail`（新源有 ZhenqiDetail 才记）。
- **③ 安全出售**（O-待定·安全出售，`XSafeSell.ENABLED`，默认开；关＝换源前的筛法）：新文件 `core/safe_sell.gd` 照 `installSafeSellRuntime` v0.40～v0.53.01。一键出售与挂机自动卖出共用 `plan`／`reason`：旧档按 Q.legacy（没品质备注按 1）、一键出售按七档成员（含旧档 15）；保留原因依次为锁定、模板找不到、专属武器（专属法宝照卖）、已培养或镶嵌（法宝升级／经验、异化、心钢与狂妄层数、强化、宝珠孔）、吞器占用、不可出售（无金币售价也无别的货币）、词条达到门槛或待确认（九档，默认「不朽及以上」，存在挂机卖出配置 `keepAffixTier41`，认旧键 `keepAffixGrade40`）。商店一键出售窗宽 680、首行「保留词条：门槛」（确定循环）、各档改叫「出售X装备」；选档后弹确认窗（720 宽、4 行居中：待售／保留件数、门槛、确认出售、取消，默认停在取消；确认时计划变了就刷新不卖）。挂机卖出页宽 680、状态宽 250，末行「保留词条品质」（确定往后一档，←/→ 前后），上方两行说明窗。深渊商人的吞噬／额外词条（重制未移植）不判；CodexElements 的备注元素统一重制不改实例备注，模板与实例原样比。
- **参照重取**：
  - 怪物图鉴 `enemy_book_oracle.json`：`ui_reference/review_system_pages.js` 的 enemy_book 页加 `enemyBookFixture()`，在原场景里按原格式整份重出（目录 850 项、状态窗每 8 项、掉落每 41 项、神话 3 只；记在 Bitmap.drawText／drawIcon、颜色为改色前、对齐非 center/right 按 left 记；神话掉落用替身目录取，免得目录重建）。「99%→299%」是旧夹具的数，新源本来就是 99%。`battle_enemy_book_oracle.json` 仍是 v0.28，新源上照样全过，没重取。
  - 战力覆盖 `power_coverage_oracle.json`：新加 `ui_reference/power_coverage_ref.cjs`（无画面 hboot，写 `mv_oracle/.sandbox/` 再复制）；在 v0.28 上跑与 2026-10-16 浏览器读数逐角色相同，新源上 141／148／149／159／162／166 六处与重制一致，多出新角色 179。`power_panel_oracle.json` 未动（新源上照样过）。
  - 宠物：`review_system_pages.cjs … pets` 在新源重取，说明卡仍在 (880,572)、技能名单不变，夹具不用换；`xiyou_pets` 的 skill_list 挂是 O-007 把 15 号背景说明放大到 16 号，新排版的这张卡因此高 25、碰底被推到 557。测试改为按原版字号（`min_font = 0`）比位置。

### cc_ui-newsrc3

#### 2026-11-06 【cc·界面·未经审查】换源追平界面第四段：人物图鉴跟新源、说明卡特效按品质排序、专属技能成长措辞（dev.待定）

- **人物图鉴**（`ui/actor_book.gd`，跟新源的显示改动，不设开关）：
  - 目录去掉 `CodexV029.hiddenActors`（141、146、152、157、160、161、166，installIntegratedV029Runtime v0.30 的 Window_ActorBookIndex.refresh 包装；「？？？」占位留着）。目录位置不再等于角色号，状态页、立绘、抬头、技能详情都按 `index_ids()` 取角色（v0.35 `Window_ActorBookIndex.actor()`）。
  - 状态页：本角色基础技能里有 `<CodexAura>` 光环时排成「主动／被动／光环／其他」四列（Star_ActorsBook v0.29）：列宽 floor(932/4)＝233，文字宽 225，技能 22 号、行距 30，每列最多 floor((684−首行 y−行高×6)/30) 行，多出的写白字「确认查看全部」；掌握段跟在最长一列后面。
  - 技能详情：光环技能标签写「【光环】」；179 流萤补技能表（10622～10632，加备注 `<CodexLiuyingPassive:` 的）并进「未解锁」名单。
  - 立绘：Codex_MiraRavenMultiFrame v1.06 的流萤 128px 档 `Codex_Liuying_SV` 登进 `XAppearance.PROFILES`（战斗归一也用这一档）；v1.07 图鉴倍率 `XActorBook.BOOK_SCALE`（流萤 0.8，只在图鉴里乘）。
- **说明卡特效按品质排序**（`XHelpCard.EFFECT_SORT_V041`，默认开，**O-待定·特效排序**，关＝原顺序）：照 installEquipmentDetailV041Runtime 的 CodexDisplay.equipmentRows 包装，装备的特效行（去色码后以「混沌神话／混沌／神话／太古／mod特效」或「特效／效果／成长」开头，或带 `\c[1-9]`）只在原位置之间按品质从高到低换位；品质取备注里该行前最近的 `<quality:N>`（`XSafeSell.rank`），不是备注带来的按模板品质，混沌 111、神话 110、mod 93、太古 91。排序放在元素／穿透行插好之后、◆唯一 标记之前（与原版包装次序一致）。另删 v0.41 旧存档里留的「效果：持有…时，造成的技能伤害＋」「效果：持武增伤作用于」。
- **专属技能「成长：」措辞**（`ui/character_help.gd` nowGrowthRows，跟 v0.62.12）：谷雨 10290、10292、10293、10298；屠苏、璇 passive.relay、10321、10335（治疗系数）、10336、10339、10358、10359、10361、10362 的字头改成新源写法（受赠消耗、追加伤害、护盾系数、技能倍率、物防魔防共享、触发加快等；10359 换成贯日／敕令倍率、盾形态受到伤害、目标伤害降低四行）。新源另加的 **10326** 一行（护盾系数 20%／保底 13.1%，数值与重制不同）按派单只列不改，归角色车道。
- **DOM 面板参照重取**（第二棒）：新写 `ui_reference/dom_ref.cjs`（只读服务＋本机无头 Chrome，在 `?battle_ref=1` 页面里执行一个取数脚本，结果写到给定文件）和两份页面脚本：
  - `gear_search_ref.js`：内存新局，背包按旧夹具的 21 件模板各得一件（得装备时随机数固定 0.5，不出随机词缀；带 `<Prefixes>` 的取再生成的那件），名字／描述／能力照旧夹具覆盖，备注用新源实例自己的；面板「仅背包」逐项操作读 sorts／cats／queries／quality／type／term／small／detail／itemList。v0.28 上重跑与旧手量夹具**逐键相同**。新源上变的不止死霸装：解放前的斩月、麒麟对剑两把、绣冬、贽殿遮那、真我之钥、斩月、斩月-虚、花与鸟之矢、队员死霸装 10 件模板都改了（专武成长、数值×10、KyoUnique 等），备注随之换新；`gear_search_oracle.json` 重出。
  - `power_panel_ref.js`：队伍 1/2/23/85，状态页 openPower，读 #cq-modal 带文字的元素（自身文字节点）与工具条按钮、面板／详情／底栏框。v0.28 上与旧手取逐行同文字、坐标差 ≤0.52（strong 行内框）；新源读数文字与 v0.28 完全相同；`power_panel_oracle.json` 重出。
- **DL 单（第二棒）**：
  - 状态页（`status_page_oracle.json`）、修行页（`zhenqi_page_ui_oracle.json`）夹具在 v0.62.12 无头重取：新页面脚本 `ui_reference/status_page_ref.js`（包住 drawText／drawFace／drawIcon／drawGauge／drawHorzLine 记调用；条的填充宽取实际画的渐变条宽，YEP 描边时少 2；可选 pageList／variables／zhenqi 与逐屏滚动）。v0.28 上重跑与两份旧手量夹具逐键相同。
  - 状态页测试：选页窗 5 项（240／252）改成直接比夹具（项矩形、光标、文字），不再按 Window_HorzCommand 公式推；v0.28 的 4 项常量另断言。
  - **武器类型加成「生效／未持有」**（`XStatusPage.WTYPE_HOLD_V041`，默认开，**O-待定·武器类型生效**，已写进优化登记）：新源 installEquipmentDetailV041Runtime 包 calcWeaponBonus，加成后缀「 生效」（isWtypeEquipped，用 `XBattleLogic.wtype_equipped`）／「 未持有」；重取的夹具第 2 页因此挂 4 项，已跟。
  - 修行页测试：抬头、文字行起点、表头四列改比新源第 5 页「修行·详细」（「项目／难度影响／不含难度／实际」），另比橙色 warn、第 4 页抬头 panelHead；旧一页写法的四列位置照同一份夹具比。
  - growth_help：心钢／狂妄说明卡也按品质排特效行（原版 H.describe 末尾调 RJO.HE.getDescParams，v0.41 排序在里面），放在 `XGrowthHelp.rows` 分组之前，挂在 `EFFECT_SORT_V041` 下（O-待定·特效排序，这次也补进优化登记）。测试 `fix.*` 段自 v0.43 起找「成长：」行越界（行首多了 `\lock[1]`），一直没跑到断言、只报 SCRIPT ERROR；改成去掉 lock 再找，外层包装的装备战力／穿透行另核。现在 77/77、无 SCRIPT ERROR。
- **DL ③ 心钢技能说明卡**（第三棒，`XGrowthHelp.skill_view`，跟 `XHeartsteel.TURN_CD_V035`，O-待定·心钢按回合冷却，关＝v0.28 没有这张卡）：照新源 H.skillHelpView（Window_BattleSkill／Window_SkillList.updateHelp 包装），巨人吞噬 10227／利维坦 10228 的说明卡换成深拷贝，备注 APs 行全删、重写：目标／命中／消耗、伤害（按角色身上对应的心钢／利维坦的阶，没装或装的是另一件就按原件）、战斗中「状态：巨人吞噬已就绪／冷却，还需 n 回合／蓄力，还需 n 回合」、效果／条件「第2回合起可用」／冷却 2 回合。拷贝标 `skill_copy`，元素包装不插技能的伤害属性（同原版 isSkill 为假）。战斗技能窗 `battle_scene._help`、技能页 `skill_scene._update_help` 接上。参照：`growth_help_probe.cjs` 加 `skills` 11 例（v0.62.12 量），`growth_help_oracle.json` 只多 `skills` 一键（cases／powerOnly 不变）；`xiyou_growth_help` 逐行比文字／字号／颜色／对齐／y／卡高，另断言开关关时原样返回。顺手修测试里卸装写成 `change(…, {})`（实际不卸，`{}` 在背包里找不到）→ `null`。
- **zhenqi page.* 12 项**（第三棒，不改代码）：集成分支 `generated/oracle/zhenqi.json` 的 6 个 `page.*` 用例是探针加「修行·详细」（0250eacc）之前出的，没有 `detail`；本机用 v0.62.12 重跑 `zhenqi_probe.cjs`（24 分钟），只这 6 例变了、多出 `detail`，换上后 `xiyou_zhenqi` 200/200。第二次同步重出 zhenqi.json 后自然消失（同步后复查一眼 `page.default` 有 `detail`）。
- **流萤技能卡**（第三棒，总装追加：流萤运行时清单 13、15；先合了 `cc/wukong-newsrc9` fd0f53b4，冲突只在优化登记两边各加的行，全留）：
  - 15 说明按进阶生成：新 `ui/liuying_help.gd`（`XLiuyingHelp`，照 L.skillLines／refreshText）：10622 天火轰击、10623 完全燃烧按流萤（179）当前进阶重写备注 APs 行（2 阶起天火 8 段；完全燃烧 3 阶冷却 3 回合、加 33% 不进冷却、去掉「消耗：当前全部护盾」、效果改增盾上限 50%；2 阶前加「解锁：进阶2阶」）。接在 `XHelpCard._content` 开头，只改出卡用的拷贝（原版改 $dataSkills，看的也是 179 的阶，结果相同）。原版流萤的 setItem 包装在元素包装之内，会把元素包装删插的「伤害属性」行冲掉，卡上留备注写法「伤害属性：火焰·物理」；照搬（这两张卡跳过 `_element_wrapper`）。新源行为，不设开关。
  - 13 技能名品质色：重制技能页／图鉴的名字本来就按 `XQuality.list_color`（品质）上色，与包装的 QualitiesColor[品质] 逐个相同（14 个技能），不用改；专项里断言。战斗技能窗照旧白字（重制原有口径）。
  - 10623 三阶清空 customCostText：随 DY① 一起做了（见下）。
- **DY① 技能列表自定义消耗文字**（第三棒续，`XSkillScene.custom_cost_text／custom_cost_row`）：YEP_SkillCore `<Custom Cost Display>` 标签间各行相连成 customCostText，drawSkillCost 在 TP／MP／HP 之后右对齐画（drawTextEx：窗口标准字号，颜色按 `\c[n]`），之后留 5。v0.28 起插件就启用、插件文件新旧相同，重制原先漏了，补缺不设开关；数据里只有 10622「5%生命」、10623「全部护盾」两个。技能页 `_costs` 与战斗技能窗 `_list_entry` 都接上（战斗窗用 Olivia 缩放后的字号 21）；技能页的消耗循环改为认 `size`。10623 在流萤三阶起清空（L.refreshText）。参照：`liuying_help_probe.cjs` 加 Window_SkillList.drawSkillCost 逐字记录（0、3 阶），`xiyou_liuying_help` 43/43。消耗先后（总装追加核对）：原版 YEP_X_SkillCostItems 把物品消耗包在 drawTpCost 里最先画，所以由右往左是 物品 → TP → MP → HP → 自定义文字，重制原有顺序就是这样（上一版这里写的「已知差」是看错了，已撤回）。参照加一例 `mix3760`（3760 的拷贝：<Item 1722 Cost: 1>、MP 1500，再加一段自定义文字），专项 `cost.mix_order` 比图标、文字、字号的先后，44/44。
  - 参照：新探针 `mv_oracle/liuying_help_probe.cjs`（进阶 0、1、2、3、再回 0 各量两张卡＋14 个技能名颜色），`tests/fixtures/liuying_help_oracle.json`，新专项 `xiyou_liuying_help` 34/34。
- **参照**：`ui_reference/review_actor_book.js` 多记 `bitmap`（状态窗实际画的图，URL 末段）；上一棒在新源重取时 `sprite` 记的是 battlerName，168、173～177 的逐帧图因此对不上。`actor_book_oracle.json` 只补了 `bitmap` 一键（其余与重取的一致），测试改为图名比 `bitmap`、battlerName 比 `sprite`。
- 测试：`xiyou_actor_book` 跟目录换算（`index_ids().find`）、立绘几何乘 bookScale、截图加 179；`xiyou_actor_book_review` 记 `actor_id()`；`xiyou_help_card` 的 O-049 出售价断言改成量排版之前的行（v0.43 排版把两种价格并成一行两列，原断言一直挂）。

- **DY② 界面旧账**（第三棒续）：翻了审查 40～50 期（没有 44 期）、交接板、变更记录。带编号的界面问题都已销账（40 P3-8、41 visual P3-1/2/4、46 P3-2、49 P3-3）。当场修了一条：`XHelpCard` 装备属性白字判定补认 `rgb(255,255,255,1)`（审查 50 乙档 ui16 注；原版正则 `rgba?\(255,255,255(?:,1)?\)`；开关默认关，不影响默认显示）。其余列表：

| 报告 | 编号 | 问题 | 状态 | 处理 |
|---|---|---|---|---|
| 50 | P2-1 | 手机标题页「导出存档」被触屏存档键盖住 | platform-fix1 已修（dev.376，O-211），待审查；审查建议的触屏点按专项没补 | 归平台／审查 |
| 50 | P2-1 附 | 地图事件打开的整页界面（商店等）原版不出 Save 键，重制仍显示（`map_scene.gd` `touch_save_visible`） | 未修，等手机实测 | 归平台（参照 Mehmet_GhostButtons.js:672） |
| 50 | 乙 ui16 注 | equipment_rows 白色判定少 `rgb(…,1)` | 本单已补 | — |
| 49 | 乙注 | 触屏虚拟键摇杆与确定同时按住各自连发，原版没对过 | 不确定 | 归平台（需参照 GhostButtons 连发） |
| 49 | 甲 6 注 | `direct_title=false` 时标题右下角也写应用名 | 审查说无害，没动 | 可选 |
| 48 | 甲 6 注 | portrait1 图鉴立绘缩放没截图比对 | 不确定 | 需截图参照 |
| 43 | 丙 tail6 注 | 甚尔、镜流说明卡行序没截图对照 | 不确定 | 需截图参照 |
| 45 | 乙 3 注 | ui9 合并解冲突后没补看 | 不确定 | 归审查 |
| 49 | 丙 sync-post028-2 注 | v0.62.12 installOtbRestoreCapRuntime 空数组时让 OTB 崩 | 未查 | 归规则／换源 |

  进度账「界面页面」83.5%（差 0.99 总点）：几次核定都只写「零散页面细节」，没列具体缺口；审查 50 另建议加「跨平台」一行，交 Kyo 定。

### cc_wukong-newsrc10

#### 2026-11-06 【cc·悟空·未经审查】渡鸦施放特效：行动序列里也换成羽毛特效、等动画算上特效；切片角色战斗图逐张比（dev.待定）

- 依据：进度核定 dev.361 第 38 行渡鸦剩的 #4 神话静态大图、#3 屏蔽支。#4：v0.62.12 的 `installNativeRavenMonsterVisual.js`、`installRavenSkillEffectsRuntime.js` 与 v0.28 逐字相同，dev.364 的实测结论（大图被多帧盖掉、只补阵亡透明度）照旧，不用再动。
- #3 抽测：新探针 `mv_oracle/raven_fx_probe.cjs`（真实 BattleManager 行动序列＋Window_BattleLog 显示动画，14 例）→ `tests/fixtures/raven_fx_oracle.json`；专项 `xiyou_raven_fx` 54 项（10122～10127 × 普通／神话＋狩猎：施放特效组数与目标数、R.Fx slash／ring 不画、收割／回响照画的个数次序、每组放够 life 帧、两组同在、封顶 6 组、别人放同一技能不换）。
  - **查出的问题**：重制只在非序列的命中显示（`_show_hit`）里换施放特效；实际战斗都走 YEP 行动序列（`XSequencePlayer`），`_normal_animation` 照放原动画，渡鸦这六招在游戏里看到的是原动画、没有羽毛特效（slash／ring 屏蔽那部分本来就对）。旧代码上 42/54（12 项施放特效缺失）。
  - 修法：`XBattleScene.raven_cast(user, skill, targets)`（V.play：目标去重、脚下往上 clamp(高×0.45,40,100)、施放者头上 48、只留动画第一个音效）；序列的 `_normal_animation` 在「本次技能的动画、渡鸦放样式技能」时调它、不放原动画（同原版 `item.animationId===animationId` 判断）；反射时放技能动画那处同样走它；序列「等动画」把施放特效没放完算进去（isAnimationPlaying 包装）。非序列路径 `_raven_cast` 改用同一函数。照搬原版，不是原版错误，没加开关。
- **战斗图逐张比（工具）**：`mv_oracle/real/actor_sv_real.cjs` 用无头 Chrome 真跑冻结源，切片 162 名每 4 名一场（一批失败就重开页面逐个重量），记主精灵图名、图大小、帧、缩放、偏移、锚点、平滑、影子、站位；结果快照 `real/actor_sv.result.json`。重制侧 `tests/xiyou_actor_sv_compare.tscn`（工具场景，设 `XIYOU_SV_REAL`／`XIYOU_APP`／`XIYOU_SV_OUT` 才比，检查里直接记过）量 XBattlerSprite 身体的同样几项，并把两边用到的图逐像素比（原版 PNG 对 generated 源 PNG）。结果见交付单「战斗图差异表」。

### cc_wukong-newsrc10_接续

#### 2026-11-06 【cc·悟空·未经审查】角色旧账二：SV 归一平滑、停用／隐藏角色、162 诛仙战斗图、人物图鉴跟 v0.62（dev.待定）

- **① SV 归一平滑**（`battle/battler_sprite.gd` `_apply_smooth`，O-待定·SV 归一平滑，`XBattlerSprite.SV_NORM_SMOOTH`）：照 v0.62 `Codex_MiraRavenMultiFrame` v1.06 applyVisual（`bitmap.smooth = !crispScaling || scale<1`，CrispScaling 默认开）：167 号以后有归一档的角色，归一缩放×SvPngFd 小于 1 时身体改 LINEAR，否则最近邻。量具 v0.62 实测正好 168、174、175、179 平滑（0.55～0.72 倍），其余（167、169～173、176～178 放大或原尺寸）不平滑。关掉开关回 v0.28（一律最近邻）。重跑逐张比 `xiyou_actor_sv_compare`：平滑四条差异清零。
- **② 没进出战栏的 5 名定性**（见下表）：不是漏实现，出战栏两边一致。顺带跟进同一批新源插件里重制没做的两处（O-待定·V029 隐藏角色，`XImportedBalance.V029_HIDE_ACTORS`）：人物图鉴目录、角色仓库列表滤掉 V029 隐藏的 7 名（仓库只滤显示，编号留着不丢）；读档时照 `B.migrateParty` 把停用角色挪出队伍与出战栏（`XImportedBalance.migrate_party`，`XState.from_dict` 调）。图鉴目录改成按行取角色（`XActorBook.row_ids`／`cur_id`），仓库取出改按编号删（列表滤过后行号不等于仓库下标）。
- **162 诛仙战斗图是空的（查出来的）**：原版 `guanxi7_1.png`、`小诛仙.png`、`characters/guanxi7_1 (1).png` 是扩展名 .png 的 JPEG，早年原样复制时导入失败留下 `valid=false` 的 `.import`；转换器后来转成真 PNG 了，但 Godot 认旧记录不重导，战斗里 162 没有身体贴图、脸图也空。`xiyou_export.py` 复制图时遇到 `valid=false` 的 `.import` 就删掉（记 issue `resetInvalidImport`），下次导入重做；专项查 generated/img 下没有坏导入。EB 工作树已删掉重导：162 逐张比几何与逐像素都对上（比对场景按内容读原版伪 PNG）。主工作区、集成树那 3 个 .import 由总装处理。
- **③ 零星清单**：DW 交付单末尾的候选（审查 40 P3-11、41 P3-4、42 P3-1～3、45 raven.gd 头注释）**全部已销账**（变更记录 4517、4562、dev.334、dev.336，审查 48 第 36 行）。另找真缺的，做了前 5 条：
  1. 人物图鉴状态页「光环独立栏」（v0.29，Star_ActorsBook drawAllContents）：有 `<CodexAura>` 技能的角色四栏「主动／被动／光环／其他」、栏宽 floor(932/4)、22 号行高 30、超出写「确认查看全部」，武器掌握接在最长一栏下（`status_ops`）。
  2. 技能详情类型「【光环】」（`skillTypeName`，`XActorBook.is_aura`）。
  3. 流萤 179 详情专属段（10622～10632＋全库 `<CodexLiuyingPassive:>`）与「未解锁」灰字（PREVIEW_ACTORS 加 179）。
  4. 流萤图鉴立绘：179 归一档登记 `[128,128,19,12,111,128]`（与战斗 inferProfile 量出的一致）＋图鉴 bookScale 0.8（v1.07，`XAppearance.BOOK_SCALE`，只作用于图鉴）；actor_book 立绘名改按参照记的战斗图名比（参照 `review_actor_book.js` 记的是 `battlerName()`，168、173～177 图鉴画逐帧图）。
  5. `xiyou_actor_p0`：参照 slice_d2 没有 179 时第②段 `d.actors[str(id)]` 脚本出错、测试停住不出结果（基线就这样）；改成跳过，oracle_row_179 两条照记挂，等整份同步。
  - actor_book 从 17/22（CV 重取参照后挂的 5 项：光环标签、主动列宽、新角色立绘、179 技能表、目录名单）到 26/26。

### cc_wukong-newsrc4

#### 2026-11-06 【cc·悟空·未经审查】换源集成：装备说明卡＋难度真气玄 Boss 第一批追平 v0.62.12（dev.待定）

- 22 个场景里 10 个在新源上追平：物品使用、法宝等级、玄战斗、装备公式、公式其余、装备准入、挑战被动、难度敌人、难度敌群、渡鸦法宝。
- 夹具在新源上重出（猫帮助、难度传承、公式其余、法宝成长帮助、法宝等级、玄战斗、敌人读装备公式、装备准入）；后两份原来没留探针，补了 `formula_equipment_enemy_probe.cjs`、`equipment_admission_probe.cjs`（旧夹具的 24／4 例逐条复现，再出新源的 27／4 例）。
- 数量随新源：可用物品 1029→1037、读装备等级的公式 24→27 个技能（336→378 例）、公式其余 31→34 个技能（135→147 例）。
- 难度敌人／敌群第 6 项比 `cnt`：探针读的是 v0.35 起夹到 0～1 的 `cnt`，测试原来比没夹的 `xparam(6)`。
- 挑战被动：新源参照开战读数已含状态特性，不再补加（`ADD_STATE_TRAITS` 开关留着回旧源）。
- 渡鸦专属法宝跟 v0.29 生命／魔法对调：固定 100／350，另加那份从生命改到魔法（`XRaven.artifact_mp_bonus`）。

### cc_wukong-newsrc5

#### 2026-11-06 【cc·悟空·未经审查】换源集成：KyoTier 强弱分类、异化 v0.58 隐藏开关（dev.待定）

- 新 `XTier`（`modes/xiyou/core/tier.gd`，正式 v0.44 `installTierTagsV044` 的 CodexTier）：角色备注 `<KyoTier:超强者／强者>`，有名字没标签的是弱者。超强者名单（`XItemMarks.super_strong_ids`）、强者名单（新 `XPowerBooks.strong_ids()`）、弱者挑战 `is_weak`、难度传承（强弱档与补强档、167 号以后入队）、强者技能替换 `is_strong_classified` 都读它。产物里一个标签也没有（v0.44 以前的源）时各处退回原来的写死名单。v0.62.12 的标签和旧名单不一样：强者多了 121、150、151、153、154、158、178，超强者多了 174、176、177、179，150～158 里五人从超强者降成强者。
- 异化：正式 v0.58 整套隐藏，Kyo 11-05 定重制保持开启。新开关 `XAlienBattle.HIDDEN_V058`（默认 false）；打开时照 v0.58：遭遇、奖励不再出现，工坊打不开。物品隐藏、商店、读档还原、菜单项去掉还没跟（登记 O-待定·异化隐藏）。参照：`hboot` 新增 `opts.skipModules`（`shared/host.cjs` 的 `start({skipModules})` 传进去），`alien_battle_probe`、`alien_affix_probe` 跳过 `installAlienationHide`，量没装隐藏模块的原版行为；`xiyou_alien_battle` 另加默认开启与开关打开两组断言。
- 事件脚本里的 `CodexTier.nonWeakIds()`（公共事件 1345、1443～1445 等）翻译归 A：接口是 `XTier.non_weak_ids()`、`XTier.is_non_weak()`、`is_weak()`、`tier_of()`。

### cc_wukong-newsrc6

#### 2026-11-06 【cc·悟空·未经审查】换源集成：真气 v0.45 神兵试炼与指定道法（dev.待定）

- 照 v0.62.12 `installNativeZhenqiRuntime.js` 改 `modes/xiyou/core/zhenqi.gd`：
  - `weapon_masters`：每类武器只取第一位神兵之仙，敌群须只有它一个且不隐藏，按武器类型排序；新源多了 2005～2009 五位（钝器、斧、太刀……），共 12 位。新 `weapon_types`（有名字、有 `daofa:benming:N` 技能、有该类武器；原版另排 `hiddenGear`，v0.62.12 恒 false）。
  - 神兵试炼菜单每页 4 位，翻页／返回／离开，标签改「［试炼完成］／［已领悟］」，说明三行照新源。`_start_weapon` 按神兵本身（不是序号）开战，先核对仍有效、没有待开的试炼（原版另判 `inBattle`，重制闭关菜单只在地图上跑，不判）。
  - 神兵试炼结算：只记试炼完成（有人活着），**不再给真气**；不顺带降服灵根；`zq_weapon_trial` 敌人经验、金钱为 0（`enemy.gd`），`battle_logic.rewards()` 末尾照原版 makeRewards 包装：幻化之战清空物品（含米拉深渊额外掉落），神兵试炼经验金钱清零。
  - `spec_state`：只有 `weaponTrials` 的旧档补上 `w`；`_learned` 照 learned45（true 或正数）。
  - 灵根解锁再认只给灵根的新备注 `<CodexZhenqiLinggen:…>`，与 `<Element Absorb>` 合并，同元素只提示一次。
  - 指定道法：`_roll_daofa` 掷出的道法存 `pendingDaofaRoll`（随存档，`from_save` 读回），返回、读档都不重掷；本命兵／灵根走 `_pick_specialization`（可指定项每页 4 个、翻页、「随机（X）」、「稍后再选」），`_finish_daofa` 核对后学技能、记 `spec`、清掉 roll；选属性奖励也清 roll（原版 `done`）。
- 第 5 条首领血条（瓶颈之战、神兵试炼、可指定本命兵 Boss）属界面车道（`battle/boss_hp_bar.gd`），没做。
- 测试：`xiyou_zhenqi_break` 的 `flow_weapon_menu` 选项数 9→7（新源每页 4 位＋下一页＋返回＋离开）；新增 `daofa_roll_kept`、`daofa_roll_cleared`（掷出结果读档不重掷、选定后清掉）、`weapon_no_exp_gold`（神兵试炼经验金钱为 0、物品清空）。

### cc_wukong-newsrc7

#### 2026-11-06 【cc·悟空·未经审查】换源集成：真气 v0.45 开关、装备词条与符文之语、流萤遮住 setHp、云裳天丝（dev.待定）

- ⓪ 真气 v0.45 回退开关 `XZhenqi.V045`（默认 true，**O-待定·真气 v0.45**）：false 时五条都回到 v0.28——神兵之仙不按类去重也不分页（菜单按序号 k）、神兵试炼照常记真气、经验金钱不清零、灵根不认 `<CodexZhenqiLinggen>`、指定道法不保留掷出结果也没有「稍后再选」。v0.28 的函数原样留在 `zhenqi.gd` 末尾（`_weapon_masters_v028` 等 6 个，取自 d1b41749）。幻化之战清物品两版都有，不受开关管。
- 装备词条（跟到 v0.62.12 `installIntegratedV029Runtime.js` exclusiveAffix，v0.37／v0.56.01）：名字「天外天·」开头或备注带 `<req_actors:>` 的装备不再当随机词缀（`XGear.valid_affix`，`gear.gd` 和测试模式加速 `test_mode.gd` 两处）。开关 `XGear.EXCLUSIVE_V056`（**O-待定·专武不当词缀**）。原版另有读档把已掉落的专武前缀装备转回普通装备（`U.revertExclusiveAffixes`，v0.57），**没做**：重制存档里有没有这种装备要看玩家，留给下一单定要不要做。
- 符文之语挂起（跟到 v0.62.12 `installNativeRunewordRuntime.js` RW.decide／canGrow，用户 2026-10-27 在原版定）：刚做成的配方若是更长配方的开头、剩余孔位还够镶完，先挂起（`runewordPending` 随装备存档），下一颗没接上或孔用完时再结算。开关 `XRunewords.PENDING_V062`（**O-待定·符文之语挂起**）。原版读档补匹配（RW.catchUp）重制本来就没有，没做。
- 流萤遮住角色 setHp（**原版代码错误**，**O-待定·流萤遮住角色 setHp**）：v0.62.12 `installLiuyingRuntime.js`（模块 33）在 `Game_Actor.prototype` 上另定义了 `setHp`，此后装在 `Game_BattlerBase.prototype.setHp` 上的包装——异化 Runtime（35）、异化 Advanced（37：生命池／嫁祸／空壳／舍身／绝缘）、谷雨（40：归根中抬不起生命）、护盾账本（41）——对角色全都走不到。`XResourceContext.o_actor_sethp_wrappers` 默认 true＝照旧对角色生效（加流萤之前的行为）；false＝照原版跳过。alien_affix、guyu_battle 按 false 比新参照，另加默认值的断言。
- 云裳（跟到 v0.62.12 `installNativeYunshangRuntime.js`）：不朽天丝每场 1→2 份（天丝成锦偶数次多给的也 1→2）；胜利时补记最后没走完的回合的订单进度（v0.49，一击结束的战斗也算 1 格）。开关 `XYunshangOrders.V062`（**O-待定·云裳天丝与订单回合**）。
- reincarnation_entry 夹具按 v0.62.12 重跑 `reincarnation_entry_probe.cjs` 换掉（只有 sourceIdentity 和 8105 知者数 166→167 变）。

### cc_wukong-newsrc8

#### 2026-11-06 【cc·悟空·未经审查】换源集成：专武前缀旧武器读档还原、心钢按回合冷却、SvPngFd 先清再解析（dev.待定）

- ① 专武前缀旧武器读档还原（跟到 v0.62.12 `installIntegratedV029Runtime.js` `U.revertExclusiveAffixes`，v0.57，extractSaveContents 包装）：`XGear.revert_exclusive_affixes`，`XState.from_dict` 读完仓库后调用。v0.37 前掉落、抽到了专武词缀的武器（如「卍解-斩月练习剑」）转回普通装备：原版拿存档里的模板比，重制不存模板，按 `affixIds` 用现在的数据重拼模板 t（底装备＋各词缀＋备注参数）；特效、备注、说明换成底装备那段＋实例在 t 之后追加的，属性＝底＋实例−t（底值不为负的夹到 0），价格同理；名字去掉专武前缀（最长的专武名，找不到按底装备名切）。原版把整份模板换掉，同一件上别的词缀也一起没了、名字里的后缀字留着，照搬。备注解析出的 meta 取底装备的、留实例上不是备注来的键；yep、套装只换回被词缀改过的项。对不上的不动、记进 `last_affix_revert.skipped`。**只跑一次**：改前字段整份存进 `_affixRevert`（随存档），有它的不再处理。只管武器（原版只扫 `_independentWeapons`），背包、身上、仓库都扫。开关同 `XGear.EXCLUSIVE_V056`（**O-待定·专武不当词缀与读档还原**，false＝读档不还原）。
  - 属性浮动的口径：原版掉落掷两次浮动（makeItem 给模板一次、gainItem 登记实例再一次），还原丢掉模板那次、留实例那次；重制只掷一次，t 用不带浮动的模板，所以留下的是这一次（幅度同原版：专武词缀的 Random Variance），强化加的照留。
  - 参照：`equipment_probe.cjs` 加 `affixRevert` 三例（临时放开 isValidItem 造出旧装备，照掉落 gainItem 进背包、可选强化一次，调 revertExclusiveAffixes 量前后；重复执行不变）。为两边可比，前两个随机数取 0（抽中专武 67「卍解-斩月」）、其余 0.5（浮动为 0）。`xiyou_equipment` 照 v0.28 造出同一件，存档往返后比名字、属性、特效、价格、说明、品质，另比开关关着不动、备份字段、再读一次不变。
- ② 心之钢巨人吞噬按回合冷却（跟到 v0.62.12 `installNativeHeartsteelRuntime.js`，v0.35）：第 2 回合可用，施放后冷却 2 回合（`_ready_turn`＝施放回合＋2，剩余＝就绪回合−max(1, 回合数)，开战就绪回合 2），行动结束不再减蓄力。回合数从本场战斗取（`_logic_ref` 弱引用，不让静态变量留住战斗对象）。说明卡冷却行同步成「冷却：巨人吞噬第2回合可用；冷却2回合」。开关 `XHeartsteel.TURN_CD_V035`（**O-待定·心钢按回合冷却**；false＝v0.28 按行动）。
  - `heartsteel_probe.cjs` 两版都能量（有 `H.round` 就按回合设就绪回合、读 `H.remaining`，否则照旧读 `_codexHeartsteelWait`；v0.28 重跑与旧夹具逐字节相同）。夹具 `heartsteel_oracle.json` 换成 v0.62.12 量的，旧的改名 `heartsteel_oracle_v028.json`；`xiyou_heartsteel` 开关开着比新夹具全部例，关掉再比旧夹具的心钢几例（heart.*、suppress.*，标签前缀 v028.）。
- ③ SvPngFd 先清再解析（跟到 v0.62.12 dsPassiveSkill v0.51：refreshPassiveCache 先把 SvPngFd 复位成 1 再解析，状态／装备／技能变了置脏、下一次 refresh 重建，Sprite_Actor.updateFrame 每帧读缓存）：战斗图 `XBattlerSprite._process` 每帧比装备／状态／技能签名（`XSvPngFd.signature`），变了重算倍数、按比例改身体缩放。开关 `XSvPngFd.REFRESH_V051`（**O-待定·SvPngFd 先清再解析**；false＝回到 v0.28 开战算一次）。参照里 `stateMidBattle` 加状态后 refresh 变 2，跟上；`unequipMidBattle` 只 setObject 不 refresh 所以没变，重制换装总会刷新，不比这一条。dsPassiveSkill v0.51 同一处还复位了 harmRe 等别的字段，重制的被动缓存本来每次整份重建，没有累计问题，没动。
- ①补 gear_search 词条来源（总装归到本单）：原版 `getBaseItem` 对随机词缀装备返回 DreamX 生成时的模板（v0.62.12 实测：布腰带实例 baseItemId 指向模板、模板备注带词缀），所以词缀那几行算「固定」。重制原来拿底装备比，词缀行成了「随机 / 附加」。抽出 `XGear.affix_template`（还原和检索共用），`XGearQuery.record` 改用它。`xiyou_gear_search` 加 `affix_lines_fixed`、`added_line_random`（旧代码挂前一条）。
  - **剩的 3 项（sort_power、row_small_power、detail_rows）不是词缀归类**：夹具是 v0.28 手量的，测试把 v0.28「队员死霸装」的备注叠到 v0.62.12 防具 130 上，新源这件闪避、爆伤、passiveHarmRi 从 5 改成 50（导入平衡 revision 2），行对不上底装备、战力 1410 变 2400。要在新源重量 gear_search 夹具（手取、没无头驱动，归界面）。
- 优化登记加三行 O-待定（上面三个开关；专武那行把 newsrc7 的「专武不当词缀」一并写进去，两项同一个开关）。

### cc_wukong-newsrc9

#### 2026-11-06 【cc·悟空·未经审查】换源集成：流萤 179 第一期（招募、公式、伤害钩子、能力值、逐火、学忘）、说明卡 10326（dev.待定）

- 跟到 v0.62.12 `installLiuyingRuntime.js`（v0.60～v0.62.08，见 `冻结后改动盘点_v0.29-v0.62.12.md` 第 104、105、110、112 行）：新模块 `core/liuying.gd`（XLiuying）。
  - 公式 `CodexLiuying.damage(a,b,id)`：转换器 `MODULE_FORMULAS` 把 10622／10623 记成 `liuying`，`XFormulaExecution` 调 `XLiuying.formula`：round((基数＋最大生命×3000＋攻击×3888＋敏捷＋护盾×3888)×0.7)，≤0 为 1。护盾取施放前快照（二期写），没有就取 `XShieldLedger.total`（原版 a.shield getter 含账本）。AI 估值（CodexAIEstimators）接进 `XSmartAI._safe_damage`。
  - 伤害钩子并进 `XActorDamageHooks.capture`；赤染之茧的火元素穿透 33% 写在 `XDamage` 建帧处（`resistancePierceByElement` 不在钩子可写字段里，`XLiuying.pierce_by_element` 取较大值）。物理受伤率穿透原版是 max(原值, 0.33)，流萤这两招别的钩子不写它，重制直接设 0.33。
  - 必中、不闪避在 itemHit／itemEva 最外层（原版第 34 个，在云裳、甚尔之外）；段数在 numRepeats 最外层。
  - 能力值：param 包在云裳夹值之外、异化之内（`XActor.param`），所以 99999999 上限乘过倍率会超（参照 hook.ziXian 249999997）；paramPlus／actionPlusSet 走 `XActorModules`；shieldEffectBonus 加在 `XBattler.shield_effect_bonus`。
  - 逐火：`XBattleLogic.grant` 末尾（gainRewards 包装），存 `state_data._codexLbEmber／_codexLbEmberWins`（随存档）。缺胜场字段时按生命÷10 估一次，估完写入、之后不再重估（总装 11-06 要求，测试覆盖已有胜场不被改写）。
  - 学忘同步：`levelUp`／`levelDown`（`XActorModules`）、`change_level_mv` 末尾（原版包 changeLevel，同级也同步）、读档（`XState.from_dict`，extractSaveContents 包装）；learnSkill 学 10628 连带学梦应（`XActor.learn_skill`）。每次都是按等级、进阶的幂等整理，不是一次性迁移。
  - 招募：公共事件 9043 `CodexLiuying.recruit();`（`XMvScript` 语句分支，超强者门槛同别的角色）；`_RECRUITMENTS`、`_module_recruit`、`XItemMarks.RECRUIT_HORNS` 加 3063→179。
  - 战力：`XPower.formula_ok` 认 `CodexLiuying.damage(a,b,N)`（原版 compileFormula 换成 1）。天火要剑（requiredWtypeId1＝2），新开局的流萤没武器，所以战力覆盖记「当前条件不可用」，不再是「尚未完整评估」（ui-newsrc2 转来的 status_power_panel 那项）。
  - 切片：actors 加 179（Codex_Liuying_SV、头像、行走图随角色导出），extraImages 加 `sv_actors/Codex_Sam_SV`（萨姆形态，二期用；界面 DE 的 actor_book 立绘那项要它们）。
- 说明卡 10326 铸环守：新源 `installDisplayPreferencesRuntime` nowGrowthRows 新加了 10326 一条（护盾系数＝成长权重曲线、保底比例 10%～30%，按屠苏等级），`character_help._tusu_xuan_growth_rows` 补上。同函数里别的条目新源改了措辞（「成长权重」→「护盾系数」等），归界面 DE，本单没动。


#### 2026-11-06 【cc·悟空·未经审查】换源集成：流萤 179 第二期（击破印记、施放流程、萨姆形态与负面免疫免死、萤火印记）（dev.待定）

- 跟到 v0.62.12 `installLiuyingRuntime.js` 第 4～10、14 节，都在 `core/liuying.gd` 第二期一节。参照 `liuying2_probe.cjs` → `tests/fixtures/liuying2_oracle.json`，测试 `xiyou_liuying2`（188 项；挂点没接时 80/188）。
- 施放流程（Game_Action.apply 包装，原版第 34 个，在云裳、饿狼之外）：`XBattleLogic._invoke` 加 `XLiuying.wraps／apply` 分支；本次行动第一次结算时记施放前护盾（`XShieldLedger.total`，原版 a.shield getter 含账本）；天火扣 5% 当前生命（直接改生命，不经账本与原生护盾，同原版 `_hp` 直写）、按实扣量 ×(1＋护盾加成) 加原生护盾；燃烧：三阶加等量护盾（上限 50% 最大生命、不吃加成），否则 `add_shield(−快照)` 只扣原生护盾、账本里队友给的期限护盾保留；回满生命；冷却按自然回合 4（三阶 3、随机 <0.33 免冷却，规则流 `liuying_cooldown`），`meetsSkillConditions` 挡；再释放随机 <0.2（`liuying_rerelease`）整次重放。每段：命中且本行动还没施印就给主目标施印（天火 1、燃烧 5）；天火对其余活着的敌人各结算一次（×0.5）；燃烧只剩一个敌人时额外 4 段（重放再补 4 段）；单目标天火 ×1.2、燃烧 ×1.5。行动帧在 numRepeats（`XLiuying.repeats`）开新帧。
  - 天火付费：总装 11-06 定照原版直接写生命、不走护盾账本（代码注释已写）；账本只用在读施放前护盾上。
- 击破印记：层数记在 `state_data._codexLbMark`，只在带着状态 2787 时有效；满 12 引爆：最大生命×6 真伤（`set_resource`，原生护盾照 setHp 吸收）、强制眩晕 29（`add_new_state` 无视抵抗；霸体＝首领难度霸体免疫；同一目标 2 个自然回合内不再眩晕；眩晕期间 `_refresh_base` 不按抵抗抹掉，`keeps_resisted`）；战斗中、目标没死时移除／清状态挡下（`XBattler.remove_state`／`clear_states`），引爆放行；全队对带印记的目标技能倍率 ×(1＋0.1×层)；受治疗 −10%/层（`XResourceContext.gain` 最外层）。原版另弹「击破印记引爆！」提示，重制战斗日志没有这类提示，没做。
- 萨姆形态与免疫：开战（`setup` 末尾，原 startBattle 移除战斗状态之后）戴法宝加 2788、学了飞萤加 2789／2790；战斗图 `XCostumes.battler_name` 里换 Codex_Sam_SV；负面免疫按 `<BuffType>`（没有时按行动限制或状态名）挡 addState（`XResourceContext.add_state`、`XBattler.add_state`）并在 refresh 末尾清掉绕过的；燃烧后刷新（`end_action`，原 endAction 之后）；结束战斗去掉三个状态、清燃烧冷却（施放前护盾快照原版不清，照搬）。
- 萤火印记（学了梦应 10633）：流萤每次行动第一次掉血（`_set_resource` 生命变少、天火付费）全队叠 1 层（上限 30，开战清零），出战成员加状态 2791，角色行动者终伤 +10%/层。「一次行动」按行动序号比（原版比 BattleManager._action，行动结束不清，同样照搬：行动之外的掉血跟最后一次行动算同一次）。
- **O-待定·流萤燃烧后免死刷新**（原版代码错误，`XLiuying.FIX_UNDYING_REFRESH`，默认 true）：原版 refreshUndying 先移除再附加，同一次行动的结果记着「刚移除」，加不回，燃烧后负面免疫与免死反倒没了（下次燃烧才又加上）。true＝已有的重置回合数；false＝照原版。参照是原版行为，测试关着比参照、开着另查两个状态还在。已登进优化登记。
- firefly 例原来敌人普攻打流萤参照扣 5、重制扣 4：rules 查明是探针没去掉超强者路线压制（承伤 ×1.5，O-050 不移植）。两份探针都加了 `superReference(w)` 重出参照（一期参照没变，二期 5 处改），firefly 例改回逐步比生命，一期 144／二期 188 重跑全过。


#### 2026-11-06 【cc·悟空·未经审查】换源集成：流萤 179 第三期（萨姆残核掉落）、战力条件复核、运行时清单收口（dev.待定）

- 跟到 v0.62.12 `installLiuyingRuntime.js` 第 16 节（v0.62.08＋11-01 补丁）：`XLiuying.core_drops`，接在 `XBattleLogic.rewards` 末尾（`_liuying_core`，每场只掷一次，奖励随机流 `liuying_core`）。倒下的、备注带 `<CodexLiuyingCoreDrop[:下限]>` 的敌人各掷一次；只在地图名以「深渊」开头、或地图备注带同名标签的地图掉；概率按路线（洪荒按诅咒倍率插值），敌人写了下限取较大；不吃掉落率、不经件数上限与品质屏蔽；幻化之战照真气包装整份清掉。具体数值只在代码常量与夹具里。
- 开关 **O-待定·萨姆残核掉落**（`XLiuying.CORE_DROP`，默认 true；false＝不掉），已登进优化登记。
- 参照 `liuying3_probe.cjs` → `tests/fixtures/liuying3_oracle.json`（4 条路线 × 3 张地图 × 3 个敌人的概率），测试 `xiyou_liuying3` 50/50（另查倒下才掷、活着／普通地图不掷、开关关掉不掉）。这一期没动存档字段，测试是和实现同一提交写的，没先单独挂一次。
- ② status_power_panel 179「天火轰击」：一期已顺带修好（`XPower.formula_ok` 认 `CodexLiuying.damage`，新开局没剑记「当前条件不可用」），本期复跑 11/11。


## 原 newsrc2 做了什么（都在本树验证过）

- `battler.gd` `param_state()`：按 v0.62.05 每个状态只乘自己的层数（`counter.carry` 2420→220）；`xiyou_state_js` 注释跟上。**只在换源时成立**，旧源上会挂 counter.carry。
- `event_presets.json`：删掉 795 个挂在深渊商人旧第 3 页（`p2`）上的变体（v0.30 起深渊商人改成脚本 `CodexAbyssMerchant.openCurrent`，那一页在新源不存在；改到新脚本页只会量一句脚本调用，重制还没跟这个运行时，留给期一跟深渊商人时再加）；Map004 EV069 的 3 个变体跟到 `p1`（v0.62.12 前面插了一张空页，内容逐条相同）。同样只在换源时成立。
- 来源核验（`battle_event_contract.py`、`formula_effect_contract.py`）：敌群事件目录数、装备等级公式块数改成按冻结源版本查表（v0.28：35／47、24；v0.62.12：51／73、27），没登记的版本报错。旧源核验照旧通过。
- 同步换源工具（`同步正式西游.py`、`oracle_additions.py`、`生成接受单.py`，测试在 `测试合并工具.py`）：
  - 同步加 `--accept-source-switch <版本>`：只有本轮确实从别的版本换到这个版本时，才不要求旧输入原样存在；测量变化照旧要接受单逐条（或整组）接受。版本号对不上不生效。
  - 删掉的用例／地图／角色、没有稳定键的顶层列表字段，现在也出变化候选，但标 `switchOnly`，**只在换源时**接受单才认；平时行为不变。
  - 接受单可按「文件＋集合」整组接受（`key` 写 `*`、`fields` 写 `["*"]`，摘要取全组 [键, 摘要] 排序后的摘要，多一条、少一条、任一条不同都对不上；只在换源时认）；`生成接受单.py --grouped` 出这种草稿。换源有 33 万条单条改变，逐条写接受单要八十多 MB。整组扣问题改成按计数一次扣（逐条 `list.remove` 是平方级，33 万条要跑很久）。
- 转换器：原版有两首 bgm 的 `.ogg` 其实是 MP3（`fade to black`、`Number One`，新源切片才用到），Godot 按扩展名导入失败、同步的导入步骤会因此判失败。转换器按内容存成 `.mp3`，`XDB.audio_path` 先找 `.ogg` 再找 `.mp3`。旧源切片不引用这两首，旧产物不变。

## 总装合并（换源那次，集成分支全绿后）在本机要做的

照[换源操作单](../../03_再刷重制_Godot/02_内容与素材/冻结正式源/换源操作单_v0.28-v0.62.12.md)，补上本分支新加的开关：

1. 没有别的同步在跑（`pgrep -fl 同步正式西游.py`）。
2. 切链接：
   ```
   cd /Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源
   chmod u+w app.nw && mkdir v0.28 && mv app.nw v0.28/app.nw && chmod a-w v0.28/app.nw
   ln -s v0.62.12/app.nw app.nw
   cat app.nw/data/ContentVersion.json
   ```
3. main 上同步：`python3 03_再刷重制_Godot/03_转换工具/同步正式西游.py --accept-additions --accept-source-switch v0.62.12 --accept-changes 03_再刷重制_Godot/04_验证/测量接受/cc_wukong-newsrc2.json`。整组摘要是对着本树当时的 main 基线算的；main 产物这期间变过，第一轮会报「接受单对不上」（探针结果已进缓存，不白跑），用本轮报告重出：`python3 03_转换工具/生成接受单.py --grouped --report <本轮同步报告.json> --out <新接受单>`，理由照抄本接受单（按文件对应），再跑一次（只比较，几分钟）。
4. `配方转换.py`、`插件备注覆盖.py`（操作单第 3 步），然后全量 `检查.sh --oracle`。
5. 来源登记：`00_项目管理/来源登记.json` 的 `legacy_xiyou_mod_kyo`：`confirmedReleaseVersion` → `v0.62.12`（同步登记时自动写）；`frozenCopy` 不变，加 `frozenCopyTarget`: `03_再刷重制_Godot/02_内容与素材/冻结正式源/v0.62.12/app.nw`、`previousFrozenCopy`: `03_再刷重制_Godot/02_内容与素材/冻结正式源/v0.28/app.nw`；`fingerprint` 换成本轮同步写的来源清单；`note` 追加一句换源说明（操作单原文）。`冻结正式源/README.md` 第一段与目录说明改写，AGENTS.md「正式源默认仍读 v0.28」那句改掉。
6. 回退：`cd …/冻结正式源 && rm app.nw && chmod u+w v0.28/app.nw && mv v0.28/app.nw app.nw && chmod a-w app.nw && rmdir v0.28`，再跑一次同步（回到 v0.28 测量）；本分支的 `param_state()` 与删预设要一起回退（`git revert` 对应两个提交）。

## 接续要点（给下一位）

- 本树 generated 现在是**新源产物**（转换＋96 个探针，第二轮同步留在 `04_验证/本地结果/自动同步/20261106_041418_537721_v0.28-v0.62.12/`）。第二轮同步核验当时没过（两条契约，已修），所以探针缓存没提交；下一轮同步仍会整轮重跑（约 3.5 小时，机器满载时更久）。
- `.sandbox/` 里 event_states 是新源 5038 个变体的结果。
- 云端快照 `refs/ci/generated/cc/wukong-newsrc2` 是新源产物。

## 可优化（流程／工具／效率）

- 已做：整组接受按计数扣问题（见上）。
- 建议（归工具车道，已报协调者）：同步里某个探针失败时，已经成功的探针结果也提交进缓存（现在只有核验通过才提交，一个探针挂就要整轮 3.5 小时重跑；本车道因此白跑一轮）。归工具车道。
- 建议：event_state_probe 在同步里也走 BO 的分段并行（现在只有 `补跑事件状态探针.py` 分段；新源 5038 个变体单进程约 70 分钟）。

## 待交叉核查

- `battler.gd`（战斗核心，`param_state`）、`同步正式西游.py`／`oracle_additions.py`／`生成接受单.py`（接受边界放宽只在换源时）、两份契约、`xiyou_export.py` 音频扩展名、`xdb.gd` `audio_path`、`event_presets.json` 删 795 条。

## 验证

- `测试合并工具.py` AdditionTests／AcceptanceDraftTests／SyncRegistrationTests 全过（新加换源、删除、整组接受、`--grouped` 用例）；`工具回归.py` 全过；`语法检查.py` 0 问题；新源 Godot 导入无错误。
- 新源同步 96 个探针全部成功；离线接受单验证见上。
- 云端整轮 431 场景：242 过、189 挂（见上，是没跟的内容，不是工具问题）。

## 本分支提交

- 见 `git log main..cc/newsrc-switch`
