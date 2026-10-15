extends SceneTree

const _WorldVegetationItemScript = preload("res://src/world_generator/data/world_vegetation_item.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldGenerationContextScript = preload("res://src/world_generator/core/world_generation_context.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _WorldRendererScript = preload("res://src/world_renderer/world_renderer.gd")

func _init() -> void:
	print("==================================================")
	print(" Testing Wood Log and Stump Forest Decorations")
	print("==================================================")

	# 1. Verificar existencia de recursos GLB y Texturas
	assert(ResourceLoader.exists("res://models/nature/wood_log/wood_log.glb"), "wood_log.glb must exist")
	assert(ResourceLoader.exists("res://models/nature/wood_log/wood_log_tree_log.png"), "wood_log_tree_log.png must exist")
	assert(ResourceLoader.exists("res://models/nature/stump/STUMP.glb"), "STUMP.glb must exist")
	assert(ResourceLoader.exists("res://models/nature/stump/STUMP_stump.png"), "STUMP_stump.png must exist")
	print(" [PASS] 1. Model and texture assets verified")

	# 2. Verificar horneado de mallas en WorldRenderer
	var log_mesh = _WorldRendererScript._create_wood_log_mesh()
	assert(log_mesh != null, "Wood log mesh must bake successfully")
	assert(log_mesh is ArrayMesh or log_mesh is Mesh, "Wood log must be a Mesh")
	var log_aabb: AABB = log_mesh.get_aabb()
	assert(log_aabb.size.z > 0.6, "Wood log must have realistic length along Z axis")
	assert(log_mesh.surface_get_material(0) != null, "Wood log must have surface material")

	var stump_mesh = _WorldRendererScript._create_stump_mesh()
	assert(stump_mesh != null, "Stump mesh must bake successfully")
	assert(stump_mesh is ArrayMesh or stump_mesh is Mesh, "Stump must be a Mesh")
	var stump_aabb: AABB = stump_mesh.get_aabb()
	assert(stump_aabb.size.y > 0.4, "Stump must have realistic vertical height")
	assert(stump_mesh.surface_get_material(0) != null, "Stump must have surface material")
	print(" [PASS] 2. Mesh baking and materials verified for log and stump")

	# 3. Generar un mundo con TaigaWorldProfile y verificar que se colocan troncos y tocones
	var profile := _TaigaWorldProfileScript.new()
	profile.tree_density = 0.40
	profile.log_density = 0.12
	profile.stump_density = 0.10

	var result = _WorldPipelineScript.generate(4242, profile)
	assert(result != null, "World result must generate")

	var conifer_count := 0
	var shrub_count := 0
	var rock_count := 0
	var log_count := 0
	var stump_count := 0

	for it in result.vegetation:
		var item := it as WorldVegetationItem
		match item.type:
			WorldVegetationItem.Type.CONIFER: conifer_count += 1
			WorldVegetationItem.Type.SHRUB: shrub_count += 1
			WorldVegetationItem.Type.ROCK: rock_count += 1
			WorldVegetationItem.Type.WOOD_LOG: log_count += 1
			WorldVegetationItem.Type.STUMP: stump_count += 1

	print(" [INFO] Conifers: %d, Shrubs: %d, Rocks: %d, Logs: %d, Stumps: %d" % [
		conifer_count, shrub_count, rock_count, log_count, stump_count
	])
	assert(log_count > 0, "World must contain fallen wood logs (got %d)" % log_count)
	assert(stump_count > 0, "World must contain tree stumps (got %d)" % stump_count)
	print(" [PASS] 3. VegetationStage procedural placement verified for logs and stumps")

	# 4. Verificar renderizado en MultiMesh de WorldRenderer
	var world_node := Node3D.new()
	_WorldRendererScript.spawn_vegetation(world_node, result.vegetation, Vector3.ZERO, profile)

	var log_mmi: MultiMeshInstance3D = world_node.get_node_or_null("WoodLogs") as MultiMeshInstance3D
	assert(log_mmi != null, "WoodLogs MultiMeshInstance3D must be created in scene")
	assert(log_mmi.multimesh != null, "WoodLogs must have MultiMesh assigned")
	assert(log_mmi.multimesh.instance_count == log_count, "WoodLogs instance count must match items count")

	var stump_mmi: MultiMeshInstance3D = world_node.get_node_or_null("Stumps") as MultiMeshInstance3D
	assert(stump_mmi != null, "Stumps MultiMeshInstance3D must be created in scene")
	assert(stump_mmi.multimesh != null, "Stumps must have MultiMesh assigned")
	assert(stump_mmi.multimesh.instance_count == stump_count, "Stumps instance count must match items count")
	print(" [PASS] 4. WorldRenderer MultiMeshInstance3D rendering verified")

	# 5. Determinismo estricto: regenerar con la misma semilla
	var result2 = _WorldPipelineScript.generate(4242, profile)
	var log_count_2 := 0
	var stump_count_2 := 0
	for it in result2.vegetation:
		var item := it as WorldVegetationItem
		if item.type == WorldVegetationItem.Type.WOOD_LOG:
			log_count_2 += 1
		elif item.type == WorldVegetationItem.Type.STUMP:
			stump_count_2 += 1

	assert(log_count == log_count_2, "Log count must be deterministic")
	assert(stump_count == stump_count_2, "Stump count must be deterministic")
	print(" [PASS] 5. Deterministic reproducibility verified")

	world_node.free()
	print("==================================================")
	print(" ALL WOOD LOG AND STUMP DECORATION TESTS PASSED!")
	print("==================================================")
	quit(0)
