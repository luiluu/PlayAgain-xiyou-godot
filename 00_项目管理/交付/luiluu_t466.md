# 交付：luiluu/t466

- 车道／工作者：cc（Opus＋medium，P8；T464 原车道接着做）
- 状态：可合并（排在三阶段整包之后合）

## 变更记录草稿

## 2026-11-24 【cc·未经审查】T466：13～30 层替身守层者（非求道者教派）记首通真气，读档按已通关层补发（O-待定·替身守层者首通，dev.待定）

- **起因**：T464 查清，开局没选「求道者雕像」的西游档（天道使者 2302、攻击引路人 2303、轮回归来 2307）在 13～30 层打的是替身敌群（748～765、798～814，26 层是 761），真气的守层者表 `GUARDIANS` 不认它们，所以不记首通，只给 Boss 奖励。这是原版就有的缺口。Kyo 11-24 事项53 定：「修，带开关」；「补，读档时按已通关层数补发」；补给当前队伍全员（出战＋后备，即 party，不含仓库里的角色），只补当前路线。
- **改动**：
  - `modes/xiyou/core/zhenqi.gd`：加 `STAND_IN_GUARDIANS`（敌群→层，36 项）、`STAND_IN_SECT_SWITCHES`、回退开关 `STAND_IN_FIRSTS`。`battle_setup` 只在本场不是正牌守层者、不是心魔或神兵试炼、也不是天启篇档时查替身表，记进 `battle.standInFloor`，并给存档打标记 `flags.zqStandInFirsts`；`guardianFloor` 照旧只放正牌层。`on_victory` 用「正牌层或替身层」走首通＋每胜分支：首通 10×层×系数，每胜 3×层×系数，不再给 Boss 奖励，与正牌同口径。首通键照旧是 `路线:层`，同一层正牌和替身不会重复记。`GUARDIANS` 没动，天启篇掉落 `tianqi_drop.gd:506`、试炼取守层者 `guardian_troop_of_floor`、星爆书礼（读 `guardianFloor`）都照旧。
  - 读档补发 `XZhenqi.backfill_stand_in`，挂在 `modes/xiyou/core/xsave.gd` `_load_data` 里，手动读档和读切后台存档两条入口都走到。补发条件：西游档、开关开、还没打标记、教派开关 2302／2303／2307 任一开着、修行进度层 ≥13。补哪些层：13～min(30, 进度层)。补给 party 每人当前路线缺的首通（10×层×系数），已有的键跳过，不补每胜；补完打标记，只补一次。进度层不到 13 的不补也不打标记，之后打替身战时由 `battle_setup` 打标记。点数直接加进真气，同原版 migrate 补楼层的做法，不逐人弹境界提示。进地图时弹一条汇总提示（`map_scene.gd` → `XZhenqi.map_start`）。
  - 补发没挂在 `XState.from_dict` 上：战斗回放、存读档往返测试也走 from_dict，挂在那里会在不是读档的地方补发。
- **实测（阿夜存档副本，原件没动，`cmp` 一致）**：用临时 HOME，走真实读档 `XSave._load_data`，无头 `--audio-driver Dummy`。这份档是洪荒路线，开着 2307（轮回归来），进度层 33。party 9 人（出战 147/159/119/117/108，后备 118/129/130/131），仓库里的角色共 38 个，不补。补完 9 人每人 +50,310（＝130×(13+…+30)），共 +452,790。补后 9 人都有 `primordial:13～30`，第二次补发返回空。开关关掉（`STAND_IN_FIRSTS = false`）时什么都不补、不打标记，firsts 只有原来的 31～33 层。
- **玩家可见**：西游档非求道者教派的玩家，13～30 层守层者打赢后会出「真气 …（首通）」，每胜也给守层者真气（以前只给 Boss 奖励，少一截）。老存档读档进地图时弹一条「补发洪荒第13～30层守层者首通真气：9 名队员共 +452790」，路线名和层数按档。提示文字待小A 审。

## 交接板

- 下一步：小A 审读档补发提示文字（`zhenqi.gd` `backfill_stand_in` 里的 `_pending_notice` 那一行）；合并时把 O-待定 换成实际编号（`zhenqi.gd` 注释、`00_设计/优化登记.md`）。
- 用户试玩说明：非求道者雕像开局的西游档，读档进地图会提示一次补发真气；之后 13～30 层守层者每场都按首通／守层给真气。
- 需要用户决定：无（口径 Kyo 11-24 已定：party、当前路线）。

## 进度账

- 无变化（原版缺口修复）

## 可优化（流程／工具／效率）

- 建议：星爆书的守层者礼（`starburst_books.gd` `GIFTS` 读 `guardianFloor`）对替身守层者也不给，是同一个原版缺口。本单没动，因为派单只让在 XZhenqi 认层。要不要一起修，由总装或 Kyo 定，再派小单。
- 建议：用 `-s` 起 SceneTree 脚本跑存档时，自动加载的 GameApp 不在，`XSave` 编译不过；拿玩家存档实测要用临时 tests 场景（用完删掉），别用 `-s`。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XZhenqi.battle_setup` | 游戏代码 1 处（`battle_logic.gd:195`），测试 13 处（`git grep -nE 'XZhenqi\.battle_setup\|XZhenqi\.on_victory' -- '*.gd'`） | 调用方 1 处逐处结论：签名没变；只多了 `standInFloor` 键，只有替身敌群才非 0，其余场次 `f` 和 `guardianFloor` 与原来逐值相同 |
| `XZhenqi.on_victory` | 游戏代码 1 处（`battle_logic.gd:3930`） | 调用方 1 处逐处结论：`standInFloor` 为 0 时分支与原来完全相同；读的是 `b.get("standInFloor", 0)`，旧的 battle 字典（回放快照）缺这个键也不报错 |
| `XZhenqi.battle` 字典 | 读者：`starburst_books.gd:61`（guardianFloor）、`tianqi_brand.gd:261/853`（trial／scaled）、`guardian_rework.gd:585/685`（trial）、`battle_replay.gd:57`（整份复制）、`battle_logic.gd:1221`（trial） | 都不读新键，guardianFloor 没变，不受影响 |
| `XSave._load_data` | 2 处（`xsave.gd:176` 读切后台存档、`:349` 读档位） | 两处都要补发，符合口径 |
| `map_scene` 进地图 | 新加 `XZhenqi.map_start()` 一行 | 没有待放的提示时空转 |
| `XZhenqi.STAND_IN_FIRSTS`（新开关） | 专项 `xiyou_zhenqi_standin` 设 false 测过回退 | — |

## 测试

- 专项（本机）：`xiyou_zhenqi_standin` 47/47。内容：替身表与 18 张图守层者事件 2302／2303／2307 页的敌群逐项相同；不并进 GUARDIANS；三种教派各一场的首通与每胜；正牌照旧；开关回退；补发数额、上限 30、只补一次、存读档后不再补；不到 13 层、求道者档、普通路线；天启篇不认也不补。
- 云端选测：通过。提交 41d8f3965d，基准 3e86b53dfd，331 个场景、8 片，最长一片 13.4 分钟；`gh run watch` 等完结论 success。运行页：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45442607672
- 发行空壳：`发行空壳.py check` 退出 0（80 个脚本、774 个函数都有）。
- 截图：本单没有截图（读档补发提示没截图，文字等小A 审）。

## 本分支提交

- 41d8f3965 T466：替身守层者记首通真气＋读档补发（O-待定，STAND_IN_FIRSTS）
- 本交付单
