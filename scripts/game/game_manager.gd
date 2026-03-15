extends Node

# main orchestrator for the prototype

# preload data classes so enums/types are available
const Role = preload("res://scripts/data/role.gd").Role
const Player = preload("res://scripts/data/player.gd")
const Policy = preload("res://scripts/data/policy.gd")
const GameState = preload("res://scripts/data/game_state.gd")
static var influence_to_win: int = 5
static var last_winner_text: String = ""
static var last_patrician_influence: int = 0
static var last_plebian_influence: int = 0
static var last_round_number: int = 0

@onready var state: GameState = GameState.new()
var pending_policy_choices: Array = []
var policy_discard_stage: String = ""
var _game_over_handled: bool = false

func role_name(role: int) -> String:
	match role:
		Role.CAESAR:
			return "Caesar"
		Role.PATRICIAN:
			return "Patrician"
		Role.PLEBIAN:
			return "Plebeian"
		_:
			return "Unknown"

func _alignment_score(role: int, beneficiary: int) -> int:
	if role == beneficiary:
		return 2
	if role == Role.CAESAR and beneficiary == Role.PATRICIAN:
		return 1
	if role == Role.CAESAR and beneficiary == Role.PLEBIAN:
		return -1
	if role == Role.PATRICIAN and beneficiary == Role.PLEBIAN:
		return -2
	if role == Role.PLEBIAN and beneficiary == Role.PATRICIAN:
		return -2
	return 0

func _required_yes_votes() -> int:
	# Simple majority: floor(n/2) + 1
	return int(floor(state.players.size() / 2.0)) + 1

func _pick_ai_nominee() -> int:
	var candidates = get_nominee_candidates()
	if candidates.size() == 0:
		return -1
	var consul_role = state.players[state.current_consul_index].role
	var best_candidate = candidates[0]
	var best_score = -99999
	for candidate_index in candidates:
		var candidate = state.players[candidate_index]
		var score = _alignment_score(consul_role, candidate.role) * 10 - candidate.co_consul_count
		if score > best_score:
			best_score = score
			best_candidate = candidate_index
	return best_candidate

func auto_select_ai_nominee() -> bool:
	if state.game_phase != "election" or state.election_nominee_index >= 0:
		return false
	if not state.players[state.current_consul_index].is_ai:
		return false
	var nominee = _pick_ai_nominee()
	if nominee < 0:
		return false
	return select_election_nominee(nominee)

func _should_ai_vote_yes(voter_id: int, nominee_id: int) -> bool:
	var voter = state.players[voter_id]
	var nominee = state.players[nominee_id]

	if voter.role == nominee.role:
		return true
	if voter.role == Role.CAESAR:
		return true

	if voter.role == Role.PATRICIAN and nominee.role == Role.PLEBIAN:
		return state.influence_plebian > state.influence_patrician + 1
	if voter.role == Role.PLEBIAN and nominee.role == Role.PATRICIAN:
		return state.influence_patrician > state.influence_plebian + 1

	return true

func auto_fill_ai_election_votes() -> void:
	if state.game_phase != "election" or state.election_nominee_index < 0:
		return
	var yes_count = 0
	for vote in state.election_vote_inputs:
		if vote == 1:
			yes_count += 1
	for player_id in range(state.players.size()):
		if state.election_vote_inputs[player_id] != -1:
			continue
		if not state.players[player_id].is_ai:
			continue
		var remaining_ai_unset = 0
		for j in range(player_id + 1, state.players.size()):
			if state.election_vote_inputs[j] == -1 and state.players[j].is_ai:
				remaining_ai_unset += 1
		var needed_yes = _required_yes_votes() - yes_count
		var must_vote_yes = needed_yes > 0 and needed_yes >= (remaining_ai_unset + 1)
		var vote_yes = must_vote_yes or _should_ai_vote_yes(player_id, state.election_nominee_index)
		set_election_vote(player_id, vote_yes)
		if vote_yes:
			yes_count += 1

func _pick_ai_spending_choice(player_id: int) -> Dictionary:
	var player = state.players[player_id]
	var money = player.money
	if money <= 0:
		return {"option": "A", "amount": 0}

	var a_score = _alignment_score(player.role, state.policy_enacted.option_a_beneficiary)
	var b_score = _alignment_score(player.role, state.policy_enacted.option_b_beneficiary)
	var option = "A"
	var score = a_score
	if b_score > a_score or (b_score == a_score and state.policy_enacted.option_b_gold_amount > state.policy_enacted.option_a_gold_amount):
		option = "B"
		score = b_score

	var spend_ratio = 0.35
	if score >= 2:
		spend_ratio = 0.75
	elif score == 1:
		spend_ratio = 0.6
	elif score < 0:
		spend_ratio = 0.15

	var amount = int(round(float(money) * spend_ratio))
	amount = clamp(amount, 0, money)
	return {"option": option, "amount": amount}

