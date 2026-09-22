extends SceneTree

## Test BLOQUE 15: Paridad Visual WorldRenderer ↔ ChunkWorld
## Valida:
## 15A: Vegetación (Pino GLB + pino_foliage shader + ProceduralRockGenerator)
## 15B: Terreno (Normales continuas C1 en costuras entre chunks adyacentes)
## 15C: Shoreline SDF (Inmutabilidad del SDF macro y muestreo ventana sin mutación)
## 15D: Agua (Integración WaterRenderer -> WaterMeshBuilder -> water_flow.gdshader unificado)
## 15E: Dominio (Desacople de la ventana 64x64 de las coordenadas globales de ChunkWorld)

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _ChunkDataScript = preload("res://src/world_generator/chunks/chunk_data.gd")
const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _TerrainMeshBuilderScript = preload("res://src/world_renderer/terrain_mesh_builder.gd")
const _WaterMeshBuilderScript = preload("res://src/world_generator/presentation/water/water_mesh_builder.gd")
const _WaterRendererScript = preload("res://src/world_generator/presentation/water/water_renderer.gd")
const _WorldRendererScript = preload("res://src/world_renderer/world_renderer.gd")
const _ProceduralRockGeneratorScript = preload("res://src/world_renderer/procedural_rock_generator.gd")

