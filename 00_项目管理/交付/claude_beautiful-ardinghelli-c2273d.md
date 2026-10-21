# 交付：claude/beautiful-ardinghelli-c2273d

- 车道／工作者：C 规则·机制／八戒（Claude，八戒_35）
- 状态：可合并

## 变更记录草稿

## 2026-10-21 【Claude·八戒·未经Codex检验】法宝每级成长进战斗能力值（dev.待定）

- 做了什么：照 CP_MagicWeapon 的 `Game_Actor.paramPlus`，角色每件法宝（备注 `<Magic Weapon>`）在装备属性上再加「法宝等级 × 每级成长」。
  - `XActor.param_plus` 加 `magic_param`：成长照原版在载入时从**数据库原件**备注 `<mhp／mmp／atk… Param +N per Level>` 解析一次（实例复制原件的 `paramPlusPerLevel`，词缀合并改备注也不影响），按基础编号缓存；等级取 `XEquipmentView.level`（实例 `level`，缺省 `<Init Level>`，再缺省插件参数 1）。不受 `passiveWPNM／ARMM` 放大（原版在 YEP 链外另加）。
  - 最大生命 ×1.2 是赤染樱自带的特性 21，Godot 原本就乘在 (基础+装备) 上，加了法宝成长后一起乘，不用另做。
  - 「伤害成长 growth」不是法宝机制：它是五乘区成长修正，用户 2026-10-12 定不移植，`xiyou_rules` 一直按参照值 ÷ growth 比较，所以不用做。元素增幅 `<Element Amplify n: +150%>` 已由装备 YEP 字段进伤害。
- 参照：新探针 `mv_oracle/magic_weapon_probe.cjs`（只写 `.sandbox/magic_weapon.json`，已登记进 `同步正式西游.py` 与 `oracle_additions.py`）：八重樱 92 入队自带赤染樱（armor 4518）在法宝 1／7／40 级；诛仙剑 123（各项成长不同）、落芸之力 121（无专属）、带土的面具 1906（头部法宝）装上后改等级；另一件新生成的赤染樱。共 5 例 10 行，记每级成长、paramPlus 与能力值。武器类法宝 73～75 都带 `<Custom Parameters>` 读变量（参照里是 NaN，Godot 未做），没选。
- 验证：合 main 后在工作树跑 `同步正式西游.py --accept-additions`（测量不变，留指纹）与 `检查.sh --oracle` 全部通过，无偶发。
- 测试：新测试 `tests/xiyou_magic_weapon` 逐行比对 43 项全过；去掉 `magic_param` 时 20 项失败（确认测得到）。
- 没做（另登记）：法宝升级与经验（打怪得经验、升级效果 `<Magic Weapon LevelUp Effect>`、`<Equip LevelUp Trait …>` 升级加特性）、按等级学技能（CP_X_MagicWeaponLearnSkill），渡鸦法宝的运行时成长（Codex_Raven 直接写 `paramPlusPerLevel`），武器类法宝的 `<Custom Parameters>`。眼下 Godot 法宝都停在初始等级，所以只有 1 级的成长会实际出现。
- 可用范围：法宝成长进能力值，**battleReady** 不变；八重樱 92 仍未进切片（见交接板）。

## 交接板

- 下一步（新增）：八重樱 92 回切片——悟空_28 合并后由总装另派扩角色车道：`xiyou_slice.json` 的 `actors` 加回 92，跑 `slice_probe`／`actor_passive_probe`、`xiyou_rules*`、`xiyou_wtype`、`xiyou_actor_p0`（第五批招募表补 92 的「召唤八重樱」入口）。本分支已让她的初始法宝赤染樱的能力值对上参照（`xiyou_magic_weapon` 的 `yae_setup_init` 行）；我没能在本分支试加 92（切片归悟空），伤害行要在那时才真正对照。
- 下一步（新增，可排后）：法宝升级与经验、按等级学技能（CP_X_MagicWeaponLearnSkill）、渡鸦法宝成长。
- 用户试玩说明：装着法宝的角色，能力值会多出法宝的每级成长（1 级时就有，比如赤染樱各项 +13）；法宝还不能升级。
- 需要用户决定：无

## 进度账

- 无变化（法宝成长只是战斗数值链里的一小块，八重樱未进切片）

## 本分支提交

- 559bc5d 法宝每级成长：mv_oracle 探针 magic_weapon_probe（八重樱赤染樱等 5 例）
- 3a0cdbe 法宝每级成长：XActor.param_plus 加法宝 等级×每级成长，新测试 xiyou_magic_weapon
