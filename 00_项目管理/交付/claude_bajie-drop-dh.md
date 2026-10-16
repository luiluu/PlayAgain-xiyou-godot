# 交付：claude/bajie-drop-dh

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_11）
- 状态：可合并（检查结果见下）。建议下一项（交接板「下一步」第 5 项的界面项）：设置页其余 5 项按内容批次接入，或主菜单灰显指令；另见下面「交接板」里的 MVAnimation 跟进项。

## 变更记录草稿

## 2026-10-17 【Claude·八戒·未经Codex检验】图标 dh 目标闪光：掉落图标动画按正式版逐帧（dev.待定）

- 定位：`<dh:N>` 由 krz_iconsetimprove 覆写的 `SpriteEnemyTrP.createIcon` 处理，N 是**动画 ID**；建图标时（敌人倒下、掉落图标出现的同一帧）`Sprite_Base.startAnimation($dataAnimations[N], false, 0)`，不受「显示技能动画」开关影响，帧速 = 战斗变速（YEP_BattleAniSpeedOpt）。数据里 dh 用到 8 个动画（135/143/166/179/181/183/197/531，都在「中心」），179 紫装、181/135 粉装靠 animation1Hue（216/267）转色相区分，多数还带屏幕闪光（flashScope 2）。
- `battle/drop_popup.gd` 改写：
  - 动画改为 `DhAnimation`（MVAnimation 子类，由弹出节点逐帧推进）：位置取图标**上一帧**坐标（子节点先更新、弹跳在后），中心按 32×scale.y 上移；动画图按 animation1Hue/animation2Hue 转色相（Bitmap.rotateHue 同算法的着色器，含四舍五入到偶数）；屏幕闪光是动画子节点、画满画面、盖住它之前的兄弟节点，不透明度每帧 ×(d−1)/d；`_duration` 到 0 的下一帧才由图标移除（原先早一帧）。
  - 图标改为子节点 `DropIcon`；图标与动画按正式版 `children.sort`（V8 短数组＝稳定的二分插入排序，动画无 intY 得 NaN 视为「不小于」）排定绘制与更新顺序；`_icons` 同法排序定 wait（原先用 Godot 不稳定排序，intY 相同时 wait 可能错配）。
  - 淡出到 0 后照正式版继续弹跳/淡出计算（Sprite_Base.update 每帧把 visible 设回 true），纵向缩放一直变大。
  - 不复现：正式版首次载入动画图的 2～5 帧异步加载等待（Godot 已预载，动画从第一帧播）。
- ui_reference：战斗工具栏加「dh 掉落逐帧读数」与 `__dhRef.run/pump`（逐帧记录 SpriteEnemyTrP 子节点、屏幕闪光、转色相前后像素；窗格不在前台时手动推帧）。读数存 `tests/fixtures/drop_dh_oracle.json`（A：三件都带 dh、intY 相同；B：混一件无 dh、intY 各异）。
- 验证（标准级＋逐帧读数）：新测试 `tests/xiyou_drop_dh` 15 项（无头 12 项）：A、B 各 240 帧逐帧与正式版一致（子节点顺序、图标 x/y/缩放/不透明度、动画 x/y/剩余时长/帧序、闪光不透明度）；转色相 144 个取样点源像素差 ≤1、算法结果差 ≤1；窗口模式实画着色器 16 点差 ≤2；dh 动画只用 flashScope 0/2 的数据守卫。截图对照：正式 `04_验证/本地结果/原版参照/dh_drop_reference_A_f6.png` 与 Godot `04_验证/本地结果/dh_drop/dh_drop_godot_A_f6.png`（同一帧，光芒形状/角度/位置/满屏色调一致；Godot 截图直接调倒下钩子，敌人图与名字未淡出，属夹具差异）。原有 `xiyou_drop_record` 26 项通过。检查.sh（worktree，合并 main 后）全部通过。
- 提交：cb66a59、57890b5（及合并 main、交付单提交）
- 未完成／已知问题：flashScope 1（目标闪光）、3（隐藏目标）没有实现（dh 动画不用，测试守着）；技能动画用的 `MVAnimation` 本身仍没有色相、闪光，且比正式版早一帧移除（不在本车道独占文件，见交接板建议）。

## 交接板

- 下一步（建议加进第 4 或第 5 项）：战斗技能动画 `MVAnimation`（mv_animation.gd）补 animation1Hue/2Hue 转色相、flashScope 1/2/3（目标闪光、屏幕闪光、隐藏）与移除时机（_duration 到 0 的下一帧），可直接复用 `XDropPopup.HUE_SHADER`／`DhAnimation` 的写法；改后要回看用到技能动画的测试。
- 用户试玩说明：开着「掉落动画」时，紫装／粉装等带光效的掉落图标，光芒颜色与正式版一致（以前全是原图颜色），掉落瞬间有一下满屏闪色。
- 需要用户决定：无

## 进度账

- 战斗规则与战斗画面：58% 不变（掉落动画的细节补齐，不单独计分）。

## 本分支提交

- cb66a59 WIP: 图标 dh 闪光正式版读数夹具（battle_ref __dhRef）与参照数据
- 57890b5 图标 dh 闪光：掉落图标动画按 Sprite_Animation 逐帧，对照正式版两组 240 帧读数

## 检查

- 合并 main（ad2bd98）后 `检查.sh` 全部通过（exit 0）。

可合并
