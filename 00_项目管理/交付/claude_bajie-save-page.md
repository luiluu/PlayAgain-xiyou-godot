# 交付：claude/bajie-save-page

- 车道／工作者：B 界面·存档／读档页／八戒（Claude，重制_八戒_10）
- 状态：可合并（main 无新提交；--补齐 后 `检查.sh --oracle` 全部通过：53 个场景、约 80,498 项）
- 预分配 O-042～O-044：用了 O-042（存档容量显示实际文件大小）。
- XState／XSave 改动（唐僧_3 批准）：`XState.save_count`（存档可选键 `saveCount`，旧档缺省 0），`XSave.save` 写盘前加 1；另加 `XSave.remove(slot)` 供「删除」用。其余存档字段不动。
- 合并注意：`dev.待定` 在 `00_设计/界面风格.md`（1 处）。本分支不改切片、转换器与探针，不需要同步。

## 变更记录草稿

## 2026-10-16 【Claude·八戒·未经Codex检验】存档／读档页整页复现（标题「旧的回忆」与一键存档选格共用）；保存次数（dev.待定）

- 界面（标准级，正式 v0.28 浏览器读数 `tests/fixtures/save_page_oracle.json`，截图 `04_验证/本地结果/原版参照/存读档页/`，Godot 对照截图在其 `godot/` 子目录）：新增 `ui/save_scene.gd`（XSaveScene），照正式 YEP_SaveCore＋SaveHistory_FullData 的 Scene_File：帮助窗、30 格列表（图标 907／905、「文件 N」、空格半透明、读档初选最近保存的一格）、读取／保存／删除横排操作窗（读档模式停在读取、存档模式停在保存，不可用的半透明、确定蜂鸣）、信息窗（游戏名、队伍前 5 格头像／名字／Lv、两列数据：地点、保存次数、游戏时间、精魂、神魔之塔层数、肝帝积分（带图标）与存档容量，空格整块暗底＋「空」）、确认窗（读取总确认、覆盖确认、删除确认，「是／否」）。删除播 Damage2（音量 100、音高 150）。标题「旧的回忆」与菜单一键存档的选格页都改用它；旧的 `ui/save_panel.gd` 删除。
- 存档：`XState.save_count`＋`XSave.save` 写盘前加 1（正式 $gameSystem._saveCount／onBeforeSave），旧档读出 0；`XSave.remove`。
- 优化 O-042：正式「存档容量」实际是 encodeURI 转义字节数（不是大小），Godot 显示实际存档文件大小；`XSaveScene.REAL_FILE_SIZE` 设 false 恢复原版算法。
- 与正式的已知差别：最近保存的一格按存档时间 savedAt（只到秒），同一秒存的几格取编号大的（正式版是毫秒时间戳）。
- 验证：`tests/xiyou_save_page` 29/29（窗口矩形、列表行、操作窗格子与可用性、信息窗文字／头像／等级／图标／暗底、空格、确认窗、读取／删除／取消／存档模式流程、保存次数 2／旧档 0／再存 1）；`xiyou_hud`（标题读档页 30 格可达）、`xiyou_panels`（一键存档无格时开选格页）、`xiyou_review_regressions`、ui_smoke、flow 通过；`检查.sh --oracle` 全部通过（53 个场景、约 80,498 项；先前一次 event_compare 用例数 566/553 不符是工作树转换产物旧，--补齐 后通过）。
- 提交：5d40aca 起至本分支末（见下）。
- 顺带：`xiyou_orb_shop_ui`、`xiyou_save_page` 退出前释放音效播放器与音频缓存（满负载偶发「resources still in use at exit」）；唐僧_3 说 main 上另有同一处修法，合并时 `xiyou_orb_shop_ui.gd` 冲突取 main 的即可。
- 未完成：无。

## 交接板

- 第 5 项「逐页复现原版界面」：删掉「标题读档页可滚动访问 30 格但仍待整页重做」，改为「存读档页已整页复现（dev.待定）」。
- 待交叉核查加一行：claude/bajie-save-page 各提交及合并提交（dev.待定），Claude（八戒、唐僧），存读档页整页、XState.save_count、XSave.remove、O-042；界面页面初值见下。
- 用户试玩说明：标题「旧的回忆」和第一次一键存档时打开的选格页，换成了原版样式：左边 30 格存档，右边显示队伍头像、等级、地点、游戏时间、精魂、层数与肝帝积分，可以读取、保存、删除。
- 需要用户决定：O-042（存档容量显示实际文件大小）。

## 进度账

- 界面页面（权重 6）：65% → 67%（+0.12；存读档页按原版整页复现，原先只算半页）。初值待 Codex 复核。

## 本分支提交

- 5d40aca 车道开工，建交付单
- WIP 初稿与读数夹具
- 3e7d443 存读档页整页复现、XState.save_count、XSave.remove
- d55a157 O-042 存档容量、优化登记与界面风格
- db1fd6b 测试退出前释放音效
