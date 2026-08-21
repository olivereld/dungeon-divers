extends SceneTree

const CatalogScript = preload("res://src/presentation/showcase/mesh_gallery_catalog.gd")
const RendererScript = preload("res://src/presentation/showcase/mesh_gallery_renderer.gd")
const MetricsScript = preload("res://src/presentation/showcase/mesh_gallery_metrics.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_mesh_gallery_generation ---")
	print("==================================================================")

	var catalog = CatalogScript.new()
	var renderer = RendererScript.new()
	var test_seed: int = 1337

	var categories = catalog.get_categories()
	for cat in categories:
		var entries = catalog.get_entries_for_category(cat.id)
		for entry in entries:
			var node: Node3D = renderer.render_entry(entry, test_seed)
			assert(node != null, "FAIL: Rendered node for entry '%s' must not be null" % entry.id)

			var metrics = MetricsScript.calculate_node_metrics(node)
			assert(metrics.mesh_count > 0, "FAIL: Entry '%s' must generate at least 1 mesh (got 0)" % entry.id)
			assert(metrics.vertex_count > 0, "FAIL: Entry '%s' must generate vertices (got 0)" % entry.id)
			assert(metrics.triangle_count > 0, "FAIL: Entry '%s' must generate triangles (got 0)" % entry.id)

			print("  [OK] %s: %s | %s" % [entry.id, metrics.to_summary_string(), metrics.to_bounds_string()])
			node.free()

	print("[PASS] test_mesh_gallery_generation completed successfully.")
	quit(0)
