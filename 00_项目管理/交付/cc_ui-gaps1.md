# 交付：cc/ui-gaps1

- 车道／工作者：B 界面／界面（cc，第十五批 FD）
- 状态：进行中

## 盘点（派单 ①：对照新源 v0.62.12 列没做或不一致的界面）

| 项 | 结论 | 依据 |
| --- | --- | --- |
| 说明卡新排版（v0.43 installPanelLayoutV043 P.view） | 已做，不用动 | `ui/help_card.gd` `LAYOUT_V043`（\col／\rgb／\lock、分区排序都在） |
| Hide/Show HP Gauge（YEP_X_VisualHpGauge） | 规则早已做（`core/enemy.gd` `hp_gauge_visible`），参照夹具还是 v0.28；本批换成新源 | 新源 HIDE 566、SHOW 278、两个都写 2（派单写的 546／277 是旧源数；grep 原始备注 568／299 是同一敌人里重复写的次数）；新增 27 个敌人，984～990 七个变了 |
| 真气首领血条（v0.37 Z.bossHpEnemy） | 已做 | `battle/boss_hp_bar.gd` `RANGE_V037`；cc_newsrc-switch 交付单那句「没做」已过期 |
| 装备页右下详情（v0.41 installEquipmentDetailV041 的 Detail＋v0.43 改写） | **没做 → 本批做了** | 新源实跑参照（下） |
| 物品页装备详情放右侧（v0.43 Scene_Item 部分） | **没做 → 本批做了** | 同上 |
| 藏宝图直接／批量使用数量窗＋至臻装备入包金色闪光（v0.29 installTreasureBatchRuntime 的界面部分） | 没做，留到下一期 | 规则层 `core/treasure_map.gd` `_run_v029` 已做；Window_TreasureNumber、useOne 同步跑公共事件（只认 118／119／120／1377 后续）、T.updateNotice（物品页／地图／战斗都弹）都没有 |
| ui5 千万级血量拖尾 | 等 Kyo | 派单注明 |

## 变更记录草稿

## 2026-11-07 【cc·界面·未经审查】装备页／物品页右侧装备详情跟到新源；敌人血条参照换新源；游戏时间不再随变速齿轮变快（dev.待定）