func auto_run_ai_spending_inputs() -> void:
	if state.game_phase != "spending":
		return
	while true:
		if state.spending_stage == "resolved":
			return
		if state.spending_stage == "handoff":
			if not advance_spending_turn():
				return
			continue
		if state.spending_stage != "input":
			return
		var player_id = state.spending_input_player_index
		if player_id < 0 or player_id >= state.players.size():
			return
		if not state.players[player_id].is_ai:
			return
		var choice = _pick_ai_spending_choice(player_id)
		set_spending_allocation(choice.get("option", "A"), choice.get("amount", 0))

# Election: consul nominates and players vote
# Policy: consul/co-consul discard, apply influence, run money vote
# Phase flow controlled by state.game_phase

func _ready():
	print("GameManager ready")
	create_players()
	state.all_policies = Policy.example_policies()
	state.game_phase = "init"
	start_round()

func create_players():
	state.players.clear()
	for i in range(6):
		var p = Player.new()
		p.player_id = i
		p.is_ai = true
		state.players.append(p)
	assign_roles()

func assign_roles():
	# simple distribution: 1 Caesar, 2 Patricians, 3 Plebeians
	var roles = [Role.CAESAR] + [Role.PATRICIAN, Role.PATRICIAN] + [Role.PLEBIAN, Role.PLEBIAN, Role.PLEBIAN]
	roles.shuffle()
	for i in range(state.players.size()):
		state.players[i].role = roles[i]
		state.players[i].money = 0

func start_round():
	state.round_number += 1
	print("Starting round %d" % state.round_number)
	distribute_money()
	# make sure consul index is valid
	state.current_consul_index = state.current_consul_index % state.players.size()
	# reset co-consul for this round
	state.current_co_consul_index = -1
	# update runtime flags
	for p in state.players:
		p.is_consul = false
		p.is_co_consul = false
	state.players[state.current_consul_index].is_consul = true
	# clear phase results
	state.election_nominee_index = -1
	state.election_votes_yes.clear()
	state.election_votes_no.clear()
	state.election_passed = false
	# Intentionally keep ineligible_co_consul_indices across rounds.
	# It is only refreshed after a successful election.
	state.election_vote_inputs.clear()
	for i in range(state.players.size()):
		state.election_vote_inputs.append(-1)
	state.policy_drawn_ids.clear()
	state.policy_discarded_ids.clear()
	state.policy_enacted = null
	pending_policy_choices.clear()
	policy_discard_stage = ""
	state.spending_option_a_total = 0
	state.spending_option_b_total = 0
	state.spending_winner = ""
	state.spending_stage = "idle"
	state.spending_input_player_index = -1
	state.spending_private_inputs.clear()
	state.spending_confirmed_players.clear()
	state.game_phase = "election"
	print_current_consul()

func distribute_money():
	for p in state.players:
		match p.role:
			Role.CAESAR:
				p.money += 8
			Role.PATRICIAN:
				p.money += 6
			Role.PLEBIAN:
				p.money += 4

func print_current_consul():
	var p = state.players[state.current_consul_index]
	print("Consul is player %d (%s)" % [p.player_id, role_name(p.role)])
	print("Current phase: %s" % state.game_phase)

func next_consul():
	state.current_consul_index = (state.current_consul_index + 1) % state.players.size()
	# update runtime flags
	for p in state.players:
		p.is_consul = false
		p.is_co_consul = false
	state.players[state.current_consul_index].is_consul = true
	state.game_phase = "election"
	print_current_consul()

# --- new functionality added below ---

func get_nominee_candidates() -> Array:
	var candidates = []
	for i in range(state.players.size()):
		if i != state.current_consul_index and not state.ineligible_co_consul_indices.has(i):
			candidates.append(i)
	return candidates

func select_election_nominee(nominee_index: int) -> bool:
	if state.game_phase != "election":
		return false
	if nominee_index < 0 or nominee_index >= state.players.size():
		return false
	if not get_nominee_candidates().has(nominee_index):
		return false
	state.election_nominee_index = nominee_index
	state.election_votes_yes.clear()
	state.election_votes_no.clear()
	for i in range(state.election_vote_inputs.size()):
		state.election_vote_inputs[i] = -1
	print("Consul selected nominee player %d" % nominee_index)
	return true

