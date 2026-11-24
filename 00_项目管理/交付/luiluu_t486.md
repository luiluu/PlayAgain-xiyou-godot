# 交付：luiluu/t486

- 车道／工作者：T486 查旧存档看不到徐凤年出场动画（cc 车道，Opus＋medium）
- 状态：可合并

## 结论（先看这里）

**不是特效开关的问题，也不是存档问题；是「全机只播一次」的设计＋两个容易踩的条件。** 代码按设计跑，没找到让 v0.03 时代旧档必然不播的 bug。

1. **跟「画面特效」开关无关**：三阶漫画过场这条链路（`XRift._rift3_event` → `CodexRift3.available()` → `XMapScene.play_rift3_anim` → `XRift3Anim.available()`）只认 `XRift.STAGE3`、`XRift.RIFT3_ANIM`、`XRift3Anim.ENABLED` 三个代码开关和 19 张素材在不在，不读 `codexScreenFx`／`XGraphics.fx_on()`／画质设置。实跑「画面特效」关和开两种情况都照常播（下面 A、B 两行）。
2. **触发条件记在配置里、不在存档里**：播没播过记在 `options.json` 的 `codexWhisperSeen`（全机共用，所有存档一份），存档里不记。条件是「rift2 看过 ＋ rift3 没看过 ＋ 不是刚播完 rift2 的这一次进大厅」，进 Map004 大厅时由 EV205 自动执行。
3. **一开播就先记看过**：事件第一条就是 `CodexWhisper.mark('rift3')`，然后才放动画。所以：
   - **玩家只要在这台机器上任意一个档（新开的档也算）进过一次大厅，动画就算看过了**，之后读旧档进大厅不会再播（实跑 C 行）。玩家说「新包旧档看不到」，最可能是先开新档或先进过一次大厅看到（或点掉）了，再读旧档就没了。
   - **0.8 秒后任意按键／点屏／鼠标左键都会整段跳过**，只把没看全的台词用对话框补一遍。读档时连点确认、手机上点屏推进的玩家很容易一进大厅就把 30 秒漫画点掉，体感就是「没看到动画、只看到几句话」。
   - 中途退游戏或闪退也不会补播。
4. **配置文件丢了（换机器只拷存档、重装清了数据、手机清数据后导回存档）**：配置里连 rift1／rift2 都没有，第一次进大厅先补放流萤（rift1）和苍龙（rift2），徐凤年要**出大厅再进一次**才播（实跑 D1、D2 行）。玩家只进一次大厅就会以为没有。

我的判断：**设计如此（并非 bug）**，但体验上有两个坑值得修：一是「只播一次且全机共用」又没有重看入口，二是点一下就跳整段太容易误触。

## 代码位置（补丁线 github/patch/v0.04 与本分支底 main 这几处逐字相同）

- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/rift.gd:67` `RIFT3_CONDITION`（rift2 看过、rift3 没看过、不是同一次进大厅）
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/rift.gd:75` `stage()`：看过 rift3 才是三阶（徐凤年号角上架也认它）
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/rift.gd:251` `_whisper_pages`：并行页查条件→自动执行页播→A 页停
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/rift.gd:349` 事件第一条 `CodexWhisper.mark('rift3')`（先记后播）
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/rift.gd:355` `CodexRift3.available()` 分支：素材齐走漫画，缺素材回退像素过场
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/xconfig.gd:51` 配置路径 `user://modes/xiyou/options.json`；`:380`／`:387` `whisper_seen`／`whisper_mark`（存配置不存存档）
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/xconfig_transfer.gd:30` `codexWhisperSeen` 属进度类，「导入／导出配置」不带它
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/rift3_anim.gd:387`／`:396` `_rift_switch_on`／`available()`：只看 STAGE3、RIFT3_ANIM、ENABLED 和素材
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/rift3_anim.gd:492` `_input`：0.8 秒后任意键／点屏／手柄键跳过
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/map_scene.gd:1494` `play_rift3_anim`（不读特效设置）
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/graphics_quality.gd:101` `fx_on()`：只被大厅异化、庆典、环形菜单用，rift3 链路没调用（`git grep -n 'fx_on()' -- modes`）
- 发行预设 `export_presets.cfg` 不排除 `content/rift3/`，素材 19 张都随包（`git ls-tree github/patch/v0.04 …/content/rift3/`）

## 复现步骤与证据

临时探针（不入仓，源码副本见 [t486_probe.gd.txt](../交付截图/luiluu_t486/t486_probe.gd.txt)）：隔离配置目录，新开一档放在大厅存进 1 号槽当「旧档」，`XSave.load_slot(1)` 读档后开大厅，最多等 900 帧看 `XRift3Anim` 节点出没出现。无头、`--audio-driver Dummy`，Godot 4.7.2。输出见 [探针实跑.log](../交付截图/luiluu_t486/探针实跑.log)：

| 场景 | 配置 codexWhisperSeen（进前） | 画面特效 | 漫画播了没 |
| --- | --- | --- | --- |
| A v0.03 玩家读旧档 | rift1、rift2 | 关 | 播了 |
| B 同上 | rift1、rift2 | 开 | 播了 |
| C 已在任意档看过一次后再读旧档 | rift1、rift2、rift3 | 开 | **不播** |
| D1 配置丢了，第一次进大厅 | 空 | 开 | **不播**（先补放 rift1、rift2） |
| D2 同上，出去再进一次 | rift1、rift2 | 开 | 播了 |

玩家侧复现（C）：装 v0.04＋v0.04.01 → 新开一档（或读任一档）进大厅，看到或点掉漫画 → 读旧档进大厅 → 不再播。（D）：只拷存档到新机器/清过数据 → 读旧档进大厅只看到流萤、苍龙 → 不出大厅就看不到徐凤年。

## 修法建议（本单不改代码）

1. **不用跟特效开关脱钩**：本来就没挂在特效开关上。
2. **给玩家补看一次**（推荐，改动小）：漫画播完／被跳过时另记一个键（如 `rift3_comic`），只有「自然播满」才记；开播时如果被 0.8～3 秒内跳过，不记 `rift3_comic`，下次进大厅再播一次漫画（只播漫画，不重复阶段推进）。已经看过 rift3 但没有 `rift3_comic` 的老配置下次进大厅也补看一次——注意老配置分不出「看完了」和「点掉了」，所以 v0.04 已看完的人也会再看一遍（30 秒、可跳，代价小）。可回退开关。
3. **加重看入口**（推荐）：在改版向导 EV071 选单或设置页「画面」下加「重看过场：徐凤年」（以后苍龙、流萤也可放进来），直接调 `XMapScene.play_rift3_anim()`，不碰 `codexWhisperSeen`、不改阶段。图鉴目前没有过场分页，放向导最省。
4. **跳过要更难误触**：把 `SKIP_GUARD_SEC` 从 0.8 拉到 2 秒，或改成「点一下出『再点一次跳过』提示、两秒内再点才跳」；手机上尤其需要。
5. 「全机共用一份看过标记」本身建议保留（阶段推进、号角上架都认它，改成按存档记会动存档结构，属要 Kyo 定的一类）。

## 变更记录草稿

## 2026-11-25 【cc·T486·未经审查】查：旧存档看不到徐凤年出场漫画（dev.待定）

- 只读排查，不改游戏代码。三阶漫画过场不挂画面特效开关；看过标记记在配置 `codexWhisperSeen`、全机只播一次、开播先记看过，0.8 秒后点一下就跳整段；配置丢了要进两次大厅。探针实跑五个场景佐证，修法建议见交付单。

## 交接板

- 下一步：可派一条小车道做「补看一次＋重看入口＋防误触跳过」（修法 2～4，开关可回退）
- 用户试玩说明：无（只读排查）
- 需要用户决定：是否做重看入口、放改版向导还是设置页；跳过改成两次点击还是拉长保护期

## 进度账

- 无变化

## 可优化（流程／工具／效率）

- 建议：过场「看过」类标记以后统一配一个重看入口，玩家反馈「没看到」时可直接让玩家自己重看，省一轮排查（归做修法 3 的车道）

## 动了的共用函数和开关

无（未改代码；临时探针已删，不入仓）

## 云端选测

没跑云端：本单只读排查、没改任何 `.gd`／数据，云端选测对未改动代码没有新增信息；证据用本地探针实跑代替（上表）。

## 本分支提交

- （见 git log：T486 交付单与探针证据）
