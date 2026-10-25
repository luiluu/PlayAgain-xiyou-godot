# 交付：claude/bajie-pets-source-97efd5-4

- 车道／工作者：B 界面·养成／八戒（Claude，重制_八戒_71）
- 状态：进行中
- 本分支从 claude/bajie-pets-source-97efd5-3（期四，已合 main 545ebd37 之后的 d6d1f99a）切出；合并顺序：期二 → 期一 → 期四 → 本张。

## 期三 领袖旗标对位置

- 原版（Star_LeadActor 包装 `Window_PartySelect.drawActor`）：出战栏首位是领袖角色时 `contents.blt(LeaderFlag, …, rect.width − 图宽, 0)`——rect 是首格内缩 textPadding/2 后的矩形，但不加它的 x。原版整队页读数（`ui_reference/review_system_pages.js` 新页 `party_leader`，队伍 1/8/9/10/2/3/4，首位狗逍遥＝领袖 5 号）：整队窗 (240,0,1040,172)、内边距 14、textPadding 6、首格 itemRect 202.4×144、旗标图 33×30 → 屏幕左上角 **(417.4, 14)**。
- 原版的旗标图是绘制时才 `ImageManager.loadSystem`：**打开整队页那一次图还没载好，不画**；光标移动等重画后才出现（`party_leader_open` 没有旗标，`party_leader_redraw` 有）。重制直接画（图已预载），算原版的载入时序问题，不照搬。
- 重制 `XPartyScene._paint_slots` 的公式与原版一致（同一左上角）；对图时发现**重制画成了一块白方块**：`_leader_flag()` 载入的纹理只在局部变量里，`XMVCanvas` 的注释早写明本帧画的纹理要引用到下次重画，否则 RID 失效画成白块。修：画之前 `c._keep.append(tex)`。
- `xiyou_party` 加检查 `leader_flag_kept`（画布留着 LeaderFlag 纹理、左上角 (417.4, 14)）。

## 变更记录草稿

## 2026-10-25 【Claude·八戒·未经Codex检验】整队页领袖旗标对位置、修白块（dev.待定）

- 整队页首位是领袖角色时右上角的旗标，与原版整队页对过位置（左上 (417.4, 14)，图 33×30）；修了重制把旗标画成白方块的问题（纹理没留引用）。
- 原版参照页 `ui_reference/review_system_pages.js` 加 `party_leader`（打开时与重画后两态）。
- 验证：`xiyou_party` 58/58；成对截图见交付单。
- 提交：见交付单「本分支提交」

## 交接板

- 用户试玩说明：整队页首位放领袖角色（如狗逍遥）时，首格右上角显示小旗，不再是白块。

## 进度账

- 界面·整队：领袖旗标与原版一致。

## 可优化（流程／工具／效率）

- 已做：无新工具；`review_system_pages.cjs <目录> party_leader` 可单独重取这页。
- 建议：`XMVCanvas` 里所有「临时 load 纹理再 draw_texture」的地方都有同样的白块风险，可给画布加一个 `blit(tex, pos)` 助手自动 `_keep`，再全仓 grep `draw_texture(` 换掉（预计查出若干潜在白块；归八戒）。

## 验证

- `xiyou_party` 58/58（单跑，窗口模式截图 57/57＋新检查）。
- 成对截图（标准级）：原版 `party_leader_redraw.png`、重制 `整队_打开.png`，首格右上角放大对比旗杆与旗面位置一致（截图在会话临时目录）。
- （待补：必跑 `xiyou_event_compare`）

## 本分支提交

- 925e84d0 期三 领袖旗标：对原版整队页、修白块、xiyou_party 加检查
