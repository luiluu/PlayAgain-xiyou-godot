# 交付：cc/kotori-firepower

- 车道／工作者：玩家反馈修复／cc（线程，五河琴里火力值）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·未经审查】五河琴里攒不了火力值：行动序列补上 CHANGE VARIABLE（dev.待定）

- 玩家反馈（v0.01.07 原版档）：五河琴里（159）火力值一直是 0。
- 原版：火力值是变量 1510，在技能备注的 YEP 行动序列 target 段里改（YEP_X_ActSeqPack1 actionChangeVariable）：连珠炮 10055、炎舞 10058 每个目标打完 `change variable 1510 += 100` 再跑公共事件 1712／1709（≥500 夹到 500、正好 500 学爆发技 10559／10561，有架势状态再学 10056／10057）；聚合炮 10056、毁灭之炎 10057 `-= 500`。全部 Skills／Items 只有这四招用到 change variable。
- 重制：`action_sequence.gd` 把 CHANGE VARIABLE 当画面指令跳过，变量从没改过，所以攒不了、爆发技也学不到。跟天启篇无关：原版档 XDB.rec 走原表（XTianqiSkills.rec 要 cards_on），发行空壳不影响这条路。
- 改：`XActionSequence._change_variable` 照 actionChangeVariable（= += -= *= /= %=、`VARIABLE Y`；右边只认数字，别的 eval 写法记 unknown），set_variable 照 MV 取整。开关 `XActionSequence.CHANGE_VARIABLE`（false＝旧重制，跳过）。
- 测试：新 `xiyou_kotori_firepower`（18 项：序列原文、炎舞／连珠炮每目标 +100、聚合炮 -500、各运算、完整 act＋run_events 后 CE1709 夹 500 并学 10559、回退支）。
- 玩家可见：五河琴里放连珠炮／炎舞能攒火力值，攒满 500 能用爆发技。

## 交接板

- 下一步：进 v0.01.08 在线更新（只改 GDScript，可补丁）
- 用户试玩说明：五河琴里放连珠炮／炎舞后右上角提示当前火力值，满 500 学到爆发技
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- 语法检查通过；选测.py 列的 11 个场景全过：xiyou_kotori_firepower 18/18、xiyou_action_sequence 117/117、xiyou_boss_sequence 8315/8315、xiyou_battle_common_events 95/95、xiyou_tianqi_skills 231/231、xiyou_event_compare(a～d)、xiyou_rules10、xiyou_sve_visual；另跑 xiyou_combat 36/36。
- 待交叉核查：`battle/action_sequence.gd`（战斗核心，甲档）。

## 本分支提交

- 见 git log
