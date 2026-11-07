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
