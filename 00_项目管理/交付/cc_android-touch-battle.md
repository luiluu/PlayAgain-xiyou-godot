# 交付：cc/android-touch-battle

- 车道／工作者：安卓 v0.01.01 玩家反馈（战斗怪物信息，第二期）／cc（项目线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-12 【cc·线程·未经审查】战斗「怪物信息」：第一次遇到的敌人也照写数值（dev.待定）
- 起因：测试玩家（玲樱）v0.01.01 安卓反馈「第一次进入战斗看不了敌人属性」，截图里怪物信息能打开，但能力值、属性、技能全是「？？？」。原版 AB_EnemyBook ResisterTiming 2＝打完才登记，登记前战斗里一律藏数值。
- 现在战斗里的「怪物信息」没登记也照写数值；大厅那本图鉴的登记、击败数、掉落照旧打完才有（O-待定·战斗怪物信息不藏数值，`XEnemyBookPage.BATTLE_SHOW_UNREGISTERED`）。
- 专项：`xiyou_battle_ui` 改成量「没登记照写数值、大厅图鉴仍不画、回退写「？？？」」；`xiyou_enemy_book` 的原版参照（「？？？」）改成对照回退态，另加一项默认不出「？？？」。
- 玩家可见：战斗里看第一次遇到的怪，也能看到能力值、属性和技能。

## 交接板

- 下一步：随 v0.01.02 修复补丁一起出（上一期的虚拟按键两项已合并），等 Kyo 说「推」。
- 用户试玩说明：新存档第一场战斗按「信息」键（或 Shift），怪物信息应写出数值而不是「？？？」；回大厅看图鉴，该怪仍要打完才登记。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·战斗怪物信息不藏数值 | `modes/xiyou/ui/enemy_book.gd` `XEnemyBookPage.BATTLE_SHOW_UNREGISTERED`（`status_ops`）；`tests/xiyou_battle_ui.gd`、`tests/xiyou_enemy_book.gd` | AB_EnemyBook ResisterTiming 2：打完才登记，登记前战斗内「怪物信息」能力值、属性、技能全写「？？？」 | 战斗内照写数值；大厅图鉴登记、击败数、掉落照旧打完才有 | 玩家反馈 v0.01.01：第一次进战斗看不了敌人属性 | `XEnemyBookPage.BATTLE_SHOW_UNREGISTERED = false` | cc | 已接受（Kyo 11-11 优化直接接受） |

## 进度账

- 无

## 验证

- `语法检查.py` 通过；`xiyou_battle_ui`、`xiyou_enemy_book` 通过。`选测.py` 另列 `xiyou_event_compare*` 四片，图鉴页不在事件对照路径上，没跑。

## 待交叉核查

- `modes/xiyou/ui/enemy_book.gd`、`tests/xiyou_battle_ui.gd`、`tests/xiyou_enemy_book.gd`。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- ffe35f981 战斗怪物信息没登记也写数值
- （本提交）合并 main、第二期交付单
