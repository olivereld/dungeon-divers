extends SceneTree

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	print("=================================================================")
	print("  AUDITORÍA DE RESOLUCIÓN DE ROOM TEMPLATES (OBSERVABILIDAD)     ")
	print("=================================================================")

	var pipeline = _DungeonPipelineScript.new()
	var config := DungeonConfig.new()
	config.algorithm = "Hybrid"
	config.archetype_id = &"necropolis"
	config.grid_width = 64
	config.grid_height = 64

	var test_seeds = [100001, 100002, 100003, 374407920, 81227591]
	var total_rooms: int = 0
	var total_templates_resolved: int = 0
	var total_procedural_fallback: int = 0

	for s in test_seeds:
		config.seed = s
		print("\n--- Generando Mazmorra con Semilla %d ---" % s)
		var res = pipeline.generate(config)
		assert(res != null, "FAIL: generación falló para semilla %d" % s)

		for r in res.rooms:
			total_rooms += 1
			var t_id = r.custom_data.get("resolved_template_id", &"none")
			var p_id = r.custom_data.get("profile_id", &"none")
			var is_fb = bool(r.custom_data.get("is_template_fallback", true))

			if not is_fb and t_id != &"procedural_fallback":
				total_templates_resolved += 1
				print("  [TEMPLATE HIT] Sala #%d | Tipo: %-8s | Perfil: %-10s | Tamaño: %-8s | Template: %s" % [
					r.id, r.room_type, p_id, str(r.rect.size), t_id
				])
			else:
				total_procedural_fallback += 1
				print("  [PROCEDURAL]   Sala #%d | Tipo: %-8s | Perfil: %-10s | Tamaño: %-8s | Fallback: %s" % [
					r.id, r.room_type, p_id, str(r.rect.size), t_id
				])

	print("\n=================================================================")
	print("  RESUMEN DE AUDITORÍA:")
	print("  Total Salas Evaluadas    : %d" % total_rooms)
	print("  Plantillas Resueltas     : %d" % total_templates_resolved)
	print("  Fallbacks Procedimentales: %d" % total_procedural_fallback)
	print("=================================================================")
	print("PASS: Auditoría de resolución completada con éxito.")
	quit(0)
