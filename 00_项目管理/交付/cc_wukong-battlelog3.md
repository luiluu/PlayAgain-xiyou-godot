# 交付：cc/wukong-battlelog3

- 车道／工作者：悟空（cc），角色专属画面遗留第三期
- 基线：总装九派单，从 cc/wukong-battlelog2 末端 768e3515 切出，交付前合了 main（50e7d346）。
- 状态：可合并

## 盘点

| 项 | 原版（冻结 v0.28） | 本期 |
| --- | --- | --- |
| 宿傩完全体外观 | `installNativeSukunaRuntime` 的 `Sprite_Actor.updateBitmap` 包装：进阶 3 时 `_states.push(2643)`（不走 addState），否则 eraseState；状态 2643 备注 `<sv:Codex_Sukuna_QFull>`，由 Mx_SuperSV 按状态选逐帧图。同一文件 update 包装里的 y＝40、藏武器被之后装上的 Codex_MiraRavenMultiFrame `applyVisual` 盖掉 | 做了：`XSukuna.full_look`（取外观键时调用），Mx_SuperSV 状态换图（重制原来没接） |
| Mx_SuperSV 状态换图 | `select`：每个动作先看带 `<sv:>` 的状态（ID 从大到小，不走 Cfdz），缺图看下一个，再退到角色自己、原侧视图；速度读角色的 `<SVspeed>`（状态上的不生效） | 做了：`XAppearance._state_sv`，外观键带 `|st:…` |
| 渡鸦神话形态图 | `Codex_Raven` battlerName 包装：战斗中神话＝`Raven_Mythic_SV`；Codex_MiraRavenMultiFrame 的 MetaProvider 换逐帧图 `UserSV_RavenMythic`（Cfdz 把 18 种动作并到 0／7／10，YCyy 藏影子，速度 10）；applyVisual 浮空 −14＋sin×1.5 | 做了：`XRaven.battler_name`、`XAppearance.sv_form`／`form_meta`，浮空在 `XBattlerSprite` |
| 米拉人形／黑龙、小猫剑圣逐帧图 | 同一个 MetaProvider 链：米拉平时 `UserSV_MiraHuman`、黑龙条件成立 `UserSV_MiraDragon`；小猫剑圣（installNativeCharacterVisualRuntime）`CatSwordSaint_v3` | 顺带做了（同一机制，派单没写，见下） |
| 新增角色站姿归一 | Codex_MiraRavenMultiFrame：角色 ID ≥ 167 按此刻显示的图取档（normProfiles，缺档时量站姿那格），缩放＝min(72／可见高, 129／可见宽)、脚底锚在可见范围底边中点，spriteWidth／Height 按可见范围；逐帧时藏武器；没档的照旧 ×0.75 | 做了：`XAppearance.PROFILES`／`profile`／`_infer`，`XBattlerSprite._show_frame`／`_place_body`。**重制原来所有角色一律 ×0.75**，新增角色（渡鸦、宿傩、饿狼等）比原版小约四成 |
| 饿狼星空外观 | G.sync：形态状态 2644～2650（重制已有）由 Mx_SuperSV 换 `Codex_Garou_QHuman`／`QCosmic`；形态 6 `setBattlerImage`／`setFaceImage('Garou_Cosmic', 0)`，否则 Garou_Human | 做了：状态换图同上；`XGarou._sync_look` 写 looks |
| 渡鸦法宝 4001 | **更正**：本期起初读的是没启用的 `js/plugins/Codex_Raven.js`（plugins.js 里没有它），数值不对。实际生效的是 `js/codex/runtime/installNativeRavenRuntime.js`：每级成长 [35,12,0,20,45,20,45,12]、上限 888，与备注一致，重制已对；装着 4001 时 paramPlus 另加固定 [350,100,0,80,150,80,90,35]，魔攻另加 ⌊阶×50＋魂×(0.02＋阶×0.006)⌋、生命另加 ⌊阶×400＋魂×(0.04＋阶×0.008)⌋ | 没做：固定加成与灵魂加成重制没有，下一期 cc/wukong-raven4 写参照后做 |
| 熟练度上限（变量 8） | 运行时技能的 masteryMaxLevel／天道枷锁变量 8 截断 | **不做**：重制没有熟练度系统（恒 0），没有东西可截 |
| 饿狼神之触媒消息 | 见上期交付单 | 等 Kyo 定，没动 |
| 同插件的零碎画面 | Codex_MiraRavenMultiFrame：quietIdle（168／172／173／174 逐帧时待机不走路、站着时 walk 换 wait）、breathe（逐帧待机纵向 0.9% 呼吸）、partyLayout 按队员最大 spriteHeight 排（渡鸦浮空会把首位往下压）、不在阵型时的 x 偏移、渡鸦神话 damage／dying 走原侧视动作表、图鉴页的多帧立绘 | 没做，记下；图鉴多帧立绘另见 `ui/actor_book.gd` 的注释 |

切片：`xiyou_slice.json` 加 `extraSvFolders`（UserSV_RavenMythic、UserSV_MiraHuman、UserSV_MiraDragon、CatSwordSaint_v3）与 extraImages 三张（Raven_Mythic_SV、Garou_Cosmic 侧视图与头像）；`xiyou_export.py` 给全部状态的 `<sv:>` 带逐帧图（宿傩 2643、饿狼 2644～2650）、`extraSvFolders` 整夹带上。转换器与切片属内容车道文件，本期由悟空改（派单为内容车道）。

## 变更记录草稿

