extends SceneTree

func _init() -> void:
	print("--- Testing TaigaWorld UI & Tabs ---")
	var scene = load("res://src/world_renderer/scenes/taiga_world.tscn").instantiate()
	root.add_child(scene)
	scene._ready()

	assert(scene != null, "Scene must instantiate")
	assert(scene.ui_root != null, "UI root must exist")
	assert(scene.left_panel != null, "Left panel must exist")
	assert(scene.right_panel != null, "Right panel must exist")
	assert(scene.top_bar != null, "Top bar must exist")
	assert(scene.bottom_bar != null, "Bottom bar must exist")

	# Test Tab 1: Telemetry
	scene._set_active_tab(scene.RightTab.TELEMETRY)
	assert(scene.panel_telemetry.visible == true)
	assert(scene.panel_noise.visible == false)
	assert(scene.panel_colors.visible == false)

	# Test Tab 2: Noise textures
	scene._set_active_tab(scene.RightTab.NOISE)
	assert(scene.panel_telemetry.visible == false)
	assert(scene.panel_noise.visible == true)
	assert(scene.panel_colors.visible == false)
	assert(scene.tex_rect_height.texture != null, "Height texture must be generated")
	assert(scene.tex_rect_warp.texture != null, "Warp texture must be generated")
	assert(scene.tex_rect_eco.texture != null, "Ecology texture must be generated")
	assert(scene.tex_rect_composite.texture != null, "Composite texture must be generated")

	# Test Tab 3: Colors
	scene._set_active_tab(scene.RightTab.COLORS)
	assert(scene.panel_telemetry.visible == false)
	assert(scene.panel_noise.visible == false)
	assert(scene.panel_colors.visible == true)
	assert(scene.panel_hydrology.visible == false)
	assert(scene.gradient_preview_rect.texture != null, "Gradient bar preview must be generated")
	assert(scene.color_pickers.size() == 8, "Must have 8 zone color pickers")

	# Test Tab 4: Hydrology Debug Visualization
	scene._set_active_tab(scene.RightTab.HYDROLOGY)
	assert(scene.panel_telemetry.visible == false)
	assert(scene.panel_noise.visible == false)
	assert(scene.panel_colors.visible == false)
	assert(scene.panel_hydrology.visible == true)
	assert(scene.hydro_debug_rect.texture != null, "Hydrology debug map texture must be generated")
	assert(scene.hydro_stat_lakes_lbl.text != "", "Hydrology lake telemetry must be populated")
	assert(scene.hydro_stat_rivers_lbl.text != "", "Hydrology river telemetry must be populated")

	# Cycle debug modes to verify texture generation for all layers
	for mode in [scene.HydroDebugMode.NOISE, scene.HydroDebugMode.LAKE_POTENTIAL, scene.HydroDebugMode.RIVER_POTENTIAL, scene.HydroDebugMode.DRAINAGE, scene.HydroDebugMode.FLOW_DIR, scene.HydroDebugMode.DEPTH, scene.HydroDebugMode.BODIES]:
		scene.current_hydro_debug_mode = mode
		scene._update_hydrology_debug_view()
		assert(scene.hydro_debug_rect.texture != null, "Debug layer %s must produce valid texture" % str(mode))

	# Test LeftPanel Sliders for Scale and Hydrology
	assert(scene._sliders.has("cell_size"), "LeftPanel must have cell_size scale slider")
	assert(scene._sliders.has("lake_threshold"), "LeftPanel must have lake_threshold slider")
	assert(scene._sliders.has("max_rivers"), "LeftPanel must have max_rivers slider")
	assert(scene._sliders.has("hydrology_noise_strength"), "LeftPanel must have hydrology_noise_strength slider")

	# Test color preset change
	scene._apply_color_preset("Mundo Alien")
	assert(scene.profile.color_deep_water == Color("#1a0a3a"))

	# Test terrain preset change
	scene._on_preset_selected(1)
	assert(scene.profile.macro_strength == 16.0)

	# Test Player Testing Module & Collision
	assert(scene.test_player != null, "PlayerTest instance must be spawned in the scene")
	assert(scene.test_player.get_parent() != null, "PlayerTest must be attached to WorldContainer")
	assert(scene.camera_rig.target == scene.test_player, "Camera rig must follow test player when active")

	# Check terrain collision exists
	assert(scene.current_world_node.has_node("TerrainCollision"), "TerrainCollision must exist for player walking")
	var col: StaticBody3D = scene.current_world_node.get_node("TerrainCollision")
	assert(col.get_child_count() > 0, "TerrainCollision must have a CollisionShape3D")
	var shape: CollisionShape3D = col.get_child(0)
	assert(shape.shape is ConcavePolygonShape3D, "Terrain collision must be a trimesh concave polygon shape")

	# Test toggling player
	scene._toggle_player()
	assert(scene.is_player_active == false)
	assert(scene.camera_rig.target == scene.focus_target, "Camera must revert to focus_target when player is OFF")

	scene._toggle_player()
	assert(scene.is_player_active == true)
	assert(scene.camera_rig.target == scene.test_player, "Camera must re-target test_player when player is ON")

	scene.free()
	print("test_taiga_world_ui: ALL PASSED OK")
	quit()
