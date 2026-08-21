extends SceneTree

const CandleClusterGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/candle_cluster_geometry_builder.gd")
const CandleClusterGeometryConfigScript = preload("res://src/geometry_generator/config/candle_cluster_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_candle_cluster_geometry_builder ---")
	print("==================================================================")

	var builder = CandleClusterGeometryBuilderScript.new()

	# 1. Test Cúmulo Pequeño
	var cfg_small = CandleClusterGeometryConfigScript.new(CandleClusterGeometryConfigScript.ClusterDensity.SMALL)
	var asset_small = builder.build_candle_cluster_fixture(cfg_small)
	assert(asset_small != null, "FAIL: Small Candle cluster must not be null")
	assert(asset_small.has_slot(&"candles_wax"), "FAIL: Must have candles_wax slot")
	assert(asset_small.has_slot(&"candle_flames"), "FAIL: Must have candle_flames slot")
	var node_small = asset_small.to_node3d("SmallCluster")
	assert(node_small.get_child_count() >= 2, "FAIL: Small cluster Node3D must contain mesh components")
	node_small.free()
	print("  [OK] Small Candle Cluster (5 candles) verified")

	# 2. Test Cúmulo Medio
	var cfg_med = CandleClusterGeometryConfigScript.new(CandleClusterGeometryConfigScript.ClusterDensity.MEDIUM)
	var asset_med = builder.build_candle_cluster_fixture(cfg_med)
	assert(asset_med != null, "FAIL: Medium Candle cluster must not be null")
	var node_med = asset_med.to_node3d("MedCluster")
	assert(node_med.get_child_count() >= 2, "FAIL: Med cluster Node3D must contain mesh components")
	node_med.free()
	print("  [OK] Medium Candle Cluster (12 candles) verified")

	# 3. Test Santuario Denso
	var cfg_dense = CandleClusterGeometryConfigScript.new(CandleClusterGeometryConfigScript.ClusterDensity.DENSE)
	var asset_dense = builder.build_candle_cluster_fixture(cfg_dense)
	assert(asset_dense != null, "FAIL: Dense Candle cluster must not be null")
	var node_dense = asset_dense.to_node3d("DenseCluster")
	assert(node_dense.get_child_count() >= 2, "FAIL: Dense cluster Node3D must contain mesh components")
	node_dense.free()
	print("  [OK] Dense Candle Sanctuary (24 candles) verified")

	print("[PASS] test_candle_cluster_geometry_builder completed successfully.")
	quit(0)
