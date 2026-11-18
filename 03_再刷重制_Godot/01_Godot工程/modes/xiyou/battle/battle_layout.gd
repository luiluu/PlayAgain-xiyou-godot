class_name XBattleLayout
extends RefCounted
## 【cc·天启篇】T126 战斗站位撑开（Kyo 2026-11-17「现在界面可视范围很大。boss 和角色站位再优化一下」）：
## 原版站位（敌群编辑器坐标、我方阵型 XPartyFormation）整体挤在画面中间一小块（敌人 x 94～430、我方 x 669～819），
## 新界面 HUD 收到四周后中部大片空着。这里在原版坐标之上再做一次「撑开＋放大」，首领战与小怪战各一套（Kyo 11-17 挑定：
## 首领战用出样 A 版、小怪战用 B 版；首领退到左边 Kyo 圈的位置；我方集体往右后退，拉开与敌人的距离）：
## - 我方脚底：以阵型原版中心 ACTOR_SRC 为基准，按 actor_spread 拉开后移到 actor_center；身体放大 actor_mul。
## - 敌群：整群外框按 enemy_spread 拉开、但收在 enemy_rect（脚底范围）里，外框中心对 enemy_rect 中心（8 只怨念之魂那种本来就散的不再拉）。
## - 敌人图大小差很多（嘤嘤怪、Q 版首领 40～60 高，狼、沉沦魔原图就 100～200 高）：放大到 enemy_mul 但显示高不超过 enemy_cap，
##   已经超过的不缩小（照原版大小）。
## - 首领战（敌群只有一名成员）：首领不照原版坐标，站到 solo 点，倍数与封顶换成 solo_mul／solo_cap。
## 只改站位（home）与身体缩放，技能动画、受击、伤害数字都跟着精灵位置与高度走（XBattlerSprite.width／height 已含放大）；
## 行动序列里按像素写的位移距离（冲到目标前方多少像素）没跟着放大。
## 原版竖排（设置页「战斗站位」选原版竖排）不撑开、不放大我方，只撑开敌人。
## 新界面（XUiSkin.on()）开着才撑开放大：西游档、发行包、设置页选原版界面时照原版站位与大小（小A 核查 R2：旧侧栏、旧指令窗、O-473 阵型都按原版坐标留位）。
## 回退：ENABLED＝false 回到原版站位与大小。
##
## T174 我方统一大小（Kyo 2026-11-18：「站位不同所有角色大小要一致。小怪战首领战大小也要一致。不允许乱乘倍数。
## 大小定在首领战的档位1.0的里德和狗逍遥大小」＝T173 t173_88_A_1.0：旧角色 0.75×1.6×4/3＝1.6 倍，64 格屏上 102 高）：
## 我方所有角色、前后排、小怪战与首领战，身体都是同一个倍数 ACTOR_SIZE（原图一个像素画成 ACTOR_SIZE 个屏幕像素）。
## 不再按小怪战／首领战（actor_mul 1.9／1.6）、新旧角色（167 号起的归一档 profile 缩放）各乘各的：同样大的原图屏上一样大。
## 装备／状态的 SvPngFd 放大（整数）和外观 scale 照旧乘在上面（那是玩法效果，不是站位倍数）。
## Kyo 11-18 01:18 定 A 版 1.6（B 版整数 2 候选已删）。
## D196 预留（Kyo 11-18：新角色以后按 128 格画、人高约 100、显示 1 倍）：倍数按图的格子大小算——MV 侧视图格子＝图宽÷9×图高÷6，
## 格高 ≥ NATIVE_CELL（128）的画成 1 倍（原图像素＝屏幕像素），其余（64 格旧图）ACTOR_SIZE；逐帧图、单图、场景外观照 ACTOR_SIZE。
## 已有大格旧图也按 1 倍，屏上身高正好落在约 100：奈叶 128 格 98、小铃兰 256 格 102、流萤 128 格 116（照 1.6 会是 157／163／186）。
## 哈基米底图是 128 格但实际画逐帧图（CatSwordSaint_v3），不算大格，照 ACTOR_SIZE（115 高，同 1d9694d0e）。
## 逐帧图（167 号起归一档）只缩不放：倍数＝ACTOR_SIZE×min(1, 归一缩放)，渡鸦神话、米拉黑龙等大画布形态缩到约 115 高（XBattlerSprite._prof_scale，小A 核 P1-1）。
## 回退：ACTOR_SIZE＝0 回到 T126（旧角色 1.425／1.2、新角色归一 ×1.9／×1.6）。原版竖排、旧界面、ENABLED＝false 照旧不放大。
##
## T188 屏幕身高按 99 像素逐角色算倍数（Kyo 11-18 01:19「要定的其实是这个99像素大小，而不是倍数」，公共规矩附则 E）：
## 统一 1.6 倍下各人原图身高不同，流萤 116、屠苏／璇／哈基米 115、大画布逐帧形态约 115、云裳 96、五条悟 94。
## 改成每张图按原图待机帧可见身高算自己的倍数：倍数＝TARGET_H ÷ 可见高，整张图（同一套帧）同一个倍数；
## T174 的倍数（ACTOR_SIZE／大格 1 倍／逐帧只缩不放）算出来已在 TARGET_RANGE（98～102）里的不动（狗逍遥、里德、谷雨、奈叶、小铃兰等）。
## 可见高：量这张图待机动作各帧里最高那帧（idle_height，不透明度 ≥ 12）；167 号起的逐帧图里不是待机那套图的帧（别的动作另一套画布）
## 按归一档（72÷归一缩放）；璇、屠苏绑定形态（悬浮武具、透明形态，不是人身）带 targetHeight 的照归一档按 72 基准等比，跟人形的比例不变。
## 装备／状态的 SvPngFd 放大和外观 scale 照旧乘在上面。变身形态（渡鸦神话、米拉黑龙）也按 99（附则 E）。
## 回退（O-579）：TARGET_H＝0 回到 T174 统一倍数（ACTOR_SIZE 等三个开关照旧）。

