# 原版界面参照（浏览器）

用内置浏览器直接运行正式西游 `app.nw` 的网页版，截取原版真实画面，作为 Godot 逐页复现的像素参照。

- `serve.py <app.nw> [截图目录]`：只读服务 127.0.0.1:8766。只允许 GET；拒绝 `save/` 与 `..` 路径段；`js/mac-preload.js` 换成本目录的 `mac-preload-shim.js`（需要 Node 的 Mac 启动脚本在浏览器里无法运行）。唯一的写入是 `POST /__ref_shot/<名字>`（PNG）与 `POST /__ref_json/<名字>`（运行时读数 JSON），只写截图目录。全部响应 `no-store`，同时允许约 250 个并发脚本请求。
- `mac-preload-shim.js`：提供 `nw`、`MacPort` 的空实现，不读写文件；浏览器模式下存档只进该浏览器自己的 localStorage，不碰真实玩家存档（`StorageManager.isLocalMode()` 为 false）。另提供 `__refShot(名字)`（`SceneManager.snap()` 原尺寸 1280×720 PNG）与 `__refErrors`（场景异常）。
- 声音（用户 2026-10-16）：用浏览器跑参照时默认静音——垫片在加载后把 `WebAudio.setMasterVolume` 固定为 0；确实需要听声音时网址加 `?sound=1`。
- 使用：后台运行 `python3 -I serve.py "<app.nw>"`（重制期间 `<app.nw>` 用冻结副本 `03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw`，见该目录 README），浏览器打开 `http://127.0.0.1:8766/index.html`，视口设 1280×720，启动约 30 秒到标题。用页面内 JS 推进剧情/打开场景后调用 `__refShot`。
- 截图默认写到 `04_验证/本地结果/原版参照/`（不入 Git）。不修改正式应用的任何文件。

- `index.html?battle_ref=1`：战斗验收工具栏，提供四人/五人内存夹具（地图 5、敌群 2）、胜利结算与截图；隔离地图剧情并固定随机值，按钮不会同时确认游戏窗口。运行时读数在折叠栏内。另提供伤害数字/技能动画内存开关、四档战斗变速与普通攻击逐帧测量（包含0伤害行动）；读数记录首次应用、日志清空与下次角色输入（可能包含敌方行动）。只测界面，不作为真实开局或战斗规则参照。
  - 工具栏「给角色设种族」（悟空_64，dev.208）：选位次、种族（无／神妖人魔鬼灵蛮）、阶位，记下选择；下次点「战斗夹具」时在 BattleManager.setup 之前照 `race_battle_probe` 的 setRace 设 `_codexRace` 并学种族技能（战斗数据在 startBattle 建，所以开战后改不生效）。「选目标确认」：填技能号，在角色指令窗激活时让当前行动者学会该技能、回满 MP，走指令窗→技能窗→onSkillOk，约 20 帧后读指令窗／技能窗／选敌窗／选我方窗的激活、可见、不透明度、序号、cursorAll、锁定，帮助窗与被选中者，写在工具栏末行与 `window.__selhelpLast`。窗格在后台时用 `__dhRef.pump({until:()=>!!window.__selhelpLast})` 推帧。

- `index.html?map_ref=1`：地图 HUD 内存夹具（教派选择、大厅、一层），停止地图解释器以观察绘制；不加载任何存档。提供截图按钮及 DOM 运行时读数（按钮/枫叶/坐标窗口的位置、字号与绘制调用）。备份操作只进浏览器 localStorage；夹具不作为剧情或战斗规则对照。

- `index.html?difficulty_ref=1`：难度提示定帧夹具。只停止本浏览器内 EnemyNameColorByDifficulty 的三个真实计时器，用按钮调用原回调；提供1～9档、推进30格/消失、快照入战、原尺寸截图与坐标/字体/颜色/绘制次数读数。不加载存档。反复切换夹具先退出旧地图，避免读取异步加载期间的空地图数据。

- 战斗工具栏「掉落与记录对照截图」开启两项偏好，触发第一只敌人的倒下与真实掉落动画并定格，输出 `codex_drop_record_reference.png`；仅测布局。规则参照另见 `mv_oracle/drop_record_probe.cjs`。

- 战斗工具栏「dh 掉落逐帧读数」（页面内 JS：`__dhRef.run({drops:[防具ID…],rand:[…],shotFrame:N,shot:名字})`，再 `await __dhRef.pump()`）：第一只敌人倒下时掉落带 `<dh:N>` 的防具，逐帧记录 SpriteEnemyTrP 的子节点（顺序即绘制先后；图标位置/缩放/不透明度、Sprite_Animation 位置/剩余时长/帧序、屏幕闪光）与动画图转色相前后的像素，到 shotFrame 帧截图。每跑一次先重载页面。内置浏览器窗格不在前台时 requestAnimationFrame 停摆，用 `__dhRef.pump()` 手动推帧。读数存 `01_Godot工程/tests/fixtures/drop_dh_oracle.json`，由 `tests/xiyou_drop_dh` 逐帧对照。

