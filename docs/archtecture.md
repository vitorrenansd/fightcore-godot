# Arquitetura

FightCore e uma engine de luta 2D em Godot 4.7. Este documento descreve como o
projeto e organizado e quais regras valem em todo o codigo.

## Separacao engine / content

```
engine/     codigo generico, nao sabe qual personagem esta rodando
content/    personagens e estagios que usam a engine
shared/     efeitos e recursos usados por mais de um personagem
mods/       conteudo de terceiros
docs/       esta documentacao
tests/      testes headless
```

`engine/` nunca referencia nada de `content/`. Um personagem e a soma de uma cena
`.tscn` com o script `Fighter` e um conjunto de resources `.tres` — nao existe
codigo de engine especifico de personagem.

```
engine/
  battle/         partida, rounds e cronometro
  character/      Fighter, resources de dados, estados concretos
  collision/      hitbox, hurtbox, resolucao de acertos
  debug/          desenho de boxes para ajuste de frame data
  input/          buffer de input, motion e mapeamento
  physics/        gravidade, movimento, knockback
  state_machine/  FSM generica
```

## Regras da engine

**Simulacao em passo fixo.** Toda logica de luta roda em `_physics_process`, com
`physics_ticks_per_second = 60`. Nada de logica de combate em `_process` ou
dependente de framerate de video.

**Contagem inteira de frames.** Startup, hitstun, blockstun e recovery sao
contados em `int`, nunca em segundos e nunca com `await` ou `Timer`. Todo estado
carrega um `state_frame`.

**Dado authorado vive em `.tres`.** Frame data, stats e listas de golpes sao
resources, nao constantes em script. Resources sao compartilhados entre lutadores,
entao **nunca** guardam estado de runtime: quem guarda estado e o no.

**Nada de deteccao de acerto por sinal.** Overlap de `Area2D` chega um frame
depois. Acerto e resolvido por consulta direta ao PhysicsServer no mesmo frame.
Ver [hitboxes.md](hitboxes.md).

**Flip so no `Visuals`.** Virar o lutador nunca usa `scale.x = -1` na raiz. O no
`Visuals` inverte a escala; as boxes sao espelhadas por codigo, com offset.

## Fluxo de um frame

```
Fighter._physics_process            (um por lutador)
  hitstop -> congela e sai
  hitbox_manager.advance()          avanca o frame do ataque
  state_machine.physics_update()    logica do estado atual
  gravidade + move_and_slide()

CollisionSolver._physics_process    (process_physics_priority = 100)
  consulta as hitboxes ativas contra as hurtboxes adversarias
  monta os HitData do frame
  aplica todos de uma vez
```

O solver roda com prioridade alta de fisica para agir depois de todos os
lutadores terem se movido, sem depender da ordem deles na cena.

## Estado atual

| Sistema | Situacao |
|---|---|
| FSM generica (`state_machine/`) | pronto — [state_machine.md](state_machine.md) |
| Fighter, stats e movimento | pronto — [fighter_format.md](fighter_format.md) |
| Estados de fighter | idle, walk, jump, crouch, block, hitstun, attack, ko |
| Hitbox / hurtbox / HitData | pronto — [hitboxes.md](hitboxes.md) |
| `BattleManager` | pronto — [battle.md](battle.md) |
| Input, buffer e comandos | pronto — [input.md](input.md) |
| Sala de treino jogavel | `content/battle/training.tscn` |
| `battle/` round e cronometro | stub |
| `physics/` (gravidade, movimento, knockback) | stub — gravidade vive no `Fighter` |
| `character/fighter_loader`, `fighter_manager` | stub |
| Animacao | stub — [animation.md](animation.md) |
| Modding | stub — [modding.md](modding.md) |
