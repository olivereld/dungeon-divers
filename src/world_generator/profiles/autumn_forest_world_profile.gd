class_name AutumnForestWorldProfile
extends TaigaWorldProfile

## Perfil especializado para la generación procedural de mundos con estética de Bosque Otoñal.
## Hereda de TaigaWorldProfile y aplica por defecto los colores cálidos de terreno, agua cristalina profunda
## y variantes de follaje ámbar/naranja para coníferas y vegetación.

func _init() -> void:
	super._init()
	apply_autumn_preset()
