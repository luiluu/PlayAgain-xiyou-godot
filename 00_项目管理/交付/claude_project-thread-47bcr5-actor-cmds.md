# 交付：claude/project-thread-47bcr5-actor-cmds

- 车道／工作者：云端项目线程「地图事件与脚本翻译」第一批（Claude，云端）：角色指令与几条地图指令
- 状态：可合并（八戒本机收尾：合 main 两次无冲突，选测全过）

## 变更记录草稿

## 2026-10-25 【Claude·云端·未经Codex检验】事件指令：更改名字／职业／角色图像／称号、增减 HP／MP／TP、画面闪烁、打开存档画面（dev.待定）

- 做了什么：`MVEventCore` 接上四条角色指令，地图与战斗共用。内容覆盖基线里仅剩的 5 条「未翻译」（大厅形象重置 CE460～463、开局 Map002 EV2 第 3 页的 322）清零。
  - 320 改名、322 改图像：写进 `XActor.looks`（name／characterName／characterIndex／faceName／faceIndex／battlerName），`XActor.data()` 把它盖在数据库记录上返回（有改动时才复制一份并缓存），所以菜单、状态、脸图、队首与跟随行走图、战斗图、`\N[n]` 都读到改后的值，数据库记录不动。322 之后同原版 `$gamePlayer.refresh()` 刷新地图上的队伍行走图。
  - 324 改称号：`XActor.nickname`。
  - 321 改职业：`XActor.change_class`，照 `Game_Actor.changeClass`（YEP_CoreEngine 版）：MV 的经验按职业分开记（`_exp[classId]`），不保留经验时新职业取它自己记下的经验（没有为 0），再按 changeExp 升降级（降级不忘技能）；保留经验时新职业取当前经验。别的职业的经验记在 `XActor.class_exp`。
  - 存档：角色行只在改过时多写 `classId`／`classExp`、`nickname`、`looks`，旧档读回照数据库；`XSave.valid_data` 检查这几项的类型。`XEquipment.clone`（换装预览、战力）带上 looks 与 class_exp。
  - `XText` 的 `\N[n]` 改读存档里的角色名（原来读数据库，与 `XMVText` 不一致）。
  - 311／312／326 增减 HP／MP／TP（核心，地图与战斗共用）：照 `Game_Interpreter.changeHp`，活着才改，不允许死亡时最多扣到 1，扣血先过护盾；MP、TP 夹在 0～上限；之后 refresh（HP 归零即倒下）。用到的：一掷千金 CE46（钱不够扣 3000 HP、可致死）、快捷回血／回蓝 CE624／625（变量 317）、真气珠 CE334（TP＋20）。
  - 224 画面闪烁（地图宿主 `XMapScene.flash_screen`，照 `Game_Screen.updateFlash` 每帧强度 ×(d−1)/d，盖在地图上、窗口下）：小明基因锁 CE1551～1554。
  - 352 打开存档画面（地图宿主 `XMapScene.open_save`，存档模式的 `XSaveScene`，关闭后事件接着跑）：炉石 CE9。
