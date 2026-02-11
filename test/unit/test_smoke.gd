extends GutTest

func test_godot_is_running():
	assert_true(true, "Godot test framework is working")

func test_basic_math():
	assert_eq(2 + 2, 4, "Basic arithmetic works")
