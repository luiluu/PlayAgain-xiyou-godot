# 交付：cc/bailong-ravenfx

- 车道／工作者：B 界面／ravenfx（cc；白龙盘点后上下文到线，接手做一期）
- 状态：可合并

## 盘点表（原版 = 冻结正式源 app.nw/js；来自白龙接续单，接手后按实测更新）

| # | 功能 | 原版位置 | 重制 | 本期 |
|---|---|---|---|---|
| 1 | R.Fx 通用特效 ring／slash／harvest／echo | NativeRaven:1097-1113 | 已做（raven_fx.gd） | — |
| 2 | 六个技能的羽毛矢量施放特效 | RavenSkillEffects:5-82 | 已做 | — |
| 3 | 施放期间算动画没放完；同技能不叠 | RavenSkillEffects:84-115 | 已做（屏蔽支未逐行核） | 二期可抽测 |
| 4 | 神话静态大图 Raven_Mythic_Monster（0.60，(−20,155)，死亡 (−20,180) α0.35，藏武器） | RavenMonsterVisual | 没做 | jsdom 实测：运行时包装在最外层，_mainSprite 确实换成这张图、0.6、(−20,155)；但 Mx_SuperSV 多帧会不会在真实渲染里盖掉（米拉同类大图实测被盖）jsdom 量不出，要无头 Chrome，**留二期** |
| 5 | 神话多帧 SV | 多帧插件 | 已做 | — |
| 6 | 普通形态 SV 归一 | 多帧插件 | 已做 | — |
| 7 | 受击改 evade、濒死改 wait | NativeRaven:570-580 | **本期做**：探针实测普通、神话都换（运行时这层包在多帧插件外面，插件给神话留的原生受击／濒死帧用不上） | 开关 `XBattlerSprite.RAVEN_MOTION_REMAP` |
| 8 | 地图始终 $Raven_Normal | NativeRaven:581-586 | 数据库本身成立 | — |
| 9 | 地图步行帧 ×1.35（队长、跟随者） | NativeRaven:588-598 | **本期做**：探针实测速度 1～6（如速度 4：15→20） | 开关 `MVCharacter.RAVEN_WALK_SLOW` |
| 10 | 167／173 隐藏技能类型左右箭头（Sprite_WindowArrow） | NativeRaven:628-636 | **不涉及**：箭头属于 My_SkillTypeSwap 的「技能栏左右翻页」，重制没有这个翻页（技能类型逐栏列出），也就没有箭头可藏 | — |
| 11 | 法宝图标 | NativeRaven:57-81 | 已做 | — |
| 12 | 神话回合清零、战后复原 | NativeRaven:1088-1094 | 已做 | — |
| 13 | 头像、昵称 | Actors.json 167 | 已做 | — |
| 米拉 | 名字 | installNativeMiraRuntime:27-29 | 与原版一致（name() 返回的就是数据库名字） | 注释改正 |
| 米拉 | 图鉴立绘（UserSV_MiraHuman1_0 整张静态、档 UserSV_MiraHuman） | Codex_MiraRavenMultiFrame:282-314 | 没做 | **本期不做**：rules 线程 portrait1 正在改同一个 actor_book.gd（167 以后按档缩放、173～177 逐帧图），已建议它把 168 一并做（同一段原版代码，一行表项）；不做的话等它合进 main 再补 |

## 变更记录草稿

## 2026-11-05 【cc·ravenfx·未经审查】渡鸦表现余项一期：地图步行帧放慢、受击／濒死动作替换（dev.待定）

