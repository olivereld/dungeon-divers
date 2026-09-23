extends SceneTree

## Test suite de validación:
## 1. Estilo Bosque Otoñal (AutumnForestWorldProfile y TaigaWorldProfile.apply_autumn_preset)
## 2. Texturas de Terreno y Agua del proyecto (TerrainMaterial, WaterMaterial, Shaders)
## 3. Cámara Isométrica (IsometricCameraRig + PlayerTest + ChunkWorld)

const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _TerrainMaterialScript = preload("res://src/world_generator/presentation/terrain_material.gd")
const _WaterMaterialScript = preload("res://src/world_generator/presentation/water/water_material.gd")
const _IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")
const _PlayerTestScript = preload("res://src/character_test/player_test.gd")
const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _WorldRendererScript = preload("res://src/world_renderer/world_renderer.gd")
const _WorldVegetationItemScript = preload("res://src/world_generator/data/world_vegetation_item.gd")
const _ChunkWorldIntegrationScript = preload("res://src/world_generator/scenes/chunk_world_integration.gd")

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("==================================================")
	print(" VALIDACIÓN: BOSQUE OTOÑAL, TEXTURAS Y CÁMARA")
	print("==================================================")

	_test_autumn_profiles()
	_test_terrain_material_and_textures()
	_test_water_material_and_textures()
	_test_vegetation_autumn_multi_tint()
	_test_isometric_camera_and_player()
	await _test_chunk_world_integration_scene()

	print("==================================================")
	print(" TODOS LOS TESTS OTOÑAL/TEXTURAS/CÁMARA PASARON OK")
	print("==================================================")
	quit(0)

func _test_autumn_profiles() -> void:
	print("[1/6] Validando AutumnForestWorldProfile y preset otoñal...")

	var profile := _AutumnForestWorldProfileScript.new()
	assert(profile != null, "FAIL: AutumnForestWorldProfile must instantiate")
	assert(profile.terrain_loam_color == Color("#422b1e"), "FAIL: loam color mismatch")
	assert(profile.terrain_moss_color == Color("#736835"), "FAIL: moss color mismatch")
	assert(profile.terrain_grass_color == Color("#5a5428"), "FAIL: grass color mismatch")
	assert(profile.forest_floor_color == Color("#3d2817"), "FAIL: forest floor color mismatch")
	assert(profile.water_color_shallow == Color("#355568"), "FAIL: shallow water color mismatch")
	assert(profile.water_color_lake == Color("#182836"), "FAIL: lake water color mismatch")
	assert(not profile.foliage_tint_variants.is_empty(), "FAIL: foliage tint variants must not be empty")

	var taiga := _TaigaWorldProfileScript.new()
	taiga.apply_autumn_preset()
	assert(taiga.terrain_grass_color == Color("#5a5428"), "FAIL: taiga apply_autumn_preset mismatch")
	assert(taiga.foliage_tint == Color("#d97706"), "FAIL: taiga autumn foliage_tint mismatch")
	print("      -> Perfiles otoñales verificados OK.")

func _test_terrain_material_and_textures() -> void:
	print("[2/6] Validando TerrainMaterial con texturas del proyecto y tintes...")

	var profile := _AutumnForestWorldProfileScript.new()
	var mat = _TerrainMaterialScript.create_material(profile, true)
	assert(mat is ShaderMaterial, "FAIL: TerrainMaterial must return ShaderMaterial")

	var sm := mat as ShaderMaterial
	assert(sm.get_shader_parameter("riverbed_texture") != null, "FAIL: riverbed_texture missing")
	assert(sm.get_shader_parameter("sand_texture") != null, "FAIL: sand_texture missing")
	assert(sm.get_shader_parameter("grass_texture") != null, "FAIL: grass_texture missing")
	assert(sm.get_shader_parameter("forest_grass_texture") != null, "FAIL: forest_grass_texture missing")
	assert(sm.get_shader_parameter("forest_dirt_texture") != null, "FAIL: forest_dirt_texture missing")

	var g_tint: Color = sm.get_shader_parameter("grass_tint")
	assert(g_tint != Color.WHITE, "FAIL: grass_tint should be tinted by autumn profile")
	print("      -> TerrainMaterial texturas y tintes verificados OK.")

