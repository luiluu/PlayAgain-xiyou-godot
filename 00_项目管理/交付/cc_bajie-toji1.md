# 交付：cc/bajie-toji1

- 车道／工作者：C 规则／八戒（Claude，八戒_92 开分支后交接）
- 状态：进行中
- 分支从 cc/bajie-blackflash 末端 3d530eb8 切（总装六交代），工作树 `.claude/worktrees/compassionate-gagarin-ec734e`。

## 交接（八戒_92 → 下一位八戒）

八戒_92 本会话已交宿傩第二期、黑闪期，上下文到 41%，按规矩不开大活，只切了分支、写了这一节。接手者从这里开工：

- 任务（总装六原话要点）：甚尔 171 移植期一。参照冻结 v0.28 `js/codex/runtime/installNativeTojiRuntime.js`（33 KB，prettier 后约 1080 行）。第一步把原版机制清单与重制现状对成表写进下面「机制对照」，按收益排期。
- 期一（先交、可合并）：招募／开机同步／能力值与基础伤害公式，加上和 XBlackFlash 的接线（`core/black_flash.gd` 已登记 171 配置：触发 10216～10219、觉醒技 10226、状态 2635；觉醒时 10216 额外一击 `_tojiHitCount`＋1 留给甚尔模块做；甚尔要学到 10225 才启用，原版由黑闪 unlock 在 setup／levelUp 学）。照 `garou.gd` 第一期写法，新文件 `core/toji.gd`，文件头写已移植／未移植；接入点参照 `sukuna.gd` 第一期（`actor_modules.gd`、`formula_execution.gd` 模块公式、`actor_damage_hooks.gd`、`mv_script.gd` 招募）。`actor.gd` 已有甚尔普攻形态（TOJI_MAIN／TOJI_SHAPES）。
- 期二起：战斗内专属机制，做不完写下期清单；画面侧只出逻辑记录，写进「下期」交画面车道。
- 参照探针对原版（mv_oracle 只写 `.sandbox/`），专项含反向验证；O 号用占位进「## 优化登记草稿」表，没有就写「优化登记草稿：无」。改了 battle_logic／actor／battler／damage／xstate 要点名。
- 不碰：`garou.gd`（白龙_7 在做饿狼第二期）、`raven.gd`、`mira.gd`。
- 验证：专项＋选测本机跑（GitHub Actions 11-01 前用不了），本机同时测试最多 2 条车道，跑前看占槽（主工作区 `检查.sh` 在跑时会排很久）。
- 停手：要等别的未移植系统才能做的，跳过写进交付单。
- 经验（八戒_92）：探针写法见 `mv_oracle/sukuna_battle_probe.cjs`——新局里 `$gameParty.addActor` 对非初始角色无效，直接写 `_actors`／`_battleMembers`；超强角色出战要开开关 2494；`BattleManager.endTurn` 前把 `_enteredEndPhase` 置 false。新 class_name 文件要先 `godot --headless --path 01_Godot工程 --import` 才认得。Parse Error 时 `并行测试.py` 会空等 600 秒，先直接跑单个场景。55 级专属角色伤害恒为原版 0.96079 倍是已知的五乘区差（Kyo 10-27 定不移植），专项按比值比。
- 回报发总装六（local_d96f72ab-eeec-4265-9505-798906c3eb37），只在可合并、卡住、要新车道时发。

## 机制对照

原版冻结 v0.28 `js/codex/runtime/installNativeTojiRuntime.js`（667 行，下表行号照原文件）。「期一」是本分支做的，「已有」是别的模块早做好的，「期二」「期三」是排期（按收益：先让甚尔能正常打一场——形态与多段，再补被动，最后 AI 与画面）。

