class_name DungeonMissionStage
extends RefCounted

## Etapa 1: Gramática de Misiones y Validación de Resolubilidad.

const _MissionGrammarScript = preload("res://src/dungeon_generator/core/grammars/mission_grammar.gd")
const _WinnabilitySolverScript = preload("res://src/dungeon_generator/core/solvers/winnability_solver.gd")
const _DungeonSeedFactoryScript = preload("res://src/dungeon_generator/core/generation/dungeon_seed_factory.gd")

var _mission_grammar := _MissionGrammarScript.new()
var _winnability_solver := _WinnabilitySolverScript.new()

func execute(ctx: DungeonGenerationContext) -> bool:
	var t0 := Time.get_ticks_msec()
	var mission_seed: int = _DungeonSeedFactoryScript.derive_seed(ctx.base_seed, ctx.attempt, &"mission")
	ctx.stage_seeds["mission"] = mission_seed

	ctx.mission_graph = _mission_grammar.generate(ctx.config, mission_seed)
	ctx.record_timing("mission_grammar", float(Time.get_ticks_msec() - t0))

	# Validar que el grafo de misiones sea un DAG estricto (sin ciclos)
	var topo_order: Array[int] = ctx.mission_graph.get_topological_order()
	if topo_order.size() != ctx.mission_graph.get_node_count() and ctx.mission_graph.get_node_count() > 0:
		if ctx.diagnostics_enabled:
			push_warning("[DungeonMissionStage] Attempt %d: MISSION_GRAPH_CYCLE - Mission graph contains cycles." % ctx.attempt)
		ctx.mark_attempt_failed("MISSION_GRAPH_CYCLE", "TRANSIENT")
		return false

	t0 = Time.get_ticks_msec()
	var val: _WinnabilitySolverScript.ValidationResult = _winnability_solver.validate(ctx.mission_graph)
	ctx.validation_result = val
	ctx.record_timing("winnability_check", float(Time.get_ticks_msec() - t0))

	if not val.is_winnable:
		ctx.mark_attempt_failed("MISSION_NOT_WINNABLE", "STRUCTURAL")
		return false

	return true
