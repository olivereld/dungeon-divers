extends SceneTree

const RockSizeProfile = preload("res://src/rock_generation/rock_size_profile.gd")
const RockMeshBuilder = preload("res://src/rock_generation/rock_mesh_builder.gd")
const RockMaterial = preload("res://src/rock_generation/rock_material.gd")
const RockInstance = preload("res://src/rock_generation/rock_instance.gd")
const RockDistribution = preload("res://src/rock_generation/rock_distribution.gd")
const RockGeneration = preload("res://src/rock_generation/rock_generation.gd")

## Test runner unitario e independiente para el módulo procedural de rocas.
## Ejecutar con: Godot_v4.6.1-stable_win64_console.exe --headless --script res://src/rock_generation/tests/test_rock_generation.gd

func _init() -> void:
	print("\n=======================================================")
	print("--- INICIANDO TEST DEL MODULO ROCK GENERATION ---")
	print("=======================================================")

	var passed: int = 0
	var total: int = 0

	# 1. Test RockSizeProfile
	total += 1
	if _test_rock_size_profiles():
		passed += 1
		print("[PASS] 1. RockSizeProfiles configurados correctamente")
	else:
		printerr("[FAIL] 1. Fallo en RockSizeProfiles")

	# 2. Test RockMeshBuilder
	total += 1
	if _test_mesh_builder():
		passed += 1
		print("[PASS] 2. RockMeshBuilder genera geometría facetada válida")
	else:
		printerr("[FAIL] 2. Fallo en RockMeshBuilder")

	# 3. Test RockMaterial
	total += 1
	if _test_rock_material():
		passed += 1
		print("[PASS] 3. RockMaterial y Shader cargados correctamente")
	else:
		printerr("[FAIL] 3. Fallo en RockMaterial")

	# 4. Test RockInstance
	total += 1
	if _test_rock_instance():
		passed += 1
		print("[PASS] 4. RockInstance calcula transforms deterministas y variación")
	else:
		printerr("[FAIL] 4. Fallo en RockInstance")

	# 5. Test RockDistribution & Clusters
	total += 1
	if _test_rock_distribution():
		passed += 1
		print("[PASS] 5. RockDistribution genera rocas y clusters respetando filtros")
	else:
		printerr("[FAIL] 5. Fallo en RockDistribution")

	# 6. Test RockGeneration Facade & MultiMesh
	total += 1
	if _test_rock_generation_facade():
		passed += 1
		print("[PASS] 6. RockGeneration fachada y MultiMeshes generados con éxito")
	else:
		printerr("[FAIL] 6. Fallo en RockGeneration fachada")

	print("\n=======================================================")
	print("RESULTADO FINAL: %d / %d tests superados." % [passed, total])
	print("=======================================================\n")

	if passed == total:
		quit(0)
	else:
		quit(1)

func _test_rock_size_profiles() -> bool:
	var profiles: Dictionary = RockSizeProfile.get_all_profiles()
	if profiles.size() != 3:
		printerr("Debe haber exactamente 3 perfiles de tamaño.")
		return false

	var large: RockSizeProfile = profiles[RockSizeProfile.Category.LARGE]
	var medium: RockSizeProfile = profiles[RockSizeProfile.Category.MEDIUM]
	var small: RockSizeProfile = profiles[RockSizeProfile.Category.SMALL]

	if large.min_scale < 2.0 or large.max_scale < 4.0:
		printerr("Perfil grande fuera de rango esperado.")
		return false

	if medium.min_scale < 0.8 or medium.max_scale > 3.0:
		printerr("Perfil mediano fuera de rango esperado.")
		return false

	if small.min_scale < 0.1 or small.max_scale > 0.9:
		printerr("Perfil minúsculo fuera de rango esperado.")
		return false

	return true

func _test_mesh_builder() -> bool:
	var large_prof: RockSizeProfile = RockSizeProfile.create_large()
	var mesh1: ArrayMesh = RockMeshBuilder.build_rock_mesh(large_prof, 12345)
	if mesh1 == null or mesh1.get_surface_count() == 0:
		printerr("No se pudo construir la malla.")
		return false

	var arrays: Array = mesh1.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	if verts.is_empty() or normals.is_empty():
		printerr("Vértices o normales vacíos.")
		return false

	# Verificar que no hay normales nulas
	for n in normals:
		if n.is_zero_approx():
			printerr("Se encontró una normal nula en la malla.")
			return false

	# Verificar determinismo
	var mesh2: ArrayMesh = RockMeshBuilder.build_rock_mesh(large_prof, 12345)
	var verts2: PackedVector3Array = mesh2.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if verts.size() != verts2.size() or verts[0] != verts2[0]:
		printerr("La generación de mallas no es determinista con la misma semilla.")
		return false

	return true

