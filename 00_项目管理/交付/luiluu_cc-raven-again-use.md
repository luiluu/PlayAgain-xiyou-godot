# 交付：luiluu/cc-raven-again-use

- 车道／工作者：T088 T046 回归判定（cc，Opus 5.5＋medium）
- 状态：可合并

## 结论（验收 1）

**不是 T046 代码错，是 `xiyou_raven_fx` 专项口径过时（没钉随机）。T046 行为与原版一致，`AGAIN_USE` 开回 true。**

- **渡鸦为什么走到 AgainUse**：渡鸦 99 级学会 10137「魂海刻度」，备注 `<AgainUseMf:15>`（说明卡也写「魔法再释放＋15%」）；10122～10127 都是 stypeId 2（魔法），所以 T046 接上 dsPassiveSkill 后，渡鸦每次放这几招有 15% 掷中、numRepeats 1→2。
- **原版掷中时特效放几次（证据）**：参照 `raven_fx_probe.cjs` 新加 `again.*` 6 例（出手前把 `Math.random` 钉 0，原版 dsPassiveSkill `Math.random()*100 < 15` 必中）：numRepeats 全是 2；**单体技能 10122／10123／10125／10127 施放特效两组**（makeTargets 重复目标，showNormalAnimation 分两次调），**全体技能 10124／10126 一组**（同一次调用里目标去重）。重制开着 AGAIN_USE 时完全一样。
- **专项为什么偶发失败**：参照 host 的 `newGame()` 把 `Math.random` 固定成 0.5（`shared/host.cjs:18`），0.5×100<15 永远不中，所以夹具里一律一组；Godot 专项用真规则流，12 次出手每次 15% 掷中，约 86% 的概率至少一例变两组（总装那次挂 10123，我本机复现挂的是 10127）。
- **根因行**：`tests/xiyou_raven_fx.gd` 的 cast.* 循环没钉 `again_use` 那一掷（T046 之前通用出手不掷，这个洞看不出来）。`battle_logic.gd` `passive_repeats` 不用改。

## 改动

- `tests/xiyou_raven_fx.gd`：加 `PinAgain`（继承 XRandomStream、拷原流状态，只把 reason＝`again_use` 的 next_float 换成固定值，其余照原流取数）；cast.*／twice／other 各例钉 0.5（同参照）；新加 `again.<id>.repeats`／`again.<id>.casts` 12 条断言（钉 0，比参照的 numRepeats 与施放特效组数、目标数）。夹具例数 14→20。
- `03_转换工具/mv_oracle/raven_fx_probe.cjs`：加 `again.*` 6 例（只比施放特效，别的随机也变 0，slash 等不比）；原 14 例产物逐字节同旧夹具（已核）。`tests/fixtures/raven_fx_oracle.json` 换新产物。
- `battle_logic.gd`：`AGAIN_USE := true`，注释写明 11-16 临时关与 T088 判定。
- `tests/xiyou_again_use.gd`：总装热修加的 `AGAIN_USE = true` 那行**保留**，只改注释：专项测开着的行为，不该依赖默认值，防默认再变。
- `选测对照.json`（验收 3）：新组 `battle_logic`（同 battle 组＋固定 `xiyou_raven_fx`、`xiyou_again_use`），battle_logic.gd 规则改指它；`选测.py main --list` 已能列出两者。

## 验证

- 修前：本机 AGAIN_USE=true 单跑 `xiyou_raven_fx` 挂 `cast.10127.normal.fx`（两组 vs 一组），复现。
- 修后：`xiyou_raven_fx` 66/66、`xiyou_again_use` 89/89（AGAIN_USE=true）。
- 反向验证（`反向验证.py`）：AGAIN_USE 改 false → again.* 挂（咬住）；PinAgain 默认值改 0（等于 cast.* 掷中）→ cast.* 挂（咬住）。
- T063 试合（本树 `git merge --no-commit cc/tianqi-again-use`，测完 `--abort`，未提交）：`xiyou_tianqi_again_use` 14/14、`xiyou_again_use` 92/92、`xiyou_raven_fx` 66/66、`xiyou_tianqi_nine_off` 19/19、`xiyou_tianqi_skills` 231/231。T063 合并时 battle_logic.gd 注释块会冲突：两边注释都留、`static var AGAIN_USE := true` 下面接 T063 的 `TIANQI_AGAIN`。
- `语法检查.py` 0 问题；`工具回归.py` 全过。
- `检查.sh --affected main --cloud`、整轮云端全量、`交付自检.py`：见下文「验证（收尾）」。

## 我不同意的地方

- 派单把它定性为「T046 回归」、方向偏「修代码」；按原版证据它是测试口径问题，所以修的是测试、没动出手逻辑。另一个可选口径是「渡鸦施放特效每次行动只放一组」——那是对原版的改动，要 Kyo 定，我没做。
- 同类风险：别的专项若带着有 AgainUse／atkk 来源的角色、又按固定段数或特效数断言，也会因 T046 变偶发。这次整轮全量只挂了 raven_fx，没有一个个查；如再有偶发，先看是否同一原因（钉 `again_use` 一掷即可）。

## 变更记录草稿

## 2026-11-16 【cc·未经审查】T088 渡鸦施放特效两次判定：不是 T046 回归，专项钉随机、AGAIN_USE 开回（dev.待定）

- 渡鸦 10137 魂海刻度 `<AgainUseMf:15>` 让 10122～10127 有 15% 再释放；原版掷中时单体技能施放特效同样放两组、全体一组（`raven_fx_probe.cjs` 新 `again.*` 6 例）。`xiyou_raven_fx` 原先不钉随机、参照钉 0.5，T046 后变偶发。
- 专项加 PinAgain 只钉 `again_use` 一掷；新增 again.* 12 条断言（AGAIN_USE 关掉会挂）；夹具 14→20 例。
- `XBattleLogic.AGAIN_USE` 开回 true（O-547 恢复「保留」）；`选测对照.json` 新组 `battle_logic` 固定选 raven_fx／again_use。
- 玩家可见：渡鸦学会魂海刻度后，魔法 15% 再释放一次（含施放特效），与原版一致。

## 交接板

- 下一步：T063（cc/tianqi-again-use）可在本单之后合，冲突处理见「验证」。
- 优化登记 O-547 状态改回「保留」（去掉「11-16 临时关」括注），车道不改共用文件，请总装合并时改。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 已做：`选测对照.json` 给 battle_logic.gd 单列组、固定选出手次数相关专项（回退：规则改回 `"group": "battle"`）。
- 建议：参照探针的 host 把所有随机钉 0.5，Godot 专项却用真规则流——凡是比参照的战斗专项都可能有这类「新掷点加进来就偶发」的洞。可以给 XBattleLogic 加一个测试用的「按 reason 钉值」入口，专项统一用（收益：以后新加掷点不再出偶发；归战斗测试工具车道，Sonnet＋medium 即可）。

## 本分支提交

- c59d4a35f T088：raven_fx 钉 again_use、参照加再释放 6 例、AGAIN_USE 开回、选测对照
