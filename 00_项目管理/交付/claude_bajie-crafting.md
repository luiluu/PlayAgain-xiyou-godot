# 交付：claude/bajie-crafting

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_55）
- 状态：可合并

本分支分两期：期一＝怪物图鉴期二（战斗内怪物信息），先交；期二＝制作系统第一期，期一合并后再做（规模估算届时写在本单或接续单）。

## 变更记录草稿

## 2026-10-23 【Claude·八戒_55·未经Codex检验】战斗内「怪物信息」（dev.待定）

- **入口**（AB_EnemyBook v1.28 快捷键）：战斗中角色指令窗、技能列表、物品列表开着且可操作时按 **Shift** 打开「怪物信息」（播确定音，原窗口停住），取消关闭后回到原窗口。复用怪物图鉴的 XEnemyBookPage（`setup_battle`）。
- **内容**（Scene_Battle.battleEnemyBook，isAllEnemies 为假）：目录只列本场活着的敌人（同 ID 一项，不写序号）；状态窗 (426,0,854,1066)（calcStatusWindowHeight，超出画面同原版）；没登记的敌人也画名字、种族、出没地图、击败数与备注，能力、命中等、属性、技能写「？？？」；登记过的照图鉴画。目录确定不做事。窗口不透明度照战斗窗口。O-078 同样适用（固定按普通敌人显示）。
- **不做**：原版在队伍指令窗加了「怪物信息」「图鉴」两项，但 Olivia OTB 不开队伍指令窗（参照里角色指令窗取消也不会打开），玩家点不到，所以不加；战斗内打开全图鉴只有事件插件指令 `EnemyBook open` 能走到，正式数据的战斗事件里没有。
- **改到的文件**：`ui/enemy_book.gd`（战斗模式）、`battle/battle_scene.gd`（Shift 处理与 `_open_battle_book`，约 25 行，没动 `battle_logic.gd`）、`tests/xiyou_enemy_book.gd`（战斗内 7 项）、`tests/xiyou_battle_ui.gd`（真按 Shift 打开与取消 2 项）。
- **参照**：`tests/fixtures/battle_enemy_book_oracle.json`（ui_reference `?battle_ref=1` 战斗夹具：地图 5、敌群 2、难度 3；按 Shift 打开后未登记与登记后的目录、状态窗全部绘制，取消后回到指令窗）。

## 交接板

- 下一步：本分支期二＝制作系统第一期（Recipes.txt 转数据、存档字段、`crafting learn` 识别、制作界面）。
- 用户试玩说明：战斗中轮到自己选指令（或打开战技／物品列表）时按 Shift，可以看当前敌人的图鉴信息；没在图鉴里登记过的敌人数值显示「？？？」。按取消回到原来的指令。

## 进度账

- 养成与周边系统：不另加（战斗内查看是怪物图鉴的一部分，已在 dev.139 计入）

## 本分支提交

- 战斗内怪物信息、参照与专项（WIP 提交）
- 合 main，交付单可合并

## 验证

- 相关专项（`并行测试.py`）：`xiyou_enemy_book` 41/41、`xiyou_battle_ui` 70/70、`xiyou_battle_options` 92/92、`xiyou_battle_events` 108/108；合 main（悟空传承人／变体）并 `--补齐` 后重跑 `xiyou_enemy_book`、`xiyou_battle_ui` 仍全过。窗口模式 `xiyou_battle_ui -- --out=` 的截图 battle_42_enemy_book 与原版战斗夹具截图版面一致（窗口模式下 `shield_pixels_*` 4 项本来就只在无头下验，与本改动无关）。