| # | 机制（原版行号） | 重制现状 | 排期 |
| --- | --- | --- | --- |
| 1 | 数据完整性检查 isDatabaseLoaded（631-641） | 不移植：重制数据库由转换器保证 | — |
| 2 | 成长 outputGrowth／smoothTail／progressionRate（23-38） | `XToji.output_growth`，对上参照 7 档等级 | 期一 |
| 3 | 普攻＝当前形态主技能 attackSkillId（64-68） | 已有：`XActor.attack_skill_id`（TOJI_MAIN／TOJI_SHAPES） | 已有 |
| 4 | 普攻指令名 addAttackCommand（69-77） | 已有：`XActor` 普攻名直接用技能名 | 已有 |
| 5 | 暴君被动缓存：终伤、暴伤各＋0.40×等级（81-93） | `XToji.passive_cache` | 期一 |
| 6 | 能力值 param：天与咒缚（MP、魔攻归 0 并入生命、物攻）、暴君（生命 ×(1＋0.1lv)、物攻／速度 ×(1＋0.05lv)）、霸王血铠／杰作、大力 ×1.2（95-120） | `XToji.param`；新加 `XActor.param_native` 读包装之内的原 MP／魔攻 | 期一 |
| 7 | 暴君暴击＋0.10×等级 xparam（121-125） | `XToji.xparam` | 期一 |
| 8 | 天与咒缚 setMp／gainMp 恒 0（126-133） | 最大 MP 为 0，资源刷新已夹到 0；repair 置 0 | 期一 |
| 9 | 暴君免负面状态与弱化 addState／addDebuff、clearDebuffs、学暴君时清（135-167） | 未移植（负面判定要 CodexDifficulty.isSystemState；与异化 O-106 的弱化包装顺序相关） | 期二 |
| 10 | 公式 T.damage（173-188） | `XToji.formula`；追加次数、第几段、反弹基数第一期按初值 | 期一（战斗字段期二） |
| 11 | 智能 AI 档案 aiProfile（189-209） | 未移植 | 期三（智能 AI 车道） |
| 12 | 敌人物理减伤穿透 sparam(6)（210-214） | 旧伤害链用；CodexDamage 下由钩子的 physicalIncomingPierce 代替 | 期一（钩子） |
| 13 | 天与咒缚 影速命中＋min(0.3, (速度比−1)×0.15)（215-223） | 未移植 | 期二 |
| 14 | 闪避 itemEva：五感时主技能／武器库必中；被打时天与咒缚加闪避（224-236） | 未移植 | 期二 |
| 15 | 五感 暴击闪避 ×0.34（237-257） | 未移植 | 期二 |
| 16 | applyCritical 包装（258-262） | 空包装，无需移植 | — |
| 17 | 反弹技能换属性 item()（263-274） | 未移植 | 期二 |
| 18 | makeDamageValue 包装（275-303） | 死代码（installDamageElementRuntime 后装、整个换掉 makeDamageValue），不移植；同宿傩 | — |
| 19 | 术师杀手：受魔法伤害 ×0.2、反弹 26.4%（293-301、319-330、653-655） | 未移植（钩子受击分支与反弹行动） | 期二 |
| 20 | 万里锁溅射 33%（觉醒 50%）、借用 16%（305-318、351-354） | 未移植 | 期二 |
| 21 | apply 包装：段数计数、天逆鉾封印 2634 附加与次数（331-357） | 未移植 | 期二 |
| 22 | 咒具切换豁免技能类别封印（359-366） | 未移植（异化 O-113 已提到） | 期二 |
| 23 | 技能条件：主技能只能用当前形态、切换技能条件（367-377） | 未移植 | 期二 |
| 24 | 技能列表过滤 Window_SkillList.includes（378-386） | 逻辑未移植；画面 | 期二（逻辑）／画面 |
| 25 | 咒具熟练度说明框 masteryInfo／Sprite_ItemHelp（387-405） | 未移植（画面） | 画面车道 |
| 26 | 封印次数随 eraseState／clearStates 清（406-412） | 未移植 | 期二 |
| 27 | 封印吞技能 applyGlobal、processActionSequenceCheck（413-430） | 未移植 | 期二 |
| 28 | startAction：切换、武器库追击 50%、多段次数、单目标（431-482） | 未移植 | 期二（最先） |
| 29 | actionActionEffect 多段（483-497）；黑闪觉醒游云额外一击（BlackFlash 116-117） | 未移植 | 期二（最先） |
| 30 | endAction 切形态（498-505） | 未移植 | 期二（最先） |
| 31 | 开战第一形态、结束清形态、复活回第一形态（506-530） | 未移植 | 期二（最先） |
| 32 | repair：setup、读档、进阶后（532-571） | `XToji.repair`：setup（XActorModules）、进阶（XAdvance.advance 后）；读档不跑（重制存档存的就是同步后的技能） | 期一 |
| 33 | 进阶石 rollAdvanceStone（573-580） | 已有：`XDungeon.roll_advance_stone` | 已有 |
| 34 | 招募 T.recruit（581-611） | `XToji.recruit`，`mv_script` 号角脚本接上（两条提示） | 期一 |
| 35 | Map132 商店补号角 2936（612-630） | 已有：`XItemMarks` LOBBY_LINK_HORNS | 已有 |
| 36 | 伤害钩子 toji（642-657） | `XToji.damage_ops`（自己的技能一支）；术师杀手受击分支见 19 | 期一 |
| 37 | 黑闪配置 171（BlackFlash 10-11）与 unlock 学 10225／10226（BlackFlash 35-37） | 已有配置；10225／10226 在职业 1 级习得表里，setup 已学 | 已有 |

