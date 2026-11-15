# 交付：cc/mira-dragon-art

- 车道／工作者：B 美术接入·米拉黑龙无剑 21 张＋头顶召剑特效／cc（Sonnet＋medium，派单定：照先例接美术、乙档）
- 分支：`cc/mira-dragon-art`（从 main a88a92b40 切出，已合 main，无冲突）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·未经审查】米拉黑龙无剑 21 张＋头顶召剑层接入（dev.待定）

- 玩家可见：重制版战斗里米拉的黑龙形态换成 co 新画的无剑黑龙（行走／待机／攻击／施法／防御／受伤／闪避／胜利／濒死／异常／睡眠／倒地共 21 张）；原版龙手里那把剑不再画在龙身上，头顶召剑特效做成了独立层，**目前没有任何技能会召剑**（名单待 Kyo 定）。重制版可见改动**不进补丁**（派单：补丁另问 Kyo）。
- 范围（同人形 u2）：战斗里的黑龙形态（`XAppearance.for_look`／`battler_key` 的 `form:MiraDragon`）。图鉴立绘、地图行走原本就只用人形，不涉及黑龙；天启篇与重制版共用同一套 `XAppearance`，两边一样换。
- 新增：`content/mira/img/sv_actors/sv/UserSV_MiraDragon/`（21 张＋.import）、`content/mira/fx/sword_u2/`（10 张＋manifest）、`content/mira/dragon_unarmed_manifest.json`、`modes/xiyou/battle/mira_sword_fx.gd`（`XMiraSwordFx`）、`tests/xiyou_mira_dragon_art.{gd,tscn}`。
- 改：`modes/xiyou/core/mira.gd`（`XMira.DRAGON_ART`）、`modes/xiyou/core/xdb.gd`（`img_path` 取图）、`modes/xiyou/battle/battle_scene.gd`（`_perform_action` 末尾 `XMiraSwordFx.on_skill`、行动收尾 `vanish_all`，各一行）、`content/mira/README.md`。没动 battle_logic／战斗计算／随机数。
- 站姿归一表沿用 `[340,280,61,58,260,217]`（没改，测试断言）。
- 召剑层：出现 3×100ms → 悬停 3×140ms 循环 → 消散 3＋clear ×100ms；层中心＝脚底＋[-40,-200]×身体缩放（与龙体相对位置不随归一缩放变）；缩小时平滑采样、放大最近邻。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/mira.gd` `XMira.DRAGON_ART`；`xdb.gd` `img_path`；`battle/mira_sword_fx.gd` | 黑龙形态用同步出的 `UserSV_MiraDragon` 带剑图 21 张（剑画在龙身上） | 换 co 的无剑 21 张；头顶召剑做成独立层 `XMiraSwordFx`（触发技能名单 `SKILLS` 待定，默认空） | Kyo 11-15 通过 co 的 21 张＋`Sword_FX_u2` | `XMira.DRAGON_ART = false`（回原版带剑图，不建召剑层） | cc | 保留 |

## 待 Kyo 定：召剑触发的技能

代码已留好接口：`XMiraSwordFx.SKILLS`（技能号列表，默认**空**＝任何技能都不召剑）；技能开始 `_perform_action` 时若技能号在名单且是黑龙形态，剑出现→悬停，整次行动结束（`_finish_action` 之后）消散。`XMiraSwordFx.RECOMMENDED = [10151, 10152]` 只是建议，不参与判断。

原版黑龙的剑：原版 21 张龙图里 20 张画着剑（只有 10_0 没有），即原版龙「一直举着剑」。盘点米拉黑龙形态能用的动作／技能：

| 技能 | 名称 | 类型 | 原动画 | 建议 |
| --- | --- | --- | --- | --- |
| 10148 | 灼鳞裂爪 | 物理（`skill` 动作） | 18 | 龙爪攻击，不需要剑 |
| 10149 | 王焰吐息 | 魔法（`spell` 动作） | 602 | 吐息，不需要剑 |
| 10150 | 天坠翼击 | 物理 | 39 | 翼击，不需要剑 |
| 10151 | 黑日焚界 | 魔法 | 70 | **建议召剑**（黑龙终极技） |
| 10152 | 王鳞龙心 | 物理 | 52 | **可选**（黑龙强化，剑悬停合适） |
| 10146 | 解放·黑龙 | 物理 | 70 | 人形施放、之后才变龙，施放那一刻不是黑龙形态，本接口不会召（要做需另配变身演出，属 u6） |
| 10147 | 黑龙现世·劫焰 | 物理 | 70 | 只随解放放出（永不单放），同上 |
| 普通攻击 | 攻击（`thrust`/`swing`/`missile` → 7 号 4 帧） | — | — | 新 7 号已是爪扫＋前扑，不需要剑；原版 7 号才是举剑横扫 |

问 Kyo：①名单放哪几个（建议 10151，可加 10152）；②要不要常驻悬停（战斗全程头顶有剑，原版龙一直带剑）而不是只在大招里出现——要的话是加一个「黑龙形态下常驻」开关，不在本单。

## 交接板

- 下一步：核查（小A 乙档美术接入；小A 读不到素材目录时由 cc Sonnet 代核：素材在 `content/mira/` 里，已拷进仓库，不需要读 ~/.codex）；Kyo 定召剑技能名单后把 `SKILLS` 填上（改一行＋测试 `fx.*` 里的名单用例）。放大倍数、升空变身演出（u6）另单。
- 用户试玩说明：无（重制版黑龙外观可见改动，不进补丁；补丁另问 Kyo）。
- 需要用户决定：召剑触发的技能名单（见上）。

## 进度账

- 无（美术替换，不涉及移植进度）。

## 可优化（流程／工具／效率）

- 无。小发现：派单写的验证截图路径 `04_验证/本地结果/` 实际是 `03_再刷重制_Godot/04_验证/本地结果/`（仓库根没有 04_验证），截图已放后者。

## 验证

- 专项 `xiyou_mira_dragon_art` 30 项全过：取图路径（黑龙 18 动作每帧读 content/mira、21 张齐）、每张 340×280／可见框／脚底 217／alpha 二值、归一档不变、人形不受 `DRAGON_ART` 影响（开关开／关都是 u2）、召剑层时间线与锚点（中心＝脚底＋[-40,-200]×缩放）、`SKILLS` 默认空不召／名单内才召／行动结束消散／人形不召、`DRAGON_ART=false` 回原版带剑图且不建层。
- 选测（本机，`选测.py main --list` 列的战斗核心类场景里与改动相关的）：`xiyou_mira_dragon_art xiyou_mira_art xiyou_actor_looks xiyou_actor_book xiyou_mira_battle xiyou_actor_modules xiyou_actor_sv_compare xiyou_battle_log xiyou_determinism`，9 个全过（86 秒）。未跑：选测结论是「整轮」（因新增了 PNG／截图被当拿不准的文件），车道不跑全量，交总装；`xdb.gd` 的 505 个关联场景未逐个跑，xdb 的改动只在一个 `if` 且开关外路径不变。
- `语法检查.py` 0 个问题；`发行空壳.py check` 通过（62 个脚本、534 个函数）。
- 截图（与原版并排，左原版带剑、右新图，4 倍）：`03_再刷重制_Godot/04_验证/本地结果/mira_dragon_art/`：`dragon_idle.png`（待机）、`dragon_attack7_frame2.png`（攻击 7 号第 3 帧）、`dragon_spell10_frame2.png`（施法 10 号第 3 帧）、`dragon_sword_hover.png`（召剑悬停合成）。这几张在本机、不入库。

## 待交叉核查

- 本分支提交（见下）：美术接入，乙档。核查点：21 张素材与 co 来源逐字节一致（`cmp` 对 `Mira_Dragon_Unarmed_Motions_u1/UserSV_MiraDragon/`）；召剑层位置公式；开关关回原版。改了 `battle_scene.gd` 两行（挂钩）。

## 本分支提交

- 见 `git log main..cc/mira-dragon-art`

## 小A 乙档核查

- **核查对象**：`cc/mira-dragon-art`（`df8d427f5`），按只读核查要求未改任何游戏代码。
- **总体结论**：**通过**（无 P1/P2/P3 代码或规格问题；其中 4 张验证截图因本会话无看图/视觉工具，仅做像素与区域程序核对，未做人眼视觉审视，详见「未核到」）。

### 逐项核查结果

1. **21 张黑龙无剑动作图规格**【核了规则＋实跑】：
   - `03_再刷重制_Godot/01_Godot工程/content/mira/img/sv_actors/sv/UserSV_MiraDragon/` 共 21 张 PNG，文件名与数量与原版 `UserSV_MiraDragon`（本工作树实际位于 `03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw/img/sv_actors/sv/UserSV_MiraDragon/`，无 `v0.62.12/` 子层）完全一一对应。
   - Python PNG 解析逐张实测：21 张全部为 `340×280` RGBA 8-bit、alpha 仅 `{0, 255}` 二值、可见外接框全部在 `[61, 58, 260, 217]` 内且底边 `y = 217`；`dragon_unarmed_manifest.json` 动作映射与 `XAppearance.form_meta("MiraDragon")` 一致。
   - 召剑特效 `content/mira/fx/sword_u2/` 10 张（`appear_0..2`、`hover_0..2`、`disappear_0..2`、`clear`）实测均为 `128×128` RGBA、`appear/hover/disappear` alpha 仅 `{0, 255}`、`clear.png` 全透明。
2. **开关关闭回退与人形影响**【核了规则＋实跑＋读代码】：
   - `XMira.DRAGON_ART = false` 时，`XDB.img_path` 跳过 `content/mira/img/sv_actors/sv/UserSV_MiraDragon/` 拦截直接走原版路径（与 `main` 一致）；`XMiraSwordFx.wants()` 与 `dragon_sprite()` 均返回 `false`，`on_skill` 不会创建 `MiraSwordFx` 节点（`layer_of(sp) == null`）。
   - 人形 `MiraHuman` / `Codex_Mira_SV_u2`（`XMira.ART`）及图鉴 `XActorBook`（`BOOK_MULTI[168]` / `Codex_Mira_SV_u2`）逻辑均不读 `XMira.DRAGON_ART`，不受影响。
3. **召剑层位置、独立性与技能名单**【核了规则＋实跑＋读代码】：
   - `XMiraSwordFx` 作为独立 `Node2D`（`z_index = 1`）挂在 `XBattlerSprite` 下（不挂在 `sp.sprite` 下、不裁进 `340×280` 龙图；`manifest.json` 顶缘相对龙画布 `y = -47`）。
   - `OFFSET = Vector2(-40, -200)`、`center_for(s) = OFFSET * body_scale`、`scale = Vector2(s, s)`、`_spr.centered = true`（`128×128` 中心 `[64,64]` 对齐层原点）；对照 `battler_sprite.gd:_place_body()` 与 `UserSV_MiraDragon` 档 `[340, 280, 61, 58, 260, 217]`，脚底 `y=217` 映射到 `XBattlerSprite` 原点 `y=0`（可见中心 `x=160.5` 与 `160` 仅差 `0.5px`，属正常取整）。
   - `XMiraSwordFx.SKILLS` 默认 `[]`（不召剑，名单待 Kyo 定，不算问题）；`RECOMMENDED` 仅作注释常量不参与判断；`battle_scene.gd` 仅在 `_play` 收尾调用 `vanish_all` 与 `_perform_action` 调用 `on_skill` 各 1 行，未动 `battle_logic`／数值／随机数。
4. **影响面（`XDB.img_path`）与测试实跑**【读代码＋实跑】：
   - `modes/xiyou/core/xdb.gd:213` 仅 1 个 `if XMira.DRAGON_ART and (folder + "/" + name).begins_with("sv_actors/sv/UserSV_MiraDragon/UserSV_MiraDragon"):`，其余所有角色／敌人／系统／行走图路径完全不变。
   - 本工作树前台单独实跑通过：
     - `xiyou_mira_dragon_art.tscn`：`30/30` 通过
     - `xiyou_actor_looks.tscn`：`35/35` 通过
     - `xiyou_mira_art.tscn`：`26/26` 通过
     - `语法检查.py`：935 个 `.gd` 0 个问题
     - `发行空壳.py check`：62 个脚本、534 个函数全过
5. **4 张截图核对**【仅程序核对像素区域，未视觉看图】：
   - `03_再刷重制_Godot/04_验证/本地结果/mira_dragon_art/` 下 4 张截图（`dragon_idle.png`、`dragon_attack7_frame2.png`、`dragon_spell10_frame2.png`、`dragon_sword_hover.png`）实测均为 `1280×720`：
     - 4 张图左右半区（原版 vs 新图）底边均为 `y = 587`，脚底对齐；
     - `dragon_sword_hover.png` 与 `dragon_idle.png` 右半区像素差分仅发生在头顶召剑区域（`4168` 像素，外接框 `(562, 162, 733, 230)`，中心 `(647.5, 196.0)` 与理论中心 `(647.5, 197.7)` 吻合）；
     - 21 张新图连通域检查：除主体外，仅 `10_0`/`10_1`/`10_2`/`7_1` 的原版同位置火焰火星像素与 `15_0` 紫色异常特效点，未见明显游离剑柄碎片。

### 发现问题（P1/P2/P3）

- **P1 / P2 / P3**：无。

### 未核到（留给总装／后续）

1. **4 张截图的人眼／视觉审视**：本会话无看图（图像输入）工具，未能肉眼确认龙身轮廓内是否有细微残留剑柄、动作帧衔接美感或头顶剑的视觉观感，请总装或 Kyo 打开 `03_再刷重制_Godot/04_验证/本地结果/mira_dragon_art/` 4 张图目视终验。
2. **全量／其余选测场景**：按本单「不跑 `并行测试.py`、超过 2 分钟不跑」要求，未跑全量 `检查.sh` 及 `xiyou_mira_battle`、`xiyou_actor_book`、`xiyou_actor_modules`、`xiyou_actor_sv_compare`、`xiyou_battle_log`、`xiyou_determinism` 等其余场景，留给总装合并时跑。
3. **`~/.codex` 原图 `cmp` 比对**：未读 `~/.codex` 源目录，未复测交付单所述的 `cmp` 逐字节对比。

