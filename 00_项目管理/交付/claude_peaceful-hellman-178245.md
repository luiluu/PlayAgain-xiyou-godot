# 交付：claude/peaceful-hellman-178245

- 车道／工作者：B 界面／C 规则／八戒（Claude，重制_八戒_17，接重制_八戒_16）
- 状态：进行中——代码与测试已完成，交付前同步与 `检查.sh --oracle` 在跑。
- 车道位置变更：本批改在 worktree `.claude/worktrees/peaceful-hellman-178245`、分支 `claude/peaceful-hellman-178245` 完成（本会话不能写八戒原工作区）。原分支 `claude/bajie-zhenqi3`（worktree `bajie-shop-stock`）停在 787bce4，是本分支的祖先，内容已全部在这里；该工作区还留着两处未提交的测试改动（xiyou_zhenqi.gd、xiyou_zhenqi_break.gd），与本分支 d298e66 相同，可直接丢弃。合并本分支后两个分支与两个工作树都可清理。

## 变更记录草稿

## 2026-10-18 【Claude·八戒·未经Codex检验】真气第三批：道法运行时效果、神兵试炼、降服含隐藏成员（dev.待定）

- 道法接在战斗者上（XBattler 按特性、XActor 加道法与 dsPassiveSkill 标签）：连击普攻段数＋1、分神必定再动＋1、灵台／passivePRETP 保留 TP、护法／passiveSUBS 掩护（BattleLogic._invoke 换目标）、护法减伤与元婴护体（XZhenqi.hp_damage，战斗中扣血前）、破甲 passiveATKST2705 与「破甲·真气」双防倍率 1−0.5×scale。金身的护盾加成先给出 XZhenqi.shield_effect_bonus（Godot 尚无护盾系统）。
- 顺带补上通用机制：普攻附加状态的几率原先漏乘 attackStatesRate（特性 32 的值），现照原版乘；passivePRETP（26 个技能）、passiveSUBS（2 个）、passiveATKST（5 个）原先在 Godot 不生效，现生效。
- 神兵试炼：闭关首页「神兵试炼」进 7 位神兵之仙列表（［试炼完成］／［已领悟·未完成试炼］、返回、离开），对手＝修行进度层守层者 ×2，不能逃、可以输；打倒神兵之仙才记本命兵可指定与试炼完成（随存档），野外击败不算；打完不回菜单。替换掉原来的「尚未开放」提示。
- 降服时含隐藏成员：胜利结算把没出场的隐藏成员也算进灵根降服与 Boss 胜利（原版 $gameTroop.members()）。正式数据里目前没有隐藏 Boss，用合成例验证。
- 优化 O-048：被动掩护要能行动（原版倒下的护法仍替队友挨打）。
- 验证：zhenqi_probe 245→301 例（新增 daofa.*、weapon.*、hidden.* 56 例）；新测试 `tests/xiyou_zhenqi_daofa` 68 项全过（逐例对照＋BattleLogic 接线、存档、闭关里打一场神兵试炼）；xiyou_zhenqi 181、xiyou_zhenqi_break 83 全过；检查.sh --oracle：（待填）
- 提交：a3915f8、787bce4、d298e66、（交付提交）
- 已知：金身要等护盾系统；隐藏成员不掷神话（提示名不带【神话】前缀，原版隐藏成员也会掷）；日后实现敌人出现（335）时 troop_members 要去重。

## 交接板

- 下一步：删掉「真气第三批（八戒）」一项；真气剩下的是金身护盾（随护盾系统）与区段里程碑／下一步建议。
- 用户试玩说明：闭关里的「神兵试炼」可以打了，打赢后领悟本命兵时能指定那种武器；学了连击、分神、灵台、护法、破甲、元婴的角色战斗里能看到效果（多打一下、多动一次、TP 保留、替濒死队友挡刀并减伤、致命伤留 1 血、普攻破防）。
- 需要用户决定：O-048（倒下的护法不再掩护），见[优化登记](../../03_再刷重制_Godot/00_设计/优化登记.md)。

## 进度账

- 养成与周边系统：10% → 12%（初值，待沙僧复核），真气三批里剩金身护盾与修行指引。

## 本分支提交

- ff55491 开工准备（八戒_16）
- a3915f8 zhenqi_probe 补第三批参照用例
- 787bce4 Godot 初稿：道法接线、神兵试炼菜单、隐藏成员
- d298e66 xiyou_zhenqi_daofa 逐例对照，O-048
- e6db8a1 合并 main（只含文档）
