# 交付：cc/review-70
- 状态：可合并
- 车道／工作者：cc（审查，GH2）

只有文档，没有游戏代码。

## 变更记录草稿

## 2026-11-09 【cc·审查】核查第十六批六条（审查第 70 期）

- 核查覆盖：cc/tools-troop-shards、cc/rules-gaps7、cc/ui-hide-power、cc/wukong-floor10b、cc/tools-compare-split、cc/tools-probe-tags
- 报告：`核查报告_20261109_审查第70期.md`。P1 0、P2 2、P3 3。
  - P2-1：随机遇敌全灭不进游戏结束（map_scene 700 行不看战斗结果），队伍 0 血留在地图上；O-244 只接了事件战斗 301 和 353。
  - P2-2：解释器 301 输了调 game_over() 没 await，游戏结束画面盖着时地图放开，实测人能走、地图事件能跑。
  - P3-1：troop 分片的变更记录条目没有标题，正文写「默认 4 段」，跟收尾改的默认单进程相反。
  - P3-2：ui-hide-power 往仓库根目录提交了空文件 sel.txt。
  - P3-3：floor10b 删 ce1431 预设还在主工作区未提交，本期没核。

## 已核／未核清单
已核：甲 cc/tools-troop-shards、cc/rules-gaps7（含总装手补 804e0b17、9e679c5f）、cc/ui-hide-power、cc/wukong-floor10b；乙 cc/tools-compare-split；丙 cc/tools-probe-tags。
未核：战力算法（不移植，派单说不核）；主工作区未提交的 event_presets／event_compare_baseline 改动；待核查.py 里 11-05～11-08 的其余乙丙档（rules-ui14、bajie-walk1 等，不在本期派单里）。

## 交接板
- 下一步：P2-1、P2-2 派悟空（floor10b 的后续）：map_scene 随机遇敌收结果、全灭走 game_over；mv_interpreter 301 改 await host.game_over()；xiyou_game_over 补随机遇敌全灭、经解释器输掉两例（画面期间 busy、玩家不能动）。P3-1 总装改变更记录条目；P3-2 删 sel.txt；P3-3 入库后下一期核。
- 需要用户决定：无（P2 都是把 Kyo 11-08 定的「全灭回标题」补全）。

## 待交叉核查
无（审查线程自己的文档分支）。

## 优化登记草稿

优化登记草稿：无

## 可优化
- 合并工具：交付单「变更记录草稿」第一行不是 `## 日期 【…】` 标题时停下提示（P3-1：没标题的草稿并进去会挂在上一条下面）。
- 选测输出：`选测.py`／并行测试的临时名单别写到仓库根目录（P3-2 的 sel.txt），或在 .gitignore 里加上。
