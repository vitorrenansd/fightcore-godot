extends SceneTree

## Checks juggle gravity: a launcher opens the juggle, every airborne hit adds
## to it, the victim falls faster the longer the combo runs, and landing wipes
## it. This is what stops an air route from repeating forever.
##
##   godot --headless --path . --script tests/juggle_smoke_test.gd

const FIGHTER_SCENE := "res://content/fighters/training_dummy/fighter.tscn"
## High enough that nothing in the test accidentally touches the floor.
const AIR_HEIGHT: float = -320.0

var p1: Fighter
var p2: Fighter
var solver: CollisionSolver
var frames: int = 0
var landed: Array[HitData] = []
var ok: bool = true

var _fall_low: float = 0.0
var _fall_high: float = 0.0
var _velocity_sample: float = 0.0


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


## Minimal move that reaches the opponent on frame 4. `launcher` and
## `juggle_cost` are what this test is actually about.
func _make_attack(launcher: bool, juggle_cost: int, knockback: Vector2) -> AttackData:
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
	attack.damage = 300
	attack.chip_damage = 30
	attack.hitstun = 24
	attack.blockstun = 12
	attack.hitstop = 4
	attack.knockback = knockback
	attack.launcher = launcher
	attack.juggle_cost = juggle_cost
	attack.hitboxes = [box]
	return attack


## Parks both fighters side by side in the air with gravity off, so an airborne
## exchange can be scripted without fighting the arc.
func _park_in_air() -> void:
	for fighter in [p1, p2]:
		fighter.gravity_enabled = false
		fighter.velocity = Vector2.ZERO
	p1.position = Vector2(0, AIR_HEIGHT)
	p2.position = Vector2(60, AIR_HEIGHT)


func check(condition: bool, message: String) -> void:
	if not condition:
		ok = false
		print("  FAIL: %s" % message)


