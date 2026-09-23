extends SceneTree

## Test formal para generación de cascadas (Waterfall Quads) en WaterMeshBuilder.
## Valida el contrato geométrico:
## 1. Geometría: 1 waterfall quad (4 vértices, 2 triángulos) por desnivel superior -> inferior.
## 2. Cotas exactas: top == water_y superior, bottom == n_wh - 0.05 * cell_size.
## 3. Offset respecto al cliff: desplazado 0.04 * cell_size hacia la celda inferior.
## 4. Orientación de normales para West, East, North y South.
## 5. Mapeo UV: UV.y == 0.0 arriba (cresta), UV.y == 1.0 abajo (base).
## 6. Sin duplicación: celda superior emite, celda inferior no emite.
## 7. Umbral de caída: 6.0 -> 6.0 produce 0, 6.0 -> 5.95 produce 0, 6.0 -> 5.0 produce 1.

const _WaterMeshBuilderScript = preload("res://src/world_generator/presentation/water/water_mesh_builder.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _ChunkDataScript = preload("res://src/world_generator/chunks/chunk_data.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test: Waterfall Mesh Generation")
	print("==================================================")

	_test_west_waterfall()
	_test_east_waterfall()
	_test_north_waterfall()
	_test_south_waterfall()
	_test_no_duplication_and_thresholds()

	print("==================================================")
	print(" ALL WATERFALL MESH GENERATION TESTS PASSED!")
	print("==================================================")
	quit(0)


func _create_chunk_data_with_water(water_dict: Dictionary) -> ChunkData:
	var chunk := _ChunkDataScript.new(Vector2i.ZERO, Rect2i(0, 0, 4, 4), Rect2i(0, 0, 4, 4))
	for y in range(4):
		for x in range(4):
			var p := Vector2i(x, y)
			var c := WorldCell.new(p)
			c.height = 4.0
			chunk.cells[p] = c

	var hydro := HydrologyResult.new()
	for p in water_dict:
		var wh: float = float(water_dict[p])
		hydro.water_cells[p] = {
			"type": "river",
			"water_height": wh,
			"bed_height": wh - 0.5,
			"depth": 0.5,
			"flow_dir": Vector2.ZERO
		}
	chunk.hydrology = hydro
	return chunk


func _test_west_waterfall() -> void:
	print("--- Testing West (-X) Waterfall ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.cell_size = 1.0

	# Celda A en (2, 2) a 6.0m; Celda B al Oeste en (1, 2) a 4.0m
	var chunk := _create_chunk_data_with_water({
		Vector2i(2, 2): 6.0,
		Vector2i(1, 2): 4.0,
	})

	var surf: WaterSurfaceData = _WaterMeshBuilderScript.build_water_surface(chunk, profile)
	assert(surf != null, "Superficie no debe ser null")

	# Filtrar vértices de cascada (abs(normal.y) < 0.5)
	var wf_verts: Array[Vector3] = []
	var wf_normals: Array[Vector3] = []
	var wf_uvs: Array[Vector2] = []
	for i in range(surf.vertices.size()):
		var n := surf.normals[i]
		if absf(n.y) < 0.5:
			wf_verts.append(surf.vertices[i])
			wf_normals.append(n)
			wf_uvs.append(surf.uvs[i])

	assert(wf_verts.size() == 4, "Debe haber exactamente 4 vértices para 1 waterfall quad, se hallaron: %d" % wf_verts.size())
	print("  [PASS] 1 quad de cascada emitido (4 vertices)")

	# Validar normales hacia el Oeste
	for n in wf_normals:
		assert(n.is_equal_approx(Vector3.LEFT), "Normal debe ser Vector3.LEFT, fue %s" % str(n))
	print("  [PASS] Normales apuntan hacia el Oeste (Vector3.LEFT)")

	# Validar cotas y offset:
	# Celda A en x=2 -> límite oeste en x0=2.0.
	# Offset = 0.04 hacia el oeste -> x_wf = 1.96.
	# h_hi = 6.0, h_lo = 4.0 - 0.05 = 3.95.
	var count_top := 0
	var count_bot := 0
	for i in range(4):
		var v := wf_verts[i]
		var uv := wf_uvs[i]
		assert(is_equal_approx(v.x, 1.96), "X debe ser 1.96 (2.0 - 0.04), fue %f" % v.x)
		if is_equal_approx(v.y, 6.0):
			count_top += 1
			assert(is_equal_approx(uv.y, 0.0), "Cresta superior debe tener UV.y == 0.0, fue %f" % uv.y)
		elif is_equal_approx(v.y, 3.95):
			count_bot += 1
			assert(is_equal_approx(uv.y, 1.0), "Base inferior debe tener UV.y == 1.0, fue %f" % uv.y)
		else:
			assert(false, "Vértice Y debe ser 6.0 o 3.95, fue %f" % v.y)

	assert(count_top == 2 and count_bot == 2, "Debe haber 2 vértices arriba y 2 abajo")
	print("  [PASS] Cotas verificadas: Top = 6.0m (UV.y=0.0), Bottom = 3.95m (UV.y=1.0), X = 1.96m")


func _test_east_waterfall() -> void:
	print("--- Testing East (+X) Waterfall ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.cell_size = 1.0

	# Celda A en (1, 2) a 6.0m; Celda B al Este en (2, 2) a 4.0m
	var chunk := _create_chunk_data_with_water({
		Vector2i(1, 2): 6.0,
		Vector2i(2, 2): 4.0,
	})

	var surf: WaterSurfaceData = _WaterMeshBuilderScript.build_water_surface(chunk, profile)
	assert(surf != null)

	var wf_verts: Array[Vector3] = []
	var wf_normals: Array[Vector3] = []
	for i in range(surf.vertices.size()):
		var n := surf.normals[i]
		if absf(n.y) < 0.5:
			wf_verts.append(surf.vertices[i])
			wf_normals.append(n)

	assert(wf_verts.size() == 4, "Debe haber 4 vértices")
	for n in wf_normals:
		assert(n.is_equal_approx(Vector3.RIGHT), "Normal debe ser Vector3.RIGHT")
	# Celda A en x=1 -> límite este en x1=2.0. Offset = +0.04 -> x_wf = 2.04
	for v in wf_verts:
		assert(is_equal_approx(v.x, 2.04), "X debe ser 2.04")
	print("  [PASS] Cascada Este OK: Normal = Vector3.RIGHT, X = 2.04m")


func _test_north_waterfall() -> void:
	print("--- Testing North (-Z) Waterfall ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.cell_size = 1.0

	# Celda A en (2, 2) a 6.0m; Celda B al Norte en (2, 1) a 4.0m
	var chunk := _create_chunk_data_with_water({
		Vector2i(2, 2): 6.0,
		Vector2i(2, 1): 4.0,
	})

	var surf: WaterSurfaceData = _WaterMeshBuilderScript.build_water_surface(chunk, profile)
	assert(surf != null)

	var wf_verts: Array[Vector3] = []
	var wf_normals: Array[Vector3] = []
	for i in range(surf.vertices.size()):
		var n := surf.normals[i]
		if absf(n.y) < 0.5:
			wf_verts.append(surf.vertices[i])
			wf_normals.append(n)

	assert(wf_verts.size() == 4, "Debe haber 4 vértices")
	for n in wf_normals:
		assert(n.is_equal_approx(Vector3.FORWARD), "Normal debe ser Vector3.FORWARD")
	# Celda A en y=2 -> límite norte en z0=2.0. Offset = -0.04 -> z_wf = 1.96
	for v in wf_verts:
		assert(is_equal_approx(v.z, 1.96), "Z debe ser 1.96")
	print("  [PASS] Cascada Norte OK: Normal = Vector3.FORWARD, Z = 1.96m")


func _test_south_waterfall() -> void:
	print("--- Testing South (+Z) Waterfall ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.cell_size = 1.0

	# Celda A en (2, 1) a 6.0m; Celda B al Sur en (2, 2) a 4.0m
	var chunk := _create_chunk_data_with_water({
		Vector2i(2, 1): 6.0,
		Vector2i(2, 2): 4.0,
	})

	var surf: WaterSurfaceData = _WaterMeshBuilderScript.build_water_surface(chunk, profile)
	assert(surf != null)

	var wf_verts: Array[Vector3] = []
	var wf_normals: Array[Vector3] = []
	for i in range(surf.vertices.size()):
		var n := surf.normals[i]
		if absf(n.y) < 0.5:
			wf_verts.append(surf.vertices[i])
			wf_normals.append(n)

	assert(wf_verts.size() == 4, "Debe haber 4 vértices")
	for n in wf_normals:
		assert(n.is_equal_approx(Vector3.BACK), "Normal debe ser Vector3.BACK")
	# Celda A en y=1 -> límite sur en z1=2.0. Offset = +0.04 -> z_wf = 2.04
	for v in wf_verts:
		assert(is_equal_approx(v.z, 2.04), "Z debe ser 2.04")
	print("  [PASS] Cascada Sur OK: Normal = Vector3.BACK, Z = 2.04m")


func _test_no_duplication_and_thresholds() -> void:
	print("--- Testing Duplication & Threshold Rules ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.cell_size = 1.0

	# 1. Caso idéntico: 6.0 -> 6.0 (debe producir 0 cascadas)
	var chunk_equal := _create_chunk_data_with_water({
		Vector2i(1, 1): 6.0,
		Vector2i(2, 1): 6.0,
	})
	var surf_equal = _WaterMeshBuilderScript.build_water_surface(chunk_equal, profile)
	var count_wf_equal := 0
	for n in surf_equal.normals:
		if absf(n.y) < 0.5:
			count_wf_equal += 1
	assert(count_wf_equal == 0, "6.0 -> 6.0 debe producir 0 cascadas")
	print("  [PASS] 6.0 -> 6.0 produce exactamente 0 cascadas")

	# 2. Caso bajo umbral: 6.0 -> 5.95 (caída 0.05 <= 0.10, debe producir 0 cascadas)
	var chunk_sub_thresh := _create_chunk_data_with_water({
		Vector2i(1, 1): 6.0,
		Vector2i(2, 1): 5.95,
	})
	var surf_sub = _WaterMeshBuilderScript.build_water_surface(chunk_sub_thresh, profile)
	var count_wf_sub := 0
	for n in surf_sub.normals:
		if absf(n.y) < 0.5:
			count_wf_sub += 1
	assert(count_wf_sub == 0, "Caída <= 0.10 debe producir 0 cascadas")
	print("  [PASS] Caída 0.05m (<= 0.10m) produce exactamente 0 cascadas")

	# 3. Caso superando umbral: 6.0 -> 5.0 (caída 1.0 > 0.10, debe producir 1 cascada = 4 vértices)
	var chunk_drop := _create_chunk_data_with_water({
		Vector2i(1, 1): 6.0,
		Vector2i(2, 1): 5.0,
	})
	var surf_drop = _WaterMeshBuilderScript.build_water_surface(chunk_drop, profile)
	var count_wf_drop := 0
	for n in surf_drop.normals:
		if absf(n.y) < 0.5:
			count_wf_drop += 1
	assert(count_wf_drop == 4, "Caída > 0.10 debe producir exactamente 1 cascada (4 vértices)")
	print("  [PASS] Caída 1.0m (> 0.10m) produce exactamente 1 cascada (4 vértices)")
