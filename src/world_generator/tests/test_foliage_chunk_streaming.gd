extends SceneTree

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _FoliageRendererScript = preload("res://src/world_generator/foliage/rendering/foliage_renderer.gd")
const _ChunkActivationSchedulerScript = preload("res://src/world_generator/chunks/chunk_activation_scheduler.gd")

func _init() -> void:
	print("--- TEST FOLIAGE CHUNK STREAMING ---")
	test_chunk_data_foliage_generation()
	test_chunk_activation_foliage_nodes()
	test_chunk_unloading_cleanup()
	print("--- TEST FOLIAGE CHUNK STREAMING: ALL PASSED ---")
	quit(0)

func test_chunk_data_foliage_generation() -> void:
	var seed_val := 4242
	var coord := Vector2i(1, 1)
	var profile := TaigaWorldProfile.new()
	var config := ChunkConfig.new()

	var chunk_data: ChunkData = _WorldPipelineScript.generate_chunk(seed_val, coord, profile, config)
	assert(chunk_data != null, "ChunkData should be generated")
	assert(chunk_data.foliage != null, "ChunkData.foliage must not be null")
	assert(chunk_data.foliage.has_method("get_total_instance_count"), "FoliageChunkData must have get_total_instance_count")

	var count: int = chunk_data.foliage.get_total_instance_count()
	print("Chunk foliage generated instance count: ", count)
	assert(count > 0, "Chunk foliage should have generated instances in Taiga")

func test_chunk_activation_foliage_nodes() -> void:
	var seed_val := 4242
	var coord := Vector2i(0, 0)
	var profile := TaigaWorldProfile.new()
	var config := ChunkConfig.new()

	var chunk_data: ChunkData = _WorldPipelineScript.generate_chunk(seed_val, coord, profile, config)
	var origin_3d := Vector3(float(chunk_data.core_bounds.position.x) * profile.cell_size, 0.0, float(chunk_data.core_bounds.position.y) * profile.cell_size)

	var chunk_view := Node3D.new()
	chunk_view.name = "ChunkView_Test"

	var fol_node: Node3D = _FoliageRendererScript.build_chunk_foliage_node(chunk_data.foliage, [], origin_3d)
	assert(fol_node != null, "Foliage node should not be null")
	chunk_view.add_child(fol_node)

	var found_mmi := false
	for child in fol_node.get_children():
		if child is MultiMeshInstance3D:
			found_mmi = true
			var mm: MultiMesh = child.multimesh
			assert(mm != null, "MultiMesh must be assigned to MultiMeshInstance3D")
			assert(mm.instance_count > 0, "MultiMesh instance count should be > 0")

	assert(found_mmi, "Chunk foliage node should contain at least one MultiMeshInstance3D")
	chunk_view.free()

func test_chunk_unloading_cleanup() -> void:
	var root := Node3D.new()
	var seed_val := 999
	var coord := Vector2i(2, 2)
	var profile := TaigaWorldProfile.new()
	var config := ChunkConfig.new()

	var chunk_data: ChunkData = _WorldPipelineScript.generate_chunk(seed_val, coord, profile, config)
	var origin_3d := Vector3(float(chunk_data.core_bounds.position.x) * profile.cell_size, 0.0, float(chunk_data.core_bounds.position.y) * profile.cell_size)

	var chunk_view := Node3D.new()
	chunk_view.name = "Chunk_2_2"
	root.add_child(chunk_view)

	var fol_node: Node3D = _FoliageRendererScript.build_chunk_foliage_node(chunk_data.foliage, [], origin_3d)
	if fol_node != null:
		chunk_view.add_child(fol_node)

	assert(chunk_view.get_child_count() > 0, "Chunk view should have children")
	var initial_children := root.get_child_count()
	assert(initial_children == 1, "Root should have 1 child")

	# Simular descarga/liberación
	root.remove_child(chunk_view)
	chunk_view.free()

	assert(root.get_child_count() == 0, "Root should have 0 children after unload")
	root.free()
	print("Chunk foliage cleanup verified cleanly.")