func set_election_vote(player_id: int, is_yes: bool) -> bool:
	if state.game_phase != "election":
		return false
	if state.election_nominee_index < 0:
		return false
	if player_id < 0 or player_id >= state.players.size():
		return false
	state.election_vote_inputs[player_id] = 1 if is_yes else 0
	return true

func are_election_votes_complete() -> bool:
	if state.election_vote_inputs.size() != state.players.size():
		return false
	for vote in state.election_vote_inputs:
		if vote == -1:
			return false
	return true

func conduct_election() -> bool:
	if state.election_nominee_index < 0:
		print("No nominee selected yet")
		return false
	var nominee = state.election_nominee_index
	print("Consul nominates player %d" % nominee)
	state.election_votes_yes.clear()
	state.election_votes_no.clear()
	if not are_election_votes_complete():
		print("Not all votes are set yet")
		return false
	for player_id in range(state.election_vote_inputs.size()):
		if state.election_vote_inputs[player_id] == 1:
			state.election_votes_yes.append(player_id)
		else:
			state.election_votes_no.append(player_id)
	var yes = state.election_votes_yes.size()
	var no = state.election_votes_no.size()
	print("Votes - yes: %d no: %d" % [yes, no])
	if yes >= _required_yes_votes():
		state.election_passed = true
		print("Election passed, player %d is co-consul" % nominee)
		state.current_co_consul_index = nominee
		# Update blocked pair only on successful election.
		# Failed elections keep the previous successful pair blocked.
		state.ineligible_co_consul_indices = [state.current_consul_index, nominee]
		# update runtime flags
		for p in state.players:
			p.is_co_consul = false
		var co = state.players[nominee]
		co.is_co_consul = true
		co.co_consul_count += 1
		return true
	else:
		state.election_passed = false
		print("Election failed")
		return false

func start_policy_phase() -> void:
	pending_policy_choices.clear()
	state.policy_drawn_ids.clear()
	state.policy_discarded_ids.clear()
	state.policy_enacted = null
	for i in range(3):
		if state.all_policies.size() > 0:
			var p = state.all_policies.pop_back()
			pending_policy_choices.append(p)
			state.policy_drawn_ids.append(p.id)
	if pending_policy_choices.size() <= 1:
		enact_remaining_policy()
		return
	policy_discard_stage = "consul"
	print("Policy phase started. Drawn policy IDs:", state.policy_drawn_ids)

func get_policy_discard_candidates() -> Array:
	var ids = []
	for p in pending_policy_choices:
		ids.append(p.id)
	return ids

func get_policy_discard_stage() -> String:
	return policy_discard_stage

func discard_policy_by_id(policy_id: int) -> bool:
	if state.game_phase != "policy":
		return false
	if policy_discard_stage == "":
		return false
	var found_index = -1
	for i in range(pending_policy_choices.size()):
		if pending_policy_choices[i].id == policy_id:
			found_index = i
			break
	if found_index == -1:
		return false
	state.policy_discarded_ids.append(policy_id)
	pending_policy_choices.remove_at(found_index)
	if pending_policy_choices.size() <= 1:
		enact_remaining_policy()
		return true
	if policy_discard_stage == "consul":
		policy_discard_stage = "co_consul"
		print("Consul discarded policy %d. Co-consul must discard next." % policy_id)
	return true

func enact_remaining_policy() -> void:
	if pending_policy_choices.size() == 0:
		policy_discard_stage = ""
		return
	state.policy_enacted = pending_policy_choices[0]
	pending_policy_choices.clear()
	policy_discard_stage = "done"
	print("Final enacted policy %d" % state.policy_enacted.id)
	apply_policy(state.policy_enacted)

func policy_cycle():
	# kept for compatibility; policy flow is now interactive via start_policy_phase/discard_policy_by_id
	start_policy_phase()

func apply_policy(p: Policy) -> void:
	if p.faction == Role.PATRICIAN:
		state.influence_patrician += 1
	else:
		state.influence_plebian += 1
	print("Applied policy %d (faction %d)" % [p.id, p.faction])
	check_win_condition()

func start_spending_phase() -> void:
	if state.policy_enacted == null:
		return
	state.spending_option_a_total = 0
	state.spending_option_b_total = 0
	state.spending_winner = ""
	state.spending_private_inputs.clear()
	state.spending_confirmed_players.clear()
	for i in range(state.players.size()):
		state.spending_private_inputs.append({"option": "A", "amount": 0})
		state.spending_confirmed_players.append(false)
	state.spending_input_player_index = 0
	state.spending_stage = "input"
	print("Spending phase started. Waiting for Player %d private input." % state.spending_input_player_index)

func get_current_spending_player_id() -> int:
	return state.spending_input_player_index

