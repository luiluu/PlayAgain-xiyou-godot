# 交付：claude/bajie-pets-source-97efd5-4

- 车道／工作者：B 界面·养成／八戒（Claude，重制_八戒_71）
- 状态：**暂停（WIP）**——2026-10-25 16:02 用户要先把额度给小小鱼审查，全量检查跑到 Godot 测试开头时停掉，没有结果。
- **接续要点**：功能已做完（期三＋期五，专项 `xiyou_battle_start_event` 50/50、`xiyou_party` 58/58）。剩下只有：① 跑全量 `检查.sh --full`（重点看 `xiyou_event_compare` 期三必跑、`xiyou_rules`／`xiyou_battle_common_events`／`xiyou_troop_events` 有没有因开战多跑 1320 变化）；② 有失败就修；③ 状态改「可合并」、开 PR（不合并）。云端还原素材见 `/mnt/project-files/云端素材还原说明.md`。
- 2026-10-25 本机额度用完，唐僧以 `WIP:` 保存现场（2f5c440a，期五参照探针与夹具）；云端线程接手，推到 `claude/project-thread-nxijc4`（内容即本分支＋期五），PR 不合并。
- 本分支从 claude/bajie-pets-source-97efd5-3（期四，已合 main 545ebd37 之后的 d6d1f99a）切出；合并顺序：期二 → 期一 → 期四 → 本张。

## 期三 领袖旗标对位置

- 原版（Star_LeadActor 包装 `Window_PartySelect.drawActor`）：出战栏首位是领袖角色时 `contents.blt(LeaderFlag, …, rect.width − 图宽, 0)`——rect 是首格内缩 textPadding/2 后的矩形，但不加它的 x。原版整队页读数（`ui_reference/review_system_pages.js` 新页 `party_leader`，队伍 1/8/9/10/2/3/4，首位狗逍遥＝领袖 5 号）：整队窗 (240,0,1040,172)、内边距 14、textPadding 6、首格 itemRect 202.4×144、旗标图 33×30 → 屏幕左上角 **(417.4, 14)**。
- 原版的旗标图是绘制时才 `ImageManager.loadSystem`：**打开整队页那一次图还没载好，不画**；光标移动等重画后才出现（`party_leader_open` 没有旗标，`party_leader_redraw` 有）。重制直接画（图已预载），算原版的载入时序问题，不照搬。
- 重制 `XPartyScene._paint_slots` 的公式与原版一致（同一左上角）；对图时发现**重制画成了一块白方块**：`_leader_flag()` 载入的纹理只在局部变量里，`XMVCanvas` 的注释早写明本帧画的纹理要引用到下次重画，否则 RID 失效画成白块。修：画之前 `c._keep.append(tex)`。
- `xiyou_party` 加检查 `leader_flag_kept`（画布留着 LeaderFlag 纹理、左上角 (417.4, 14)）。

## 期五 开战公共事件 1320「战斗开始时调整变量」（总装定接，还原原版）

- 原版：本版改过的 `BattleManager.startBattle` 每场先 `reserveCommonEvent(1320)`；开战第一次 `updateEventMain` 由敌群解释器跑完。1320 依次调 1315（特殊物品数量写进变量 376／380／379／541～546／1474）、1372（见钱眼开：变量 206≥30 时 547／548＝206÷60，再 ÷3；547 或 548 小于变量 20 且角色 79 在队、会 2838 时给它加状态 1044）、1373（角色 12 会的血脉技能数 → 399）、1375（出战成员里半人马 41～44 的个数减一 → 885；开关 2303 时设 3），变量 13＝1 时再把 364、361、362、370…1552～1556 截到上限。
- 参照（严格级）：`mv_oracle/battle_start_event_probe.cjs`（本机 2f5c440a 写好并取数），真实 BattleManager 推进到第一次输入，8 例（plain／caps／items／bloodline／centaur／centaur_switch／greed／greed_low），夹具 `tests/fixtures/battle_start_event_oracle.json`。
- 重制：
  - `XBattleLogic.setup` 末尾一行 `XBattleCommonEvent.reserve(self, XBattleCommonEvent.START_EVENT)`（常量 1320 在 `core/battle_common_event.gd`）。期四的通用机制让开战第一次事件检查先跑它，再看敌群页。
  - `XBattleEventRunner` 认两段 355 脚本：`_count_skills_script`（1373：`$gameActors.actor(N)` 后若干 `for … hasSkill … setValue(V, j+1)`）、`_count_members_script`（1375：`battleMembers().forEach … includes(actorId) …` 再减一）。去注释、去空白后整段匹配才执行，其余照旧跳过。
  - 新专项 `xiyou_battle_start_event`：8 例比 34 个变量与角色 79 的状态 1044，并要求子事件没有跳过的指令；50/50。
