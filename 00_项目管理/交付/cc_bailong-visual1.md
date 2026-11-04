# 交付：cc/bailong-visual1

- 车道／工作者：B 界面／白龙（cc）；基于 main f748c69a，已合并 main
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·白龙·未经审查】visual1：SV 敌人影子／呼吸／武器、角色立绘放大 SvPngFd、状态循环动画 1297（dev.待定）

**① SV 敌人四标签**（`YEP_X_AnimatedSVEnemies`，新探针 `sve_probe.cjs`→`oracle/sve.json`，用真实 Game_Enemy／Sprite_Enemy 量；新类 `battle/sv_enemy.gd`）
- 影子：186 个 SV 敌人全部显示（Shadow2，缩放＝一格宽/64）；非 SV 的 9 个标签无效。已做。
- 呼吸：SV 敌人全部不呼吸；1814 个非 SV 呼吸，周期 2π×Speed 帧（9 个 11，其余 20），横向 0.001、纵向 0.02。原来所有敌人固定 2.4 秒周期，已按此改。
- 武器：44 个有武器图，142 个武器号 0＝thrust 无武器图。SV 敌人普攻（行动序列 attack／thrust／swing／missile）现在播对应动作并出武器图（敌人整体镜像，武器图跟着翻）；`user.attackMotion()` 条件也读敌人。攻击动画号 186 个全是 1。
- 倒下不淡出：核实为无效，不做。`MOG_CollapseEffects` 默认死亡效果 0 在 updateCollapse 最前面接管，SV 无 Collapse 的敌人与普通敌人倒下透明度时序一样（约第 75 帧到 0）；全库没有 `<Sideview Collapse>`。
- 副发现（未做，建议派活）：原版所有敌人倒下用 MOG 默认「粉碎」效果，重制是红色淡出 0.5 秒。纯画面，中等大小。

**② SvPngFd**（dsPassiveSkill，探针 `svpng_probe.cjs`，类 `battle/sv_png_fd.gd`）：全库防具 8 件（重制切片没有 8017）＋状态 1120；倍率乘在角色身体上（影子不放大）；多件按装备→技能→状态顺序最后一个生效（不取最大）；只在开战时算一次。敌人备注（850、938）原版没人读，不做。

**③ 状态循环动画**（YEP_X_VisualStateFX，探针 `vsfx_probe.cjs`，类 `battle/vsfx.gd`，`battle_scene._update_state_animations`）：全游戏只有状态 1297 带动画 900（60 帧、位置＝目标中心、无闪光音效）；第一个有 `<State Animation: N>` 的状态定号，号变才换，播完同一帧接着播，去状态立刻清，不透明度跟战斗者，角色敌人都放，不受「战斗技能动画」开关管。

没改玩家能算的数值；没碰 `damage.gd`、`battle_logic.gd`。

## 交接板

- 下一步：MOG 默认粉碎倒下效果；界面对照图。
- 用户试玩说明：SV 敌人脚下有影子、不再呼吸；怪物普攻会挥武器／射击；穿「变大／泰坦／巨人指环」等装备或带人鱼化身状态开战，角色立绘变大；刻印环身盾状态有光环循环动画。
- 需要用户决定：无。

## 进度账 / 可优化

- 无；无。

## 待交叉核查

- 新类 `sv_enemy.gd`、`sv_png_fd.gd`、`vsfx.gd`；改了 `battler_sprite.gd`、`battle_scene.gd`、`sequence_player.gd`、`action_sequence.gd`（敌人 attackMotion）。未改 battle_logic／damage。

## 验证

- 新专项：`xiyou_sve_visual`（31）、`xiyou_svpngfd`（27）、`xiyou_vsfx`（22）通过；反向验证 7/7、4/4、6/6 咬住。
- `语法检查.py` 通过；`同步正式西游.py --accept-additions` 退出 0。
- 选测 141 个场景>40，走云端（见下）。

## 未做

- 「界面对照图」没出：无头环境截不了战斗画面，原版侧要另起 ui_reference 夹具；规则已由真实 Sprite 对象量值＋逐敌断言守住。需要的话另派出图任务。
- 开战时 StartPushState 加的状态是否计入 SvPngFd 未单独验证。

## 云端结果

- 云端选测（262 个场景、7 片，基准 b32ba7099d，提交 196bb5962f）：通过，<https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41881234552>。
