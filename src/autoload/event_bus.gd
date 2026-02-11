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
