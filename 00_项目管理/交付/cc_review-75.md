# 交付：cc/review-75
- 状态：可合并
- 车道／工作者：cc（审查，GH7）

只有文档，没有游戏代码。分支从本地 main d206fecc5 切，在 app 给的工作树里做，没碰主工作区。

## 变更记录草稿

## 2026-11-10 【cc·审查】核查 11-10 合进 main 的 14 批（审查第 75 期）

- 核查覆盖：cc/tools-probe-deps、cc/rules-gaps9、cc/rules-gaps10、cc/tools-merge-probe2、cc/platform-android-bgidle1、cc/platform-android-keys-fix、cc/rules-gaps11、cc/bailong-raven6、cc/floor-boss-lose、cc/ui-pixel1、cc/ui-pixel2、cc/rules-battle-pixel、cc/chars-gaps1、cc/tools-optnum
- 报告：`核查报告_20261110_审查第75期.md`。P1 1、P2 1、P3 3。
  - P1-1：gaps10 的 `EXTRA_ONCE` 没限定 1365，风怒、女王再次、堕天一击、雪岭舞等 10 个概率连发的公共事件也被截成最多额外一次。
  - P2-1：双方同时倒下时重制先判赢（`battle_scene.gd` 711 行），原版先判输；floor-boss-lose 车道记下了、还没派。
  - P3-1：floor-boss-lose 记下的 353 可输复活、340 中止战斗两条也没派。
  - P3-2：战斗里「自动／变速」按钮画在淡出黑幕之上，层次没核。
  - P3-3：`help_card.gd` 的「O-待定·说明卡排版」在优化登记里没有行（11-06 旧账，不在本批）。

## 已核／未核清单
已核：甲 rules-gaps9、rules-gaps10、rules-gaps11、floor-boss-lose、tools-probe-deps（含 hboot 影响面声明「其余 94 个探针不受影响」）；乙 bailong-raven6、chars-gaps1、ui-pixel1、ui-pixel2、rules-battle-pixel、platform-android-bgidle1、platform-android-keys-fix；丙 tools-merge-probe2、tools-optnum。
未核：Godot 场景没跑（只读核）；floor-boss-lose 盘点数字没抽查；像素对照数字没重量。

## 交接板
- 下一步：P1-1 派规则车道（八戒）返工 gaps10：开关只认 1365，加「CE28／1154 自连不受影响」断言；P2-1、P3-1 可一起派规则车道；P3-2 给 UI 车道；P3-3 总装补登记。
- 需要用户决定：无（P1-1 是把改动收回到 Kyo 已拍板的范围）。

## 待交叉核查
无（审查线程自己的文档分支）。

## 优化登记草稿

优化登记草稿：无

## 可优化
- 规则车道修「原版 bug」开关时，顺手扫一遍数据里同结构的其它条目（这次一条一行的 Python 就能列出 11 个自连公共事件），免得修一个、改一片。
