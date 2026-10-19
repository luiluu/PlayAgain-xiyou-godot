# 交付：claude/upbeat-newton-5288fa

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_22，Sonnet）
- 状态：进行中

## 变更记录草稿

## 2026-10-19 【Claude·八戒·未经Codex检验】审查遗留：出售筛选合一、设置页开关符号表合一（dev.待定）

- 做了什么（行为不变的重构）：
  - 一键出售（`XItemMarks.onekey_sell`）与挂机自动卖出（`XHangUpAuto.after_battle_sell`）原来各写一遍筛选，合成 `XItemMarks.sellable_gear(s, legacy)`：背包（不含身上）里备注品质在 `legacy` 里、未锁定（统一 `is_locked`，装备按名字带「[锁定]」）、按背包顺序。
  - 合并前先对照两处现状与冻结正式源（`installUnifiedQualityRuntime.js` 的 sellUnifiedQuality、`XdRs_HangUp.js` 的 OnekeyWPSell）：两处差异只有旧档范围——一键出售只含 0～14（原版 `ONEKEY = q <= 14`），自动卖出含 SellWA 里开着的全部档（含 15，原版无上限）；这是原版本来的差别，不是 bug，由调用方传 `onekey_members(g)` / `sell_legacy(s)` 保留。品质解析统一为 `strip_edges` 后整数（原先只有一键出售去空白；正式数据的 `<quality:>` 全是干净的数字，无差别）。
  - 设置页（`options_scene.gd`）状态文字、确定、左右三处各抄一份的开关 symbol 列表，合成 `FLAG_SYMBOLS`（存配置的 ON/OFF）＋ `XConfig.SESSION_FLAGS`（本次运行开关，含 pingbiDrop）＋ `XConfig.VOLUMES`，由 `_group(symbol)` 分组，三处共用。pingbiDrop 仍是状态恒空白、确定开屏蔽页、只有左右键改值。
- 验证：`检查.sh` 全部通过（见下方结果）；专项 xiyou_item_marks 108（新增 sellable_gear_shared：旧档 15 可卖、锁定不卖、身上不卖、一键 6 档不含 15）、xiyou_hangup_auto 226、xiyou_options_basic 139、options_misc 86、hangup_options 57、battle_options 92、notice_options 71、shop_buy 4895、shop_stock 46、item_list 38 全过。没有改任何数值或游戏内容。
- 提交：见下方「本分支提交」
- 未完成／已知问题：无。预分配的 O-060 未使用（没有行为变化，不登记）。

## 交接板

- 下一步：「下一步」第 4 条「审查 20%＋25% 遗留（悟空）」里的「出售筛选合成 XItemMarks 一个函数」「设置页开关 symbol 表合成一份」两项删掉（设置页其余 5 项仍留）。
- 用户试玩说明：玩家看不到变化。
- 需要用户决定：无。

## 进度账

- 无（重构，不改完成度）。

## 本分支提交

- 7fa2348 出售筛选合成 XItemMarks.sellable_gear；设置页开关符号表合成一份
