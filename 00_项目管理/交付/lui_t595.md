# 交付：lui/t595

- 车道／工作者：T595 界面小改（cc，Sonnet 5.5＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-28 【cc·未经审查】西游法宝说明卡去掉「法宝加成」行（dev.待定）

- 玩家可见：法宝说明里不再单独写「法宝加成：当前值」那一行；法宝等级、吞噬升级最低装备品级照旧显示。
- 依据：Kyo 2026-11-28 事项 101「也去掉」（T588 续），进 0.04.09。
- 改动（`modes/xiyou/ui/help_card.gd`）：只在加成行处多判一个开关 `XHelpCard.FABAO_NO_BONUS_ROW_T595`（默认 `true`；设 `false` 回到 T588 写法）。普通法宝与破限之心原来都走这同一行，两种都不再写。
- 不变：自带平加（补天石强化等）的法宝仍把成长并进顶部八项；织神天梭本来就不写这行；超本层上限提示、进化行、喂入菜单两行照旧。启封卡面不走这段代码。
- 专项：`xiyou_fabao_card_t588` 改为断言没有加成行，加开关回退断言（130/130）；`xiyou_xufeng_rework` 法宝 143 卡面断言改为默认无加成行、开回退开关核原成长数值（65/65）。

## 交接板

- 下一步：进 0.04.09。本单没有新增玩家可见文字。
- 用户试玩说明：背包里选一件法宝看说明，「法宝等级」下面不再有「法宝加成」。
- 需要用户决定：见下「偏离与待定」。

## 偏离与待定

- 去掉这行后，没有平加的法宝（多数没强化过的）卡面上看不到当前成长数值：顶部八项只对带平加的法宝并入成长。按派单「只删这一行」没改。要是 Kyo 想保留数值又不要这一行，可以另开一单让所有法宝都并进顶部八项。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 建议：`选测对照.json` 没有归类仓库根的 `归档/交付截图/`，截图一提交，选测就变成整轮（857 个场景、约 212 分钟额度）。本单先只提交代码跑云端（59 个场景），截图放到之后的提交里。建议把该目录归到文档类（归工具车道）。

## 动了的共用函数和开关

无（只改 `modes/xiyou/ui/` 下的界面脚本和测试；新增开关 `XHelpCard.FABAO_NO_BONUS_ROW_T595`）。

## 截图（`归档/交付截图/lui_t595/`）

- `xiyou_zhuxian_before.png`（T588 版，取自 `归档/交付截图/lui_t588/`）／`xiyou_zhuxian_after.png`
- `xiyou_feed_menu_after.png`、`xiyou_reinforced_card_after.png`
- `other_zhuxian_after.png`：启封对照
- 出图工具：`tests/t588_shots.tscn`（临时 HOME、`--audio-driver Dummy`）。

## 验证

- 本机：`xiyou_fabao_card_t588`、`xiyou_fabao_99_scale`、`xiyou_gear_detail`、`xiyou_help_card`、`xiyou_character_gear_help`、`xiyou_yunshang_shop`、`xiyou_cat_help`、`xiyou_fabao_rework`、`xiyou_magic_level` 9/9 通过；之后 `xiyou_xufeng_rework`、`xiyou_fabao_card_t588` 2/2 通过。语法检查、工具回归、`发行空壳.py check` 通过。
- 启封零改动：改动在 `_apply_fabao_scale_rows` 里，这个函数只在 `XMagicWeapon.scale_active` 为真时调用（`modes/xiyou/ui/help_card.gd:275`），启封存档下它返回假（`modes/xiyou/core/magic_weapon.gd:106`）。截图 `other_zhuxian_after.png` 是启封对照。
- 第一轮云端选测挂 1 个（`xiyou_xufeng_rework` 靠加成行核法宝 143 数值），已改断言：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/46129813582
- 第二轮云端选测通过：59 个场景、2 片，提交 4c1e17789a，`gh run watch` 前台确认跑完 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/46131005849

## 本分支提交

- 8b5c56116 实现、专项
- 4c1e17789 徐凤年专项跟进
