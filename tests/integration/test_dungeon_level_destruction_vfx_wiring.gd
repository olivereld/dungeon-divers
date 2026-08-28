extends SceneTree

const _DungeonLevelControllerScript = preload("res://scenes/dungeon/dungeon_level_controller.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _VFXInstanceScript = preload("res://src/vfx/vfx_instance.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_dungeon_level_destruction_vfx_wiring ---")
	print("==================================================================")

	var controller = _DungeonLevelControllerScript.new()
	root.add_child(controller)
	await process_frame

	# Configurar cripta/mausoleo con urnas
	controller.config = preload("res://resources/configs/hybrid_dungeon.tres").duplicate()
	controller.config.dungeon_archetype = 4 # MAUSOLEUM / CRYPT
	controller.config.seed = 4242
	controller.config.use_fixed_seed = true
	controller.config.total_floors = 1

	# Generar 2D y luego 3D
	controller.regenerate(false)
	controller.build_3d_presentation()
	await process_frame

	var pres_root = controller.get_node_or_null("DungeonPresentation")
	assert(pres_root != null, "FAIL: DungeonPresentation root not found")

	# Buscar un prop destructible
	var target_prop: Node3D = null
	var target_comp: _DestructionCompScript = null

	for child in pres_root.get_children():
		var comp = child.get_node_or_null("DestructionComponent")
		if comp is _DestructionCompScript:
			target_prop = child
			target_comp = comp
			break

	assert(target_prop != null, "FAIL: destructible prop not found in presentation")
	assert(target_comp != null, "FAIL: DestructionComponent not found on prop")

	var prop_world_pos: Vector3 = target_prop.global_position
	print("[Test] Encontrado Prop '%s' en posición mundial: %s" % [target_prop.name, str(prop_world_pos)])

	# Simular impacto destructivo directo
	target_comp.apply_hit(_DestructionHitScript.new(50.0, &"physical"))
	await process_frame

	# Comprobar que en el staging/árbol existen los nodos VFX generados
	var spawned_vfx: Array[Node3D] = []
	for child in pres_root.get_children():
		if child.name.begins_with("VFX_"):
			spawned_vfx.append(child)

	assert(spawned_vfx.size() >= 1, "FAIL: at least 1 VFX instance must be spawned in presentation root")
	print("[Test] Instancias VFX generadas en escena: %d" % spawned_vfx.size())

	for vfx in spawned_vfx:
		assert(vfx is _VFXInstanceScript, "FAIL: spawned VFX must be VFXInstance")
		var pos_diff = (vfx.global_position - prop_world_pos).length()
		print("   - %s en posición: %s (distancia al prop: %.3f)" % [vfx.name, str(vfx.global_position), pos_diff])
		assert(pos_diff < 0.05, "FAIL: VFX must be positioned exactly at prop world transform")

	controller.free()
	print("==================================================================")
	print("[PASS] test_dungeon_level_destruction_vfx_wiring passed 100%!")
	print("==================================================================")
	quit(0)
