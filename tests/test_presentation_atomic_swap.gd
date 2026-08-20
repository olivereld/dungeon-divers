extends SceneTree

## Suite de pruebas para Validación de Contrato:
## DungeonPresentationBuilder -> StagingRoot -> Atomic Swap / Rollback & Boss Integration.
## Valida los contratos:
## 1. Presentación válida: Creación y promoción de StagingRoot a PresentationRoot con jerarquía completa.
## 2. Integración Boss: Boss presente en Entities/Objectives dentro de presentation_root con metadata intacta.
## 3. Atomic Swap & Rollback:
##    - Swap exitoso: Reemplazo atómico de ActivePresentation A por B sin estado inconsistente.
##    - Rollback ante fallo semántico: Preservación total de presentación anterior ante datos inválidos.
##    - Rollback ante error de materialización: Destrucción de Staging y preservación de presentación activa.

const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipeline = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const ObjectiveData = preload("res://src/dungeon_generator/core/semantic/data/objective_data.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const DungeonSemanticResult = preload("res://src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd")
const SemanticOrchestrator = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonPresentationBuilder = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const BiomeProfile = preload("res://src/dungeon_generator/presentation/biome_profile.gd")
const CellGrid = preload("res://src/dungeon_generator/core/data/cell_grid.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_presentation_atomic_swap (End-to-End Pipeline) ---")
	print("==================================================================")

	var pipeline := DungeonPipeline.new()
	var semantic_orchestrator := SemanticOrchestrator.new()
	var presentation_builder := DungeonPresentationBuilder.new()
	var default_biome := BiomeProfile.new()

	var parent_node := Node3D.new()
	root.add_child(parent_node)

	var total_seeds: int = 1000

	# -------------------------------------------------------------------------
	# FASE 1: Validación de Caso A (Presentación Válida) y Caso B (Boss Integration)
	# -------------------------------------------------------------------------
	print("\n>> Ejecutando Caso A y Caso B sobre %d seeds..." % total_seeds)

	for i in range(total_seeds):
		var seed_val: int = 200000 + i

		var config := DungeonConfig.new()
		config.seed = seed_val
		config.use_fixed_seed = true
		config.mission_depth = 5
		config.boss_enabled = true

		# 1. Generar DungeonResult base
		var d_res: DungeonResult = pipeline.generate(
			config,
			DungeonPipeline.MAX_ATTEMPTS,
			true,
			false
		)
		assert(d_res != null, "Seed %d: Pipeline returned null DungeonResult" % seed_val)

		# 2. Generar capa semántica
		var sem_res: DungeonSemanticResult = semantic_orchestrator.generate_semantics(
			d_res,
			config
		)
		assert(sem_res != null and sem_res.gameplay_valid, "Seed %d: SemanticResult invalid" % seed_val)

		# 3. Construir presentación con PresentationBuilder
		var pres_res = presentation_builder.build_presentation(
			sem_res,
			parent_node,
			default_biome,
			config,
			null,
			true
		)

		# Contrato Caso A: Presentación válida
		assert(pres_res != null, "Seed %d: PresentationResult is null" % seed_val)
		assert(pres_res.success == true, "Seed %d: PresentationResult.success should be true" % seed_val)
		assert(pres_res.staging_committed == true, "Seed %d: Staging must be committed" % seed_val)
		assert(pres_res.previous_presentation_preserved == false, "Seed %d: No previous presentation to preserve" % seed_val)
		assert(pres_res.presentation_root != null, "Seed %d: presentation_root must not be null" % seed_val)
		assert(pres_res.presentation_root.name == "DungeonPresentation", "Seed %d: presentation_root must be named 'DungeonPresentation'" % seed_val)
		assert(parent_node.get_child_count() == 1, "Seed %d: parent_node must have exactly 1 child" % seed_val)
		assert(parent_node.get_child(0) == pres_res.presentation_root, "Seed %d: parent child must be presentation_root" % seed_val)

		# Jerarquía mínima esperada en presentation_root
		var pres_root: Node3D = pres_res.presentation_root
		assert(pres_root.has_node("FloorGridMap"), "Seed %d: Missing FloorGridMap" % seed_val)
		assert(pres_root.has_node("WallGridMap"), "Seed %d: Missing WallGridMap" % seed_val)
		assert(pres_root.has_node("Entities"), "Seed %d: Missing Entities node" % seed_val)

		var entities_node := pres_root.get_node("Entities")
		assert(entities_node.has_node("Objectives"), "Seed %d: Missing Objectives container" % seed_val)
		var objectives_node := entities_node.get_node("Objectives")

		# Contrato Caso B: Boss materializado dentro de presentation_root
		var boss_node: Node3D = null
		for child in objectives_node.get_children():
			if child is Node3D and child.has_meta("type"):
				if child.get_meta("type") == ObjectiveData.ObjectiveType.BOSS:
					boss_node = child as Node3D
					break

		assert(boss_node != null, "Seed %d: Boss node not found inside Entities/Objectives" % seed_val)
		assert(boss_node.get_meta("room_id") == sem_res.boss_room_id, "Seed %d: Boss room_id meta mismatch" % seed_val)
		assert(boss_node.get_meta("type") == ObjectiveData.ObjectiveType.BOSS, "Seed %d: Boss type meta mismatch" % seed_val)

		# Validar coincidencia de posición del Boss en mundo 3D
		var boss_room: RoomData = null
		for r in sem_res.rooms:
			if r != null and r.id == sem_res.boss_room_id:
				boss_room = r
				break
		assert(boss_room != null, "Seed %d: Boss room %d not found" % [seed_val, sem_res.boss_room_id])

		var expected_grid_pos: Vector2i = boss_room.get_walkable_point(sem_res.grid)
		var expected_world_pos := Vector3(
			(expected_grid_pos.x + 0.5) * config.cell_size,
			0.2,
			(expected_grid_pos.y + 0.5) * config.cell_size
		)
		assert(
			boss_node.position.is_equal_approx(expected_world_pos),
			"Seed %d: Boss position mismatch: %s vs expected %s" % [seed_val, str(boss_node.position), str(expected_world_pos)]
		)

		# Limpiar para la siguiente iteración
		parent_node.remove_child(pres_root)
		pres_root.free()

	print("  [PASS] Caso A y Caso B validados exitosamente en %d seeds." % total_seeds)

	# -------------------------------------------------------------------------
	# FASE 2: Validación de Caso C (Atomic Swap & Rollback)
	# -------------------------------------------------------------------------
	print("\n>> Ejecutando Caso C: Atomic Swap & Rollback...")

	# 1. Configurar presentación inicial A
	var config_a := DungeonConfig.new()
	config_a.seed = 300001
	config_a.use_fixed_seed = true
	var d_res_a = pipeline.generate(config_a)
	var sem_res_a = semantic_orchestrator.generate_semantics(d_res_a, config_a)
	var pres_res_a = presentation_builder.build_presentation(
		sem_res_a,
		parent_node,
		default_biome,
		config_a,
		null,
		true
	)
	assert(pres_res_a.success == true, "Build A must succeed")
	var node_a: Node3D = pres_res_a.presentation_root
	assert(node_a != null and parent_node.get_child(0) == node_a, "Node A must be active child")

	# 2. Atomic Swap Exitoso: A -> B
	var config_b := DungeonConfig.new()
	config_b.seed = 300002
	config_b.use_fixed_seed = true
	var d_res_b = pipeline.generate(config_b)
	var sem_res_b = semantic_orchestrator.generate_semantics(d_res_b, config_b)

	var pres_res_b = presentation_builder.build_presentation(
		sem_res_b,
		parent_node,
		default_biome,
		config_b,
		node_a, # active_presentation
		true
	)

	assert(pres_res_b.success == true, "Atomic Swap A -> B must succeed")
	assert(pres_res_b.staging_committed == true, "Staging B must be committed")
	assert(pres_res_b.previous_presentation_preserved == false, "Previous presentation was replaced")
	var node_b: Node3D = pres_res_b.presentation_root
	assert(node_b != null and node_b != node_a, "Node B must be a new instance")
	assert(parent_node.get_child_count() == 1, "Parent must have exactly 1 child after swap")
	assert(parent_node.get_child(0) == node_b, "Parent child must be Node B")
	print("  [OK] C.1 - Atomic Swap exitoso (A reemplazado por B de forma segura).")

	# 3. Rollback ante fallo semántico (gameplay_valid = false) con B activo
	var invalid_sem_res = DungeonSemanticResult.new()
	invalid_sem_res.gameplay_valid = false # Provoca fallo de validación
	invalid_sem_res.grid = CellGrid.new(10, 10)

	var pres_res_c = presentation_builder.build_presentation(
		invalid_sem_res,
		parent_node,
		default_biome,
		config_b,
		node_b, # active_presentation
		true
	)

	assert(pres_res_c.success == false, "Build C must fail on invalid semantics")
	assert(pres_res_c.staging_committed == false, "Staging C must NOT be committed")
	assert(pres_res_c.previous_presentation_preserved == true, "Node B must be preserved")
	assert(pres_res_c.presentation_root == node_b, "Active root must remain Node B")
	assert(parent_node.get_child_count() == 1, "Parent must still have exactly 1 child")
	assert(parent_node.get_child(0) == node_b, "Node B must remain attached to parent")
	assert(pres_res_c.has_blocking_errors() == true, "Diagnostics must indicate blocking error")
	print("  [OK] C.2 - Rollback por semántica inválida verificado (B preservado intacto).")

	# 4. Rollback ante fallo de materialización (bloqueo por assets faltantes sin placeholder)
	var strict_biome := BiomeProfile.new()
	strict_biome.mesh_library = null

	var pres_res_d = presentation_builder.build_presentation(
		sem_res_b,
		parent_node,
		strict_biome,
		config_b,
		node_b, # active_presentation
		false   # use_placeholders_if_needed = false -> provoca MISSING_MESH_LIBRARY FATAL
	)

	assert(pres_res_d.success == false, "Build D must fail when assets missing & fallback disabled")
	assert(pres_res_d.staging_committed == false, "Staging D must NOT be committed")
	assert(pres_res_d.previous_presentation_preserved == true, "Node B must remain preserved")
	assert(pres_res_d.presentation_root == node_b, "Active presentation must remain Node B")
	assert(parent_node.get_child_count() == 1, "Parent child count must remain 1")
	assert(parent_node.get_child(0) == node_b, "Parent child must still be Node B")
	assert(pres_res_d.has_blocking_errors() == true, "Must have blocking fatal diagnostic")
	print("  [OK] C.3 - Rollback por error de materialización/MeshLibrary verificado (B preservado intacto).")

	# Limpieza final
	node_b.free()
	parent_node.free()

	print("\n==================================================================")
	print("[PASS] test_presentation_atomic_swap ejecutado con 100% éxito!")
	print("==================================================================")
	quit(0)
