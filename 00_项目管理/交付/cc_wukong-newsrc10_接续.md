# 交付：cc/wukong-newsrc10（EB 接续，没开工）

- 车道／工作者：EB 角色旧账二（cc，悟空）
- 状态：进行中
- 交接原因：上一会话上下文过 40%，EB 没开工，新会话从 b3687538 接着做（同分支、同工作树 competent-ishizaka-ae6e7c）。

## 接续要点

- 工作树已备好：`modes/xiyou/generated` 是从 relaxed-cori-c96dcd 克隆的（v0.62.12 重出）；`.godot` 也克隆了；`07_开发环境/当前Godot.app` 手动链好（gitignore）。jsdom 探针要 `NODE_PATH=/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/03_转换工具/mv_oracle/node_modules`，跑完脚本要 `process.exit`，不然 jsdom 不退。
- ① 平滑（168、174、175、179）：原版 v0.62 `js/plugins/Codex_MiraRavenMultiFrame.js` 的 SV 归一（167 号以后），缩小时 bitmap.smooth＝true；还有 `<CodexSVNativeSize>`、「不再覆盖变大装备」两项，见冻结后改动盘点第 106 行。重制在 `battle/battler_sprite.gd`：`setup` 里 `texture_filter = NEAREST`，归一档在 `_show_frame` 的 `XAppearance.profile`（≥167）。开关照前例写成 static var，登记 O-待定（出处 v0.62 SV 归一）。量法：`real/actor_sv_real.cjs`（结果快照 `real/actor_sv.result.json`，字段 smooth）＋`tests/xiyou_actor_sv_compare.tscn`（设 XIYOU_SV_REAL／XIYOU_APP／XIYOU_SV_OUT）。逐像素的开、关断言写进新专项。
- ② 没进出战栏的 141、146、152、161、166：量具做法是新局→开 2494→`$gameParty._actors=[id]`→initializeBattleMembers→进战斗，原版出战栏里没有它们（重制有）。要查新源里为什么（数据开关、解锁、事件加入，或 battleMembers 包装），出定性表；162 诛仙的重制外观是 scene 类，量具不认，要另写量法。
- ③ 候选清单在 `cc_wukong-newsrc10.md` 末尾，都还没核是否已销账；先 rg 变更记录和核查报告，只留真缺的，先做前 5 条。
