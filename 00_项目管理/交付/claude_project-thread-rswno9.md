# 交付：claude/project-thread-rswno9

- 车道／工作者：天启篇丁·按段异化（四线共用）／cc（云端线程「实装天启篇四线按段异化」）
- 状态：可合并

## 依赖与合并顺序

- 本分支从 `cc/pro-tianqi-war` 切出，又合了饥荒线车道 `claude/project-thread-bjkwzm`（XTianqiLine、饥荒线，到 31d7724a；它已合了 31～36 层重做 `claude/project-thread-r4t9e0`）。
- **合并顺序：`cc/pro-tianqi-horsemen` → `cc/pro-tianqi-war` → `claude/project-thread-r4t9e0` → `claude/project-thread-bjkwzm` → 本分支。** 先合前面几支后本分支只剩自己的提交（那几支的交付单也在本分支里，合并工具会一并归并）。
- 发行开关 `XTianqi.RELEASE_OPEN` 没动（仍是 false）：发行构建里天启篇整个不开，按段异化只认天启篇存档且选了做好的线。

## 变更记录草稿

## 2026-11-11 【cc·丁·未经审查】天启篇按段异化（四线共用）：6～36 层稀有、首领、守层者、深渊怪按段表异化（dev.待定）

- 按设计仓库《天启篇四线剧情与关卡设计稿 v0.4》第 3.1、3.3、5.1 节和《四线异化与异化装备重构 v0.8》第 2.1 节实装普通楼层的异化判定。
- 新数据表 `modes/xiyou/tianqi_data/seg_alien.json`（只读，测试参数）：稀有度类（按敌人数据名的【前缀】）、七段的几率／基础级／升级几率、五档难度修正、各线每段教的种类。
- 新模块 `core/tianqi_seg_alien.gd`（XTianqiSegAlien，开关 `ENABLED`）：
  - 谁能异化：稀有、精英＝稀有；前所未见、亘古未有、首领＝非常稀有；守层者；被封印者、未知存在、古神＝深渊怪。无前缀、罕见、十分罕见是小怪，不异化。
  - 楼层：所在地图的层（`XDungeon.map_floor`），找不到时按修行进度层（变量 20 − 1）。1～5 层一概不异化，守层者也不。
  - 段表：6～10 层稀有 11%／首领 33% 侵染，守层者侵染；逐段升到 31～36 层稀有 33% 蚀骨（化形 20%）、首领 88% 化形、守层者终焉；深渊怪 6 层起一定化形。
  - 难度：寻常几率 ×0.5、稀有最高侵染、守层者低一级（最低侵染）；九死 +10 个百分点；炼狱、证道 +20 个百分点、稀有的级上限高一级（最高化形）。守层者、深渊一定异化，终焉不受难度影响。
  - 一场最多一只，按守层者＞深渊＞非常稀有＞稀有挨个掷（同类按敌群顺序）；用本场随机流（`tianqi_seg.*`）。
  - 种类：本线到这一层为止教过的种类里随机一种（每段多一种），深渊怪本线种类全出；只抽本线模块已经做好的（战争线的连击兵还没做，先不出）。
  - 本线预设异化（开场、使徒）和四骑士战不覆盖；没选线、还没做好的线（死亡、瘟疫）不动。
- 四线接口（`core/tianqi_line.gd`）：加 `alien_apply`、`alien_kinds`、`alien_active`，按线分派到本线异化模块。战争线 `XTianqiWarAlien`、饥荒线 `XTianqiFamineAlien` 的 setup 拆出 `apply(logic, s, key, list)` 和 `kinds()`，预设战照旧走 setup → apply，行为不变。
- 挂钩：`battle_logic.gd` setup 加一行 `XTianqiSegAlien.setup`（在各线预设异化、34 层鸿钧之后）。
- 31～36 层 Boss 终焉（31～36 层重做交付单留给本车道的那条）：31～33 层原守层者和 34 层鸿钧（名字「【守层者】鸿钧」）按守层者在 31～36 层段一定终焉；35、36 层影子和骑士是四骑士战，不动。
- `天启篇数据校验.py` 加 seg_alien 一组（数字避开 4、1～36 层段表连续、级名和难度键齐全、几率在 0～100）。
- 新专项 `tests/xiyou_tianqi_seg_alien`。
- 玩家可见：开发版天启篇存档选了战争线或饥荒线后，6 层起的稀有怪、首领、守层者、深渊怪会按段异化（名字「侵染·」等，带本线规则）；发行版看不到（天启篇关着）。

