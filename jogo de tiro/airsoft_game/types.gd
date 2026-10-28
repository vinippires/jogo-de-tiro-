extends RefCounted
## Tipo enumerado ÚNICO de compatibilidade, usado por arma E carregador.
## Nunca se compara texto digitado: só os valores deste enum.

enum MagType { Shotgun, Rifle, Pistol1911, PistolGlock }

const COLORS := {
	MagType.Shotgun: Color(0.95, 0.55, 0.15),
	MagType.Rifle: Color(0.25, 0.55, 1.0),
	MagType.Pistol1911: Color(0.3, 0.85, 0.4),
	MagType.PistolGlock: Color(0.75, 0.45, 0.95),
}


static func type_name(t: int) -> String:
	return MagType.keys()[t]


static func color_of(t: int) -> Color:
	return COLORS.get(t, Color.WHITE)
