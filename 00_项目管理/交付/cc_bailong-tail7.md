# cc/bailong-tail7 交付单

- 车道／工作者：E 角色专属／白龙（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·白龙·未经审查】米拉黑龙换图核实、隐藏呼吸分类（dev.待定）

接 tail6 剩余清单的两项，都先在冻结源实机量（Playwright 无头 Chrome 加载 `冻结正式源/app.nw`、只读、新开局、网页存储，不碰玩家存档），再照量到的结果做。

- **米拉黑龙换图：量完不用做，订正头注释**。开战斗让米拉进阶 3、学 10161、加 2592，原版实机的 `_mainSprite`：人形 `UserSV_MiraHuman1_0`（缩 0.554）；黑龙 `UserSV_MiraDragon1_0`（缩 0.453，spriteHeight 72，武器藏）；动作（thrust／damage／dead／victory）逐个换成 `UserSV_MiraDragon7_1`／14_0／17_0／13_0，缩放不变。`installNativeMiraRuntime` 的 `BlackDragon_Mira_Enemy`（0.55、下移 220）包装虽然置了 `_codexDragonVisual`，但被 `Codex_MiraRavenMultiFrame`／Mx_SuperSV 的多帧盖掉，敌人图从不出现。重制 `appearance.gd` 的 form `MiraDragon` 即实机结果，不改画面代码；`mira.gd` 头注释订正；`xiyou_actor_looks` 新增 `mira.dragon_sprite`（可见高 72、武器不显示）。
- **隐藏呼吸分类：照原版隐藏**。实机对 33 个角色（1～20、167～178）量 `Window_SkillType` 与 `Window_ActorCommand` 的命令表：**没有任何角色的技能菜单或战斗指令出现技能类型 3**（`Window_Command.addCommand` 对 skill＋ext 3 一律丢）。之前重制的宿傩战斗指令多一栏「呼吸法」（`[2,1,5,3]`），渡鸦／宿傩技能菜单也多一栏，这是与原版不符的。改：`actor_modules.gd` `BATTLE_SKILL_TYPES[172]` 去掉 3；新增 `HIDDEN_SKILL_TYPE`／`visible_skill_types`，`skill_scene.types()`（强制表与特性表两路）都过一遍；`MENU_SKILL_TYPES` 保留 addedSkillTypes 原值（含 3）。渡鸦战斗指令原本就是 `[2,1,5]`，不变。头注释订正。
- **专项**：`xiyou_battle_log` 的 `types.battle.172` 改 `[2,1,5]`，新增 `types.hide3.172／167／fn`。

## 交接板

- 下一步：见「发现但没做」。
- 用户试玩说明：宿傩战斗指令里不再有「呼吸法」一栏（原版也没有）；渡鸦、宿傩的技能页分类少了「呼吸法」一页；米拉黑龙形态画面不变。
- 需要用户决定：无

## 进度账

- 不加分（订正与对齐原版）。

## 验证

- `语法检查.py`：0 问题。
- 专项（本机 `CHECK_JOBS=2`）：`xiyou_battle_log` 67/67、`xiyou_actor_looks` 34/34；选测 33 个场景见下面「选测」一行。
- 实机量法：脚本在会话草稿区，不入库（沿用 `再刷西游/_sv_probe_20261031/qa_scripts/sv_probe.cjs` 的无头 Chrome 做法，换成冻结源）。mv_oracle 的 jsdom 加载不了图片，测不出多帧叠加，所以没有写进探针。
- 没有 Godot 窗口截图：改动是技能分类栏的有无，未开窗口量。

## 待交叉核查

- 隐藏 3 对所有角色生效（`skill_scene.types()` 末尾统一过滤）：若某角色的特性 41 真有 3，会被隐藏，与原版一致（实机 33 个角色没有）。3 类的技能在菜单里不可达，原版同。
- 没改 battle_logic／actor／battler／damage／xstate 等核心文件。`battle_logic.gd:572` 的「技能类型须在特性 41 里」判定没动。

## 发现但没做（可优化／缺口）

- **功法（技能类型 6）菜单页对新角色**：原版 `installV010UsabilityRuntime` 的 `Window_SkillType.makeCommandList` 包装对 167 以上的新角色（`newActor`）在被动 4 前插「功法」，没学功法也列（实机 167～175 的技能菜单是 `[1,2,6,4,5]`）。重制 `skill_scene.types()` 只认特性，167～175 里只有屠苏、璇有 6，其余缺这一页。属 UI 缺口，请总装另派。
- 米拉黑龙状态解除后再变黑龙，我的实机脚本里第二次没再显示黑龙（可能是脚本里 `removeState` 后没满足条件，没深查）；与重制无关，没追。

## 本分支提交

- 见 `git log main..cc/bailong-tail7`

## 选测

本机跑了 23 个场景全部通过（actor_looks、actor_modules、battle_log、battle_ui、options_basic、event_compare、jingliu／jingliu2、mira_abyss／mira_battle、rules d1d／d3d／d6o 抽样、skill_mastery、skill_menu_events、skill_page、target_eval、tusu_ui、window_rects、xuan_chart、yomi_battle、yunshang_wraps、determinism），无偶发；`工具回归.py` 通过。其余 `rules_*` 抽样段与 `选测.py` 余下的未跑（没碰战斗核心，只动分类栏显示），可合并。

**可合并**
