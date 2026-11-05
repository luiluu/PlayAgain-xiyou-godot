# 交付：cc/bajie-battlefx1

- 车道／工作者：C 规则·战斗画面／八戒（cc，Opus）
- 状态：可合并

## 盘点表（原版＝冻结 v0.28 `app.nw/js/plugins.js` 启用插件；重制＝本分支）

战斗画面相关的启用插件逐个对了重制里读它的地方（`rg` 插件名＋看代码），已做的写依据，没做的写大小和玩家看不看得到。

| 项 | 原版位置 | 重制现状 | 大小 | 玩家看得到 |
| --- | --- | --- | --- | --- |
| **进出战斗转场**：开战音效 Battle1、遇敌镜头拉近（60 帧）、第 30 帧换战斗 BGM 并淡出、战斗 24 帧淡入、打完 24 帧淡出、回地图暗一帧 | rpg_scenes `Scene_Map.launchBattle／updateEncounterEffect`、`Scene_Battle.start／stop`；MOG_BattleTransitions（默认 -1、闪烁 false＝用 MV 默认、不闪白）；YEP_CoreEngine「Show Events Transition」（不藏角色）；Codex_MapSceneRecovery（回地图第 2 帧清黑幕） | **本期做了**（原来整块没有：直接切画面、不放开战音效） | 中 | 每场战斗都看得到 |
| 状态 overlay（头顶 ZZZ 等） | rpg_sprites Sprite_StateOverlay＋YEP_X_VisualStateFX | 已做（ui11，O-187） | — | — |
| 状态循环动画 `<State Animation>`（1297 刻印环身盾） | YEP_X_VisualStateFX | 已做（`battle_scene._update_state_animations`） | — | — |
| 选敌名字旁状态图标与剩余回合、名字窗淡出 | Olivia_WeaknessDisplay＋YEP_BuffsStatesCore | 已做（ui12，`enemy_state_icon.gd`） | — | — |
| SSEP 节拍（StateIcon／Overlay／Weapon／motionSpeed／Balloon／startMove／动画倍率／日志等待／弹数时长） | SSEP_BattleSpeedUp_v2 | 已对完（ui12 盘点） | — | — |
| 伤害数字（弹出、缩放、位置） | LGP_BetterDamagePopup＋MOG_DmgPopupEffects | 已做（`damage_popup.gd`，`popup_anchor_oracle`） | — | — |
| 行动序列画面（移动、镜头、震屏、色调、浮空、跳跃、不透明度、动作） | YEP_BattleEngineCore＋ActSeqPack1／2／3 | 已做（`sequence_player.gd`、`battle_camera.gd`，`action_sequence_oracle` 逐帧） | — | — |
| 技能动画、播放速度 | rpg_sprites Sprite_Animation＋YEP_BattleAniSpeedOpt | 已做（`mv_animation.gd`，`mv_anim_oracle`） | — | — |
| 普攻武器动画、武器精灵 | YEP_WeaponAnimation、Sprite_Weapon | 已做（`attack_animation_oracle`） | — | — |
| 侧视敌人（动作、影子、呼吸） | YEP_X_AnimatedSVEnemies、Mx_SuperSV | 已做（`sv_enemy.gd`、`battler_sprite.gd`） | — | — |
| 倒下演出 | MOG_CollapseEffects | 已做（`collapse_fx.gd`） | — | — |
| 选择光标、选中闪白 | YEP_BattleSelectCursor、Sprite_Battler.updateSelectionEffect | 已做（`battler_sprite.gd` cursor、每 30 帧闪 15 帧） | — | — |
| 敌人血条、Boss 血条 | YEP_X_VisualHpGauge、MOG_BossHP | 已做（`battle_scene` gauges、`boss_hp_bar.gd`） | — | — |
| 行动顺序条、侧边状态、指令窗淡出 | Olivia_BattleSysOTB、Olivia_SideBattleUI | 已做（`otb_bar.gd`、`side_status.gd`） | — | — |
| 连击数、伤害记录、掉落弹出 | MOG_ComboCounter、Star_CombatDamageRecord、MOG_TrPopUpBattle | 已做（`combo_counter.gd`、`damage_record.gd`、`drop_popup.gd`） | — | — |
| 胜利结算画面 | Olivia_VictorySequenceUI | 已做（`victory_screen.gd`） | — | — |
| 战斗背景缩放 | YEP_ImprovedBattlebacks | 已做（`battle_scene._build_background`） | — | — |
| 精英 1.8 倍、按难度的敌名颜色 | EliteEnemy、EnemyNameColorByDifficulty | 已做 | — | — |
| Boss 状态面板 | Codex_BossStatusSummary | 已做（`boss_status_panel.gd`） | — | — |
| 渡鸦多帧表现 | Codex_MiraRavenMultiFrame | 归渡鸦车道（ravenfx／ravenfx2） | — | — |
| 屏障数值弹出 | YEP_AbsorptionBarrier | 不用做：唯一用法 10032 月之庇佑原版永不可用（barrier1 已核） | — | 否 |
| 璇／屠苏美术、品质染色图标逐像素（审查 38 P3-5） | Codex_XuanTusuArtPack／ExtraArt、ItemColor | **没做，留下一期**：`xiyou_xuan_tusu_art` 只核图号、绑定与动作，没有成对截图逐像素比；要在 ui_reference 战斗夹具摆出璇附身／屠苏持武，原版和 Godot 各截一张比平均差 | 小 | 是（只在带这两人时） |

