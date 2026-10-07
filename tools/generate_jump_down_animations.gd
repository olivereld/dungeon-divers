extends SceneTree

## Generador de animaciones de salto hacia abajo y recuperación para Aldeano
## Corta las fases reales, muestrea pistas con interpolación a 30 fps,
## ancla la raíz en X/Z (In-Place) y realiza pase de anclaje de pies (Y=0) calibrado con el esqueleto.

const MODEL_PATH = "res://assets/models/character/Test/Aldeano_rigged_v1.glb"
const JUMP_FBX = "res://assets/animations/human/human_01_jump_down.fbx"
const STAND_FBX = "res://assets/animations/human/human_01_stand_up.fbx"

var _model: Node3D
var _skel: Skeleton3D
var _hips_idx: int = -1
var _foot_indices: Array[int] = []

func _init() -> void:
	# 1. Cargar modelo real para calibración esqueletal
	var scn: PackedScene = load(MODEL_PATH)
	if scn == null:
		printerr("ERROR: Could not load model ", MODEL_PATH)
		quit(1)
		return
	_model = scn.instantiate()
	root.add_child(_model)
	var arm = _model.get_node_or_null("Armature")
	if arm:
		arm.rotation = Vector3.ZERO
	_skel = _model.find_child("Skeleton3D", true, false)
	if _skel == null:
		printerr("ERROR: Skeleton3D not found in ", MODEL_PATH)
		quit(1)
		return

	for i in range(_skel.get_bone_count()):
		var bn := _skel.get_bone_name(i)
		if bn.ends_with("Hips"):
			_hips_idx = i
		elif bn.ends_with("LeftToeBase") or bn.ends_with("RightToeBase") \
				or bn.ends_with("LeftFoot") or bn.ends_with("RightFoot"):
			_foot_indices.append(i)

	print("Skeleton loaded. Hips idx: ", _hips_idx, " Foot bone count: ", _foot_indices.size())

	# 2. Cargar animaciones FBX originales
	var jump_anim := _load_mixamo_anim(JUMP_FBX)
	var stand_anim := _load_mixamo_anim(STAND_FBX)
	if jump_anim == null or stand_anim == null:
		printerr("ERROR loading raw anims")
		quit(1)
		return

	print("Loaded raw jump: %.3fs, stand: %.3fs" % [jump_anim.length, stand_anim.length])

	# 3. Fase 1: Despegue / Empuje en el borde (Takeoff: 0.40s -> 0.90s, dur = 0.50s)
	# Pies en el suelo empujando hacia arriba en el borde sin avance horizontal
	var anim_takeoff := _sample_clip(jump_anim, 0.40, 0.90, false, "ground")
	_save_anim(anim_takeoff, "res://assets/animations/human/human_01_jump_down_takeoff.res")
	_save_anim(anim_takeoff, "res://assets/animations/human/human_01_jump_down_start.res")

	# Medir offset de hips al final del despegue para continuidad con el vuelo
	var takeoff_end_offset := _get_ground_offset(jump_anim, 0.90)
	var land_start_offset := _get_ground_offset(jump_anim, 1.38)

	# 4. Fase 2: Caída / Vuelo en el aire (Air: 0.90s -> 1.38s, dur = 0.48s)
	# Sin bucle; pose de vuelo sincronizada con la trayectoria parabólica
	var anim_air := _sample_clip(jump_anim, 0.90, 1.38, false, "air", takeoff_end_offset, land_start_offset)
	_save_anim(anim_air, "res://assets/animations/human/human_01_jump_down_air.res")
	_save_anim(anim_air, "res://assets/animations/human/human_01_jump_down_fall.res")

	# 5. Fase 3: Aterrizaje y absorción de impacto (Land: 1.38s -> 1.75s, dur = 0.37s)
	# Pies tocan el suelo y las rodillas se comprimen absorbiendo el impacto
	var anim_land := _sample_clip(jump_anim, 1.38, 1.75, false, "ground")
	_save_anim(anim_land, "res://assets/animations/human/human_01_jump_down_land.res")

	# 6. Fase 4: Incorporarse / Levantarse (StandUp: 0.45s -> 2.35s, dur = 1.90s)
	# Transición suave desde la pose agachada del suelo hasta quedar completamente erguido
	var anim_stand := _sample_clip(stand_anim, 0.45, 2.35, false, "ground")
	_save_anim(anim_stand, "res://assets/animations/human/human_01_stand_up.res")

	_model.free()
	print("All jump down and stand up animations successfully generated!")
	quit(0)

func _load_mixamo_anim(path: String) -> Animation:
	var scn: PackedScene = load(path)
	if scn == null: return null
	var inst = scn.instantiate()
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	if ap == null or not ap.has_animation("mixamo_com"):
		inst.free()
		return null
	var a: Animation = ap.get_animation("mixamo_com").duplicate()
	inst.free()
	return a

func _save_anim(anim: Animation, path: String) -> void:
	var err := ResourceSaver.save(anim, path)
	print("Saved %s (err = %d, length = %.3fs, tracks = %d)" % [path, err, anim.length, anim.get_track_count()])

