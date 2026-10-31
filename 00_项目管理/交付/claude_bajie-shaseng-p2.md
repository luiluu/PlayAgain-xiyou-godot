# 交付：claude/bajie-shaseng-p2

- 车道／工作者：C 规则／八戒（Claude，八戒_91，Opus／medium）
- 状态：可合并
- 本分支从 claude/bajie-alien-leftover 末端 f502ac55 切（唐僧交代），只加这一张交付单；请在 bajie-warehouse、bajie-alien-leftover 之后合。

## 核对结果：派的四条都已被后来的批次修掉，本期没改代码

逐条先找核查报告里的原版证据，再对现状与修复批次的参照、断言：

| 条目 | 原版证据（核查报告） | 修掉的批次 | 参照与断言（本分支上复跑通过） |
| --- | --- | --- | --- |
| S1 跳跃中存档丢计时与高度 | 清积压第六期 S1／P2：Map004 EV7 强制路线跳跃 (0,2) 推进 4 次后存读档，原版保留 count=12、peak=8、height=24、jumping，重制变成 0／0／0／false | dev.213（悟空，da62d867「事件跳跃到一半存档，读档后保留跳跃峰高／剩余帧及停步、动画计数」），审查第 3 期已核（f3b38ad7） | `xiyou_save_events` 31/31（跳跃存读档用例） |
| W1 无法行动时强制普攻仍触发武器解放 | 清积压第七期 W1／P2：角色 6、武器 207、眩晕 29 强制行动，原版 canMove 假、不掷、执行技能 1；重制换成 127、掷 1 次 | dev.225 第 3 条（八戒_90，3757904a，`weapon_unleash` 加 `can_move`） | `weapon_unleash_probe` 的 `state`、`w207.stunned`；`xiyou_weapon_unleash` 963/963；当时反向验证去掉 `can_move` 2 项失败 |
| 行动无效时行动结束状态提前消失 | 清积压第十期 P2：敌群 70 首敌没有可用行动，状态 5 剩 1 回合，原版 processTurn 连调两次后仍在、endAction 0 次 | dev.225 第 4 条（八戒_90，e1d3efa1，`battle_logic.act` 的 `started` 判断） | `attack_query_probe` 的 `skip.enemy73-state`、`skip.enemy1-mp-short-state`；`xiyou_attack_query` 381/381；当时反向验证 4 项失败 |
| P2-1 异化 ready 攻击固定为 1 | 交接板（沙僧 review-pending，claude/bajie-forge2／2d7b3b1）：原版演员 154＋武器 77 攻击 5769、逆骨未就绪 | dev.196（attack-query 期一，65bbc383：`XBattler.attack_skill_id` 统一查询，接上逆骨／祈祷就绪） | `attack_query_probe` 的 `154-weapon77`（逆骨未就绪）等 154 号各例；`xiyou_attack_query` 381/381 |

## 变更记录草稿

## 2026-10-31 【Claude·八戒_91·未经审查】沙僧积压 P2 四条核对：都已修（dev.待定）

- 唐僧派的沙僧第六～二十一期 P2 四条（S1 跳跃存档、W1 武器解放、行动无效状态时机、P2-1 异化就绪攻击）逐条对核查报告的原版证据核对，都已在 dev.213、dev.225、dev.196 修掉并有原版参照与断言，本分支上复跑 `xiyou_save_events`、`xiyou_weapon_unleash`、`xiyou_attack_query` 全过。本期没改代码，只交核对单（见交付单表）。

## 交接板

- 下一步：「沙僧第六～二十一期交回 Claude 的问题」一条里 S1、W1、行动无效三项划掉（dev.213／dev.225 已修）；「P2-1 异化 ready 攻击固定为 1」一条划掉（dev.196 已修，参照 `attack_query_probe` 154-weapon77）。那一条里其余项（Q1／Q2 星级仓库等）以各自交付为准：Q1、Q2 已在 claude/bajie-warehouse 处理。
- 用户试玩说明：无变化。
- 需要用户决定：无。

## 优化登记草稿

无。

## 进度账

- 无变化。

## 可优化（流程／工具／效率）

- 建议：交接板的遗留清单已经两期派下来都发现早被修掉（异化遗留、这四条）。派单前可以让车道先花几分钟对 `git log --grep` 与交付单核一遍再定范围，或合并工具在并入交付单时，把变更记录里写了「沙僧第 N 期 X／P2」的条目自动去交接板划掉（归工具车道）。

## 验证

- `xiyou_save_events` 31/31、`xiyou_weapon_unleash` 963/963、`xiyou_attack_query` 381/381（本分支，并行测试本机）。没改代码，不跑同步与其他选测。

## 本分支提交

- （本提交）交付单：四条核对，可合并
