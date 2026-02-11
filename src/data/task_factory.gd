extends RefCounted
class_name TaskFactory

const TASK_TEMPLATES = [
	"Fix authentication bug",
	"Add payment endpoint",
	"Refactor database queries",
	"Implement search feature",
	"Update REST API",
	"Fix CSS layout issue",
	"Add input validation",
	"Optimize image loading",
	"Write migration script",
	"Add logging middleware",
	"Fix race condition",
	"Implement caching layer",
	"Add rate limiting",
	"Refactor error handling",
	"Build notification service",
]

func generate_task(tier: int) -> CodingTask:
	var task = CodingTask.new()
	task.title = TASK_TEMPLATES[randi() % TASK_TEMPLATES.size()]
	task.difficulty = clampi(tier + randi_range(-1, 1), 1, 10)
	task.payout = tier * 25.0 + randf_range(0, tier * 10.0)
	task.total_clicks = 8 + tier * 4 + randi_range(0, 4)
	return task
