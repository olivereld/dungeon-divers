class_name DestructionResponseContext
extends RefCounted

## Contexto de ejecución inmutable para los consumidores de respuesta a la destrucción.
## Provee acceso al evento, transform espacial, metadatos y un generador RNG determinista.

const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")

var event: _DestructionEventScript = null
var global_transform: Transform3D = Transform3D.IDENTITY
var room_id: int = -1
var seed_value: int = 0
var base_seed: int = 0
var rng: RandomNumberGenerator = null

func _init(
	p_event: _DestructionEventScript = null,
	p_transform: Transform3D = Transform3D.IDENTITY,
	p_seed: int = 0,
	p_room: int = -1,
	p_base_seed: int = 0
) -> void:
	event = p_event
	global_transform = p_transform
	seed_value = p_seed
	room_id = p_room
	base_seed = p_base_seed
	rng = RandomNumberGenerator.new()
	rng.seed = p_seed

static func from_event(
	evt: _DestructionEventScript,
	base_seed: int = 0,
	default_room: int = -1
) -> DestructionResponseContext:
	var xform := Transform3D.IDENTITY
	var r_id := default_room
	if evt != null and evt.target != null and is_instance_valid(evt.target):
		if evt.target is Node3D:
			var n3d := evt.target as Node3D
			xform = n3d.global_transform if n3d.is_inside_tree() else n3d.transform
		if evt.target.has_meta("room_id"):
			r_id = int(evt.target.get_meta("room_id"))

	# Generar semilla determinista combinando base_seed + hash de posición espacial
	var pos_hash: int = int(xform.origin.x * 73856093) ^ int(xform.origin.y * 19349663) ^ int(xform.origin.z * 83492791)
	var final_seed: int = (base_seed ^ pos_hash) if base_seed != 0 else pos_hash
	if final_seed == 0:
		final_seed = 1337

	return load("res://src/destruction/response/destruction_response_context.gd").new(evt, xform, final_seed, r_id, base_seed)
