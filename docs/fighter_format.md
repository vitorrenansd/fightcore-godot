# Formato de Fighter

Um personagem e uma pasta em `content/fighters/<id>/` com uma cena e resources
`.tres`. Nenhum codigo de engine e especifico de personagem: o script do
personagem so precisa estender `Fighter`.

## Estrutura de pastas

```
content/fighters/training_dummy/
├── fighter.tscn          cena do personagem
├── fighter.gd            extends Fighter
├── fighter_data.tres     FighterData: identidade, stats, golpes
├── moves/                um AttackData .tres por golpe
└── config/
    └── fighter_stats.tres  FighterStats
```

## Cena

A cena precisa destes nos, com estes nomes — o `Fighter` busca por caminho fixo:

```
TrainingDummy (CharacterBody2D + script que estende Fighter)
├── Visuals (Node2D)             unico no que inverte escala no flip
├── CollisionShape2D             corpo fisico contra chao e paredes
├── StateMachine (FighterStateMachine)
│   ├── Idle, Walk, Jump, Crouch, Block, Hitstun, Attack, KO
├── HitboxManager                dono das boxes
├── Input (InputBuffer)          opcional: sem ele o lutador nao age
└── Hurtboxes (Node2D)
    ├── Body (Hurtbox, height = MID)
    └── Head (Hurtbox, height = HIGH)
```

`Visuals`, `StateMachine` e `HitboxManager` sao obrigatorios. As hurtboxes podem
estar em qualquer lugar da subarvore: o `HitboxManager` varre tudo abaixo do
lutador no `_ready`.

Cada `Hurtbox` deve ficar no **centro da propria caixa**, porque e a posicao do no
que e espelhada no flip. Ver [hitboxes.md](hitboxes.md).

## Resources

### FighterData

`engine/character/fighter_data.gd` — identidade e conteudo do personagem.

| Campo | Tipo | Uso |
|---|---|---|
| `fighter_id` | `StringName` | id interno, bate com o nome da pasta |
| `display_name` | `String` | nome exibido |
| `portrait` | `Texture2D` | retrato de selecao |
| `sprite_frames` | `SpriteFrames` | animacoes |
| `stats` | `FighterStats` | numeros do personagem |
| `moves` | `Array[AttackData]` | golpes |
| `commands` | `Array[CommandData]` | comandos que disparam os golpes — [input.md](input.md) |

### FighterStats

`engine/character/fighter_stats.gd` — os numeros que balanceiam o personagem.

| Campo | Padrao | Uso |
|---|---|---|
| `max_health` | 10000 | vida cheia; 10k a 15k da rounds de ~20s |
| `max_meter` | 10000 | barra especial |
| `walk_speed` | 150.0 | px/s andando |
| `dash_speed` | 400.0 | px/s no dash |
| `jump_velocity` | -650.0 | impulso do pulo (negativo sobe) |
| `gravity` | 1800.0 | px/s² |
| `weight` | 1.0 | divide o knockback recebido |
| `defense_multiplier` | 1.0 | multiplica o dano recebido |

### AttackData

`engine/character/attack_data.gd` — frame data e propriedades de acerto de um
golpe. Documentado em [hitboxes.md](hitboxes.md).

### CommandData

`engine/character/command_data.gd` — liga um input (motion + botao + postura) a
um `AttackData`. Documentado em [input.md](input.md).

## Script do personagem

```gdscript
extends Fighter
```

So isso. O `Fighter` cuida de vida, facing, gravidade, hitstop, reacao a acerto e
guarda. O script do personagem existe para comportamento exclusivo dele.

## API do Fighter

`engine/character/fighter.gd`.

**Estado**

| Membro | Uso |
|---|---|
| `fighter_data` | resource do personagem |
| `team` | define a camada das hurtboxes e quem ele pode acertar |
| `opponent` | usado pelo `update_facing()` |
| `facing_right` | lado que encara |
| `health` | vida atual |
| `combo_hits` | golpes ja levados no combo, base do escalonamento |
| `hitstop_frames` | frames de congelamento restantes |
| `stats` | atalho para `fighter_data.stats` |

**Movimento**: `walk(direction)`, `jump()`, `update_facing()`, `set_facing()`.

**Combate**: `perform_attack(attack)`, `perform_attack_by_id(id)`,
`get_attack(id)`, `apply_hit(hit)`, `apply_hit_landed(hit)`,
`apply_hitstop(frames)`, `can_block(guard)`, `is_blocking()`, `is_crouching()`,
`can_be_hit()`, `reset_combo()`.

**Consultas de estado**: `can_act()` (livre para receber comando), `can_turn()`
(pode virar de lado), `is_in_stun()`, `is_alive()`.

**Sinais**: `health_changed`, `hit_taken`, `hit_landed`, `died`.

## Criando um personagem novo

1. Copiar `content/fighters/training_dummy/` para `content/fighters/<id>/`.
2. Ajustar `fighter_id` e `display_name` no `fighter_data.tres`.
3. Ajustar os numeros em `config/fighter_stats.tres`.
4. Redimensionar as hurtboxes na cena para o corpo do personagem.
5. Criar os `AttackData` dos golpes em `moves/` e listar em `moves`.
6. Criar os `CommandData` que disparam cada golpe e listar em `commands`.
