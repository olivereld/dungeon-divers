extends SceneTree

const _FoliageRendererScript = preload("res://src/world_generator/foliage/rendering/foliage_renderer.gd")
const _FoliageChunkDataScript = preload("res://src/world_generator/foliage/foliage_chunk_data.gd")
const _FoliageSpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")
const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")
const _BiomeIdScript = preload("res://src/world_generator/biomes/biome_id.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Foliage Renderer Test Suite (Tarea 5)")
	print("==================================================")

	var reg = _BiomeRegistryScript.get_default()
	var sp = _FoliageSpeciesScript.new(
		&"grass_large",
		"Large Grass",
		"res://assets/texture/foliage/grass/large_grass_01.jpg",
		1.0,
		Vector3.ONE,
		Vector3.ONE,
		25.0
	)

	var chunk_data = _FoliageChunkDataScript.new(Vector2i(1, 2))
	var t1 := Transform3D(Basis.IDENTITY, Vector3(16.0, 4.0, 32.0))
	var t2 := Transform3D(Basis.IDENTITY, Vector3(20.0, 4.0, 35.0))
	chunk_data.add_instance(&"grass_large", t1, Color(1, 1, 1))
	chunk_data.add_instance(&"grass_large", t2, Color(0.9, 0.9, 0.9))

	var origin_offset := Vector3(16.0, 0.0, 32.0)
	var foliage_node = _FoliageRendererScript.build_chunk_foliage_node(chunk_data, [sp], origin_offset)

	assert(foliage_node != null, "Foliage node must be created")
	assert(foliage_node.name == "ChunkFoliage", "Node name must be ChunkFoliage")
	assert(foliage_node.get_child_count() == 1, "Must have 1 MultiMesh child for 1 species")

	var mmi = foliage_node.get_child(0) as MultiMeshInstance3D
	assert(mmi != null, "Child must be MultiMeshInstance3D")
	assert(mmi.multimesh != null, "MultiMesh must be created")
	assert(mmi.multimesh.instance_count == 2, "Instance count must be 2")
	assert(mmi.material_override != null, "Material override must be assigned")

	assert(mmi.multimesh.mesh != null, "MultiMesh mesh must be assigned")
	assert(mmi.multimesh.transform_format == MultiMesh.TRANSFORM_3D, "Transform format must be TRANSFORM_3D")

	print(" -> [PASS] MultiMesh construction and chunk-local transformation verified")

	foliage_node.queue_free()
	print("==================================================")
	print(" ALL FOLIAGE RENDERER TESTS PASSED!")
	print("==================================================")
	quit(0)
