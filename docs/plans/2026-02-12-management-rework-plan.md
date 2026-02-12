# Management Rework Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rework the management/hiring system from an overlay panel into a separate top-down office scene with consultant lifecycle, tiered contracts, rentals, and training.

**Architecture:** The management office is a new scene (`ManagementOffice`) toggled from the personal office via a door. ConsultantData gets a `location` enum to track where each consultant is. New `ConsultantRental` resource tracks long-duration placements. ConsultantManager gains training/rental logic. The existing HiringPanel and team-assignment flow in main.gd get removed, replaced by the management scene's own UI.

**Tech Stack:** Godot 4.6, GDScript, GUT v9.5.0

**Design doc:** `docs/plans/2026-02-12-management-rework-design.md`

---

### Task 1: Extend ConsultantData with Location and Training State

**Files:**
- Modify: `src/data/consultant_data.gd`
- Test: `test/unit/test_consultant_state.gd`

**Step 1: Write the failing tests**

Create `test/unit/test_consultant_state.gd`:

```gdscript
extends GutTest

var consultant: ConsultantData

func before_each():
	consultant = ConsultantData.new()
	consultant.id = "test1"
	consultant.name = "Test Dev"
	consultant.skills = {"javascript": 2}
	consultant.salary = 500.0
	consultant.trait_id = "fast"
	consultant.morale = 1.0

func test_default_location_is_in_office():
	assert_eq(consultant.location, ConsultantData.Location.IN_OFFICE)

func test_set_location():
	consultant.location = ConsultantData.Location.REMOTE
	assert_eq(consultant.location, ConsultantData.Location.REMOTE)

func test_default_training_skill_is_empty():
	assert_eq(consultant.training_skill, "")

func test_set_training_skill():
	consultant.training_skill = "python"
	assert_eq(consultant.training_skill, "python")

func test_is_available_when_in_office_idle():
	consultant.location = ConsultantData.Location.IN_OFFICE
	consultant.training_skill = ""
	assert_true(consultant.is_available())

func test_is_available_when_remote_idle():
	consultant.location = ConsultantData.Location.REMOTE
	assert_true(consultant.is_available())

func test_not_available_when_on_project():
	consultant.location = ConsultantData.Location.ON_PROJECT
	assert_false(consultant.is_available())

func test_not_available_when_on_rental():
	consultant.location = ConsultantData.Location.ON_RENTAL
	assert_false(consultant.is_available())

func test_is_trainable_in_office():
	consultant.location = ConsultantData.Location.IN_OFFICE
	assert_true(consultant.is_trainable())

func test_is_trainable_remote():
	consultant.location = ConsultantData.Location.REMOTE
	assert_true(consultant.is_trainable())

func test_not_trainable_on_project():
	consultant.location = ConsultantData.Location.ON_PROJECT
	assert_false(consultant.is_trainable())
```

**Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_consultant_state.gd`
Expected: FAIL — `Location` enum doesn't exist yet

**Step 3: Implement the changes to ConsultantData**

Add to `src/data/consultant_data.gd` (after `class_name ConsultantData`, before vars):

```gdscript
enum Location { IN_OFFICE, REMOTE, ON_PROJECT, ON_RENTAL }
```

Add new vars (after existing `morale` var):

```gdscript
var location: Location = Location.IN_OFFICE
var training_skill: String = ""  # empty = not training
```

Add new methods (after existing methods):

```gdscript
func is_available() -> bool:
	return location == Location.IN_OFFICE or location == Location.REMOTE

func is_trainable() -> bool:
	return location == Location.IN_OFFICE or location == Location.REMOTE
```

**Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_consultant_state.gd`
Expected: All 11 tests PASS

**Step 5: Run all tests to check no regressions**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All 113 tests PASS (102 existing + 11 new)

**Step 6: Commit**

```bash
git add src/data/consultant_data.gd test/unit/test_consultant_state.gd
git commit -m "feat: add location and training state to ConsultantData"
```

---

### Task 2: Create ConsultantRental Data Model

**Files:**
- Create: `src/data/consultant_rental.gd`
- Test: `test/unit/test_consultant_rental.gd`

**Step 1: Write the failing tests**

Create `test/unit/test_consultant_rental.gd`:

```gdscript
extends GutTest

func _make_consultant() -> ConsultantData:
	var c = ConsultantData.new()
	c.id = "test1"
	c.name = "Test Dev"
	c.skills = {"javascript": 3}
	c.salary = 500.0
	c.trait_id = "fast"
	c.morale = 1.0
	return c

func test_create_rental():
	var c = _make_consultant()
	var rental = ConsultantRental.new()
	rental.consultant = c
	rental.client_name = "BigCorp"
	rental.rate_per_tick = 2.0
	rental.duration_remaining = 600.0
	assert_eq(rental.client_name, "BigCorp")
	assert_eq(rental.rate_per_tick, 2.0)

func test_rental_not_complete_initially():
	var rental = ConsultantRental.new()
	rental.duration_remaining = 100.0
	assert_false(rental.is_complete())

func test_rental_completes_at_zero():
	var rental = ConsultantRental.new()
	rental.duration_remaining = 0.0
	assert_true(rental.is_complete())

func test_tick_reduces_duration():
	var rental = ConsultantRental.new()
	rental.duration_remaining = 100.0
	rental.tick(10.0)
	assert_almost_eq(rental.duration_remaining, 90.0, 0.01)

func test_tick_does_not_go_negative():
	var rental = ConsultantRental.new()
	rental.duration_remaining = 5.0
	rental.tick(10.0)
	assert_almost_eq(rental.duration_remaining, 0.0, 0.01)

func test_extension_pending_near_end():
	var rental = ConsultantRental.new()
	rental.duration_remaining = 50.0
	rental.total_duration = 600.0
	assert_false(rental.is_extension_window())
	rental.duration_remaining = 55.0  # within 10% of total
	assert_true(rental.is_extension_window())

func test_extension_not_pending_if_already_extended():
	var rental = ConsultantRental.new()
	rental.duration_remaining = 55.0
	rental.total_duration = 600.0
	rental.extension_offered = true
	assert_false(rental.is_extension_window())

func test_get_earnings_per_tick():
	var rental = ConsultantRental.new()
	rental.rate_per_tick = 3.5
	assert_eq(rental.get_earnings_per_tick(), 3.5)
```

**Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_consultant_rental.gd`
Expected: FAIL — `ConsultantRental` class doesn't exist

**Step 3: Implement ConsultantRental**

Create `src/data/consultant_rental.gd`:

```gdscript
extends Resource
class_name ConsultantRental

var consultant: ConsultantData
var client_name: String = ""
var rate_per_tick: float = 1.0  # income per second
var total_duration: float = 600.0  # total rental length in seconds
var duration_remaining: float = 600.0
var extension_offered: bool = false

func is_complete() -> bool:
	return duration_remaining <= 0.0

func tick(delta: float) -> void:
	duration_remaining = maxf(duration_remaining - delta, 0.0)

func is_extension_window() -> bool:
	if extension_offered:
		return false
	return duration_remaining <= total_duration * 0.1 and duration_remaining > 0.0

func get_earnings_per_tick() -> float:
	return rate_per_tick
```

**Step 4: Register class_name**

Run: `godot --headless --import`

**Step 5: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_consultant_rental.gd`
Expected: All 8 tests PASS

**Step 6: Run all tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add src/data/consultant_rental.gd test/unit/test_consultant_rental.gd
git commit -m "feat: add ConsultantRental data model"
```

---

### Task 3: Extend GameState for Management

**Files:**
- Modify: `src/autoload/game_state.gd`
- Modify: `src/autoload/event_bus.gd`
- Test: `test/unit/test_management_state.gd`

**Step 1: Write the failing tests**

Create `test/unit/test_management_state.gd`:

```gdscript
extends GutTest

var state: Node

func before_each():
	state = load("res://src/autoload/game_state.gd").new()
	add_child_autofree(state)

func test_default_desk_capacity():
	assert_eq(state.desk_capacity, 4)

func test_active_rentals_starts_empty():
	assert_eq(state.active_rentals.size(), 0)

func test_add_rental():
	var rental = ConsultantRental.new()
	rental.client_name = "TestCo"
	state.add_rental(rental)
	assert_eq(state.active_rentals.size(), 1)

func test_remove_rental():
	var rental = ConsultantRental.new()
	state.add_rental(rental)
	state.remove_rental(rental)
	assert_eq(state.active_rentals.size(), 0)

func test_max_staff_is_3x_desk_capacity():
	assert_eq(state.get_max_staff(), 12)  # 4 * 3

func test_max_staff_scales_with_capacity():
	state.desk_capacity = 6
	assert_eq(state.get_max_staff(), 18)

func test_can_hire_under_max():
	state.desk_capacity = 4
	assert_true(state.can_hire())

func test_cannot_hire_at_max():
	state.desk_capacity = 1  # max 3
	for i in range(3):
		var c = ConsultantData.new()
		c.id = str(i)
		state.consultants.append(c)
	assert_false(state.can_hire())

func test_get_in_office_consultants():
	var c1 = ConsultantData.new()
	c1.id = "1"
	c1.location = ConsultantData.Location.IN_OFFICE
	var c2 = ConsultantData.new()
	c2.id = "2"
	c2.location = ConsultantData.Location.ON_RENTAL
	state.consultants = [c1, c2]
	assert_eq(state.get_consultants_by_location(ConsultantData.Location.IN_OFFICE).size(), 1)

