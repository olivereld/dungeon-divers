## Re-export / delegación de CompositionStrategy bajo src/dungeon_generator/core/strategies/
## para garantizar compatibilidad con referencias en esta ruta.

const _CompositionStrategyBase = preload("res://src/dungeon_generator/core/grammars/composition_strategy.gd")

class_name CompositionStrategyProxy
extends _CompositionStrategyBase
