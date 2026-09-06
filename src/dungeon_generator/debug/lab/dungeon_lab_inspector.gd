class_name DungeonLabInspector
extends RefCounted

## Inspector diagnóstico que consume directamente la API pública de RoomTemplateResolver.

const _RoomTemplateResolverScript = preload("res://src/dungeon_generator/core/room_templates/resolver/room_template_resolver.gd")

func inspect_room(
	room: RoomData,
	bundle: ProfileBundle,
	p_seed: int = 0,
	entrances: Array[Vector2i] = [],
	spatial_composition = null
) -> Dictionary:
	if room == null or bundle == null:
		return {}

	var room_profile = bundle.get_room(room.room_type)
	if room_profile == null and bundle.archetype != null:
		var g_map: Dictionary = bundle.archetype.gameplay_purpose_map
		var key: String = str(room.room_type).to_upper()
		if g_map.has(key) and not g_map[key].is_empty():
			var candidates_list: Array = g_map[key]
			var rng := RandomNumberGenerator.new()
			rng.seed = p_seed
			var mapped_purpose = candidates_list[rng.randi_range(0, candidates_list.size() - 1)]
			room_profile = bundle.get_room(mapped_purpose)

	var resolver := _RoomTemplateResolverScript.new(bundle.template_registry)
	var raw_diag := resolver.resolve_with_diagnostics(room, room_profile, entrances, p_seed)

	var node_id: int = room.mission_node_id if room.mission_node_id >= 0 else room.id
	var comp_region: StringName = &"none"
	var prog_factor: float = -1.0
	var anchor_pos: Vector2 = Vector2.ZERO
	var density_val: float = 1.0
	var is_main_path: bool = false
	var branch_anchor_id: int = -1

	if spatial_composition != null:
		comp_region = spatial_composition.get_region(node_id)
		prog_factor = spatial_composition.get_main_path_factor(node_id)
		if prog_factor < 0.0:
			prog_factor = spatial_composition.get_branch_factor(node_id)
		anchor_pos = spatial_composition.get_anchor_target(node_id)
		density_val = spatial_composition.get_density(node_id)
		is_main_path = spatial_composition.is_main_path(node_id)
		branch_anchor_id = spatial_composition.get_branch_anchor(node_id)

	return {
		"room_id": room.id,
		"purpose": room.room_type,
		"profile_id": raw_diag.get("profile_id", &"none"),
		"resolved_template_id": raw_diag.get("resolved_template_id", &"procedural_fallback"),
		"is_fallback": raw_diag.get("is_fallback", true),
		"room_size": raw_diag.get("room_size", room.rect.size),
		"candidate_templates": raw_diag.get("candidate_templates", []),
		"compatible_templates": raw_diag.get("compatible_templates", []),
		"rejected_templates": raw_diag.get("rejected_templates", {}),
		"composition_region": comp_region,
		"progression_factor": prog_factor,
		"anchor_position": anchor_pos,
		"density": density_val,
		"main_path": is_main_path,
		"branch_anchor": branch_anchor_id
	}

func format_corridor_diagnostics(diagnostics: Array, corridor_paths: Array = []) -> String:
	if diagnostics.is_empty() and corridor_paths.is_empty():
		return "[color=gray]No corridor diagnostic data available.[/color]"

	var bbcode := "[b]CORRIDOR DETAILS & ROUTING ROBUSTNESS[/b]\n\n"

	var path_map: Dictionary = {}
	for cp in corridor_paths:
		if cp != null:
			path_map[cp.connection_id] = cp

	var displayed_conns: Dictionary = {}

	for diag in diagnostics:
		var cid: int = diag.get("connection_id", -1)
		displayed_conns[cid] = true
		var r_a = diag.get("room_a_id", diag.get("room_a", "?"))
		var r_b = diag.get("room_b_id", diag.get("room_b", "?"))
		var role = diag.get("role", "UNKNOWN")
		var routing = diag.get("routing_preference", "DEFAULT")
		var strat = diag.get("strategy", "Unknown")
		var pref_len = diag.get("preferred_length", 0.0)
		var act_len = diag.get("actual_length", 0)
		var turns = diag.get("turn_count", 0)
		var states = diag.get("expanded_states", 0)
		var ms = diag.get("elapsed_ms", 0.0)
		var term_reason = diag.get("termination_reason", diag.get("reason", "OK"))
		var status = diag.get("status", "SUCCESS")
		var rep_att = diag.get("repair_attempted", false)
		var rep_succ = diag.get("repair_success", false)

		var rep_str := "N/A"
		if rep_att:
			rep_str = "[color=green]REPAIRED[/color]" if rep_succ else "[color=coral]FAILED[/color]"

		var status_color := "green" if (status == "SUCCESS" or status == "REPAIRED") else "coral"

		bbcode += "[b]Connection #%d (Room %s ➔ %s)[/b]\n" % [cid, str(r_a), str(r_b)]
		bbcode += "  - Role: [color=cyan]%s[/color] | Status: [color=%s]%s[/color]\n" % [str(role), status_color, str(status)]
		bbcode += "  - Routing: %s (%s)\n" % [str(routing), str(strat)]
		bbcode += "  - Preferred Length: %.1f | Actual Length: %d\n" % [float(pref_len), int(act_len)]
		bbcode += "  - Turns: %d\n" % int(turns)
		bbcode += "  - Search States: %d | Search Time: %.2f ms\n" % [int(states), float(ms)]
		if status == "FAILED" or status == "REJECTED" or term_reason != "SUCCESS":
			bbcode += "  - Failure Reason: [color=coral]%s[/color]\n" % str(term_reason)
		bbcode += "  - Repair Status: %s\n\n" % rep_str

	for cid in path_map:
		if not displayed_conns.has(cid):
			var cp = path_map[cid]
			bbcode += "[b]Connection #%d (Room %d ➔ %d)[/b]\n" % [cp.connection_id, cp.room_a_id, cp.room_b_id]
			bbcode += "  - Routing Strategy: %s\n" % cp.routing_strategy
			bbcode += "  - Actual Length: %d | Turns: %d\n" % [cp.centerline_cells.size(), cp.turn_count]
			bbcode += "  - Search States: %d | Search Time: %.2f ms\n\n" % [cp.expanded_states, cp.elapsed_ms]

	return bbcode