盘点结论：除转场外没找到别的确定缺口；SSEP 清单、overlay 这两块 ui11／ui12 已对完。

## 一期：进出战斗转场

原版逐帧读数：`03_转换工具/ui_reference/battle_transition_ref.cjs`（无头 Chrome、静音，map_ref 一层地图夹具，内存新局，只写给出的输出文件）→ `tests/fixtures/battle_transition_oracle.json`。
- 遇敌演出 60 帧：镜头以玩家（screenX，screenY−24；地图 5 玩家 11,13 → 552,354）为中心缩放 q＝((p−1)·20·p＋5)·p＋1，先拉近到约 1.37（第 10 帧）、第 30 帧回到 1、最后到 6；地图层偏移 Math.round(−中心×(q−1))。第 30 帧开始 24 帧淡出（第 53 帧全黑）。窗口层（HUD）不缩放，盖在黑幕下。
- 战斗：第一帧黑幕 244.375，24 帧淡完，淡完之前战斗流程不往下走（入场移动照走）。
- 打完：24 帧淡出到 255；回到地图第一帧 244.375，第二帧被 Codex_MapSceneRecovery 清成 0。
- BGM：开战时停地图 BGM，第 30 帧放战斗 BGM（无头 Chrome 里开战时又重放一次，是缓冲没解码完、isCurrentBgm 为假；正式版不重放，所以重制在第 30 帧放起后战斗接着放）。

## 变更记录草稿

## 2026-11-05 【cc·八戒·未经审查】战斗画面零星项盘点；进出战斗转场（开战音效、遇敌拉近、淡入淡出）battlefx1（dev.待定）

