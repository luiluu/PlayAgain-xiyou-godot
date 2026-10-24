# 交付：claude/wukong-fortress

- 车道／工作者：A 内容·楼层／悟空（Claude，重制_悟空_49）
- 状态：可合并（期一＋期二合一张）

## 变更记录草稿

## 2026-10-24 【Claude·悟空_49·未经Codex检验】解释器补指令 223／236，并接入盘点最后四张可达地图 Map029／023／035／036（dev.待定）

- **指令 223 更改画面色调、236 设置天气**（原版 `rpg_objects.js` Game_Screen.startTint／changeWeather／updateTone／updateWeather、`rpg_core.js` Weather、ToneFilter 对照）：新 `core/screen_fx.gd`（XScreenFx，逐帧渐变与原版同式，期望值取自冻结正式源实测）；`xstate.gd` 只加 `screen` 字段与存读档（`"screen"`，旧档缺省＝无色调无天气；换地图不清，同原版 $gameScreen）；解释器 223／236 进 HOST_CODES，等待参数按帧数等；新 `map/screen_fx_view.gd`：色调用屏幕着色器（先降饱和再加红绿蓝偏移，同 ToneFilter），只作用在地图世界、不染窗口与 HUD；天气 rain／storm／snow 粒子（强度×10 个，角度、速度、透明度与暗幕同原版 Weather），在世界之上、窗口之下；粒子用自己的随机流，不动全局随机。战斗里不显示（战斗页盖在上面）；`map_scene.gd` 只加画面层与每物理帧更新（打开菜单时不更新）。
- 冻结数据里用到 223／236 的多是换图重置（色调归零、天气 none），真正开雪的是 Map023 EV2（进北风高原 Map034，snow 7／999 帧）、Map004 EV36（雪岭门）、Map220 EV8、公共事件 12／168；这些现在照原版下雪。
- 事件对照：`event_probe.cjs` 与 `xiyou_event_compare.gd` 的状态快照加 `screen`（色调目标、天气类型与强度目标；天气类型仅在目标强度不为 0 时记），Map220 EV8 页 0 的 snow 1 因此多一项 delta.screen，已用接受单 `04_验证/测量接受/claude_wukong-fortress.json` 接受（其余 events.json 测量只增 28 个新用例）。
- **接入四张地图**：切片加 Map029 十三层要塞遗址、Map023 十二层冰封洞穴、Map035 破败城堡、Map036 实验室（keepEvents 全放）与敌群 1、99、100、103、104～108、139～143（共 14 组；101、102、110、111 已在）。入口门（Map152 EV1、Map037 EV7、Map038 EV7、Map034 EV15、Map029 EV2、Map036 EV1、Map035 EV7）本来就放着，现在传得过去，不用补门。说明：Map029 EV3 嘤嘤怪要独立开关 A 开启才出现（原版也是休眠彩蛋）；Map036 通关页队伍有角色 38 时继续进 Map037，否则回 Map029 并重置副本；Map023 EV2 进北风高原时开始下雪。
- 新专项 `xiyou_floor_fortress029`（70 项）：守层者、嘤嘤怪、副本门（缺符文、有符文进 Map035）、遇敌表、试验品四战、实验用狼（变量 267 战斗／被吓跑）、入口到 Map036、塔克·修、通关回 Map029 并重置、逃离阵、冰封洞穴守层者与进北风高原下雪；新专项 `xiyou_screen_fx`（28 项）：与参照引擎逐帧数值一致、真地图跑解释器的等待与渐变、粒子数、色调层显隐、存读档保留、换地图不清。
- 内容覆盖：新增 0、已解决 65（223／236 的页），基线已更新。盘点文档「结论」已写明可达 17 张全部接完，切片现 131／231。优化登记 O-086 本批未用（没有改原版行为）。

## 交接板

- 下一步：盘点里「可达」的 17 张已全部接完；剩下 100 张原版里无可达来源，可从「来源事件就在已接地图里、只是没放进 keepEvents」的 14 张里选便宜的（224、40、192、128、125、222、132、139、195、173 等）逐张放开入口再接，需要用户决定要不要放开这些原版不可达的入口。
- 用户试玩说明：十三层守层者之后可经 Map029 的门进破败城堡（高级副本符文 110）；十二层门进北风高原时屏幕下雪；换图后天气与色调按事件设定保留，回大厅等换图事件会把它们清掉。
- 需要用户决定：无。

## 进度账

- 「楼层、副本与剧情内容」地图数 127/231 → 131/231（本期新增 4 张）；解释器指令覆盖补 223、236。

## 验证

- 同步正式西游 `--accept-additions --accept-changes`（在 worktree，不写登记）通过，核对 0 问题；内容覆盖检查 new 0、resolved 65，基线已更新。
- 专项（并行测试.py，同步后）：xiyou_floor_fortress029 70/70、xiyou_screen_fx 28/28、xiyou_event_compare 5/5、xiyou_floor_run／_b／_c 273／332／560、xiyou_floor_goblin024 96/96、xiyou_save_page 40/40；同步前（仅期一代码）另跑 xiyou_troop_events／_b 6574／6450、xiyou_battleback_save 5/5、xiyou_floor_abyss／brave／guild／unknown／lab111 等全过。第一轮 floor_run 的 `boss_no_global_random` 失败是天气粒子取了全局随机，已改为自己的随机流并复测通过。未跑全量 检查.sh。
- 画面：非 headless 截图确认色调只染世界、不染 HUD 与窗口，snow／storm 粒子与暗幕可见。
- 已清理：本车道 04_验证/本地结果 下的长任务日志、同步备份与基线、内容覆盖输出，以及临时截图。

## 本分支提交

- 见 `git log main..claude/wukong-fortress`

## 偶发修复（唐僧_17 转来）

- `xiyou_floor_lab111` 总装并行时失败一次（159 秒，单跑 68 秒通过）：该测试每个事件／等地图的等待都用 90 秒墙钟 `TIMEOUT_MS`，并行负载下单个战斗事件慢一倍就会超时；随机已固定（`seed`、`force_roll`），所以判为负载超时。把 `xiyou_floor_lab111`、同写法的 `xiyou_floor_goblin024` 的 `TIMEOUT_MS` 改为 240 秒（总上限 600 秒不变）。未能复现，只改了等待上限；若再偶发，需要抓失败时的 FAIL 行。