### 未做（下一单）

- 死亡、瘟疫两线：模块做好后在 `XTianqiLine.alien_apply／alien_kinds／alien_active` 各加一行，并按自己的种类键改 `seg_alien.json` 的 `lines.death／plague.teach`（键是 cc 占的位，已告知两条车道）。
- 战争线连击兵（11 层起教）还没做，段表里有，抽种类时自动跳过。
- 原版的 1% 异化遭遇（XAlienBattle）和怪物「神话」在天启篇里还开着，没去掉（v0.8 第 2.3 节「去掉神话」归数值车道）；同一只怪可能叠两种异化的生命加成。
- 异化装备掉落（v0.8 第 1.2 节掉率）、异化图鉴、画面（级的纹、附加件、本线色调）都没做。
- 31～36 层里不带【守层者】前缀的 Boss（如果以后加）不会自动终焉，要在表里加类或改名字。

## 交接板

- 下一步：按上面顺序合并；死亡、瘟疫线做好后各补一行接口；数值阶段再定段表几率。
- 用户试玩说明：开发版新开天启篇档，选战争线或饥荒线、打完开场后去 6 层以上，遇到稀有怪、首领、守层者时名字前会出现「侵染·」「蚀骨·」等，战斗日志里报本线的计量。
- 需要用户决定：无（炼狱「稀有级上限高一级」、古神算深渊怪是 cc 的读法，写在表的 `_note` 里，Kyo 想改直接改 `seg_alien.json`）。

## 进度账

- 天启篇（扩展账）：按段异化 0 → 段表、难度修正、战争和饥荒两线接上；死亡、瘟疫两线待接，掉落和画面未做。

## 可优化（流程／工具／效率）

- 已做：各线异化模块统一成 `apply`＋`kinds` 两个入口，按段异化只认 `XTianqiLine` 的分派，新线接入只加三行（回退：关 `XTianqiSegAlien.ENABLED`）。
- 建议：云端容器首次 `godot --import` 超过 `云端准备.sh` 的 900 秒上限会被掐断（本轮 4 核约 25 分钟以上），可以把导入缓存一起放进 `generated.tgz` 或把上限调大（归工具车道）。

## 在 Mac 上要跑的专项

本分支改了 `battle_logic.gd`（战斗核心）：

- 必跑：＊`xiyou_rules*`、＊`xiyou_event_compare*`（云端跑不了）、`xiyou_tianqi_*`、`xiyou_determinism`、`xiyou_alien_battle`，以及 `选测.py main --list` 列出的组（或直接 `检查.sh --full`）。

## 验证

云端容器（Godot 4.7.2 Linux，转换产物取自 `refs/ci/generated/main`）：

- 新专项 `xiyou_tianqi_seg_alien` 64/64（段表、难度修正、种类、判定、开战：战争线 10 层守层者侵染、饥荒线 12 层蚀骨、34 层鸿钧终焉、使徒和四骑士战不覆盖、没选线／没做好的线／开关关／原版档不动）。
- `并行测试.py` 一批 36 个全过：`xiyou_tianqi_*`（16 个，含 war 96/96、famine 99/99、summit）、`xiyou_boss_*`、`xiyou_map_*`、`xiyou_determinism`、`xiyou_alien_battle`、`xiyou_alien_affix`、`xiyou_enemy_book`、`xiyou_battle_pace`、`xiyou_action_sequence`、`xiyou_lobby_corruption`、`xiyou_actor1_damage`、`xiyou_attack_query`。
- `天启篇数据校验.py` 全过（含 seg_alien）。
- `选测.py main --list` 判整轮（本分支带着四条未合的天启篇分支）；没跑全量 `检查.sh`（车道规则），`xiyou_rules*`、`xiyou_event_compare*` 云端跑不了，见上「在 Mac 上要跑的专项」。

## 本分支提交

- WIP: 按段异化 XTianqiSegAlien（段表、难度、种类）接战争线 apply；专项与数据校验
- WIP: 合入饥荒线车道 XTianqiLine；按段异化改走 XTianqiLine.alien_apply／alien_kinds，饥荒异化拆出 apply
- WIP: 再合饥荒线车道（含 31～36 层重做）；按段异化放在 34 层鸿钧之后，鸿钧终焉
- 本次：交付单可合并
