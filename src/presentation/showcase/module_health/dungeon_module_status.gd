class_name DungeonModuleStatus
extends RefCounted

## Data contract for module health status within the Laboratory showcase.
## Distinguishes between file availability on disk and active use within the generator pipeline.

enum State {
	LOADED,    # Internal state indicator
	AVAILABLE, # File exists on disk and loads successfully
	MISSING,   # File does not exist at the declared path
	ERROR      # File exists but fails to compile/load
}

var id: String = ""
var name: String = ""
var path: String = ""
var category: String = ""
var state: State = State.MISSING
var message: String = ""
var is_used_by_pipeline: bool = false

func get_state_symbol() -> String:
	match state:
		State.AVAILABLE:
			return "🟢"
		State.MISSING:
			return "🔴"
		State.ERROR:
			return "🟡"
		_:
			return "⚪"

func get_state_text() -> String:
	match state:
		State.AVAILABLE:
			return "AVAILABLE"
		State.MISSING:
			return "MISSING"
		State.ERROR:
			return "ERROR"
		State.LOADED:
			return "LOADED"
		_:
			return "UNKNOWN"

func get_pipeline_symbol() -> String:
	return "🟢 USED" if is_used_by_pipeline else "🔴 NOT USED"

func to_display_string() -> String:
	if state == State.MISSING:
		return "%s File: %s MISSING Path: %s" % [name, get_state_symbol(), path]
	return "%s File: %s %s Pipeline: %s" % [name, get_state_symbol(), get_state_text(), get_pipeline_symbol()]