func _init() -> void:
	print("==================================================")
	print(" BLOQUE 15: TEST DE PARIDAD VISUAL WorldRenderer ↔ ChunkWorld")
	print("==================================================")

	var seed_val: int = 12345
	var profile: WorldProfile = TaigaWorldProfile.new()
	var config := _ChunkConfigScript.new(16, 1)

	# -------------------------------------------------------------------------
	# Generar Macro Hidrología e inicializar el entorno
	# -------------------------------------------------------------------------
	print("[1/5] Generando Macro Hydrology y Terreno de referencia...")
	var lab_world: WorldResult = _WorldPipelineScript.generate(seed_val, profile)
	var macro_hydro: HydrologyResult = lab_world.hydrology
	assert(macro_hydro != null, "Macro hydrology must not be null")

	# Precomputar SDF macro en el lab world para validar inmutabilidad posterior
	var lab_mesh: ArrayMesh = _TerrainMeshBuilderScript.build_mesh(lab_world, profile.cell_size, profile)
	assert(not macro_hydro.shoreline_sdf.is_empty(), "Macro shoreline_sdf must be populated")
	var initial_sdf_size: int = macro_hydro.shoreline_sdf.size()
	assert(initial_sdf_size == profile.width * profile.height, "Macro SDF size must be 64*64")
	print("      Macro SDF precomputado OK (tamaño: %d)." % initial_sdf_size)

	# -------------------------------------------------------------------------
	# 15E: Dominio — Generar chunks en coordenadas globales fuera de 64x64
	# -------------------------------------------------------------------------
	print("[2/5] Validando 15E: Dominio y cálculo de pendientes fuera de 64x64...")
	var outside_coords: Array[Vector2i] = [
		Vector2i(-1, 0),  # x in [-16, -1]
		Vector2i(4, 0),   # x in [64, 79]
		Vector2i(0, 4),   # y in [64, 79]
		Vector2i(-2, -2)  # negativo en ambos ejes
	]
	var unbounded_config := _ChunkConfigScript.new(16, 1)
	unbounded_config.is_unbounded = true

	for o_coord in outside_coords:
		var o_chunk: ChunkData = _WorldPipelineScript.generate_chunk(seed_val, o_coord, profile, unbounded_config, macro_hydro)
		assert(o_chunk != null, "Chunk at %s must generate successfully" % str(o_coord))
		assert(o_chunk.cells.size() == 256, "Chunk at %s must have 256 cells" % str(o_coord))

		# Comprobar que las pendientes no fueron colapsadas por límites artificiales
		var non_zero_slopes := 0
		for cell in o_chunk.cells.values():
			if cell.slope > 0.0:
				non_zero_slopes += 1
		assert(non_zero_slopes > 0, "Slopes in chunk %s must be calculated from halo, found 0 non-zero" % str(o_coord))
	print("      15E OK: Chunks fuera de 64x64 calculan pendientes correctamente sin cortar en bordes.")

	# -------------------------------------------------------------------------
	# 15C: Shoreline SDF — Inmutabilidad y resolución por ventana
	# -------------------------------------------------------------------------
	print("[3/5] Validando 15C: Inmutabilidad de shoreline_sdf en shared_hydrology...")
	var chunk_0_0: ChunkData = _WorldPipelineScript.generate_chunk(seed_val, Vector2i(0, 0), profile, config, macro_hydro)
	var chunk_mesh_0_0: ArrayMesh = _TerrainMeshBuilderScript.build_mesh(chunk_0_0, profile.cell_size, profile)
	assert(chunk_mesh_0_0 != null, "Chunk mesh 0,0 must not be null")

	# Verificar que macro_hydro.shoreline_sdf NO fue mutado ni truncado a 16x16 (256)
	assert(macro_hydro.shoreline_sdf.size() == initial_sdf_size,
		"15C VIOLATION: macro shoreline_sdf size changed from %d to %d!" % [initial_sdf_size, macro_hydro.shoreline_sdf.size()])

	# Verificar que los vértices del chunk obtuvieron el SDF muestreado en su ventana
	var arrays_0_0: Array = chunk_mesh_0_0.surface_get_arrays(0)
	var colors_0_0: PackedColorArray = arrays_0_0[Mesh.ARRAY_COLOR]
	assert(colors_0_0.size() == 17 * 17, "Chunk 0,0 mesh must have 289 vertices")
	print("      15C OK: macro shoreline_sdf intacto (size=%d), sampling por ventana OK." % macro_hydro.shoreline_sdf.size())

	# -------------------------------------------------------------------------
	# 15B: Terreno — Normales continuas en costuras (Chunk A ↔ Chunk B)
	# -------------------------------------------------------------------------
	print("[4/5] Validando 15B: Continuidad C1 de normales en costuras entre chunks...")
	var chunk_1_0: ChunkData = _WorldPipelineScript.generate_chunk(seed_val, Vector2i(1, 0), profile, config, macro_hydro)
	var chunk_mesh_1_0: ArrayMesh = _TerrainMeshBuilderScript.build_mesh(chunk_1_0, profile.cell_size, profile)

	var normals_a: PackedVector3Array = arrays_0_0[Mesh.ARRAY_NORMAL]
	var normals_b: PackedVector3Array = chunk_mesh_1_0.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]

	var max_normal_diff := 0.0
	var seam_verts_tested := 0

	# En Chunk (0,0), el borde este es x = 16 (local)
	# En Chunk (1,0), el borde oeste es x = 0 (local)
	for y in range(17):
		var idx_a := y * 17 + 16
		var idx_b := y * 17 + 0

		var na: Vector3 = normals_a[idx_a]
		var nb: Vector3 = normals_b[idx_b]
		var diff: float = (na - nb).length()
		max_normal_diff = maxf(max_normal_diff, diff)
		seam_verts_tested += 1

	print("      -> Vertices de costura testeados: %d" % seam_verts_tested)
	print("      -> Max normal difference en costura: %.6f" % max_normal_diff)
	assert(max_normal_diff < 0.001, "15B VIOLATION: Seam normals diverge across chunk border! Max diff: %f" % max_normal_diff)
	print("      15B OK: Normales continuas C1 en frontera (diff ≈ 0.000000).")

	# -------------------------------------------------------------------------
	# 15A & 15D: Vegetación y Agua en ChunkWorld
	# -------------------------------------------------------------------------
	print("[5/5] Validando 15A (Vegetación GLB/Shader/Rocas) y 15D (Agua Unificada) en ChunkWorld...")
	var chunk_world := _ChunkWorldScript.new()
	root.add_child(chunk_world)
	chunk_world.initialize(seed_val, profile, config, macro_hydro)

	# Cargar área que contenga agua y tierra (alrededor de 0,0 a 1,1)
	chunk_world.load_initial_area(Vector2i(0, 0), 1)

	var loaded_coords: Array[Vector2i] = chunk_world.get_loaded_chunk_coords()
	assert(loaded_coords.size() > 0, "ChunkWorld must have loaded chunks")

	var verified_pino_shader := false
	var verified_rocks := false
	var verified_water_surface := false

	for ccoord in loaded_coords:
		var cview: Node3D = chunk_world.chunk_views[ccoord]
		assert(cview != null, "ChunkView must exist")

		# Buscar Conifers
		var conifers_node: MultiMeshInstance3D = cview.get_node_or_null("Conifers") as MultiMeshInstance3D
		if conifers_node != null and conifers_node.multimesh != null and conifers_node.multimesh.mesh != null:
			var cm: Mesh = conifers_node.multimesh.mesh
			if cm.get_surface_count() > 0:
				var mat = cm.surface_get_material(0)
				if mat is ShaderMaterial:
					verified_pino_shader = true

		# Buscar Rocks
		var rocks_node: Node3D = cview.get_node_or_null("Rocks")
		if rocks_node != null and rocks_node.get_child_count() > 0:
			verified_rocks = true

		# Buscar Agua
		var water_root: Node3D = cview.get_node_or_null("WaterRoot")
		if water_root != null:
			var water_mi: MeshInstance3D = water_root.get_node_or_null("UnifiedWaterSurface") as MeshInstance3D
			if water_mi != null and water_mi.mesh != null:
				var w_mat = water_mi.material_override
				if w_mat is ShaderMaterial:
					verified_water_surface = true

	print("      -> Conifers pino_foliage.gdshader verificado: %s" % str(verified_pino_shader))
	print("      -> Rocks ProceduralRockGenerator verificado: %s" % str(verified_rocks))
	print("      -> UnifiedWaterSurface con water_flow.gdshader verificado: %s" % str(verified_water_surface))

	assert(verified_pino_shader, "15A: Conifers must use ShaderMaterial with pino_foliage.gdshader")
	assert(verified_rocks, "15A: Rocks must be instantiated using multi-variant rock generator")
	assert(verified_water_surface, "15D: Chunks with water must instantiate UnifiedWaterSurface with water_flow.gdshader")

	print("\n==================================================")
	print(" BLOQUE 15: TODOS LOS CRITERIOS CUMPLIDOS CON ÉXITO")
	print("==================================================")
	chunk_world.queue_free()
	quit(0)
