# Hitboxes, Hurtboxes e HitData

Sistema de deteccao e resolucao de acertos do FightCore.

## Ideia central

**Hitbox e dado, hurtbox e volume.**

Só a hurtbox existe no servidor de fisica. A hitbox nunca vira no de cena: no frame
em que ela esta ativa, o `CollisionSolver` transforma ela em uma consulta
`PhysicsDirectSpaceState2D.intersect_shape` contra a camada de hurtbox do time
adversario.

Sinal de `Area2D` (`area_entered`, `get_overlapping_areas`) nao e usado em lugar
nenhum da resolucao: overlap de area so e atualizado uma vez por frame de fisica e
chega tarde demais, o que quebra trocas de golpe e trades no mesmo frame.

## Pecas

| Classe | Arquivo | O que e |
|---|---|---|
| `Hitbox` | `engine/collision/hitbox.gd` | `Resource` imutavel: forma, offset, janela de frames, `hit_group` |
| `Hurtbox` | `engine/collision/hurtbox.gd` | `Area2D` passiva na camada do time, `monitoring = false` |
| `AttackData` | `engine/character/attack_data.gd` | frame data e propriedades de acerto do golpe |
| `HitData` | `engine/collision/hit_data.gd` | resultado ja resolvido de um acerto |
| `HitboxManager` | `engine/collision/hitbox_manager.gd` | estado de runtime das boxes de um lutador |
| `CollisionSolver` | `engine/collision/collision_solver.gd` | consulta e aplica os acertos do frame |
| `CollisionLayers` | `engine/collision/collision_layer.gd` | mapa de camadas e mascaras |

`AttackData` e `Hitbox` sao compartilhados entre todos os lutadores que usam o
mesmo golpe, entao **nunca** guardam estado de runtime. Frame atual do ataque e
registro de quem ja foi acertado vivem no `HitboxManager`.

## Camadas

| Bit | Camada | Uso |
|---|---|---|
| 1 | `WORLD` | chao e paredes do estagio |
| 2 | `PUSHBOX` | colisao corpo a corpo entre lutadores |
| 3 | `HURTBOX_TEAM_0` | hurtboxes do time 0 |
| 4 | `HURTBOX_TEAM_1` | hurtboxes do time 1 |

Um atacante do time 0 consulta com `CollisionLayers.opponent_hurtbox_mask(0)`, que
devolve a camada de hurtbox do time 1. O filtro de time acontece na mascara da
consulta, nao em comparacao de owner no meio do loop.

## Fluxo de um frame

```
Fighter._physics_process (por lutador)
  1. hitstop_frames > 0  -> congela e sai
  2. hitbox_manager.advance()      # attack_frame += 1
  3. state_machine.physics_update()
  4. gravidade + move_and_slide()

CollisionSolver._physics_process   # process_physics_priority = 100
  5. para cada atacante, para cada hitbox ativa: intersect_shape
  6. monta os HitData de todos os acertos do frame
  7. so entao aplica: victim.apply_hit() / attacker.apply_hit_landed()
```

O passo 6 antes do 7 e o que permite **trade**: os dois lados confirmam o golpe
antes de qualquer um entrar em hitstun ou hitstop.

A prioridade alta de fisica garante que o solver rode depois de todos os lutadores
terem se movido, independente da ordem deles na cena.

## Contagem de frames

`attack_frame` comeca em `0` no frame em que `start_attack()` foi chamado, e
`advance()` roda antes da state machine. Um ataque com `startup_frames = 5` tem a
primeira hitbox ativa em `start_frame = 5`.

```
frame:   0  1  2  3  4 | 5  6  7 | 8 ... 19
         startup        | active  | recovery
```

Durante o hitstop o lutador nao chama `advance()`, entao os frames ativos ficam
congelados junto com o resto. Reacerto no mesmo golpe e evitado pelo registro de
`hit_group`, nao pela contagem de frames.

## Authorando um golpe

`AttackData` e um `.tres` com a lista de `Hitbox`:

```gdscript
var jab := AttackData.new()
jab.attack_id = &"5L"
jab.startup_frames = 4
jab.active_frames = 3
jab.recovery_frames = 8
jab.damage = 400
jab.hitstun = 16
jab.blockstun = 12
jab.hitstop = 6
jab.guard = AttackData.Guard.MID

var box := Hitbox.new()
box.shape = RectangleShape2D.new()
box.offset = Vector2(60, -20)   # sempre no espaco "olhando para a direita"
box.start_frame = 4             # == startup_frames
box.end_frame = 6               # start + active - 1
jab.hitboxes = [box]
```

