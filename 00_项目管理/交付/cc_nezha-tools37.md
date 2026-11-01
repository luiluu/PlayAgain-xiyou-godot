# 交付：cc/nezha-tools37

- 车道／工作者：C 工具／cc（哪吒）
- 状态：可合并

## 变更记录草稿

## 2026-11-01 【cc·哪吒·未经审查】tools37：第六批选测 260 个场景的原因、extraSvFolders 归图像组（dev.待定）

- **第六批选了 260 个场景（全工程 309 个）是对的，没有找到安全的大幅收窄。** 对基点 7d72dd80 到 909f5638（drops1／yunshang8／relic3 等）逐文件看：`core/actor.gd`（187 个场景，其中 `param` 取值顺序重排、`addState`／`die` 前后加云裳／三法宝钩子）、`battle/battle_logic.gd`（128）、`core/battler.gd`（90，谷雨钩子进 `addState`／`removeState`／`recoverAll`／`is_dead`）都是改了每个角色都走的路径，战斗核心类要宽（`xiyou_rules*` 全段＋引用 XActor／XBattler／XBattleLogic 的专项）；这三份的并集 221 个。其余 `map_scene.gd`（95）、`battle_scene.gd`（79）、`mv_script.gd`（62）、转换器类 26 个（`同步正式西游.py`、`xiyou_slice.json`、几个 probe）并进来再多 39 个（airship／shop／hud 之类）。
- 试过按「脚本里有没有战斗类」收窄 `actor.gd` 的引用：只能去掉 22 个，而且被去掉的是 `param_max`、`dual_wield`、`custom_params`、`costumes`、`power` 这类恰好依赖 actor 取值的专项，不安全，没做。「只加新函数的纯新增改动才收窄」也不适用：这批 actor／battler／map_scene 的改动都是往现有函数里插调用，纯新增判断会放过它们。
- **做了的小收窄**：`xiyou_slice.json` 的 `extraSvFolders`（导出时拷的 SV 战斗图文件夹）原来不在 `选测对照.json` 的切片键表里，一改就退回整组 converter（`xiyou_rules*` 全部段）；现归 `slice_asset`（事件对照＋界面专项＋导出）。这批的 260 不变（战斗核心类已把它们全选了），但以后只改 SV 文件夹名单时少跑 26 个。`测试选测.py` 加 1 个用例。
- 另一个办法（没做）：总装收尾 `--finish --affected` 前，车道各自已经跑过自己的选测，可考虑只补跑「合并后新组合」才会暴露的场景，需要总装定规则。

## 交接板

- 下一步：无
- 用户试玩说明：无
- 需要用户决定：无

## 进度账

- 无（工具车道）

## 可优化（流程／工具／效率）

- 已做：见上。建议：每个场景记录它依赖的源文件（运行时由 Godot 的资源加载记下），选测直接按依赖求交，而不是按类名引用；工程量中等，收益最大（工具车道，需总装排期）。

## 验证

- `测试选测.py` 64 个全过；语法检查通过；收窄前后对第六批基点 7d72dd80→909f5638：260 → 260（此批无变化）。

## 待交叉核查

- 无需

## 本分支提交

- 见 git log
