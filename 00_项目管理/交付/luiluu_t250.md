# 交付：luiluu/t250

- 车道／工作者：B 界面／cc 车道（Opus＋medium，P8）
- 状态：进行中

> **WIP（11-19 项目经理cc 叫停：Kyo 要 Fable 先出 2C 详细设计，车道再照稿执行）。** 本分支是照 v0.7 风格先做的一版，可以当 Fable 出稿的对照素材，也可以整个推倒。没跑交付自检，不合并。

## 做到哪了

新增 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/skin/skin_battle_2c.gd`（`XSkin2C`），六个文件各加一个开关分支，只换画法：

| 页 | 做了什么 | 文件 |
| --- | --- | --- |
| 胜利结算 | 整屏压暗；A 版「左右两栏」（左：标题、金钱经验两枚胶囊、队员一行一张面板＋金色经验条；右：获得物品面板、品质色名字、滚动条）；B 版「居中一张牌」（队员一行一人，物品改成 12×2 图标格，多出的收进「＋N」）；关页提示画在页内胶囊 | `ui/victory_screen.gd` |
| 全灭 | A 版：保留 Kyo 11-08 定的 NULL 字图，加暗角＋底部提示胶囊；B 版：整页换成黑底、裂纹、「NULL」暗红字＋外晕、「全军覆没」 | `ui/game_over_screen.gd` |
| 本线计量条 | 照 v0.7 样稿 battle：小牌「战争线　火花 3 / 10」＋细金条，文字型（死期、饥饿）第二行写内容；挪到自动／变速圆钮下面；死期小钟换黑底细线 | `battle/tianqi_meter.gd`、`battle/battle_scene.gd`（摆位一行） |
| 伤害统计 | 烟色面板、旧金标题、窄体数字、每行底下一条占比细金线 | `battle/damage_record.gd` |
| 连击 | 不用 Combo_A／Combo_D 图，程序画淡金大数＋「连击」；挪到左侧 (36,340)；计时、淡出、右滑、2 倍缩回照旧 | `battle/combo_counter.gd` |
| 掉落图标 | 图标下垫暗圆片＋品质色细圈；弹跳轨迹、随机数照旧 | `battle/drop_popup.gd` |

开关：`XSkin2C.ENABLED` 总开关，`VICTORY／GAMEOVER／METER／RECORD／COMBO／DROPS` 分开关，`VICTORY_STYLE／GAMEOVER_STYLE` 选 A／B（默认 A）。只在 `XUiSkin.on()` 时生效（天启篇存档＋设置选新界面），西游存档走旧画法。

## 现成截图（`归档/交付截图/luiluu_t250/`，800×450；对照图左旧右新）

- `对照_战斗HUD.png`（计量条＋连击＋伤害统计＋掉落）、`old_drops.png`／`new_drops.png`（首领脚下掉落图标放大 2 倍）
- `对照_胜利结算_A.png`、`对照_胜利结算_B.png`
- `对照_全灭_A.png`、`对照_全灭_B.png`
- 单张：`old_*`、`new_*`
- 重拍：`godot --audio-driver Dummy --path 01_Godot工程 res://tests/xiyou_ui_skin_2c.tscn -- --out=<目录>`

## 自己看出来的问题（给出稿参考）

1. 掉落图标几个落在同一处，暗圆片叠在一起反而把图标盖暗了（`new_drops.png`）；要么不垫圆片，要么改成落地后横排。
2. 全灭 B 的「NULL」只能用游戏字体（圆头无衬线），不如原图有味道；B 版会把 Kyo 定过的 NULL 字图换掉，要 Kyo 点头。
3. 胜利页「等级提升！」照旧压在那一行上（A 压名字、B 压经验条），原版也是这样，没改位置。
4. 伤害统计的面板在亮背景上偏淡（烟色九宫格），小字是 14 号。
5. 连击挪到了左侧 y 340；首领在左侧时会靠近首领，位置要设计定。

## 验证

- 专项 `xiyou_ui_skin_2c`（新加，带窗口）46/46：两轮同一场战斗（西游旧画法／强开新皮肤），核旧画法不走新层、新层在、计量条摆位、连击位数、滚动上限、全灭盖层透明度跟淡入、两轮都跑到底。
- `语法检查.py` 0 问题。
- **没跑**：选测（`xiyou_battle_ui`、`xiyou_game_over`、`xiyou_drop_record`、`xiyou_drop_dh`、`xiyou_tianqi_look`、`xiyou_panels`、`xiyou_victory_text_flow` 这些旧画法专项）、`皮肤关闭对照.py`、`工具回归.py`、`交付自检.py`。续做时要补。

## 变更记录草稿

待写

## 交接板

- 下一步：等 Fable 的 2C 详细设计；出稿后照稿改本分支或推倒重做。
- 需要用户决定：胜利结算 A／B、全灭 A／B（B 会换掉 NULL 字图）——如果 Fable 稿另有方案，以稿为准。

## 进度账

- 无（WIP）

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- （见 WIP 提交）
