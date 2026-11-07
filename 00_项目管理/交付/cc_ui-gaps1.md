# 交付：cc/ui-gaps1

- 车道／工作者：B 界面／界面（cc，第十五批 FD）
- 状态：可合并

## 盘点（派单 ①：对照新源 v0.62.12 列没做或不一致的界面）

| 项 | 结论 | 依据 |
| --- | --- | --- |
| 说明卡新排版（v0.43 installPanelLayoutV043 P.view） | 已做，不用动 | `ui/help_card.gd` `LAYOUT_V043`（\col／\rgb／\lock、分区排序都在） |
| Hide/Show HP Gauge（YEP_X_VisualHpGauge） | 规则早已做（`core/enemy.gd` `hp_gauge_visible`），参照夹具还是 v0.28；本批换成新源 | 新源 HIDE 566、SHOW 278、两个都写 2（派单写的 546／277 是旧源数；grep 原始备注 568／299 是同一敌人里重复写的次数）；新增 27 个敌人，984～990 七个变了 |
| 真气首领血条（v0.37 Z.bossHpEnemy） | 已做 | `battle/boss_hp_bar.gd` `RANGE_V037`；cc_newsrc-switch 交付单那句「没做」已过期 |
| 装备页右下详情（v0.41 installEquipmentDetailV041 的 Detail＋v0.43 改写） | **没做 → 本批做了** | 新源实跑参照（下） |
| 物品页装备详情放右侧（v0.43 Scene_Item 部分） | **没做 → 本批做了** | 同上 |
| 藏宝图直接／批量使用数量窗＋至臻装备入包金色闪光（v0.29 installTreasureBatchRuntime 的界面部分） | **没做 → 本批第二期做了** | 规则层 `core/treasure_map.gd` `_run_v029` 已做；Window_TreasureNumber、useOne 同步跑公共事件（只认 118／119／120／1377 后续）、T.updateNotice（物品页／地图／战斗都弹）都没有 |
| ui5 千万级血量拖尾 | 等 Kyo | 派单注明 |

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·装备详情 | `modes/xiyou/ui/gear_detail.gd` `XGearDetail`；装备页 `XEquipScene.DETAIL_V041`、物品页 `XItemScene.DETAIL_V043` | v0.28 装备页右下是物品信息窗与属性对比轮换，装备说明弹浮窗；物品页装备也弹浮窗 | 照新源 installEquipmentDetailV041（v0.41）＋installPanelLayoutV043（v0.43）：装备页右下换成页签条「装备详情／属性对比／插槽与镶嵌」＋详情（P.view 排版、整行分页）＋翻页条，PageUp／PageDown 翻详情、滚轮与拖动滚动；物品页选中装备时右侧换成「装备详情／插槽与镶嵌」，不再弹浮窗 | 跟进新源界面改动；参照 `tests/fixtures/gear_detail_oracle.json`（review_system_pages 的 equip_detail／item_detail），专项 `xiyou_gear_detail`（含两个开关的回退支） | `XEquipScene.DETAIL_V041 = false`、`XItemScene.DETAIL_V043 = false` | cc（界面 ui-gaps1） | 待用户确认 |

## 变更记录草稿

## 2026-11-07 【cc·界面·未经审查】装备页／物品页右侧装备详情、藏宝图批量使用与至臻闪光跟到新源；敌人血条参照换新源；游戏时间不再随变速齿轮变快（dev.待定）

