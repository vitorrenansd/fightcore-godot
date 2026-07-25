# Partida

`BattleManager` (`engine/battle/battle_manager.gd`) e o dono da partida: instancia
os lutadores, define os times, liga os oponentes e roda o `CollisionSolver`. E o
unico lugar da engine que sabe que existem dois lados.

Round, cronometro e placar **nao** ficam aqui — sao do `RoundManager`, ainda stub.

## Montagem

```gdscript
var battle := BattleManager.new()
battle.fighter_scenes = [p1_scene, p2_scene]
battle.spawn_positions = [Vector2(-120, 0), Vector2(120, 0)]
add_child(battle)
```

Com `start_on_ready` (padrao), a partida comeca sozinha assim que o no entra na
arvore. Para controlar na mao, desligue e chame `start_battle()`.

O `team` de cada lutador e o indice dele em `fighter_scenes`, e e definido
**antes** do lutador entrar na arvore, porque e ele que decide em qual camada as
hurtboxes vao ser registradas.

`pair_fighters()` roda so depois de todos estarem na arvore: ligar oponente e
ajustar facing mexe em nos que so existem depois do `_ready` do lutador.

## Solver

O `BattleManager` cria o `CollisionSolver` como filho e registra cada lutador
nele. O solver se resolve sozinho todo frame de fisica, com
`process_physics_priority = 100` para rodar depois de todos os lutadores terem se
movido. Ver [hitboxes.md](hitboxes.md).

## Facing

Quem decide de que lado cada lutador olha e a partida, nao o lutador: saber quem
e o oponente de quem e responsabilidade daqui.

```gdscript
for fighter in fighters:
	if fighter.can_turn():
		fighter.update_facing()
```

`can_turn()` e falso durante ataque, stun, hitstop e no ar. Na pratica: **golpe
comecado nao vira de lado no meio**. Um lutador que cruza para o outro lado
durante o proprio golpe continua batendo para onde comecou, que e o
comportamento esperado do genero (e o que faz crossup existir).

## API

| Membro | Uso |
|---|---|
| `fighters` | lutadores da partida, na ordem dos times |
| `solver` | o `CollisionSolver` da partida |
| `start_battle()` | limpa e monta tudo de novo |
| `spawn_fighter(scene, index)` | instancia um lutador no time `index` |
| `register_fighter(f)` | registra um lutador ja existente |
| `pair_fighters()` | liga oponentes e ajusta o facing inicial |
| `get_fighter(team)` | lutador de um time |
| `get_opponent_of(f)` | adversario de um lutador |
| `reset_positions()` | volta todos para o spawn (reset de round) |
| `clear_battle()` | remove todos os lutadores |

**Sinais**: `battle_started`, `fighter_spawned(fighter)`, `fighter_died(fighter)`,
`hit_resolved(hit)`.

## Teste

```sh
godot --headless --path . --script tests/battle_smoke_test.gd
```

Cobre spawn, times, facing, o solver resolvendo acerto sozinho e o KO.

## Ainda nao implementado

- `RoundManager` e `Timer`: rounds, contagem regressiva, vitoria.
- Camera, limites de tela e pushback na parede.
- Entrada de input: hoje o golpe so sai chamando `Fighter.perform_attack()`.
