# 交付：claude/friendly-babbage-af0af6

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_18）
- 状态：进行中
- 位置：本会话被限定在桌面 app 建的 worktree `.claude/worktrees/friendly-babbage-af0af6`（不能写别的 worktree），所以没用唐僧建的 `bajie-guidance`；该 worktree 与分支 `claude/bajie-guidance` 未动（仍在 199b8f6），可直接清理。本 worktree 已 `新建工作树.sh --补齐`。

## 变更记录草稿

## 2026-10-18 【Claude·八戒·未经Codex检验】修行指引第二阶段：区段里程碑与「下一步建议」（dev.待定）

- 照 installNativeGuidanceRuntime v2.1 做区段里程碑与方桌大厅「商店向导」→「下一步建议」（修行页与战力条真气已在 dev.077）。
  - 区段表 G.ATLAS（7 段：1～6、7～12、13～15、16～18、19～21、22～25、26～33 层；介绍、可刷副本 Boss、流派书／专属被动书、洪荒权能）从冻结源抽成 `modes/xiyou/guide_atlas.json`（记源文件 SHA）。
  - 区段里程碑：地图上没有事件、菜单、传送页时每 30 帧查修行进度层所在区段，没看过就记看过（`XState.guide_seen`，随存档 `guideSeen`）并弹出本段说明（每段一页，101／401 `<WordWrap>`），每段一次。开局到大厅后会弹「神魔之塔 1～6 层」。
  - 「下一步建议」：`CodexGuide.advise(this)` 由 mv_script 接，子解释器显示：进度与下一个守层者、待选奖励／可突破的人、本段可刷副本 Boss 与奖励规则、专属掉落、养成入口与本段祝福进阶石（首次胜利是否已领）。
  - 消息窗支持 YEP `<WordWrap>`（之前会把标记原样画出来）：去标记、去换行、`<BR>` 换行，无标记时删 `<BR>`；自动换行比 zidonghuanhang 早 30 像素（本作改过的 checkWordWrap）。
  - Boss 预告：原版 `G.PREVIEW_ENABLED=false` 且无调用处，照原版不做。洪荒权能一句随洪荒难度（未移植）。
- 优化：O-050「下一步建议」不显示「战力短板」一段（五乘区不移植，同 O-044）。
- 验证：新探针 `mv_oracle/guide_probe.cjs` 冻结 v0.28 参照 25 例（区段表、楼层→区段、各段里程碑文字与指令列、看过判定与存档、建议 12 种局面、商店向导事件指令列、祝福石段）；已加进 同步正式西游.py PROBES 与 oracle_additions KEYS。`tests/xiyou_guide` 54 项全过（建议文字比去掉 CodexZones 的参照，另查完整原文只多「战力短板」一段；商店向导事件用固定应答宿主跑完整流程；WordWrap 3 例）。检查.sh：见下方状态。
- 未完成：Map004 事件 73「商店向导」不在切片 keepEvents（切片是悟空独占文件），游戏里还见不到这位 NPC，见交接板一节。

## 交接板

- 下一步：合并时（或悟空下一批）在 `xiyou_slice.json` 的 keepEvents["4"] 加 `73`（商店向导，只有 101／102／355 `CodexGuide.advise`，无其他依赖），之后跑 `内容覆盖检查.py`。交接板「下一步」4 的修行指引一条与第 4 页「修行」一条可删。
- 用户试玩说明：首次到新区段（新局到大厅、通过第 6、12、15、18、21、25 层后）会弹出该段的玩法说明；方桌大厅入口「商店向导」可问「下一步建议」（切片加事件 73 后）。
- 需要用户决定：O-050（攒批）。

## 进度账

- 养成与周边系统：12% → 13%（初值，待沙僧复核），依据：修行指引除战力短板（不移植）与 Boss 预告（原版关闭）外已做完。

## 本分支提交

- bd81dd2 WIP: 修行指引第二阶段：区段里程碑、商店向导「下一步建议」、消息窗 WordWrap；guide_probe 参照 25 例
