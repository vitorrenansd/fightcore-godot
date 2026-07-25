extends SceneTree

## Verifica o input de ponta a ponta com input simulado: buffer, SOCD,
## reconhecimento de motion e o golpe saindo pelo estado de ataque.
##
##   godot --headless --path . --script tests/input_smoke_test.gd

const FIGHTER_SCENE := "res://content/fighters/training_dummy/fighter.tscn"

var battle: BattleManager
var p1: Fighter
var p2: Fighter
var frames: int = 0
var landed: Array[HitData] = []
var accepted: Array[CommandData] = []
var ok: bool = true

## Acoes seguradas neste frame, repostas a cada frame para o Godot enxergar
## press e release do jeito certo.
var _held: Array[StringName] = []


func _initialize() -> void:
	var scene: PackedScene = load(FIGHTER_SCENE)
	battle = BattleManager.new()
	battle.fighter_scenes = [scene, scene]
	battle.spawn_positions = [Vector2(-60, 0), Vector2(60, 0)]
	battle.hit_resolved.connect(func(hit: HitData) -> void: landed.append(hit))
	root.add_child(battle)

	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 40)
	floor_shape.shape = rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 70)
	root.add_child(floor_body)


func hold(actions: Array[StringName]) -> void:
	for action in _held:
		if not actions.has(action):
			Input.action_release(action)
	for action in actions:
		if not _held.has(action):
			Input.action_press(action)
	_held = actions.duplicate()


func check(condition: bool, message: String) -> void:
	if not condition:
		ok = false
		print("  FALHA: %s" % message)


func _physics_process(_delta: float) -> bool:
	frames += 1
	match frames:
		1:
			p1 = battle.get_fighter(0)
			p2 = battle.get_fighter(1)
			p1.input.command_accepted.connect(func(c: CommandData) -> void: accepted.append(c))
			# O dummy nao reage: so o p1 recebe comando neste teste.
			p2.input.enabled = false
			print("== 1. acoes registradas no InputMap ==")
			for action in [&"p1_left", &"p1_right", &"p1_up", &"p1_down", &"p1_p", &"p1_k", &"p1_s", &"p1_hs", &"p1_d"]:
				check(InputMap.has_action(action), "acao %s registrada" % action)
			check(not Input.use_accumulated_input, "input acumulado desligado")
			print("  %d acoes de p1 e p2 no mapa" % InputMap.get_actions().size())

			print("\n== 2. SOCD: esquerda + direita ao mesmo tempo ==")
			hold([&"p1_left", &"p1_right"])
		3:
			print("  direcao com os dois lados apertados: %d" % p1.input.get_direction())
			check(p1.input.get_direction() == FightInput.NEUTRAL, "opostos se cancelam (neutro)")
			hold([&"p1_right"])
		6:
			check(p1.input.get_direction() == 6, "direita sozinha = 6")
			check(p1.state_machine.current_state.name == &"Walk", "andando para frente")
			hold([&"p1_down"])
		9:
			check(p1.input.get_direction() == 2, "baixo = 2")
			check(p1.state_machine.current_state.name == &"Crouch", "agachado")
			check(p1.get_stance() == CommandData.Stance.CROUCH, "postura agachada")

			print("\n== 3. golpe baixo por postura: 2K ==")
			hold([&"p1_down", &"p1_k"])
		11:
			check(accepted.size() == 1, "um comando aceito")
			if accepted.size() == 1:
				print("  comando: %s" % accepted[0].command_id)
				check(accepted[0].command_id == &"2K", "agachado + K deu 2K, nao 5K")
			check(p1.state_machine.current_state.name == &"Attack", "entrou em Attack")
			hold([])
		30:
			print("\n== 4. buffer: botao apertado antes de poder agir ==")
			accepted.clear()
			check(p1.can_act(), "p1 livre")
			hold([&"p1_hs"])
		31:
			hold([])
			check(accepted.size() == 1 and accepted[0].command_id == &"5HS", "5HS saiu")
			# 5HS tem 40 frames no total; o P apertado agora e no meio do golpe
			# e precisa sobreviver ate o fim da recuperacao.
		34:
			hold([&"p1_p"])
		35:
			hold([])
			check(accepted.size() == 1, "aperto no meio do golpe nao sai na hora")
		42:
			print("  golpes aceitos ate aqui: %d (buffer de 8 frames ja expirou)" % accepted.size())
			check(accepted.size() == 1, "buffer de 8 frames expira, nao guarda para sempre")

		75:
			print("\n== 5. motion: 236 + S ==")
			accepted.clear()
			hold([&"p1_down"])
		77:
			hold([&"p1_down", &"p1_right"])
		79:
			hold([&"p1_right"])
		81:
			hold([&"p1_right", &"p1_s"])
		83:
			hold([])
			check(accepted.size() == 1, "um comando aceito no 236S")
			if accepted.size() == 1:
				print("  comando: %s (prioridade %d)" % [
					accepted[0].command_id, accepted[0].get_effective_priority(),
				])
				check(accepted[0].command_id == &"236S", "236+S deu o especial, nao 5S")
		130:
			print("\n== 6. diagonal pulada ainda vale (2 -> 6, sem o 3) ==")
			accepted.clear()
			hold([&"p1_down"])
		133:
			hold([&"p1_right"])
		135:
			hold([&"p1_right", &"p1_s"])
		137:
			hold([])
			if accepted.size() == 1:
				print("  comando: %s" % accepted[0].command_id)
				check(accepted[0].command_id == &"236S", "meia lua sem a diagonal ainda sai")
			else:
				check(false, "nenhum comando aceito com a diagonal pulada")
		185:
			print("\n== 7. o golpe acerta o oponente ==")
			landed.clear()
			p1.position = Vector2(-60, 0)
			p2.position = Vector2(10, 0)
		187:
			hold([&"p1_s"])
		188:
			hold([])
		200:
			print("  acertos: %d  vida do p2: %d" % [landed.size(), p2.health])
			check(landed.size() == 1, "5S acertou")
			check(p2.health < 10000, "dano aplicado")
		201:
			print("\nRESULTADO: %s" % ("OK" if ok else "FALHOU"))
			quit(0 if ok else 1)
			return true
	return false
