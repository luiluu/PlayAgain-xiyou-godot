# 交付：claude/bajie-status-power

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_7）
- 状态：可合并

## 变更记录草稿

## 2026-10-16 【Claude·八戒·未经Codex检验】状态页战力条、装备变更后的战力提示（dev.待定）

- 状态页战力条 `ui/power_strip.gd`（XPowerStrip，照 installCombatPowerRuntime 的 Scene_Status.create／refreshCombatPowerSummary）：页窗上方独立一条 (24, 页窗原 y, 画面宽−48, 36)，页窗下移 36；「战力：N」、人物属性（元素色，CodexElements.drawAttributes 超宽缩字）、「自身 N · 装备战力 N」。数值都取 XPower.actor（dev.046 已与正式版一致）。关掉「战力显示与估算」时不建条、页窗不下移。
- 装备变更战力提示 `ui/power_notice.gd`（XPowerNotice，照 notify＋installGamePanelTheme 外观）：装备页装上／卸下／清空且身上装备确实变了才弹；两行「名字 · 战力提升 +N／战力下降 -N」「当前总战力：N」；右下角浮框（右 24、下 36），跨场景保留，3.5 秒消失。`equip_scene.gd` 只在 `_keep_rates` 里套一层 `XPowerNotice.around`。
- 优化 O-031：战力条第三段加「装备提升 +N」（总战力−自身）。原版只写「装备战力」（各件装备评分之和，与实际提升不同，正式版读数魔雷老人 439＝406＋33，装备战力却是 78），三个数对不上；`XPowerStrip.SHOW_GEAR_GAIN` 设 false 即恢复。
- 验证分级「标准」：ui_reference（冻结副本，静音）取正式版运行时读数——战力条各段 drawText 的 x、宽、字号、颜色（4 个角色：无属性、单属性、双属性），提示框矩形、内边距、颜色、字体、计时——存为 `tests/fixtures/status_power_oracle.json`；新测试 `xiyou_status_power`（32 项，带截图 34 项）逐段比对，并测关闭战力、无变化不弹、3.5 秒消失。截图对比：正式版 `04_验证/本地结果/原版参照/bajie7_status_power_00.png`、`_23.png`；Godot `04_验证/本地结果/八戒7_战力条/`。检查.sh 全部通过（48 个 Godot 测试场景，参照工具访问守卫通过；本分支未改切片、转换器与探针，未跑 --oracle）。
- 未做：战力条右端 300 宽的真气段（真气系统未移植）；状态页右上角「战力 N」按钮与它打开的「角色战力」面板（installEquipmentStatusRuntime renderPower：总／自身／装备战力、人物属性与各元素承伤、能力构成、3／10 回合平均输出、已穿装备评分、自身成长来源）；状态页整体尚未按正式版逐像素复现（页窗原 y 280，正式版 72）。设置页切换战力开关时正式版会立刻收起提示框，Godot 不处理（提示 3.5 秒自己消失，设置页不在本车道）。

## 交接板

- 下一步（界面清单第 5 项）：删掉「状态页战力条、装备变更后的战力提示（八戒做中…）」，改为「状态页『查看角色战力』按钮与角色战力面板（installEquipmentStatusRuntime renderPower，可复用 XGearSearch 的网页层面板）」；状态页逐像素复现（JAH_StatusMenuCore：选页窗 (0,0,1280,64)、页窗 (0,72→108,1280,612)）。
- 用户试玩说明：状态页上方多了一条战力条（总战力、人物属性、自身／装备提升／装备战力）；在装备页换装或清空后右下角弹出战力变化提示。
- 需要用户决定：O-031（战力条加「装备提升」）。

## 进度账

- 界面页面：62% → 63%，状态页战力条与装备变更战力提示完成（角色战力面板与状态页逐像素复现仍未做）。

## 本分支提交

- e67d14d 建交付单
- fc78c41 战力条、战力提示、夹具与测试、O-031
- f7c7cf4 界面风格登记
- （本提交）交付单可合并
