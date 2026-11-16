# 交付：luiluu/cc-fest-envoy-missing

- 车道／工作者：T069 大厅庆典使者、报名处不显示（cc，Opus＋medium）
- 状态：进行中

## 变更记录草稿

## 2026-11-16 【cc·T069·未经审查】冠军庆典：大厅庆典使者、报名处不显示（只剩奖杯）（dev.待定）

- 玩家可见：冠军庆典期间方桌大厅里重新能看到庆典使者和报名处（之前只看得到银龙奖杯），奖杯两格也恢复挡路、可调查。
- **复现条件**：任何存档（西游档、天启篇档都一样）、活动日期内、任何方式进大厅（读档、传送、回城）都会出现，跟存档类型和版本无关；只要漩涡二阶段开关 `XRift.STAGE2` 是默认的 true。
- **根因**：`modes/xiyou/core/xdb.gd:195` 的 `XRift.patch_map` 先于庆典补丁（同文件 197 行）运行，漩涡二阶段把 Map004 事件表扩到 201～204 号（表长 205）；庆典补丁 `modes/xiyou/map/fest_lobby.gd:133` 原写法 `if events.size() > FIRST_EV: return`（「表长超过 78＝编号被占」）于是整段放弃，78～81 四个事件都没加。奖杯贴图是叠加层 `_deco` 直接画的、不走事件，所以只剩奖杯（而且奖杯两格事件也没进，实际不挡路、不能调查）。横幅、彩旗、BGM 判断各自不受影响——BGM 其实也在这段补丁里，同样没换。
- 专项一直没发现：`tests/xiyou_fest_lobby.gd` 开头 `XRift.STAGE2 = false`，测的是正式游戏不会出现的配置。
- **为什么推补丁前的验证没抓到**（协调问：T059 截图里使者在）：差别不在开发环境与正式包、真实日期或真实存档，而在**专项关掉了一个正式默认开着的开关**。`tests/xiyou_fest_lobby.gd` 从第一版（ca37454eb）起开头就写 `XRift.STAGE2 = false; XRift.clear_cache()`，本意是「大厅异化层另测」；T059 的候选图、最终图和专项自带的 `fest_lobby_*.png` 都是这个专项（或照它的 `open_lobby` 拍的）出的，所以图里使者一直在。`XRift.STAGE2` 的默认值在庆典开发前就已是 true（rift.gd 最后改动早于庆典），所以这个 bug 从大厅庆典第一次进包就存在，不是 T059 换位引起的。没有任何一步在「正式默认开关＋活动日期内」进过大厅看事件：专项是唯一覆盖，实机验收按 11-06 规矩不挡出包，Kyo 实机才看到。
- 修法（`fest_lobby.gd` `patch_map`）：只看 78～81 这四格是否已被别的事件占用，不看表长；空着就按编号写进去（表不够长才补 null）。四格有一格被占照旧不动。
- 专项新增「T069」一段：`XRift.STAGE2 = true`（正式默认）进大厅，断言 `rift2_on.events_padded`（表确实被扩到 204 以后）、`rift2_on.envoy_enroll_trophy`（78～81 都进图）、`rift2_on.rift_events_kept`（201～204 不受影响）、`rift2_on.envoy_cell`、天启篇档 `rift2_on.tianqi.*` 两条；该段临时把 rift2 记成看过，免得二阶段过场在本专项里开播（过场另有 `xiyou_rift2_canglong`）。修前跑：`rift2_on.envoy_enroll_trophy`、`rift2_on.envoy_cell` 失败（123/125，事件列表 1～77＋201～204）；修后 127/127。
- 天启篇隐藏（`XTianqiSect` YI/JIA_HIDDEN）只藏大厅 3、16、35 号，不涉及 78～81；`map_scene.gd:438` 的 keepEvents 过滤已有 `XFestLobby.keep_event` 放行，都不是原因。
- 验证：`xiyou_fest_lobby` 127/127；带窗口截图（西游档、天启篇档各一张，报名处 (5,17)、奖杯 (6～7,17)、使者 (8,17) 都在，使者在奖杯右侧、不被盖住）；语法检查 984 个 0 问题；`检查.sh --affected`（见下）。

## 交接板

- 下一步：无（修复随下一个补丁出）
- 用户试玩说明：庆典期间进大厅，左侧一排应看到报名处、奖杯、庆典使者，大厅曲子换成庆典 BGM。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：专项为了隔离别的系统关掉了默认开着的开关（这次是 `XRift.STAGE2`），等于测了一个玩家碰不到的组合。大厅类叠加补丁（XRift／XLobbyDebugNpc／XFestLobby／XLobbyCorruption）可以加一个「全部默认开关一起开」的冒烟专项，只断言各自的事件都进了图（预计半小时，归 cc 车道）。

## 本分支提交

- 见 git log（T069）