func get_current_spending_player_money() -> int:
	if state.spending_input_player_index < 0 or state.spending_input_player_index >= state.players.size():
		return 0
	return state.players[state.spending_input_player_index].money

func set_spending_allocation(option_key: String, spend_amount: int) -> bool:
	if state.game_phase != "spending" or state.spending_stage != "input":
		return false
	var player_id = state.spending_input_player_index
	if player_id < 0 or player_id >= state.players.size():
		return false
	if option_key != "A" and option_key != "B":
		return false
	var total_money = state.players[player_id].money
	if spend_amount < 0 or spend_amount > total_money:
		return false
	state.spending_private_inputs[player_id] = {"option": option_key, "amount": spend_amount}
	state.spending_confirmed_players[player_id] = true
	state.spending_stage = "handoff"
	print("Player %d spending captured privately." % player_id)
	return true

func advance_spending_turn() -> bool:
	if state.game_phase != "spending" or state.spending_stage != "handoff":
		return false
	var next_player = state.spending_input_player_index + 1
	while next_player < state.players.size() and state.spending_confirmed_players[next_player]:
		next_player += 1
	if next_player >= state.players.size():
		resolve_spending_totals()
		return true
	state.spending_input_player_index = next_player
	state.spending_stage = "input"
	print("Ready for Player %d private spending input." % next_player)
	return true

func resolve_spending_totals() -> void:
	if state.policy_enacted == null:
		return
	var total_a = 0
	var total_b = 0
	for player_id in range(state.players.size()):
		var allocation = state.spending_private_inputs[player_id]
		var chosen_option = allocation.get("option", "A")
		var spent_amount = allocation.get("amount", 0)
		if chosen_option == "A":
			total_a += spent_amount
		else:
			total_b += spent_amount
		# unspent gold remains in the player's purse for future rounds
		state.players[player_id].money = max(state.players[player_id].money - spent_amount, 0)
	state.spending_option_a_total = total_a
	state.spending_option_b_total = total_b
	print("Money vote totals A:%d B:%d" % [total_a, total_b])
	if total_a >= total_b:
		state.spending_winner = "A"
		apply_benefit(state.policy_enacted.option_a_beneficiary, state.policy_enacted.option_a_gold_amount)
	else:
		state.spending_winner = "B"
		apply_benefit(state.policy_enacted.option_b_beneficiary, state.policy_enacted.option_b_gold_amount)
	state.spending_stage = "resolved"
	check_win_condition()

func check_win_condition() -> void:
	if _game_over_handled:
		return
	if state.influence_patrician >= influence_to_win:
		state.game_phase = "game_over"
		last_winner_text = "Patricians"
		last_patrician_influence = state.influence_patrician
		last_plebian_influence = state.influence_plebian
		last_round_number = state.round_number
		_game_over_handled = true
		print("Patricians win! Influence reached %d" % state.influence_patrician)
		get_tree().change_scene_to_file("res://scenes/ui/end_game.tscn")
	elif state.influence_plebian >= influence_to_win:
		state.game_phase = "game_over"
		last_winner_text = "Plebeians"
		last_patrician_influence = state.influence_patrician
		last_plebian_influence = state.influence_plebian
		last_round_number = state.round_number
		_game_over_handled = true
		print("Plebeians win! Influence reached %d" % state.influence_plebian)
		get_tree().change_scene_to_file("res://scenes/ui/end_game.tscn")

func apply_benefit(faction: int, amount: int) -> void:
	for pl in state.players:
		if pl.role == faction and not (faction == Role.PATRICIAN and pl.role == Role.CAESAR):
			pl.money += amount
	print("Applied benefit %d gold to faction %d" % [amount, faction])

func progress():
	match state.game_phase:
		"init":
			start_round()
			state.game_phase = "election"
		"election":
			if state.election_nominee_index < 0:
				auto_select_ai_nominee()
			if state.election_nominee_index < 0:
				print("Select a co-consul nominee first")
				return
			if not are_election_votes_complete():
				auto_fill_ai_election_votes()
			if not are_election_votes_complete():
				print("Set all election votes first")
				return
			if conduct_election():
				state.game_phase = "policy"
				start_policy_phase()
			else:
				state.game_phase = "round_end"
		"policy":
			if state.policy_enacted == null:
				print("Complete policy discards first")
				return
			state.game_phase = "spending"
			start_spending_phase()
		"spending":
			if state.spending_stage != "resolved":
				auto_run_ai_spending_inputs()
			if state.spending_stage != "resolved":
				print("Complete private spending for all players first")
				return
			state.game_phase = "round_end"
		"round_end":
			next_consul()
			start_round()
		"game_over":
			print("Game is over!")
		_:
			print("Unknown phase: %s" % state.game_phase)
