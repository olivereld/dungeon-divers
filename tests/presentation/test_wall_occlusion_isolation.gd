extends SceneTree

const _OccluderResolverScript = preload("res://src/presentation/camera/occluder_resolver.gd")
const _WallFadeControllerScript = preload("res://src/presentation/camera/wall_fade_controller.gd")
const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_occlusion_isolation ---")
	print("==================================================================")

	var root := Node3D.new()
	var walls_container := Node3D.new()
	walls_container.name = "ContinuousWalls"
	root.add_child(walls_container)

	# Crear Section A
	var gm_a := _GeneratedMeshScript.new()
	gm_a.component_id = 1
	gm_a.section_id = 0
	gm_a.mesh = BoxMesh.new()
	var inst_a := gm_a.to_mesh_instance("WallSection")
	inst_a.add_to_group(_OccluderResolverScript.CAMERA_OCCLUDER_GROUP, true)
	var col_a := gm_a.create_collision_body()
	col_a.add_to_group(_OccluderResolverScript.CAMERA_OCCLUDER_GROUP, true)
	inst_a.add_child(col_a)
	walls_container.add_child(inst_a)

	# Crear Section B
	var gm_b := _GeneratedMeshScript.new()
	gm_b.component_id = 1
	gm_b.section_id = 1
	gm_b.mesh = BoxMesh.new()
	var inst_b := gm_b.to_mesh_instance("WallSection")
	inst_b.add_to_group(_OccluderResolverScript.CAMERA_OCCLUDER_GROUP, true)
	var col_b := gm_b.create_collision_body()
	col_b.add_to_group(_OccluderResolverScript.CAMERA_OCCLUDER_GROUP, true)
	inst_b.add_child(col_b)
	walls_container.add_child(inst_b)

	# 1. OccluderResolver debe resolver collider_a directamente a inst_a
	var resolver := _OccluderResolverScript.new()
	var resolved_a = resolver.resolve_candidate(col_a)
	assert(resolved_a == inst_a, "FAIL: col_a must resolve directly to inst_a (got %s)" % str(resolved_a))

	var resolved_b = resolver.resolve_candidate(col_b)
	assert(resolved_b == inst_b, "FAIL: col_b must resolve directly to inst_b (got %s)" % str(resolved_b))

	# 2. Desvanecer inst_a no debe afectar a inst_b
	var fader := _WallFadeControllerScript.new()
	fader.occluded_transparency = 0.75
	fader.fade_speed = 100.0 # Instantáneo para test
	root.add_child(fader)

	fader.fade_out([inst_a])
	fader.process_fade_step(1.0)

	assert(inst_a.transparency > 0.5, "FAIL: inst_a transparency should be faded (got %f)" % inst_a.transparency)
	assert(inst_b.transparency == 0.0, "FAIL: inst_b must NOT be affected or faded (got %f)" % inst_b.transparency)

	print("  [OK] OccluderResolver correctly isolates individual WallSection instances.")
	print("  [OK] WallFadeController fades ONLY the occluding section, leaving neighbors fully opaque.")
	print("==================================================================")
	print("[PASS] test_wall_occlusion_isolation passed successfully!")
	print("==================================================================")
	quit(0)