func test_get_available_consultants():
	var c1 = ConsultantData.new()
	c1.id = "1"
	c1.location = ConsultantData.Location.IN_OFFICE
	var c2 = ConsultantData.new()
	c2.id = "2"
	c2.location = ConsultantData.Location.ON_PROJECT
	var c3 = ConsultantData.new()
	c3.id = "3"
	c3.location = ConsultantData.Location.REMOTE
	state.consultants = [c1, c2, c3]
	var available = state.get_available_consultants()
	assert_eq(available.size(), 2)  # c1 and c3
```

**Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_management_state.gd`
Expected: FAIL — `desk_capacity`, `active_rentals` etc. don't exist

**Step 3: Implement GameState extensions**

Add to `src/autoload/game_state.gd` (new vars after `claimed_easter_eggs`):

```gdscript
var desk_capacity: int = 4
var active_rentals: Array = []  # Array of ConsultantRental
```

Add new methods (after `get_total_salary`):

```gdscript
func add_rental(rental: ConsultantRental) -> void:
	active_rentals.append(rental)

func remove_rental(rental: ConsultantRental) -> void:
	active_rentals.erase(rental)

func get_max_staff() -> int:
	return desk_capacity * 3

func can_hire() -> bool:
	return consultants.size() < get_max_staff()

func get_consultants_by_location(loc: int) -> Array:
	var result: Array = []
	for c in consultants:
		if c.location == loc:
			result.append(c)
	return result

func get_available_consultants() -> Array:
	var result: Array = []
	for c in consultants:
		if c.is_available():
			result.append(c)
	return result
```

Add new signals to `src/autoload/event_bus.gd` (after existing management signals):

```gdscript
# Management scene signals
signal rental_started(rental)
signal rental_completed(rental)
signal rental_extension_available(rental)
signal consultant_training_started(consultant, skill_id)
signal consultant_location_changed(consultant, new_location)
signal scene_switch_requested(scene_name)  # "personal" or "management"
```

**Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_management_state.gd`
Expected: All 11 tests PASS

**Step 5: Run all tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add src/autoload/game_state.gd src/autoload/event_bus.gd test/unit/test_management_state.gd
git commit -m "feat: extend GameState with desk capacity, rentals, and staff queries"
```

---

### Task 4: Training Logic in ConsultantManager

**Files:**
- Modify: `src/logic/consultant_manager.gd`
- Test: `test/unit/test_training.gd`

**Step 1: Write the failing tests**

Create `test/unit/test_training.gd`:

```gdscript
extends GutTest

var manager: ConsultantManager
var state: Node

func before_each():
	manager = load("res://src/logic/consultant_manager.gd").new()
	state = load("res://src/autoload/game_state.gd").new()
	add_child_autofree(state)

func _make_consultant(location: int = ConsultantData.Location.IN_OFFICE) -> ConsultantData:
	var c = ConsultantData.new()
	c.id = "test1"
	c.name = "Test Dev"
	c.skills = {"javascript": 2}
	c.salary = 500.0
	c.trait_id = "fast"
	c.morale = 1.0
	c.location = location
	return c

func test_passive_skill_growth_in_office():
	var c = _make_consultant(ConsultantData.Location.IN_OFFICE)
	state.add_consultant(c)
	# Tick many times to accumulate passive growth
	for i in range(1000):
		manager.tick_training(1.0, state)
	# At least some skill should have grown (passive is very slow)
	var total_skill: float = 0.0
	for level in c.skills.values():
		total_skill += level
	assert_gt(total_skill, 2.0, "Should have some passive growth after 1000 seconds")

func test_passive_growth_slower_when_remote():
	var c_office = _make_consultant(ConsultantData.Location.IN_OFFICE)
	c_office.id = "office1"
	c_office.skills = {"javascript": 2}
	var c_remote = _make_consultant(ConsultantData.Location.REMOTE)
	c_remote.id = "remote1"
	c_remote.skills = {"javascript": 2}
	state.add_consultant(c_office)
	state.add_consultant(c_remote)
	for i in range(1000):
		manager.tick_training(1.0, state)
	# Office consultant should have grown more
	assert_gte(c_office.skills["javascript"], c_remote.skills["javascript"])

func test_active_training_faster_than_passive():
	var c_passive = _make_consultant()
	c_passive.id = "passive1"
	c_passive.skills = {"javascript": 2}
	var c_active = _make_consultant()
	c_active.id = "active1"
	c_active.skills = {"javascript": 2}
	c_active.training_skill = "javascript"
	state.add_consultant(c_passive)
	state.add_consultant(c_active)
	for i in range(500):
		manager.tick_training(1.0, state)
	assert_gt(c_active.skills["javascript"], c_passive.skills["javascript"],
		"Active training should be faster")

func test_training_cost_per_tick():
	state.money = 10000.0
	var c = _make_consultant()
	c.training_skill = "python"
	state.add_consultant(c)
	manager.tick_training(1.0, state)
	assert_lt(state.money, 10000.0, "Training should cost money")

func test_no_training_cost_for_idle():
	state.money = 10000.0
	var c = _make_consultant()
	c.training_skill = ""  # idle, not training
	state.add_consultant(c)
	manager.tick_training(1.0, state)
	assert_eq(state.money, 10000.0, "Idle consultant should not cost training fees")

func test_no_training_when_on_project():
	var c = _make_consultant(ConsultantData.Location.ON_PROJECT)
	c.training_skill = "javascript"
	var initial_level = c.skills["javascript"]
	state.add_consultant(c)
	for i in range(100):
		manager.tick_training(1.0, state)
	assert_eq(c.skills["javascript"], initial_level, "On-project consultant should not train")

func test_start_training():
	state.money = 10000.0
	var c = _make_consultant()
	state.add_consultant(c)
	var result = manager.start_training(c, "python")
	assert_true(result)
	assert_eq(c.training_skill, "python")

func test_stop_training():
	var c = _make_consultant()
	c.training_skill = "python"
	state.add_consultant(c)
	manager.stop_training(c)
	assert_eq(c.training_skill, "")
```

**Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_training.gd`
Expected: FAIL — `tick_training`, `start_training`, `stop_training` don't exist

**Step 3: Implement training logic in ConsultantManager**

Add constants to `src/logic/consultant_manager.gd` (after existing constants):

```gdscript
const PASSIVE_SKILL_RATE: float = 0.001  # XP per second per existing skill (very slow)
const ACTIVE_TRAINING_RATE: float = 0.01  # XP per second for active training (10x passive)
const REMOTE_PENALTY: float = 0.7  # 70% effectiveness for remote consultants
const TRAINING_COST_PER_SEC: float = 0.1  # $ per second of active training
```

Add new methods (after `pay_salaries`):

```gdscript
func tick_training(delta: float, state: Node) -> void:
	for c in state.consultants:
		if not c.is_trainable():
			continue
		var location_mult = REMOTE_PENALTY if c.location == ConsultantData.Location.REMOTE else 1.0

		# Active training
		if c.training_skill != "":
			var xp = ACTIVE_TRAINING_RATE * delta * location_mult
			_add_skill_xp(c, c.training_skill, xp)
			state.spend_money(TRAINING_COST_PER_SEC * delta)
		else:
			# Passive growth on existing skills
			for skill_id in c.skills:
				var xp = PASSIVE_SKILL_RATE * delta * location_mult
				_add_skill_xp(c, skill_id, xp)

func _add_skill_xp(c: ConsultantData, skill_id: String, xp: float) -> void:
	var current = float(c.skills.get(skill_id, 0))
	var new_val = current + xp
	# Level up at integer boundaries
	c.skills[skill_id] = new_val

func start_training(c: ConsultantData, skill_id: String) -> bool:
	if not c.is_trainable():
		return false
	c.training_skill = skill_id
	return true

func stop_training(c: ConsultantData) -> void:
	c.training_skill = ""
```

**Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_training.gd`
Expected: All 8 tests PASS

**Step 5: Run all tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add src/logic/consultant_manager.gd test/unit/test_training.gd
git commit -m "feat: add consultant training system with passive and active learning"
```

---

### Task 5: Rental System Logic

**Files:**
- Modify: `src/logic/consultant_manager.gd`
- Test: `test/unit/test_rentals.gd`

**Step 1: Write the failing tests**

Create `test/unit/test_rentals.gd`:

```gdscript
extends GutTest

var manager: ConsultantManager
var state: Node

func before_each():
	manager = load("res://src/logic/consultant_manager.gd").new()
	state = load("res://src/autoload/game_state.gd").new()
	add_child_autofree(state)

func _make_consultant() -> ConsultantData:
	var c = ConsultantData.new()
	c.id = "test1"
	c.name = "Test Dev"
	c.skills = {"javascript": 3}
	c.salary = 500.0
	c.trait_id = "fast"
	c.morale = 1.0
	c.location = ConsultantData.Location.IN_OFFICE
	return c

func test_place_on_rental():
	var c = _make_consultant()
	state.add_consultant(c)
	var rental = manager.place_on_rental(c, "BigCorp", 2.0, 600.0, state)
	assert_not_null(rental)
	assert_eq(c.location, ConsultantData.Location.ON_RENTAL)
	assert_eq(state.active_rentals.size(), 1)

