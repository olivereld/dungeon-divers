extends SceneTree

## Test suite para validar la iluminación real y transmisión de luz en faroles (Lantern Illumination & Shadow Fix).

const LanternGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/lantern_geometry_builder.gd")
const LanternGeometryConfigScript = preload("res://src/geometry_generator/config/lantern_geometry_config.gd")
const FixtureSpawnerScript = preload("res://src/presentation/fixtures/fixture_spawner.gd")
const FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")
const FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_lantern_light_illumination ---")
	print("==================================================================")

	var builder = LanternGeometryBuilderScript.new()
	var spawner = FixtureSpawnerScript.new()

	# 1. Validar que lantern_glass tiene material translúcido y no bloquea sombras
	var cfg_hang = LanternGeometryConfigScript.new(1.0, 6, false, Color(0.85, 0.25, 0.95, 1.0))
	var asset_hang = builder.build_lantern_fixture(cfg_hang)
	assert(asset_hang != null, "FAIL: Hanging lantern generated")

	var glass_gm = asset_hang.get_mesh(&"lantern_glass")
	assert(glass_gm != null and glass_gm.material_slots.has(0), "FAIL: Glass has material slot 0")
	var mat_glass: StandardMaterial3D = glass_gm.material_slots[0] as StandardMaterial3D
	assert(mat_glass != null, "FAIL: Glass material is StandardMaterial3D")
	assert(mat_glass.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "FAIL: Glass material must be transparent")
	assert(mat_glass.emission_enabled == true, "FAIL: Glass material must have emission enabled")
	print("  [OK] Lantern glass material properties (Transparency + Emission) verified.")

	var node_hang: Node3D = asset_hang.to_node3d("LanternTest")
	var found_glass_mi: bool = false
	for child in node_hang.get_children():
		if child is MeshInstance3D and child.name.contains("Glass"):
			found_glass_mi = true
			assert(child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "FAIL: Glass MeshInstance3D must have cast_shadow OFF")
	assert(found_glass_mi, "FAIL: Found Glass MeshInstance3D in to_node3d hierarchy")
	node_hang.free()
	print("  [OK] GeneratedAsset.to_node3d() sets cast_shadow = OFF for glass components.")

	# 2. Validar que FixtureSpawner configura OmniLight3D con shadow_bias y atenuación radial óptima
	var style_lantern = FixtureStyleScript.new(
		&"test_wall_lantern",
		FixtureStyleScript.Type.LANTERN,
		FixturePlacementModeScript.Mode.WALL,
		1.0,
		Vector3(0.0, 2.0, 0.0),
		true,
		0,
		true,
		Color(0.82, 0.38, 0.96, 1.0),
		2.4,
		8.0
	)
	var directive = FixtureDirectiveScript.new(
		style_lantern,
		Vector2i(2, 2),
		0,
		Vector3(4.0, 2.0, 4.0),
		0.0,
		FixturePlacementModeScript.Mode.WALL
	)

	var root_spawn = spawner.spawn_fixture(directive)
	assert(root_spawn != null, "FAIL: Spawned lantern node is null")

	var light_node: OmniLight3D = null
	for child in root_spawn.get_children():
		if child is OmniLight3D:
			light_node = child
			break

	assert(light_node != null, "FAIL: FixtureSpawner must attach an OmniLight3D to lanterns with has_light = true")
	assert(light_node.omni_attenuation == 1.0, "FAIL: OmniLight3D attenuation must be 1.0 for wide radial illumination")
	assert(light_node.shadow_bias >= 0.05, "FAIL: Shadow bias must be >= 0.05 to prevent self-shadowing acne")
	assert(light_node.light_energy >= 2.0, "FAIL: Lantern light energy must provide strong illumination")

	root_spawn.free()
	print("  [OK] FixtureSpawner OmniLight3D illumination parameters verified.")

	print("==================================================================")
	print("[PASS] test_lantern_light_illumination completado con 100% éxito!")
	print("==================================================================")
	quit(0)
