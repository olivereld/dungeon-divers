extends SceneTree

const CandleHolderGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/candle_holder_geometry_builder.gd")
const CandleHolderGeometryConfigScript = preload("res://src/geometry_generator/config/candle_holder_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_candle_holder_geometry_builder ---")
	print("==================================================================")

	var builder = CandleHolderGeometryBuilderScript.new()
	var cfg = CandleHolderGeometryConfigScript.new()
	var holder_asset = builder.build_candle_holder_fixture(cfg)
	assert(holder_asset != null, "FAIL: Candle holder asset must not be null")
	assert(holder_asset.has_slot(&"holder_frame"), "FAIL: Must have holder_frame slot")
	assert(holder_asset.has_slot(&"candles_wax"), "FAIL: Must have candles_wax slot")
	assert(holder_asset.has_slot(&"candle_flames"), "FAIL: Must have candle_flames slot")

	var g_frame = holder_asset.get_mesh(&"holder_frame")
	var g_wax = holder_asset.get_mesh(&"candles_wax")
	var g_flames = holder_asset.get_mesh(&"candle_flames")

	assert(g_frame != null and g_frame.mesh != null, "FAIL: Frame mesh must not be null")
	assert(g_wax != null and g_wax.mesh != null, "FAIL: Wax mesh must not be null")
	assert(g_flames != null and g_flames.mesh != null, "FAIL: Flames mesh must not be null")

	var holder_node = holder_asset.to_node3d("CandleHolder")
	assert(holder_node.get_child_count() >= 3, "FAIL: CandleHolder Node3D must contain mesh components and collision")
	holder_node.free()

	print("  [OK] Candle holder slots verified: holder_frame, candles_wax, candle_flames")
	print("[PASS] test_candle_holder_geometry_builder completed successfully.")
	quit(0)