func test_cannot_rental_unavailable_consultant():
	var c = _make_consultant()
	c.location = ConsultantData.Location.ON_PROJECT
	state.add_consultant(c)
	var rental = manager.place_on_rental(c, "BigCorp", 2.0, 600.0, state)
	assert_null(rental)

func test_tick_rentals_earns_income():
	state.money = 1000.0
	var c = _make_consultant()
	state.add_consultant(c)
	manager.place_on_rental(c, "BigCorp", 5.0, 600.0, state)
	manager.tick_rentals(10.0, state)
	assert_almost_eq(state.money, 1050.0, 0.01)  # 5.0 * 10 = 50

func test_tick_rentals_reduces_duration():
	var c = _make_consultant()
	state.add_consultant(c)
	manager.place_on_rental(c, "BigCorp", 2.0, 600.0, state)
	manager.tick_rentals(100.0, state)
	assert_almost_eq(state.active_rentals[0].duration_remaining, 500.0, 0.01)

func test_completed_rental_returns_consultant():
	var c = _make_consultant()
	state.add_consultant(c)
	manager.place_on_rental(c, "BigCorp", 2.0, 10.0, state)
	var completed = manager.tick_rentals(15.0, state)
	assert_eq(completed.size(), 1)
	assert_eq(c.location, ConsultantData.Location.IN_OFFICE)
	assert_eq(state.active_rentals.size(), 0)

func test_extension_window_detected():
	var c = _make_consultant()
	state.add_consultant(c)
	manager.place_on_rental(c, "BigCorp", 2.0, 100.0, state)
	var rental = state.active_rentals[0]
	# Move to extension window (within 10% of total)
	rental.duration_remaining = 9.0
	var extensions = manager.check_rental_extensions(state)
	assert_eq(extensions.size(), 1)
	assert_true(rental.extension_offered)

func test_apply_rental_extension():
	var c = _make_consultant()
	state.add_consultant(c)
	manager.place_on_rental(c, "BigCorp", 2.0, 100.0, state)
	var rental = state.active_rentals[0]
	rental.duration_remaining = 5.0
	rental.extension_offered = true
	manager.extend_rental(rental, 100.0)
	assert_almost_eq(rental.duration_remaining, 105.0, 0.01)
	assert_almost_eq(rental.total_duration, 200.0, 0.01)
	assert_false(rental.extension_offered)  # Reset for next extension

func test_generate_rental_offers():
	var offers = manager.generate_rental_offers(3, 50.0)
	assert_eq(offers.size(), 3)
	for offer in offers:
		assert_has(offer, "client_name")
		assert_has(offer, "rate_per_tick")
		assert_has(offer, "duration")
		assert_has(offer, "required_skills")
```

**Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_rentals.gd`
Expected: FAIL — rental methods don't exist

**Step 3: Implement rental logic in ConsultantManager**

Add constants (after training constants):

```gdscript
const RENTAL_CLIENT_NAMES = [
	"Acme Corp", "TechVentures", "GlobalSoft", "DataDriven", "CloudFirst",
	"NexGen", "PrimeSoft", "CoreStack", "BluePeak", "AlphaWorks",
]
```

Add methods (after training methods):

```gdscript
func place_on_rental(c: ConsultantData, client_name: String, rate: float, duration: float, state: Node) -> ConsultantRental:
	if not c.is_available():
		return null
	var rental = ConsultantRental.new()
	rental.consultant = c
	rental.client_name = client_name
	rental.rate_per_tick = rate
	rental.total_duration = duration
	rental.duration_remaining = duration
	c.location = ConsultantData.Location.ON_RENTAL
	c.training_skill = ""
	state.add_rental(rental)
	return rental

func tick_rentals(delta: float, state: Node) -> Array:
	var completed: Array = []
	for rental in state.active_rentals.duplicate():
		rental.tick(delta)
		state.add_money(rental.get_earnings_per_tick() * delta)
		if rental.is_complete():
			completed.append(rental)
			rental.consultant.location = ConsultantData.Location.IN_OFFICE
			state.remove_rental(rental)
	return completed

func check_rental_extensions(state: Node) -> Array:
	var extensions: Array = []
	for rental in state.active_rentals:
		if rental.is_extension_window():
			rental.extension_offered = true
			extensions.append(rental)
	return extensions

func extend_rental(rental: ConsultantRental, extra_duration: float) -> void:
	rental.duration_remaining += extra_duration
	rental.total_duration += extra_duration
	rental.extension_offered = false  # Reset for next potential extension

func generate_rental_offers(count: int, reputation: float) -> Array:
	var offers: Array = []
	for i in range(count):
		var base_rate = 1.0 + reputation * 0.05 + randf_range(0.0, 2.0)
		var duration = randf_range(300.0, 900.0)  # 5-15 minutes game time
		var num_skills = randi_range(1, 2)
		var required: Dictionary = {}
		var shuffled = SKILL_POOL.duplicate()
		shuffled.shuffle()
		for j in range(num_skills):
			required[shuffled[j]] = randi_range(1, clampi(int(reputation / 20.0) + 1, 1, 4))
		offers.append({
			"client_name": RENTAL_CLIENT_NAMES[randi() % RENTAL_CLIENT_NAMES.size()],
			"rate_per_tick": base_rate,
			"duration": duration,
			"required_skills": required,
		})
	return offers
```

**Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_rentals.gd`
Expected: All 8 tests PASS

**Step 5: Run all tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add src/logic/consultant_manager.gd test/unit/test_rentals.gd
git commit -m "feat: add consultant rental system with extensions"
```

---

### Task 6: Management Contract Pool (Tiered Split)

**Files:**
- Modify: `src/logic/bidding_system.gd`
- Test: `test/unit/test_contract_tiers.gd`

**Step 1: Write the failing tests**

Create `test/unit/test_contract_tiers.gd`:

```gdscript
extends GutTest

var bidding: BiddingSystem

func before_each():
	bidding = BiddingSystem.new()

func test_personal_contracts_are_tier_1_and_2():
	# Generate many contracts and filter for personal
	var contracts = bidding.generate_personal_contracts(10, 80.0)
	for c in contracts:
		assert_lte(c.tier, 2, "Personal contracts should be tier 1-2")

func test_management_contracts_are_tier_2_and_above():
	var contracts = bidding.generate_management_contracts(10, 80.0)
	for c in contracts:
		assert_gte(c.tier, 2, "Management contracts should be tier 2+")

func test_management_contracts_have_more_tasks():
	var personal = bidding.generate_personal_contracts(20, 80.0)
	var management = bidding.generate_management_contracts(20, 80.0)
	var avg_personal = 0.0
	for c in personal:
		avg_personal += c.task_count
	avg_personal /= personal.size()
	var avg_management = 0.0
	for c in management:
		avg_management += c.task_count
	avg_management /= management.size()
	assert_gt(avg_management, avg_personal, "Management contracts should have more tasks")

func test_existing_generate_contracts_still_works():
	# Backward compatibility
	var contracts = bidding.generate_contracts(5, 50.0)
	assert_eq(contracts.size(), 5)
```

**Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_contract_tiers.gd`
Expected: FAIL — `generate_personal_contracts`, `generate_management_contracts` don't exist

**Step 3: Implement tiered contract generation**

Add to `src/logic/bidding_system.gd` (after existing `generate_contracts` method):

```gdscript
func generate_personal_contracts(count: int, reputation: float) -> Array[ClientContract]:
	var contracts: Array[ClientContract] = []
	var max_tier = clampi(int(reputation / 20.0) + 1, 1, 2)  # Cap at tier 2
	for i in range(count):
		var contract = _generate_contract(clampi(randi_range(1, max_tier), 1, 2))
		contracts.append(contract)
	return contracts

func generate_management_contracts(count: int, reputation: float) -> Array[ClientContract]:
	var contracts: Array[ClientContract] = []
	var max_tier = clampi(int(reputation / 20.0) + 1, 2, 4)
	for i in range(count):
		var tier = clampi(randi_range(2, max_tier), 2, 4)
		var contract = _generate_contract(tier)
		# Management contracts are bigger
		contract.task_count = int(contract.task_count * 1.5)
		contracts.append(contract)
	return contracts

func _generate_contract(tier: int) -> ClientContract:
	var contract = ClientContract.new()
	contract.client_name = CLIENT_NAMES[randi() % CLIENT_NAMES.size()]
	contract.project_description = PROJECT_TYPES[randi() % PROJECT_TYPES.size()]
	contract.tier = tier
	var base_tasks = tier * 15 + randi_range(9, 36)
	if tier <= 2:
		base_tasks = base_tasks / 2
	contract.task_count = base_tasks
	contract.payout_per_task = tier * 25.0 + randf_range(0, tier * 15.0)
	var num_skills = randi_range(1, mini(2, SKILL_POOL.size()))
	var shuffled = SKILL_POOL.duplicate()
	shuffled.shuffle()
	for j in range(num_skills):
		contract.required_skills[shuffled[j]] = randi_range(1, tier * 2)
	contract.duration = 120.0 - tier * 15.0
	return contract
