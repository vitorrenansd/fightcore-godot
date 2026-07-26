extends SceneTree

## Checks knockback friction: a fighter hit on the ground slides to a stop
## instead of travelling at a constant speed until the stun ends, never bounces
## back toward the attacker, and keeps their arc untouched in the air.
##
##   godot --headless --path . --script tests/friction_smoke_test.gd

const FIGHTER_SCENE := "res://content/fighters/training_dummy/fighter.tscn"

var p1: Fighter
var p2: Fighter
var solver: CollisionSolver
var frames: int = 0
var landed: Array[HitData] = []
var ok: bool = true

## Sampled while p2 is being pushed around.
var _observing: bool = false
var _samples: Array[float] = []
var _went_backwards: bool = false
var _sped_up: bool = false
var _stopped_frame: int = -1
var _hitstun_end_frame: int = -1
var _air_samples: Array[float] = []


func _initialize() -> void:
	var scene: PackedScene = load(FIGHTER_SCENE)
	InputBindings.create_default().apply()

	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	floor_shape.shape = rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 70)
	root.add_child(floor_body)

	p1 = scene.instantiate()
	p1.team = 0
	root.add_child(p1)
	p1.position = Vector2(0, 0)

	p2 = scene.instantiate()
	p2.team = 1
	root.add_child(p2)
	p2.position = Vector2(60, 0)

	solver = CollisionSolver.new()
	root.add_child(solver)
	solver.register_fighter(p1)
	solver.register_fighter(p2)
	solver.hit_resolved.connect(func(hit: HitData) -> void: landed.append(hit))


func _make_attack(knockback: Vector2, hitstun: int, blockstun: int) -> AttackData:
	var box := Hitbox.new()
	var box_shape := RectangleShape2D.new()
	box_shape.size = Vector2(60, 60)
	box.shape = box_shape
	box.offset = Vector2(60, 0)
	box.start_frame = 4
	box.end_frame = 6

	var attack := AttackData.new()
	attack.startup_frames = 4
	attack.active_frames = 3
	attack.recovery_frames = 8
	attack.damage = 200
	attack.chip_damage = 20
	attack.hitstun = hitstun
	attack.blockstun = blockstun
	attack.hitstop = 4
	attack.knockback = knockback
	attack.block_pushback = knockback
	attack.hitboxes = [box]
	return attack


func check(condition: bool, message: String) -> void:
	if not condition:
		ok = false
		print("  FAIL: %s" % message)


## Records the slide, ignoring the frozen frames where nothing moves.
func _observe() -> void:
	if p2.hitstop_frames > 0:
		return
	if _samples.size() > 0:
		var previous: float = _samples[-1]
		if p2.velocity.x < -0.01:
			_went_backwards = true
		if p2.velocity.x > previous + 0.01:
			_sped_up = true
		if _stopped_frame < 0 and is_zero_approx(p2.velocity.x):
			_stopped_frame = frames
		if _hitstun_end_frame < 0 and not p2.is_in_hitstun():
			_hitstun_end_frame = frames
	_samples.append(p2.velocity.x)


func _physics_process(_delta: float) -> bool:
	frames += 1
	if _observing:
		_observe()
	match frames:
		1:
			p1.opponent = p2
			p2.opponent = p1
			p1.set_facing(true)
			p2.set_facing(false)
			p1.input.enabled = false
			p2.input.enabled = false
			p2.input.player_index = 1
			print("== 1. a grounded hit slides to a stop ==")
			# Long hitstun so the slide has room to finish inside it.
			p1.hitbox_manager.start_attack(_make_attack(Vector2(400, 0), 40, 12))
		10:
			_observing = true
		56:
			_observing = false
			print("  samples %d   first %.0f   last %.0f" % [
				_samples.size(), _samples[0], _samples[-1],
			])
			print("  went backwards: %s   sped up: %s" % [_went_backwards, _sped_up])
			print("  stopped on f%d, hitstun ended on f%d" % [
				_stopped_frame, _hitstun_end_frame,
			])
			check(landed.size() == 1, "the move connected")
			check(_samples[0] > 100.0, "the hit pushed p2 away to begin with")
			check(is_zero_approx(_samples[-1]), "the slide came to a full stop")
			check(not _sped_up, "the slide only ever loses speed")
			check(
				not _went_backwards,
				"it stops at zero instead of bouncing back at the attacker"
			)
			check(_stopped_frame > 0, "the slide ended on its own")
			check(_hitstun_end_frame > 0, "hitstun ran out during the window")
			# The point of the whole thing: the slide is ended by friction, not
			# by the stun timer expiring underneath it.
			check(
				_stopped_frame < _hitstun_end_frame,
				"friction ended the slide, not the end of hitstun"
			)
		90:
			print("\n== 2. a fighter in control is not slowed down ==")
			landed.clear()
			p2.state_machine.transition_to(&"Idle")
			p2.position = Vector2(200, 0)
			p2.velocity = Vector2.ZERO
			p2.walk(1.0)
		92:
			var before := p2.velocity.x
			p2.walk(1.0)
			print("  walking at %.0f, still %.0f a frame later" % [before, p2.velocity.x])
			check(
				is_equal_approx(p2.velocity.x, p2.stats.walk_speed),
				"walking speed is untouched, got %.0f" % p2.velocity.x
			)
		100:
			print("\n== 3. blockstun pushback decays too ==")
			landed.clear()
			_samples.clear()
			_went_backwards = false
			_sped_up = false
			p2.state_machine.transition_to(&"Idle")
			p2.velocity = Vector2.ZERO
			p1.position = Vector2(0, 0)
			p1.velocity = Vector2.ZERO
			p2.position = Vector2(60, 0)
			p2.input.enabled = true
			# p2 faces left, so its back is screen right.
			Input.action_press(&"p2_right")
			p1.hitbox_manager.start_attack(_make_attack(Vector2(400, 0), 40, 30))
		110:
			_observing = true
		136:
			_observing = false
			print("  blocked %s   first %.0f   last %.0f   sped up %s" % [
				landed[0].blocked if landed.size() > 0 else false,
				_samples[0], _samples[-1], _sped_up,
			])
			check(landed.size() == 1, "the move connected")
			if landed.size() == 1:
				check(landed[0].blocked, "p2 blocked it")
			check(_samples[0] > 100.0, "the block pushed p2 away")
			check(is_zero_approx(_samples[-1]), "the pushback also came to a stop")
			check(not _sped_up, "and only ever lost speed")
			Input.action_release(&"p2_right")
		144:
			print("\n== 4. an airborne victim keeps their arc ==")
			landed.clear()
			p2.input.enabled = false
			p2.state_machine.transition_to(&"Jump")
			p2.position = Vector2(60, -300)
			p2.velocity = Vector2.ZERO
			p1.gravity_enabled = false
			p1.position = Vector2(0, -300)
			p1.hitbox_manager.start_attack(_make_attack(Vector2(400, -100), 40, 12))
		156:
			check(not p2.is_on_floor(), "p2 is airborne")
			check(p2.hitstop_frames == 0, "not frozen")
			_air_samples.append(p2.velocity.x)
		160:
			_air_samples.append(p2.velocity.x)
			print("  airborne horizontal speed %.0f -> %.0f" % [
				_air_samples[0], _air_samples[1],
			])
			check(_air_samples[0] > 100.0, "the air hit carried p2 away")
			check(
				is_equal_approx(_air_samples[0], _air_samples[1]),
				"no friction in the air, the juggle keeps its arc"
			)
		162:
			print("\nRESULT: %s" % ("OK" if ok else "FAILED"))
			quit(0 if ok else 1)
			return true
	return false
