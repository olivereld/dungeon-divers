class_name DestructionDebrisConsumer
extends RefCounted

## Consumidor desacoplado encargado de instanciar y posicionar escombros físicos/visuales
## alrededor del objeto destruido, leyendo las especificaciones de debris.json.

const _DestructionResponseContextScript = preload("res://src/destruction/response/destruction_response_context.gd")

var _debris_catalog: Dictionary = {}
var _catalog_path: String = "res://resources/dungeon_profiles/assets/debris.json"

func _init(catalog_path: String = "") -> void:
	if catalog_path != "":
		_catalog_path = catalog_path
	_load_catalog()

func _load_catalog() -> void:
	if not ResourceLoader.exists(_catalog_path) and not FileAccess.file_exists(_catalog_path):
		return
	var file := FileAccess.open(_catalog_path, FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary and parsed.has("debris"):
			_debris_catalog = parsed["debris"]

## Instancia fragmentos de escombros alrededor del objeto destruido según su clave de debris.
func handle_debris(ctx: _DestructionResponseContextScript, staging_parent: Node3D = null) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if ctx == null or ctx.event == null or ctx.event.definition == null:
		return result

	var debris_key: String = str(ctx.event.definition.debris)
	if debris_key == "" or debris_key == "none" or not _debris_catalog.has(debris_key):
		return result

	var dcfg: Dictionary = _debris_catalog[debris_key]
	var c_min: int = int(dcfg.get("count_min", 2))
	var c_max: int = int(dcfg.get("count_max", 5))
	var s_min: float = float(dcfg.get("scale_min", 0.08))
	var s_max: float = float(dcfg.get("scale_max", 0.20))
	var radius: float = float(dcfg.get("scatter_radius", 0.8))
	var s_height: float = float(dcfg.get("scatter_height", 0.1))

	var raw_color = dcfg.get("material_color", [0.6, 0.5, 0.4, 1.0])
	var mat_col := Color(raw_color[0], raw_color[1], raw_color[2], raw_color[3])

	var count := ctx.rng.randi_range(c_min, c_max)

	var target_parent = staging_parent
	if target_parent == null and ctx.event.target != null and is_instance_valid(ctx.event.target):
		target_parent = ctx.event.target.get_parent()

	var origin_pos := ctx.global_transform.origin

	for i in range(count):
		var shard := MeshInstance3D.new()
		shard.name = "Debris_%s_%d" % [debris_key, i]

		var box_mesh := BoxMesh.new()
		var sz_x = ctx.rng.randf_range(s_min, s_max)
		var sz_y = ctx.rng.randf_range(s_min * 0.5, s_max * 0.8)
		var sz_z = ctx.rng.randf_range(s_min, s_max)
		box_mesh.size = Vector3(sz_x, sz_y, sz_z)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = mat_col
		mat.roughness = 0.8
		box_mesh.material = mat
		shard.mesh = box_mesh

		var angle = ctx.rng.randf_range(0.0, TAU)
		var dist = ctx.rng.randf_range(0.1, radius)
		var offset := Vector3(cos(angle) * dist, ctx.rng.randf_range(0.02, s_height), sin(angle) * dist)

		shard.position = origin_pos + offset
		shard.rotation = Vector3(
			ctx.rng.randf_range(-PI, PI),
			ctx.rng.randf_range(-PI, PI),
			ctx.rng.randf_range(-PI, PI)
		)

		if target_parent != null and is_instance_valid(target_parent):
			target_parent.add_child(shard)

		result.append(shard)

	return result

## Alias de interfaz común para todos los consumidores de respuesta
func handle(ctx: _DestructionResponseContextScript, staging_parent: Node3D = null) -> Array[Node3D]:
	return handle_debris(ctx, staging_parent)