Vantagem em hit e block **nao sao authoradas**: `get_advantage_on_hit()` e
`get_advantage_on_block()` derivam do frame data, entao nao existe dado duplicado
capaz de mentir sobre o golpe.

O offset e sempre escrito olhando para a direita e espelhado em runtime por
`get_query_transform()`. Escala negativa em no nunca e usada para virar o lutador:
so o no `Visuals` inverte, as boxes sao espelhadas por codigo.

### Multi-hit

Hitboxes com o mesmo `hit_group` contam como um golpe so — util para descrever um
golpe largo com varias caixas sem acertar duas vezes. Para um golpe que acerta de
verdade duas vezes, use grupos diferentes:

```gdscript
box_hit_1.hit_group = 0   # frames 8..10
box_hit_2.hit_group = 1   # frames 14..16
```

## Hurtboxes

Sao `Area2D` com o script `Hurtbox` e filhas `CollisionShape2D` authoradas na cena
do lutador (ver `content/fighters/training_dummy/fighter.tscn`). Cada `Hurtbox`
deve ficar **no centro da propria caixa**: e a posicao do no que e espelhada quando
o lutador troca de lado.

O `HitboxManager` varre a subarvore do lutador no `_ready` e registra todas.

- `height` (`HIGH` / `MID` / `LOW`) classifica a box para anti-aereo e overhead.
- `set_invulnerable(true)` tira o lutador do alcance das consultas sem mexer na
  cena — e assim que frames de invencibilidade de reversal e wakeup vao funcionar.

## Resolucao do acerto

`HitData.build()` produz o resultado final; quem recebe nao reinterpreta nada.

**Guarda** — `Fighter.can_block()`. Defender e segurar para tras, nao apertar
botao (ver [input.md](input.md)):

| `Guard` | Defende |
|---|---|
| `MID` | em pe ou abaixado |
| `HIGH` | so em pe (overhead) |
| `LOW` | so abaixado |
| `UNBLOCKABLE` | nunca |

Defendeu: leva `chip_damage` e entra em blockstun. Nao defendeu: leva o dano
escalonado e entra em hitstun.

**Escalonamento de dano** — cada golpe ja levado no combo tira `scaling_per_hit`
(10% por padrao) do dano, com piso em `min_damage_scaling`. `Fighter.combo_hits`
sobe a cada acerto limpo e zera quando o lutador sai do hitstun. Sem isso um combo
longo vira partida infinita.

**Counter hit** — acerto durante o startup do golpe do oponente. Multiplica o dano
e adiciona hitstun.

**Knockback** — `AttackData.knockback.x` e sempre "para longe do atacante"; o
solver orienta pelo facing e divide pelo `weight` do alvo.

**Hitstop** — os dois lados congelam pelos mesmos frames. Vale
`maxi(atual, novo)`, entao um acerto durante hitstop nao encurta o congelamento.

## Uso

O `BattleManager` ja cria o solver e registra os lutadores, entao normalmente
basta disparar o golpe:

```gdscript
fighter.perform_attack(attack_data)
fighter.perform_attack_by_id(&"5L")   # busca em fighter_data.moves
```

Montando na mao, fora de uma partida:

```gdscript
var solver := CollisionSolver.new()
add_child(solver)
solver.register_fighter(player_1)
solver.register_fighter(player_2)
solver.hit_resolved.connect(_on_hit_resolved)
```

Sinais uteis: `Fighter.hit_taken`, `Fighter.hit_landed`, `Fighter.health_changed`,
`Fighter.died`, `CollisionSolver.hit_resolved`.

## Teste

`tests/hitbox_smoke_test.gd` monta dois lutadores, um solver e tres cenarios
(acerto limpo, golpe defendido, golpe baixo contra guarda em pe) sem abrir editor:

```sh
godot --headless --path . --script tests/hitbox_smoke_test.gd
```

## Ainda nao implementado

- Cancels e hierarquia de cancelamento entre golpes.
- Pushbox (colisao corpo a corpo) e throwbox.
- Atrito no knockback: hoje o alvo desliza com velocidade constante ate sair do
  hitstun, porque `engine/physics/knockback.gd` ainda e stub.
- Proximity guard (bloqueio automatico quando a hitbox se aproxima).
- Hurtboxes por estado (agachado encolhe, aereo troca de altura).