```

Refactor existing `generate_contracts` to use `_generate_contract`:

```gdscript
func generate_contracts(count: int, reputation: float) -> Array[ClientContract]:
	var contracts: Array[ClientContract] = []
	var max_tier = clampi(int(reputation / 20.0) + 1, 1, 4)
	for i in range(count):
		var contract = _generate_contract(clampi(randi_range(1, max_tier), 1, 4))
		contracts.append(contract)
	return contracts
```

**Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_contract_tiers.gd`
Expected: All 4 tests PASS

**Step 5: Run all tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All tests PASS (existing bidding tests should still pass)

**Step 6: Commit**

```bash
git add src/logic/bidding_system.gd test/unit/test_contract_tiers.gd
git commit -m "feat: add tiered contract generation for personal vs management"
```

---

### Task 7: Management Office Scene (Top-Down Visual)

**Files:**
- Create: `src/management/management_office.tscn`
- Create: `src/management/management_office.gd`

This task creates the visual scene without full UI panels — just the office floor layout with clickable areas.

**Step 1: Create the minimal .tscn file**

Create `src/management/management_office.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/management/management_office.gd" id="1"]

[node name="ManagementOffice" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

**Step 2: Implement the management office scene**

Create `src/management/management_office.gd`:

```gdscript
extends Control

signal back_to_desk_requested
signal contract_board_clicked
signal hiring_board_clicked
signal staff_roster_clicked
signal inbox_clicked
signal consultant_clicked(consultant: ConsultantData)

const DESK_SIZE = Vector2(80, 60)
const DESK_SPACING = Vector2(120, 100)
const OFFICE_BG_COLOR = Color(0.18, 0.2, 0.22)
const WALL_COLOR = Color(0.25, 0.27, 0.3)
const DESK_COLOR = Color(0.35, 0.3, 0.25)
const FLOOR_COLOR = Color(0.22, 0.24, 0.26)

const CHAT_MESSAGES = [
	"JavaScript really sucks",
	"I hate weak typing",
	"Who wrote this code... oh wait, it was me",
	"It works on my machine",
	"Have you tried turning it off and on again?",
	"This should only take 5 minutes...",
	"Tabs > spaces, fight me",
	"sudo rm -rf /",
	"It's not a bug, it's a feature",
	"Segfault at line 42",
	"Why is Python so slow?",
	"Rust would never let this happen",
	"LGTM, ship it",
	"Did anyone review this PR?",
	"The tests pass locally...",
	"Can we just rewrite it in Go?",
	"Docker fixes everything",
	"My code compiles, therefore it works",
]

var _desk_positions: Array = []
var _consultant_sprites: Dictionary = {}  # consultant.id -> dictionary of nodes
var _chat_timer: float = 0.0
var _interactive_rects: Dictionary = {}  # name -> Rect2

func _ready():
	_build_office()

func _build_office():
	# Background
	var bg = ColorRect.new()
	bg.color = FLOOR_COLOR
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Walls (top border)
	var wall = ColorRect.new()
	wall.color = WALL_COLOR
	wall.position = Vector2(0, 0)
	wall.size = Vector2(1152, 60)
	add_child(wall)

	# Back to Desk door (top-left)
	var door_back = _create_interactive_object(
		"Back to Desk", Vector2(40, 10), Vector2(100, 45),
		Color(0.5, 0.35, 0.2), Color(0.9, 0.85, 0.7)
	)
	door_back.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			back_to_desk_requested.emit()
	)

	# Contract Board (whiteboard on wall, center-left)
	var board = _create_interactive_object(
		"Contracts", Vector2(300, 8), Vector2(130, 46),
		Color(0.85, 0.85, 0.8), Color(0.2, 0.2, 0.25)
	)
	board.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			contract_board_clicked.emit()
	)

	# Hiring Board (screen on wall, center)
	var hiring = _create_interactive_object(
		"Hiring", Vector2(500, 8), Vector2(110, 46),
		Color(0.2, 0.3, 0.45), Color(0.8, 0.9, 1.0)
	)
	hiring.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			hiring_board_clicked.emit()
	)

	# Staff Roster (clipboard on wall, center-right)
	var roster = _create_interactive_object(
		"Staff", Vector2(680, 8), Vector2(90, 46),
		Color(0.6, 0.55, 0.4), Color(0.15, 0.15, 0.2)
	)
	roster.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			staff_roster_clicked.emit()
	)

	# Inbox (near entrance, right side of wall)
	var inbox = _create_interactive_object(
		"Inbox", Vector2(850, 8), Vector2(90, 46),
		Color(0.3, 0.35, 0.5), Color(0.9, 0.8, 0.6)
	)
	inbox.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			inbox_clicked.emit()
	)

	# Locked door placeholder (far right on wall)
	var locked_door = _create_interactive_object(
		"🔒 Teams", Vector2(1020, 10), Vector2(100, 45),
		Color(0.3, 0.25, 0.2), Color(0.5, 0.5, 0.55)
	)

	# Generate desk positions (grid layout below wall)
	_generate_desk_layout()

func _create_interactive_object(label_text: String, pos: Vector2, obj_size: Vector2, bg_color: Color, text_color: Color) -> Control:
	var container = Control.new()
	container.position = pos
	container.size = obj_size
	add_child(container)

	var bg = ColorRect.new()
	bg.color = bg_color
	bg.size = obj_size
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(bg)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", text_color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = obj_size
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(lbl)

	return bg

func _generate_desk_layout():
	_desk_positions.clear()
	var start_pos = Vector2(100, 100)
	var cols = 4
	var rows = ceili(float(GameState.desk_capacity) / cols)
	for row in range(rows):
		for col in range(cols):
			var idx = row * cols + col
			if idx >= GameState.desk_capacity:
				break
			var pos = start_pos + Vector2(col * DESK_SPACING.x, row * DESK_SPACING.y)
			_desk_positions.append(pos)
			_draw_desk(pos, idx)

func _draw_desk(pos: Vector2, index: int):
	var desk = ColorRect.new()
	desk.name = "Desk_%d" % index
	desk.color = DESK_COLOR
	desk.position = pos
	desk.size = DESK_SIZE
	add_child(desk)

func refresh():
	# Update consultant sprites based on current GameState
	_clear_consultant_sprites()
	var in_office = GameState.get_consultants_by_location(ConsultantData.Location.IN_OFFICE)
	for i in range(mini(in_office.size(), _desk_positions.size())):
		_add_consultant_sprite(in_office[i], _desk_positions[i], i)

func _clear_consultant_sprites():
	for id in _consultant_sprites:
		var nodes = _consultant_sprites[id]
		if nodes.has("container") and is_instance_valid(nodes["container"]):
			nodes["container"].queue_free()
	_consultant_sprites.clear()

func _add_consultant_sprite(c: ConsultantData, desk_pos: Vector2, _index: int):
	var container = Control.new()
	container.position = desk_pos + Vector2(DESK_SIZE.x / 2 - 15, -35)
	add_child(container)

	# Consultant circle (top-down head view)
	var head = ColorRect.new()
	head.size = Vector2(30, 30)
	head.color = _get_consultant_color(c)
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			consultant_clicked.emit(c)
	)
	container.add_child(head)

	# Name label
	var name_label = Label.new()
	name_label.text = c.name.split(" ")[0]  # First name only
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.position = Vector2(-10, 32)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(name_label)

	# State indicator
	var state_label = Label.new()
	state_label.name = "StateLabel"
	state_label.add_theme_font_size_override("font_size", 9)
	state_label.position = Vector2(-10, -15)
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if c.training_skill != "":
		state_label.text = "📖 Training"
		state_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	else:
		state_label.text = "📱 Idle"
		state_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	container.add_child(state_label)

	_consultant_sprites[c.id] = {"container": container, "consultant": c}

func _get_consultant_color(c: ConsultantData) -> Color:
	# Hash-based color from consultant name for consistency
	var h = c.name.hash()
	return Color.from_hsv(fmod(abs(float(h)) / 1000.0, 1.0), 0.4, 0.7)

func _process(delta: float):
	_chat_timer += delta
	if _chat_timer >= 4.0:  # New chat bubble every 4 seconds
		_chat_timer = 0.0
		_spawn_random_chat()

func _spawn_random_chat():
	if _consultant_sprites.is_empty():
		return
	var ids = _consultant_sprites.keys()
	var random_id = ids[randi() % ids.size()]
	var sprite_data = _consultant_sprites[random_id]
	if not is_instance_valid(sprite_data["container"]):
		return

	var bubble = Label.new()
	bubble.text = CHAT_MESSAGES[randi() % CHAT_MESSAGES.size()]
	bubble.add_theme_font_size_override("font_size", 10)
	bubble.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	bubble.position = Vector2(35, -25)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_data["container"].add_child(bubble)

	# Fade out and remove after 3 seconds
	var tween = create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.5)
	tween.tween_callback(bubble.queue_free)

# Show empty desks for "on assignment" with nameplate
func _mark_empty_desks():
	# Get consultants on project or rental
	var away = []
	for c in GameState.consultants:
		if c.location == ConsultantData.Location.ON_PROJECT or c.location == ConsultantData.Location.ON_RENTAL:
			away.append(c)
	# Place "Out" signs on remaining desks after in-office consultants
	var in_office_count = GameState.get_consultants_by_location(ConsultantData.Location.IN_OFFICE).size()
	for i in range(mini(away.size(), _desk_positions.size() - in_office_count)):
		var desk_idx = in_office_count + i
		if desk_idx < _desk_positions.size():
			var pos = _desk_positions[desk_idx]
			var sign_label = Label.new()
			sign_label.text = "Out: %s" % away[i].name.split(" ")[0]
			sign_label.add_theme_font_size_override("font_size", 9)
			sign_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
			sign_label.position = pos + Vector2(5, DESK_SIZE.y + 2)
			sign_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(sign_label)
