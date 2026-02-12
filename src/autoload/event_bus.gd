extends Node

# Coding loop signals
signal task_started(task)
signal task_phase_changed(phase)
signal task_completed(task, payout)
signal click_performed(progress_delta)

# Client signals
signal contract_offered(contract)
signal contract_bid_result(contract, success)

# Skill signals
signal skill_purchased(skill_id)

# Economy signals
signal money_changed(new_amount)
signal reputation_changed(new_amount)

# Random event signals
signal random_event_received(event)
signal random_event_resolved(event)

# AI tool signals
signal ai_tool_upgraded(tool_id, tier)
signal ai_tool_acted(tool_id, action, success)

# Office / hiring signals
signal office_unlocked
signal consultant_hired(consultant)
signal consultant_left(consultant)
signal assignment_completed(assignment)
signal management_issue(issue)

# Management scene signals
signal rental_started(rental)
signal rental_completed(rental)
signal rental_extension_available(rental)
signal consultant_training_started(consultant, skill_id)
signal consultant_location_changed(consultant, new_location)
signal scene_switch_requested(scene_name)

# Multi-tab signals
signal tab_stuck(tab_index: int)
signal tab_unstuck(tab_index: int)
signal tab_task_done(task: CodingTask, tab: CodingTab)