func _test_rock_material() -> bool:
	var mat: ShaderMaterial = RockMaterial.create_rock_material()
	if mat == null:
		printerr("No se pudo crear el ShaderMaterial.")
		return false

	if mat.shader == null:
		printerr("El shader no fue asignado al material.")
		return false

	return true

func _test_rock_instance() -> bool:
	var prof: RockSizeProfile = RockSizeProfile.create_medium()
	var inst1: RockInstance = RockInstance.create(Vector3(10, 2, 10), prof, 555)
	var inst2: RockInstance = RockInstance.create(Vector3(10, 2, 10), prof, 555)

	# Verificar determinismo
	if inst1.transform != inst2.transform:
		printerr("Las instancias con la misma semilla tienen transforms distintos.")
		return false

	# Verificar escala no uniforme
	if is_equal_approx(inst1.scale.x, inst1.scale.y) and is_equal_approx(inst1.scale.y, inst1.scale.z):
		printerr("La escala no debería ser estrictamente simétrica uniforme.")
		return false

	# Verificar que custom_data contiene variación válida
	if inst1.custom_data.r < 0.1 or inst1.custom_data.r > 0.9:
		printerr("Variación de material fuera de límites esperados.")
		return false

	return true

func _test_rock_distribution() -> bool:
	var profiles: Dictionary = RockSizeProfile.get_all_profiles()
	var bounds: Rect2 = Rect2(0, 0, 48, 48)

	# Mock de terreno: plano con elevación 5.0, pero con un lago en x > 40
	var mock_terrain: Callable = func(x: float, z: float) -> Dictionary:
		if x > 40.0:
			return {"is_water": true}
		return {
			"valid": true,
			"height": 5.0,
			"normal": Vector3.UP
		}

	var instances: Array[RockInstance] = RockDistribution.generate_area_rocks(bounds, 9999, profiles, mock_terrain)

	if instances.is_empty():
		printerr("No se generó ninguna roca en el área.")
		return false

	# Ninguna roca debe estar en la zona de agua (x > 40)
	for inst in instances:
		if inst.position.x > 40.0:
			printerr("Se generó una roca dentro del agua en x = %f" % inst.position.x)
			return false

	# Debe haber al menos rocas de tamaño mediano o pequeño
	var has_small: bool = false
	var has_med: bool = false
	for inst in instances:
		if inst.category == RockSizeProfile.Category.SMALL:
			has_small = true
		elif inst.category == RockSizeProfile.Category.MEDIUM:
			has_med = true

	if not (has_small and has_med):
		printerr("La distribución debe contener tanto rocas medianas como pequeñas.")
		return false

	return true

func _test_rock_generation_facade() -> bool:
	var rock_gen: RockGeneration = RockGeneration.new(777)

	# Verificar mallas pregeneradas
	var mesh_l: ArrayMesh = rock_gen.get_mesh(RockSizeProfile.Category.LARGE, 0)
	var mesh_m: ArrayMesh = rock_gen.get_mesh(RockSizeProfile.Category.MEDIUM, 0)
	var mesh_s: ArrayMesh = rock_gen.get_mesh(RockSizeProfile.Category.SMALL, 0)

	if mesh_l == null or mesh_m == null or mesh_s == null:
		printerr("No se pregeneraron todas las mallas en la fachada.")
		return false

	# Generar instancias y MultiMeshes
	var bounds: Rect2 = Rect2(0, 0, 32, 32)
	var instances: Array[RockInstance] = rock_gen.generate_instances(bounds, 777)
	var multimesh_nodes: Array[MultiMeshInstance3D] = rock_gen.create_multimesh_nodes(instances)

	if multimesh_nodes.is_empty():
		printerr("No se generaron nodos MultiMeshInstance3D.")
		return false

	for mmi in multimesh_nodes:
		if mmi.multimesh == null:
			printerr("El MultiMeshInstance3D no tiene MultiMesh asignado.")
			return false
		if mmi.multimesh.instance_count <= 0:
			printerr("El MultiMesh tiene 0 instancias.")
			return false

	return true
