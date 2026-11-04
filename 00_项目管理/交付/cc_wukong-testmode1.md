# 交付：cc/wukong-testmode1

- 车道／工作者：B 界面／悟空（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·悟空·未经审查】设置页「测试模式」「GM 工具」移植，只在 Kyo 本机解锁（dev.待定）

- 读原版冻结源 `installTestModeRuntime.js`（v1.4.0）。测试模式：战斗经验 ×10；战斗中付过费的技能用完直接升到当前上限（变量 8／13 难度上限、异化借用／拟态再夹角色等级）；普通（非 Boss）敌人掉的装备词缀加速（几率 ×35、60% 取最高品质组、最多 4 个，13 档以上品质不被后面普通词缀盖掉）。开关存在原版 `ConfigManager.codexTestMode`，重制改存 `user://modes/xiyou/test_mode_state`，不碰 options.json。GM 工具：加物品／武器／防具（装备每次 ≤99）、加金币、加经验（`changeExp(当前+n)`，不乘经验率）、全队恢复复活、肝帝积分／人道碎片／天道币／逆天币的增加或设为。都直接写进存档，和原版一样。
- 解锁：只认 `user://modes/xiyou/test_mode_unlock` 这个文件（有就算解锁，内容随意）。没有时设置页两项照旧留灰、状态空白、所有功能返回关，GM 页打不开。原版的作者密钥文件／联网密码不移植。仓库里没有任何密钥。
- 新增 `core/test_mode.gd`（XTestMode）、`ui/test_mode_scene.gd`（GM 工具页，Godot 控件）；挂点：`battle_logic.gd`（rewards 经验 ×rate、掉落标记 boost、gain_drops 作用域）、`skill_mastery.gd`（all_actions_end 末尾）、`gear.gd`（roll_item 在 boost 作用域内改走 `XTestMode.roll_affixes`；关闭时代码路径与原来完全一样）、`options_scene.gd`。
- 导出：`export_presets.cfg` 两个预设的 exclude_filter 加 `*test_mode_unlock*, *test_mode_state*`；`.gitignore` 加同名。`user://` 本来就在工程之外，不进 Git 也不进导出包，这两条是兜底。
- 没做：主菜单上的「GM 工具」入口（原版 `Window_MenuCommand`）、战斗外菜单用技能的熟练度训练（原版 `Scene_ItemBase.useItem`）、「待提交反馈」（要原版服务器，Kyo 定不做）。

## 交接板

- 下一步：无新增
- 用户试玩说明：Kyo 想用时在终端建解锁文件（见下），进游戏 → 设置 → 「测试模式」确定／左右键打开，再点「GM 工具」。玩家（没有这个文件）看到的设置页与以前一样，两项灰着。
- 需要用户决定：无

### Kyo 怎么用、怎么确认导出包干净

- 建解锁文件（Godot 的 user:// 在 Mac 上是 `~/Library/Application Support/Godot/app_userdata/<项目名>/`；项目名以 `project.godot` 的 `config/name` 为准，不确定时在游戏里 `ProjectSettings.globalize_path("user://")` 或看 Godot 日志）：
  `mkdir -p "<user://>/modes/xiyou" && touch "<user://>/modes/xiyou/test_mode_unlock"`
  删掉这个文件即回到普通玩家状态。状态文件 `test_mode_state` 可一起删。
- 确认导出包里没有入口：（1）解锁文件在 `user://` 即工程之外，导出包不可能带；（2）导出后 `unzip -l 导出包.zip | grep test_mode_` 应只看到源码 `core/test_mode.gd`、`ui/test_mode_scene.gd`，没有 `test_mode_unlock`／`test_mode_state`；（3）玩家机上没有解锁文件时，`XTestMode.unlocked()` 为 false，设置页两项灰着（专项 `xiyou_test_mode` 的 locked_* 段）。注意：功能代码本身是公开仓库的一部分（和原版无密钥的开关一样），拦住的是文件，不是代码。

## 进度账

- 设置页：「测试模式」「GM 工具」两项由「留灰」改为本机解锁后可用；完成度不变（玩家侧仍灰），依据：专项 66/66。

## 可优化（流程／工具／效率）

- 无

## 验证

- 专项 `xiyou_test_mode`（新，66 项）：本机 3 秒通过；覆盖无解锁文件时入口关闭／功能拒绝／状态文件无效、有解锁文件时开关与持久化、设置页状态文字与操作、GM 各项与数值校验、经验 ×10、技能升满与难度上限、掉落词缀加速与上限 4、导出过滤与 .gitignore。
- 语法检查通过（525 个 .gd）。
- 云端选测（基准上次云端通过的祖先 3644400699，合并 main 后的 e722e14324）：218 个场景、7 片，全部通过（其中 `选测.py main --list` 点名的战斗核心类、options 类场景均在内）。本机没跑选测名单（217 个 >40）。云端的 report 任务没起来，汇总由本机用各片工件算出。
- 反向验证没做（专项里关键断言用对比量：boost 前后差、×10 倍数）。

## 待交叉核查

- `battle_logic.gd`（rewards 乘 `XTestMode.exp_rate()`；drops 加 boost 标记；gain_drops 前后加减 boost_depth）：关闭时 exp_rate 为 1、不加标记，应与原行为字节一致，请核。
- `gear.gd`：`roll_item` 的词缀循环在 `boost_depth > 0` 时被跳过，改走 `XTestMode.roll_affixes`；关闭时 `boost_depth` 恒为 0。请核预掷随机池消耗无变化。
- `skill_mastery.gd all_actions_end`：只多取一份 `used_skills`（关闭时返回空），末尾 `train`。
- 原版对照点可抽核：`roll_affixes` 与原 `DX.choose`／`makeItem` 的权重顺序、60% 最高品质、`quality>=13` 保留。偏差：原版 `changeExp` 走 Game_Actor 完整流程（含升级学技能），这里直接加 exp_total 后 `_level_up`，若升级学习技能有差异，请核。

## 本分支提交

- 70a8b618 WIP: testmode1 测试模式/GM 工具（本机解锁）
- 本交付单及合并 main 的提交（见 git log）