- **盘点**（派单 AU 第 1 条）：战斗画面相关的启用插件约 30 个逐个对了重制（表在本分支交付单），除进出战斗转场外都已做或不用做；审查 38 P3-5（璇／屠苏美术逐像素）没做，留下一期。
- **进出战斗转场**（原来整块没有：直接切画面、不放开战音效）。照原版 `Scene_Map.launchBattle／updateEncounterEffect`、`Scene_Battle.start／stop`，MOG_BattleTransitions 默认 -1 与「遇敌闪烁 false」等于 MV 默认演出、不闪白，Codex_MapSceneRecovery 让回地图只暗一帧。新 `XBattleTransition`（常量、缩放公式、开关）、`XSceneFade`（Scene_Base 黑幕，由场景每帧 step）；`XMapScene.start_battle`：放系统音效 7 → 截战斗背景 → 60 帧遇敌演出（Camera2D 缩放＋偏移照 Spriteset_Base.updatePosition，演出中放开镜头边界、震屏叠在上面）→ 第 30 帧放战斗 BGM、交给战斗接着放 → 战斗 24 帧淡入、淡完才开始 → 打完 24 帧淡出（全灭去结束画面 48 帧）→ 回地图暗一帧。HUD 演出中照样显示、被黑幕盖住，黑幕挡鼠标。
- 原版逐帧读数 `tests/fixtures/battle_transition_oracle.json`（新 `ui_reference/battle_transition_ref.cjs`），专项 `xiyou_battle_transition` 20 项：公式 60 帧缩放与偏移、三段黑幕、实战逐帧（XBattleTransition.trace）、拉近时真实画面变换对上「shift＋q·s」、镜头复原、回退支。窗口模式 `-- --out=<目录>` 截第 10、40 帧，和原版同帧对过（雪人、路灯、木箱位置一致）。
- 无画面（headless）默认不走转场（地图快照本来就是空的；每场多 100 多帧会拖慢几十场战斗的楼层测试），专项打开 `IN_HEADLESS` 核。
- 没照做：原版地图上的图片（Spriteset 里的 pictures）和天气也跟着缩放，重制图片、天气在单独的画布层，演出中不缩放（遇敌时很少有图片）。
- 回退开关 `XBattleTransition.ENABLED = false`（直接切、不放 Battle1，同原来），O-待定。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 进出战斗转场（`battle/battle_transition.gd`、`map/map_scene.gd` `start_battle`／`_encounter_effect`、`battle/battle_scene.gd` 淡入、`ui/scene_fade.gd`） | 原版：开战放 Battle1、60 帧遇敌拉近、淡出淡入；重制原来直接切画面、没有开战音效 | 照原版补上（逐帧对原版读数） | 原版有的表现补齐（派单第八批 AU） | `XBattleTransition.ENABLED = false` | cc（八戒） | 待用户确认 |

## 交接板

- 下一步：battlefx 二期（可选）：审查 38 P3-5 璇／屠苏美术与品质染色图标成对截图逐像素（ui_reference 战斗夹具摆附身／持武，原版和 Godot 各截一张比平均差）。
- 用户试玩说明：进战斗时有开战音效，地图先拉近再淡黑，战斗画面淡入；打完淡黑再回地图。设置里没有开关，回退要改 `XBattleTransition.ENABLED`。
- 需要用户决定：无（O 号照惯例「待用户确认」）。

## 进度账

- 战斗规则与画面：画面零星项里最后一块确定缺口（进出战斗转场）补上，建议 +0.5～1。

## 可优化（流程／工具／效率）

- 已做：`ui_reference/battle_transition_ref.cjs` 用无头 Chrome 量地图↔战斗切换，不用内置浏览器窗格（窗格藏起来时 requestAnimationFrame 停摆，地图夹具没有 `__dhRef.pump` 推帧）。
- 建议：map_ref 夹具也加一个推帧函数（像 battle_ref 的 `__dhRef.pump`），窗格隐藏时也能量；归界面车道，约半小时。

## 待交叉核查

- 改了 `map_scene.gd`（`start_battle` 整段、`_update_shake` 改成整体设 offset）、`battle_scene.gd`（`_ready` 的 BGM 与淡入、`_main` 等淡入、`_physics_process`）。重点核：关掉开关和无画面时 `start_battle` 与原来逐行等价（只多了次序调整：`difficulty_notice.hide()` 挪到 `battle.setup` 之后）；`_update_shake` 原来只写 offset.x，现在写整个 offset（y 原来也恒为 0）。

## 验证

- 专项 `xiyou_battle_transition` 20/20（无画面；窗口模式 20/20，截图对过原版）。
- `语法检查.py` 通过；`工具回归.py` 全过；`回退开关覆盖.py` 新缺口 0。
- 选测（`选测.py main --list` 129 个场景，>40 走云端）：云端选测全过（提交 6c006ecc73，4 片，最长 9.1 分钟，run 42047475395）。上传时提示本树 `oracle/raven_visual.json` 落后主工作区一项（ravenfx 合并中未收尾），不在本次选测名单里。

## 本分支提交

- 6c2ed7b9 转场代码、原版参照工具与读数、专项
- 合并 main（cc/bailong-ravenfx 已到）
- 交付单（本提交）
