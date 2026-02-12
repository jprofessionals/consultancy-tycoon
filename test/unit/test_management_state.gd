extends GutTest

var state: Node

func before_each():
	state = load("res://src/autoload/game_state.gd").new()
	add_child_autofree(state)

func _make_consultant(loc: int = ConsultantData.Location.IN_OFFICE) -> ConsultantData:
	var c = ConsultantData.new()
	c.id = "test_%d" % randi()
	c.name = "Test Consultant"
	c.salary = 500.0
	c.location = loc
	return c

func _make_rental() -> ConsultantRental:
	var r = ConsultantRental.new()
	r.consultant = _make_consultant(ConsultantData.Location.ON_RENTAL)
	r.client_name = "Test Client"
	r.rate_per_tick = 2.0
	r.total_duration = 600.0
	r.duration_remaining = 600.0
	return r

func test_default_desk_capacity():
	assert_eq(state.desk_capacity, 4)

func test_active_rentals_starts_empty():
	assert_eq(state.active_rentals.size(), 0)

func test_add_rental():
	var rental = _make_rental()
	state.add_rental(rental)
	assert_eq(state.active_rentals.size(), 1)
	assert_eq(state.active_rentals[0], rental)

func test_remove_rental():
	var rental = _make_rental()
	state.add_rental(rental)
	state.remove_rental(rental)
	assert_eq(state.active_rentals.size(), 0)

func test_max_staff_is_3x_desk_capacity():
	assert_eq(state.get_max_staff(), 12)  # 4 desks * 3

func test_max_staff_scales_with_capacity():
	state.desk_capacity = 1
	assert_eq(state.get_max_staff(), 3)
	state.desk_capacity = 8
	assert_eq(state.get_max_staff(), 24)

func test_can_hire_under_max():
	assert_true(state.can_hire())  # 0 consultants, max 12

func test_cannot_hire_at_max():
	state.desk_capacity = 1  # max = 3
	for i in 3:
		state.consultants.append(_make_consultant())
	assert_false(state.can_hire())

func test_get_in_office_consultants():
	var office1 = _make_consultant(ConsultantData.Location.IN_OFFICE)
	var remote1 = _make_consultant(ConsultantData.Location.REMOTE)
	var office2 = _make_consultant(ConsultantData.Location.IN_OFFICE)
	state.consultants.append(office1)
	state.consultants.append(remote1)
	state.consultants.append(office2)
	var in_office = state.get_consultants_by_location(ConsultantData.Location.IN_OFFICE)
	assert_eq(in_office.size(), 2)
	assert_has(in_office, office1)
	assert_has(in_office, office2)

func test_get_available_consultants():
	var office = _make_consultant(ConsultantData.Location.IN_OFFICE)
	var remote = _make_consultant(ConsultantData.Location.REMOTE)
	var on_project = _make_consultant(ConsultantData.Location.ON_PROJECT)
	var on_rental = _make_consultant(ConsultantData.Location.ON_RENTAL)
	state.consultants.append(office)
	state.consultants.append(remote)
	state.consultants.append(on_project)
	state.consultants.append(on_rental)
	var available = state.get_available_consultants()
	assert_eq(available.size(), 2)
	assert_has(available, office)
	assert_has(available, remote)