## 变更记录草稿

## 2026-10-31 【cc·八戒_93·未经审查】伏黑甚尔 171 第一期：招募、开机同步、能力值与基础伤害（dev.待定）

1. **甚尔 XToji**（冻结 v0.28 `installNativeTojiRuntime.js`）：新文件 `modes/xiyou/core/toji.gd`。开机同步 repair（setup、进阶后）；能力值包装（天与咒缚 MP／魔攻并入生命／物攻、暴君成长、霸王血铠与杰作、大力）、暴君暴击与终伤／暴伤；成长 outputGrowth；公式 CodexToji.damage（10216～10224）；伤害钩子 toji（物理／魔法、五感防御率 ×0.67、释魂刀穿透、成长、藏兵咒灵 ×1.11、暴君 ×3）；号角招募（生成或取背包里的藏兵咒灵装上、两条提示）。37 项机制对照与排期见本交付单「机制对照」。
2. **接线**：`XActorModules`（setup、param、xparam、被动缓存，IDS 加 171）、`XActorDamageHooks`、`XFormulaExecution` 模块公式 toji、`XAdvance.advance` 后 `XToji.after_advance`、`mv_script` 号角招募 CodexToji；`XActor` 加 `param_native`（包装之内的原值）。转换器 `formula_program.py` 登记 CodexToji.damage 为模块公式；切片 `actors` 加 171（slice_probe、actor_passive_probe 等自动覆盖甚尔）。
3. **参照与专项**：新探针 `mv_oracle/toji_probe.cjs`（31 例：等级 1～99 × 进阶 0／1 × 生命满／半的能力、暴击、被动缓存、技能表、成长与 8 个技能的结算，戴法宝一档，招募三例），新专项 `xiyou_toji`；`xiyou_actor_p0` 招募表加 9006→171。
   - 反向验证：拿掉大力（物攻与伤害对不上）、拿掉暴君（暴击、缓存、伤害对不上）、换成 1 号角色（钩子空、公式 0、能力不改），写在专项里常驻。

## 下期