- **地图步行帧**：原版 installNativeRavenRuntime 包了 Game_CharacterBase.animationWait，玩家（取队长）或跟随者是渡鸦时步行帧停留 ×1.35 四舍五入（披风三帧变化大），不改移动速度、不影响别人和事件。重制原来没有。现在 `MVCharacter.animation_wait`（玩家、跟随者各自给出对应角色）照做。
- **受击／濒死动作**：原版把渡鸦的受击改播闪避、濒死改播待机（战斗缩放后看着一直趴着），只换显示。新探针实测普通和神话形态都换。重制原来照通用动作播。现在 `XBattlerSprite.raven_motion` 照做，待机刷新也按替换后的动作比，免得每次刷新都把帧重设回 0。
- 新探针 `mv_oracle/raven_visual_probe.cjs`（7 例，进 PROBES），专项 `xiyou_raven_visual` 51 项（含两个开关关时照通用值）。
- 注释：`raven.gd` 未移植清单去掉已移植的 RavenSkillEffects，`mira.gd` 写明名字与原版一致。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 渡鸦地图步行帧（`map/mv_character.gd` `animation_wait`，`mv_player.gd`／`mv_follower.gd` `walking_actor`） | 原版：渡鸦当队长或跟随者时步行帧停留 ×1.35；重制移植前和别人一样 | 照原版移植 | 原版有的表现补齐（派单第七批 AQ） | `MVCharacter.RAVEN_WALK_SLOW = false` | cc（ravenfx） | 待用户确认 |
| O-待定 | 渡鸦受击濒死动作（`battle/battler_sprite.gd` `raven_motion`） | 原版：渡鸦受击播闪避、濒死播待机；重制移植前照通用动作 | 照原版移植（普通、神话都换，探针实测） | 同上 | `XBattlerSprite.RAVEN_MOTION_REMAP = false` | cc（ravenfx） | 待用户确认 |

## 交接板

- 下一步：ravenfx 二期——#4 神话静态大图用无头 Chrome 实测会不会被多帧盖掉（米拉同类图被盖）；#3 屏蔽支抽测；米拉图鉴立绘看 portrait1 有没有一并做。
- 用户试玩说明：渡鸦在地图上走路的步伐稍慢一点（只是动画，移动速度不变）；战斗里渡鸦挨打时做闪避动作、残血时保持站立待机，不再趴着。
- 需要用户决定：两条 O-待定（默认照原版开着）。

## 进度账

- 角色（渡鸦）：表现余项 13 项里本期做 2 项、1 项确认不涉及，剩 #4 大图待实测。

## 可优化（流程／工具／效率）

- 建议：mv_oracle 加一个无头 Chrome 量战斗精灵最终画面的公用小工具（白龙量米拉黑龙时手写过一次），这类「插件之间谁盖谁」的表现项就不用每次手搭；归哪吒（工具）。

## 待交叉核查

- 乙档：`mv_character.gd`、`mv_player.gd`、`mv_follower.gd`、`battler_sprite.gd`（set_motion／refresh_idle）、`raven.gd`／`mira.gd` 注释、探针 `raven_visual_probe.cjs`、`tests/xiyou_raven_visual.gd`。

## 验证

- 专项：`xiyou_raven_visual` 51/51。
- 选测（本机，没走云端）：`选测.py main --list` 列 158 个（改了 mv_character 牵出全部楼层专项、改 raven.gd 注释牵出 xiyou_rules*），挑 37 个跑，全过：xiyou_actor_looks、xiyou_actor_modules、xiyou_airship_view、xiyou_appearance、xiyou_battle_events、xiyou_battle_log、xiyou_cat、xiyou_collapse_fx、xiyou_costume_battle、xiyou_costumes、xiyou_flow、xiyou_guyu_ui、xiyou_jingliu2、xiyou_map、xiyou_map132_shop、xiyou_map186、xiyou_map_balloon、xiyou_map_hotkeys、xiyou_mira_abyss、xiyou_mira_battle、xiyou_mv_animation、xiyou_options_basic、xiyou_raven_artifact、xiyou_raven_battle、xiyou_raven_reflect、xiyou_raven_soul、xiyou_raven_visual、xiyou_review_fixes、xiyou_rules、xiyou_sequence_visual、xiyou_state_overlay、xiyou_sve_visual、xiyou_svpngfd、xiyou_vsfx、xiyou_xuan_tusu_art、xiyou_floor_run、xiyou_determinism。其余楼层／规则场景只因 mv_character、raven.gd 注释被牵出：非渡鸦的步行帧值不变，raven.gd 只改了注释，留给合并选测。
- `同步正式西游.py --accept-additions`（新增用例已接受，留了指纹）；`语法检查.py`、`工具回归.py` 全过。验收后又合了一次 main（mac1、equip1），没碰本分支文件，没重跑。

## 本分支提交

- cf17bee3 白龙接续单（盘点）
- 17b9b0c1 步行帧 ×1.35、受击濒死替换，探针 raven_visual＋专项
- 5c58829f 交付单（接续单并入后删除）
- 最后一笔：合 main、交付单可合并
