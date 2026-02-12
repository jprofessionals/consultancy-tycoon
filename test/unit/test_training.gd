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
	for i in range(1000):
		manager.tick_training(1.0, state)
	var total_skill: float = 0.0
	for level in c.skills.values():
		total_skill += level
	assert_gt(total_skill, 2.0, "Should have some passive growth after 1000 seconds")

func test_passive_growth_slower_when_remote():
	var c_office = _make_consultant(ConsultantData.Location.IN_OFFICE)
	c_office.id = "office1"
	c_office.skills = {"javascript": 2.0}
	var c_remote = _make_consultant(ConsultantData.Location.REMOTE)
	c_remote.id = "remote1"
	c_remote.skills = {"javascript": 2.0}
	state.add_consultant(c_office)
	state.add_consultant(c_remote)
	for i in range(1000):
		manager.tick_training(1.0, state)
	assert_gt(c_office.skills["javascript"], c_remote.skills["javascript"])

func test_active_training_faster_than_passive():
	var c_passive = _make_consultant()
	c_passive.id = "passive1"
	c_passive.skills = {"javascript": 2.0}
	var c_active = _make_consultant()
	c_active.id = "active1"
	c_active.skills = {"javascript": 2.0}
	c_active.training_skill = "javascript"
	state.add_consultant(c_passive)
	state.add_consultant(c_active)
	for i in range(500):
		manager.tick_training(1.0, state)
	assert_gt(c_active.skills["javascript"], c_passive.skills["javascript"])

func test_training_cost_per_tick():
	state.money = 10000.0
	var c = _make_consultant()
	c.training_skill = "python"
	state.add_consultant(c)
	manager.tick_training(1.0, state)
	assert_lt(state.money, 10000.0)

func test_no_training_cost_for_idle():
	state.money = 10000.0
	var c = _make_consultant()
	c.training_skill = ""
	state.add_consultant(c)
	manager.tick_training(1.0, state)
	assert_eq(state.money, 10000.0)

func test_no_training_when_on_project():
	var c = _make_consultant(ConsultantData.Location.ON_PROJECT)
	c.training_skill = "javascript"
	var initial_level = c.skills["javascript"]
	state.add_consultant(c)
	for i in range(100):
		manager.tick_training(1.0, state)
	assert_eq(c.skills["javascript"], initial_level)

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
