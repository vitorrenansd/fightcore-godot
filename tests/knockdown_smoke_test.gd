extends SceneTree

## Checks the knockdown: an air combo ends on the floor instead of handing
## control back mid-air, the fall stays vulnerable, the ground does not, and the
## fighter is actionable again the frame the wakeup ends.
##
##   godot --headless --path . --script tests/knockdown_smoke_test.gd

const FIGHTER_SCENE := "res://content/fighters/training_dummy/fighter.tscn"

var p1: Fighter
var p2: Fighter
var solver: CollisionSolver
var frames: int = 0
var landed: Array[HitData] = []
var ok: bool = true

## Observations collected frame by frame, so the assertions do not depend on
## guessing exactly when a falling body touches the floor.
var _observing: bool = false
var _saw_airborne_knockdown: bool = false
var _airborne_knockdown_vulnerable: bool = false
var _landed_frame: int = -1
var _wakeup_frame: int = -1
var _idle_frame: int = -1
var _vulnerable_while_down: bool = false


func _initialize() -> void:
	var scene: PackedScene = load(FIGHTER_SCENE)
	InputBindings.create_default().apply()

	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 40)
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


func _make_attack(knockback: Vector2, hitstun: int, knockdown: bool) -> AttackData:
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
	attack.hitstun = hitstun
	attack.hitstop = 4
	attack.knockback = knockback
	attack.causes_knockdown = knockdown
	attack.hitboxes = [box]
	return attack


func _state_of(fighter: Fighter) -> StringName:
	return fighter.state_machine.current_state.name if fighter.state_machine.current_state else &""


## True while at least one hurtbox can still be found by the solver.
func _is_vulnerable(fighter: Fighter) -> bool:
	for hurtbox in fighter.hitbox_manager.get_hurtboxes():
		if hurtbox.is_active():
			return true
	return false


func check(condition: bool, message: String) -> void:
	if not condition:
		ok = false
		print("  FAIL: %s" % message)