- 影响：每场战斗开战时多跑一次 1320。默认存档里这些变量都是 0，只有 885 变成 −1（没有半人马时「减去自身」）；半人马、见钱眼开、血脉、特殊物品计数从此在战斗里有值，原版本来如此。回退：删 `setup` 末尾那一行。

## 变更记录草稿

## 2026-10-25 【Claude·八戒·未经Codex检验】整队页领袖旗标对位置、修白块（dev.待定）

- 整队页首位是领袖角色时右上角的旗标，与原版整队页对过位置（左上 (417.4, 14)，图 33×30）；修了重制把旗标画成白方块的问题（纹理没留引用）。
- 原版参照页 `ui_reference/review_system_pages.js` 加 `party_leader`（打开时与重画后两态）。
- 验证：`xiyou_party` 58/58；成对截图见交付单。
- 提交：见交付单「本分支提交」

## 2026-10-25 【Claude·八戒·未经Codex检验】开战公共事件 1320（dev.待定）

- 每场战斗开战照原版先跑公共事件 1320「战斗开始时调整变量」（特殊物品数量、见钱眼开、血脉数量、半人马数量、变量上限）；1373／1375 的脚本翻译成重制指令。
- 参照：`mv_oracle/battle_start_event_probe.cjs`（8 例）；专项 `xiyou_battle_start_event` 50/50。
- 提交：见交付单「本分支提交」

## 交接板

- 下一步：期五已做完；角色专属的 355 脚本仍随各角色车道接。
- 用户试玩说明：开战后半人马、见钱眼开（角色 79）、血脉等计数照原版在战斗里生效。
- 用户试玩说明：整队页首位放领袖角色（如狗逍遥）时，首格右上角显示小旗，不再是白块。

## 进度账

- 界面·整队：领袖旗标与原版一致。
- 战斗·事件：开战公共事件 1320 从「不执行」到照原版执行。

## 可优化（流程／工具／效率）

- 已做：无新工具；`review_system_pages.cjs <目录> party_leader` 可单独重取这页。
- 建议：`XMVCanvas` 里所有「临时 load 纹理再 draw_texture」的地方都有同样的白块风险，可给画布加一个 `blit(tex, pos)` 助手自动 `_keep`，再全仓 grep `draw_texture(` 换掉（预计查出若干潜在白块；归八戒）。

## 验证

- `xiyou_party` 58/58（单跑，窗口模式截图 57/57＋新检查）。
- 成对截图（标准级）：原版 `party_leader_redraw.png`、重制 `整队_打开.png`，首格右上角放大对比旗杆与旗面位置一致（截图在会话临时目录）。
- （待补：必跑 `xiyou_event_compare`）

## 本分支提交

- 925e84d0 期三 领袖旗标：对原版整队页、修白块、xiyou_party 加检查
- 50b4cdf7 交付单：期三
- 2f5c440a WIP: 期五参照探针与夹具（唐僧代提交）
- 0482b1e7 期五 开战预约 1320、1373／1375 脚本、专项 xiyou_battle_start_event
