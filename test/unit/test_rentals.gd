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
	assert_almost_eq(state.money, 1050.0, 0.01)

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
	assert_false(rental.extension_offered)

func test_generate_rental_offers():
	var offers = manager.generate_rental_offers(3, 50.0)
	assert_eq(offers.size(), 3)
	for offer in offers:
		assert_has(offer, "client_name")
		assert_has(offer, "rate_per_tick")
		assert_has(offer, "duration")
		assert_has(offer, "required_skills")
