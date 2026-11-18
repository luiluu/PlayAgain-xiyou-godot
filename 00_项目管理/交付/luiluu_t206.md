# 交付：luiluu/t206

- 车道／工作者：T206 米拉黑龙待机像异常帧（cc，Opus＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-18 【cc·T206·未经审查】战斗中轮到输入／行动的角色照原版播 walk，不再趴濒死帧（dev.待定）

- 原因（Kyo 11-18「黑龙的待机动作怎么像是吃异常的帧」）：T197 样张里那条黑龙播的是 `dying`（UserSV_MiraDragon14_0），不是异常（15_0）也不是待机。探针读数：生命 17499／上限 142497＝12%，低于 1/4，`XBattlerSprite._idle_motion` 判了濒死。上限偏高有两个原因：解放·黑龙 2592 的特性让生命上限 ×2（真实游戏里满血解放后也只剩 50%）；样张夹具（`xiyou_big_form_sizes`／`xiyou_battle_actor_size._battle`）先回满血、后设进阶 3 和 2592，所以生命停在进阶前的数。manifest 映射（wait＝1_0、walk＝0_0～0_3）、外观键 `|form:MiraDragon`、2592 身上的 motion（0）都没问题；美术 1_0、0_x 是抬头站姿，14_0 本来就是濒死姿势，不是美术的问题。
- 重制和原版不一致的地方：YEP_BattleEngineCore／YEP_X_VisualStateFX 的 `Sprite_Actor.refreshMotion` 第一条是「输入中或行动中 → idleMotion（walk）」，排在濒死之前；OTB 换人时 `BattleManager.changeActor` 会给轮到的人设 `inputting`。重制漏了这一条，所以生命低于 1/4 的角色轮到输入时还趴着。
- 改动：`XBattlerSprite._idle_motion` 加上这一条（当前的人＝`XBattleScene._active`，在等指令和角色行动演出期间都是这个人；防御指令不算 acting，照旧判防御）。轮到、轮完时由 `motion_tick` 重判一次。所有角色都按这条规则走，跟原版一致。不轮到时生命低于 1/4 照原版播濒死。
- R1 返修（小A 核）：阵亡优先，照原版 `requestMotionRefresh` 的阵亡守卫（YEP_BattleEngineCore:4144），行动中被反击、反射、自伤打死的人锁在 dead，演出读数 `view.dead` 也照这条算；「不算 acting」改用 `XBattlerSprite.not_acting` 判断：`XBattleScene` 设 `_active` 前，若这次是防御指令就置真，`XSequencePlayer._perform_finish`（PERFORM FINISH 之后、seq_end 之前）也置真，不再读 `battler.guarding`（以前同回合先防御、后追加行动会误判）；`_active` 换人或清空时自动清掉。为此 `battle_scene.gd` 改了 2 行、`sequence_player.gd` 改了 2 行，不在独占文件里。
- 回退：`XBattlerSprite.INPUT_WALK = false`。
- 测试：新增 `tests/xiyou_mira_dragon_idle.tscn`（R1 后 24 项，含行动中反死、演出读数阵亡、先防御后追加行动、PERFORM FINISH 之后、标记自动清；旧代码跑这些会挂 4 项，窗口模式加 `-- --out=<目录>` 存修前／修后截图）；首轮按选测本机跑 42 个场景全过；R1 后云端选测 170 个场景全过（7eeca1c1d）。
- 截图：[luiluu_t206附图](luiluu_t206附图/)（修前_黑龙生命12%_输入中、修后_黑龙生命12%_输入中、修后_黑龙满血_输入中，1280×720 原尺寸）。
- 玩家可见：生命不到 1/4 的角色轮到下指令时，站着等指令，不再趴着（黑龙最明显）。

## 交接板

- 下一步：T197／T194 样张夹具（`tests/xiyou_big_form_sizes.gd`、`xiyou_battle_actor_size._battle` 的 `_big_forms`）设了进阶 3 和 2592 之后没回满血，米拉只剩 12% 生命，不轮到她时照规则会趴濒死。以后再出样张要在 prep 末尾 `recover_all`（再设一次 hp＝mhp），这件事不在本车道的独占文件里。
- 用户试玩说明：生命低于 1/4 时轮到某人输入，他会站起来；轮完之后照原版趴濒死。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：重制 `_idle_motion` 的判定顺序和原版还有两处不同：原版防御排在濒死之前，重制排在之后；原版 VisualStateFX 有 `stateMotion >= 4` 自定义状态动作，重制没有。本单不改，归战斗画面车道，改之前先拿参照核一下。

## 本分支提交

- f9a83c3c9 WIP：T206 输入中播 walk、专项、截图
- 6de79b7f2 补 .uid 与交付单
- 7eeca1c1d R1 返修：阵亡优先、not_acting、专项补 7 项
