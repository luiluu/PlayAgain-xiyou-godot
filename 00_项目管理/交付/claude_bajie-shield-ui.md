# 交付：claude/bajie-shield-ui

- 车道／工作者：B 界面／工具／八戒（Claude，重制_八戒_50）
- 状态：可合并

## 变更记录草稿

## 2026-10-22 【Claude·八戒·未经Codex检验】清理工作树归档撞同名目录；护盾侧栏原生窗口画面对照（dev.待定）

- **期一 `清理工作树.sh`**：同一 worktree 路径被复用时（如 `magical-cori-e77cba` 先后给 bajie-samemap、bajie-icc-z），第二次清理把证据 `mv` 进已存在的 `worktree_<目录名>/`，撞上同名的 `自动同步/` 报 `Directory not empty`，`合并车道.sh --finish` 停住（唐僧_14 合并 dev.133 时实测）。现在用 `merge_into` 逐层合并：目标没有就直接移入；两边都是目录就递归合并后删空源目录；同名文件内容相同（如空的 `sync.lock`）丢掉新来的；内容不同则新来的改名为 `名字.2`、`名字.3`…，旧证据不覆盖（选后缀不选时间戳子目录：文件仍挨着原名，按原路径就能找到）。任何一步失败照旧因 `set -e` 非零退出，不删 worktree 与分支。
  - 回归 `测试工作树清理.py` 4→7 项：同一路径清理三次（第二次带同名 `自动同步/` 不同子目录，两份都留、空锁只留一份；第三次同名文件不同内容，旧的不变、新的成 `.2`）；归档目标不可写时非零退出、worktree 与分支都在。用旧脚本跑新测试复现 `Directory not empty`。
- **期二 护盾侧栏画面对照**（补沙僧 54 批核查 P3）：
  - 原版参照：`ui_reference` 战斗夹具四人（冻结版），页面内设 狗逍遥 242/485＋盾 100（蓝段在条内）、修 450/450＋盾 225（按 max(上限, HP＋盾) 折算）、罗琳 300/525＋盾 123456（「盾12.3万」）、美娜 120/480＋盾 2.5 亿（「盾2.5亿」，在输入、左移 48），截 `battle_shield_side`。读数：Window_BattleSideHP 在 (1080＋8, 序号×121＋28)，内边距 0、textPadding 4、行高 22、条高 6。
  - Godot：`tests/xiyou_battle_ui` 同一场面截 `battle_50_shield_side`。蓝段四行起止列（1171–1203、1198–1251、1092–1251、1044–1203）与行（y＋16～21）**逐像素一致**；盾字左起点与上下边一致。
  - **修复**：读到正式版 `installDisplayPreferencesRuntime` 把所有 Bitmap 的 outlineWidth 封顶 0.75px，但 outlineColor 不封顶——ShieldSystem 设的 rgba(0,0,0,0.7) 照样生效，Godot 原来用通用的黑 0.45。`XMVCanvas.text` 加可选参数 `outline`（默认不变），`side_status.gd` 的盾字传黑 0.7；蓝段起止抽成 `XSideStatus.shield_segment()`。
  - 测试 `xiyou_battle_ui`：新加 `shield_seg_*`（4 种情形的起止列）、`shield_label_*`（万／亿单位）、`shield_label_style`（盾字色、描边、蓝段色），窗口模式另加 `shield_pixels_*`（截图上蓝段起止列与原版一致）。无头 68 项，窗口模式 87 项，全过。
  - 已知、不修：盾字 12 号字形比原版右边宽 1～2px、浅蓝像素多约四成——是全工程 `XMVCanvas.EMBOLDEN`（Mac 加粗补 1px 同色描边，按 16／26 号字调的）在 12 号字上的结果，改它影响所有界面文字，不在本批范围。背景（夹具战斗背景 vs Godot 地图）、状态格图标、TP 随机值两边不同，与护盾无关。
- 截图（不入 Git）：原版 `03_再刷重制_Godot/04_验证/本地结果/原版参照/bajie50/battle_shield_side.png`；Godot `03_再刷重制_Godot/04_验证/本地结果/bajie50_godot/battle_50_shield_side.png`（及本测试其余截图）。
- 验证（车道不跑全量）：`测试工作树清理.py` 7/7；`并行测试.py` 跑 `xiyou_shield`（565）、`xiyou_battle*`（battle 8、battle_events 108、battle_options 92、battle_ui 68、battleback_save 5），全过、无偶发；`xiyou_battle_ui` 窗口模式 87/87。
- 提交：见「本分支提交」。

## 交接板

- 下一步：无新增。可从「待交叉核查」核沙僧 54 批 P3 的护盾侧栏一项：已补双端截图。
- 用户试玩说明：护盾数值文字的黑描边略深（与原版一致）；清理工作树在同一路径复用时不再停住。
- 需要用户决定：无。

## 进度账

- 无完成度变化（界面验收补项与工具修复）。

## 本分支提交

- 89ecad54 清理工作树.sh：归档撞同名目录时逐层合并，同名文件加后缀不覆盖
- d7f846f9 护盾侧栏对照原版：盾字描边黑 0.7；蓝段起止抽成 shield_segment 并加画面断言
