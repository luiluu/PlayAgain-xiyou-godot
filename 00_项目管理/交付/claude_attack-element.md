# 交付：claude/attack-element

- 车道／工作者：C 规则／八戒（Claude，八戒_44）
- 状态：可合并

## 变更记录草稿

## 2026-10-22 【Claude·八戒·未经Codex检验】普通攻击空手另加物理属性，154 夏娜／158 炮姐的伤害与原版对齐（dev.待定）

- 做了什么：
  - **原因**：原版 `Game_Actor.attackElements`（冻结源 `js/rpg_οbjects.js:3970`）在角色没装武器时另加空手属性物理（`bareHandsElementId`＝1）；`installDamageElementRuntime.js:59` 的 `actionElements` 对普攻（elementId −1）直接用这份列表，多属性时取对目标最有利的一项。154 夏娜（角色特性 31 火 2）、158 炮姐（雷 5）初始不带武器，空手普攻在原版是「火＋物理」「雷＋物理」，Godot 只取了火／雷，遇到抗火、抗雷或被克制的敌人就少约 28%（悟空_35 记的 xiyou_rules 原版 2104 对 Godot 1516）。`installImportedBalanceRuntime.js` 没有改写 `attackElements`，与此无关。
  - **修复**：`XActor.attack_elements()` 照原版在没装武器时补 1；`XBattler.attack_elements()`（Game_BattlerBase 口径）只取特性 31、可为空，去掉原来空集时补 [1] 的兜底——原版无特性 31 的敌人（465、926、947、1999）普攻无属性，带武器但武器和角色都没有特性 31 的角色也是无属性。`damage.gd` 未改。
  - **参照**：新探针 `03_转换工具/mv_oracle/attack_element_probe.cjs`（13 例，产物 `attack_elements.json`，已登记同步探针表与只增接受键）：154／158／1 号 × 裸装与各自能装备、不替换普攻的物理／无特性 31／火／雷武器，记 `attackElements`、`getItemElements`、是否空手，普攻公式在内存固定 1000000、去浮动后对三个属性抗性不同的敌人量 `makeDamageValue`；另记 4 个无特性 31 敌人的普攻属性。
  - **测试**：`xiyou_attack_element` 66 项逐例比对属性列表与伤害；把补 1 那行临时关掉时空手各例全部失败（伤害 15630 对 19538 等），证明测试能拦住回退。
- 验证（按规则车道不跑全量，只跑相关专项；合 main（含 0a5ec4c 转换器、36696e3 切片）后 `新建工作树.sh --补齐`，在工作树跑 `同步正式西游.py --accept-additions`：测量不变、核对 0 问题、留指纹；新探针 `attack_elements.json` 在 main 的基线里是新增，总装合并时的同步应只增这一份）：`并行测试.py` 30 个场景全过——`xiyou_rules` 12 段（每段 124433～124498 项）、`xiyou_attack_element` 66、`xiyou_actor_p0` 3124、`xiyou_wtype` 15378、`xiyou_smart_ai` 四份、`xiyou_settlement` 11、`xiyou_imported_balance` 273、`xiyou_orbs` 63、`xiyou_review_fix` 60、`xiyou_review_fixes` 16、`xiyou_combat` 34、`xiyou_battle*` 五个，无偶发。xiyou_rules 各段 321～342 秒，超过 300 秒提示线（负载 8～16 下），与以前「390～420 秒以后再拆」的遗留相同，未拆。
- 提交：be7c993、0481458（测试 uid）。
- 未完成／已知问题：
  - 154／158 还没加回切片与招募表，按分工由悟空加回（不碰 `xiyou_slice.json`）；加回时 xiyou_rules 12 段的普攻行应与原版一致。
  - 探针没量到「带武器、武器和角色都没有特性 31」的角色（切片里找不到能装备这类武器的人），这一支只按源码改；敌人这一支有参照。

## 交接板

- 下一步：0 条「待补角色」处：154／158 剔出原因（空手普攻缺物理属性）已由八戒修复，可由悟空加回切片与招募表。
- 用户试玩说明：没装武器的角色普攻按「本属性＋物理」里对敌人最有利的一项算（夏娜、炮姐空手打抗火／抗雷的敌人不再吃亏），与原版一致。
- 需要用户决定：无

## 进度账

- 战斗规则：不单独加点（修复既有规则偏差），交沙僧复核

## 本分支提交

- be7c993 普通攻击空手另加物理属性；attack_element_probe 参照 13 例与逐例测试
- 0481458 xiyou_attack_element 测试 uid
- b955941 合并 main
- 二期工具提交另见 [claude_attack-element_工具P3.md](claude_attack-element_工具P3.md)
