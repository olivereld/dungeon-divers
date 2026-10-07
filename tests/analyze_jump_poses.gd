extends SceneTree

## Análisis de poses de salto: aplica cada clip al esqueleto real del Aldeano y mide
## altura de cadera, altura de pies y diferencia angular entre poses en los puntos de corte.

const PlayerScript = preload("res://src/character_test/player_test.gd")
const MODEL_PATH = "res://assets/models/character/Test/Aldeano_rigged_v1.glb"

var _model: Node3D
var _ap: AnimationPlayer
var _skel: Skeleton3D

func _initialize() -> void:
	var scn: PackedScene = load(MODEL_PATH)
	_model = scn.instantiate()
	root.add_child(_model)
	var arm = _model.get_node_or_null("Armature")
	if arm:
		arm.rotation = Vector3.ZERO
	_ap = _model.get_node("AnimationPlayer")
	_skel = _model.find_child("Skeleton3D", true, false)

	var lib: AnimationLibrary = PlayerScript._get_or_create_anim_library()
	if _ap.has_animation_library(""):
		var ex = _ap.get_animation_library("")
		for n in lib.get_animation_list():
			if not ex.has_animation(n):
				ex.add_animation(n, lib.get_animation(n))
	else:
		_ap.add_animation_library("", lib)

	_add_raw("raw_jump", "res://assets/animations/human/human_01_jump_down.fbx")
	_add_raw("raw_stand", "res://assets/animations/human/human_01_stand_up.fbx")

	var clips := ["idle", "walk", "jump_down_takeoff", "jump_down_air", "jump_down_land", "stand_up"]
	for c in clips:
		if not _ap.has_animation(c):
			print("MISSING: ", c)
			continue
		var a: Animation = _ap.get_animation(c)
		print("\n=== %s | length %.3fs | tracks %d ===" % [c, a.length, a.get_track_count()])
		var steps := 8
		if c == "idle" or c == "walk":
			steps = 2
		for i in range(steps + 1):
			var t := minf(a.length * float(i) / steps, a.length - 0.001)
			var m := _measure(c, t)
			print("  t=%.2f  hips=%.2fm  pieL=%+.2fm  pieR=%+.2fm  cadera-pies=%.2fm  inclinacion=%.0f°" % [t, m.hips, m.fl, m.fr, m.hips - minf(m.fl, m.fr), m.tilt])

	print("\n=== DIFERENCIAS DE POSE EN CORTES DE SECUENCIA REAL ===")
	_cmp("idle", 0.0, "jump_down_takeoff", 0.0)
	var t_len := _ap.get_animation("jump_down_takeoff").length
	_cmp("jump_down_takeoff", t_len, "jump_down_air", 0.0)
	var a_len := _ap.get_animation("jump_down_air").length - 0.001
	_cmp("jump_down_air", a_len, "jump_down_land", 0.0)
	var l_len := _ap.get_animation("jump_down_land").length
	_cmp("jump_down_land", l_len, "stand_up", 0.0)
	var su_len := _ap.get_animation("stand_up").length
	_cmp("stand_up", su_len, "idle", 0.0)

	quit(0)

func _add_raw(n: String, path: String) -> void:
	var scn: PackedScene = load(path)
	var inst = scn.instantiate()
	var src: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	var a: Animation = src.get_animation("mixamo_com").duplicate()
	a.loop_mode = Animation.LOOP_NONE
	for t in range(a.get_track_count()):
		var p := String(a.track_get_path(t))
		if p.begins_with("Skeleton3D:"):
			a.track_set_path(t, NodePath("Armature/Skeleton3D:" + p.substr(11)))
	_ap.get_animation_library("").add_animation(n, a)
	inst.free()

func _apply(clip: String, t: float) -> void:
	_ap.play(clip)
	_ap.seek(t, true)
	_ap.advance(0.0)

func _skel_to_model() -> Transform3D:
	var xf := Transform3D()
	var n: Node = _skel
	while n != null and n != _model:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf

func _manual_global(i: int) -> Transform3D:
	var xf := Transform3D(Basis(_skel.get_bone_pose_rotation(i)).scaled(_skel.get_bone_pose_scale(i)), _skel.get_bone_pose_position(i))
	var p := _skel.get_bone_parent(i)
	if p >= 0:
		return _manual_global(p) * xf
	return xf

func _bone_y(name_part: String) -> float:
	for i in range(_skel.get_bone_count()):
		if _skel.get_bone_name(i).ends_with(name_part):
			var gp: Transform3D = _skel_to_model() * _manual_global(i)
			return gp.origin.y * 175.0 + 0.58
	return NAN

func _bone_global(name_part: String) -> Transform3D:
	for i in range(_skel.get_bone_count()):
		if _skel.get_bone_name(i).ends_with(name_part):
			return _skel_to_model() * _manual_global(i)
	return Transform3D()

func _measure(clip: String, t: float) -> Dictionary:
	_apply(clip, t)
	var spine := _bone_global("Spine2")
	var up: Vector3 = (spine.basis.y).normalized()
	return {
		"hips": _bone_y("Hips"),
		"fl": _bone_y("LeftToeBase") if not is_nan(_bone_y("LeftToeBase")) else _bone_y("LeftFoot"),
		"fr": _bone_y("RightToeBase") if not is_nan(_bone_y("RightToeBase")) else _bone_y("RightFoot"),
		"tilt": rad_to_deg(up.angle_to(Vector3.UP)),
	}

func _pose(clip: String, t: float) -> Array:
	_apply(clip, t)
	var out := []
	for i in range(_skel.get_bone_count()):
		out.append(_skel.get_bone_pose_rotation(i))
	return out

func _cmp(a: String, ta: float, b: String, tb: float) -> void:
	var pa := _pose(a, ta)
	var pb := _pose(b, tb)
	var total := 0.0
	var mx := 0.0
	var mx_name := ""
	for i in range(pa.size()):
		var d := rad_to_deg((pa[i] as Quaternion).angle_to(pb[i] as Quaternion))
		total += d
		if d > mx:
			mx = d
			mx_name = _skel.get_bone_name(i)
	var ha: float = _measure(a, ta).hips
	var hb: float = _measure(b, tb).hips
	print("  %s@%.2f -> %s@%.2f : avg %.1f°, max %.1f° (%s), salto cadera %.3f m" % [a, ta, b, tb, total / pa.size(), mx, mx_name, hb - ha])
