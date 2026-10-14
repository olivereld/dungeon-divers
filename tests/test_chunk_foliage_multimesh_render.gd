extends SceneTree

const _GeneratorScript = preload("res://src/world_generator/foliage/foliage_generator.gd")
const _RendererScript = preload("res://src/world_generator/foliage/rendering/foliage_renderer.gd")
const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")
const _ProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("Running test_chunk_foliage_multimesh_render...")
	var prof := _ProfileScript.new()
	var result = _WorldPipelineScript.generate(12345, prof)
	assert(result != null, "WorldResult must not be null")

	var gen := _GeneratorScript.new()
	var bounds := Rect2i(0, 0, 32, 32)
	var chunk_data = gen.generate_foliage(result, 12345, bounds, prof)
	assert(chunk_data != null, "Foliage chunk data must not be null")

	var node = _RendererScript.build_chunk_foliage_node(chunk_data)
	assert(node != null, "Chunk foliage node must not be null")
	assert(node.get_child_count() >= 3, "Node must have multiple species MultiMeshInstance3Ds (got %d)" % node.get_child_count())

	var species_found := {}
	for child in node.get_children():
		if child is MultiMeshInstance3D:
			species_found[child.name] = child.multimesh.instance_count
			print(" -> Child: %s, Instances: %d" % [child.name, child.multimesh.instance_count])

	assert(chunk_data.get_total_instance_count() > 0, "Must have generated instances")
	node.free()
	print("[PASS] test_chunk_foliage_multimesh_render")
	quit(0)
