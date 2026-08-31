extends SceneTree

## Checks the stage walls: the ring of sections, the corner, wall damage, the
## regen and the break that moves the fight one screen over.
##
##   godot --headless --path . --script tests/wall_smoke_test.gd
##
## The stage is a ring, so the interesting case is not the first break but the
## one that runs off the end of the section list and comes back at the start.
## Phase 7 is that case, and it is the reason the section index is a `wrapi` and
## not a `clamp`.

const FIGHTER_SCENE := "res://content/fighters/training_dummy/fighter.tscn"
const STAGE_DATA := "res://content/stages/empty_stage/stage_data.tres"

var battle: BattleManager
var bounds: StageBounds
var data: StageData
var p1: Fighter
var p2: Fighter
var frames: int = 0
var ok: bool = true

var _wall_before: int = 0
var _breaks: Array = []


func _initialize() -> void:
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Wide enough to reach under every section of the ring.
	rect.size = Vector2(20000, 80)
	floor_shape.shape = rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 240)
	root.add_child(floor_body)

	data = load(STAGE_DATA)
	bounds = StageBounds.new()
	bounds.name = &"Bounds"
	bounds.data = data
	root.add_child(bounds)

	var scene: PackedScene = load(FIGHTER_SCENE)
	battle = BattleManager.new()
	battle.fighter_scenes = [scene, scene]
	# Set before entering the tree: the battle reads the section to place its
	# spawns, and that happens in `_ready`.
	battle.stage_bounds = bounds
	root.add_child(battle)
	battle.wall_broken.connect(
		func(side: int, from: int, to: int) -> void: _breaks.append([side, from, to])
	)


## Whether the two of them are standing the way a round starts them: the round's
## distance apart, with the middle of the pair on the middle of the section.
func centred_and_apart() -> bool:
	var gap := absf(p2.global_position.x - p1.global_position.x)
	var middle := (p1.global_position.x + p2.global_position.x) * 0.5
	print("  gap %.1f (round %.1f)   middle %.1f (section %.1f)" % [
		gap, battle.get_spawn_separation(), middle, bounds.get_center(),
	])
	return absf(gap - battle.get_spawn_separation()) < 1.0 \
		and absf(middle - bounds.get_center()) < 1.0


func check(condition: bool, message: String) -> void:
	if not condition:
		ok = false
		print("  FAIL: %s" % message)


func half_width(fighter: Fighter) -> float:
	return fighter.stats.pushbox_width * 0.5


## Puts `fighter` with their back flat against the wall on `side`.
func park_at_wall(fighter: Fighter, side: int) -> void:
	var half := half_width(fighter)
	fighter.global_position.x = (
		bounds.get_left() + half if side == StageBounds.Side.LEFT else bounds.get_right() - half
	)
	fighter.velocity = Vector2.ZERO


func state_of(fighter: Fighter) -> StringName:
	return fighter.state_machine.current_state.name