static var ENABLED := true
## T174 我方统一身体倍数（见上；0＝回退到 T126 分档小数倍）
static var ACTOR_SIZE := 1.6
## T174／D196：格高到这个数的侧视图画成 1 倍（见上）；回退：设成很大（如 100000）＝全按 ACTOR_SIZE
static var NATIVE_CELL := 128.0
## T174 胜利镜头对准我方：原版镜头点 (700,460) 放大 2 倍是按原版站位（我方 x 669～819）定的，撑开后后排在画面外。
## 开着（且站位撑开生效）时镜头点＝我方身体外框中心，放大倍数＝原版倍数与「整队装得下」取小（不小于 1）；false＝照原版定点
static var VICTORY_FOCUS := true
## T188 我方待机屏幕身高（见上）；0＝回退到 T174 统一倍数
static var TARGET_H := 99.0
## T188：T174 倍数下屏幕身高已落在这个范围里的不改倍数
const TARGET_RANGE := Vector2(98.0, 102.0)
## T194（D204 B）：大型变身（米拉黑龙、渡鸦神话）单独的屏幕身高，默认＝99（跟 TARGET_H 一样，行为不变）。
## Kyo 从样张里挑定后改这个数；样张档位 99／115／130／150／170。TARGET_H＝0 时不起作用（回到 T174）
static var BIG_FORM_H := 99.0
## 算 BIG_FORM_H 的外观键片段
const BIG_FORM_KEYS := ["RavenMythic", "MiraDragon"]

## 我方两排错开 4 人点位 (669..819, 280..580) 的中心（原版坐标、1280×720 画面）
const ACTOR_SRC := Vector2(744.0, 430.0)

## 参数（脚底坐标、1280×720）：
## HUD 占位：顶部首领血弧＋名字＋状态胶囊 y≤215（x 350～930）；右上队伍栏 x≥975、y≤250；左下行动条 y≥610（x≤560）。
## 我方 4 人两排：首领战 前排 x 822、后排 x 1017，小怪战 前排 x 811、后排 x 1029；脚底 y 330～600（上排在队伍栏下面）。
## 首领点 (215, 470)：Kyo 在首领战截图上圈的地面（800×450 图上约 (132, 283)，合 1280×720 的 (211, 453)），脚底略往下压一点站在圈里。
## 敌人脚底右边到 540 左右（狼一类朝右的图身体往右伸 100 多）。
const BOSS := {"actor_mul": 1.6, "actor_center": Vector2(920, 465), "actor_spread": Vector2(1.3, 0.9),
	"solo_mul": 2.2, "solo_cap": 260.0, "solo": Vector2(215, 470)}
