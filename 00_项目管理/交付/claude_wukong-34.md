# 交付：claude/wukong-34

- 车道／工作者：A 内容·楼层／悟空（Claude，重制_悟空_34）
- 状态：可合并（徽章图的导出等切片归八戒的 bajie-42 合并后再补，见「未完成」）
- 完成范围：期一参照、期二实现（绘制参数与样式）；两张徽章 PNG 未经切片导出。

## 变更记录草稿

## 2026-10-21 【Claude·悟空·未经Codex检验】成就 142／143 专用徽章与特殊样式（dev.待定）

- **期一：参照**。新增 `mv_oracle/achievement_badge_probe.cjs`（登记进 `同步正式西游.py` 的 PROBES，产物 `achievement_badges.json`）：真实 `Window_AchievementBookIndex.drawItem` 与 `Window_AchievementPopup.refresh`，把 `contents` 的 2D 上下文包一层，记 canvas 级调用（`drawImage` 目标位置／尺寸／`globalAlpha`、`createLinearGradient` 与停点、`strokeText`／`fillText` 的 baseline、`lineWidth`／`strokeStyle`／`shadowColor`／`shadowBlur`、`fillRect`）以及方法级的 text／icon 调用。6 例：`list.142.owned／unowned`、`list.143.owned／unowned`、`popup.142`、`popup.143`。徽章图用 256×256 的空位图代替。旧探针 `achievement_probe` 与既有用例不动；用新探针而不往 `achievements.json` 加字段，是因为 `oracle_additions` 对该文件没有稳定键，新增顶层字段会被判「顶层字段集合变化」。
- **期二：实现**。新增 `ui/achievement_badge.gd`（`XAchievementBadge`，把「画什么」写成数据 plan）、`XMVCanvas` 加 `badge`／`fill_rect`／`gradient_text`；`XAchievementScene.paint_item`、`XAchievementPopup` 按 plan 画：
  - 142 已得：徽章 64 画在 (6, y)（普通图标在 22），名字改渐变描边字（字号 26，baseline＝y＋108/3/2＋26×0.35，渐变 `#fff8db`→`#f7dda0`→`#c69d55`，描边 3 `#2d1749`，阴影 `#9463d0` 模糊 4）；触发条件、「已获得」、「完成于…」照旧；未得走普通「未获得」。
  - 143：列表行不论得否只画 64 徽章在 (14, y＋22)，未得透明度 80/255，不写「未获得」。
  - 弹窗 142：32 徽章 (10,10)，标题渐变字（字号 20，(50,5)），说明照旧，上下各 1px 线 `#b391d5`／`#c7a261`；弹窗 143：窗宽 64、窗口不透明度 0、只画 40 徽章在 (12,5)，无标题与说明，居中位置按实际窗宽。
  - 渐变字在 Godot 画布里没有逐字渐变，用描边＋外圈阴影＋渐变中间色填充**近似**，参数与参照逐项对照，画面不比像素。
- 测试：新增 `xiyou_achievement_badge`（32 项）逐例对照参照的位置、尺寸、透明度、停点、baseline、描边阴影参数、两条线、窗宽与窗口不透明度，并实例化弹窗节点核对；`xiyou_achievement` 50／50、`ui_smoke` 22／22 不变。
- 同步：`同步正式西游.py --accept-additions` 一轮「新增用例，已接受」，只新增 `achievement_badges.json`，其余测量不变。

## 未完成（等八戒 bajie-42 合并后）

- `xiyou_slice.json` 的 `extraImages` 加两条：`codex_achievements/EssenceMaster`、`codex_achievements/KYO`（现有条目格式同 `pictures/BattleCursor_A`），然后重跑 `同步正式西游.py`、`内容覆盖检查.py`。图片没导出前，`XMVCanvas.badge` 找不到文件就不画（不报错），徽章位置是空白、文字样式已生效。
- 地图名牌里玩家昵称的铂金渐变循环（`K.updatePlayerName`）属称号／名牌系统，本期不做；143「首次获得需测试模式」重制没有测试模式，沿用既有处理。

## 交接板

- 下一步：八戒合并后补 extraImages 一轮；然后把「142／143 专用徽章」从未完成里划掉，仅留名牌渐变。
- 用户试玩说明：成就界面与弹窗里 142「本质高手」、143「kyo专属」的专用样式（徽章图要等切片补图后才会显示）。
- 需要用户决定：无。

## 进度账

- 无变化。

## 检查

- 相关专项：`xiyou_achievement_badge` 32／32、`xiyou_achievement` 50／50、`ui_smoke` 22／22；同步一轮；没有改切片，未跑内容覆盖检查（补图那一轮再跑）。车道不跑全量。

## 本分支提交

- 见 `git log main..HEAD`
