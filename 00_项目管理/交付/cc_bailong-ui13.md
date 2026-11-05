# 交付：cc/bailong-ui13

- 车道／工作者：B 界面／白龙（cc，ui13）
- 状态：验证中

## 变更记录草稿

## 2026-11-05 【cc·白龙·未经审查】地图气泡停留跟战斗变速档位 ui13（dev.待定）

审查 46 P3-2：ui10 把地图气泡 `Sprite_Balloon.waitTime` 固定成 3（12÷2÷2）。原版 SSEP 的加速开关 QuickMode（战斗里 Shift／按钮切，模块级变量，切了以后地图上也一直生效）开着时是 12÷BattleSpeed(Default) 2÷BattleSpeed(Boost) 8＝**0.75 帧**；重制用 O-006 的四档战斗变速代替了 QuickMode。现在 `MVCharacter.balloon_wait()` 按档位换算：四倍／三倍／二倍（`XConfig.battle_speed()` 1～3）照 QuickMode 取 0.75，OFF（4，默认）仍 3；`_balloon_t` 改成小数（原版 `_duration` 就是 64.75 这样的小数），帧号公式不变。开着变速时气泡共 64 帧（原来 67）。向原版对齐，跟原开关 `MVCharacter.BALLOON_SSEP` 一起回退，不占 O 号；默认档位是 OFF，默认画面不变。

## 交接板

- 下一步：无新增。
- 用户试玩说明：设置里战斗变速开着（四倍／三倍／二倍）时，地图上人物头顶的气泡停留比原来短 2 帧左右，和正式版开了加速一样；OFF 时不变。
- 需要用户决定：无。

## 进度账

- 无（对齐修正）。

## 可优化（流程／工具／效率）

- 无新增。

## 验证

- `xiyou_map_balloon` 13 项（原 9 项先固定 OFF 档；新加 Boost 参数 8、四档等待 [0.75,0.75,0.75,3]、加速档时长 64.75、逐帧帧号对按 `rpg_sprites.js` 独立算的序列）；`xiyou_review_fixes` 16 项。
- `语法检查.py` 通过。
- 云端选测：（跑完填）

## 本分支提交

- 本提交
