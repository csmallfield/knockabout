extends Node
## Puppet atlas + crowd budget.
##
## At boot this bakes one MotionCutoutAtlas holding the hero (front, back,
## side, and the side drawing mirrored for facing left), the sword, a blob
## shadow, and a recoloured copy of the hero for every MobProfile in the
## Registry (scarf removed, so the hero stays the only one wearing it). One
## texture and one material for everything: the whole crowd can batch.
##
## Each frame it also caches what every puppet's LOD check needs (the camera
## rect, the player's position, the frame number), so a mob decides whether
## to re-pose with a few comparisons instead of its own tree queries.

const ART := "res://art/"
const VIEWS := {
	&"front": ["hero_front.svg", MotionCutoutRig2D.EITHER, false],
	&"back": ["hero_back.svg", MotionCutoutRig2D.EITHER, false],
	&"side": ["hero_side.svg", MotionCutoutRig2D.RIGHT, false],
	&"side_left": ["hero_side.svg", MotionCutoutRig2D.LEFT, true],
}
## The feet, in SVG units (the rig origin), and the drawing's full height.
const ORIGIN := Vector2(110, 318)
const ART_HEIGHT := 318.0
## Baked pixels per screen pixel. The game draws at 960x540 and shows at
## 1080p with canvas_items stretch, so 2x keeps the puppets sharp.
const BAKE := 2.0
const OUTLINE_PX := 1.4 * BAKE
## Colour families in the hero drawing, recoloured separately for mobs.
const SKIN := ["f2bf96", "f7cfa6", "e2ad85", "f3998a"]
const HAIR := ["8a3f2a", "a14b30", "7a3624"]
const CLOTH := ["3f8f5c", "4fa86c", "367a4f"]
const HIDE_ON_MOBS := ["scarf", "scarf_knot"]

var atlas: MotionCutoutAtlas
## Hero height in screen px (the player's body radius × this).
var hero_height_per_radius := 3.4

# --- per-frame crowd context (read by MobPuppet) ---
var frame := 0
var view_rect := Rect2()          # world-space rect the camera shows, grown by a margin
var player_pos := Vector2.INF
var crowd := 0                    # puppets alive (last frame)
var _crowd_counting := 0

func _ready() -> void:
	process_priority = -100       # before every entity
	_bake()

func _process(_delta: float) -> void:
	frame = Engine.get_process_frames()
	crowd = _crowd_counting
	_crowd_counting = 0
	var vp := get_viewport()
	var inv := vp.get_canvas_transform().affine_inverse()
	view_rect = (inv * Rect2(Vector2.ZERO, vp.get_visible_rect().size)).abs().grow(48.0)
	var p := get_tree().get_first_node_in_group("player") as Node2D
	player_pos = p.global_position if p else Vector2.INF

## Called by every live puppet once per frame (crowd size for the LOD).
func count_me() -> void:
	_crowd_counting += 1

## Atlas key for a view of the hero ("hero") or a mob id.
func key(who: String, view: StringName) -> StringName:
	return StringName(who + "/" + String(view))

## A rig for the hero or a mob id, every view added, scaled to `height` px.
func make_rig(who: String, height: float) -> MotionCutoutRig2D:
	var rig := MotionCutoutRig2D.new(atlas)
	for v: StringName in VIEWS:
		rig.add_view(v, key(who, v), VIEWS[v][1])
	var baked_h: float = atlas.views[key(who, &"front")].scale * ART_HEIGHT
	rig.display_scale = height / baked_h
	return rig

## A Sprite2D showing an atlas card (the shadow), sharing the atlas material.
func card_sprite(card: StringName, height: float) -> Sprite2D:
	var L: Dictionary = atlas.views[card].layers[0]
	var s := Sprite2D.new()
	s.texture = atlas.texture
	s.material = MotionCutoutAtlas.material()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.region_enabled = true
	s.region_rect = L.region
	s.centered = false
	s.offset = L.offset
	var baked_h: float = (L.region as Rect2).size.y
	s.scale = Vector2.ONE * (height / baked_h)
	return s

# ------------------------------------------------------------------ baking

func _bake() -> void:
	var t0 := Time.get_ticks_usec()
	atlas = MotionCutoutAtlas.new()
	var data := {}
	for v: StringName in VIEWS:
		var d := MotionSvgData.load_any(ART + VIEWS[v][0])
		data[v] = d.mirrored(ORIGIN.x) if VIEWS[v][2] else d
	# The hero at its size (player body radius 10 unless the profile says otherwise).
	var hero_r := 10.0
	var pp := load("res://resources/profiles/player.tres") as PlayerProfile
	if pp:
		hero_r = pp.body_radius
	var hero_scale := hero_r * hero_height_per_radius * BAKE / ART_HEIGHT
	for v: StringName in VIEWS:
		atlas.add_view(key("hero", v), data[v], hero_scale, _opts())
	atlas.add_card(&"sword", MotionSvgData.load_any(ART + "sword.svg"), hero_scale, Vector2(20, 136), {outline = OUTLINE_PX})
	atlas.add_card(&"shadow", MotionSvgData.load_any(ART + "shadow.svg"), 1.0, Vector2(50, 20), {outline = 0.0})
	atlas.add_card(&"marker", MotionSvgData.load_any(ART + "marker.svg"), 1.0, Vector2(50, 20), {outline = 0.0})
	# Every mob profile: the hero, recoloured, at its own size.
	for id: String in Registry.ids():
		var prof := Registry.get_profile(id) as MobProfile
		if prof == null:
			continue
		var s := prof.radius * prof.puppet_height * BAKE / ART_HEIGHT
		var o := _opts()
		o.recolor = {}
		for v: StringName in VIEWS:
			(o.recolor as Dictionary).merge(_mob_colours(data[v], prof))
		o.hide = HIDE_ON_MOBS
		for v: StringName in VIEWS:
			atlas.add_view(key(id, v), data[v], s, o)
	atlas.bake()
	print("Puppets: baked %d views in %.0f ms, atlas %s" % [atlas.views.size(), (Time.get_ticks_usec() - t0) / 1000.0, atlas.texture.get_size()])

func _opts() -> Dictionary:
	return {origin = ORIGIN, outline = OUTLINE_PX, ink = Color("#1b1622")}

## Skin to the mob's colour, hair darker, clothes the muted complement, so a
## goblin never reads as the green-tunic hero. Profile overrides win.
static func _mob_colours(d: MotionSvgData, p: MobProfile) -> Dictionary:
	var c := p.color
	var skin := p.puppet_skin if p.puppet_skin.a > 0.0 else c.lightened(0.15)
	var hair := p.puppet_hair if p.puppet_hair.a > 0.0 else c.darkened(0.55)
	var cloth := p.puppet_cloth if p.puppet_cloth.a > 0.0 \
		else Color.from_hsv(fposmod(c.h + 0.5, 1.0), 0.38, 0.5)
	var m := MotionCutoutAtlas.hue_map(d, Color("#f7cfa6"), skin, [], 1.0, PackedStringArray(SKIN))
	m.merge(MotionCutoutAtlas.hue_map(d, Color("#a14b30"), hair, [], 1.0, PackedStringArray(HAIR)))
	m.merge(MotionCutoutAtlas.hue_map(d, Color("#4fa86c"), cloth, [], 1.0, PackedStringArray(CLOTH)))
	return m
