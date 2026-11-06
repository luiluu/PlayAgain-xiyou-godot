# 交付：cc/bajie-events15

- 车道／工作者：tests／预设／八戒（cc，派单 CN）
- 状态：第 1 项（查 3 例老不一致）已交，只有文档；第 2 项（CL 失败表的事件／楼层／脚本领域，在 cc/newsrc-switch 上做）等简报。分支从 main 74d696d3 切出。

## 变更记录草稿

## 2026-11-06 【cc·八戒·未经审查】查清地图事件对照的 3 例老不一致：都不是重制的错（dev.待定）

- **m4e73p0（商店向导「下一步建议」）**：原版 `CodexGuide.advise(this)` 插入的建议页最后有「战力短板」一段（CodexZones 五乘区预算：各人装备／外部／真气填到几成、
  建议、已溢出）；重制 `XGuide.advice_texts` 按优化登记 O-050（连同 O-044）不移植这一段，所以 trace 第 5 条原版有这页、重制没有。有意的差异，已在基线说明里。
- **m4e60p0#g3／m4e60p2#g3（希禾「自定义单抽」「自定义20连抽」，预设只选第 4 项）**：原版 `installCasinoBatchRuntime` 的 `CodexCasino.open` 先要求
  `SceneManager._scene` 是 Scene_Map 且在 Map004，才查券数、不够时 `$gameMessage.add('肝帝积分抽奖券不足。'／'20连抽至少需要20张…')`；
  重制 `XCasinoBatch.open` 判断顺序完全一样（宿主是 XMapScene 且 map_id 4，再查 `maximum<1`、写 pending_lines）。参照探针里场景是 Scene_Map，提示出；
  `xiyou_event_compare` 的宿主是测试用 `EventHost`（不是 XMapScene），第一道判断就返回，提示不出。**是对照宿主的限制，不是重制错**。
  实测：临时场景里用真 XMapScene、大厅、0 张券分别调两种模式，`open` 都返回 false 并留下与原版同字的提示（临时测试已删）。
  另：基线说明写着「游戏里由 xiyou_casino_batch 管」，但该专项现在没测「券不足」这条提示；要补的话是在 xiyou_casino_batch 里加一例 0 张券。

## 优化登记草稿

- 无

## 交接板

- 下一步：第 2 项等 CL 失败表与简报。可选：xiyou_casino_batch 补「0 张券→提示」一例；基线说明里「现存 1 例」改成 3 例（说明文字已分别写了三例的原因，只是计数旧）。
- 用户试玩说明：无
- 需要用户决定：无

## 发现的不一致（只记，没改游戏代码）

- 无新的；上面 3 例都不是重制错。

## 验证

- 读原版 `js/codex/runtime/installCasinoBatchRuntime.js` 第 16～20 行与重制 `modes/xiyou/core/casino_batch.gd` `open`；临时 Godot 场景实测（输出
  `{"single":[false,["肝帝积分抽奖券不足。"]],"twenty":[false,["20连抽至少需要20张肝帝积分抽奖券。"]]}`）。
- 事件对照 events14 全量结果里这 3 例的 diff 原样（trace:5／trace:2，Godot null）。只改文档，未跑测试。

## 待交叉核查

- 上面的判断（对照宿主限制）。

## 本分支提交

- 交付单