func _sample_clip(
	src: Animation,
	start_t: float,
	end_t: float,
	is_loop: bool,
	mode: String, # "ground" o "air"
	air_start_offset: float = 0.0,
	air_end_offset: float = 0.0
) -> Animation:
	var dst := Animation.new()
	var dur := maxf(end_t - start_t, 0.033)
	dst.length = dur
	dst.loop_mode = Animation.LOOP_LINEAR if is_loop else Animation.LOOP_NONE
	dst.step = 1.0 / 30.0

	var fps := 30.0
	var sample_count := int(ceil(dur * fps)) + 1

	# Mapear pistas retargeteadas
	var track_map: Array[Dictionary] = []
	for t in range(src.get_track_count()):
		var track_path := String(src.track_get_path(t))
		var track_type := src.track_get_type(t)
		var retargeted_path := track_path
		if retargeted_path.begins_with("Skeleton3D:"):
			retargeted_path = "Armature/Skeleton3D:" + retargeted_path.substr("Skeleton3D:".length())

		var dst_t := dst.add_track(track_type)
		dst.track_set_path(dst_t, NodePath(retargeted_path))
		dst.track_set_interpolation_type(dst_t, Animation.INTERPOLATION_LINEAR)

		var is_hips_pos: bool = retargeted_path.ends_with("mixamorig_Hips") and track_type == Animation.TYPE_POSITION_3D
		track_map.append({
			"src_idx": t,
			"dst_idx": dst_t,
			"type": track_type,
			"is_hips_pos": is_hips_pos
		})

	# Precalcular compensaciones de Y para Hips
	var hips_y_adjustments: Array[float] = []
	for s in range(sample_count):
		var rel_t := float(s) / fps
		rel_t = clampf(rel_t, 0.0, dur)
		var abs_t := clampf(start_t + rel_t, start_t, end_t)

		var adj_y := 0.0
		if mode == "ground":
			adj_y = _get_ground_offset(src, abs_t)
		elif mode == "air":
			var frac := rel_t / dur
			adj_y = lerpf(air_start_offset, air_end_offset, frac)
		hips_y_adjustments.append(adj_y)

	# In-Place hips reference X/Z
	var ref_hips_pos := Vector3(0.000033, 0.0, 0.000007)

	for s in range(sample_count):
		var rel_t := minf(float(s) / fps, dur)
		var abs_t := clampf(start_t + rel_t, start_t, end_t)
		var hips_y_adj: float = hips_y_adjustments[s]

		for item in track_map:
			var src_t: int = item.src_idx
			var dst_t: int = item.dst_idx
			var ttype: int = item.type

			if ttype == Animation.TYPE_POSITION_3D:
				var pos: Vector3 = src.position_track_interpolate(src_t, abs_t)
				if item.is_hips_pos:
					pos = Vector3(ref_hips_pos.x, pos.y + hips_y_adj, ref_hips_pos.z)
				dst.track_insert_key(dst_t, rel_t, pos)
			elif ttype == Animation.TYPE_ROTATION_3D:
				var rot: Quaternion = src.rotation_track_interpolate(src_t, abs_t)
				dst.track_insert_key(dst_t, rel_t, rot)
			elif ttype == Animation.TYPE_SCALE_3D:
				var sc: Vector3 = src.scale_track_interpolate(src_t, abs_t)
				dst.track_insert_key(dst_t, rel_t, sc)
			elif ttype == Animation.TYPE_VALUE:
				var v = src.value_track_interpolate(src_t, abs_t)
				dst.track_insert_key(dst_t, rel_t, v)

	return dst

func _get_ground_offset(anim: Animation, t: float) -> float:
	_apply_anim_frame(anim, t)
	var min_foot_y := 999.0
	for f_idx in _foot_indices:
		var fy := _bone_y(f_idx)
		if not is_nan(fy) and fy < min_foot_y:
			min_foot_y = fy
	if min_foot_y > 900.0:
		return 0.0
	# Factor de escala Armature (0.01) * Model (175.0) = 1.75
	return -min_foot_y / 1.75

func _apply_anim_frame(anim: Animation, t: float) -> void:
	for track in range(anim.get_track_count()):
		var p := String(anim.track_get_path(track))
		var bone_name := p.substr("Skeleton3D:".length()) if p.begins_with("Skeleton3D:") else p
		var idx := _skel.find_bone(bone_name)
		if idx == -1: continue
		var tt := anim.track_get_type(track)
		if tt == Animation.TYPE_ROTATION_3D:
			_skel.set_bone_pose_rotation(idx, anim.rotation_track_interpolate(track, t))
		elif tt == Animation.TYPE_POSITION_3D:
			_skel.set_bone_pose_position(idx, anim.position_track_interpolate(track, t))
		elif tt == Animation.TYPE_SCALE_3D:
			_skel.set_bone_pose_scale(idx, anim.scale_track_interpolate(track, t))

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

func _bone_y(i: int) -> float:
	if i < 0: return NAN
	var gp: Transform3D = _skel_to_model() * _manual_global(i)
	return gp.origin.y * 175.0 + 0.58
