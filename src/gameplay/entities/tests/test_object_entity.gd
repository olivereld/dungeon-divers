extends SceneTree

func _init() -> void:
	test_creacion()
	test_integridad_via_destructible()
	test_no_es_living()
	print("test_object_entity: OK")
	quit()

func test_creacion() -> void:
	var identity := EntityIdentity.new("barrel_001", EntityKind.Type.DESTRUCTIBLE_OBJECT)
	var barrel := ObjectEntity.new(identity)
	assert(barrel.entity_id == "barrel_001")

func test_integridad_via_destructible() -> void:
	var identity := EntityIdentity.new("barrel_002", EntityKind.Type.DESTRUCTIBLE_OBJECT)
	var barrel := ObjectEntity.new(identity)
	var integrity := Integrity.new(50.0)
	barrel.add_capability("destructible", Destructible.new(integrity))
	var destructible: Destructible = barrel.get_capability("destructible")
	assert(destructible.integrity.integrity == 50.0)
	destructible.integrity.apply_damage(60.0)
	assert(destructible.is_destroyed())

func test_no_es_living() -> void:
	var turret = ObjectEntity.new(EntityIdentity.new("turret_002", EntityKind.Type.TURRET))
	assert(not (turret is LivingEntity))
