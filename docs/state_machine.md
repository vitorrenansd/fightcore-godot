# State Machine

FSM generica usada pelos lutadores. Cada estado e um no filho da state machine, e
a contagem de frames e inteira: nada de `await`, `Timer` ou tempo em segundos.

## Classes

| Classe | Arquivo | Papel |
|---|---|---|
| `State` | `engine/state_machine/state.gd` | base de qualquer estado, conta `state_frame` |
| `StateMachine` | `engine/state_machine/state_machine.gd` | registra os filhos e troca de estado |
| `FighterState` | `engine/character/fighter_state.gd` | base dos estados de lutador, expoe `fighter` |
| `FighterStateMachine` | `engine/character/fighter_state_machine.gd` | FSM do lutador |

A FSM e generica de proposito: `engine/state_machine/` nao sabe o que e um
lutador. O acoplamento acontece so em `FighterState`, que resolve `fighter` a
partir do `owner` da cena.

## Como funciona

Os estados sao nos filhos da `StateMachine`. No `_ready` ela indexa cada filho
pelo nome do no e conecta o sinal `transitioned` de todos:

```
StateMachine
├── Idle
├── Walk
├── Jump
├── Crouch
├── Block
└── Hitstun
```

O nome do no **e** o identificador do estado, entao `transition_to(&"Hitstun")`
depende do no se chamar `Hitstun`.

`Fighter._physics_process` chama `state_machine.physics_update(delta)`, que
repassa para o estado atual. A FSM nao tem `_process` proprio: quem dita o ritmo
e o lutador, porque durante o hitstop ele precisa congelar a maquina inteira.

## Contagem de frames

```gdscript
func enter() -> void:
	state_frame = 0

func physics_update(_delta: float) -> void:
	state_frame += 1
```

`enter()` zera e cada update incrementa **antes** da logica, entao no primeiro
update `state_frame == 1`. Um estado que dura N frames sai quando
`state_frame >= N`.

## Trocando de estado

Do proprio estado, por sinal:

```gdscript
if fighter.is_on_floor():
	transitioned.emit(&"Idle")
```

De fora, direto:

```gdscript
fighter.state_machine.transition_to(&"Block")
```

`transition_to` ignora nome desconhecido e ignora transicao para o estado atual —
ou seja, **reentrar no mesmo estado nao chama `enter()` de novo**. Quem precisa
reiniciar (todo hit de combo depois do primeiro) usa um metodo proprio:

```gdscript
# Fighter._enter_hitstun
var state := state_machine.get_state(&"Hitstun") as FighterHitstunState
state.start_hitstun(hit.stun_frames)   # zera state_frame na mao
state_machine.transition_to(&"Hitstun")
```

`get_state()` existe justamente para parametrizar um estado antes de entrar nele:
hitstun e blockstun recebem a duracao do golpe que acabou de acertar.

## Estados atuais

| Estado | Comportamento |
|---|---|
| `Idle` | zera velocidade horizontal |
| `Walk` | aplica `direction` na velocidade de caminhada |
| `Jump` | pula ao entrar, volta para `Idle` ao tocar o chao |
| `Crouch` | zera velocidade horizontal, conta como abaixado na guarda |
| `Block` | guarda em pe ou abaixada; com `stun_frames > 0` vira blockstun |
| `Hitstun` | preso pelos frames do golpe; ao sair zera o combo do lutador |

`Block` acumula duas funcoes de proposito: segurar a guarda (`stun_frames == 0`,
sai quando quiser) e o blockstun (`stun_frames > 0`, preso). `crouch_block` diz
se a guarda e baixa, o que decide se um overhead ou um golpe baixo passa.

## Adicionando um estado

1. Criar o script em `engine/character/states/`:

```gdscript
class_name FighterDashState
extends FighterState

func enter() -> void:
	super()
	fighter.velocity.x = fighter.stats.dash_speed * (1.0 if fighter.facing_right else -1.0)

func physics_update(delta: float) -> void:
	super(delta)
	if state_frame >= 12:
		transitioned.emit(&"Idle")
```

2. Adicionar um no com esse script sob `StateMachine` na cena do lutador, com o
   nome que sera usado nas transicoes.

Sempre chamar `super()` em `enter()` e `super(delta)` em `physics_update()`: e o
que zera e incrementa `state_frame`.
