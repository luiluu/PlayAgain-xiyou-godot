# 交付：cc/review-18

- 车道／工作者：审查／cc（审查）
- 状态：可合并
- 基线：从 main `7d72dd80`（dev.256）切出，只加报告和本交付单。

## 变更记录草稿

## 2026-11-01 【cc·审查】核查 第五批：批量丹药、甚尔二至四期、云裳一二期、谷雨一期、战斗日志／批量抽奖／道具回背包、工具 29／30

- 核查覆盖：cc/nezha-bulkpills1b（f2b98e93）；收尾 d2e1d6ae；cc/nezha-tools29（8e8e791d）；收尾 08f3a017；cc/bajie-toji4（d7ce03b4）；收尾 917c5ff9；cc/bajie-toji2；cc/bajie-toji3；cc/bailong-yunshang2（42e3ff69）；收尾 dd322673；cc/bailong-yunshang1；cc/bajie-guyu1（cb880386）；收尾 9c8157df；cc/wukong-battlelog2（fe139874）；收尾 c5c74152；cc/wukong-battlelog1；cc/wukong-casino1；cc/wukong-itembag1；cc/nezha-tools30（50e7d346）；收尾 7d72dd80
- 结论：P1 无；P2 一条、P3 三条，其余通过。总装九手解的冲突（`_damage_value`、`_apply` 末尾、itemEva／itemHit、伤害钩子 ops、actor_modules、help_card、切片）逐处对过原版装入顺序，都对；收尾补的 guyu_probe 进 PROBES、airship_view 等 3 帧也都对。P2：甚尔「学暴君清弱化」（`XToji.CLEAR_DEBUFFS`）没进优化登记，收尾把它也换成了 O-131，现在一个号两件事。P3：云裳战斗指令栏缺 `BATTLE_SKILL_TYPES` 174［2,1,5］；镜流／黄泉必中打影速甚尔时闪避次序和原版不同（碰不到）；谷雨没包 itemEva／itemCri（现在无差异）。详见[报告](核查报告_20261101_审查第18期.md)。
- 验证：对着冻结 v0.28 读 diff；Godot 临时脚本验证 `+` 的求值次序；本地并行测试 32 个场景全过。

## 交接板

- 下一步：P2 给暴君清弱化补一个新优化号，toji.gd、xiyou_toji_battle.gd、变更记录 toji2 段里的 O-131 改过去（文档和注释，八戒顺手做）。P3-1 云裳指令栏加 `174: [2, 1, 5]` 并补一例（悟空或白龙）；P3-2、P3-3 记进遗留，P3-3 等谷雨第二期顺手补。
- 用户试玩说明：无（只改文档）。
- 需要用户决定：无。

## 进度账

- 无变化。

## 优化登记草稿

优化登记草稿：无

## 可优化（流程／工具／效率）

- 合并收尾把 O-待定 换成正式编号时，按交付单「优化登记草稿」逐行对应来换，不要整文件替换：一张交付单（或一个文件）里有两条 O-待定，整文件替换就会把两条都换成同一个号（本期 P2）。合并工具可以在收尾时数一下：一个文件里 O-待定 的出现处要是对应多条登记草稿，就停下提示。

## 本分支提交

- 见 `git log 7d72dd80..cc/review-18`。