## Runs every frame during phase 1 and records the lifecycle as it happens.
func _observe() -> void:
	var state := _state_of(p2)
	if state == &"Knockdown" and not p2.is_on_floor():
		_saw_airborne_knockdown = true
		if _is_vulnerable(p2):
			_airborne_knockdown_vulnerable = true
	if state == &"Knockdown" and p2.is_on_floor() and _landed_frame < 0:
		_landed_frame = frames
	if state == &"Wakeup" and _wakeup_frame < 0:
		_wakeup_frame = frames
	if _wakeup_frame > 0 and state == &"Idle" and _idle_frame < 0:
		_idle_frame = frames
	# From the frame *after* landing: on the landing frame itself this observer
	# may run before the fighter's own update, so it would read the body as
	# still on. What the solver sees is covered by phase 2, which is the check
	# that actually matters.
	if _landed_frame > 0 and frames > _landed_frame and _idle_frame < 0 and _is_vulnerable(p2):
		_vulnerable_while_down = true


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
			print("== 1. hitstun ending in the air drops the fighter ==")
			# Park p2 airborne and hit it there: this used to hand back control.
			p2.position = Vector2(60, -160)
			p2.velocity = Vector2.ZERO
			p1.gravity_enabled = false
			p1.position = Vector2(0, -160)
			p1.hitbox_manager.start_attack(_make_attack(Vector2(40, -120), 10, false))
			_observing = true
		20:
			print("  state %s   on floor %s   vulnerable %s" % [
				_state_of(p2), p2.is_on_floor(), _is_vulnerable(p2),
			])
			check(_state_of(p2) == &"Knockdown", "went down instead of back to Jump")
			check(not p2.is_on_floor(), "still falling")
			check(p2.is_in_stun(), "a downed fighter counts as stunned")
			check(not p2.can_act(), "and cannot act")
		100:
			_observing = false
			print("  airborne knockdown seen: %s   vulnerable while falling: %s" % [
				_saw_airborne_knockdown, _airborne_knockdown_vulnerable,
			])
			print("  landed f%d -> wakeup f%d -> idle f%d  (down %d, wakeup %d)" % [
				_landed_frame, _wakeup_frame, _idle_frame,
				_wakeup_frame - _landed_frame, _idle_frame - _wakeup_frame,
			])
			check(_saw_airborne_knockdown, "the fall happens in Knockdown")
			check(
				_airborne_knockdown_vulnerable,
				"the fall stays vulnerable, that is the juggle window"
			)
			check(_landed_frame > 0, "p2 reached the floor")
			check(_wakeup_frame > _landed_frame, "lying down leads into Wakeup")
			check(_idle_frame > _wakeup_frame, "the wakeup ends in Idle")
			check(
				_wakeup_frame - _landed_frame == p2.stats.knockdown_frames,
				"lay down for knockdown_frames, got %d" % (_wakeup_frame - _landed_frame)
			)
			check(
				_idle_frame - _wakeup_frame == p2.stats.wakeup_frames,
				"rose for wakeup_frames, got %d" % (_idle_frame - _wakeup_frame)
			)
			check(
				not _vulnerable_while_down,
				"invulnerable from touching the floor until actionable"
			)
			check(_is_vulnerable(p2), "vulnerable again once actionable")
			check(p2.can_act(), "and actionable")
		104:
			print("\n== 2. a downed fighter cannot be hit ==")
			landed.clear()
			p1.gravity_enabled = true
			p1.position = Vector2(0, 0)
			p1.velocity = Vector2.ZERO
			p2.position = Vector2(60, 0)
			p2.velocity = Vector2.ZERO
			p2.state_machine.transition_to(&"Knockdown")
		108:
			# One frame on the floor is enough to turn the body off.
			check(_state_of(p2) == &"Knockdown", "p2 is down")
			check(not _is_vulnerable(p2), "the body is off")
			p1.hitbox_manager.start_attack(_make_attack(Vector2(200, 0), 16, false))
		120:
			print("  hits while down: %d   p2 state %s" % [landed.size(), _state_of(p2)])
			check(landed.is_empty(), "the attack whiffed over a downed fighter")
		160:
			print("\n== 3. a grounded hit still returns to neutral ==")
			landed.clear()
			p2.state_machine.transition_to(&"Idle")
			p1.position = Vector2(0, 0)
			p1.velocity = Vector2.ZERO
			p2.position = Vector2(60, 0)
			p2.velocity = Vector2.ZERO
			p1.hitbox_manager.start_attack(_make_attack(Vector2(150, 0), 12, false))
		186:
			print("  hits %d   knockdown flag %s   p2 state %s" % [
				landed.size(),
				landed[0].knockdown if landed.size() > 0 else false,
				_state_of(p2),
			])
			check(landed.size() == 1, "the move connected")
			if landed.size() == 1:
				check(not landed[0].knockdown, "a plain move does not knock down")
			check(_state_of(p2) == &"Idle", "a plain grounded hit ends in Idle")
		190:
			print("\n== 4. causes_knockdown puts a grounded fighter down ==")
			landed.clear()
			p1.position = Vector2(0, 0)
			p1.velocity = Vector2.ZERO
			p2.position = Vector2(60, 0)
			p2.velocity = Vector2.ZERO
			# Flat knockback: the fighter never leaves the floor, so only the
			# authored flag can put them down.
			p1.hitbox_manager.start_attack(_make_attack(Vector2(150, 0), 12, true))
		216:
			print("  hits %d   knockdown flag %s   p2 state %s   on floor %s" % [
				landed.size(),
				landed[0].knockdown if landed.size() > 0 else false,
				_state_of(p2),
				p2.is_on_floor(),
			])
			check(landed.size() == 1, "the move connected")
			if landed.size() == 1:
				check(landed[0].knockdown, "the hit carries the knockdown")
			check(p2.is_on_floor(), "p2 never left the floor")
			check(_state_of(p2) == &"Knockdown", "the sweep put p2 down")
		220:
			print("\n== 5. the special ender knocks down ==")
			var special := p2.get_attack(&"236S")
			check(special != null, "236S exists")
			if special != null:
				check(special.causes_knockdown, "236S is authored as a knockdown")
			print("\nRESULT: %s" % ("OK" if ok else "FAILED"))
			quit(0 if ok else 1)
			return true
	return false