## 2026-11-01 【cc·悟空·未经审查】宿傩完全体、渡鸦神话、饿狼星空等专属战斗外观：状态换图与新增角色站姿归一（dev.待定）

- `core/appearance.gd`：Cfdz 动作映射认数字（原来 JSON 里的 1.0 认不出，映射一直没生效）；Mx_SuperSV 状态换图 `_state_sv`（带 `<sv:>` 的状态 ID 从大到小、每个动作缺图退下一个，速度读角色）；Codex_MiraRavenMultiFrame 的形态 `sv_form`（米拉人形／黑龙、渡鸦神话）与变身标签 `form_meta`，小猫剑圣 `CatSwordSaint_v3`（`sv_provider`）；外观键 `battler_key` 带 `|form:`、`|st:`，`for_look` 照键取图；站姿归一档 `PROFILES`／`profile`／`_infer`（角色 ID ≥ 167）。
- `battle/battler_sprite.gd`：有归一档时缩放＝min(72／可见高, 129／可见宽)、可见范围底边中点落在脚底，宽高按可见范围；逐帧图时藏武器；渡鸦神话浮空；换外观时按 YCyy 藏影子。
- `core/sukuna.gd` `full_look`：进阶 3 时把 2643 塞进状态（原版 updateBitmap 包装）。`core/raven.gd` `battler_name`：战斗中神话＝Raven_Mythic_SV。`core/costumes.gd`：卡图那层里面先过渡鸦。`core/garou.gd` `_sync_look`：形态 6 战斗图与头像 Garou_Cosmic。
- 转换器 `xiyou_export.py`：状态备注的逐帧图、`extraSvFolders`；切片 `xiyou_slice.json` 带上变身逐帧图与三张图。
- 新专项 `tests/xiyou_actor_looks`。

## 验证

- 合 main（50e7d346）后补齐并跑 `同步正式西游.py --accept-additions`：「新增用例，已接受」（新增的都是图），留了产物指纹；`内容覆盖检查.py` new 0／resolved 0，不用更新基线。
- 选测 20 场景（CHECK_JOBS=3）：`xiyou_actor_looks`（新，33 项）、`xiyou_appearance`、`xiyou_costumes`、`xiyou_costume_battle`、`xiyou_sukuna_battle`、`xiyou_raven_battle`、`xiyou_raven_soul`、`xiyou_battle_ui`、`xiyou_battle_log`、`xiyou_battle_events`、`xiyou_sequence_visual`、`xiyou_mv_animation`、`xiyou_review_fixes`、`xiyou_poison_collapse`、`xiyou_garou_battle`、`xiyou_garou_progress`、`xiyou_mira_battle`、`xiyou_cat`、`xiyou_yunshang`、`xiyou_actor_change`。第一轮 19 过，`xiyou_actor_looks` 查出 Cfdz 映射没生效（见下）；修后重跑 `xiyou_actor_looks`／`xiyou_appearance`／`xiyou_costumes` 全过（日志 `04_验证/本地结果/并行测试/20261101_061112_5xpmch9q/`，第一轮 `20261101_055342_3jv1bsmf/`）。无偶发。
- Cfdz 修的是重制自己的错（`_super_sv` 用 `str(x).is_valid_int()` 认 JSON 解析出的浮点 1.0，认不出），不是原版缺陷，不加回退开关；数据库里没有角色／敌人写 Cfdz，只有本期的变身那套用到，所以第一轮其余场景结果不受影响。
- `语法检查.py` 通过。
- 没截图实看：归一后的大小、浮空是按原版公式算的，没和原版并排截图比（ui_reference 战斗夹具只有 1/8/9/10 四人队）。

## 交接板

- 下一步：渡鸦法宝 4001 装备时的固定加成与灵魂加成（已派 cc/wukong-raven4；每级成长与上限重制已对）；饿狼神之触媒消息（等用户定）。「渡鸦遗留」里的神话形态战斗图、「宿傩画面遗留」里的完全体外观 2643、「白龙」条里饿狼的星空外观可以划掉；框架维护约定「目标（未实现）」第一条（状态换图与站姿归一）可改成已实现，5 人站位原来已有。熟练度上限在重制没有熟练度前不用做。
- 用户试玩说明：渡鸦、宿傩、饿狼、米拉等新增角色在战斗里和原版一样大（原来偏小）；宿傩二十指完全体换完全体战斗图；渡鸦开神话后换神话形态逐帧图并浮空；饿狼各形态用对应逐帧图，星空形态战斗图与头像换星空；米拉平时人形逐帧图，解放黑龙换黑龙；小猫剑圣用逐帧图。
- 需要用户决定：饿狼神之触媒消息（上期留下的，仍待定）。

## 进度账

- 专属角色画面遗留：宿傩完全体外观、渡鸦神话形态图、饿狼星空外观完成；新增角色站姿归一完成；渡鸦法宝成长与固定加成未做（要参照）；熟练度上限不适用。

## 可优化（流程／工具／效率）

- 建议：车道从旧提交切出时（本期 768e3515），补齐拷来的转换产物是 main 的，切片少了 main 新加的角色，同步会报「删除」退出 2，只能合 main 再同步一轮（白跑约 35 分钟）。派单从车道末端切时，开工就先 `git merge main` 再补齐，或补齐时提示「产物比切片新」。归哪条车道：哪吒（工具）。

## 本分支提交

- 9a85bbfe WIP：状态换图、变身逐帧图、站姿归一、宿傩 2643、饿狼星空外观、切片带图
- WIP：专项 xiyou_actor_looks
- 合并 main
- Cfdz 映射修正、交付单（本提交）
