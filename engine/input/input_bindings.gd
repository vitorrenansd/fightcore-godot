class_name InputBindings
extends Resource

## Mapeamento fisico -> acao, por jogador. E a camada personalizavel do input.
##
## As acoes sao criadas em runtime no InputMap (`p1_up`, `p1_p`, `p2_hs`...) em
## vez de ficarem fixas no project.godot, porque remapear precisa funcionar com
## o jogo rodando e ser salvo por usuario.
##
## Teclado usa `physical_keycode`: a tecla e a posicao fisica, entao o padrao
## funciona igual em ABNT2, QWERTY e AZERTY.
##
## Controle e leverless nao precisam de tratamento especial aqui — leverless se
## apresenta como teclado ou controle comum. O que ele exige e a limpeza de SOCD
## que vive no InputDevice.

const SAVE_PATH: String = "user://input_bindings.tres"
## Deadzone alta de proposito: analogico precisa se comportar como gate, senao
## direcao intermediaria vira motion falso.
const STICK_DEADZONE: float = 0.5

const DIRECTIONS: Array[StringName] = [&"up", &"down", &"left", &"right"]

## Um dicionario por jogador: sufixo da acao -> Array de InputEvent.
@export var players: Array[Dictionary] = []


static func create_default() -> InputBindings:
	var bindings := InputBindings.new()
	bindings.players = [_default_player_1(), _default_player_2()]
	return bindings


static func load_or_create() -> InputBindings:
	if ResourceLoader.exists(SAVE_PATH):
		var loaded := ResourceLoader.load(SAVE_PATH) as InputBindings
		if loaded != null and not loaded.players.is_empty():
			return loaded
	return create_default()


## Registra tudo no InputMap. Chamar uma vez antes da partida comecar.
func apply() -> void:
	# Sem isto o Godot junta eventos do mesmo frame e o timing sub-frame de link
	# se perde.
	Input.use_accumulated_input = false
	for index in players.size():
		var prefix := "p%d" % (index + 1)
		var actions: Dictionary = players[index]
		for suffix in actions:
			var action := StringName("%s_%s" % [prefix, suffix])
			if InputMap.has_action(action):
				InputMap.action_erase_events(action)
			else:
				InputMap.add_action(action, STICK_DEADZONE)
			for event in actions[suffix]:
				InputMap.action_add_event(action, event)


func get_events(player_index: int, suffix: StringName) -> Array:
	if player_index >= players.size():
		return []
	return players[player_index].get(suffix, [])


## Troca um binding. `slot` 0 costuma ser teclado e 1 controle, mas e livre.
func set_event(player_index: int, suffix: StringName, slot: int, event: InputEvent) -> void:
	if player_index >= players.size():
		return
	var events: Array = players[player_index].get(suffix, [])
	while events.size() <= slot:
		events.append(null)
	events[slot] = event
	players[player_index][suffix] = events
	apply()


func save() -> Error:
	return ResourceSaver.save(self, SAVE_PATH)


static func _key(physical_keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	return event


static func _pad_button(button: JoyButton, device: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = device
	return event


static func _pad_axis(axis: JoyAxis, value: float, device: int) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	event.device = device
	return event


## Teclado WASD + JKLUI, e controle no primeiro dispositivo.
## No controle: A=P, B=K, X=S, Y=HS, RB=D. Gatilhos ficam livres para sistema.
static func _default_player_1() -> Dictionary:
	return {
		&"up": [_key(KEY_W), _pad_button(JOY_BUTTON_DPAD_UP, 0), _pad_axis(JOY_AXIS_LEFT_Y, -1.0, 0)],
		&"down": [_key(KEY_S), _pad_button(JOY_BUTTON_DPAD_DOWN, 0), _pad_axis(JOY_AXIS_LEFT_Y, 1.0, 0)],
		&"left": [_key(KEY_A), _pad_button(JOY_BUTTON_DPAD_LEFT, 0), _pad_axis(JOY_AXIS_LEFT_X, -1.0, 0)],
		&"right": [_key(KEY_D), _pad_button(JOY_BUTTON_DPAD_RIGHT, 0), _pad_axis(JOY_AXIS_LEFT_X, 1.0, 0)],
		&"p": [_key(KEY_J), _pad_button(JOY_BUTTON_A, 0)],
		&"k": [_key(KEY_K), _pad_button(JOY_BUTTON_B, 0)],
		&"s": [_key(KEY_L), _pad_button(JOY_BUTTON_X, 0)],
		&"hs": [_key(KEY_U), _pad_button(JOY_BUTTON_Y, 0)],
		&"d": [_key(KEY_I), _pad_button(JOY_BUTTON_RIGHT_SHOULDER, 0)],
	}


## Teclado setas + teclado numerico, e controle no segundo dispositivo.
static func _default_player_2() -> Dictionary:
	return {
		&"up": [_key(KEY_UP), _pad_button(JOY_BUTTON_DPAD_UP, 1), _pad_axis(JOY_AXIS_LEFT_Y, -1.0, 1)],
		&"down": [_key(KEY_DOWN), _pad_button(JOY_BUTTON_DPAD_DOWN, 1), _pad_axis(JOY_AXIS_LEFT_Y, 1.0, 1)],
		&"left": [_key(KEY_LEFT), _pad_button(JOY_BUTTON_DPAD_LEFT, 1), _pad_axis(JOY_AXIS_LEFT_X, -1.0, 1)],
		&"right": [_key(KEY_RIGHT), _pad_button(JOY_BUTTON_DPAD_RIGHT, 1), _pad_axis(JOY_AXIS_LEFT_X, 1.0, 1)],
		&"p": [_key(KEY_KP_1), _pad_button(JOY_BUTTON_A, 1)],
		&"k": [_key(KEY_KP_2), _pad_button(JOY_BUTTON_B, 1)],
		&"s": [_key(KEY_KP_3), _pad_button(JOY_BUTTON_X, 1)],
		&"hs": [_key(KEY_KP_4), _pad_button(JOY_BUTTON_Y, 1)],
		&"d": [_key(KEY_KP_5), _pad_button(JOY_BUTTON_RIGHT_SHOULDER, 1)],
	}
