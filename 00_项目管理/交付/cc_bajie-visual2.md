# 交付：cc/bajie-visual2

- 车道／工作者：B 界面／八戒（cc，八戒）
- 状态：可合并
- 分支从 main fe57c224 切（自建工作树 `.claude/worktrees/bajie-visual2`）。

## 变更记录草稿

## 2026-11-02 【cc·八戒·未经审查】角色形象 CharacterVisual 期二：甚尔命中动画、宿傩领域法阵、黑闪觉醒描边（dev.待定）

- **甚尔命中动画**（原版 Game_Action.apply 包装，装在甚尔包装之外）：`XToji.apply` 命中后在记录上带 `toji_anims [[动画, 延迟]]`——武器库内部行动 10220～10224（不是溅射）放该技能动画、不延迟；主技能游云 10216 第 2 段起放动画 1，延迟 min(18,(段−1)×3) 帧；术师杀手反弹（10224，`XToji.reflect`）命中同样放。`battle_scene._hit_visual` 照记录 `_start_animation` 并设 `wait`（Sprite_Animation._delay），行动序列里的照常由序列播放器逐帧推进。
- **宿傩领域法阵**（CodexBattleIndicators）：新 `battle/battle_indicators.gd`（`XBattleIndicators.DomainCircle`）照 domainCircle 原样画（88／73／49 三圈、两个三角、12 个符，y 压扁 0.34，透明度 0.82±0.08 呼吸、每帧转 0.003），放在战斗者最底层（影子之下）、可见脚底。线不抗锯齿，和原版 pixi.js 同帧截图比红色掩码交并比 0.98。
- **黑闪觉醒描边**：身体之下 2 层 × 8 方向剪影（暗红 3.5px、亮红 2px，剪影着色器整色换掉、保留透明度），每帧跟身体同图、同区域、同偏移、同翻转缩放，透明度同身体。
- 两种指示只在活着、身体看得见时显示；回放行动时按命中记录的读数（`view_of` 新增 `domain`、`flash_awake`，同换装卡 look），平时按当前状态；画面只读状态（宿傩、黑闪临时数据不存在时不判，不为渲染开数据）。

## 交接板

- 下一步：CharacterVisual 已收完（期一小猫剑圣两处动作、期二三项）；spriteWidth／Height 期一记「没做」，查过重制 `XBattlerSprite.width()／height()` 早已按归一档可见范围算（光标、状态图标用），不用另做。黑闪描边只做了断言、没和原版成对截图（要在原版战斗里让宿傩或甚尔觉醒，夹具没有），可另派一期补。
- 用户试玩说明：宿傩开领域时脚下有红色法阵慢慢转；黑闪觉醒的角色身体外有一圈红色描边；甚尔武器库追击、术师杀手反弹、游云第 2 段起命中时目标身上会放动画。
- 需要用户决定：无。

## 进度账

- 界面：角色形象 CharacterVisual 期二（甚尔命中动画、宿傩法阵、黑闪描边），整块收完。

## 待交叉核查

- 甲档（战斗核心）：`battle_logic.gd`（`view_of` 加两个只读字段）、`toji.gd`（`_hit_animation`、`reflect` 回调里加一行）。
- 乙档：`battle_scene.gd`（`_hit_visual` 放 toji_anims）、`battler_sprite.gd`（`_update_indicators`）、新 `battle_indicators.gd`、`tests/xiyou_toji_battle.gd`（`_local_visual`）、`tests/xiyou_battle_log.gd`（`toji_anim_case`、`indicator_case`）、新 `tests/xiyou_indicator_shot`。
- 丙档：新 `03_转换工具/ui_reference/domain_circle_ref.py`、ui_reference README 一条。

## 验证

- 专项：`xiyou_toji_battle` 全过（新 visual 5 条：游云 5 段动画与延迟、武器库、武器库万里锁溅射不放、反弹、别的角色不放）；`xiyou_battle_log` 50/50（新 toji 2 条、indicator 10 条）；`xiyou_indicator_shot` 4/4。
- 成对截图：`domain_circle_ref.py` 原版 PIXI 对 Godot（30 帧）平均差 0.216、红色掩码交并比 0.9836、两边掩码像素都是 1328；抗锯齿时交并比只有 0.68，所以改成不抗锯齿。
- 语法检查 0 问题。
- 云端选测（2154a04c，基准 fe57c224）：217 个场景 216 过；`xiyou_floor_reach080` 偶发（单跑通过）；`xiyou_costumes` 挂在指示读部分 view（测试只给 look）时取 `view.dead` 的脚本错误，5ea25c71 修成缺字段回退当前状态。修后本地复跑 xiyou_costumes、battle_log、change_clothes、appearance、guyu_ui、sukuna_battle、black_flash_ui、battle_ui、floor_reach080 全过；只改了 battler_sprite 一行判断，没再跑整轮云端。运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41388256658

## 可优化（流程／工具／效率）

- 已做：`domain_circle_ref.py` 自带最小 PNG 解码（本机 python 没装 PIL），以后小块图形成对比像素可照抄；回退＝删文件。

## 本分支提交

- 66ea55a5 WIP：甚尔命中动画＋专项
- 22242f07 WIP：宿傩领域法阵、黑闪描边＋画面断言
- 2154a04c WIP：领域法阵成对截图、线改不抗锯齿
- 5ea25c71 修：部分 view 时回退当前状态（云端选测 xiyou_costumes）
- 本交付单
