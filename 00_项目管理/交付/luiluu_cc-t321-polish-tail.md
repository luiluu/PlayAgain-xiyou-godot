# 交付：luiluu/cc-t321-polish-tail

- 车道／工作者：B 界面／cc 车道（T321，Sonnet＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·T321·未经审查】新界面美化收尾：关态守护用例、首领属性行回落、页签暖底对称（dev.待定）

- 依据：T309 cc Opus 核 P2-1、P3-1、P3-2。
- 守护用例：`tests/xiyou_ui_skin_offshot.gd` 加一档 `tq_on`（天启篇存档、新皮肤开、`XUiSkin.POLISH_V1=false`），钉住 `XUiSkin._clock_ms`，藏环心小人（`SvSprite`）和战斗者（`XBattlerSprite`），环导航 `_spin` 归零停转；不拍战斗。基线没有的开关（`POLISH_V1`、`_clock_ms`）读不到就跳过，所以也能在美化前的提交上跑。
- `skin_boss_status.gd` `_attr_line`：属性多到 11 号也放不下时继续回落到 9 号，不再压到右边的关闭×。
- `skin_inner_tabs.gd` `_draw`：页签暖底两侧留白取 `min(8, 左边剩余, 右边剩余)`，首尾页签贴边时左右一起收窄，不画出控件。
- 玩家可见：首领状态页属性很多时字号更小但不再压住关闭键；页签首尾暖底左右对称。未新增或修改任何文字。

## 合并须知（改准 T309 的措辞）

- T309 交付单写的「POLISH_V1 关态逐像素回退」，之前验的是 `XUiSkin.ENABLED=false`（`tq_off`）和 `xiyou` 两档，**没有**覆盖「新皮肤开着、只关 POLISH_V1」；现在由 `tq_on` 档覆盖。
- `tq_on` 档只能对「新皮肤已开」的提交比：`皮肤关闭对照.py --base <提交>`，对 main（旧界面）比这一档必然 DIFF，不看。本单实测基线 `b3cc3716f`（含 T309）。
- 对 T309 合并前的 `525969a7a` 比 `tq_on` 不会 SAME：基线之后 main 还有别的界面改动，不是 POLISH_V1 的问题。

## 交接板

- 下一步：无。
- 用户试玩说明：无需。
- 需要用户决定：无。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 已做：offshot `_freeze` 统一停环导航 `_spin`（相位按真实帧间隔累计，会让逐像素对照出噪声）；不需回退，旧档里没有该节点。

## 验证

- `皮肤关闭对照.py --base b3cc3716f`：88/88 SAME（含 `tq_on`；修前 `tq_on` 13 页因环导航呼吸噪声 DIFF，修后清零）。
- 专项（`--audio-driver Dummy`）：`xiyou_ui_skin_offshot` 85/85、`xiyou_ui_skin_4b` 123/123、`xiyou_ui_skin_1c` 81/81、`xiyou_ui_skin_close` 71/71、`xiyou_ui_skin` 111/111、`xiyou_ui_skin_card_k` 97/97；`语法检查.py` 0 个问题。
- 没测：首领属性行 5 个以上属性的实际截图、页签首尾暖底截图（只做了代码改动与上述回归）。

## 本分支提交

- 见 `git log`
