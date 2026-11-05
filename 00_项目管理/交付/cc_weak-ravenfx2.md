# 交付：cc/weak-ravenfx2

- 车道／工作者：B 界面＋工具／ravenfx2（cc，派单第八批 AW）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·ravenfx2·未经审查】战斗精灵画面量具（无头 Chrome）与渡鸦神话大图实测（dev.待定）

- **量具** `03_转换工具/mv_oracle/real/sprite_real.cjs`：用本机 Playwright 无头 Chrome 真跑冻结正式源，进一场战斗、按规格里的步骤改状态，记指定角色 Sprite_Actor 最终画的图名、图大小、可见帧、缩放、偏移、锚点、透明度、武器／影子显示，并截图。照白龙 11-05 量米拉黑龙时手写的脚本整理成通用工具（规格 JSON、只读 http 只给冻结源、别的主机全拦、只写 `.sandbox/sprite_real/`）。`real/` 目录从探针缓存公共键里排除（`incremental_sync.py` 一处），加量具、加规格不会让全部探针重跑。README 加了一节。
- **#4 渡鸦神话静态大图**（规格 `real/raven_myth.json`，结果快照 `real/raven_myth.result.json`）：原版 installNativeRavenMonsterVisual 想把神话形态换成 Raven_Mythic_Monster（0.60、(−20,155)），实机被 Mx_SuperSV 多帧盖掉、从不出现。最终画的是 UserSV_RavenMythic 逐帧图，缩放 0.4615，武器和影子藏起来，和重制已有的一致。只剩一条漏网的：神话形态阵亡时主图透明度 0.35（那段 update 包装还在生效），重制原来没有，现在补上（`XBattlerSprite._raven_myth_alpha`）。阵亡时下移约 15 像素，是悬浮停了，重制已有。
- 专项 `xiyou_raven_visual` 51 → 55 项（神话／普通 × 开关开／关：活着 1、阵亡 0.35 或 1、复活回 1）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 渡鸦神话阵亡半透明（`battle/battler_sprite.gd` `_raven_myth_alpha`） | 原版：渡鸦神话形态阵亡时主图透明度 0.35（实机量具实测）；重制移植前阵亡也不透明 | 照原版移植 | 原版有的表现补齐（派单第八批 AW） | `XBattlerSprite.RAVEN_MYTH_DEAD_ALPHA = false` | cc（ravenfx2） | 待用户确认 |

## 交接板

- 下一步：ravenfx2 二期——#3 施放期间同技能不叠的屏蔽支抽测（见下「接续」）。
- 用户试玩说明：渡鸦变成神话形态后如果倒下，身影会变成半透明（原版就是这样）。
- 需要用户决定：上表 O-待定（默认照原版开着）。

## 接续（#3，没做）

- 原版 `js/codex/runtime/installRavenSkillEffectsRuntime.js` 84～86、108～115 行：施放期间 `isAnimationPlaying` 算没放完；同一技能的 slash／ring 正在播时不再叠一层。重制在 `battle/battle_scene.gd` 约 1621、1733 行。
- 做法建议：jsdom 探针就够（不涉及图），对 10122～10127 各放一次、放完前再放一次，记 R.Fx 队列里的特效条目数与种类；重制专项比 `XRavenFx` 的队列。量具 `real/` 用不上。

## 进度账

- 角色（渡鸦）：表现余项 #4 实测结案（大图不出现，补透明度），剩 #3 抽测。

## 可优化（流程／工具／效率）

- 已做：量具放在 `mv_oracle/real/` 并从探针缓存公共键排除（回退：删 `incremental_sync.py` 排除元组里的 `'real'`，注意那样会让下一次同步全部探针重跑）。
- 建议：米拉图鉴立绘、渡鸦以外的新角色表现核对，都可以写一个 `real/*.json` 规格直接量，不用再手搭浏览器；归白龙或界面车道。

## 待交叉核查

- 乙档：`battler_sprite.gd`（`_raven_myth_alpha`）、`tests/xiyou_raven_visual.gd`。
- 丙档：`mv_oracle/real/sprite_real.cjs`（看是否只读、只写 .sandbox）、`incremental_sync.py` 排除一处、README。

## 验证

- 专项：`xiyou_raven_visual` 55/55；量具 `real/raven_myth.json` 跑两次结果一致。
- 选测（本机，没走云端）：`选测.py main --list` 列 85 个；楼层与 xiyou_rules* 只因改了 `incremental_sync.py`（转换工具类）被牵出，那一行只是排除 `real/` 目录，不影响游戏，没跑。跑了 21 个，全过：xiyou_actor_looks、xiyou_appearance、xiyou_battle_events、xiyou_battle_log、xiyou_cat、xiyou_collapse_fx、xiyou_costume_battle、xiyou_costumes、xiyou_guyu_ui、xiyou_mv_animation、xiyou_raven_visual、xiyou_review_fixes、xiyou_sequence_visual、xiyou_state_overlay、xiyou_status_power_panel、xiyou_sve_visual、xiyou_svpngfd、xiyou_vsfx、xiyou_xuan_tusu_art、xiyou_raven_battle、xiyou_mira_battle。
- `语法检查.py`、`工具回归.py` 全过。没改探针，不用重同步。

## 本分支提交

- WIP：量具 real/sprite_real.cjs、渡鸦神话阵亡半透明
- 最后一笔：交付单、合 main、可合并
