extends SceneTree

func _init() -> void:
	test_relacion_especifica_prevalece()
	test_relacion_por_faccion()
	test_fallback_por_defecto()
	test_no_simetrica()
	test_auto_relacion_defecto_neutral()
	test_auto_relacion_con_override_explicito()
	test_entidad_sin_faccion_cae_a_defecto()
	print("test_relationship: OK")
	quit()

func _make_entity(id: String, kind: EntityKind.Type, faction_id) -> Entity:
	var entity := Entity.new(EntityIdentity.new(id, kind))
	if faction_id != null:
		entity.add_capability(Entity.CAPABILITY_FACTION, Faction.new(faction_id))
	return entity

func test_relacion_especifica_prevalece() -> void:
	var resolver := RelationshipResolver.new(Disposition.new(-80.0))
	resolver.set_faction_relationship(FactionId.Type.GOBLINS, FactionId.Type.PLAYER_PARTY, Disposition.new(-80.0))

	var goblin_chief := _make_entity("goblin_chief", EntityKind.Type.MONSTER, FactionId.Type.GOBLINS)
	var player := _make_entity("player_001", EntityKind.Type.PLAYER, FactionId.Type.PLAYER_PARTY)

	resolver.set_entity_relationship(EntityRelationship.new("goblin_chief", "player_001", Disposition.new(60.0)))

	var result := resolver.resolve(goblin_chief, player)
	assert(result.value == 60.0)
	assert(result.is_friendly())

func test_relacion_por_faccion() -> void:
	var resolver := RelationshipResolver.new(Disposition.new(0.0))
	resolver.set_faction_relationship(FactionId.Type.GOBLINS, FactionId.Type.PLAYER_PARTY, Disposition.new(-80.0))

	var goblin_scout := _make_entity("goblin_scout", EntityKind.Type.MONSTER, FactionId.Type.GOBLINS)
	var player := _make_entity("player_001", EntityKind.Type.PLAYER, FactionId.Type.PLAYER_PARTY)

	var result := resolver.resolve(goblin_scout, player)
	assert(result.value == -80.0)
	assert(result.is_hostile())

func test_fallback_por_defecto() -> void:
	var resolver := RelationshipResolver.new(Disposition.new(10.0))
	var villager := _make_entity("villager_001", EntityKind.Type.NPC, FactionId.Type.VILLAGERS)
	var player := _make_entity("player_001", EntityKind.Type.PLAYER, FactionId.Type.PLAYER_PARTY)

	var result := resolver.resolve(villager, player)
	assert(result.value == 10.0)

func test_no_simetrica() -> void:
	var resolver := RelationshipResolver.new(Disposition.new(0.0))
	var a := _make_entity("a", EntityKind.Type.NPC, null)
	var b := _make_entity("b", EntityKind.Type.NPC, null)
	resolver.set_entity_relationship(EntityRelationship.new("a", "b", Disposition.new(50.0)))
	var a_to_b := resolver.resolve(a, b)
	var b_to_a := resolver.resolve(b, a)
	assert(a_to_b.value == 50.0)
	assert(b_to_a.value == 0.0)

func test_auto_relacion_defecto_neutral() -> void:
	var resolver := RelationshipResolver.new(Disposition.new(-100.0)) # defecto hostil
	var hero := _make_entity("hero", EntityKind.Type.PLAYER, FactionId.Type.PLAYER_PARTY)
	var self_res := resolver.resolve(hero, hero)
	assert(self_res.value == 0.0)
	assert(self_res.is_neutral())

func test_auto_relacion_con_override_explicito() -> void:
	var resolver := RelationshipResolver.new(Disposition.new(0.0))
	var hero := _make_entity("hero", EntityKind.Type.PLAYER, FactionId.Type.PLAYER_PARTY)
	resolver.set_entity_relationship(EntityRelationship.new("hero", "hero", Disposition.new(100.0)))
	var self_res := resolver.resolve(hero, hero)
	assert(self_res.value == 100.0)
	assert(self_res.is_friendly())

func test_entidad_sin_faccion_cae_a_defecto() -> void:
	var resolver := RelationshipResolver.new(Disposition.new(0.0))
	resolver.set_faction_relationship(FactionId.Type.GUARDS, FactionId.Type.GOBLINS, Disposition.new(-100.0))

	var guard := _make_entity("guard_001", EntityKind.Type.NPC, FactionId.Type.GUARDS)
	var barrel := _make_entity("barrel_001", EntityKind.Type.DESTRUCTIBLE_OBJECT, null) # sin facción

	var guard_to_barrel := resolver.resolve(guard, barrel)
	var barrel_to_guard := resolver.resolve(barrel, guard)
	assert(guard_to_barrel.value == 0.0)
	assert(barrel_to_guard.value == 0.0)
