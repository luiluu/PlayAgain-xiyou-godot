# 交付：cc/bajie-visual1

- 车道／工作者：B 界面（总装十二派给八戒）／八戒（cc，八戒）
- 状态：进行中
- 分支从 cc/bajie-mastery3 末端 2373ba91 切（链式：ui-gaps1 → mastery2 → mastery3 → 本期，总装只合链尾）。

## 盘点（installNativeCharacterVisualRuntime，冻结 v0.28，258 行）

「角色形象 CharacterVisual」不是换装／外观系统，是三块独立的战斗画面包装，main.js 第 110 行安装：

1. **小猫剑圣 178 的战斗图**（要 Mx_SuperSV 和 CodexSV；只认 battlerName＝CatSwordSaint_SV_v3、没开卡图）：
   - Mx.SuperSVMetaProvider：换成逐帧图 CatSwordSaint_v3，每个动作 3 帧（1 号 1 帧）、速度 12、不藏影子。**重制已有**（`XAppearance.sv_provider`）。
   - 两张图的站姿归一档（可见范围、缩放 min(72／高, 129／宽)、脚底锚点、最近邻）、逐帧时藏武器。**重制已有**（`XAppearance.PROFILES`，battler_sprite 藏武器）。
   - performAttack 之后再要挥舞动作。**本期做**。
   - 不在移动时「走」改「待机」，待机停在第 0 帧（OTB 走完一步会留着走路动作）。**本期做**（和谷雨共用 `_guyu_planted`）。
   - spriteWidth／spriteHeight 按归一后的可见范围算。**没做**：重制的动画、伤害弹字位置不读 spriteWidth／Height，要先查清哪些画面用到。
2. **甚尔 171 的命中动画**（Game_Action.apply 包装）：武器库内部行动 10220～10224（不是溅射）命中时在目标身上放技能动画；主技能 10216 第 2 次起的追加段（`_tojiIndex>1`）放动画 1，延迟 min(18, (段−1)×3) 帧。**没做**，期二。
3. **战斗指示 CodexBattleIndicators**（Sprite_Actor.update 包装，Scene_Boot 时最后装，跟着实际显示的那一帧）：
   - 宿傩 172 领域展开中：脚下红色法阵（半径 88／73／49 三圈、两个三角、12 个符，y 压扁 0.34，透明度 0.82±0.08 呼吸、每帧转 0.003），按归一档放在可见脚底。**没做**，期二。
   - 黑闪觉醒（CodexBlackFlash.status(a).awake）：身体外两层 8 方向剪影描边（暗红 3.5px、亮红 2px），跟身体同帧同变换。**没做**，期二（要 Godot 着色器或剪影缓存）。
   - 换战斗者时藏起两者。

分期：期一（本期）＝小猫剑圣两处动作；期二＝宿傩法阵、黑闪描边、甚尔命中动画（都要浏览器参照成对截图）；spriteWidth／Height 先查用途再定。

## 变更记录草稿

## 2026-11-01 【cc·八戒·未经审查】角色形象 CharacterVisual 盘点；小猫剑圣普攻挥舞、站定不走（dev.待定）

- 盘点 installNativeCharacterVisualRuntime：小猫剑圣战斗图、甚尔命中动画、战斗指示（宿傩领域法阵、黑闪觉醒描边）三块；小猫剑圣的逐帧图与站姿归一重制已有（见交付单「盘点」）。
- 小猫剑圣（`XAppearance.cat_visual`：battlerName CatSwordSaint_SV_v3、没开卡图）：普攻动作改挥舞（battle_scene `_perform_action`、sequence_player 的 attack）；不在移动时「走」改「待机」、待机停在第 0 帧（battler_sprite，和谷雨同一处）。

## 交接板

- 下一步：CharacterVisual 期二（宿傩领域法阵、黑闪觉醒描边、甚尔命中动画，对浏览器参照成对截图）；spriteWidth／Height 先查重制哪些画面要用。
- 用户试玩说明：小猫剑圣普攻改成挥舞动作；站着不动时不再原地踏步。
- 需要用户决定：无。

## 进度账

- 界面：角色形象 CharacterVisual 期一（盘点＋小猫剑圣两处动作）。

## 待交叉核查

- 乙档：`appearance.gd`（cat_visual）、`battle_scene.gd`／`sequence_player.gd`（普攻动作各一行）、`battler_sprite.gd`（planted 认小猫剑圣）、`tests/xiyou_cat.gd`（_visual）。

## 验证

- `xiyou_cat` 998/998（新 visual 4 条）。
- 选测：xiyou_appearance、change_clothes、costumes、actor_looks、battle_ui、cat、guyu_battle 7 个收工时在跑，结果没看到；接手先单跑这 7 个再标可合并。
- 没对浏览器截图：这两处是动作选择，不是像素；期二的法阵、描边要截图。
- 语法检查 0 问题。

## 可优化（流程／工具／效率）

- 无。

## 本分支提交

- 本交付单（含实现）
