# 交付：cc/review-71
- 状态：可合并
- 车道／工作者：cc（审查，GH3）

只有文档，没有游戏代码。分支从 github/main b445a3fe 切，在 scratchpad 的 clone 里做，推回本库后删 clone。

## 变更记录草稿

## 2026-11-09 【cc·审查】核查第十六批追加六条（审查第 71 期）

- 核查覆盖：cc/rules-gaps8、cc/bajie-interp7、cc/wukong-floor10c、9bb0f05、fdf8fa2、46be52e
- 报告：`核查报告_20261109_审查第71期.md`。P1 0、P2 0、P3 3。
  - P3-1：rules-gaps8 的「多出格不比参照」放宽没排除固定 0.5 的 `_half` 严比模式，以后多出一次行动会被自己放过。
  - P3-2：9bb0f05 写删 ce1431 预设 15 个，实际删 17 个（变量 1200 取 1～10、12～18）。
  - P3-3：battle_event_runner 353 注释还写「全灭回大厅」，O-244 后是结束画面回标题（只是注释）。

## 已核／未核清单
已核：甲 cc/rules-gaps8、cc/bajie-interp7、总装 9bb0f05、fdf8fa2；乙 cc/wukong-floor10c、总装 46be52e。
未核：cc/events-seg-a3（开工时没进 github/main，留下期）；战力算法（派单说不核）；待核查.py 里 11-05～11-08 其余乙丙档（不在本期派单）。

## 交接板
- 下一步：P3-1 派规则车道（xiyou_troop_events 的 more_slots 加 `not oracle_half`，或 `_half` 里多出格记失败）；P3-2、P3-3 总装顺手改（变更记录数字、注释一行）；seg-a3 推上 github/main 后派下一期审查。审查 66 P3-1～3（i7 变体、gate_of、b1／b2 前缀）原定随 interp7 做，interp7 改派后没收，请总装定还派不派。
- 需要用户决定：无

## 待交叉核查
无（审查线程自己的文档分支）。

## 优化登记草稿

优化登记草稿：无

## 可优化
- `待核查分档.json`：`04_验证/事件预设轮次/*.json` 归丙（盘点产物），免得每期都列进「拿不准、按甲算」。
