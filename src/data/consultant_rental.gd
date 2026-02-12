extends Resource
class_name ConsultantRental

var consultant: ConsultantData
var client_name: String = ""
var rate_per_tick: float = 1.0
var total_duration: float = 600.0
var duration_remaining: float = 600.0
var extension_offered: bool = false

func is_complete() -> bool:
	return duration_remaining <= 0.0

func tick(delta: float) -> void:
	duration_remaining = maxf(duration_remaining - delta, 0.0)

func is_extension_window() -> bool:
	if extension_offered:
		return false
	if is_complete():
		return false
	return duration_remaining <= total_duration * 0.1

func get_earnings_per_tick() -> float:
	return rate_per_tick
