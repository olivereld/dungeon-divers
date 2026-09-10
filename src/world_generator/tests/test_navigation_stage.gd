extends SceneTree

func _init() -> void:
	var profile := TaigaWorldProfile.new()
	var context := WorldGenerationContext.new(123, profile)
	TerrainStage.new().execute(context)
	NavigationStage.new().execute(context)

	assert(context.result.spawn_position != Vector3.ZERO)
	var spawn_cell := context.result.get_cell(Vector2i(int(context.result.spawn_position.x), int(context.result.spawn_position.z)))
	assert(spawn_cell.is_walkable, "Spawn cell must be walkable")
	assert(spawn_cell.slope <= profile.max_walkable_slope)

	print("test_navigation_stage: OK")
	quit()