- 装备页（`ui/equip_scene.gd`）：右下换成 `XGearDetail`（新 `ui/gear_detail.gd`）——页签条 (640,173,640,58)「【装备详情】　属性对比　插槽与镶嵌」、详情 (640,231,640,431)、翻页条 (640,662,640,58)；属性对比挪进详情的位置，物品信息窗与说明卡浮窗不再出现。→／Tab 下一个页签、← 上一个（首尾相接，不响音效，照 v0.41 改写后的 updateLowerRightWindowTriggers），点页签条按三等分选；详情页与插槽页 PageUp／PageDown 翻详情（不再换角色，Q／E 照旧），点翻页条左半／右半翻页，滚轮一格 100 像素，按住拖动滚动（6 像素起算，点详情区不再轮换窗口）。
- 物品页（`ui/item_scene.gd`）：物品列表活动且选中装备时，右侧换成「装备详情／插槽与镶嵌」两页签（Tab 或点左半／右半切换），不弹说明卡；操作菜单、分类、普通物品照旧显示信息窗。
- 详情内容：装备详情＝`XHelpCard.detail_rows`（getDescParams＋星级名＋P.view，宽 612；不带说明卡那层 installCombatPowerRuntime 加的「装备战力：」行，原版详情不经 Sprite_ItemHelp.setItem）；插槽与镶嵌＝星级名（#ffe499）、宝珠插槽数与每孔、符文镶嵌剩余孔与记录、「镶嵌操作可在物品菜单选择这件装备。」。排版照 render43：每行文字高、整行分页、页顶的空白分隔行去掉，多页时总高＝页数×页高；翻页条一页时空着、多页时「▲ 上一页　p／n　下一页 ▼」（20 号，到头的一侧半透明）。字号沿用说明卡 O-007（分隔行除外）。
- 回退：`XEquipScene.DETAIL_V041 = false`、`XItemScene.DETAIL_V043 = false` 回到 v0.28 版面（O-待定·装备详情，已写进优化登记）。核 v0.28 版面的旧测试（`xiyou_gear_ui`、`xiyou_panels`、`xiyou_system_evidence`、`xiyou_window_rects`）开头把两个开关关掉。
- 参照：`ui_reference/review_system_pages.js` 新页 `equip_detail`（7 态）、`item_detail`（5 态），新源 v0.62.12 实跑，读数压成 `tests/fixtures/gear_detail_oracle.json`；新专项 `xiyou_gear_detail`（行内容逐行比 3 件、窗口矩形、页签文字、→←Tab 与点击、PageDown 不换角色／属性对比页照旧换、分页与翻页滚动、原版总高 259／389／404、两个回退支）。
- 敌人血条显隐：`hp_gauge_probe` 用新源重跑，`tests/fixtures/hp_gauge_oracle.json` 换成 v0.62.12（2027 个敌人），`xiyou_hp_gauge_visible` 计数断言改成 566／278。
- 审查第 52 期 P2-2（来源 ui-battlefix2）：`XState.play_seconds` 原来按 `_process` 的 delta 累加，变速齿轮 time_scale 1.6 让游戏时间快 1.6 倍（商店补货、变量「游戏时间」、脚本 playtime() 冷却、存档页时间都受影响）。原版 playtime＝frameCount／60，齿轮不碰 frameCount。现在 `map_scene` 累加 `XSpeedGear.real_seconds(delta)`（除掉 set_engine 设下的那份倍率；测试快进、平台离线追帧的倍率照旧算进去）；`xiyou_speed_gear` 加 `map.play_seconds_real_time`（开齿轮 1.5 秒真实时间，play_seconds 增量误差 ≤8%）。
- 玩家可见：装备页右边改成可翻页的完整装备详情和插槽页；物品菜单里选中装备时右边直接显示详情，不再弹浮窗；开着变速齿轮时游戏时间、商店补货按真实时间走。

## 交接板

- 下一步：界面 FD 第二期——藏宝图直接／批量使用数量窗（Window_TreasureNumber：宽 500、fittingHeight(9) 居中，「使用藏宝图」、名字、×数量、「持有 N 张」、按键说明，±1／±10、MAX 键与 PageDown 取最大；每帧最多 8 张、取消可停；结果写进说明卡文字）＋至臻装备入包金色闪光（物品页、地图、战斗都弹，150 帧窗、45 帧闪光）。
- 用户试玩说明：装备页右下三页签（→／Tab 切换，PageUp／PageDown 翻页）；物品菜单选中装备看右边。
- 需要用户决定：无（O-待定·装备详情随优化登记待确认）

## 进度账

- 界面页面：本批补上新源两处页面（装备详情、物品页装备详情），完成度由总装核定

## 可优化（流程／工具／效率）

- 建议：平台车道看一下 `core/platform.gd` 离线追帧 `_catch_up_left -= delta`：delta 含变速齿轮的 1.6，追帧按「齿轮秒」扣，开齿轮时实际补的游戏时间只有离开时长的 1/1.6（和本批 P2-2 同一类，我没改，不是本车道文件）。
- 已做：`review_system_pages.js` 加了 equip_detail／item_detail 两页（回退＝删这两段）。

## 验证

（主线推送、补齐后填）

## 本分支提交

- 13dc73fa 敌人血条显隐参照换 v0.62.12
- 6322eefa 装备页／物品页右侧装备详情（XGearDetail）
- 9a34dbf8 装备详情专项与参照夹具；旧版面测试关开关
- 19cc44c6 审查 52 P2-2：游戏时间按真实时间累加
