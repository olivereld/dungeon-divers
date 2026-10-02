extends SceneTree

const RockConfig = preload("res://src/rock_generation/config/rock_config.gd")
const RockSizeConfig = preload("res://src/rock_generation/config/rock_size_config.gd")
const RockGeneration = preload("res://src/rock_generation/rock_generation.gd")
const VegetationStage = preload("res://src/world_generator/stages/vegetation_stage.gd")
const WorldProfile = preload("res://src/world_generator/config/world_profile.gd")
const WorldGenerationContext = preload("res://src/world_generator/core/world_generation_context.gd")

func _init() -> void:
	print("==================================================")
	print(" END-TO-END ROCK AUTHORING & RUNTIME TEST")
	print("==================================================")

	var passed := 0
	var total := 0

	# 1. Test canonical JSON files loading
	total += 1
	if _test_canonical_json_loading():
		passed += 1
		print("[PASS] 1. Carga íntegra de taiga, desert y mountain JSON")
	else:
		printerr("[FAIL] 1. Fallo al cargar configs JSON canónicas")

	# 2. Test mesh generation and CW winding for all biomes
	total += 1
	if _test_biome_meshes():
		passed += 1
		print("[PASS] 2. Generación de mallas sólidas con winding horario (CW) verificada")
	else:
		printerr("[FAIL] 2. Fallo en mallas o winding de biomas")

	# 3. Test MultiMesh and Instance generation
	total += 1
	if _test_multimesh_pipeline():
		passed += 1
		print("[PASS] 3. Generación de MultiMeshInstance3D exitosa")
	else:
		printerr("[FAIL] 3. Fallo en MultiMesh pipeline")

	# 4. Test VegetationStage integration with RockConfig
	total += 1
	if _test_vegetation_stage_integration():
		passed += 1
		print("[PASS] 4. Integración runtime VegetationStage <-> RockConfig verificada")
	else:
		printerr("[FAIL] 4. Fallo en VegetationStage integration")

	print("==================================================")
	print("RESULTADO FINAL: %d / %d tests superados." % [passed, total])
	print("==================================================")

	if passed == total:
		quit(0)
	else:
		quit(1)

func _test_canonical_json_loading() -> bool:
	var biomes := ["taiga", "desert", "mountain"]
	for b in biomes:
		var path := "res://assets/config/rocks/%s_rocks.json" % b
		var cfg = RockConfig.new()
		var err: Error = cfg.load_from_json(path)
		if err != OK:
			printerr("Error cargando: ", path, " err=", err)
			return false
		if cfg.biome != b:
			printerr("Bioma mismatch: ", cfg.biome, " vs ", b)
			return false
		if cfg.profiles.size() != 3:
			printerr("Faltan perfiles en: ", b)
			return false
	return true

func _test_biome_meshes() -> bool:
	var biomes := ["taiga", "desert", "mountain"]
	for b in biomes:
		var path := "res://assets/config/rocks/%s_rocks.json" % b
		var rg = RockGeneration.new(5555, path)
		for cat in [RockSizeConfig.Category.LARGE, RockSizeConfig.Category.MEDIUM, RockSizeConfig.Category.SMALL]:
			var mesh: ArrayMesh = rg.get_mesh(cat, 0)
			if mesh == null or mesh.get_surface_count() == 0:
				printerr("Malla nula para bioma ", b, " cat ", cat)
				return false

			var arr = mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]

			if verts.size() < 12 or normals.size() < 12:
				return false

			# Verificar que los triángulos son CW desde el exterior
			var aabb = AABB()
			for v in verts:
				aabb = aabb.expand(v)
			var center = aabb.get_center()

			var cw_count := 0
			var total_tris := verts.size() / 3
			for i in range(0, verts.size(), 3):
				var v0 = verts[i]
				var v1 = verts[i+1]
				var v2 = verts[i+2]
				var tri_center = (v0 + v1 + v2) / 3.0
				var dir = (tri_center - center).normalized()
				var cw_normal = (v2 - v0).cross(v1 - v0).normalized()
				if dir.dot(cw_normal) > 0.0:
					cw_count += 1

			if cw_count != total_tris:
				printerr("Regresión de winding en ", b, ": ", cw_count, "/", total_tris, " CW")
				return false
	return true

func _test_multimesh_pipeline() -> bool:
	var rg = RockGeneration.new(7777, "res://assets/config/rocks/taiga_rocks.json")
	var bounds := Rect2(-30, -30, 60, 60)
	var instances = rg.generate_instances(bounds, 12345)
	if instances.is_empty():
		printerr("No se generaron instancias para el área.")
		return false

	var mm_nodes = rg.create_multimesh_nodes(instances)
	if mm_nodes.is_empty():
		printerr("create_multimesh_nodes devolvió lista vacía.")
		return false

	for node in mm_nodes:
		if node.multimesh == null or node.multimesh.instance_count == 0:
			return false
	return true

func _test_vegetation_stage_integration() -> bool:
	var prof = WorldProfile.new()
	prof.width = 32
	prof.height = 32
	prof.cell_size = 1.0

	var rock_cfg = RockConfig.create_default_taiga()
	rock_cfg.distribution["density"] = 0.90 # Alta densidad para forzar spawn
	prof.set("rock_config", rock_cfg)

	var ctx = WorldGenerationContext.new(12345, prof)
	# Poblar celdas con pendiente adecuada para rocas
	for x in range(32):
		for y in range(32):
			var pos := Vector2i(x, y)
			var cell := WorldCell.new(pos)
			cell.slope = 28.0
			cell.slope_category = 2 # STEEP
			cell.height = 5.0
			ctx.result.cells[pos] = cell

	var stage := VegetationStage.new()
	stage.execute(ctx)

	var rock_count := 0
	for item in ctx.result.vegetation:
		if item.type == WorldVegetationItem.Type.ROCK:
			rock_count += 1

	if rock_count == 0:
		printerr("VegetationStage no generó ninguna roca con RockConfig.")
		return false

	return true
