class_name Hitbox
extends Resource

## Volume de acerto de um ataque. E dado puro e imutavel: nunca vira no de cena.
##
## O offset e authorado no espaco "olhando para a direita" e espelhado em runtime
## conforme o facing do lutador, nunca invertendo escala de nos.
## Hitboxes com o mesmo hit_group contam como um unico golpe, o que permite
## descrever ataques largos sem acertar o mesmo alvo duas vezes; multi-hits usam
## grupos diferentes para reacertar.

@export var shape: Shape2D
## Deslocamento em relacao a origem do lutador (facing direita).
@export var offset: Vector2 = Vector2.ZERO
## Primeiro frame ativo, contado a partir do inicio do ataque.
@export var start_frame: int = 0
## Ultimo frame ativo, inclusivo.
@export var end_frame: int = 0
## Golpes de multi-hit usam grupos diferentes para poder reacertar.
@export var hit_group: int = 0


func is_active_on_frame(frame: int) -> bool:
	return shape != null and frame >= start_frame and frame <= end_frame


## Transform de consulta, ja espelhado para o lado que o lutador encara.
func get_query_transform(origin: Vector2, facing_right: bool) -> Transform2D:
	var mirrored := offset
	if not facing_right:
		mirrored.x = -mirrored.x
	return Transform2D(0.0, origin + mirrored)