```

**Step 3: Run import to register**

Run: `godot --headless --import`

**Step 4: Verify scene loads without errors**

Run: `godot --headless --quit` (quick startup/shutdown test)
Expected: No errors in output

**Step 5: Commit**

```bash
git add src/management/management_office.tscn src/management/management_office.gd
git commit -m "feat: add management office top-down scene with desk layout and chat bubbles"
```

---

### Task 8: Management UI Panels (Contract Board, Hiring Board, Staff Roster, Inbox)

**Files:**
- Create: `src/management/contract_board.tscn` + `src/management/contract_board.gd`
- Create: `src/management/hiring_board.tscn` + `src/management/hiring_board.gd`
- Create: `src/management/staff_roster.tscn` + `src/management/staff_roster.gd`
- Create: `src/management/management_inbox.tscn` + `src/management/management_inbox.gd`

Each panel follows the same pattern: PanelContainer with `_build_ui()`, a `close_requested` signal, and a `refresh()` method. This task is large but all four panels are independent.

**Step 1: Create Contract Board**

Create `src/management/contract_board.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/management/contract_board.gd" id="1"]

[node name="ContractBoard" type="PanelContainer"]
script = ExtResource("1")
```

Create `src/management/contract_board.gd`:

```gdscript
extends PanelContainer

signal close_requested
signal consultant_assigned(consultant: ConsultantData, contract: ClientContract)
signal consultant_placed_on_rental(consultant: ConsultantData, offer: Dictionary)

var _bidding_system: BiddingSystem = BiddingSystem.new()
var _consultant_manager: ConsultantManager = ConsultantManager.new()
var _content: VBoxContainer
var _contracts: Array = []
var _rental_offers: Array = []
var _tab: String = "projects"  # "projects" or "rentals"

func _ready():
	custom_minimum_size = Vector2(700, 500)
	_build_ui()

func _build_ui():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	add_child(_content)

func refresh():
	_contracts = _bidding_system.generate_management_contracts(4, GameState.reputation)
	_rental_offers = _consultant_manager.generate_rental_offers(3, GameState.reputation)
	_rebuild_display()

func _rebuild_display():
	for child in _content.get_children():
		child.queue_free()

	# Header
	var header = HBoxContainer.new()
	_content.add_child(header)

	var title = Label.new()
	title.text = "Contract Board"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	# Tabs
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	_content.add_child(tab_row)

	var proj_btn = Button.new()
	proj_btn.text = "Projects"
	proj_btn.disabled = _tab == "projects"
	proj_btn.pressed.connect(func(): _tab = "projects"; _rebuild_display())
	tab_row.add_child(proj_btn)

	var rental_btn = Button.new()
	rental_btn.text = "Rentals"
	rental_btn.disabled = _tab == "rentals"
	rental_btn.pressed.connect(func(): _tab = "rentals"; _rebuild_display())
	tab_row.add_child(rental_btn)

	# Scroll container
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 350)
	_content.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	if _tab == "projects":
		_show_projects(list)
	else:
		_show_rentals(list)

func _show_projects(list: VBoxContainer):
	var available = GameState.get_available_consultants()
	for contract in _contracts:
		var card = _create_contract_card(contract, available)
		list.add_child(card)

func _show_rentals(list: VBoxContainer):
	var available = GameState.get_available_consultants()
	for offer in _rental_offers:
		var card = _create_rental_card(offer, available)
		list.add_child(card)

func _create_contract_card(contract: ClientContract, available: Array) -> PanelContainer:
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.16, 0.16, 0.2)
	card_style.set_content_margin_all(10)
	card_style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var name_label = Label.new()
	name_label.text = "%s — %s" % [contract.client_name, contract.project_description]
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	var info = Label.new()
	info.text = "Tier %d | %d tasks | $%.0f/task | Total: $%.0f" % [
		contract.tier, contract.task_count, contract.payout_per_task,
		contract.get_total_value() * 0.7  # 70% team rate
	]
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(info)

	var skills_text = "Skills: "
	for skill_id in contract.required_skills:
		skills_text += "%s Lv%d  " % [skill_id, contract.required_skills[skill_id]]
	var skills_label = Label.new()
	skills_label.text = skills_text
	skills_label.add_theme_font_size_override("font_size", 11)
	skills_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
	vbox.add_child(skills_label)

	# Assign buttons for each available consultant
	if not available.is_empty():
		var btn_row = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 6)
		vbox.add_child(btn_row)
		for c in available:
			var btn = Button.new()
			btn.text = "Assign %s" % c.name.split(" ")[0]
			btn.add_theme_font_size_override("font_size", 11)
			btn.pressed.connect(func(): consultant_assigned.emit(c, contract))
			btn_row.add_child(btn)

	return card

func _create_rental_card(offer: Dictionary, available: Array) -> PanelContainer:
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.16, 0.18, 0.2)
	card_style.set_content_margin_all(10)
	card_style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var name_label = Label.new()
	name_label.text = "%s — Consultant Rental" % offer["client_name"]
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	var info = Label.new()
	var duration_min = offer["duration"] / 60.0
	info.text = "$%.1f/sec | %.0f min duration | Est. total: $%.0f" % [
		offer["rate_per_tick"], duration_min,
		offer["rate_per_tick"] * offer["duration"]
	]
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(info)

	var skills_text = "Wants: "
	for skill_id in offer["required_skills"]:
		skills_text += "%s Lv%d  " % [skill_id, offer["required_skills"][skill_id]]
	var skills_label = Label.new()
	skills_label.text = skills_text
	skills_label.add_theme_font_size_override("font_size", 11)
	skills_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
	vbox.add_child(skills_label)

	if not available.is_empty():
		var btn_row = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 6)
		vbox.add_child(btn_row)
		for c in available:
			var btn = Button.new()
			btn.text = "Send %s" % c.name.split(" ")[0]
			btn.add_theme_font_size_override("font_size", 11)
			btn.pressed.connect(func(): consultant_placed_on_rental.emit(c, offer))
			btn_row.add_child(btn)

	return card
```

**Step 2: Create Hiring Board**

Create `src/management/hiring_board.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/management/hiring_board.gd" id="1"]

[node name="HiringBoard" type="PanelContainer"]
script = ExtResource("1")
```

Create `src/management/hiring_board.gd`:

```gdscript
extends PanelContainer

signal close_requested

var _consultant_manager: ConsultantManager = ConsultantManager.new()
var _job_market: Array = []
var _content: VBoxContainer

func _ready():
	custom_minimum_size = Vector2(600, 450)
	_build_ui()

func _build_ui():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	add_child(_content)

func refresh():
	_job_market = _consultant_manager.generate_job_market(4, GameState.reputation)
	_rebuild_display()

func refresh_market():
	refresh()

func _rebuild_display():
	for child in _content.get_children():
		child.queue_free()

	# Header
	var header = HBoxContainer.new()
	_content.add_child(header)

	var title = Label.new()
	title.text = "Hiring — Job Market"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	# Capacity info
	var cap_label = Label.new()
	cap_label.text = "Staff: %d / %d (Desks: %d)" % [
		GameState.consultants.size(), GameState.get_max_staff(), GameState.desk_capacity
	]
	cap_label.add_theme_font_size_override("font_size", 12)
	cap_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_content.add_child(cap_label)

	# Scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for c in _job_market:
		var card = _create_candidate_card(c)
		list.add_child(card)

	# Refresh button
	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh Market"
	refresh_btn.pressed.connect(func(): refresh())
	_content.add_child(refresh_btn)

func _create_candidate_card(c: ConsultantData) -> PanelContainer:
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.16, 0.16, 0.2)
	card_style.set_content_margin_all(10)
	card_style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", card_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = "%s — %s" % [c.name, c.get_trait_label()]
	name_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(name_label)

	var skills_text = ""
	for skill_id in c.skills:
		skills_text += "%s Lv%d  " % [skill_id, int(c.skills[skill_id])]
	var skills_label = Label.new()
	skills_label.text = skills_text
	skills_label.add_theme_font_size_override("font_size", 11)
	skills_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
	info_vbox.add_child(skills_label)

	var salary_label = Label.new()
	salary_label.text = "Salary: $%.0f/period | Hire fee: $%.0f" % [
		c.salary, _consultant_manager.get_hire_cost(c)
	]
	salary_label.add_theme_font_size_override("font_size", 11)
	salary_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	info_vbox.add_child(salary_label)

	var already_hired = false
	for existing in GameState.consultants:
		if existing.id == c.id:
			already_hired = true
			break

	var btn = Button.new()
	if already_hired:
		btn.text = "Hired"
		btn.disabled = true
	elif not GameState.can_hire():
		btn.text = "Full"
		btn.disabled = true
	else:
		btn.text = "Hire $%.0f" % _consultant_manager.get_hire_cost(c)
		btn.pressed.connect(func():
			if _consultant_manager.try_hire(c, GameState):
				_rebuild_display()
		)
	hbox.add_child(btn)

	return card
