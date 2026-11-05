# 交付：cc/rules-portrait1

- 车道／工作者：C 规则／rules 线程（cc，派单第七批 AR2）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·rules·未经审查】角色形象、立绘核对：图鉴立绘、换装卡战斗图、奔跑姿势、图名偏移（dev.待定）

按派单把切片里 161 名角色（数据库 1～178 号有名字的）在原版和重制里取图的地方逐处对了一遍。取错图、缺图都按 bug 修，不占 O 号。

**怎么对的**
- 图片文件：用脚本对比 178 名角色的脸图、行走图、战斗图和 `<sv:>` 逐帧图，看原版和重制导出的文件是否一致（md5）。结果全部一致，只有两类例外，都不用改：
  - 162 诛仙有三张图（小诛仙、guanxi7_1 (1)、guanxi7_1），原版存的是 JPEG／WebP，后缀却是 .png，转换器有意转成真 PNG。
  - 173 饿狼、174 云裳的 `SVzs1:1` 动作只用 1 帧，第 2、3 帧本来就不用，所以没导出。
- 取图的地方：原版里所有改角色脸图、战斗图、行走图的插件和运行时都过了一遍，对照重制各页面读的字段。菜单、状态页、技能页、装备页、物品页、队伍页、存档页、对话框读的都是 `data()`（含 322 改过的图）。战斗图走 `XAppearance`，换装卡、渡鸦形态、饿狼形态、小猫剑圣都已在里面。状态页立绘（JAH_StatusMenuCore `<Portrait:>`）数据里一个都没用，所以这个游戏没有单独的立绘图；图鉴、进阶、加点页画的就是战斗图本身。

**修的**
1. **人物图鉴立绘（167 号以后）**（`ui/actor_book.gd`）
   - 原版：Codex_MiraRavenMultiFrame 和饿狼运行时会包一层图鉴。168 米拉、174 云裳、175 谷雨、176 屠苏、177 璇（谷雨、屠苏、璇要求数据库战斗图没被改过）换成逐帧图第 1 个动作第 0 帧整张。173 饿狼按进阶阶段画 Codex_Garou_QHuman 或 QCosmic，竖向带呼吸。167 号以后有 CodexSV 档的图都缩到可见高 72（宽不超 129），脚底锚在可见范围底边中点。
   - 重制原来：168、173～177 干脆不画；167、169～172、178 按原尺寸画在中心。
   - 现在照原版画。参照 actor_book_oracle 的图名 179 个全部对上；原来豁免的 108、143、144、145、157、170、171 现在切片都导出了，取消豁免。截图看过 167、168、173～178。
2. **进阶页云裳立绘**（`ui/actor_advanced.gd`）：云裳运行时第 582 行会在原 update 之后按 CodexSV 档 Yunshang 缩放（约 0.545）。重制原来是 1 倍，画得太大。
3. **换装卡和变身状态的战斗图没导出**（`03_转换工具/xiyou_export.py`）
   - 18 张切片里学得到的换装卡战斗中没有图：恶灵、狼人、假面骑士、小僵尸×2、魅魔、佩恩、狂鲨、圣斗士、白胡子、水龙、亚丝娜、红／黄／白猫猫、小恐龙、香🐧、欣然猫猫、铃兰。变身状态 173、208、277、1031、1205 的 setBattlerImage 也没导出。
   - 转换器原来只写死带了 66、226 两张。现在扫全部状态备注里的 `var battlerName = '…'` 和 `setBattlerImage('…')`，71 处引用全部导出，多了 23 张图。
4. **MOG_CharPoses 奔跑姿势**（`map/mv_character.gd`、`mv_player.gd`、`mv_follower.gd`）：插件参数「角色奔跑-3」＝CXK-lan-qiu。3 号艾坤当玩家或跟随时，跑步就换这张图，停下后保持 3 帧再换回。跟随看的是玩家的保持帧数，角色号照原版取 `$gameParty._actors[位置]`。别的角色没配，跑步照原图。
5. **MOG 图名偏移**（`map/mv_character.gd`）：原版 setCharacterFrames 把图名里的 X数字、Y数字当作行走图偏移，朝右 +X、朝左 −X，竖向 +Y，气泡跟着偏，技能动画不偏。数据里只有 103 波风水门 TZX01、146 苍龙破晓 TZX04、147 天剑 非天 TZX03 带 X，朝左右时各偏 1、4、3 像素。

