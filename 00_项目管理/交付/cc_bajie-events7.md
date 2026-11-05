# 交付：cc/bajie-events7

- 车道／工作者：A 内容·事件／八戒（cc，派单第二批 X，一期：电影＋专属号角路径）
- 状态：进行中

## 变更记录草稿

## 2026-11-05 【cc·八戒·未经审查】播放电影 261 做出来了；屠苏／璇号角接上招募模块；号角招募路径逐条对齐（dev.待定）

- **播放电影（事件指令 261）**：原版只有宇智波鼬两段——CE1514「血轮眼开」（状态 1317「亲朋好友」的 Deselect 块在挂着它的队友倒下时 reserveCommonEvent）、CE1516「幻术世界」（技能 7481 万花筒血轮眼的公共事件效果），都在战斗里，玩家走得到。之前 `mv_event_core.gd` 261 是空操作。
  - 转换器 `xiyou_export.py` `export_movie`：Godot 4 只认 Theora，本机 ffmpeg 又没有 Theora 编码器，所以把 `movies/<名>.webm`（VP9＋Opus，3840×2160，30 帧）转成 `generated/movies/<名>/0001.jpg…`（缩到 1280×720）＋ `<名>.ogg`（Vorbis）＋ `<名>.json {fps, frames}`；ffmpeg 加 bitexact，两次转出逐字节相同（第二遍 written 0）。没有 ffmpeg 时源与上次产物都对得上就沿用，否则记 issue `movieNeedsFfmpeg`、不出片子（游戏照旧往下走）。261 不在切片爬取范围（CE1514 由状态脚本预约），所以全部公共事件扫一遍；`remove_stale` 多管一个 `movies` 子树。TOOL_VERSION 没动。
  - `ui/movie_player.gd`（XMoviePlayer）：层 89（在提示 90 下面，同原版 toaster zIndex 50000 盖在 video 上），黑底、按墙钟逐帧换图、同时放音轨（主音量总线，同 Graphics.setVideoVolume←masterVolume），只留当前一帧在内存；放完发 finished 并移除。不能跳过（原版也不能）。
  - 解释器：261 进 FLUSH_BEFORE（原版 `$gameMessage.isBusy()` 时不执行）；空片名不放（`name.length > 0`）；新虚函数 `_play_movie`。地图：发宿主指令，`XMapScene.play_movie` 放完再接着执行（waitMode 'video'）；替身宿主没有 `play_movie` 时什么也不做。战斗：`XBattleEventRunner` 记 `{type: movie}`，`XBattleScene._play` 放完再演后面的记录。
  - 新专项 `xiyou_movie`（18 项）：产物帧数（86／76）、首末帧与音轨、播放器层级与时长（≥ 帧数÷帧率）、播完移除、地图上「文字先显示→放片→放完才执行下一条」、空片名、战斗记录、CE1514／1516 原版指令里的片名。
- **屠苏／璇号角（物品 2945／2946 → CE9013／9016）之前用了号角被吞、人不入队**：`mv_script.gd` 号角脚本 `try { if (!X.recruit()) 还号角 }` 只认得渡鸦～宿傩、谷雨的模块，屠苏、璇的注释还写着「模块没移植」，其实白龙 tusu1 已做了 `XTusuXuan.recruit`。`_module_recruit` 接上 CodexTusu／CodexXuan（入队、首次给并装上法宝 4047／4048、璇建星谱，没有提示；已在队返回 false 还号角），超强者门槛照旧在外层。反向验证：去掉这两支时 `xiyou_actor_p0` 的 recruit_176／177、relic_176／177、xuan_chart、tusu_horn_refund 六项红。
- **号角招募路径逐条对齐**（`xiyou_actor_p0`）：新增 `_horn_paths`——所有效果里有公共事件、而该公共事件（含 117 子事件）有 129 入队或 `X.recruit()` 的物品（242 个）都要在招募表里真跑过，或在 `HORN_EXEMPT` 里写明为什么不跑。补跑 RECRUIT_9：开局角色 2～7 的「招聘」CE692～697、175 谷雨 9012、176 屠苏 9013、177 璇 9016。豁免 11 条：开局在队的 1、8、9、10（CE691、1205～1207），阿语 374（与 399 同一个 129）、南宫恨 1670（122＋123 已由 1668／1669 跑过），`<CodexDisabledActor>` 的 143～145、157、160（号角禁用，`xiyou_imported_balance` 对照）。另加屠苏／璇法宝已装上、璇星谱已建、已在队再用屠苏号角会还回来。

## 交接板

- 下一步：events7 二期（派单 X 的 3、4）：普查 57 种剩余写法逐种写销号依据（`script_census_known.json` 每种一句理由）、黑作坊 Map217～219 空绿补预设。一期没碰这两项。
- 用户试玩说明：鼬的「亲朋好友」队友倒下、放万花筒血轮眼时，战斗会停下来放一段两三秒的动画（原版就有，之前重制跳过了）；屠苏、璇的号角现在能招到人（之前号角没了人也没来）。
- 需要用户决定：无

## 进度账

- 地图事件解释器与脚本翻译：60% → 建议 61%，电影这一项从「仍缺」移出（转换＋地图／战斗放映＋专项）；号角路径是修正（屠苏／璇）加测试，按「修正不加分」不另记。由审查核定。

## 可优化（流程／工具／效率）

- 建议：`并行测试.py` 的「本树 generated 落后主工作区」检查把「本分支新产出、main 还没有」的文件（本期 movies/ 168 项）也当成落后，要加 `--skip-generated-check` 才跑得动；可以只在本树缺少或比 main 旧时拦（归工具车道，预计半小时）。
- 无其它。

## 验证

- 专项：`xiyou_movie`（新，18 项）、`xiyou_actor_p0`（加号角覆盖与 RECRUIT_9）、`xiyou_event_compare`、`xiyou_script_census`、`xiyou_script_gaps`、`xiyou_skill_menu_events`、`xiyou_tusu`、`xiyou_imported_balance` 本机通过（`--skip-generated-check`，原因见可优化）；`语法检查.py`、`工具回归.py` 通过。
- 选测：待写

## 待交叉核查

- 核心文件：`mv_event_core.gd`（261 改走 `_play_movie`、FLUSH_BEFORE 加 261）、`battle_scene.gd`（`_play` 多一个 movie 分支）、`battle_event_runner.gd`、`mv_interpreter.gd`、`map_scene.gd`、`mv_script.gd`。
- 转换器 `export_movie`：bitexact 稳定性、无 ffmpeg 时沿用旧产物的判断（inputs 键 `movies/<名>.webm`）。
- 号角豁免表的每一条理由。

## 本分支提交

- 87c1e98f 播放电影 261（转换器抽帧＋OGG，XMoviePlayer 地图／战斗都放、放完再往下）
- 621bdf4e 屠苏／璇号角接上 XTusuXuan.recruit；招募测试补 2～7、175～177 与物品→公共事件全量覆盖
- 2bd21c2c 合并 main