- 原版里看得到的差别：v0.28 共 173 条 322 与数据库相同，不同的有波加尼脸图（CE153）、劲夫（CE228）、绿司机戴帽／脱帽（CE689／690）、钟离→云无迹（CE1209）、甘雨（CE1575），以及 CE463 把 93 号炭治郎的图像设成天虎令的（原版错写，见下「可优化」，已改成写给 104 号）；改名 4 处、改称号 18 处、改职业 1 处（玛莎 16→21，招募后能力值按 21 号职业）。
- 参照：新探针 `mv_oracle/actor_change_probe.cjs`（冻结 v0.28，新游戏，只写 `.sandbox/actor_change.json`，复制成 `tests/fixtures/actor_change_oracle.json`，不登记进同步）。四组：招募 29／125／153／1209／1575 前后的名字、称号、职业、等级、经验、五项图像、mhp 与队伍；绿司机 689／690；1～4 号改乱后跑 460～463，1～93 号的图像；狗逍遥 10 级换职业 2 不保留→换回 1→换 3 保留→3 不保留→1 保留。
- 测试：新专项 `tests/xiyou_actor_change` 48 项全过（含闪烁衰减、宿主指令登记两项不靠参照的）。分别去掉 320／324、321、322 的分支时各有 5～7 项失败。
- 验证：（本机八戒收尾，2026-10-26）单跑 `node mv_oracle/actor_change_probe.cjs`（约 8 秒，5 组无错），产物与 `tests/fixtures/actor_change_oracle.json` 除时间外完全一致。专项 xiyou_actor_change 48/48、actor_advanced 33/33、party 57/57、party_skills 214/214、save_page 40/40、battleback_save 5/5、status_page 43/43、status_power 36/36、status_power_panel 11/11。`xiyou_actor_p0` 原有断言「招募后职业等于数据库职业」与本分支照原版的 321 冲突（玛莎 CE29 16→21，参照 recruit 组已确认），改成按 `RECRUIT_CLASS_CHANGE = {21: 21}` 取期望值后 3212/3212。`检查.sh --affected main`（基准合 main 后，186 个场景＋content、guards、same_source、tools）全部通过。之后 main 又进 19 个提交，再合一次无冲突、两边改动文件不重叠，补齐后复跑 actor_change、actor_p0、actor_advanced、party、party_skills、save_page、status_page、event_compare 与 main 新加的 json_cache、variants_b，全过（合并提交 0ec3a057）。
- 没做：战斗中的 224 画面闪烁（战斗事件仍记进 skipped；v0.28 用到的四处都在地图上用的物品里）；323 更改载具图像（重制没有载具，14 处都在 CE487～498 坐骑事件里，另批）；325 更改简介（v0.28 没用到）；MOG_CharPoses 在 setCharacterImage 后记的「原行走图名」（姿势图用，Godot 没接姿势图）。
- 可用范围：招募后的职业与名字、称号与原版一致；戴帽子等换形象生效。**battleReady** 不变。

## 交接板

- 下一步：无新增。
- 用户试玩说明：招募玛莎后状态页职业与能力值同原版；签弟招募后叫「电音之王」；绿司机戴帽子换形象；大厅「更改形象」能把形象改回来；快捷回血、真气珠、一掷千金生效；炉石打开存档页；小明基因锁有红色闪屏。
- 需要用户决定：无。

## 进度账

- 地图事件与脚本翻译：38% → 40%，依据：角色指令 320～324、311／312／326、224、352 补齐，切片内容覆盖基线清零；全部 231 张图里地图上仍未翻译的只剩 323 载具图像、261 影片、235 消除图片（局部估值，请沙僧核算）。

## 可优化（流程／工具／效率）

- 待登记优化（请总装分配 O 号，代码里写的是 `O-待定`）：大厅「更改形象80」CE463 最后一条 322 写给 93 号（炭治郎），图像却是 `tianhuling-c`／`face`／`tianhuling-s`，与招募天虎令 CE1405 给 104 号的完全相同；原版用了这个重置后炭治郎变成天虎令的样子。Godot 改成写给 104 号（`MVEventCore.ACTOR_IMAGE_FIX = {"463:93": 104}`），93 号保持数据库图像。恢复方法：把这个常量设为 `{}`。专项 `reset_fix_93_104` 同时确认参照里原版确实写的是 93 号。

## 本分支提交

- 8782f140 WIP: 事件指令更改名字／职业／角色图像／称号（320～324）与原版参照、专项测试
- 1c0ac6f3 WIP: 事件指令增减 HP／MP／TP（311／312／326）、画面闪烁 224、打开存档画面 352；参照加 resources 组，专项 48 项
- 02962bde 同步：环境已有 NODE_OPTIONS 时也给 node 加 10GB 堆上限（Mac 上无影响，保留）
- 47baa009 测试：xiyou_actor_p0 招募职业断言照原版改职业（玛莎 CE29 16→21）
- 另有两次合 main 的合并提交
