class_name HitboxManager
extends Node

## Owner of a fighter's boxes.
##
## Holds the current attack frame, decides which hitboxes are active and keeps
## track of who has already been hit. Mutable state lives here and never in the
## resources: AttackData and Hitbox are shared between fighters and can never
## carry runtime state.

signal attack_started(attack: AttackData)
signal attack_finished()

var fighter: Fighter
var current_attack: AttackData
## Current attack frame, counted from 0. Reads -1 while not attacking.
var attack_frame: int = -1
## Whether the current attack has touched anyone, on hit or on block. Cancels
## are gated on this, which is what stops a whiffed move from being free.
var has_connected: bool = false

## Last frame of the current attack. Kept here rather than read off the resource
## every frame because connecting can bring it forward — see
## `AttackData.recovery_on_hit`. Reads -1 while not attacking.
var _last_frame: int = -1

var _hurtboxes: Array[Hurtbox] = []
## victim_id -> { hit_group: true }
var _hits: Dictionary = {}


func setup(owner_fighter: Fighter) -> void:
	fighter = owner_fighter
	_collect_hurtboxes()
	set_facing(fighter.facing_right)


func is_attacking() -> bool:
	return current_attack != null


## True while the move has not become active yet: the counter hit window.
func is_in_startup() -> bool:
	return is_attacking() and attack_frame < current_attack.startup_frames


## Whether the current attack is open to being cancelled right now.
func is_in_cancel_window() -> bool:
	if not is_attacking():
		return false
	if attack_frame < current_attack.get_cancel_window_start():
		return false
	return has_connected or current_attack.can_whiff_cancel


func start_attack(attack: AttackData) -> void:
	if attack == null:
		return
	current_attack = attack
	attack_frame = 0
	_last_frame = attack.get_last_frame()
	has_connected = false
	_hits.clear()
	attack_started.emit(attack)


func stop_attack() -> void:
	if not is_attacking():
		return
	current_attack = null
	attack_frame = -1
	_last_frame = -1
	has_connected = false
	_hits.clear()
	attack_finished.emit()


## Advances the attack frame. Called once per physics frame by the Fighter,
## before the state machine, so an attack started this frame lands on frame 0.
func advance() -> void:
	if not is_attacking():
		return
	attack_frame += 1
	if attack_frame > _last_frame:
		stop_attack()


func get_active_hitboxes() -> Array[Hitbox]:
	var active: Array[Hitbox] = []
	if not is_attacking():
		return active
	for hitbox in current_attack.hitboxes:
		if hitbox != null and hitbox.is_active_on_frame(attack_frame):
			active.append(hitbox)
	return active


## False once this hitbox group has already connected during the current attack.
func can_hit(victim: Fighter, hit_group: int) -> bool:
	if victim == null:
		return false
	var groups: Dictionary = _hits.get(victim.get_instance_id(), {})
	return not groups.has(hit_group)


func register_hit(victim: Fighter, hit_group: int) -> void:
	if victim == null:
		return
	var victim_id := victim.get_instance_id()
	if not _hits.has(victim_id):
		_hits[victim_id] = {}
	_hits[victim_id][hit_group] = true
	has_connected = true
	# A move that authors its own recovery on hit ends earlier now that it has
	# landed. Only ever earlier: connecting cannot lengthen a move.
	if current_attack.recovery_on_hit >= 0:
		_last_frame = mini(_last_frame, attack_frame + current_attack.recovery_on_hit)


func get_hurtboxes() -> Array[Hurtbox]:
	return _hurtboxes


func set_facing(facing_right: bool) -> void:
	for hurtbox in _hurtboxes:
		hurtbox.set_facing(facing_right)


func set_hurtboxes_enabled(enabled: bool) -> void:
	for hurtbox in _hurtboxes:
		hurtbox.set_enabled(enabled)


## Full-body invincibility, used by reversals and wakeup.
func set_invulnerable(invulnerable: bool) -> void:
	for hurtbox in _hurtboxes:
		hurtbox.set_invulnerable(invulnerable)


func _collect_hurtboxes() -> void:
	_hurtboxes.clear()
	if fighter == null:
		return
	_collect_hurtboxes_from(fighter)


func _collect_hurtboxes_from(node: Node) -> void:
	for child in node.get_children():
		if child is Hurtbox:
			var hurtbox: Hurtbox = child
			hurtbox.setup(fighter)
			_hurtboxes.append(hurtbox)
		_collect_hurtboxes_from(child)
