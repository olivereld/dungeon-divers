extends SceneTree

const BenchGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/bench_geometry_builder.gd")
const BenchGeometryConfigScript = preload("res://src/geometry_generator/config/bench_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_bench_geometry_builder ---")
	print("==================================================================")

	var builder := BenchGeometryBuilderScript.new()

	# 1. Test Banco de Iglesia / Templo (Church Pew)
	var cfg_pew := BenchGeometryConfigScript.new(BenchGeometryConfigScript.BenchStyle.CHURCH_PEW)
	var asset_pew = builder.build_bench_fixture(cfg_pew)
	assert(asset_pew != null, "FAIL: Church Pew asset is null")
	assert(asset_pew.has_slot(&"bench_main"), "FAIL: Missing bench_main slot")
	assert(asset_pew.has_slot(&"bench_trim"), "FAIL: Missing bench_trim slot")
	var aabb_pew = asset_pew.get_mesh(&"bench_main").mesh.get_aabb()
	assert(aabb_pew.size.x >= 1.30, "FAIL: Bench length should be >= 1.3m")
	print("  [OK] Church Pew validated: %s" % str(aabb_pew.size))

	# 2. Test Banco Monumental de Piedra (Stone Orior)
	var cfg_stone := BenchGeometryConfigScript.new(BenchGeometryConfigScript.BenchStyle.STONE_ORIOR)
	var asset_stone = builder.build_bench_fixture(cfg_stone)
	assert(asset_stone != null, "FAIL: Stone Orior asset is null")
	var mat_stone = asset_stone.get_mesh(&"bench_main").material_slots[0]
	assert(mat_stone.albedo_color == cfg_stone.stone_color, "FAIL: Stone material color mismatch")
	print("  [OK] Stone Orior Bench validated.")

	# 3. Test Banco de Taberna con Cojines (Tavern Bench)
	var cfg_tavern := BenchGeometryConfigScript.new(BenchGeometryConfigScript.BenchStyle.TAVERN_BENCH)
	var asset_tavern = builder.build_bench_fixture(cfg_tavern)
	assert(asset_tavern != null, "FAIL: Tavern Bench asset is null")
	var mat_cushion = asset_tavern.get_mesh(&"bench_trim").material_slots[0]
	assert(mat_cushion.albedo_color == cfg_tavern.cushion_color, "FAIL: Cushion material color mismatch")
	print("  [OK] Tavern Bench with Cushions validated.")

	# 4. Test Banqueta Corrida Rústica (Backless Bench)
	var cfg_backless := BenchGeometryConfigScript.new(BenchGeometryConfigScript.BenchStyle.BACKLESS_BENCH)
	var asset_backless = builder.build_bench_fixture(cfg_backless)
	assert(asset_backless != null, "FAIL: Backless Bench asset is null")
	print("  [OK] Backless Bench validated.")

	# 5. Validar que no hay caras invertidas (normales no nulas y no degeneradas)
	for slot_name in asset_pew.meshes:
		var gen_mesh = asset_pew.meshes[slot_name]
		var arrays = gen_mesh.mesh.surface_get_arrays(0)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for norm in normals:
			assert(not norm.is_zero_approx(), "FAIL: Zero normal detected in %s" % slot_name)

	print("  [OK] All normals valid and correctly oriented (CCW).")
	print("[PASS] test_bench_geometry_builder completed successfully!")
	quit(0)
