extends Node3D

@export var world_seed: int = 12345

func _ready() -> void:
	var profile := TaigaWorldProfile.new()
	var result := WorldPipeline.generate(world_seed, profile)

	var renderer := WorldRenderer.new()
	var world_node := renderer.render_world(result, profile.cell_size)
	add_child(world_node)

	# Position camera at spawn overlooking the terrain
	var cam := Camera3D.new()
	cam.name = "InspectionCamera"
	add_child(cam)
	cam.position = result.spawn_position + Vector3(0, 15, 25)
	cam.look_at(result.spawn_position)

	# Directional Sun Light
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	add_child(light)

	print("Taiga World generated and ready at spawn: ", result.spawn_position)