**没做（拿不准或不值得）**
- 同一处的 S数字（动画加速）：只有楼梯事件 `!fsm_Stairs01` 被误认成 S01（速度 +1）。原版对不走路、不踏步的事件只是更频繁地把花样复位，看不出差别；重制的花样计数写法跟原版不同，照搬反而可能让楼梯花样乱转，所以没做。
- 饿狼图鉴的呼吸用的是图鉴页自己的帧数，不是 Graphics.frameCount，相位不同，幅度一样。
- 渡鸦图鉴原版画的 battlerName 在地图上恒为 Raven_Normal_SV；重制直接写死 167 号用这张。

## 交接板

- 下一步：无新增。
- 用户试玩说明：人物图鉴里米拉、饿狼、云裳、谷雨、屠苏、璇有立绘了，167 号以后的人物大小和原版一样；进阶页云裳不再画得太大；18 张换装卡和几个变身状态战斗中有图了；艾坤在地图上跑步会换成打篮球的图。
- 需要用户决定：无（都是取错图／缺图，照原版修，不占 O 号）。

## 进度账

- 角色行：dev.355 核定写的「角色形象、立绘（待核）」本期核完。CharacterVisual（小猫剑圣）此前已做；图鉴、进阶页立绘和换装卡图补齐了。建议核定时把「角色形象、立绘」从待核改为完成。

## 可优化（流程／工具／效率）

- 已做：`xiyou_portrait1` 加了一条「状态脚本写死的战斗图都要导出」「切片角色脸图、行走图、战斗图都要在」的断言，以后加角色、加换装卡漏图会当场挂。
- 建议：转换器里还有几处写死的图片名单（`extraImages`、`extraSvFolders`），可以照这次的办法改成从数据或插件参数里扫。归哪吒工具车道，预计一小时。

## 验证

- 语法检查通过；`工具回归.py` 7 项全过；`内容覆盖检查.py` 无变化。
- 新专项 `xiyou_portrait1` 15/15：云裳进阶页缩放、奔跑姿势（玩家、跟随、保持 3 帧）、状态写死战斗图 71 处全导出、换装卡 58 张、切片角色三类图都在、图名偏移。
- 本机选测 19 个全部通过（361 秒，`--skip-generated-check`，差异是本分支多导出的 23 张图）：xiyou_actor_advanced、xiyou_actor_book、xiyou_actor_book_review、xiyou_airship_view、xiyou_appearance、xiyou_floor_run、xiyou_flow、xiyou_map_balloon、xiyou_map_hotkeys、xiyou_portrait1、xiyou_event_compare、xiyou_costumes、xiyou_costume_battle、xiyou_change_clothes、xiyou_determinism、xiyou_state_effects、xiyou_yunshang_ui、xiyou_floor16_dungeon、xiyou_status_power_panel。
- 截图（窗口模式 `xiyou_actor_book -- --out=`）看过 167、168、171、173～178 的图鉴立绘，大小与脚底位置正常。
- 合了 main（e6a706b1，含 fix6 收尾、equip1、mac1）。新提交没碰转换器和本车道的文件，没重跑。
- 没跑的：`选测.py main --list` 共 140 个场景，主要是转换器改动带出来的 xiyou_rules* 段和楼层专项，请合并时 `--affected`。转换器只多导出图片，不改数据库和事件。没开云端。

## 待交叉核查

- `ui/actor_book.gd`（`sprite_spec`／`sprite_rect`）、`ui/actor_advanced.gd`（云裳缩放）、`map/mv_character.gd`、`mv_player.gd`、`mv_follower.gd`（姿势、偏移）、转换器 `xiyou_export.py`（状态战斗图导出）。

## 本分支提交

- 53397036、6f698dea、aaee2655、477e0a7c、f1587678、bb7b42b3、d0b76b8c（WIP 各步），本提交收尾
