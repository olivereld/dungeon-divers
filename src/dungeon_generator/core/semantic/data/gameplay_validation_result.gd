class_name GameplayValidationResult
extends RefCounted

## Resultado formal e inmutable del bloque de Gameplay Validation (Fase 6).
## Diagnostica con precisión la jugabilidad y completabilidad (winnability) del dungeon.
## 100% puro y determinista. Inmutable post-construcción.

const _ObjectiveDataScript = preload("res://src/dungeon_generator/core/semantic/data/objective_data.gd")
const _KeyDataScript = preload("res://src/dungeon_generator/core/semantic/data/key_data.gd")
const _LockDataScript = preload("res://src/dungeon_generator/core/semantic/data/lock_data.gd")

var valid: bool = false
var failure_reason: String = ""
var critical_path: Array[int] = []
var unreachable_objectives: Array = [] # Array[ObjectiveData]
var unavailable_keys: Array = []       # Array[KeyData]
var blocked_locks: Array = []          # Array[LockData]
var solution_trace: Array = []         # Array[Dictionary]
var failing_reasons: Array[String] = []

var _is_sealed: bool = false

func seal() -> void:
	_is_sealed = true

func is_sealed() -> bool:
	return _is_sealed

func is_valid() -> bool:
	return valid

func to_debug_string() -> String:
	var s := "=== GAMEPLAY VALIDATION RESULT (Valid: %s) ===\n" % str(valid)
	if not valid:
		s += "Failure Reason: %s\n" % failure_reason
		s += "Failing Reasons (%d): %s\n" % [failing_reasons.size(), str(failing_reasons)]
		s += "Blocked Locks (%d): %s\n" % [blocked_locks.size(), str(blocked_locks.map(func(l): return l.to_debug_string()))]
		s += "Unavailable Keys (%d): %s\n" % [unavailable_keys.size(), str(unavailable_keys.map(func(k): return k.to_debug_string()))]
		s += "Unreachable Objectives (%d): %s\n" % [unreachable_objectives.size(), str(unreachable_objectives.map(func(o): return o.to_debug_string()))]
	else:
		s += "Playable Critical Path (%d): %s\n" % [critical_path.size(), str(critical_path)]
		s += "Solution Trace Steps: %d\n" % solution_trace.size()
	return s
