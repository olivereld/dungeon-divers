class_name DungeonTopologyStage
extends RefCounted

## Etapa 3: Construcción de Topología (Delaunay + MST + Loops).

const _RoomGraphBuilderScript = preload("res://src/dungeon_generator/core/topology/room_graph_builder.gd")
const _DungeonSeedFactoryScript = preload("res://src/dungeon_generator/core/generation/dungeon_seed_factory.gd")

func execute(ctx: DungeonGenerationContext) -> bool:
	var t0 := Time.get_ticks_msec()
	var topology_seed: int = _DungeonSeedFactoryScript.derive_seed(ctx.base_seed, ctx.attempt, &"topology")
	ctx.stage_seeds["topology"] = topology_seed

	var topology_res = _RoomGraphBuilderScript.build_topology(ctx.rooms, topology_seed, ctx.config.extra_loop_chance)
	ctx.connections = topology_res.connections
	ctx.record_timing("topology_builder", float(Time.get_ticks_msec() - t0))

	if ctx.connections.is_empty() and ctx.rooms.size() > 1:
		ctx.mark_attempt_failed("TOPOLOGY_NO_CONNECTIONS", "TRANSIENT")
		return false

	return true
