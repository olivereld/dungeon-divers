extends SceneTree

func _init() -> void:
	test_identidad_valida()
	test_kind_correcto()
	test_capacidades_composicion()
	test_reemplazar_capacidad()
	print("test_entity: OK")
	quit()

func test_identidad_valida() -> void:
	var identity := EntityIdentity.new("goblin_001", EntityKind.Type.MONSTER, "Goblin")
	var entity := Entity.new(identity)
	assert(entity.entity_id == "goblin_001")

func test_kind_correcto() -> void:
	var identity := EntityIdentity.new("barrel_001", EntityKind.Type.DESTRUCTIBLE_OBJECT)
	var entity := Entity.new(identity)
	assert(entity.kind == EntityKind.Type.DESTRUCTIBLE_OBJECT)

func test_capacidades_composicion() -> void:
	var identity := EntityIdentity.new("turret_001", EntityKind.Type.TURRET)
	var entity := Entity.new(identity)
	assert(not entity.has_capability(Entity.CAPABILITY_TARGETABLE))
	entity.add_capability(Entity.CAPABILITY_TARGETABLE, Targetable.new(true))
	assert(entity.has_capability(Entity.CAPABILITY_TARGETABLE))
	assert(entity.get_capability(Entity.CAPABILITY_TARGETABLE).is_targetable())

func test_reemplazar_capacidad() -> void:
	var identity := EntityIdentity.new("turret_002", EntityKind.Type.TURRET)
	var entity := Entity.new(identity)
	entity.add_capability(Entity.CAPABILITY_TARGETABLE, Targetable.new(true))
	assert(entity.get_capability(Entity.CAPABILITY_TARGETABLE).is_targetable())

	entity.replace_capability(Entity.CAPABILITY_TARGETABLE, Targetable.new(false))
	assert(not entity.get_capability(Entity.CAPABILITY_TARGETABLE).is_targetable())

# NOTA: "identity vacía rechazada" usa assert() de Godot (aborta en debug).
# Para probarlo de forma automatizada como caso NEGATIVO se recomienda un
# framework como GUT con assert_error/expect_assert, en vez de plain assert().
