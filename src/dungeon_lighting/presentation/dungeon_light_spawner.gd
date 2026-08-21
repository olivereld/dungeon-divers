class_name DungeonLightSpawner
extends RefCounted

## Spawner y materializador 3D de iluminación procedural para mazmorras.
## Crea y organiza antorchas, luces OmniLight3D y controladores de parpadeo en la jerarquía de presentación.

const _LightingResultScript = preload("res://src/dungeon_lighting/data/lighting_result.gd")
const _LightPlacementScript = preload("res://src/dungeon_lighting/data/light_placement.gd")
const _LightingProfileScript = preload("res://src/dungeon_lighting/config/lighting_profile.gd")
const _TorchLightControllerScript = preload("res://src/dungeon_lighting/presentation/torch_light_controller.gd")
const _TorchGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/torch_geometry_builder.gd")

## Spawnea toda la iluminación en el contenedor de presentación StagingRoot.
func spawn_lighting(
	lighting_result: LightingResult,
	staging_root: Node3D,
	profile: LightingProfile = null,
	tile_size: float = 2.0
) -> Dictionary:
	var result := {
		"spawned_lights": [],
		"diagnostics": []
	}

	if lighting_result == null or not lighting_result.has_lights() or staging_root == null:
		return result

	if profile == null:
		profile = _LightingProfileScript.new()

	# 1. Crear jerarquía de contenedores
	var lighting_root := Node3D.new()
	lighting_root.name = "Lighting"
	staging_root.add_child(lighting_root)

	var room_lights_container := Node3D.new()
	room_lights_container.name = "RoomLights"
	lighting_root.add_child(room_lights_container)

	var corridor_lights_container := Node3D.new()
	corridor_lights_container.name = "CorridorLights"
	lighting_root.add_child(corridor_lights_container)

	var half_tile: float = tile_size * 0.5

	# 2. Materializar cada LightPlacement
	for placement in lighting_result.placements:
		if placement == null:
			continue

		var torch_root := Node3D.new()
		torch_root.name = "Torch_%03d" % placement.light_id

		# Calcular posición 3D anclada al muro
		var base_pos := Vector3(
			(float(placement.cell.x) * tile_size) + half_tile,
			profile.wall_mount_height,
			(float(placement.cell.y) * tile_size) + half_tile
		)

		var offset_dist: float = half_tile - profile.wall_mount_offset
		var wall_offset := Vector3.ZERO
		var torch_rot_y: float = 0.0

		match placement.wall_side:
			_LightPlacementScript.WallSide.NORTH:
				wall_offset = Vector3(0.0, 0.0, -offset_dist)
				torch_rot_y = PI
			_LightPlacementScript.WallSide.SOUTH:
				wall_offset = Vector3(0.0, 0.0, offset_dist)
				torch_rot_y = 0.0
			_LightPlacementScript.WallSide.EAST:
				wall_offset = Vector3(offset_dist, 0.0, 0.0)
				torch_rot_y = PI * 0.5
			_LightPlacementScript.WallSide.WEST:
				wall_offset = Vector3(-offset_dist, 0.0, 0.0)
				torch_rot_y = -PI * 0.5

		torch_root.position = base_pos + wall_offset
		torch_root.rotation.y = torch_rot_y

		# Si hay escena de antorcha personalizada, instanciarla
		if profile.torch_scene != null:
			var torch_inst = profile.torch_scene.instantiate()
			torch_root.add_child(torch_inst)
		else:
			# Instanciar fixture 3D desacoplado (Soporte de hierro + Llama emisiva)
			var torch_builder = _TorchGeometryBuilderScript.new()
			var fixture_asset = torch_builder.build_torch_fixture()
			var fixture_node = fixture_asset.to_node3d("Fixture")
			torch_root.add_child(fixture_node)

		# 3. Luz OmniLight3D (Ilumina 360° la pared, piedras y suelo con degradado cálido)
		var omni := OmniLight3D.new()
		omni.name = "OmniLight3D"
		omni.light_color = profile.light_color
		omni.light_energy = profile.energy
		omni.omni_range = profile.omni_range
		omni.omni_attenuation = profile.attenuation
		omni.shadow_enabled = profile.shadow_enabled
		omni.shadow_bias = profile.shadow_bias
		omni.position = Vector3(0.0, 0.25, 0.16)
		torch_root.add_child(omni)

		# 4. Controlador de Parpadeo Suave
		if profile.flicker_enabled:
			var controller := _TorchLightControllerScript.new()
			controller.name = "FlickerController"
			controller.target_light = omni
			controller.base_energy = profile.energy
			controller.flicker_amplitude = profile.flicker_amplitude
			controller.flicker_speed = profile.flicker_speed
			controller.time_offset = float(placement.light_id * 137.5)
			torch_root.add_child(controller)

		# Asignar a su contenedor respectivo
		if placement.room_id != -1:
			room_lights_container.add_child(torch_root)
		else:
			corridor_lights_container.add_child(torch_root)

		result["spawned_lights"].append(torch_root)

	return result