- **期二（战斗内，按收益排）**：①咒具形态与切换（#28～31：开战第一形态、切换技能 endAction 换形态、复活回第一形态、主技能只能用当前形态 #23、战斗中技能列表 #24 逻辑、切换豁免类别封印 #22）；②多段与追加次数（startAction 记 `_tojiExtra`、游云 5＋追加段、万里锁／天逆鉾 1＋追加段第 2 段起 ×0.8、单目标、actionActionEffect 逐段；`XToji.formula` 里的 extra／index 换成战斗字段）与黑闪觉醒游云额外一击（XBlackFlash 的 extraHitSkill，`black_flash.gd` 文件头「未移植」那条）；③暴君免负面状态与弱化、学暴君清负面（#9，先看异化 O-106 的弱化包装顺序）；④五感必中与暴击闪避 ×0.34、天与咒缚影速命中／闪避（#13～15）；⑤武器库追击 50%（随机咒具、借用特效、天逆鉾 50% 封印）与万里锁溅射（#20、#28）；⑥天逆鉾封印 2634（附加、次数、吞技能、清次数，#21、#26、#27）；⑦术师杀手受魔法伤害 ×0.2 与反弹（#17、#19：钩子受击分支、反弹行动换属性）。
- **期三**：智能 AI 档案 aiProfile（#11，交智能 AI 车道或随期二末尾）。
- **画面车道（只出逻辑记录，期二做完逻辑再交）**：咒具熟练度说明框两行（#25：「咒具熟练：Lv…；本级进度…」「当前咒具…」）；技能页里主技能显示规则（#24：技能页战技类别列主技能，战斗中只列切换技能）；招募两条右上角提示已走 `interp.host.toast`；切片现在导出了甚尔的行走图／脸图／SV 图（同步 changedInputs），`ui/actor_book.gd` 文件头写 169～171 没导出 SV 图，171 这条可以去掉、状态页可画立绘。
- **读档 repair**：原版读档会再跑一次 repair（rank≥1 后升到 30 级学到的 10208 在下次读档被忘掉）；重制不跑，技能表上会同时有 10208 与 10210，数值不受影响（杰作优先）。要不要补，等期二一起看。

## 优化登记草稿

优化登记草稿：无

## 交接板

- 下一步：八戒甚尔期二（见本交付单「下期」）。
- 用户试玩说明：吹伏黑甚尔号角（公共事件 9006）能招到甚尔并自动装上藏兵咒灵；甚尔的生命、物攻、速度、暴击和普攻／咒具伤害与原版一致。战斗里的咒具切换、多段、封印、反弹等还没做，进战斗只按第一形态出手、每次一段。
- 需要用户决定：无

## 进度账

- 专属角色模块：甚尔 171 0% → 约 30%（第一期：招募、同步、能力值、公式与钩子；战斗内机制在期二）

## 可优化（流程／工具／效率）

- 无

## 验证

- 新专项 `xiyou_toji`：68/68（31 例参照逐例＋3 条常驻反向验证）。
- 反向验证（临时改代码，已还原）：霸王血铠已损生命系数 0.12→0.13、藏兵咒灵 1.11→1.12，5 项失败（4 档半血＋戴法宝档）。
- 同步：`同步正式西游.py --accept-additions` 通过，测量只增（slice_d1～d6 加 171 角色行与伤害行、actor_passive、wtype、help_cards、新增 toji.json），来源核对 0 问题。
- 选测：`检查.sh --oracle --affected dd374cdf`（待写结果）

## 待交叉核查

- 甲档（战斗核心）：`modes/xiyou/core/actor.gd`（加 `param_native`）——原沙僧核心文件，请重点核；`toji.gd` 能力值与伤害钩子、`actor_modules.gd`／`actor_damage_hooks.gd`／`formula_execution.gd`／`advance.gd` 挂点。
- 乙档：`mv_script.gd` 号角招募、切片加 171、转换器模块公式。
- 丙档：`toji_probe.cjs`、`xiyou_toji`、`xiyou_actor_p0` 招募表。

## 本分支提交

（待写）
