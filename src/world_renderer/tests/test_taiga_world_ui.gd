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
	assert(scene.gradient_preview_rect.texture != null, "Gradient bar preview must be generated")
	assert(scene.color_pickers.size() == 8, "Must have 8 zone color pickers")

	# Test color preset change
	scene._apply_color_preset("Mundo Alien")
	assert(scene.profile.color_deep_water == Color("#1a0a3a"))

	# Test terrain preset change
	scene._on_preset_selected(1)
	assert(scene.profile.macro_strength == 16.0)

	scene.free()
	print("test_taiga_world_ui: ALL PASSED OK")
	quit()
