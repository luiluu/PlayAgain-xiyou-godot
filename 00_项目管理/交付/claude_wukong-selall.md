# 交付：claude/wukong-selall

- 车道／工作者：B 界面（战斗选目标高亮）／悟空_64（Claude）
- 状态：可合并

从 main bc7829ee 切出。用户 2026-10-29 定：全体技能选目标时全部高亮（优化 O-112）。

## 原版依据

- 原版选目标时只亮光标那一只（dev.205 实测）。全体我方只亮第 1 位，全体或随机敌人只亮光标那只。
- 原因：YEP 的 `startAllSelection` 在 `drawSpecialSelectionText` 里，而 HelpExtend 把战斗帮助窗换成了没有 `setBattler` 的说明卡，updateHelp 抛错被吞，跑不到那一步（`YEP_BattleEngineCore.js:5034–5038`、`HelpExtend.js:526–529`）。也就是说 YEP 的本意是全亮。

## 重制落点

- `battle_scene.gd`：
  - 新开关 `static var SELECT_ALL_HIGHLIGHT := true`。用 static var 而不是 const，是为了让专项能把开、关两种取值都跑一遍；改成 `false` 就回原版。
  - `_select_all_group(scope, prey_pick)` 决定这次一起亮的整组：
    - 敌方全体（2）、随机（3～6）：活着的敌人；
    - 我方全体（8）：活着的队友；我方全体倒下的（10）：倒下的队友；
    - 妖族群攻手选猎物：活着的敌人；
    - 单体、自身、开关关掉：空，照原版只亮光标那只。
  - 范围按**投影后**的技能判断：`_pick_target` 开头已经做了 `XAlienBattle.project`（八戒 dev.211），新代码排在它后面。
  - `_select_target`：整组的精灵和状态行都是 `selected`（一起闪），顺序条 `set_selected` 用整组。光标那只照旧可以移动、默认最右，确定后照旧执行，行动对象不变。
- `battler_sprite.gd`（界面文件）：新增两个显示属性。
  - `show_cursor`：整组一起闪，但箭头只画在光标那只上，表示确定会落在哪。
  - `prey`：**妖族选猎物的区分方式**是，整组白色闪，光标那只改成红色闪（亮相 (1.7, 0.7, 0.7)，暗相 (1.3, 0.85, 0.85)），再加箭头。
- 没碰 battler／actor／battle_logic。

## 优化登记行（唐僧登记）

| O-112 | 全体技能选目标全亮（`battle_scene.gd` `SELECT_ALL_HIGHLIGHT`） | 原版只亮光标那只：YEP startAllSelection 因 HelpExtend 说明卡缺 setBattler 没跑到 | 敌方全体／随机、我方全体（含倒下）的技能选目标时，整组一起闪，箭头只在光标那只；妖族群攻选猎物时整组亮、光标那只闪红当猎物；光标照旧可移动、默认最右 | 改 `SELECT_ALL_HIGHLIGHT = false` | 保留（用户 2026-10-29 定） |

## 验证

悟空_64，2026-10-29：

- `xiyou_battle_ui` 选目标确认段改成开、关两种取值各跑一遍（关时标签带 `_off`）。
  - 开：全体敌人、全体我方整组都亮，箭头只有一个、在光标那只。
  - 关：只亮一只。
  - 妖族选猎物段（开）：活着的敌人全亮；光标那只 `prey` 并且画箭头，其余没有。
- 无头单跑 `xiyou_battle_ui` 144/144。
- 窗口模式 `--out` 单跑 174/174，新截图：
  - 开：`battle_52_selhelp_all_enemies`、`battle_52b_selhelp_user`、`battle_52c_selhelp_all_allies`
  - 关：同名加 `_off`
  - `battle_53_prey_pick`
  - 目视：猎物那只闪红、带箭头；全体那张截图拍在闪烁暗相，顺序条上三只敌人都放大了。
- 选测 `xiyou_race_battle` 653/653、`xiyou_alien_affix` 674/674。
- 照派单省额度：不跑同步，没跑全量和别的专项。
- 已清理：scratchpad 里的截图和日志都删了；这期没开参照服务。

## 变更记录草稿

## 2026-10-29 【Claude·悟空·未经Codex检验】全体技能选目标全亮（O-112）（dev.待定）

- 敌方全体／随机、我方全体（含倒下）的技能选目标时整组一起亮，箭头只在光标那只；光标照旧可移动、默认最右。妖族群攻手选猎物时整组亮，光标那只闪红当猎物。范围按异化投影后的技能判断。`battle_scene.gd` `SELECT_ALL_HIGHLIGHT = false` 回原版（只亮光标那只）。
- 验收：`xiyou_battle_ui` 选目标确认段开、关两种取值都验，妖族选猎物段加全亮和猎物标记断言。

## 交接板

- 需要用户决定：「全体技能选目标全亮」那条已做（O-112），删掉。
- 用户试玩说明：放全体、随机技能时，所有可能被打到的目标一起闪，箭头那只是光标；妖族群攻时闪红的那只是猎物。

## 遗留

- 我方全体的光标照原版锁在第 1 位，整组亮了以后箭头仍在第 1 位，不能移动。这是原版的锁定行为，没改。

## 待交叉核查

- 改了：`battle_scene.gd`（`SELECT_ALL_HIGHLIGHT`、`_select_all_group`、`_select_target`、`_pick_target` 里设、清 `_target_group`／`_target_prey`）、`battler_sprite.gd`（`show_cursor`、`prey`）、`tests/xiyou_battle_ui.gd`。

## 可优化

无。

## 本分支提交

- （WIP）O-112 实现与专项
- （本提交）交付单、可合并