func _physics_process(_delta: float) -> bool:
	frames += 1
	match frames:
		1:
			p1.opponent = p2
			p2.opponent = p1
			p1.set_facing(true)
			p2.set_facing(false)
			p1.input.enabled = false
			p2.input.enabled = false
			p2.input.player_index = 1
			print("== 1. a grounded hit builds no juggle ==")
			check(p2.juggle_count == 0, "starts clean")
			p1.hitbox_manager.start_attack(_make_attack(false, 1, Vector2(200, 0)))
		14:
			print("  hits %d   juggle %d   multiplier %.2f" % [
				landed.size(), p2.juggle_count, p2.get_juggle_gravity_multiplier(),
			])
			check(landed.size() == 1, "the move connected")
			check(p2.juggle_count == 0, "a grounded hit adds no juggle")
			check(is_equal_approx(p2.get_juggle_gravity_multiplier(), 1.0), "gravity untouched")
		40:
			print("\n== 2. a launcher opens the juggle ==")
			landed.clear()
			p1.position = Vector2(0, 0)
			p1.velocity = Vector2.ZERO
			p2.position = Vector2(60, 0)
			p2.velocity = Vector2.ZERO
			p1.hitbox_manager.start_attack(_make_attack(true, 1, Vector2(120, -600)))
		52:
			print("  hits %d   juggle %d   on floor %s" % [
				landed.size(), p2.juggle_count, p2.is_on_floor(),
			])
			check(landed.size() == 1, "the launcher connected")
			check(landed[0].launcher, "the hit reads as a launcher")
			check(landed[0].juggle_cost == 1, "the hit carries its juggle cost")
			check(p2.juggle_count == 1, "juggle opened at 1, got %d" % p2.juggle_count)
			check(not p2.is_on_floor(), "p2 left the ground")
		56:
			print("\n== 3. every airborne hit adds more ==")
			landed.clear()
			_park_in_air()
			p1.hitbox_manager.start_attack(_make_attack(false, 2, Vector2(80, -120)))
		68:
			print("  hits %d   juggle %d   multiplier %.2f" % [
				landed.size(), p2.juggle_count, p2.get_juggle_gravity_multiplier(),
			])
			check(landed.size() == 1, "the air hit connected")
			check(p2.juggle_count == 3, "juggle 1 + cost 2 = 3, got %d" % p2.juggle_count)
			check(
				p2.get_juggle_gravity_multiplier() > 1.0,
				"the multiplier grew, got %.2f" % p2.get_juggle_gravity_multiplier()
			)
		74:
			print("\n== 4. more juggle means a faster fall ==")
			# Out of hitstun and hitstop, in free fall with a clean counter.
			p2.state_machine.transition_to(&"Jump")
			p2.hitstop_frames = 0
			p2.juggle_count = 0
			p2.gravity_enabled = true
			p2.position = Vector2(60, AIR_HEIGHT)
			p2.velocity = Vector2.ZERO
		76:
			check(p2.hitstop_frames == 0, "not frozen while measuring")
			_velocity_sample = p2.velocity.y
		78:
			_fall_low = p2.velocity.y - _velocity_sample
			p2.juggle_count = 8
			p2.position = Vector2(60, AIR_HEIGHT)
			p2.velocity = Vector2.ZERO
		80:
			_velocity_sample = p2.velocity.y
		82:
			_fall_high = p2.velocity.y - _velocity_sample
			var expected := p2.get_juggle_gravity_multiplier()
			print("  juggle 0: %.1f/frame   juggle 8: %.1f/frame   multiplier %.2f" % [
				_fall_low, _fall_high, expected,
			])
			check(_fall_low > 0.0, "falling at all with no juggle")
			check(_fall_high > _fall_low, "a juggled fighter falls faster")
			check(
				is_equal_approx(_fall_high / _fall_low, expected),
				"the speed-up matches the multiplier, got %.2f" % (_fall_high / _fall_low)
			)
		84:
			print("\n== 5. the cap holds ==")
			p2.juggle_count = 999
			print("  juggle 999 -> multiplier %.2f (cap %.2f)" % [
				p2.get_juggle_gravity_multiplier(), p2.stats.max_juggle_gravity,
			])
			check(
				is_equal_approx(p2.get_juggle_gravity_multiplier(), p2.stats.max_juggle_gravity),
				"a long combo cannot push gravity past the cap"
			)
			print("\n== 6. landing wipes the juggle ==")
			p2.juggle_count = 5
			p2.position = Vector2(60, -40)
			p2.velocity = Vector2.ZERO
		95:
			print("  on floor %s   juggle %d   air jumps %d" % [
				p2.is_on_floor(), p2.juggle_count, p2.air_jumps_left,
			])
			check(p2.is_on_floor(), "p2 landed")
			check(p2.juggle_count == 0, "landing cleared the juggle, got %d" % p2.juggle_count)
			check(p2.air_jumps_left == p2.stats.air_jumps, "air options came back with it")
		100:
			print("\n== 7. a blocked hit feeds nothing ==")
			landed.clear()
			p1.gravity_enabled = true
			p1.position = Vector2(0, 0)
			p1.velocity = Vector2.ZERO
			p2.position = Vector2(60, 0)
			p2.velocity = Vector2.ZERO
			p2.input.enabled = true
			# p2 faces left, so its back is screen right.
			Input.action_press(&"p2_right")
			p1.hitbox_manager.start_attack(_make_attack(true, 3, Vector2(120, -600)))
		112:
			print("  hits %d   blocked %s   juggle %d" % [
				landed.size(),
				landed[0].blocked if landed.size() > 0 else false,
				p2.juggle_count,
			])
			check(landed.size() == 1, "the move connected")
			if landed.size() == 1:
				check(landed[0].blocked, "p2 blocked it")
				check(landed[0].juggle_cost == 0, "a blocked hit carries no juggle cost")
				check(not landed[0].launcher, "a blocked launcher does not launch")
			check(p2.juggle_count == 0, "blocking built no juggle, got %d" % p2.juggle_count)
			Input.action_release(&"p2_right")
		114:
			print("\nRESULT: %s" % ("OK" if ok else "FAILED"))
			quit(0 if ok else 1)
			return true
	return false
