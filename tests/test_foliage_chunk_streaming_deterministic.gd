extends SceneTree

const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _AutumnProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _GeneratorScript = preload("res://src/world_generator/foliage/foliage_generator.gd")

func _init() -> void:
	print("Running test_foliage_chunk_streaming_deterministic...")
	var seed_val := 98765
	var profile = _AutumnProfileScript.new()
	var config = _ChunkConfigScript.new(16, 1, 3)
	var hydro = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)
	
	var cw = _ChunkWorldScript.new()
	cw.initialize(seed_val, profile, config, hydro, 3)
	cw.load_initial_area(Vector2i(2, -3), 1)
	
	var gen := _GeneratorScript.new()
	var chunk_data = cw.chunk_manager.load_chunk(Vector2i(2, -3))
	assert(chunk_data != null, "Chunk data must exist")
	var chunk_bounds: Rect2i = chunk_data.core_bounds
	print("Loaded chunk (2, -3) cells: ", chunk_data.cells.size(), " bounds: ", chunk_bounds)
	
	# Generate chunk A run 1
	var data1 = gen.generate_foliage(chunk_data, seed_val, chunk_bounds, profile)
	print("Run 1 instances: ", data1.get_total_instance_count())
	# Generate chunk A run 2
	var data2 = gen.generate_foliage(chunk_data, seed_val, chunk_bounds, profile)
	print("Run 2 instances: ", data2.get_total_instance_count())
	
	assert(data1 != null and data2 != null, "Foliage chunk data must not be null")
	assert(data1.get_total_instance_count() == data2.get_total_instance_count(), "Instance count must be identical across runs")
	assert(data1.get_total_instance_count() > 0, "Chunk with land must generate foliage instances")
	
	# Verify transforms match perfectly
	for sp_id in data1.instances_by_species.keys():
		var list1: Array = data1.instances_by_species[sp_id]
		var list2: Array = data2.instances_by_species[sp_id]
		assert(list1.size() == list2.size(), "Species instance count mismatch for %s" % str(sp_id))
		for i in range(list1.size()):
			assert(list1[i].origin.is_equal_approx(list2[i].origin), "Instance position mismatch")
			assert(list1[i].basis.is_equal_approx(list2[i].basis), "Instance rotation/scale mismatch")
	
	print("[PASS] test_foliage_chunk_streaming_deterministic (Total instances: %d)" % data1.get_total_instance_count())
	quit(0)
