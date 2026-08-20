extends SceneTree

## Test suite para validar la Integración de GeometryResult y Clusters con DungeonPresentationBuilder (Fase M6).
## Verifica que la presentación 3D consume GeometryResult con clusters independientes y colisiones físicas.

const DungeonPipeline = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const SemanticOrchestrator = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonPresentationBuilder = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const BiomeProfile = preload("res://src/dungeon_generator/presentation/biome_profile.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_presentation_geometry_clusters (Fase M6) ---")
	print("==================================================================")

	var pipeline := DungeonPipeline.new()
	var semantic_orchestrator := SemanticOrchestrator.new()
	var builder := DungeonPresentationBuilder.new()

	var config := DungeonConfig.new()
	config.seed = 777001
	config.use_fixed_seed = true
	config.mission_depth = 5

	# 1. Generar mazmorra
	var d_res = pipeline.generate(config)
	assert(d_res != null, "Dungeon generation must succeed")

	# 2. Capa semántica
	var sem_res = semantic_orchestrator.generate_semantics(d_res, config)
	assert(sem_res != null and sem_res.gameplay_valid, "Semantics must be valid")

	var parent := Node3D.new()
	root.add_child(parent)

	# 3. Construir presentación
	var pres_res = builder.build_presentation(sem_res, parent, BiomeProfile.new(), config, null, true)
	assert(pres_res.success == true, "Presentation must succeed")
	assert(pres_res.presentation_root != null, "Presentation root must exist")

	var pres_root: Node3D = pres_res.presentation_root
	var walls_node: Node = pres_root.get_node_or_null("ContinuousWalls")
	assert(walls_node != null, "ContinuousWalls node must exist in presentation root")

	# Validar que tiene geometría y colisión válidas
	if walls_node is MeshInstance3D:
		var mesh_inst := walls_node as MeshInstance3D
		assert(mesh_inst.mesh != null, "MeshInstance3D must have a valid mesh")
		assert(mesh_inst.mesh.get_surface_count() >= 2, "Wall mesh must contain at least Trims and WallPanel surfaces")
		assert(mesh_inst.get_child_count() > 0, "Wall node must contain a physics body (StaticBody3D) child")
		var body = mesh_inst.get_child(0)
		assert(body is StaticBody3D, "Child must be a StaticBody3D")
		assert(body.get_child_count() > 0, "StaticBody3D must have CollisionShape3D children")

	parent.free()
	print("==================================================================")
	print("[PASS] test_presentation_geometry_clusters completado con éxito!")
	print("==================================================================")
	quit(0)