```

**Step 3: Create Staff Roster**

Create `src/management/staff_roster.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/management/staff_roster.gd" id="1"]

[node name="StaffRoster" type="PanelContainer"]
script = ExtResource("1")
```

Create `src/management/staff_roster.gd`:

```gdscript
extends PanelContainer

signal close_requested
signal fire_consultant(consultant: ConsultantData)
signal train_consultant(consultant: ConsultantData, skill_id: String)
signal stop_training_consultant(consultant: ConsultantData)
signal set_remote(consultant: ConsultantData, remote: bool)

var _content: VBoxContainer
var _consultant_manager: ConsultantManager = ConsultantManager.new()

func _ready():
	custom_minimum_size = Vector2(650, 500)
	_build_ui()

func _build_ui():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	add_child(_content)

func refresh():
	for child in _content.get_children():
		child.queue_free()

	# Header
	var header = HBoxContainer.new()
	_content.add_child(header)

	var title = Label.new()
	title.text = "Staff Roster"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	# Summary
	var summary = Label.new()
	var total_salary = GameState.get_total_salary()
	summary.text = "Staff: %d | Desks: %d | Total salary: $%.0f/period" % [
		GameState.consultants.size(), GameState.desk_capacity, total_salary
	]
	summary.add_theme_font_size_override("font_size", 12)
	summary.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_content.add_child(summary)

	# Scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for c in GameState.consultants:
		list.add_child(_create_consultant_row(c))

func _create_consultant_row(c: ConsultantData) -> PanelContainer:
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.16, 0.16, 0.2)
	card_style.set_content_margin_all(8)
	card_style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", card_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Info column
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label = Label.new()
	name_label.text = "%s — %s" % [c.name, c.get_trait_label()]
	name_label.add_theme_font_size_override("font_size", 13)
	info.add_child(name_label)

	var skills_text = ""
	for skill_id in c.skills:
		skills_text += "%s Lv%.1f  " % [skill_id, c.skills[skill_id]]
	var skills_label = Label.new()
	skills_label.text = skills_text
	skills_label.add_theme_font_size_override("font_size", 10)
	skills_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
	info.add_child(skills_label)

	# Status
	var status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 11)
	match c.location:
		ConsultantData.Location.IN_OFFICE:
			if c.training_skill != "":
				status_label.text = "📖 Training: %s | $%.0f/period" % [c.training_skill, c.salary]
				status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
			else:
				status_label.text = "📱 Idle (In Office) | $%.0f/period" % c.salary
				status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
		ConsultantData.Location.REMOTE:
			if c.training_skill != "":
				status_label.text = "🏠 Remote Training: %s (slower) | $%.0f/period" % [c.training_skill, c.salary]
			else:
				status_label.text = "🏠 Remote (Idle) | $%.0f/period" % c.salary
			status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		ConsultantData.Location.ON_PROJECT:
			var assignment_info = _find_assignment_info(c)
			status_label.text = "💼 On Project: %s | $%.0f/period" % [assignment_info, c.salary]
			status_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
		ConsultantData.Location.ON_RENTAL:
			var rental_info = _find_rental_info(c)
			status_label.text = "🏢 On Rental: %s | $%.0f/period" % [rental_info, c.salary]
			status_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.7))
	info.add_child(status_label)

	# Action buttons (only for available consultants)
	var btn_col = VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 4)
	hbox.add_child(btn_col)

	if c.is_available():
		if c.training_skill != "":
			var stop_btn = Button.new()
			stop_btn.text = "Stop Training"
			stop_btn.add_theme_font_size_override("font_size", 10)
			stop_btn.pressed.connect(func(): stop_training_consultant.emit(c))
			btn_col.add_child(stop_btn)
		else:
			var train_btn = Button.new()
			train_btn.text = "Train..."
			train_btn.add_theme_font_size_override("font_size", 10)
			train_btn.pressed.connect(func(): _show_training_picker(c))
			btn_col.add_child(train_btn)

		if c.location == ConsultantData.Location.IN_OFFICE:
			var remote_btn = Button.new()
			remote_btn.text = "Send Remote"
			remote_btn.add_theme_font_size_override("font_size", 10)
			remote_btn.pressed.connect(func(): set_remote.emit(c, true))
			btn_col.add_child(remote_btn)
		else:
			var office_btn = Button.new()
			office_btn.text = "Bring to Office"
			office_btn.add_theme_font_size_override("font_size", 10)
			office_btn.pressed.connect(func(): set_remote.emit(c, false))
			btn_col.add_child(office_btn)

	var fire_btn = Button.new()
	fire_btn.text = "Fire"
	fire_btn.add_theme_font_size_override("font_size", 10)
	fire_btn.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	fire_btn.disabled = not c.is_available()  # Can't fire someone on assignment
	fire_btn.pressed.connect(func(): fire_consultant.emit(c))
	btn_col.add_child(fire_btn)

	return card

func _find_assignment_info(c: ConsultantData) -> String:
	for a in GameState.active_assignments:
		if c in a.consultants:
			return "%s (Task %d/%d)" % [a.contract.client_name, a.current_task_index + 1, a.get_total_tasks()]
	return "Unknown"

func _find_rental_info(c: ConsultantData) -> String:
	for r in GameState.active_rentals:
		if r.consultant == c:
			var mins_left = r.duration_remaining / 60.0
			return "%s (%.0f min left)" % [r.client_name, mins_left]
	return "Unknown"

func _show_training_picker(c: ConsultantData):
	# Simple skill picker - train any skill they have or common skills
	var all_skills = ["javascript", "python", "rust", "go", "devops", "frameworks", "coding_speed", "code_quality"]
	train_consultant.emit(c, all_skills[0])  # Default to first; TODO: add picker UI
	# For now, cycle through skills or pick first non-maxed
	# This will be refined in a follow-up task
```

**Step 4: Create Management Inbox**

Create `src/management/management_inbox.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/management/management_inbox.gd" id="1"]

[node name="ManagementInbox" type="PanelContainer"]
script = ExtResource("1")
```

Create `src/management/management_inbox.gd`:

```gdscript
extends PanelContainer

signal close_requested
signal extension_accepted(rental: ConsultantRental)
signal issue_choice_made(issue: ManagementIssue, choice_index: int)

var _content: VBoxContainer
var _pending_extensions: Array = []  # Array of ConsultantRental
var _pending_issues: Array = []  # Array of ManagementIssue

func _ready():
	custom_minimum_size = Vector2(550, 400)
	_build_ui()

func _build_ui():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	add_child(_content)

func set_notifications(extensions: Array, issues: Array):
	_pending_extensions = extensions
	_pending_issues = issues
	refresh()

func get_notification_count() -> int:
	return _pending_extensions.size() + _pending_issues.size()

func refresh():
	for child in _content.get_children():
		child.queue_free()

	# Header
	var header = HBoxContainer.new()
	_content.add_child(header)

	var title = Label.new()
	title.text = "Management Inbox"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	if _pending_extensions.is_empty() and _pending_issues.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No notifications"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		_content.add_child(empty_label)
		return

	# Scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	# Rental extensions
	for rental in _pending_extensions:
		list.add_child(_create_extension_card(rental))

	# Management issues
	for issue in _pending_issues:
		list.add_child(_create_issue_card(issue))

func _create_extension_card(rental: ConsultantRental) -> PanelContainer:
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.16, 0.2, 0.18)
	card_style.set_content_margin_all(10)
	card_style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var title_label = Label.new()
	title_label.text = "Rental Extension — %s at %s" % [rental.consultant.name, rental.client_name]
	title_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title_label)

	var desc = Label.new()
	desc.text = "%s wants to keep %s for another %.0f minutes. Accept to extend the rental." % [
		rental.client_name, rental.consultant.name, rental.total_duration / 60.0
	]
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	var accept_btn = Button.new()
	accept_btn.text = "Accept Extension"
	accept_btn.pressed.connect(func(): extension_accepted.emit(rental))
	btn_row.add_child(accept_btn)

	var decline_btn = Button.new()
	decline_btn.text = "Let it end"
	decline_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	decline_btn.pressed.connect(func():
		_pending_extensions.erase(rental)
		refresh()
	)
	btn_row.add_child(decline_btn)

	return card

func _create_issue_card(issue: ManagementIssue) -> PanelContainer:
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.16, 0.16, 0.2)
	card_style.set_content_margin_all(10)
	card_style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var title_label = Label.new()
	title_label.text = issue.title
	title_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title_label)

	var desc = Label.new()
	desc.text = issue.description
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	for i in range(issue.choices.size()):
		var choice = issue.choices[i]
		var btn = Button.new()
		btn.text = choice["label"]
		btn.add_theme_font_size_override("font_size", 11)
		var idx = i  # Capture for closure
		btn.pressed.connect(func(): issue_choice_made.emit(issue, idx))
		btn_row.add_child(btn)

	return card
```

**Step 5: Run import to register all new scenes**

Run: `godot --headless --import`

**Step 6: Commit**

```bash
git add src/management/contract_board.tscn src/management/contract_board.gd \
  src/management/hiring_board.tscn src/management/hiring_board.gd \
  src/management/staff_roster.tscn src/management/staff_roster.gd \
  src/management/management_inbox.tscn src/management/management_inbox.gd
