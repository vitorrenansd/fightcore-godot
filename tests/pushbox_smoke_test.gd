extends SceneTree

## Checks that fighters cannot stand on each other, can still jump across, and
## get separated horizontally once both are on the ground.
##
##   godot --headless --path . --script tests/pushbox_smoke_test.gd

const FIGHTER_SCENE := "res://content/fighters/training_dummy/fighter.tscn"
const FLOOR_TOP: float = 50.0

var battle: BattleManager
var p1: Fighter
var p2: Fighter
var frames: int = 0
var ok: bool = true

var min_gap_while_grounded: float = 9999.0


func _initialize() -> void:
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	floor_shape.shape = rect
	floor_body.position = Vector2(0, FLOOR_TOP + 20.0)
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)

	var scene: PackedScene = load(FIGHTER_SCENE)
	battle = BattleManager.new()
	battle.fighter_scenes = [scene, scene]
	battle.spawn_positions = [Vector2(-120, 0), Vector2(120, 0)]
	root.add_child(battle)


func check(condition: bool, message: String) -> void:
	if not condition:
		ok = false
		print("  FAIL: %s" % message)


func gap() -> float:
	return absf(p2.global_position.x - p1.global_position.x)


func height_difference() -> float:
	return absf(p2.global_position.y - p1.global_position.y)


func _physics_process(_delta: float) -> bool:
	frames += 1
	if p1 != null and p1.is_on_floor() and p2.is_on_floor():
		min_gap_while_grounded = minf(min_gap_while_grounded, gap())

	match frames:
		1:
			p1 = battle.get_fighter(0)
			p2 = battle.get_fighter(1)
			p1.input.enabled = false
			p2.input.enabled = false
		20:
			print("== 1. fighters are not physics obstacles to each other ==")
			print("  p1 layer=%d mask=%d" % [p1.collision_layer, p1.collision_mask])
			check(p1.collision_layer & CollisionLayers.WORLD == 0, "not on the world layer")
			check(p1.collision_mask & CollisionLayers.PUSHBOX == 0, "does not mask other fighters")
			check(p1.is_on_floor() and p2.is_on_floor(), "both standing on the stage")

			print("\n== 2. dropped right on top of the opponent ==")
			# The exact bug: land on the opponent's head and stay there forever.
			p2.global_position = Vector2(0, 0)
			p1.global_position = Vector2(0, -140)
			p1.velocity = Vector2.ZERO
		25:
			print("  falling: p1 y=%.0f  p2 y=%.0f  height difference=%.0f" % [
				p1.global_position.y, p2.global_position.y, height_difference(),
			])
			check(p1.global_position.y > -140.0, "the fighter above keeps falling")
		60:
			print("  landed: p1 y=%.0f  p2 y=%.0f  gap=%.1f" % [
				p1.global_position.y, p2.global_position.y, gap(),
			])
			check(p1.is_on_floor() and p2.is_on_floor(), "both reached the floor")
			check(height_difference() < 5.0, "neither ended up standing on the other")
			check(
				gap() >= p1.stats.pushbox_width - 1.0,
				"pushed apart to at least one pushbox, gap %.1f" % gap()
			)
		62:
			print("\n== 3. a jump crosses over instead of being blocked ==")
			p1.global_position = Vector2(-90, 0)
			p2.global_position = Vector2(0, 0)
			p1.velocity = Vector2.ZERO
			p2.velocity = Vector2.ZERO
		66:
			# Only measure the overlap from here on: phase 2 legitimately starts
			# overlapped and separates over a few frames.
			min_gap_while_grounded = 9999.0
			# Jump forward hard enough to land past the opponent.
			p1.state_machine.transition_to(&"Jump")
			p1.velocity.x = 260.0
		125:
			print("  after the jump: p1 x=%.0f  p2 x=%.0f" % [
				p1.global_position.x, p2.global_position.x,
			])
			check(p1.is_on_floor(), "landed")
			check(p1.global_position.x > p2.global_position.x, "crossed to the other side")
			check(
				min_gap_while_grounded >= p1.stats.pushbox_width - 1.0,
				"never overlapped while both were grounded, min gap %.1f" % min_gap_while_grounded
			)
		126:
			print("\nRESULT: %s" % ("OK" if ok else "FAILED"))
			quit(0 if ok else 1)
			return true
	return false
