# 接续：cc/bailong-ravenfx（渡鸦特效余项＋米拉名字与外观）

- 车道／工作者：B 界面／白龙（cc）
- 状态：接续（盘点完成，代码未动；上一个会话上下文到线交接）
- 分支：`cc/bailong-ravenfx`，从 github/main 0d2afe87 切出（派单要等「合并 cc/nezha-fix6（dev.35x）收尾」，切时还没到）。**接手先** `git merge main`（fix6 进来以后），再 `03_再刷重制_Godot/07_开发环境/新建工作树.sh --补齐 <路径>`（切分支时没跑补齐）。
- 派单：`.git/tangseng/派单_第七批_1105.md` AQ 节。

## 盘点表（只读，2026-11-05；原版 = 冻结正式源 app.nw/js，重制 = 01_Godot工程）

原版涉及：`codex/runtime/installNativeRavenRuntime.js`（1135 行）、`installRavenSkillEffectsRuntime.js`（117）、`installNativeRavenMonsterVisual.js`（52）、`plugins/Codex_MiraRavenMultiFrame.js`。数值类的 `installMiraRavenNumberBoostRuntime.js` 不列。

| # | 功能 | 原版位置 | 要点 | 重制 | 确定度 |
|---|---|---|---|---|---|
| 1 | R.Fx 通用特效 ring／slash／harvest／echo | NativeRaven:1097-1113 | 见 raven_fx.gd 头注释 | 已做（raven_fx.gd:111-175） | — |
| 2 | 六个技能的羽毛矢量施放特效 | SkillEffects:5-82 | 10122～10127 各自 life／count／半径／颜色 | 已做（raven_fx.gd:15-130，battle_scene.gd:1732-1755） | — |
| 3 | 施放期间算动画没放完；同技能不叠 slash／ring | SkillEffects:84-86、108-115 | | 已做（battle_scene.gd:1621、1733）；屏蔽支未逐行核，可抽测 | — |
| 4 | 神话形态静态大图 Raven_Mythic_Monster | MonsterVisual:5-47 | 576×384 整张，缩放 0.60，(−20,155)，死亡 (−20,180) α0.35，藏武器 | 没做；米拉同类大图实测被多帧插件盖掉（mira.gd:30-34），渡鸦未实测 | 低：先实机确认 |
| 5 | 神话多帧 SV（UserSV_RavenMythic） | Plugin:120-141；NativeRaven:564-568 | | 已做（appearance.gd:126-143、battler_sprite 悬浮） | — |
| 6 | 普通形态 SV 归一 | Plugin normProfiles | | 已做（appearance.gd:204-207） | — |
| 7 | 受击改播 evade、濒死改播 wait | NativeRaven:573-580 | 167 专用 | 没做（battler_sprite.gd:354、359 通用） | 中：先量多帧图下实际表现 |
| 8 | 地图始终用 $Raven_Normal | NativeRaven:581-586 | | 数据库本身成立 | — |
| 9 | 地图行走动画放慢 ×1.35 取整（队长与跟随者） | NativeRaven:590-598 | animationWait×1.35 | 没做（mv_character.gd／mv_follower.gd 无 167 特判） | **高** |
| 10 | 战斗目标箭头隐藏（167、173 的 Sprite_WindowArrow opacity 0） | NativeRaven:628-636 | | 没做；先核重制有没有这个箭头 | 中 |
| 11 | 法宝图标 Raven_Artifact_Icon（9001） | NativeRaven:57-81 | 小图 blt、大图缩放居中 | 已做（quality_icons.gd:28）；大图路径可抽测 | — |
| 12 | 神话回合清零、战后复原 | NativeRaven:1088-1094 | | 已做 | — |
| 13 | 头像 Raven_Face、昵称「冥河御魂者」 | Actors.json 167 | | 已做 | — |

米拉（actor 168，不是渡鸦形态；人形／黑龙两形态都叫「米拉」，昵称「禁忌黑龙」）：
- 名字：重制与原版一致（installNativeMiraRuntime.js:27-29 的 name() 覆盖返回同一个名字）。`mira.gd:34`「未移植：名字与外观」里「名字」已无差异，注释可改。
- 战斗形态切换、归一框：已做（appearance.gd:126-131、208-209）。
- 黑龙静态大图 BlackDragon_Mira_Enemy：有意不做（mira.gd:30-34，实测被多帧盖掉）。
- **状态页立绘没做**：actor_book.gd:465-470 写明 168 等要换多帧图（原版参照 UserSV_MiraHuman1_0），重制不画。唯一明确可见的差异。
- 站立呼吸 quietIdle（168、172～174：纵向最多约 0.9%、周期 23 帧）：battler_sprite.gd 有通用呼吸，168 参数未核。

## 建议的一期（按确定度）

1. 渡鸦地图行走动画 ×1.35（#9）：mv_character.gd 的行走帧停留，对 167 队长与跟随者包一层；回退开关；专项量帧数。
2. 状态页补米拉多帧立绘（actor_book.gd:465-470）：图与归一框都有。
3. 改正两处过时注释：raven.gd:37-41（RavenSkillEffects 已移植，MonsterVisual 待实测）、mira.gd:34（名字无差异）。
4. 实机（ui_reference 战斗夹具，浏览器静音）确认 #4 渡鸦神话大图是否被多帧盖掉、#7 受击／濒死替换的实际表现、#10 箭头，再决定做不做。

## 本分支提交

- 本接续单（代码未动）
