extends SceneTree

func _init() -> void:
	var path := "res://assets/animations/human/human_01_stand_up.fbx"
	var scn: PackedScene = load(path)
	var inst = scn.instantiate()
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	var raw_anim: Animation = ap.get_animation("mixamo_com")

	print("Raw stand_up length: ", raw_anim.length)

	# Recortamos desde t = 0.30s (donde comienza el impulso activo hacia arriba)
	# eliminando la pausa inmóvil del suelo, hasta t = 1.65s (donde queda erguido)
	var anim_stand: Animation = _create_retargeted_anim(raw_anim, 0.30, 1.65)
	var dst_path := "res://assets/animations/human/human_01_stand_up.res"
	var err := ResourceSaver.save(anim_stand, dst_path)
	print("Saved human_01_stand_up.res: err = ", err, " length = ", anim_stand.length)

	inst.free()
	quit(0)

func _create_retargeted_anim(src: Animation, start_t: float, end_t: float) -> Animation:
	var dst := Animation.new()
	dst.length = end_t - start_t
	dst.loop_mode = Animation.LOOP_NONE
	dst.step = src.step

	var ref_hips_pos := Vector3(0.000033, 0.001376, 0.000007)

	for t in range(src.get_track_count()):
		var track_path := String(src.track_get_path(t))
		var track_type := src.track_get_type(t)

		var retargeted_path := track_path
		if retargeted_path.begins_with("Skeleton3D:"):
			var bone_name := retargeted_path.substr("Skeleton3D:".length())
			retargeted_path = "Armature/Skeleton3D:" + bone_name

		var dst_t := dst.add_track(track_type)
		dst.track_set_path(dst_t, NodePath(retargeted_path))
		dst.track_set_interpolation_type(dst_t, src.track_get_interpolation_type(t))

		var is_hips_pos: bool = retargeted_path.ends_with("mixamorig_Hips") and track_type == Animation.TYPE_POSITION_3D

		for k in range(src.track_get_key_count(t)):
			var kt := src.track_get_key_time(t, k)
			if kt >= start_t and kt <= end_t:
				var new_t := kt - start_t
				var val = src.track_get_key_value(t, k)
				if is_hips_pos and val is Vector3:
					# Anclar X y Z estrictamente al origen para In-Place, permitiendo la elevación Y
					val = Vector3(ref_hips_pos.x, val.y, ref_hips_pos.z)
				dst.track_insert_key(dst_t, new_t, val)

	return dst
