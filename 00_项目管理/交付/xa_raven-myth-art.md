# 交付：xa/raven-myth-art

- 车道／工作者：ag（默认模型，乙档美术接入）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【ag·未经审查】渡鸦神话形态新美术接入（O-待定，dev.待定）

- 玩家可见：167 号角色「渡鸦」战斗中神话形态（`UserSV_RavenMythic`）切换为 Kyo 2026-11-15 定稿的 18 动作 20 帧新美术，画布 340×280、可见框 `[61,58,259,217]`、脚底第 217 行与黑龙形态（`UserSV_MiraDragon`）对齐，由开关 `XRaven.ART` 控制一键回退。
- `03_再刷重制_Godot/01_Godot工程/content/raven/`：
  - 复制定稿素材 `img/sv_actors/sv/UserSV_RavenMythic/UserSV_RavenMythic*.png` 共 20 张（严格保留原版命名，340×280，二值透明 alpha 仅 `0`/`255`，全部可见框位于 `[61, 58, 259, 217]` 内、脚底统一第 217 行）并生成对应 `.import` 与 `README.md`；`modes/xiyou/generated/img/sv_actors/sv/UserSV_RavenMythic/` 原版图保留不删。
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/raven.gd`：新增回退开关 `XRaven.ART := true`。
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/xdb.gd`：`img_path()` 在 `XRaven.ART` 开启时优先把 `UserSV_RavenMythic*` 指到 `res://content/raven/img/sv_actors/sv/UserSV_RavenMythic/`（先于 `generated/img/`）。
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/appearance.gd`：`PROFILES["UserSV_RavenMythic"]` 更新为 `[340, 280, 66, 58, 255, 217]`（`0_0` 站姿格可见高 159、脚底 217 行、缩放 `72 / 159`，与黑龙 `UserSV_MiraDragon` 一致）；新增 `RAVEN_OLD_PROFILE := [380, 280, 84, 55, 268, 211]` 并在 `profile_of()` 于 `XRaven.ART == false` 时回退。
- 测试：
  - 新增 `tests/xiyou_raven_myth_art.tscn`／`.gd`／`.gd.uid`（覆盖 20 张新图路径优先取自 `content/raven/`、340×280 尺寸、二值透明、可见框与脚底 217、18 动作映射到 20 张新图、`0_0` 站姿归一档与缩放同黑龙 `UserSV_MiraDragon`、普通形态 `Raven_Normal_SV` 不受影响，以及 `XRaven.ART = false` 完整回退到 `generated/` 380×280 原图与旧档）。
- 验证：
  - `tests/xiyou_raven_myth_art.tscn`（headless 与有窗口模式）：22/22 通过；
  - `tests/xiyou_actor_looks.tscn`：35/35 通过；
  - `tests/xiyou_appearance.tscn`：34/34 通过；
  - `tests/xiyou_raven_visual.tscn`：55/55 通过；
  - `tests/xiyou_raven_battle.tscn`：368/368 通过；
  - `tests/xiyou_sv_smooth.tscn`：140/140 通过；
  - `发行空壳.py check`：通过（58 个脚本，483 个函数都有）；
  - `语法检查.py`：877 个 `.gd`，0 个问题；
  - `工具回归.py`：20/20 全部通过；
  - `回退开关覆盖.py`：通过（退出码 0）。
- 提交：84ccc8f7e

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/raven.gd` `XRaven.ART`、`core/xdb.gd` `img_path`、`core/appearance.gd` `PROFILES`／`RAVEN_OLD_PROFILE`／`profile_of`；`content/raven/`；`tests/xiyou_raven_myth_art.gd` | 167 号「渡鸦」神话形态使用原版 `UserSV_RavenMythic`（380×280、可见框 `[84,55,268,211]`）20 帧逐帧图 | 渡鸦神话形态战斗逐帧图默认切换为 2026-11-15 定稿 20 帧新美术（340×280、可见框 `[61,58,259,217]`、脚底 217，与黑龙对齐），保留原版图作回退 | Kyo 2026-11-15 拍板渡鸦神话形态 18 动作 20 帧定稿接入，尺寸／脚底与黑龙 `UserSV_MiraDragon` 对齐 | `XRaven.ART = false`（`tests/xiyou_raven_myth_art.gd` 对开关双态分别验证） | ag | 保留 |

## 交接板

- 下一步：无
- 需要用户决定：无

## 进度账

- 美术接入：渡鸦神话形态 18 动作 20 帧新美术（340×280、可见框 `[61,58,259,217]`、脚底 217，缩放 `72 / 159` 与黑龙对齐）已接入工程，原版图保留不删、默认新图优先且支持 `XRaven.ART = false` 回退。

## 对比截图

左：原版（`XRaven.ART = false`）／ 右：新版（`XRaven.ART = true`），均于有窗口 Godot 战斗实机截出并等比拼合（位于 git 忽略目录 `/Users/kyo/orca/workspaces/再刷项目资料库/xa-raven-myth-art/03_再刷重制_Godot/04_验证/本地结果/xa_raven_myth_art/`）：

- 战斗神话形态待机与攻击总览（上待机／下攻击）：![渡鸦神话形态待机与攻击原版vs新版对照](../../03_再刷重制_Godot/04_验证/本地结果/xa_raven_myth_art/battle_myth_compare.png)
- 战斗待机（`wait` 第 0 帧）：![渡鸦神话形态待机原版vs新版对照](../../03_再刷重制_Godot/04_验证/本地结果/xa_raven_myth_art/battle_idle_compare.png)
- 战斗攻击（`swing` 第 1 帧）：![渡鸦神话形态攻击原版vs新版对照](../../03_再刷重制_Godot/04_验证/本地结果/xa_raven_myth_art/battle_attack_compare.png)

## 留给总装跑的长测试

- `03_再刷重制_Godot/07_开发环境/检查.sh`（全量测试与全仓回归）：按派单约定留给总装合并时跑（另 `选测.py main --list` 因新增 `content/raven/` 资源触发整轮规则，同样留总装跑）。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 84ccc8f7e 渡鸦神话形态新美术接入（O-待定）