const MOB := {"actor_mul": 1.9, "actor_center": Vector2(920, 465), "actor_spread": Vector2(1.45, 0.9),
	"enemy_mul": 1.8, "enemy_cap": 170.0, "enemy_rect": Rect2(120, 335, 420, 270), "enemy_spread": Vector2(1.5, 1.5),
	"size_shift": Vector2(15, 0)}
## T174：统一大小开着时我方整体再挪 size_shift（小怪战人变大往左伸，跟狼一类朝右的敌人拉开；首领战首领在最左，不挪）


## solo＝本场敌群只有一名成员（首领战）
static func spec(solo: bool) -> Dictionary:
	if not ENABLED or not XUiSkin.on():
		return {}
	return BOSS if solo else MOB


## 原版竖排不放大我方（同一列上下间隔按 72 高留的，放大就叠在一起）
## T174 统一大小开着时＝ACTOR_SIZE ÷ 旧式缩放 0.75（旧式身体正好 ACTOR_SIZE 倍；选择光标高度也按它算）
static func actor_mul(solo: bool) -> float:
	if XPartyFormation.current() == XPartyFormation.COLUMN:
		return 1.0
	var size := actor_size(solo)
	if size > 0.0:
		return size / XBattleScene.ACTOR_SCALE
	return float(spec(solo).get("actor_mul", 1.0))


## T174：我方身体的统一倍数；0＝不统一（ACTOR_SIZE＝0、旧界面、原版竖排、ENABLED＝false）。solo 只为判断开没开，两种战斗同一个数
static func actor_size(solo: bool) -> float:
	if ACTOR_SIZE <= 0.0 or spec(solo).is_empty() or XPartyFormation.current() == XPartyFormation.COLUMN:
		return 0.0
	return ACTOR_SIZE


## T174／D196：这张外观实际画的倍数。size＝actor_size()（0＝不统一，原样返回 0）；格高 ≥ NATIVE_CELL 的侧视图 1 倍，其余 size
static func sheet_size(size: float, look: XAppearance) -> float:
	if size <= 0.0:
		return 0.0
	if look != null and look.sideview and look.cell.y >= NATIVE_CELL and (look.frame("walk", 0).get("rect", Rect2()) as Rect2).has_area():
		return 1.0  # 帧真从这张 9×6 图切（哈基米底图 128 格、实际画逐帧图，不算）
	return size


## T188：按原图待机可见高 src_h 定倍数。base＝T174 算出的倍数（0＝没开统一大小，原样返回）；
## base×src_h（四舍五入到整像素）已在 TARGET_RANGE 里不动，否则 TARGET_H÷src_h；TARGET_H＝0 或量不出可见高时照 base
static func fit_height(base: float, src_h: float, big_form := false) -> float:
	if base <= 0.0 or TARGET_H <= 0.0 or src_h <= 0.0:
		return base
	if big_form and not is_equal_approx(BIG_FORM_H, TARGET_H):
		return BIG_FORM_H / src_h
	var h := roundf(base * src_h)  # 按整像素判：64 高满格的 1.6 倍 102.4 算 102（里德、狗逍遥这档不动）
	if h >= TARGET_RANGE.x and h <= TARGET_RANGE.y:
		return base
	return TARGET_H / src_h


## T188：外观待机动作（MV 侧视图「走路」那行 3 帧、逐帧图的待机各帧）里最高那帧的可见高（原图像素，不透明度 ≥ 12，同 XAppearance._infer）；
## 量不出 0。按贴图＋格子记一次。不用归一档表里的可见高：表是原版旧图的数，换过新图的（云裳 v9 实际 52、表里 62）对不上
static var _idle_h := {}


## T189：planted＝true（谷雨、小猫剑圣等停在 wait 第 0 帧的角色）只量 wait 第 0 帧，实际站的就是那一帧
static func idle_height(look: XAppearance, planted := false) -> float:
	if look == null:
		return 0.0
	if planted:
		return frame_height(look.frame("wait", 0))
	var h := 0.0
	for i in range(maxi(look.frame_count("walk"), 1)):
		h = maxf(h, frame_height(look.frame("walk", i)))
	return h