func _test_water_material_and_textures() -> void:
	print("[3/6] Validando WaterMaterial con textura Water_01 y colores otoñales...")

	var profile := _AutumnForestWorldProfileScript.new()
	var mat = _WaterMaterialScript.create_water_material(profile, true)
	assert(mat is ShaderMaterial, "FAIL: WaterMaterial must return ShaderMaterial")

	var sm := mat as ShaderMaterial
	var w_tex = sm.get_shader_parameter("water_texture")
	assert(w_tex != null, "FAIL: water_texture must be set from Water_01.png")

	var c_shore: Color = sm.get_shader_parameter("color_shore")
	var c_deep: Color = sm.get_shader_parameter("color_deep")
	assert(is_equal_approx(c_deep.r, profile.water_color_lake.r), "FAIL: deep water color must match profile lake color")
	print("      -> WaterMaterial textura y colores verificados OK.")

func _test_vegetation_autumn_multi_tint() -> void:
	print("[4/6] Validando vegetación con variación cromática otoñal...")

	var root := Node3D.new()
	get_root().add_child(root)

	var profile := _AutumnForestWorldProfileScript.new()
	var items: Array[WorldVegetationItem] = []

	var item1 := _WorldVegetationItemScript.new(WorldVegetationItem.Type.CONIFER, Vector3(10.0, 5.0, 10.0))
	items.append(item1)

	var item2 := _WorldVegetationItemScript.new(WorldVegetationItem.Type.CONIFER, Vector3(25.0, 5.0, 30.0))
	items.append(item2)

	_WorldRendererScript.spawn_vegetation(root, items, Vector3.ZERO, profile)

	var conifers_mmi := root.find_child("Conifers", true, false) as MultiMeshInstance3D
	assert(conifers_mmi != null, "FAIL: Conifers MultiMeshInstance3D must be created")
	assert(conifers_mmi.multimesh != null, "FAIL: MultiMesh must exist")
	assert(conifers_mmi.multimesh.use_colors, "FAIL: MultiMesh should have use_colors=true for autumn foliage variants")

	root.queue_free()
	print("      -> Vegetación MultiMesh con use_colors verificada OK.")

func _test_isometric_camera_and_player() -> void:
	print("[5/6] Validando IsometricCameraRig y vinculación a PlayerTest...")

	var root := Node3D.new()
	get_root().add_child(root)

	var player = _PlayerTestScript.new()
	player.position = Vector3(12.0, 2.0, 12.0)
	root.add_child(player)

	var chunk_world = _ChunkWorldScript.new()
	root.add_child(chunk_world)

	var rig = chunk_world.setup_isometric_camera(player)
	assert(rig != null, "FAIL: setup_isometric_camera must return IsometricCameraRig")
	assert(is_equal_approx(rig.pitch_degrees, 35.264), "FAIL: Pitch must be true isometric ~35.264°")
	assert(is_equal_approx(rig.yaw_degrees, 45.0), "FAIL: Yaw must be 45°")
	assert(rig.target == player, "FAIL: Rig target must be player")

	var initial_zoom: float = rig.get_zoom()
	rig.zoom_in()
	assert(rig.target_zoom < initial_zoom, "FAIL: zoom_in must decrease zoom")
	rig.zoom_out()
	assert(is_equal_approx(rig.target_zoom, initial_zoom), "FAIL: zoom_out must restore zoom")

	root.queue_free()
	print("      -> IsometricCameraRig y setup_isometric_camera verificados OK.")

func _test_chunk_world_integration_scene() -> void:
	print("[6/6] Validando escena ChunkWorldIntegration con perfil otoñal y cámara...")

	var scene_inst = _ChunkWorldIntegrationScript.new()
	get_root().add_child(scene_inst)

	await process_frame

	assert(scene_inst.profile is _AutumnForestWorldProfileScript, "FAIL: Default profile must be AutumnForestWorldProfile")
	assert(scene_inst.camera_rig != null, "FAIL: Scene must have camera_rig instantiated")
	assert(scene_inst.player != null, "FAIL: Scene must have player instantiated")
	assert(scene_inst.camera_rig.target == scene_inst.player, "FAIL: camera_rig target must be player")

	scene_inst.queue_free()
	print("      -> Escena ChunkWorldIntegration verificada OK.")
