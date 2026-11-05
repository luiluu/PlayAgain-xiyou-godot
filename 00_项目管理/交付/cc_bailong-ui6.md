# 交付：cc/bailong-ui6

- 车道／工作者：B 界面／白龙（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·白龙·未经审查】界面三处缺口核实：实为已做，只订正备注豁免（dev.待定）

哪吒 tools63 扫出的三处「缺口」逐项读工程核实，**都已实现**，没有新增游戏代码：

- **Hide／Show HP Gauge**：`core/enemy.gd hp_gauge_visible()`（隐藏成员→无；`<HIDE HP GAUGE>` 先判；其余有），`battle_scene.gd` 画血条前调用；对照夹具 `tests/fixtures/hp_gauge_oracle.json`（原版逐个 Game_Enemy 读数），专项 `xiyou_hp_gauge_visible`。插件参数 Defeat First=false、Always Visible=false，所以不存在「需击败过才显示」。覆盖表里 HIDE 标「已读」、SHOW 标「已核」，本就无缺。
- **状态循环动画 1297**：`battle/vsfx.gd`＋`battle_scene._update_state_animations()`，动画 900 在 battler 上循环、去状态即清，专项 `xiyou_vsfx`（bailong-visual1 已交）。**State Overlay**：全库 States 备注只有 1297 一处 `<State Animation: 900>`，没有 Overlay 标签，无需画；gaps6 的「没找到」是因为数据里本就没用。
- **AnimatedSVEnemies 四个标签**：Breathing Speed／Sideview Show Shadow／Sideview Weapon 已在 `battle/sv_enemy.gd`，专项 `xiyou_sve_visual` 对 186 个 SV 敌人逐个核原版读数；Sideview No Collapse 实测无效（MOG_CollapseEffects 默认死亡效果接管，SV／非 SV 倒下一样），按「不做」登记。

改动只有 `07_开发环境/插件备注豁免.json`：把 5 条过期的「别的车道在做」订正为「已由别处实现」／「无运行效果」并写明依据，免得下次扫描又当缺口。

## 验证

- `xiyou_hp_gauge_visible`、`xiyou_vsfx`、`xiyou_sve_visual` 通过（CHECK_JOBS=2，209 秒）。
- `工具回归.py` 全部通过（71 秒）。`选测.py main --list`：Godot 场景 0 个（只改了豁免 JSON）。
- 窗口模式截图：未做——没有新的画面改动，且原版对照截图本就做不了（原版是 MV 网页）；画面对照靠上述 oracle 数值夹具。

## 待交叉核查

- 本车道提交：核对豁免 JSON 里 5 条的依据与代码一致（尤其 sideviewnocollapse 的「无运行效果」结论出自 bailong-visual1 的探针）。
