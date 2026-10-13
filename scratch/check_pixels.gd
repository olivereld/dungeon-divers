extends SceneTree

const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _PlayerTestScript = preload("res://src/character_test/player_test.gd")
const _VisualizerScript = preload("res://src/world_generator/navigation/world_navigation_visualizer.gd")

func _init() -> void:
	var profile = _AutumnForestWorldProfileScript.new()
	var config = _ChunkConfigScript.new(16, 1, 3)
	var world_seed = 12345
	var shared_hydrology = _WorldPipelineScript.generate_regional_hydrology(world_seed, profile)

	var chunk_world = _ChunkWorldScript.new()
	chunk_world.render_distance = 3
	root.add_child(chunk_world)
	chunk_world.initialize(world_seed, profile, config, shared_hydrology, 3)
	chunk_world.load_initial_area(Vector2i.ZERO, 3)

	var nav_grid = chunk_world.navigation_grid
	var player = _PlayerTestScript.new()
	root.add_child(player)
	player.setup_movement(nav_grid, null, Vector2i(8, 18))

	var vis = _VisualizerScript.new()
	vis.enabled = true
	root.add_child(vis)
	vis.setup(nav_grid, player)
	vis.refresh(true)

	print("Visualizer mesh created: ", vis._mesh_instance.mesh != null)
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(vis._mesh_instance.mesh, 0)
	print("Total faces: ", mdt.get_face_count())

	# Count faces by color
	var colors := {}
	for f in range(mdt.get_face_count()):
		var v0 = mdt.get_face_vertex(f, 0)
		var c = mdt.get_vertex_color(v0)
		var c_str = "R=%.2f G=%.2f B=%.2f A=%.2f" % [c.r, c.g, c.b, c.a]
		colors[c_str] = colors.get(c_str, 0) + 1

	for k in colors:
		print("Color: ", k, " -> faces: ", colors[k])

	# Now let's check which cells get which color specifically for neighbors of (8, 18)
	var p_profile = player.movement_component.profile
	for dir in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var c = Vector2i(8, 18) + dir
		var el = nav_grid.get_elevation_level(c) if nav_grid.has_cell(c) else -1
		var h = nav_grid.get_height(c) if nav_grid.has_cell(c) else -1.0
		var w = nav_grid.is_walkable(c) if nav_grid.has_cell(c) else false
		var j = vis._evaluate_jumpable_edges(c, p_profile)
		print("Neighbor (8,18)+", dir, " = ", c, " el=", el, " h=", h, " w=", w, " can_down=", j.can_jump_down, " can_up=", j.can_jump_up)

	quit(0)
