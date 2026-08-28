class_name DestructionDebugInteractor
extends Node

## Adaptador de Input y Raycasting 3D para interactuar con objetos destructibles en tiempo de ejecución.
## Desacoplado: convierte eventos de mouse en DestructionHit y los envía a DestructionService.

const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")

signal destructible_hit(node: Node3D, component: _DestructionCompScript, hit: _DestructionHitScript)
signal hover_changed(node: Node3D, component: _DestructionCompScript)

@export var enabled: bool = true
@export var normal_damage: float = 10.0
@export var fatal_damage: float = 9999.0
@export var damage_type: StringName = &"physical"
@export var collision_mask: int = 0xFFFFFFFF

var _service: _DestructionServiceScript = null
var _last_hovered_node: Node3D = null
var _last_hovered_comp: _DestructionCompScript = null

func _init(service: _DestructionServiceScript = null) -> void:
	_service = service

func set_service(service: _DestructionServiceScript) -> void:
	_service = service

func get_service() -> _DestructionServiceScript:
	return _service

## Resuelve el DestructionComponent navegando el árbol hacia la raíz del prop
func resolve_destructible_from_collider(collider: Object) -> _DestructionCompScript:
	if collider == null:
		return null

	if collider is Node:
		var curr: Node = collider
		while curr != null:
			for child in curr.get_children():
				if child is _DestructionCompScript:
					return child as _DestructionCompScript
			curr = curr.get_parent()

	return null

## Aplica daño directo sobre un nodo destino
func apply_hit_to_target(
	target_node: Node3D,
	damage_val: float = 10.0,
	dmg_type: StringName = &"physical",
	is_fatal: bool = false,
	impact_pos: Vector3 = Vector3.ZERO,
	impact_dir: Vector3 = Vector3.DOWN
) -> Dictionary:
	if target_node == null:
		return {"success": false, "error": "target_node_null"}

	var comp: _DestructionCompScript = null
	for child in target_node.get_children():
		if child is _DestructionCompScript:
			comp = child
			break
	if comp == null:
		comp = resolve_destructible_from_collider(target_node)

	if comp == null or comp.is_destroyed():
		return {"success": false, "error": "no_active_component"}

	var final_damage = fatal_damage if is_fatal else damage_val
	var hit = _DestructionHitScript.new(final_damage, dmg_type, impact_pos, impact_dir, self)

	var applied := false
	if _service != null:
		applied = _service.apply_hit_to_node(target_node, hit)
	else:
		applied = comp.apply_hit(hit)

	if applied:
		destructible_hit.emit(target_node, comp, hit)
		return {
			"success": true,
			"target": target_node,
			"component": comp,
			"damage": final_damage,
			"durability": comp.current_durability,
			"state": comp.current_state,
			"destroyed": comp.is_destroyed()
		}

	return {"success": false, "error": "hit_rejected"}

## Lanza un rayo desde la cámara y aplica interacción si colisiona con un destructible
func interact_ray(
	camera: Camera3D,
	screen_pos: Vector2,
	is_fatal: bool = false
) -> Dictionary:
	if not enabled or camera == null:
		return {"success": false, "error": "disabled_or_no_camera"}

	var world_3d = camera.get_world_3d()
	if world_3d == null:
		return {"success": false, "error": "no_world_3d"}

	var space_state = world_3d.direct_space_state
	if space_state == null:
		return {"success": false, "error": "no_space_state"}

	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_dir = camera.project_ray_normal(screen_pos)
	var ray_length = camera.far if camera.far > 0.0 else 1000.0
	var ray_end = ray_origin + ray_dir * ray_length

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit_dict = space_state.intersect_ray(query)
	if hit_dict.is_empty():
		_update_hover(null, null)
		return {"success": false, "hit_geometry": false}

	var collider = hit_dict.get("collider", null)
	var hit_pos = hit_dict.get("position", Vector3.ZERO)
	var hit_normal = hit_dict.get("normal", Vector3.UP)
	var comp = resolve_destructible_from_collider(collider)

	if comp != null and comp.get_parent() is Node3D:
		var parent_3d = comp.get_parent() as Node3D
		_update_hover(parent_3d, comp)
		return apply_hit_to_target(parent_3d, normal_damage, damage_type, is_fatal, hit_pos, -hit_normal)

	_update_hover(null, null)
	return {"success": false, "hit_geometry": true, "collider": collider}

func _update_hover(node: Node3D, comp: _DestructionCompScript) -> void:
	if node != _last_hovered_node or comp != _last_hovered_comp:
		_last_hovered_node = node
		_last_hovered_comp = comp
		hover_changed.emit(node, comp)

func handle_input_event(camera: Camera3D, event: InputEvent) -> bool:
	if not enabled or camera == null:
		return false

	if event is InputEventMouseButton and event.pressed:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var res = interact_ray(camera, mb.position, false)
			return bool(res.get("success", false))
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			var res = interact_ray(camera, mb.position, true)
			return bool(res.get("success", false))

	return false
