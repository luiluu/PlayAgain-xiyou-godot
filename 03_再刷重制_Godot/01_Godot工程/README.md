# Godot 工程

唯一 Godot 工程（GDScript，Godot 4.7.2，见[开发环境](../07_开发环境/README.md)）。启动后选「西游改版」或「新版」（新版未开放）。

## 首次运行

西游模式的数据与素材由转换器从正式 Mac 应用（v0.04）只读生成，不入 Git：

```
python3 ../03_转换工具/xiyou_export.py          # → modes/xiyou/generated/
cd ../03_转换工具/mv_oracle && npm install         # 参照引擎依赖（只需一次）
node slice_probe.cjs && node map_probe.cjs          # 生成对照基准（测试用）
```

然后用 `../07_开发环境/打开重制工程.command` 打开，或 `../07_开发环境/godot --path .` 直接运行。

## 目录

- `core/`、`scenes/`：共用入口与路由；`content/modes.json` 为模式原件。
- `modes/xiyou/core/`：数据（XDB）、战斗者（XBattler/XActor/XEnemy）、伤害（XDamage，移植正式版 CodexDamage）、状态与存档（XState/XSave）。
- `modes/xiyou/map/`：MV 图块绘制与通行、角色/事件/玩家、事件解释器、地图场景。
- `modes/xiyou/battle/`：战斗规则（XBattleLogic）、侧视战斗画面、MV 动画播放。
- `modes/xiyou/ui/`：文字代码转换、对话框、商店、菜单、样式。
- `tests/`：`检查.sh` 自动运行。xiyou_rules（与正式版对照能力值/伤害）、xiyou_map（通行对照）、xiyou_battle（战斗规则）、xiyou_flow（无人操作走完首期流程）、ui_smoke（入口）。

开发编号以上级 `开发编号.json` 为准，用 `07_开发环境/开发编号.py bump` 递增。首期范围见[首期可玩版规格](../00_设计/首期可玩版规格.md)。
