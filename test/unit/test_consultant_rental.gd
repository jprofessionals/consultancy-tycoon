extends GutTest

var rental: ConsultantRental

func before_each():
	rental = ConsultantRental.new()
	rental.consultant = ConsultantData.new()
	rental.consultant.id = "test_c"
	rental.consultant.name = "Test Dev"
	rental.client_name = "Acme Corp"
	rental.rate_per_tick = 2.5
	rental.total_duration = 600.0
	rental.duration_remaining = 600.0

func test_create_rental():
	assert_eq(rental.client_name, "Acme Corp")
	assert_eq(rental.rate_per_tick, 2.5)
	assert_eq(rental.total_duration, 600.0)
	assert_eq(rental.duration_remaining, 600.0)
	assert_eq(rental.extension_offered, false)
	assert_eq(rental.consultant.name, "Test Dev")

func test_rental_not_complete_initially():
	assert_false(rental.is_complete(), "New rental should not be complete")

func test_rental_completes_at_zero():
	rental.duration_remaining = 0.0
	assert_true(rental.is_complete(), "Rental with 0 remaining should be complete")

func test_tick_reduces_duration():
	rental.tick(1.0)
	assert_eq(rental.duration_remaining, 599.0, "Tick should reduce duration by delta")

func test_tick_does_not_go_negative():
	rental.duration_remaining = 0.5
	rental.tick(1.0)
	assert_eq(rental.duration_remaining, 0.0, "Duration should clamp at 0")

func test_extension_pending_near_end():
	# 10% of 600 = 60, so at 50 remaining we're in the window
	rental.duration_remaining = 50.0
	assert_true(rental.is_extension_window(), "Should be in extension window near end")

func test_extension_not_pending_if_already_extended():
	rental.duration_remaining = 50.0
	rental.extension_offered = true
	assert_false(rental.is_extension_window(), "Should not offer extension if already offered")

func test_get_earnings_per_tick():
	assert_eq(rental.get_earnings_per_tick(), 2.5)
