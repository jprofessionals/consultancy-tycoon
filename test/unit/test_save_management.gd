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
	state.money = 1000.0
	save_mgr.save_game({}, state)
	var data = save_mgr.load_game()
	data["game_state"].erase("desk_capacity")
	data.erase("active_rentals")
	save_mgr.apply_save(data, state)
	assert_eq(state.desk_capacity, 4)
	assert_eq(state.active_rentals.size(), 0)
