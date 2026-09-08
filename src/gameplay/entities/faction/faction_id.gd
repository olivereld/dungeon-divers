# faction_id.gd
# Identidad de GRUPO/ORGANIZACIÓN: "¿A qué facción pertenece?"
# Nunca especie (eso es SpeciesId) ni disposición (eso es Disposition).
#
# Ejemplos: un goblin mercader pertenece a MERCHANTS (facción),
# pero su especie es GOBLINOID (SpeciesId). Un guardia humano
# pertenece a GUARDS, su especie es HUMANITY.
#
# NOTA DE DISEÑO: implementado como enum por seguridad de tipos. Si el juego
# termina necesitando facciones definidas por datos/contenido (mods, editor
# de nivel, DLC), conviene migrar a String validado contra un registro.
class_name FactionId
extends RefCounted

enum Type {
	PLAYER_PARTY,  # grupo/party del jugador
	GOBLINS,       # tribu/clan goblin
	GUARDS,        # guardia de ciudad, milicia
	VILLAGERS,     # población civil
	MERCHANTS,     # gremio de comerciantes
}
