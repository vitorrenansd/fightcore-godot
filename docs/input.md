# Input

Leitura de comando do FightCore: buffer, motion classico (meia lua, dragon
punch) e mapeamento personalizavel.

## Layout de botoes

Cinco botoes, no formato Guilty Gear:

| Botao | Nome | Papel |
|---|---|---|
| P | Soco | golpe rapido, pouco dano |
| K | Chute | alcance medio |
| S | Slash | golpe forte |
| HS | Heavy Slash | golpe lento e pesado |
| D | Dust | overhead universal sozinho, agarrao com direcao |

`SYSTEM_1..3` ficam reservados no bitmask para mecanica de sistema (burst,
roman cancel, macro). Botao nao mapeado nao custa nada e nao compromete design.

O D existe para dar a todo personagem um overhead e um launcher sem precisar
authorar isso golpe a golpe.

**Specials saem por motion**, nao por botao dedicado: `236S`, `623P`, `214K`.
E o que faz cinco botoes gerarem dezenas de golpes.

## Notacao numerica

Direcao usa a notacao do teclado numerico, padrao do genero no mundo todo:

```
7 8 9      cima-tras   cima   cima-frente
4 5 6      tras        neutro frente
1 2 3      baixo-tras  baixo  baixo-frente
```

A engine **guarda a direcao absoluta** (4 e sempre a esquerda da tela) e
converte para frente/tras na leitura, usando o facing. E o que faz um input
gravado antes de trocar de lado continuar valendo.

| Motion | Sequencia |
|---|---|
| meia lua frente | `[2, 3, 6]` |
| meia lua tras | `[2, 1, 4]` |
| dragon punch | `[6, 2, 3]` |
| normal | `[]` |

## Pecas

| Classe | Arquivo | Papel |
|---|---|---|
| `FightInput` | `engine/input/fight_input.gd` | vocabulario: botoes, direcoes, SOCD |
| `InputBindings` | `engine/input/input_bindings.gd` | mapeamento fisico, remapeavel |
| `InputDevice` | `engine/input/input_device.gd` | le o InputMap e limpa SOCD |
| `InputHistory` | `engine/input/input_history.gd` | historico circular, um registro por frame |
| `CommandParser` | `engine/input/command_parser.gd` | casa motion contra o historico |
| `InputBuffer` | `engine/input/input_buffer.gd` | componente do lutador, junta tudo |
| `CommandData` | `engine/character/command_data.gd` | input -> golpe |

## Buffer

Exigir o frame exato e injusto: o jogador aperta o botao alguns frames antes de
poder agir e o golpe tem que sair mesmo assim. O padrao e **8 frames**, dentro
da faixa de 5 a 10 do genero — menos pune link legitimo, mais solta golpe que o
jogador nao pediu.

A amostragem continua durante o hitstop de proposito: e justamente quando o
jogador esta montando a continuacao do combo.

Aperto que virou golpe e marcado como gasto (`InputBuffer.consume()`), senao o
mesmo toque dispararia de novo nos frames seguintes.

## Reconhecimento de motion

O parser anda **para tras no tempo**, partindo do frame em que o botao desceu:
acha o botao dentro da janela de buffer, depois a ultima direcao do motion,
depois a anterior, ate a primeira. Nao importa quando o motion comecou, so que
tenha sido completado dentro de `motion_window` (padrao 20 frames).

**Diagonal pulada nao invalida** (`allow_skipped_diagonals`): quase ninguem
acerta o `3` de um `236`. Cardeal pulada invalida — senao `26` viraria meia lua
e specials sairiam sem querer.

Comando com motion tem prioridade sobre comando sem motion, senao `236S` sairia
como `5S` puro.

## SOCD

Controle leverless (hitbox) permite segurar esquerda e direita ao mesmo tempo,
o que produz input ambiguo e e banido em torneio sem tratamento. `InputDevice`
resolve:

| Modo | Comportamento |
|---|---|
| `NEUTRAL` (padrao) | opostos se cancelam |
| `LAST_WINS` | vale a direcao apertada por ultimo |

Vertical sempre da prioridade para cima: pular vence agachar.

## Mapeamento personalizavel

As acoes (`p1_up`, `p1_p`, `p2_hs`...) sao criadas em runtime a partir de
`InputBindings`, e nao fixas no `project.godot`, porque remapear precisa
funcionar com o jogo rodando e ser salvo por usuario
(`user://input_bindings.tres`).

Teclado usa `physical_keycode`: a tecla e a posicao fisica, entao o padrao
funciona igual em ABNT2, QWERTY e AZERTY.

```gdscript
var bindings := InputBindings.load_or_create()
bindings.set_event(0, &"p", 0, event)   # jogador 1, botao P, slot 0
bindings.save()
```

Padrao de fabrica:

| | P1 | P2 |
|---|---|---|
| Direcao | WASD | setas |
| P K S HS D | J K L U I | numerico 1 2 3 4 5 |
| Controle | dispositivo 0 | dispositivo 1 |
| Controle: botoes | A=P B=K X=S Y=HS RB=D | igual |

Analogico usa deadzone alta (0.5) de proposito: sem isso ele se comporta como
eixo continuo e produz direcao intermediaria, virando motion falso.

`Input.use_accumulated_input` e desligado ao aplicar os bindings — o Godot
juntaria eventos do mesmo frame e o timing sub-frame de link se perderia.

## Comandos de um personagem

`CommandData` mora em `FighterData.commands`. Cada um liga um input a um
`AttackData`:

```gdscript
command.motion = [2, 3, 6]
command.button = FightInput.Buttons.S
command.stance = CommandData.Stance.ANY    # ANY, STAND, CROUCH, AIR
command.hold_direction = 6                 # opcional: 6P vira comando proprio
```

`button` e bitmask e nao enum de proposito: macro de dois botoes (agarrao,
burst) precisa marcar mais de um.

Comandos do training dummy: `5P`, `5K`, `2K`, `5S`, `5HS`, `5D` e `236S`.

## Guarda

Defesa nao e botao: **quem segura para tras defende**, como em todo jogo 2D do
genero. `Fighter.is_blocking()` olha o input, nao o estado. Segurar baixo-tras
defende golpe baixo; em pe defende overhead.

## Sala de treino

`content/battle/training.tscn` e a cena principal do projeto. Mostra vida,
estado, frame do golpe, direcao lida e hitstop dos dois lados; **F1** liga e
desliga o desenho de hitbox e hurtbox.

## Teste

```sh
godot --headless --path . --script tests/input_smoke_test.gd
```

Simula input com `Input.action_press` e cobre SOCD, postura, buffer, motion,
diagonal pulada e o golpe acertando.

## Ainda nao implementado

- Motion de carga (`[4]` segurado 40 frames depois `6`).
- Comando de dois botoes na pratica (o bitmask ja aceita).
- Tela de remapeamento: a API existe, falta a interface.
- Cancels: hoje um golpe so pode ser cancelado depois de terminar.
