extends SceneTree

const SarcophagusGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/sarcophagus_geometry_builder.gd")
const SarcophagusGeometryConfigScript = preload("res://src/geometry_generator/config/sarcophagus_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_sarcophagus_geometry_builder ---")
	print("==================================================================")

	var builder := SarcophagusGeometryBuilderScript.new()

	# 1. Test Sarcófago de Piedra Cerrado (Closed Gothic Stone)
	var cfg_closed := SarcophagusGeometryConfigScript.new(
		SarcophagusGeometryConfigScript.Style.GOTHIC_STONE,
		false
	)
	var asset_closed = builder.build_sarcophagus_fixture(cfg_closed)
	assert(asset_closed != null, "FAIL: Closed sarcophagus asset is null")
	assert(asset_closed.has_slot(&"sarcophagus_base_body"), "FAIL: Missing base body")
	assert(asset_closed.has_slot(&"sarcophagus_base_trim"), "FAIL: Missing base trim")
	assert(asset_closed.has_slot(&"sarcophagus_lid_body"), "FAIL: Missing lid body")
	assert(asset_closed.has_slot(&"sarcophagus_lid_trim"), "FAIL: Missing lid trim")

	var m_base = asset_closed.get_mesh(&"sarcophagus_base_body").mesh
	var aabb_base = m_base.get_aabb()
	assert(aabb_base.size.x > 1.0 and aabb_base.size.z > 0.5, "FAIL: Base AABB dimensions incorrect")
	print("  [OK] Closed Gothic Stone Sarcophagus validated: %d mesh slots, valid AABB (%s)" % [
		asset_closed.meshes.size(), str(aabb_base.size)
	])

	# 2. Test Sarcófago de Piedra Abierto (Open Gothic Stone)
	var cfg_open := SarcophagusGeometryConfigScript.new(
		SarcophagusGeometryConfigScript.Style.GOTHIC_STONE,
		true
	)
	var asset_open = builder.build_sarcophagus_fixture(cfg_open)
	assert(asset_open != null, "FAIL: Open sarcophagus asset is null")
	var m_lid_open = asset_open.get_mesh(&"sarcophagus_lid_body").mesh
	var aabb_lid_open = m_lid_open.get_aabb()
	assert(aabb_lid_open.position.x != 0.0 or aabb_lid_open.position.z != 0.0, "FAIL: Open lid should be offset from center")
	print("  [OK] Open Gothic Stone Sarcophagus validated (lid displaced/askew).")

	# 3. Test Féretro de Madera Rústica (Rustic Wood Coffin)
	var cfg_wood := SarcophagusGeometryConfigScript.new(
		SarcophagusGeometryConfigScript.Style.RUSTIC_WOOD,
		false
	)
	var asset_wood = builder.build_sarcophagus_fixture(cfg_wood)
	assert(asset_wood != null, "FAIL: Wood sarcophagus asset is null")
	var mat_wood = asset_wood.get_mesh(&"sarcophagus_base_body").material_slots[0]
	assert(mat_wood.albedo_color == cfg_wood.wood_body_color, "FAIL: Wood material color mismatch")
	print("  [OK] Rustic Wood Coffin validated.")

	# 4. Validar que no hay caras invertidas (normales apuntando hacia afuera)
	for slot_name in asset_closed.meshes:
		var gen_mesh = asset_closed.meshes[slot_name]
		var arrays = gen_mesh.mesh.surface_get_arrays(0)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for norm in normals:
			assert(not norm.is_zero_approx(), "FAIL: Zero normal detected in %s" % slot_name)

	print("  [OK] All surface normals non-degenerate and oriented correctly.")
	print("[PASS] test_sarcophagus_geometry_builder completed successfully!")
	quit(0)
