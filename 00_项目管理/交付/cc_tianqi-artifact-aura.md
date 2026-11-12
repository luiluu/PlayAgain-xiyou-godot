# 交付：cc/tianqi-artifact-aura

- 车道／工作者：天启篇·通用法宝光环按养成分阶／cc（项目线程「完成再刷西游 Godot 引擎重制」）
- 状态：可合并

## 依赖与合并顺序

- 从 main（dev.505，含 cc/tianqi-gear-affix-roll）切出，不依赖待合的分支。

## 变更记录草稿

## 2026-11-12 【cc·天启篇·未经审查】天启篇通用法宝带光环，阶随法宝养成（dev.待定）

- 按设计仓库《天启篇_词条重构设计稿 v0.3》第 7 节「法宝：只有通用法宝有 1 个词条槽，只出光环，获得时 50% 几率带一条；按养成进度算阶」。只认天启篇存档。
- `core/tianqi_affix_roll.gd`（XTianqiAffixRoll）加法宝分支：通用法宝（CP_MagicWeapon 的法宝，没有 `<req_actors>`、不是 `<KyoUnique>` 独特物件）在 `XGear.roll_item` 生成时按表里 `artifact_aura.chance`（50%）带一条光环（记 `growth: true`），阶按法宝等级／满级：不到三分之一二阶、不到三分之二三阶、再往上四阶。专属法宝、独特法宝不出。
- `core/magic_weapon.gd`：`level_up` 升级后调 `XTianqiAffixRoll.refresh_growth`，光环按新等级重定阶、说明跟着重写。
- 光环效果走已有的 `XTianqiAffixBattle`（同名全队取最高），不用另接。
- 新专项 `tests/xiyou_tianqi_artifact_aura`（10 项）。
- 玩家可见：开发版天启篇存档里新得到的通用法宝有一半带一条全队光环，法宝升级光环跟着变强。发行版看不到（天启篇关着）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_affix_roll.gd`（法宝分支，随 `XTianqiAffixRoll.ENABLED`）、`core/magic_weapon.gd`（`level_up` 一行） | 原版法宝光环是插件四档固定值 | 天启篇存档的通用法宝 50% 带一条天启篇光环，阶随养成 | 词条稿 v0.3 第 7 节（已定） | `XTianqiAffixRoll.ENABLED = false`（整套天启篇词条关掉）；单关法宝：`affix_table.json` 的 `artifact_aura.chance` 改成 0 | cc | 已接受（Kyo 11-11 优化直接接受） |

## 交接板

- 下一步：无（法宝光环这一项做完）。
- 用户试玩说明：开发版天启篇档拿通用法宝（不是角色专属的），看说明末尾有没有一行光环；用法宝经验丹把它升级，光环的阶会从二阶升到四阶。
- 需要用户决定：无。

## 进度账

- 天启篇词条（扩展账）：法宝光环分阶 0 → 已接；重铸未做。不写主表。

## 可优化（流程／工具／效率）

- 无。

## 验证

- `xiyou_tianqi_artifact_aura`：10/10。
- 相关专项（Mac，本工作树，`并行测试.py`，8 个场景，162 秒，全部通过）：`xiyou_tianqi_artifact_aura`、`xiyou_tianqi_affix_roll`、`xiyou_tianqi_affix_battle`、`xiyou_magic_weapon`、`xiyou_magic_weapon_level`、`xiyou_tianqi_party`、`xiyou_tianqi_gear`、`xiyou_determinism`。
- 反向验证（`反向验证.py`，单跑本专项）：法宝不掷、专属也掷、必带、升级不改阶、阶不看养成，5 处全部咬住。
- `语法检查.py`：通过。
- `交付自检.py`：提交后跑，见回报。

## 本分支提交

- 天启篇通用法宝光环与专项
- 交付单