func _physics_process(_delta: float) -> bool:
	frames += 1
	match frames:
		1:
			p1 = battle.get_fighter(0)
			p2 = battle.get_fighter(1)
			p1.input.enabled = false
			p2.input.enabled = false

			print("== 1. the stage is a ring of sections ==")
			print("  %d sections of %.0f, starting at %d   left %.0f right %.0f" % [
				data.section_count, data.section_width, bounds.current_section,
				bounds.get_left(), bounds.get_right(),
			])
			check(data.section_count == 3, "three sections")
			check(bounds.current_section == 1, "starts in the middle one")
			check(data.get_section_label(bounds.current_section) == 2, "labelled 2")
			check(is_equal_approx(bounds.get_center(), 0.0), "the middle section is centred on 0")
			check(is_equal_approx(bounds.get_right() - bounds.get_left(), data.section_width),
				"the walls are one section apart")
			# The ring: off either end and back around.
			check(data.get_neighbour(2, 1) == 0, "right off the last section wraps to the first")
			check(data.get_neighbour(0, -1) == 2, "left off the first wraps to the last")
			check(data.get_neighbour(1, 1) == 2, "and the middle still just goes right")
		2:
			print("\n== 1b. the section count is a number, not a shape ==")
			for count in [2, 4, 5, 11]:
				var other := StageData.new()
				other.section_count = count
				var start := other.get_start_section()
				print("  %2d sections: start %d, wrap right %d, wrap left %d, %.0f wide" % [
					count, start,
					other.get_neighbour(count - 1, 1), other.get_neighbour(0, -1),
					other.get_total_width(),
				])
				check(other.get_neighbour(count - 1, 1) == 0,
					"%d sections still wrap right" % count)
				check(other.get_neighbour(0, -1) == count - 1,
					"%d sections still wrap left" % count)
				check(start >= 0 and start < count, "%d sections start inside" % count)
				check(is_equal_approx(other.get_total_width(), other.section_width * count),
					"%d sections cover their own width" % count)
				# An odd count has a real middle, so it lands on the origin. An
				# even one has none and picks a side, which is only a
				# convention: on a ring every section has the same two walls.
				if count % 2 == 1:
					check(is_equal_approx(other.get_section_center(start), 0.0),
						"%d sections start centred on the origin" % count)
		3:
			print("\n== 2. nobody leaves the stage ==")
			# Straight past the wall, the way a knockback would carry someone.
			p1.global_position.x = bounds.get_left() - 300.0
			p2.global_position.x = bounds.get_right() + 300.0
		5:
			print("  p1 x %.1f (wall %.1f)   p2 x %.1f (wall %.1f)" % [
				p1.global_position.x, bounds.get_left(),
				p2.global_position.x, bounds.get_right(),
			])
			check(is_equal_approx(p1.global_position.x, bounds.get_left() + half_width(p1)),
				"p1 pulled back to the left wall")
			check(is_equal_approx(p2.global_position.x, bounds.get_right() - half_width(p2)),
				"p2 pulled back to the right wall")
		10:
			print("\n== 3. a cornered fighter pushes the opponent out ==")
			park_at_wall(p1, StageBounds.Side.LEFT)
			# Overlapped, so the solver has a real separation to hand out.
			p2.global_position.x = p1.global_position.x + 10.0
			p2.velocity = Vector2.ZERO
			_wall_before = 0
		30:
			var gap := p2.global_position.x - p1.global_position.x
			print("  p1 x %.1f   p2 x %.1f   gap %.1f" % [
				p1.global_position.x, p2.global_position.x, gap,
			])
			check(is_equal_approx(p1.global_position.x, bounds.get_left() + half_width(p1)),
				"the cornered fighter gave no ground")
			check(gap >= p1.stats.pushbox_width - 0.5,
				"the opponent took the whole separation, gap %.1f" % gap)
		40:
			print("\n== 4. a clean hit on a cornered opponent wears the wall down ==")
			bounds.refill()
			park_at_wall(p2, StageBounds.Side.RIGHT)
			p1.global_position.x = p2.global_position.x - p1.stats.pushbox_width
			battle.pair_fighters()
			_wall_before = bounds.get_wall_health(StageBounds.Side.RIGHT)
		42:
			p1.perform_attack(p1.get_attack(&"5P"), true)
		50:
			var right := bounds.get_wall_health(StageBounds.Side.RIGHT)
			var left := bounds.get_wall_health(StageBounds.Side.LEFT)
			print("  wall right %d -> %d   wall left %d   p2 health %d" % [
				_wall_before, right, left, p2.health,
			])
			check(right < _wall_before, "the right wall took the hit")
			check(right == _wall_before - (10000 - p2.health),
				"the wall took exactly the damage the hit dealt")
			check(left == data.wall_health, "the wall behind the attacker took nothing")
		58:
			print("\n== 5. blocking the same hit leaves the wall alone ==")
			bounds.refill()
			p2.health = 10000
			# Out of the hitstun phase 4 left behind: a fighter still being hit
			# is not guarding, and that would read as the block failing.
			p2.state_machine.transition_to(&"Idle")
			p2.input.enabled = true
			# p2 faces left, so holding back is holding screen right — into the
			# wall it is already against, which guards without giving ground.
			Input.action_press(&"p2_right")
			park_at_wall(p2, StageBounds.Side.RIGHT)
			p1.global_position.x = p2.global_position.x - p1.stats.pushbox_width
			battle.pair_fighters()
		63:
			# Checked a few frames after the press: the buffer samples once per
			# frame, so the direction is not readable on the frame it goes down.
			check(p2.is_blocking(), "p2 is holding back")
			p1.perform_attack(p1.get_attack(&"5P"), true)
		72:
			print("  wall right %d   p2 health %d   p2 state %s" % [
				bounds.get_wall_health(StageBounds.Side.RIGHT), p2.health, state_of(p2),
			])
			check(p2.health < 10000, "the chip went through")
			check(bounds.get_wall_health(StageBounds.Side.RIGHT) == data.wall_health,
				"a blocked hit costs the wall nothing")
			Input.action_release(&"p2_right")
			p2.input.enabled = false
		80:
			print("\n== 6. the wall comes back once the pressure stops ==")
			bounds.damage_wall(StageBounds.Side.RIGHT, 1000)
			check(bounds.get_wall_health(StageBounds.Side.RIGHT) == data.wall_health - 1000,
				"the wall is down 1000")
		80 + 30:
			# Still inside the delay, so nothing has come back yet.
			print("  %d frames later: %d" % [30, bounds.get_wall_health(StageBounds.Side.RIGHT)])
			check(bounds.get_wall_health(StageBounds.Side.RIGHT) == data.wall_health - 1000,
				"nothing regenerates inside the delay")
		80 + 45:
			print("  past the delay: %d" % bounds.get_wall_health(StageBounds.Side.RIGHT))
			check(bounds.get_wall_health(StageBounds.Side.RIGHT) > data.wall_health - 1000,
				"the wall started coming back")
		80 + 90:
			print("  a second later: %d" % bounds.get_wall_health(StageBounds.Side.RIGHT))
			check(bounds.get_wall_health(StageBounds.Side.RIGHT) == data.wall_health,
				"back to full")
		200:
			print("\n== 7. breaking through moves the fight one section over ==")
			p2.health = 10000
			park_at_wall(p2, StageBounds.Side.RIGHT)
			p1.global_position.x = p2.global_position.x - p1.stats.pushbox_width
			battle.pair_fighters()
			# Softened to the last hit, so a real 5P is what finishes it.
			bounds.damage_wall(StageBounds.Side.RIGHT, data.wall_health - 100)
			_breaks.clear()
		202:
			p1.perform_attack(p1.get_attack(&"5P"), true)
		210:
			print("  section %d   breaks %s" % [bounds.current_section, _breaks])
			print("  p1 x %.1f   p2 x %.1f   section %.0f..%.0f" % [
				p1.global_position.x, p2.global_position.x,
				bounds.get_left(), bounds.get_right(),
			])
			print("  p2 health %d   p2 state %s   p1 state %s" % [
				p2.health, state_of(p2), state_of(p1),
			])
			check(bounds.current_section == 2, "moved into section 3, got %d" % (
				bounds.current_section + 1))
			check(_breaks.size() == 1, "the break was reported once")
			check(p2.global_position.x > p1.global_position.x, "the victim came out ahead")
			# The point of the break is the room it opens, so it cannot hand the
			# attacker a corner of their own: both of them land where a round
			# starts, centred in the section they arrived in.
			check(centred_and_apart(), "the pair came out at a neutral distance")
			# 5P deals 300 and the wall had 100 left, so the rest is the break.
			check(p2.health == 10000 - 300 - data.wall_break_damage,
				"the break dealt its own damage, health %d" % p2.health)
			check(state_of(p2) == &"Knockdown", "the victim went down, state %s" % state_of(p2))
			check(bounds.get_wall_health(StageBounds.Side.RIGHT) == data.wall_health,
				"the new section's walls are whole")
		240:
			print("\n== 8. the last section's wall leads back to the first ==")
			p2.health = 10000
			p2.state_machine.transition_to(&"Idle")
			park_at_wall(p2, StageBounds.Side.RIGHT)
			p1.global_position.x = p2.global_position.x - p1.stats.pushbox_width
			battle.pair_fighters()
			bounds.damage_wall(StageBounds.Side.RIGHT, data.wall_health - 100)
			_breaks.clear()
		242:
			p1.perform_attack(p1.get_attack(&"5P"), true)
		250:
			print("  section %d   breaks %s" % [bounds.current_section, _breaks])
			print("  p1 x %.1f   p2 x %.1f   section %.0f..%.0f" % [
				p1.global_position.x, p2.global_position.x,
				bounds.get_left(), bounds.get_right(),
			])
			check(bounds.current_section == 0, "wrapped round to section 1, got %d" % (
				bounds.current_section + 1))
			check(p1.global_position.x >= bounds.get_left(), "the attacker is inside the section")
			check(p2.global_position.x <= bounds.get_right(), "and so is the victim")
			check(centred_and_apart(), "and the wrap is as neutral as any other break")
		255:
			print("\n== 9. a new round puts the stage back ==")
			battle.reset_round()
		257:
			print("  section %d   p1 x %.0f   p2 x %.0f   walls %d/%d" % [
				bounds.current_section, p1.global_position.x, p2.global_position.x,
				bounds.get_wall_health(StageBounds.Side.LEFT),
				bounds.get_wall_health(StageBounds.Side.RIGHT),
			])
			check(bounds.current_section == 1, "back to the starting section")
			check(is_equal_approx(p1.global_position.x, -BattleManager.DEFAULT_SPAWN_OFFSET),
				"p1 back on its spawn column")
			check(is_equal_approx(p2.global_position.x, BattleManager.DEFAULT_SPAWN_OFFSET),
				"p2 back on its spawn column")
			check(bounds.get_wall_health(StageBounds.Side.LEFT) == data.wall_health
				and bounds.get_wall_health(StageBounds.Side.RIGHT) == data.wall_health,
				"both walls whole again")
		260:
			print("\nRESULT: %s" % ("OK" if ok else "FAILED"))
			quit(0 if ok else 1)
			return true
	return false
