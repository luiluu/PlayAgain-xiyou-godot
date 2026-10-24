# 交付：claude/bajie-clothes-d34623

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_67）
- 状态：可合并
- 期一：更衣范围与参照；期二：实现（见「追加：期二」）

## 期一：范围清单（Scene_ChangeClothes）

**生效链**
- 入口只有 Map4 EV17「衣橱管理员」两页（全游戏 `SceneManager.push(Scene_ChangeClothes)` 只这两处）。第 0 页无条件：选「查看衣橱」先把换装表 -9～-117 全部解锁再开界面；第 1 页要独立开关 A（「备份」页，条件是开关 295～354 逐项解锁），正常玩不会出现。
- 解锁写法全游戏只有一种：`if(ConfigManager.ChangeClothesLite.indexOf(N) == -1){ ConfigManager.ChangeClothesLite.push(N); }`（62 个文件 324 处，EV17、各层宝箱／特殊事件、公共事件）。
- 插件只改 `Game_CharacterBase.characterName／characterIndex`：**只对 Game_Player 生效**（`Set_OcharacterName || _characterName`；序号是数字才替换），队伍跟随、战斗图、脸图都不变。之后没有插件再改这两个函数（Codex_Raven／installNativeRavenRuntime 改的是 Game_Actor.characterName，不影响玩家）。
- `installCostumePreferencesRuntime`（设置／菜单「角色换装」Scene_CodexCostumes）是**另一个系统**：战斗中换装卡外观的开关（存角色 `_codexCostumeEnabled`），和本界面没有数据往来；重制设置页已列「角色换装」（禁用），不在本期范围。
- XAppearance 不用改：地图上玩家行走图走 `map_scene.refresh_party_sprites → player.set_image`，在那里套上替换形象即可。

**存档**
- 解锁表 `ConfigManager.ChangeClothesLite`（**全局配置**，所有存档共用，同成就 SAchievementS）：换装表项是负数 -i，角色是正的角色 ID。打开界面时把队伍与角色仓库里的角色补进表。原版只在别处调用 `ConfigManager.save()` 时顺带存盘。
- 替换形象 `$gamePlayer.Set_OcharacterName／Set_OcharacterIndex`（随局内存档）；「还原当前形象」设回 null。

**界面（冻结 v0.28 读数，`tests/fixtures/change_clothes_oracle.json`）**
- 分类窗 Window_ChangeClothesC (0,0,426,620)：普通／优秀／精良／史诗／传说／不朽／神话／典藏 8 行，行高 36，开场无光标、不活动。
- 名单窗 Window_ChangeClothesIndex (426,0,426,720)：第 k 档（k=0..5）列 `CodexQuality.actorGrade == k` 且名字非空的数据库角色；**第 6 行「神话」列换装表 95 项**（refresh(0) → actorGrade==−1 没有角色＋换装表），**第 7 行「典藏」是空表**（refresh(8) → actorGrade==7）。已解锁行：行走图上半（同整队名单）＋名字 x=36；未解锁「？？？」x=6。开场显示普通档、无光标。
- 状态窗 Window_ChangeClothesStatus (852,0,428,720)：已解锁时「形象展示」(207−字宽「形象0」, 0)、行走图正面 2 倍（锚点中心，窗内 (213.33,360)，每 20 帧换一格 0→1→2，放在窗口底层）；y=432「获得途径:<GetFs>」或「获得途径:获得伙伴<名字>」；y=468「状态:已解锁／未解锁」。未解锁不画图、不写「形象展示」。名单离开（光标 −1）后约 20 帧内清空（只在画着图时清）。
- 底部指令 Window_ChangeClothesConfirm (0,620,427,100)：「更换」「还原当前形象」，开场活动、选第 1 项。
- 窗口不透明度同其他菜单（opacity 30、back 192，MOG 菜单底图）。

**操作**
- 底部：更换 → 分类窗选第 1 行活动；还原当前形象 → 清替换形象、提示「还原完成」、留在底部；取消 → 关闭。
- 分类：上下移动时名单跟着换档（光标不动）；确定 → 名单选第 1 行、状态窗重画；取消 → 分类去光标、回底部选第 1 项（确定音＋取消音）。
- 名单：已解锁确定 → 替换玩家行走图、提示「替换完成」；未解锁确定 → 提示「未解锁」；都留在名单。取消 → 名单去光标、回分类。
- 提示是 `$.toaster`（重制 XToast）。

**原版缺陷（O-093 候选，做成可回退）**
1. 神话档：v0.15 插入「神话」后入口序号没跟着改，64 个神话角色永远不显示，换装表落在「神话」，「典藏」成了空表。
2. 典藏空表上按确定：`_list[0].id` 抛 TypeError（游戏报错）。
3. 解锁表只在别处存配置时才落盘。

**要动到的文件**：新增 `core/change_clothes.gd`、`ui/change_clothes.gd`、专项 `tests/xiyou_change_clothes.gd`；`xconfig.gd` 新增键 ChangeClothesLite；`xstate.gd` 新增存档键；`mv_script.gd`（解锁写法、开界面）；`map_scene.gd`（`open_change_clothes`、`refresh_party_sprites` 套替换形象）；`xiyou_event_compare.gd` 宿主补 `open_change_clothes`；基线删 m4e17p0／p1；转换器 `xiyou_export.py` 带上换装表 73 张行走图（缺 53 张；悟空本轮独占清单里没有转换器，改动只是新增引用）。

## 变更记录草稿

（期二完成后写）

## 交接板

- 下一步：（期二完成后写）

## 进度账

- （期二完成后写）

## 验证

- 参照：`node review_system_pages.cjs <目录> change_clothes`（新页 change_clothes，12 态，无报错），压成 `tests/fixtures/change_clothes_oracle.json`。

## 本分支提交

- （见 git log）
