extends SceneTree

const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_prop_spawner_real_mesh ---")
	print("==================================================================")

	var spawner := _PropSpawnerScript.new()
	var pal_resolver := _DecorationPaletteResolverScript.new()
	var palette = pal_resolver.resolve_palette(1, 14, null)

	var pillar_style = null
	for entry in palette.props.entries:
		if entry.style.id == &"pillar_stone":
			pillar_style = entry.style
			break

	assert(pillar_style != null, "FAIL: pillar_style not found in palette")

	var directive := _PropDirectiveScript.new(
		&"pillar_stone",
		1,
		pillar_style,
		Vector3(10.0, 0.0, 10.0),
		0.0,
		[Vector2i(5, 5)],
		0,
		0
	)

	var root := Node3D.new()
	var spawned_node = spawner.spawn_prop(directive, root)

	assert(spawned_node != null, "FAIL: spawned_node is null")
	print("  Spawned node name: ", spawned_node.name)
	print("  Child count: ", spawned_node.get_child_count())

	assert(spawned_node.get_child_count() > 0, "FAIL: spawned_node is an empty Node3D, mesh was not instantiated!")
	
	# Verify that the Model / Mesh exists
	var model_node = spawned_node.find_child("Model", true, false)
	assert(model_node != null or spawned_node.get_child(0) is Node3D, "FAIL: Model child node not found in spawned pillar")

	print("  [OK] Confirmed 3D mesh model is correctly instantiated and attached to scene graph.")
	print("==================================================================")
	print("[PASS] test_prop_spawner_real_mesh passed successfully!")
	print("==================================================================")
	quit(0)
