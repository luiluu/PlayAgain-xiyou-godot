# 交付：claude/wukong-airship2

- 状态：可合并
- 车道／工作者：A 内容·地图／悟空_69（Claude）
- 本期：天之上飞艇方案甲二（上下飞艇、飞行、降落、飞行中屏蔽事件与遇敌、BGM、跟随）；O-117 飞行中锁传送与挂机
- 基线：从甲一交付末 187e271f 切出，交付前已合 main（654be040，只多了甲一合并与交接板，没碰本车道文件）。

## 变更记录草稿

## 2026-10-29 【Claude·悟空·未经Codex检验】天之上飞艇甲二：能上下飞艇、在岛间飞（dev.待定）

- 起因：用户 10-29 定方案甲（照原版飞艇分 3 期）。甲一已让飞艇位置随档；本期让玩家真的能上艇、飞、降落，天之上 15 张图与神魔战场大半事件从此走得到。
- 照原版 `rpg_οbjects.js` Game_Player／Game_Vehicle 逐条移植（`map_scene.gd` 新增「飞艇」一节）：
  - 上艇（getOnVehicle）：站在本图飞艇所在格按确认；收拢跟随，飞艇升到 48 之前不能动（canMove 要 isHighest）；之后朝向取飞艇的、速度 6、透明、穿透，存下地图 BGM（saveWalkingBgm）、放飞艇 BGM（140 改过的或 System 的 Theme_Amara）。确认键先判上下飞艇，再判事件（triggerButtonAction 的顺序），所以站在飞艇上按确认是上艇、不是调查面前的事件。
  - 飞行：通行只看图内（穿透）；不触发确认、接触事件（canStartLocalEvents），自动执行与并行照常；不计队伍步数（increaseSteps 只在 isNormal）、不减遇敌步数（canEncounter 加不乘飞艇）；玩家穿透时不挡事件（isCollided）。
  - 降落（getOffVehicle／isLandOk）：图块 0x0800 不挡、四向不全挡（`MVTilemap.is_airship_land_ok`，与 `checkPassage` 共用新拆出的 `check_passage`）且该格没有事件（含暂时消除的、切片没放的按原位置算）；朝下、跟随叠到脚下、飞艇熄火朝向 4、放回地图 BGM、速度 4、取消穿透、重算遇敌步数；降到 0 才变回走路、取消透明。
  - 换图：飞行中被传送时飞艇跟到新图（Game_Vehicle.refresh），自动播放只记下新图 BGM（saveWalkingBgm2）不换曲；`XState.walking_bgm` 随档（新字段，旧档缺省 null）。
  - 读档在空中：照飞艇的驾驶与高度恢复飞行状态；存档时正在上下的按高度接着上下。
  - 画面：飞艇用 System 的默认图（`characters/Vehicle` 第 3 格，切片 `extraImages` 新增，`extraAudio` 加 `bgm/Theme_Amara`），停着时在角色下方，驾驶中在角色上方跟着玩家；升空高度偏移、影子、改造包换图显示留给甲三。
- 可回退优化 O-117（用户 10-29 定）：乘飞艇时（含升降中）地图传送按钮不可用、不能开始挂机（原版两者都不看载具，飞艇会被带进楼层图越墙降落）。`XMapScene.SAFE_AIRSHIP_MENU = false` 回原版，已登记优化登记。
- 验证：新专项 `xiyou_airship_fly`（242 项）：69／186 全图每格降落判定与盘点脚本逐格相同；69 (65,56) 上艇，按交付单 1.2 表 17 块、1.3 表 8 块逐块飞到可降落格降落，传送门进目标图再用目标图出口回来、对话事件按「离开」跑一次、Map075（不在切片）只验走得到，再走回飞艇上艇；有事件的格、0x0800 格按确认不下；飞行中站到事件上不触发、不计步、不遇敌；传送按钮与挂机锁住；飞行中换图带着飞艇；空中存读档。原 `xiyou_airship_state` 全过。

## 交接板

- 下一步：「天之上岛间移动」改为：甲二已交（能飞），待派甲三（飞艇高度偏移与影子、升空动画、改造包 14 张图进切片并显示、截图对照原版）。
- 用户试玩说明：天之上恰兰吉尔那块（用恰兰吉尔物品进去，从恰兰吉尔出口出来）右下 (65,56) 停着飞艇：站上去按确认起飞，方向键飞，到岛上空地按确认降落。楼层回大厅后飞艇停在天之上 (30,25)；神魔战场入口旁 (50,49) 也有一艘（同一艘，跟着 202 挪）。飞行中地图传送按钮变灰、G 键挂机不响应（O-117）。飞艇现在贴地画、没有升空动画（甲三）。
- 需要用户决定：无（O-117 已按用户 10-29 拍板做成可回退）。

## 进度账

- 天之上／神魔战场岛间移动：甲一 → 甲二（可玩），剩甲三表现。

## 待交叉核查

