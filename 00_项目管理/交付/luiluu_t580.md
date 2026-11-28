# 交付：luiluu/t580

- 车道／工作者：T580 六维输出补算角色模块收尾追加（cc，claude-opus-5-5＋medium，P8；接 T558 量具）
- 状态：进行中

## 变更记录草稿

## 2026-11-28 【cc·T580·未经审查】天启篇六维：输出整次施放再收角色模块收尾追加（渡鸦收割／回响、饿狼追击、宿傩追斩、镜流追加段等），全库三种子重量重出 six_dim.json（dev.待定）

- 依据：Kyo 11-27 事项 83「算，另开小卡补，不挡这次合」；T558 R4 交付单「要 Kyo 看（R4）」第 2 条。口径追问两次由协调定（下「口径」节）。
- 量具 `tests/virtual_player/t445_book_probe.gd`：`--act-tail` 在 execute 之后先跑 `_module_tail`（照 `XBattleLogic.act` 收尾次序：屠苏 end_action、璇 end_action、谷雨／狂妄／心钢记账、饿狼 finish、宿傩 finish、五条悟 finish、黑闪 finish、镜流 j_finish、甚尔 finish、渡鸦 finish、云裳 finish、小猫 end_action、流萤 end_action），再跑 R4 已有的词条再释放、技能卡追加。模块段全收、不按技能号剔；条件倍率：挂在已算过倍率的招上照那招，其余记 1。保险：模块段单段超被量主招单段 10 倍的单列 `tail_suspect` 不计入（全库 0 段）。不走 hit 日志的模块伤害另收：渡鸦 `_direct`（type regen 带 raven 键）、云裳 `derived`（type yunshang_derived）。
- 强制量条件全中（`--cond-full`）再摆模块收尾门槛（`_prime_module`，不超实战上限）：渡鸦残响 3（上限 3）＋狩猎（残响满 3 且学会 10133，同游戏 `_add_residue`）＋神话形态 3 回合（变身时游戏就置 3；要学会 10127）；饿狼目标解析 3 层（`add_analysis` 上限 3，追击要等于 3）。
- 新开关：`--no-module-tail`（回 R4 口径）、`--no-module-prime`（不摆门槛）、`--race-tail`／`--weak-tail`（种族收尾、弱者专属词条派生，只作对照，缺省不收）。
- `07_开发环境/六维打分.py`：认 `tail_suspect` 记名单、报告第 0 节前列出；文件头和实测数据说明补 T580 口径。
- 重量：本分支 0215b2bba，炼狱探针 `--book-build=lianyu --noisy --seed=1/2/3 --force-all-tiers --cond-full --act-tail` 全库 156 人×3 种子（6 片，每种子 151 人有量数，全部 invalid=false、违规 0）；`--lianyu … --write` 重出 `six_dim.json`、实测数据、报告。面板、生存照旧。
- 六维专项跟表（钉住的 10 人里东方教主输出 B→D，是 main 漂移，不是模块）。
- 玩家可见：天启篇角色图鉴六维字母相对 R4 表 29 人变（全在输出一维；其中模块收尾带来的只有英雄猎人 S→SS，其余 28 人是 T558 量数之后 main 合进的技能改动带来的，见下「字母变动」）。

（待补：种子 3 对照轮跑完后填「字母变动归因」「若收种族／弱者词条会怎样」）
