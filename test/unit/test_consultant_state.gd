extends GutTest

var consultant: ConsultantData

func before_each():
	consultant = ConsultantData.new()
	consultant.id = "test_loc"
	consultant.name = "Test Consultant"
	consultant.skills = {"javascript": 2}
	consultant.salary = 600.0
	consultant.morale = 1.0

func test_default_location_is_in_office():
	assert_eq(consultant.location, ConsultantData.Location.IN_OFFICE,
		"Default location should be IN_OFFICE")

func test_set_location():
	consultant.location = ConsultantData.Location.REMOTE
	assert_eq(consultant.location, ConsultantData.Location.REMOTE,
		"Should be able to set location to REMOTE")
	consultant.location = ConsultantData.Location.ON_PROJECT
	assert_eq(consultant.location, ConsultantData.Location.ON_PROJECT,
		"Should be able to set location to ON_PROJECT")
	consultant.location = ConsultantData.Location.ON_RENTAL
	assert_eq(consultant.location, ConsultantData.Location.ON_RENTAL,
		"Should be able to set location to ON_RENTAL")

func test_default_training_skill_is_empty():
	assert_eq(consultant.training_skill, "",
		"Default training_skill should be empty string")

func test_set_training_skill():
	consultant.training_skill = "python"
	assert_eq(consultant.training_skill, "python",
		"Should be able to set training_skill")

func test_is_available_when_in_office_idle():
	consultant.location = ConsultantData.Location.IN_OFFICE
	assert_true(consultant.is_available(),
		"Should be available when IN_OFFICE")

func test_is_available_when_remote_idle():
	consultant.location = ConsultantData.Location.REMOTE
	assert_true(consultant.is_available(),
		"Should be available when REMOTE")

func test_not_available_when_on_project():
	consultant.location = ConsultantData.Location.ON_PROJECT
	assert_false(consultant.is_available(),
		"Should NOT be available when ON_PROJECT")

func test_not_available_when_on_rental():
	consultant.location = ConsultantData.Location.ON_RENTAL
	assert_false(consultant.is_available(),
		"Should NOT be available when ON_RENTAL")

func test_is_trainable_in_office():
	consultant.location = ConsultantData.Location.IN_OFFICE
	assert_true(consultant.is_trainable(),
		"Should be trainable when IN_OFFICE")

func test_is_trainable_remote():
	consultant.location = ConsultantData.Location.REMOTE
	assert_true(consultant.is_trainable(),
		"Should be trainable when REMOTE")

func test_not_trainable_on_project():
	consultant.location = ConsultantData.Location.ON_PROJECT
	assert_false(consultant.is_trainable(),
		"Should NOT be trainable when ON_PROJECT")
