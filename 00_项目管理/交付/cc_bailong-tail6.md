# 交付：cc/bailong-tail6

- 车道／工作者：角色专属／界面／白龙（cc，Sonnet／medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·白龙·未经审查】角色模块头注释剩余画面零星项（dev.待定）

盘点 `modes/xiyou/core` 等各角色模块头注释里的「未移植／未做」，先对冻结源核是否其实已做，再按规模从小到大补。做了四项、订正了三处过时头注释，其余列在下面「剩余清单」。

- **甚尔说明框熟练度行**（`toji.gd` `help_rows`，`help_card.gd` 接入）：照 `installNativeTojiRuntime.js` 的 `Sprite_ItemHelp.setItem` 包装，技能页／战斗技能窗里甚尔看已学的主技能（10216～10219）时，卡尾加两行 16 号白字：「咒具熟练：Lv·本级进度 n/m」和「当前咒具；普通攻击使用此熟练度」（当前形态那把）或「切换至此咒具后，普通攻击使用此熟练度」。行文先并入说明行，再交 `characterHelpView` 分组（它早就认这两种前缀）。`XHelpCard.scene_actor` 沿用黑闪的接法（技能页、战斗技能窗已设）。
- **镜流 10194 说明卡星魂行**（`yomi_jingliu.gd` `help_rows`）：去掉卡里原有的「特效:星魂」行，卡尾按镜流当前等级列已解锁的星魂（20/25/30/35/40/45 级，18 号白字 `\c[1]`）；原版读全局 `$gameActors.actor(170)`，不看是谁在翻技能页，这里同。
- **小猫剑圣段间 WAIT 6**（`cat.gd` `cast`、`sequence_player.gd`）：原版每打完一段且还有下一段，在下一个 CAT STRIKE 前插 `WAIT 6`；重制一次打完所有段，现在在非末段的最后一条 hit 记录上记 `wait_after: 6`，播放器在该记录的日志方法之后排一个 `wait`（按战斗速度缩放，同 `WAIT` 命令）。逻辑结算不变。
- **订正头注释**：饿狼「applyCritical 0 伤不暴击」（`battle_logic` 伤害值恰为 0 时通用清暴击标记，参照 raven_reflect_probe garouzero）与「指令窗 [2,1,5,4]」（`actor_modules` MENU／BATTLE_SKILL_TYPES）早已有；镜流「追加段战斗日志显示」（supplemental 记录进 logs，`sequence_player` 同走 displayActionResults，与原版一致）也无缺口；`character_help.gd` 头注释的「镜流星魂行」删去。

## 交接板

- 下一步：见下面「剩余清单」，米拉战斗图换图与隐藏呼吸分类都需要先量原版再做，别直接照头注释做。
- 用户试玩说明：甚尔技能页的主技能说明卡多两行熟练度；镜流学了「命途：毁灭」后，该技能说明卡末尾列已解锁星魂；小猫剑圣连斩每段之间有 6 帧停顿（和原版一致）。
- 需要用户决定：无

## 进度账

- 角色与专属机制：不加分（零星画面项，按「修正不加分」）；甚尔头注释不再写「只剩说明框熟练度行」，镜流不再写「星魂说明行」。

## 验证

- `语法检查.py`：0 问题。
- 专项（本机 `CHECK_JOBS=2`）：`xiyou_toji`（新增 help.active／other／not_main／unlearned）、`xiyou_jingliu2`（新增 soul_help.rows／none／other_skill）、`xiyou_help_card`、`xiyou_cat`（`_chain` 每行新增 wait_after 断言）、`xiyou_battle_log`，全部通过。
- `工具回归.py` 通过。
- `选测.py main --list` 50 个 >40，走 `云端选测.py`（结果见本单末尾「云端选测」一行）。
- 没有窗口截图：改动是说明卡文字行和 6 帧等待，未开窗口量。

## 待交叉核查

- `help_card.gd` 的接入位置：原版甚尔／镜流的包装装在 DamageElement／CombatPower 等外层包装之前（更靠内），这里在 `XCharacterHelp.view` 之前追加；行序依赖 `characterHelpView` 的分组，没做与原版逐行截图对照。
- `sequence_player.gd` 新增 `wait` 方法与 `wait_after` 字段：只在 `cat.gd` 设置，别的技能不受影响。
- 没改 battle_logic／actor／battler／damage／xstate 等核心文件。

## 剩余清单（头注释里还写着的，未做）

| 角色 | 剩什么 | 原版位置 | 规模 | 说明 |
| --- | --- | --- | --- | --- |
| 米拉 | 黑龙形态战斗图换成 `sv_enemies/BlackDragon_Mira_Enemy`（缩 0.55、下移、藏武器） | `installNativeMiraRuntime.js` 457-477 | 小～中，**需先量原版** | 素材 `img/sv_enemies/BlackDragon_Mira_Enemy.png` 冻结源里有。但 `Codex_MiraRavenMultiFrame` 已把黑龙显示成 `UserSV_MiraDragon` 多帧，Mira 的包装在其外层再改 bitmap／缩放；两者叠加后到底显示哪张图，要开原版量一次（`xiyou_actor_looks` 现断言的是多帧）。没量就改会把现有断言改坏，所以只列不做 |
| 黄泉／镜流 | 隐藏呼吸技能分类（`Window_Command.addCommand` 对 symbol=skill、ext=3 一律不加） | `installNativeYomiJingliuRuntime.js` 707-710 | 小，**需先量原版** | 原版对所有角色的技能栏／战斗指令都生效，会影响渡鸦、宿傩的 `[2,1,5,3,4]`／`[2,1,5,3]`（现在显示 3）；需要探针量原版窗口里这几个角色到底有没有第 3 栏，再决定改不改 |
| 渡鸦 | 魔法反射支的累计伤害／行动结束追加（reflect 分支不记帧） | `installNativeRavenRuntime.js`；交付单 cc_bailong-visual2 已量得「反射回渡鸦自己的那一击只记一条打自己的 hit，待核追加伤害」 | 中（规则，归规则车道） | 动 battle_logic 反射路径，不是画面项 |
| 三法宝成长 | 屠苏／璇的五相／列星特效、传家宝品质整理 | `installThreeGrowthRelicRuntime.js` | 中（特效） | 未查素材 |
| 宿傩 | 看破闪避归零、`applyCriticalRate` 改写在 CodexDamage 下不走 | 头注释自述「西游无效／不走」 | 无需做 | 原版本身无效，头注释是说明不是缺口 |
| 黑闪 | 遗忘 10225／觉醒技时清空 | `installNativeBlackFlashRuntime.js` | 未查 | 规则项 |
| 谷雨 | isValid 包装 | — | 无需做 | 重制不看 isValid |
| 图鉴 | 168、173～177 多帧立绘 | `actor_book.gd` | 中（素材） | 屠苏／璇／谷雨等美术包已在 dev.307、309 接入，这条头注释可能过时，没逐一核 |
| 异化／狂妄 | 杰作无我锻造、revive 重开贡献 | `hubris.gd` | 中 | 非画面项 |

## 可优化（流程／工具／效率）

- 建议：模块头注释的「未移植」行常落后于实现（本轮订正了三处：饿狼、镜流两条、character_help），可以让审查线程每期顺手扫一遍头注释对照进度核定表，预计省下一次「先核是不是已经做了」的盘点（归审查线程）。

## 本分支提交

- 见 `git log main..cc/bailong-tail6`

## 云端选测

云端选测通过：提交 8886965475（ci/cc/bailong-tail6），基准 a95541f61d，50 个场景、4 片，最长一片 5.5 分钟；运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41948272155 。之后只改了本交付单。