static func frame_height(f: Dictionary) -> float:
	var t: Texture2D = f.get("tex")
	if t == null:
		return 0.0
	var r: Rect2 = f.get("rect", Rect2())
	var key := "%s#%s" % [t.resource_path if t.resource_path != "" else str(t.get_instance_id()), r]
	if _idle_h.has(key):
		return _idle_h[key]
	var h := 0.0
	var img := t.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var area := (Rect2i(r) if r.has_area() else Rect2i(Vector2i.ZERO, img.get_size())).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var top := area.end.y
		var btm := area.position.y
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				if img.get_pixel(x, y).a8 >= 12:
					top = mini(top, y)
					btm = maxi(btm, y + 1)
					break
		h = float(btm - top) if btm > top else 0.0
	_idle_h[key] = h
	return h


## 敌人放大倍数：h＝原版大小时的显示高；放大后不超过封顶，原本就超过的保持 1 倍
static func enemy_factor(h: float, solo: bool) -> float:
	var s := spec(solo)
	if s.is_empty() or h <= 0.0:
		return 1.0
	var mul := float(s.solo_mul if solo else s.enemy_mul)
	var cap := float(s.solo_cap if solo else s.enemy_cap)
	return clampf(cap / h, 1.0, mul)


## 敌群撑开的变换：points＝全体成员原版脚底（含隐藏的，之后出现也按同一变换）。返回 {src, dst, k}，空＝不撑开（首领战不用）
static func enemy_fit(points: Array) -> Dictionary:
	var s := spec(false)
	if s.is_empty() or points.is_empty():
		return {}
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	var r: Rect2 = s.enemy_rect
	var sp: Vector2 = s.enemy_spread
	var k := Vector2(
		minf(sp.x, r.size.x / box.size.x) if box.size.x > 0.0 else sp.x,
		minf(sp.y, r.size.y / box.size.y) if box.size.y > 0.0 else sp.y)
	return {"src": box.get_center(), "dst": r.get_center(), "k": Vector2(maxf(k.x, 1.0), maxf(k.y, 1.0))}


## 敌人脚底：原版坐标 → 撑开后；首领战站首领点
static func enemy_home(p: Vector2, fit: Dictionary, solo: bool) -> Vector2:
	var s := spec(solo)
	if s.is_empty():
		return p
	if solo:
		return s.solo
	if fit.is_empty():
		return p
	return (fit.dst + (p - fit.src) * fit.k).round()


## 我方脚底：阵型点位 → 撑开后（原版竖排不撑开）
static func actor_home(p: Vector2, solo: bool) -> Vector2:
	var s := spec(solo)
	if s.is_empty() or XPartyFormation.current() == XPartyFormation.COLUMN:
		return p
	var shift: Vector2 = s.get("size_shift", Vector2.ZERO) if actor_size(solo) > 0.0 else Vector2.ZERO
	return (s.actor_center + shift + (p - ACTOR_SRC) * s.actor_spread).round()


static func actor_points(points: Array, solo: bool) -> Array:
	return points.map(func(p): return actor_home(p, solo))


## T174 胜利镜头：bodies＝我方各人身体框（画面坐标）；返回 {to＝镜头点, scale}，空＝照原版（开关关、站位撑开不生效、没人）。
## 整队落在 VICTORY_AREA（结算面板左半边之外的右侧，原版站位放大后也在这一块）里、居中，放大倍数＝原版倍数与装得下取小（不小于 1）。
## 镜头点按 XBattleScene 胜利镜头的换算（场景层位置＝画面中心 − 镜头点×放大）反推。
const VICTORY_AREA := Rect2(600, 0, 680, 720)

static func victory_focus(bodies: Array, base_scale: float, solo: bool) -> Dictionary:
	if not VICTORY_FOCUS or spec(solo).is_empty() or XPartyFormation.current() == XPartyFormation.COLUMN or bodies.is_empty():
		return {}
	var box: Rect2 = bodies[0]
	for r in bodies:
		box = box.merge(r)
	box = box.grow(16.0)
	var zoom := maxf(1.0, minf(base_scale, minf(VICTORY_AREA.size.x / box.size.x, VICTORY_AREA.size.y / box.size.y)))
	var to := box.get_center() + (XBattleScene.BOX / 2.0 - VICTORY_AREA.get_center()) / zoom
	return {"to": to, "scale": zoom}
