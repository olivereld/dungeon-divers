extends SceneTree

func _init() -> void:
	print("--- Testing corner rotations ---")
	var arm_x := Vector3(-1, 0, 0) # West
	var arm_z := Vector3(0, 0, 1)  # South
	var gm := GridMap.new()

	for deg in [0, 90, 180, 270]:
		var b := Basis(Vector3.UP, deg_to_rad(deg))
		var rot_arm_x: Vector3 = b * arm_x
		var rot_arm_z: Vector3 = b * arm_z
		var inside_dir: Vector3 = (rot_arm_x + rot_arm_z).normalized()
		print("Rot %3d° (ortho_idx=%2d): Arm1=(%+.1f, %+.1f) Arm2=(%+.1f, %+.1f) -> Inside Room=(%+.1f, %+.1f)" % [
			deg, gm.get_orthogonal_index_from_basis(b),
			rot_arm_x.x, rot_arm_x.z,
			rot_arm_z.x, rot_arm_z.z,
			inside_dir.x, inside_dir.z
		])
	quit(0)