- 战斗技能动画逐帧（页面内 JS：在战斗夹具等到角色指令窗口后 `await __animRef.suite()`；单条用 `__animRef.run({anim:ID,side:'enemy'|'actor',index:0})` 再 `await __animRef.pump()`）：在战斗者精灵上 startAnimation，每帧记 Sprite_Animation 相对目标的位置、剩余时长、帧序、可见格数、目标混合色与显示、屏幕闪光，到移除后 2 帧；动画图先载好再开始。`suite()` 跑动画 3（目标＋屏幕闪光，含四倍速）、14（转色相）、24（隐藏目标，敌人与角色），用 `__refJson('mv_anim_oracle', …)` 写到截图目录（`serve.py` 的 `POST /__ref_json/<名字>`，与截图同样只写截图目录），复制到 `01_Godot工程/tests/fixtures/mv_anim_oracle.json`，由 `tests/xiyou_mv_animation` 逐帧对照。窗格隐藏时先用 `__dhRef.pump({until:…})` 推到标题再开夹具。

- YEP 行动序列逐帧（页面内 JS：在战斗夹具等到角色指令窗口后 `await __seqRef.suite()`；单条用 `__seqRef.run({skill:ID, target:敌人选择窗序号, camera:true|false, anim:true|false})` 再 `await __seqRef.pump()`）：当前行动角色学会该技能、补满 MP/TP，敌人加 100 万生命（打不死）后照指令窗流程出招；每帧 Spriteset_Battle.update 之后记战斗者精灵（位置、移动偏移、朝向、不透明度、浮空/跳跃、动作、帧格、身体锚点）、镜头（场景层位置与缩放、$gameScreen 镜头点）、窗口层位置（HIDE BATTLE HUD）、日志窗等待与排队方法，另记每条序列指令执行的帧，到该角色行动结束。`suite()` 先载好要用的动画图（首次载入的异步等待不比），跑 9 段（`suite(列表, 读数名)` 可只跑几招并另起读数名；`run` 的 `prep(角色, 敌人)` 另设场景，如反击致死；每帧另记敌人 [实际 HP, 血条显示值]），`__refJson('action_sequence_oracle', …)` 写到截图目录，再用 `python3 -I 压缩序列参照.py` 压成 `01_Godot工程/tests/fixtures/action_sequence_oracle.json`，由 `tests/xiyou_sequence_visual` 逐帧对照；另跑的 s131 多段攻击与 s104 反击致死压成 `action_sequence_hp_oracle.json`（`压缩序列参照.py <源> action_sequence_hp_oracle.json`）。窗格隐藏时整段放进不等待的异步函数里跑，再轮询结果。

- 普通攻击动画（双持，页面内 JS：在战斗夹具等到角色指令窗口后 `await __atkAniRef.suite()`）：第一位角色直接设成双持（独立物品武器 2005 鸾凤和鸣剑＋武器 2，不经 canEquip）、单武器、空手，再加敌人出手，对两只敌人调日志窗 `showAttackAnimation` 与 `showActorAtkAniMirror`，包住 `Sprite_Base.startAnimation` 记每个新建动画的目标、动画号、镜像与 `_delay`。`__refJson('attack_animation_oracle', …)` 写到截图目录，复制到 `01_Godot工程/tests/fixtures/attack_animation_oracle.json`，由 `tests/xiyou_sequence_visual` 对照。窗格隐藏时整段放进不等待的异步函数里跑（先 `__dhRef.pump` 推到标题再点夹具），再轮询结果。

- 战斗里的 101 消息窗：战斗夹具到角色指令窗口后 `$gameMessage` 设无头像、背景 0、位置 2，加 `\n<海拉的幻影>很久没有打的这么尽兴了，哈哈哈。`，推到文字全显再 `__refShot('battle_msg_101_formal')`。读数：消息窗 0,548,1280,172，名字框 0,484,298,64（`\c[6]`），角色／队伍指令窗关上（`Scene_Battle.updateStatusWindow`），右侧状态与行动顺序条照常。Godot 对应 `tests/xiyou_battle_ui` 的 `battle_49_message_101`。另三种切片里真有的写法用同一夹具截（`$gameMessage.clear()` 后 setFaceImage／setBackground(0)／setPositionType 再 add，推到文字停住）：带头像 `battle_msg_101_face`（QY touxiang 2，`\n<玉皇大帝>你确实很强，不过到此为止了！`：消息窗同上、名字框 0,484,272,64、正文 newLineX 168）、中间位置 `battle_msg_101_middle`（无头像、位置 1，`天空中的圣雷积攒到了极限`：消息窗 0,274,1280,172、无名字框）、放大字 `battle_msg_101_bigfont`（KH06-2_faces_MV_03 4，`\n<魇脑>\{\{前所未有的兴奋！\}\}\!`：名字框 0,484,220,64）。窗口层里 Window_OTBDisplay 在 Window_Message 之前：消息窗底色压在行动顺序条上、头像盖住条左端。Godot 对应 `battle_49b`～`battle_49d`。

