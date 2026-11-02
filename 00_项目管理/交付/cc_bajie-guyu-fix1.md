# 交付：cc/bajie-guyu-fix1

- 车道／工作者：B 界面·规则／八戒（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-02 【cc·八戒·未经审查】谷雨读档按新档进阶同步；技能窗熟练度 LV 千位逗号（dev.待定）

- **谷雨读档（沙僧二审 S2-2-01）**：`XState.from_dict` 原先在 `_become_current(s)` 之前调 `XGuyu.after_load(s)`，而 `XGuyu.stage` 查的是 `XState.current`，于是按「读档前那一局」的进阶次数学／忘「我即万物之春」（10297）。改成换成新档之后再同步，和原版一致：extractSaveContents 包装在原函数之后 syncAll，看新档（`guyu_probe` 的 stats.s5.lv60 经原版 encode→restore 后含 10297，errors 空；现成参照，未改探针）。
- **技能窗「LV.n」（审查第 22 期 P3-2）**：原版 `drawSkillMasteryLevel` 用 `Yanfly.Util.toGroup`，1000 级起显示「LV.1,000」；新 `XSkillScene.mastery_level_text` 复用 `XMenu._group`。

## 交接板

- 下一步：CharacterVisual 期二（宿傩领域法阵、黑闪觉醒描边、甚尔命中动画）本分支没做，照旧待派；做法要点见下「期二要点」。
- 用户试玩说明：读一个谷雨 5 阶、60 级的档时，不再因为之前开着的另一局而暂时少了「我即万物之春」；技能熟练度到 1000 级以上显示带逗号。
- 需要用户决定：无。

## 进度账

- 规则：谷雨读档同步顺序修正（S2-2-01 销项待审查）；界面：熟练度技能窗 LV 千位逗号。

## 待交叉核查

- 甲档（存档）：`xstate.gd` from_dict 里 `XGuyu.after_load` 挪到 `_become_current` 之后（3 行）；请顺带看同一处 `XYomiJingliu.after_load`、`XBinding.clear_all`、`XTusu.clear` 是否也读 `XState.current`（`tusu_xuan.gd` 的 `_owner` 读 `XState.current`）（本分支没查、没改）。
- 乙档：`skill_scene.gd`（`mastery_level_text`）、`tests/xiyou_guyu.gd`（`_load_cases`）、`tests/xiyou_skill_mastery.gd`（`_level_text`）。

## 验证

- 新专项「内存读档」（xiyou_guyu `load.*`）：两组——新档 5 阶读在 0 阶当前局之上、新档 0 阶读在 5 阶当前局之上，都走 `to_dict`→JSON→`from_dict`；读后不进战斗查技能账本、技能表、被动缓存，再进战斗 setup 后、结束后各查一次，全程与存档前同一角色比。
- 本机：`xiyou_guyu` 78/78、`xiyou_skill_mastery` 306/306（新 `ui.level_text_group`）。
- 反向验证（`反向验证.py`）：把谷雨同步放回换档之前（旧顺序）→ 咬住；LV 改回 `str(lv)` → 咬住；「读档完全不同步」→ 没咬住，这是预期：两组存档本身账本一致，不需要同步也对，旧顺序错在按旧局去「改」。
- 选测：`选测.py main --list` 284 个（xstate.gd 是核心文件），走云端（基准取上次云端通过的祖先 007c3c72，实际 311 个场景、14 片）全过，运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41367931973
- 合 main（edcc1ca4，含屠苏三期）：`xstate.gd` 同一处冲突，留 `XTusu.clear(s)`、谷雨同步仍在换档之后；`--补齐` 刷新参照后本机复跑 `xiyou_guyu` 78/78、`xiyou_tusu` 314/314、`xiyou_tusu_battle` 992/992。合并后的提交没再上云端（main 那批已云端测过，冲突只一行）。
- 语法检查 0 问题。

## 期二要点（没做，留给下一期）

- 甚尔命中动画：原版 Game_Action.apply 包装，命中后 `_tojiInternal && !_tojiSpreadRate && 10220～10224` 放该技能动画、延迟 0；主技能 10216 非内部且 `_tojiIndex>1` 放动画 1，延迟 min(18,(段−1)×3) 帧。重制挂点：`XToji.apply`（toji.gd，命中判断 `used and not missed and not evaded` 已有）在结果里带上动画号和延迟；`battle_scene._show_hit` 放，但 `_start_animation` 现在没有延迟参数，要补。
- 宿傩法阵、黑闪描边：要浏览器参照成对截图，描边要着色器或剪影缓存，工作量大，建议单开一期。

## 可优化（流程／工具／效率）

- 无。

## 本分支提交

- cb315f63 谷雨读档同步挪到换成新档之后＋内存读档专项；技能窗熟练度 LV 千位逗号
- 17ddf905 交付单
- 97b45019 合并 main（解 xstate.gd 冲突）
- 本次：交付单补合并后验证
