# 交付：luiluu/t235

- 车道／工作者：文案·测试／小A（T235 序章两句台词改 D219 Q6；Hydrogen＋medium，职级 P7，因为是玩家可见台词，由小A 执笔）
- 状态：可合并

## 一句话

按 Kyo 11-19 09:18 原话及主线大纲 v0.2 第 0 节 Q6，替换战争／瘟疫／饥荒／死亡四条线 JSON 里的序章选线与 36 层通关卡结尾两句台词，并同步更新全仓引用旧句的 4 处测试断言。

## 改动文件

- 改：`modes/xiyou/tianqi_data/war_line.json`、`plague_line.json`、`famine_line.json`、`death_line.json`
  1. `scenes.choose[1]` 小小鱼：「这次的世界我想再改一次，你帮我验收。」→「这方天地已经烂透了……我还不死心。我进不去，只能托付给你了。」
  2. `scenes.final_win` 末句旁白：「已完成，已验证。（未经姐姐复核）」→「第一重封·已破。（彼岸未允）」
- 改：`tests/xiyou_tianqi_war.gd`（第 149、235 行）、`tests/xiyou_tianqi_summit.gd`（第 247 行）、`tests/xiyou_tianqi_ending.gd`（第 165 行）旧句断言同步改用新台词子串（「托付给你」「彼岸未允」）。

## 变更记录草稿

## 2026-11-19 【小A·T235·未经审查】天启篇序章两句台词调整（D219 Q6）（dev.待定）
- 按 Kyo 11-19 09:18 口径将四线（`war_line.json`、`plague_line.json`、`famine_line.json`、`death_line.json`）选线后小小鱼台词润色定稿为「这方天地已经烂透了……我还不死心。我进不去，只能托付给你了。」，`final_win` 末句改为「第一重封·已破。（彼岸未允）」。
- 同步更新 `tests/xiyou_tianqi_war.gd`、`tests/xiyou_tianqi_summit.gd`、`tests/xiyou_tianqi_ending.gd` 共 4 处旧台词断言；全仓 `grep` 确认无「你帮我验收」「未经姐姐复核」残留。
- 玩家可见：天启篇四条路线选线后小小鱼的委托台词、以及 36 层骑士战胜利后的结尾文本调整为新定稿。
- 验证：四线专项 `xiyou_tianqi_war` 97/97、`xiyou_tianqi_plague` 98/98、`xiyou_tianqi_famine` 96/96、`xiyou_tianqi_death` 93/93，以及 `xiyou_tianqi_summit` 78/78、`xiyou_tianqi_ending` 24/24 全过；`语法检查.py` 1059 个 `.gd` 0 问题。

## 交接板

- 下一步：合并进 `main`（无遗留）。
- 用户试玩说明：天启篇选线后与 36 层首领通关结尾的文本已更新。
- 需要用户决定：无。

## 进度账

- 纯文本与测试断言微调，不改进度百分比。

## 可优化（流程／工具／效率）

- 无。

## 本分支提交

- 2cda2aeee T235 序章两句台词调整（D219 Q6）