- `index.html?item_marks_ref=1`：一键出售与多货币买入的内存夹具；「多货币买入夹具」打开 2230／4375／732 三件商品并显示窗口几何，「买入数量窗」进入实际最多能买 1 件的数量窗，「买入复核截图」保存当前商店原尺寸画面。金币、变量与物品都只属于新建测试局，不加载玩家存档。

- `index.html?item_list_ref=1`：物品列表一组（NEW 角标、「序号/9,999」、战斗物品窗口）参照。不放工具栏，用页面内 JS 调 `__ilr`：`newGame()` 建四人内存新局（1/8/9/10，不读写存档），`go(场景类)` 切场景并等就绪，`rows(窗口)` 读每行的数据、`$gameSystem._seenItems` 与此刻画面（`newShown` 是否画着 newIcon、`texts` 该行文字的 x／宽／对齐／字号；包装 Bitmap 的 blt/drawText/clearRect/clear 记录），`saveRoundTrip()` 只在内存里做存读档序列化。移光标用 `cursorDown(false)`／`processOk()`，换分类后先等几帧（分类窗在 update 里才 setCategory）。读数存 `01_Godot工程/tests/fixtures/item_list_oracle.json`。

- 伤害弹数纵向锚点（八戒_61）：`python3 popup_anchor_ref.py <app.nw> <输出目录>`（只读，127.0.0.1:8768，沿用 serve.py 守卫，追加 `popup_anchor_ref.js`），打开 `index.html?battle_ref=1&popup_anchor=1`，页面内 `await __popupAnchor.run()`：四人内存夹具上对敌人 0／角色 0 用真实 startDamagePopup／setupDamagePopup 依次弹七种普通伤害／回复组合（间隔 5 帧、最后再推 5 帧），记每个弹数子精灵锚点、根位置与边界，`__refJson("popup_anchor_oracle")`。压缩后存 `01_Godot工程/tests/fixtures/popup_anchor_oracle.json`，由 `tests/xiyou_popup_overlap` 对照。

- 系统页成对截图（八戒_63）：`python3 review_system_pages.py <app.nw> <输出目录>`（只读，127.0.0.1:8769，沿用 serve.py 守卫，追加 `review_system_pages.js`；SIGINT／SIGTERM 收尾时写 `source_after.json` 并核对来源身份），再 `node review_system_pages.cjs <输出目录> [页名…]`：用本机 Google Chrome 无头（临时用户目录、1280×720、静音）逐页 `await __sysRef.run(页)` 建内存新局（1/8/9/10、地图 5、Math.random 固定 0.5、不读写存档），照各 fixture 的 setup 摆状态、走真实原版场景，整页截图（含异化工坊 DOM 叠加层）并写 `<状态>.json`（所有窗口的矩形、开合、不透明度、本帧文字；异化工坊记 DOM 节点矩形与字号）。页：制作 4 态、法宝等级字 3 态（附战力读数）、宠物 3 态、喂养／合成、种族祝福 default-first 前 5 页、怪物图鉴目录与掉落（八戒_64）、修炼底部「修炼」（附 44 空格实测宽）、异化工坊 2 态与配置页，最后是战斗内怪物信息（进了战斗回不到新局，所以放最后）。Godot 同态截图：`tests/xiyou_system_evidence -- --out=<目录>`（制作类别页、法宝三态、宠物底部指令、喂养、合成、种族五页）与 `xiyou_crafting`／`xiyou_pets`／`xiyou_alien_workshop`／`xiyou_alien_config`／`xiyou_enemy_book` 的 `--out`；`battle_42_enemy_book` 取 `xiyou_battle_ui`、`training_bottom` 取 `xiyou_training` 的 `training_2_bottom`。带 `--out=` 运行时设置一律用内存默认值（`XConfig.screenshot_mode`），不读本机开发档的 options.json。读数核对：`python3 -I review_system_pages_compare.py <原版目录> <Godot目录> 01_Godot工程/tests/fixtures <输出.json>`（窗口矩形、种族行文与说明、制作按钮、宠物重造、异化面板、原尺寸 PNG、来源身份）。

- 宿傩领域法阵成对截图（八戒 visual2）：`python3 -I domain_circle_ref.py <app.nw> <输出目录> [Godot 截图目录]`。不起服务：照 `installNativeCharacterVisualRuntime.js` 的 domainCircle 原文用冻结源的 `js/libs/pixi.js` 画（黑底 256×128、推进 30 帧），本机 Chrome 无头 `--screenshot`（静音、临时用户目录）；Godot 一侧 `tests/xiyou_indicator_shot -- --out=<目录>`（非 headless）写 `domain_circle_godot.png`。给了 Godot 目录就比逐像素平均差与红色掩码交并比，写 `domain_circle_compare.json`（11-02 实测平均差 0.216、交并比 0.98，线不抗锯齿时）。
