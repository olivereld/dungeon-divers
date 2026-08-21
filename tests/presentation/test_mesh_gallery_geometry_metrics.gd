extends SceneTree

const CatalogScript = preload("res://src/presentation/showcase/mesh_gallery_catalog.gd")
const RendererScript = preload("res://src/presentation/showcase/mesh_gallery_renderer.gd")
const MetricsScript = preload("res://src/presentation/showcase/mesh_gallery_metrics.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_mesh_gallery_geometry_metrics ---")
	print("==================================================================")

	var catalog = CatalogScript.new()
	var renderer = RendererScript.new()

	# 1. Probar métricas sobre un muro continuo complejo
	var wall_entry = catalog.get_entry(&"wall_continuous_straight")
	assert(wall_entry != null, "FAIL: Wall entry must exist")

	var wall_node: Node3D = renderer.render_entry(wall_entry, 1337)
	var metrics = MetricsScript.calculate_node_metrics(wall_node)

	assert(metrics.mesh_count >= 1, "FAIL: Continuous wall must have at least 1 mesh")
	assert(metrics.vertex_count > 10, "FAIL: Wall must have realistic vertex count")
	assert(metrics.bounds.size.x > 0.0 and metrics.bounds.size.y > 0.0, "FAIL: AABB bounds must be positive")
	print("  [OK] Wall continuous metrics: %s" % metrics.to_summary_string())
	print("  [OK] Wall bounds: %s" % metrics.to_bounds_string())

	# 2. Probar cambio de semilla determinista
	var wall_node_alt: Node3D = renderer.render_entry(wall_entry, 999999)
	var metrics_alt = MetricsScript.calculate_node_metrics(wall_node_alt)
	assert(metrics_alt.vertex_count > 0, "FAIL: Alt seed must generate valid mesh")

	wall_node.free()
	wall_node_alt.free()

	print("[PASS] test_mesh_gallery_geometry_metrics completed successfully.")
	quit(0)