- 本期改了原沙僧独占的 `modes/xiyou/core/xstate.gd`（只加 `walking_bgm` 字段与存读），请重点核。
- 重点：`map_scene.gd` 的走路分支应一行不变（只在 `vehicle_type != "walk"` 时走新分支）；`_on_action` 先判上下飞艇的顺序；`is_blocked` 加了「玩家穿透不挡事件」（走路时玩家不穿透，不影响）；`mv_tilemap.is_passable` 拆出 `check_passage` 后行为不变。

## 可优化（流程／工具／效率）

- 已做：`载具可达.py` 加第 4 个输出（JSON：69／186 每个可降落格的块号、事件所在块、走得到的块），作专项 `xiyou_airship_fly` 的静态对照表 `tests/fixtures/airship_land.json`；以后改降落规则或切片收新岛，重跑脚本即可更新。回退：删掉脚本末段与该文件。
- 建议（工具 bug，归 A 车道或哪吒，约 1 行）：新工作树第一次跑 `同步正式西游.py` 时，若分片探针（slice_probe）走「增量、只跑 0 个单元」分支，`oracle_shard_merge.cjs:106` 直接写 `mv_oracle/.sandbox/slice/slice_dN.json`，目录不存在就 ENOENT，六段全失败、整轮同步白跑约 40 分钟。本期手动 `mkdir -p 03_转换工具/mv_oracle/.sandbox/slice` 后重跑通过。修法：写之前 `fs.mkdirSync(path.dirname(f.out), {recursive: true})`。

## 验证

- 选测＋专项＋必跑项，没跑全量。`选测.py 187e271f` 因动了 `xstate.gd` 选出 220 个场景，按影响面自己挑了 40 个（`并行测试.py --full`，日志 `04_验证/本地结果/并行测试/20261030_003319_zs70tatm/`，全部通过）：
  - 本期专项：`xiyou_airship_fly`（242）、`xiyou_airship_state`（28）；
  - 地图／事件／接触：`xiyou_event_compare`（必跑）、`xiyou_map`、`xiyou_map186`／`_b`／`_c`、`xiyou_map186_legions`／`_b`、`xiyou_floor_reach069`／`094`／`106`／`109`／`115`（天之上各岛图）、`xiyou_floor16_dungeon`、`xiyou_start_state_walk`、`xiyou_options_basic`（触控点按）、`xiyou_floor_run`／`_b`／`_c`（走路、遇敌、跟随全程）、`xiyou_determinism`、`xiyou_random_streams`；
  - 传送、挂机、HUD（O-117）：`xiyou_transfer`、`xiyou_hud`、`xiyou_hangup`、`xiyou_hangup_auto`、`xiyou_hangup_options`；
  - 存档（`xstate.gd` 新字段）：`xiyou_save_events`、`xiyou_save_page`、`xiyou_autosave`、`xiyou_battleback_save`、`xiyou_flow`、`xiyou_opening_branches`、`xiyou_review_regressions`、`xiyou_loose_fixes`；
  - 其它：`xiyou_screen_fx`、`xiyou_message`；切片素材名单：`ui_smoke`、`xiyou_mac_export`、`xiyou_battle_ui`。
- 偶发：`xiyou_airship_fly` 并行时 1 次失败（飞到 EV5 格上那一刻地图恰有别的提示在跑，busy 为真，判据误伤），单跑通过。已改测试：先等地图空闲、以「没被 EV5 传到 Map071」为判据，确认键前也先等空闲；改后单跑 242/242。累计偶发记录 1 次。
- 切片只加了两份素材（`extraImages` 的 `characters/Vehicle`、`extraAudio` 的 `bgm/Theme_Amara`），不算「新地图、敌群、角色、技能」，没跑 `xiyou_rules` 难度 1 四段。
- 同步：`同步正式西游.py --accept-additions --accept-changes 04_验证/测量接受/claude_wukong-airship2.json` 通过（退出码 0，留了产物指纹）。输入只多 Vehicle.png、Theme_Amara.ogg；那张接受单接受的是 `alien_affix.json` hostScope 37b5→89d8，**不是本车道改的**：本工作树的同步基线早于 main 已接受的八戒两步（`claude_bajie-alien-mp.json`、`claude_bajie-alien-mask.json`），这里一次接受首尾。总装合并时以 main 的基线为准，用不上可删。
- `内容覆盖检查.py`：new 0、resolved 0，不用更新基线。
- 降落表静态对照：`载具可达.py` 第 4 个输出生成 `tests/fixtures/airship_land.json`，专项里 69、186 全图每格（可降落＝图块判定通过且原位置没有事件）逐格与 `XMapScene.airship_land_ok` 相同。

## 本分支提交

- c56ec5d2 WIP：飞艇上下与飞行、O-117、新专项 xiyou_airship_fly、切片加飞艇图与 BGM、载具可达.py 第 4 个输出
- （登记）优化登记加 O-117 行；87bb0001 合 main
- （本提交）专项去偶发、测量接受单、交付单