- 装备页（`ui/equip_scene.gd`）：右下换成 `XGearDetail`（新 `ui/gear_detail.gd`）——页签条 (640,173,640,58)「【装备详情】　属性对比　插槽与镶嵌」、详情 (640,231,640,431)、翻页条 (640,662,640,58)；属性对比挪进详情的位置，物品信息窗与说明卡浮窗不再出现。→／Tab 下一个页签、← 上一个（首尾相接，不响音效，照 v0.41 改写后的 updateLowerRightWindowTriggers），点页签条按三等分选；详情页与插槽页 PageUp／PageDown 翻详情（不再换角色，Q／E 照旧），点翻页条左半／右半翻页，滚轮一格 100 像素，按住拖动滚动（6 像素起算，点详情区不再轮换窗口）。
- 物品页（`ui/item_scene.gd`）：物品列表活动且选中装备时，右侧换成「装备详情／插槽与镶嵌」两页签（Tab 或点左半／右半切换），不弹说明卡；操作菜单、分类、普通物品照旧显示信息窗。
- 详情内容：装备详情＝`XHelpCard.detail_rows`（getDescParams＋星级名＋P.view，宽 612；不带说明卡那层 installCombatPowerRuntime 加的「装备战力：」行，原版详情不经 Sprite_ItemHelp.setItem）；插槽与镶嵌＝星级名（#ffe499）、宝珠插槽数与每孔、符文镶嵌剩余孔与记录、「镶嵌操作可在物品菜单选择这件装备。」。排版照 render43：每行文字高、整行分页、页顶的空白分隔行去掉，多页时总高＝页数×页高；翻页条一页时空着、多页时「▲ 上一页　p／n　下一页 ▼」（20 号，到头的一侧半透明）。字号沿用说明卡 O-007（分隔行除外）。
- 回退：`XEquipScene.DETAIL_V041 = false`、`XItemScene.DETAIL_V043 = false` 回到 v0.28 版面（O-待定·装备详情，见上方优化登记草稿）。核 v0.28 版面的旧测试（`xiyou_gear_ui`、`xiyou_panels`、`xiyou_system_evidence`、`xiyou_window_rects`）开头把两个开关关掉。
- 参照：`ui_reference/review_system_pages.js` 新页 `equip_detail`（7 态）、`item_detail`（5 态），新源 v0.62.12 实跑，读数压成 `tests/fixtures/gear_detail_oracle.json`；新专项 `xiyou_gear_detail`（行内容逐行比 3 件、窗口矩形、页签文字、→←Tab 与点击、PageDown 不换角色／属性对比页照旧换、分页与翻页滚动、原版总高 259／389／404、两个回退支）。
- 敌人血条显隐：`hp_gauge_probe` 用新源重跑，`tests/fixtures/hp_gauge_oracle.json` 换成 v0.62.12（2027 个敌人），`xiyou_hp_gauge_visible` 计数断言改成 566／278。
- 审查第 52 期 P2-2（来源 ui-battlefix2）：`XState.play_seconds` 原来按 `_process` 的 delta 累加，变速齿轮 time_scale 1.6 让游戏时间快 1.6 倍（商店补货、变量「游戏时间」、脚本 playtime() 冷却、存档页时间都受影响）。原版 playtime＝frameCount／60，齿轮不碰 frameCount。现在 `map_scene` 累加 `XSpeedGear.real_seconds(delta)`（除掉 set_engine 设下的那份倍率；测试快进、平台离线追帧的倍率照旧算进去）；`xiyou_speed_gear` 加 `map.play_seconds_real_time`（开齿轮 1.5 秒真实时间，play_seconds 增量误差 ≤8%）。
- 藏宝图直接／批量使用（新 `core/treasure_batch.gd` `XTreasureBatch`，`ui/item_scene.gd` 数量窗）：表里 21 种藏宝图在物品页「使用」时开 Window_TreasureNumber (390,184,500,352)——「使用藏宝图」、名字、× 数量、「持有 N 张」、按键说明，五个触摸键（y 194，一直显示）与 MAX 键 (206,258,88,40)；左右 ±1、上下 ±10、PageDown 取最大。确定后当场逐张用（T.useOne：该图公共事件带 common_id 跑，后续只认 118／119／120／1377，最多 12 条，提示不弹；成功＝库存正好少 1），每帧最多 8 张，取消键停；结束回列表，说明卡写「已使用 名字 ×N；剩余 N 张[；获得至臻装备 N 件][（原因）]」／「已取消使用藏宝图」。不再回地图跑事件。
- 至臻装备入包闪光（新 `ui/prestige_notice.gd` `XPrestigeNotice`）：`XState.gain_gear` 新得到底子名以「至臻」开头的武器／防具时记队列；当前场景（地图；物品页、战斗是它的子节点）上弹窗 (290,86,700,172)「至臻现世 · 获得 N 件」＋前两种名字＋「另有 k 种至臻装备」，全屏闪光 255,219,130 不透明度 floor(128×剩余／45)，45 帧；窗 150 帧、文字不透明度 min(255, 剩余×12)。
- 回退：`XTreasureBatch.ENABLED = false`（藏宝图单张使用回地图、不弹至臻窗）。复现原版，不登 O 号。
- 参照：`review_system_pages.js` 新页 `treasure_batch`（开窗、加减、MAX、确定用 3 张、取消 5 态）与 `prestige_notice`；读数 `tests/fixtures/treasure_batch_ui_oracle.json`；新专项 `xiyou_treasure_batch`。
- 玩家可见：装备页右边改成可翻页的完整装备详情和插槽页；物品菜单里选中装备时右边直接显示详情，不再弹浮窗；藏宝图可以在背包里直接一次用多张；拿到至臻装备时全屏金光提示；开着变速齿轮时游戏时间、商店补货按真实时间走。

