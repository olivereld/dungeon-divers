class_name AttributeSet
extends RefCounted

var strength: float
var dexterity: float
var constitution: float
var intelligence: float
var wisdom: float
var charisma: float

func _init(
	p_strength: float = 10.0,
	p_dexterity: float = 10.0,
	p_constitution: float = 10.0,
	p_intelligence: float = 10.0,
	p_wisdom: float = 10.0,
	p_charisma: float = 10.0
) -> void:
	strength = p_strength
	dexterity = p_dexterity
	constitution = p_constitution
	intelligence = p_intelligence
	wisdom = p_wisdom
	charisma = p_charisma

func get_value(attribute: AttributeType.Type) -> float:
	match attribute:
		AttributeType.Type.STRENGTH: return strength
		AttributeType.Type.DEXTERITY: return dexterity
		AttributeType.Type.CONSTITUTION: return constitution
		AttributeType.Type.INTELLIGENCE: return intelligence
		AttributeType.Type.WISDOM: return wisdom
		AttributeType.Type.CHARISMA: return charisma
		_: 
			push_warning("AttributeSet: atributo desconocido %s" % attribute)
			return 0.0

func set_value(attribute: AttributeType.Type, value: float) -> void:
	match attribute:
		AttributeType.Type.STRENGTH: strength = value
		AttributeType.Type.DEXTERITY: dexterity = value
		AttributeType.Type.CONSTITUTION: constitution = value
		AttributeType.Type.INTELLIGENCE: intelligence = value
		AttributeType.Type.WISDOM: wisdom = value
		AttributeType.Type.CHARISMA: charisma = value
		_:
			push_warning("AttributeSet: atributo desconocido %s" % attribute)

func duplicate_attributes() -> AttributeSet:
	return AttributeSet.new(
		strength,
		dexterity,
		constitution,
		intelligence,
		wisdom,
		charisma
	)