git commit -m "feat: add management UI panels (contract board, hiring, roster, inbox)"
```

---

### Task 9: Integrate Scene Switching in main.gd

**Files:**
- Modify: `src/main.gd`
- Delete references to: `src/ui/hiring_panel.gd`, `src/ui/hiring_panel.tscn`

This is the integration task that wires everything together. The door in the personal office now transitions to the management office scene instead of opening the hiring panel overlay.

**Step 1: Modify main.gd — Add management scene and scene switching**

Add new vars (after existing panel vars):

```gdscript
# Management scene
var management_office: Control
var management_layer: CanvasLayer
var management_overlay_layer: CanvasLayer
var management_dimmer: ColorRect
var _management_current_overlay: Control = null
var _in_management: bool = false

# Management UI panels
var contract_board: PanelContainer
var hiring_board: PanelContainer
var staff_roster: PanelContainer
var management_inbox: PanelContainer

# Rental extension queue
var _pending_extensions: Array = []
```

**Step 2: Add management scene builder (after `_build_overlay_layer`)**

Add method `_build_management_layer()`:

```gdscript
func _build_management_layer():
	management_layer = CanvasLayer.new()
	management_layer.layer = 5
	management_layer.visible = false
	add_child(management_layer)

	management_office = load("res://src/management/management_office.tscn").instantiate()
	management_office.set_anchors_preset(Control.PRESET_FULL_RECT)
	management_layer.add_child(management_office)

	# Management overlay layer (on top of management scene)
	management_overlay_layer = CanvasLayer.new()
	management_overlay_layer.layer = 25
	management_overlay_layer.visible = false
	add_child(management_overlay_layer)

	management_dimmer = ColorRect.new()
	management_dimmer.color = Color(0, 0, 0, 0.5)
	management_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	management_dimmer.gui_input.connect(_on_management_dimmer_input)
	management_overlay_layer.add_child(management_dimmer)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	management_overlay_layer.add_child(center)

	contract_board = load("res://src/management/contract_board.tscn").instantiate()
	contract_board.visible = false
	center.add_child(contract_board)

	hiring_board = load("res://src/management/hiring_board.tscn").instantiate()
	hiring_board.visible = false
	center.add_child(hiring_board)

	staff_roster = load("res://src/management/staff_roster.tscn").instantiate()
	staff_roster.visible = false
	center.add_child(staff_roster)

	management_inbox = load("res://src/management/management_inbox.tscn").instantiate()
	management_inbox.visible = false
	center.add_child(management_inbox)
```

**Step 3: Connect management signals (add to `_connect_signals`)**

```gdscript
	# Management office signals
	management_office.back_to_desk_requested.connect(_switch_to_personal)
	management_office.contract_board_clicked.connect(func():
		contract_board.refresh()
		_show_management_overlay(contract_board)
	)
	management_office.hiring_board_clicked.connect(func():
		hiring_board.refresh()
		_show_management_overlay(hiring_board)
	)
	management_office.staff_roster_clicked.connect(func():
		staff_roster.refresh()
		_show_management_overlay(staff_roster)
	)
	management_office.inbox_clicked.connect(func():
		management_inbox.set_notifications(_pending_extensions, _pending_issues)
		_show_management_overlay(management_inbox)
	)

	# Management panel close signals
	contract_board.close_requested.connect(_hide_management_overlay)
	hiring_board.close_requested.connect(_hide_management_overlay)
	staff_roster.close_requested.connect(_hide_management_overlay)
	management_inbox.close_requested.connect(_hide_management_overlay)

	# Contract board actions
	contract_board.consultant_assigned.connect(_on_management_assign)
	contract_board.consultant_placed_on_rental.connect(_on_management_rental)

	# Staff roster actions
	staff_roster.fire_consultant.connect(_on_fire_consultant)
	staff_roster.train_consultant.connect(_on_train_consultant)
	staff_roster.stop_training_consultant.connect(_on_stop_training)
	staff_roster.set_remote.connect(_on_set_remote)

	# Inbox actions
	management_inbox.extension_accepted.connect(_on_rental_extension_accepted)
	management_inbox.issue_choice_made.connect(_on_management_issue_choice)
```

**Step 4: Add scene switching methods**

```gdscript
func _switch_to_management():
	if not GameState.office_unlocked:
		return
	_in_management = true
	desk_scene.visible = false
	if state == DeskState.ZOOMED_TO_MONITOR:
		ide_layer.visible = false
	management_layer.visible = true
	management_office.refresh()

func _switch_to_personal():
	_in_management = false
	management_layer.visible = false
	management_overlay_layer.visible = false
	desk_scene.visible = true
	if state == DeskState.ZOOMED_TO_MONITOR:
		ide_layer.visible = true

func _show_management_overlay(panel: Control):
	_management_current_overlay = panel
	panel.visible = true
	management_overlay_layer.visible = true

func _hide_management_overlay():
	if _management_current_overlay:
		_management_current_overlay.visible = false
	_management_current_overlay = null
	management_overlay_layer.visible = false

func _on_management_dimmer_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_management_overlay()
```

**Step 5: Add management action handlers**

```gdscript
func _on_management_assign(consultant: ConsultantData, contract: ClientContract):
	consultant.location = ConsultantData.Location.ON_PROJECT
	consultant.training_skill = ""
	consultant_manager.create_assignment(contract, [consultant], GameState)
	_hide_management_overlay()
	management_office.refresh()

func _on_management_rental(consultant: ConsultantData, offer: Dictionary):
	consultant_manager.place_on_rental(
		consultant, offer["client_name"], offer["rate_per_tick"], offer["duration"], GameState
	)
	_hide_management_overlay()
	management_office.refresh()

func _on_fire_consultant(consultant: ConsultantData):
	if not consultant.is_available():
		return
	GameState.remove_consultant(consultant)
	staff_roster.refresh()
	management_office.refresh()

func _on_train_consultant(consultant: ConsultantData, skill_id: String):
	consultant_manager.start_training(consultant, skill_id)
	staff_roster.refresh()
	management_office.refresh()

func _on_stop_training(consultant: ConsultantData):
	consultant_manager.stop_training(consultant)
	staff_roster.refresh()
	management_office.refresh()

func _on_set_remote(consultant: ConsultantData, remote: bool):
	if remote:
		consultant.location = ConsultantData.Location.REMOTE
	else:
		# Check if there's desk space
		var in_office = GameState.get_consultants_by_location(ConsultantData.Location.IN_OFFICE).size()
		if in_office < GameState.desk_capacity:
			consultant.location = ConsultantData.Location.IN_OFFICE
	staff_roster.refresh()
	management_office.refresh()

func _on_rental_extension_accepted(rental: ConsultantRental):
	consultant_manager.extend_rental(rental, rental.total_duration)
	_pending_extensions.erase(rental)
	management_inbox.set_notifications(_pending_extensions, _pending_issues)

func _on_management_issue_choice(issue: ManagementIssue, choice_index: int):
	consultant_manager.apply_issue_choice(issue, choice_index, GameState)
	_pending_issues.erase(issue)
	management_inbox.set_notifications(_pending_extensions, _pending_issues)
```

**Step 6: Modify `_on_door_clicked` to switch scenes**

Replace the existing `_on_door_clicked` method:

```gdscript
func _on_door_clicked():
	if state != DeskState.DESK:
		return
	if not GameState.office_unlocked:
		# Show unlock prompt (keep existing behavior)
		return
	_switch_to_management()
```

**Step 7: Update `_process` to tick training and rentals**

Add to `_process` (after existing consultant assignment ticking):

```gdscript
	# Training ticking
	consultant_manager.tick_training(delta, GameState)

	# Rental ticking
	var completed_rentals = consultant_manager.tick_rentals(delta, GameState)
	for rental in completed_rentals:
		EventBus.rental_completed.emit(rental)

	# Check for rental extension opportunities
	var new_extensions = consultant_manager.check_rental_extensions(GameState)
	for rental in new_extensions:
		_pending_extensions.append(rental)
		EventBus.rental_extension_available.emit(rental)
```

**Step 8: Update `_ready` to call `_build_management_layer`**

Add `_build_management_layer()` call in `_ready()` after `_build_overlay_layer()`.

**Step 9: Remove old hiring panel references**

Remove from `_build_overlay_layer`:
```gdscript
	hiring_panel = load("res://src/ui/hiring_panel.tscn").instantiate()
	hiring_panel.visible = false
	center.add_child(hiring_panel)
```

Remove from `_connect_signals`:
```gdscript
	hiring_panel.close_requested.connect(_hide_overlay)
```

Remove the `hiring_panel` var declaration.

**Step 10: Update contract acceptance flow**

Modify `_on_contract_accepted` — remove the team assignment choice when in the personal office. Personal contracts are always worked personally now:

```gdscript
func _on_contract_accepted(contract: ClientContract, diff_mod: float):
	_work_personally(contract, diff_mod)
```

Remove `_show_contract_choice`, `_assign_team`, `_team_assign_contract`, `_team_assign_diff_mod`.

**Step 11: Update ESC handling for management scene**

In `_unhandled_input`, add management overlay handling:

```gdscript
	if _in_management:
		if _management_current_overlay:
			_hide_management_overlay()
		else:
			_switch_to_personal()
		get_viewport().set_input_as_handled()
		return