## 交接板

- 下一步：界面缺口下一批（ui5 千万级血量拖尾等 Kyo 定）；至臻闪光原版只认 gainItem／gainIndependentItem，重制只挂在 `gain_gear`，深渊商人等直接 append 实例的路径没接（量小，需要时补）。
- 用户试玩说明：装备页右下三页签（→／Tab 切换，PageUp／PageDown 翻页）；物品菜单选中装备看右边；背包里用藏宝图会弹数量窗。
- 需要用户决定：无（O-待定·装备详情随优化登记待确认）

## 进度账

- 界面页面：本批补上新源两处页面（装备详情、物品页装备详情），完成度由总装核定

## 可优化（流程／工具／效率）

- 建议：平台车道看一下 `core/platform.gd` 离线追帧 `_catch_up_left -= delta`：delta 含变速齿轮的 1.6，追帧按「齿轮秒」扣，开齿轮时实际补的游戏时间只有离开时长的 1/1.6（和本批 P2-2 同一类，我没改，不是本车道文件）。
- 已做：`review_system_pages.js` 加了 equip_detail／item_detail 两页（回退＝删这两段）。

## 验证

- 工具快速回归 `工具回归.py`：全过（64 秒）。
- 选测走云端（`检查.sh --affected main --cloud`，`CHECK_CLOUD_NO_UPLOAD=1`；xstate.gd 改了 gain_gear，选中 361 个场景）：
  - 6d99b22e（运行 42389806479）：359 过，挂 `xiyou_gear_detail`（测试里宿主不是 Control，解析错）、`xiyou_hp_gauge_visible`（新源神兵之仙 984～990、2005 原版 hpGaugeVisible 为假——v0.37 真气首领血条范围，断言改比战斗里实际用的 `XBossHpBar.small_gauge_visible`）。其余守卫、文档检查全过。
  - 修后按上次提交为基准只重跑受影响的：74ac88f5／01329855（17 个场景，运行 42392166502、42393026180）——专项对着原版读数又改了三处：详情不带 installDamageElementRuntime（setItem 层）的攻击属性／元素增伤行、文字照 normalizeGear 换元素别名（暗黑→黑暗）、插槽行按实例孔数比结构；其余 16 个全过。
  - 9072a5e4（运行 42394227958）：`xiyou_gear_detail` 55/55。
- 新专项：`xiyou_gear_detail` 55 条、`xiyou_treasure_batch`（首轮即过）；`xiyou_speed_gear` 新断言 `map.play_seconds_real_time` 在首轮里过。
- 没在 Mac 上跑 Godot（Kyo 11-07 定重测试走云端）；`--补齐` 已完成（等槽约 50 分钟后导入完）。

## 本分支提交

- 13dc73fa 敌人血条显隐参照换 v0.62.12
- 6322eefa 装备页／物品页右侧装备详情（XGearDetail）
- 9a34dbf8 装备详情专项与参照夹具；旧版面测试关开关
- 19cc44c6 审查 52 P2-2：游戏时间按真实时间累加
- 44d88be2 交付单、优化登记
- 82ba44da 合 main（2443a7b0）
- 5e01c4d6 第二期 C：藏宝图批量使用＋至臻闪光
- e286aa4e 交付单补第二期
- 02c350ef、74ac88f5、01329855、9072a5e4 云端选测后的修正（测试宿主、血条比较对象、详情去元素行与别名、插槽断言、物品页高度）
