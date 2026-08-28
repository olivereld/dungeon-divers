class_name DestructibleDefinition
extends RefCounted

## Definición tipada de las propiedades de destrucción de un asset.

const _DestructionModeScript = preload("res://src/destruction/core/destruction_mode.gd")

var id: StringName = &""
var enabled: bool = true
var durability: float = 20.0
var damage_vulnerabilities: Array[StringName] = []
var destruction_mode: int = _DestructionModeScript.Mode.BREAK
var replacement_asset: StringName = &""
var debris_id: StringName = &""
var debris: StringName:
	get:
		return debris_id
	set(val):
		debris_id = val
var effects: Array[String] = []

static func from_dict(p_id: StringName, d: Dictionary):
	var def = load("res://src/destruction/core/destructible_definition.gd").new()
	def.id = p_id
	def.enabled = bool(d.get("enabled", true))
	def.durability = float(d.get("durability", 20.0))

	var vulns: Array[StringName] = []
	for v in d.get("damage_type_vulnerabilities", []):
		vulns.append(StringName(str(v)))
	def.damage_vulnerabilities = vulns

	var mode_str = str(d.get("destruction_mode", "break"))
	def.destruction_mode = _DestructionModeScript.from_string(mode_str)

	var repl = d.get("replacement_asset", null)
	if repl != null and str(repl) != "" and str(repl) != "<null>":
		def.replacement_asset = StringName(str(repl))

	var deb = d.get("debris", null)
	if deb != null and str(deb) != "" and str(deb) != "<null>":
		def.debris_id = StringName(str(deb))

	var effs: Array[String] = []
	for e in d.get("effects", []):
		effs.append(str(e))
	def.effects = effs

	return def
