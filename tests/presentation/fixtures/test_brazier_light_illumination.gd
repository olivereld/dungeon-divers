extends SceneTree

const _BrazierGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/brazier_geometry_builder.gd")
const _BrazierGeometryConfigScript = preload("res://src/geometry_generator/config/brazier_geometry_config.gd")
const _FixtureSpawnerScript = preload("res://src/presentation/fixtures/fixture_spawner.gd")
const _FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _FixturePlacementScript = preload("res://src/presentation/fixtures/fixture_placement.gd")

func _init() -> void:
	print("--- Running test_brazier_light_illumination ---")

	var spawner := _FixtureSpawnerScript.new()
	var style_brazier := _FixtureStyleScript.new(
		&"test_brazier",
		_FixtureStyleScript.Type.BRAZIER,
		_FixturePlacementModeScript.Mode.FLOOR,
		1.0,
		Vector3.ZERO,
		false,
		0,
		true,
		Color(1.0, 0.65, 0.25, 1.0),
		2.6,
		9.0
	)
	var placement := _FixturePlacementScript.new(
		_FixturePlacementModeScript.Mode.FLOOR,
		Vector2i(2, 2),
		Vector3(4.0, 0.0, 4.0),
		Vector3.UP,
		0.0
	)
	var directive := _FixtureDirectiveScript.new(
		style_brazier,
		placement,
		Vector2i(2, 2),
		0,
		_FixtureDirectiveScript.PlacementPurpose.AMBIENT
	)

	var node = spawner.spawn_fixture(directive, 1337)
	assert(node != null, "Brazier node must not be null")

	var light: OmniLight3D = null
	var mesh_instances: Array[MeshInstance3D] = []

	for child in node.get_children():
		if child is OmniLight3D:
			light = child
		elif child is MeshInstance3D:
			mesh_instances.append(child)

	assert(light != null, "Fixture must contain OmniLight3D")
	assert(light.position.y >= 1.20, "Light Y position must be above cup/embers (>= 1.20m), got %f" % light.position.y)
	assert(mesh_instances.size() > 0, "Brazier must contain mesh instances")

	for mi in mesh_instances:
		assert(mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Brazier mesh '%s' must not cast shadow that occludes its own light" % mi.name)

	print("  [OK] Brazier OmniLight3D positioned at Y=%0.2fm above cup" % light.position.y)
	print("  [OK] Brazier mesh instances (%d) have cast_shadow = OFF for full 360 light propagation" % mesh_instances.size())

	node.free()
	print("[PASS] test_brazier_light_illumination completed successfully!")
	quit(0)