```

**Step 12: Run all tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All tests PASS

**Step 13: Commit**

```bash
git add src/main.gd
git commit -m "feat: integrate management office scene with scene switching"
```

---

### Task 10: Update Save/Load for New State

**Files:**
- Modify: `src/systems/save_manager.gd`
- Test: `test/unit/test_save_management.gd`

**Step 1: Write the failing tests**

Create `test/unit/test_save_management.gd`:

```gdscript
extends GutTest

var save_mgr: Node
var state: Node

func before_each():
	save_mgr = load("res://src/systems/save_manager.gd").new()
	save_mgr.save_path = "user://test_management_save.json"
	add_child_autofree(save_mgr)
	state = load("res://src/autoload/game_state.gd").new()
	add_child_autofree(state)

func after_each():
	save_mgr.delete_save()

func test_save_desk_capacity():
	state.desk_capacity = 6
	save_mgr.save_game({}, state)
	var data = save_mgr.load_game()
	save_mgr.apply_save(data, state)
	assert_eq(state.desk_capacity, 6)

func test_save_consultant_location():
	var c = ConsultantData.new()
	c.id = "loc1"
	c.name = "Test"
	c.salary = 500.0
	c.location = ConsultantData.Location.REMOTE
	c.training_skill = "python"
	state.add_consultant(c)
	save_mgr.save_game({}, state)

	state.consultants.clear()
	var data = save_mgr.load_game()
	save_mgr.apply_save(data, state)
	assert_eq(state.consultants.size(), 1)
	assert_eq(state.consultants[0].location, ConsultantData.Location.REMOTE)
	assert_eq(state.consultants[0].training_skill, "python")

func test_save_active_rentals():
	var c = ConsultantData.new()
	c.id = "rent1"
	c.name = "Renter"
	c.salary = 600.0
	c.location = ConsultantData.Location.ON_RENTAL
	state.add_consultant(c)

	var rental = ConsultantRental.new()
	rental.consultant = c
	rental.client_name = "BigCorp"
	rental.rate_per_tick = 3.0
	rental.total_duration = 600.0
	rental.duration_remaining = 400.0
	rental.extension_offered = true
	state.add_rental(rental)

	save_mgr.save_game({}, state)
	state.consultants.clear()
	state.active_rentals.clear()

	var data = save_mgr.load_game()
	save_mgr.apply_save(data, state)
	assert_eq(state.active_rentals.size(), 1)
	var restored = state.active_rentals[0]
	assert_eq(restored.client_name, "BigCorp")
	assert_almost_eq(restored.rate_per_tick, 3.0, 0.01)
	assert_almost_eq(restored.duration_remaining, 400.0, 0.01)
	assert_true(restored.extension_offered)
	assert_eq(restored.consultant.id, "rent1")

func test_backward_compat_without_new_fields():
	# Simulate an old save that doesn't have new fields
	state.money = 1000.0
	save_mgr.save_game({}, state)

	# Manually strip new fields from save
	var data = save_mgr.load_game()
	data["game_state"].erase("desk_capacity")
	data.erase("active_rentals")

	save_mgr.apply_save(data, state)
	assert_eq(state.desk_capacity, 4)  # Default
	assert_eq(state.active_rentals.size(), 0)
```

**Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_save_management.gd`
Expected: FAIL — new fields not serialized

**Step 3: Implement save/load extensions**

Modify `_build_save_dict` in `src/systems/save_manager.gd` — add desk_capacity to game_state dict:

```gdscript
	# In game_state dict, add:
	"desk_capacity": gs_node.desk_capacity,
```

Add rental serialization (after active_assignments block):

```gdscript
	# Active rentals
	data["active_rentals"] = []
	for r in gs_node.active_rentals:
		data["active_rentals"].append(_serialize_rental(r))
```

Modify `apply_save` — restore desk_capacity:

```gdscript
	gs_node.desk_capacity = int(gs.get("desk_capacity", 4))
```

Add rental restoration (after assignment restoration):

```gdscript
	# Restore active rentals
	gs_node.active_rentals.clear()
	for rd in data.get("active_rentals", []):
		var rental = _deserialize_rental(rd, gs_node.consultants)
		if rental:
			gs_node.active_rentals.append(rental)
```

Modify `_serialize_consultant` — add new fields:

```gdscript
	"location": c.location,
	"training_skill": c.training_skill,
```

Modify `_deserialize_consultant` — restore new fields:

```gdscript
	c.location = int(d.get("location", 0))  # 0 = IN_OFFICE
	c.training_skill = str(d.get("training_skill", ""))
```

Add rental serialization helpers:

```gdscript
func _serialize_rental(r: ConsultantRental) -> Dictionary:
	return {
		"consultant_id": r.consultant.id if r.consultant else "",
		"client_name": r.client_name,
		"rate_per_tick": r.rate_per_tick,
		"total_duration": r.total_duration,
		"duration_remaining": r.duration_remaining,
		"extension_offered": r.extension_offered,
	}

func _deserialize_rental(d: Dictionary, all_consultants: Array) -> ConsultantRental:
	var r = ConsultantRental.new()
	r.client_name = str(d.get("client_name", ""))
	r.rate_per_tick = float(d.get("rate_per_tick", 1.0))
	r.total_duration = float(d.get("total_duration", 600.0))
	r.duration_remaining = float(d.get("duration_remaining", 600.0))
	r.extension_offered = bool(d.get("extension_offered", false))
	var cid = str(d.get("consultant_id", ""))
	for c in all_consultants:
		if c.id == cid:
			r.consultant = c
			break
	if not r.consultant:
		return null
	return r
```

**Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_save_management.gd`
Expected: All 4 tests PASS

**Step 5: Run all tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add src/systems/save_manager.gd test/unit/test_save_management.gd
git commit -m "feat: extend save/load for consultant location, training, and rentals"
```

---

### Task 11: Clean Up Old Hiring Panel References

**Files:**
- Delete: `src/ui/hiring_panel.gd`, `src/ui/hiring_panel.tscn`
- Modify: `src/main.gd` (if any remaining references)

**Step 1: Remove old files**

```bash
git rm src/ui/hiring_panel.gd src/ui/hiring_panel.tscn
```

**Step 2: Search for remaining references**

Search codebase for `hiring_panel` references in files other than management code. Fix any remaining references in `main.gd`.

**Step 3: Remove `[Team]` prefix email integration from main.gd**

The management issues now go through the management inbox, not the personal email. Remove the management issue merging from `_refresh_email_display` and `_on_email_choice`.

In `_refresh_email_display`, remove the management issue loop:
```gdscript
func _refresh_email_display():
	var all_events: Array = event_manager.pending_events.duplicate()
	# Removed: management issue merge — issues now in management inbox
	email_panel.display_events(all_events)
```

In `_on_email_choice`, remove the management issue detection:
```gdscript
func _on_email_choice(event: RandomEvent, choice_index: int):
	event_manager.apply_choice(event, choice_index, GameState)
	desk_scene.set_email_badge_count(event_manager.get_unread_count())
	_refresh_email_display()
	EventBus.random_event_resolved.emit(event)
	if event_manager.pending_events.is_empty():
		_hide_overlay()
```

Update email badge to not include management issues:
```gdscript
# Everywhere that sets email badge, remove + _pending_issues.size()
desk_scene.set_email_badge_count(event_manager.get_unread_count())
```

**Step 4: Run all tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor: remove old hiring panel, move management issues to management inbox"
```

---

### Task 12: Update Test Save and Manual Verification

**Files:**
- Modify: `src/systems/save_manager.gd` (update `create_test_save`)

**Step 1: Update test save to include management data**

Update `create_test_save` in save_manager.gd to include desk_capacity, consultant locations, and an active rental for testing.

**Step 2: Run the game manually**

Run: `godot --path /home/lars/Prosjekter/consultancy-tycoon`

Manual test checklist:
- [ ] Click door in personal office → transitions to top-down management office
- [ ] Management office shows desk layout with consultant sprites
- [ ] Chat bubbles appear on idle/training consultants
- [ ] Click "Back to Desk" → returns to personal office
- [ ] Click Contract Board → shows projects and rentals tabs
- [ ] Click Hiring Board → shows job market with hire buttons
- [ ] Click Staff Roster → shows all consultants with status
- [ ] Assign consultant to rental → they disappear from office
- [ ] Rental completes → consultant returns
- [ ] ESC works in management scene (closes overlay, then switches back)
- [ ] Save/Load preserves management state
- [ ] Personal contracts still work (click to code, no team choice)

**Step 3: Run all tests one final time**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add src/systems/save_manager.gd
git commit -m "chore: update test save with management data"
```

---

## Summary

| Task | What | Tests Added |
|------|------|-------------|
| 1 | ConsultantData location + training state | 11 |
| 2 | ConsultantRental data model | 8 |
| 3 | GameState desk capacity + rentals + queries | 11 |
| 4 | Training logic (passive + active) | 8 |
| 5 | Rental system logic | 8 |
| 6 | Tiered contract generation | 4 |
| 7 | Management office scene (top-down) | — |
| 8 | Management UI panels (4 panels) | — |
| 9 | Scene switching integration in main.gd | — |
| 10 | Save/Load extensions | 4 |
| 11 | Clean up old hiring panel | — |
| 12 | Test save update + manual verification | — |

**Total new tests: ~54**
**Total estimated: 156 tests (102 existing + 54 new)**
