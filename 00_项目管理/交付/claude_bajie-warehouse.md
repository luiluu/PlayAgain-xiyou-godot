# 交付：claude/bajie-warehouse

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_65）
- 状态：可合并

## 变更记录草稿

## 2026-10-24 【Claude·八戒·未经Codex检验】大厅三界面期一：装备镶嵌图鉴（dev.待定）

- 新界面 `ui/inlay_book.gd`（XInlayBook）复现 Star_EquipInlayBook 的 Scene_EquipInlayBook：方桌大厅魂灯商人 Map4 EV40 p1／p3「查看图鉴」（插件指令 `StarEIBook GetAll` 后 `SceneManager.push(Scene_EquipInlayBook)`）打开。类型窗 (0,0,320,100)「武器／防具」、目录窗 (0,100,320,620) 16 行、状态窗 (320,0,960,720)；武器 117 项、防具 115 项（Star_EquipmentMosaic 配方，即 XDB Runewords）。状态窗画模板八项能力（原版 textWidth 空格算式定横坐标）、模板备注 `<pos … text=…>` 的符石说明（drawTextEx 逐字、`\c[n]`、zidonghuanhang 换行、全伤→全属性伤害）、需求类型、镶嵌顺序（宝珠 drawItemName 每行 4 个）。操作：类型确定列目录并选第 1 项、目录无确定、取消清空目录与状态窗回类型窗、PageUp/PageDown 翻页、鼠标点选／滚轮／右键取消。
- 解锁：原版 `$gameParty.StarEMosaicOpt` 记形成过的符文之语，未形成的写「？？？」；但正式版三处入口（Map4、Map66、Map137）都先 GetAll，玩家永远看到全部，所以不新增存档字段、全部列出，`StarEIBook GetAll／RomGet` 认作无操作。
- 接线：`mv_script.gd` 认 `SceneManager.push(Scene_EquipInlayBook)` → `map_scene.gd` 新增 `open_inlay_book`；`mv_event_core.gd` 认 `StarEIBook`。
- 参照：`ui_reference/review_system_pages.js` 新增 `inlay_book` 页（4 个截图状态）与 `__sysRef.inlayAll()`（逐项读状态窗 drawText／drawIcon），`review_system_pages.cjs --inlay-all` 写出；压成 `tests/fixtures/inlay_book_oracle.json`。成对截图（原版／Godot 各 4 张）在工作树 `04_验证/本地结果/原版参照/大厅三界面/`，目视版面一致。
- 事件对照基线删 m4e40p1／p3（7 例 → 5 例），`xiyou_event_compare` 记录宿主补 `open_inlay_book`。
- 验证：`xiyou_inlay_book` 19/19（232 项状态窗逐条对照，坐标容差 0.15：类型名逐个累加 textWidth，Godot 与浏览器小数字宽每个差约 0.01）；`xiyou_event_compare` 5/5。

## 交接板

- 下一步：大厅三界面期二（仓库，Map4 EV8）、期三（更衣，可砍）由八戒_65 继续。
- 用户试玩说明：方桌大厅魂灯商人（第 15 层后出现）「查看图鉴」现在打开装备镶嵌（符文之语）图鉴。

## 进度账

- 界面：大厅未接界面 3 → 2（装备镶嵌图鉴已接）

## 本分支提交

- b503c77a 装备镶嵌图鉴 XInlayBook：原版浏览器参照、入口接线、专项
- （本提交）事件对照基线删 m4e40p1／p3、交付单
