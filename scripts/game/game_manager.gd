extends Node

# main orchestrator for the prototype

# preload data classes so enums/types are available
const Role = preload("res://scripts/data/role.gd").Role
const Player = preload("res://scripts/data/player.gd")
const Policy = preload("res://scripts/data/policy.gd")
const GameState = preload("res://scripts/data/game_state.gd")

@onready var state: GameState = GameState.new()
var pending_policy_choices: Array = []
var policy_discard_stage: String = ""

func role_name(role: int) -> String:
	match role:
		Role.CAESAR:
			return "Caesar"
		Role.PATRICIAN:
			return "Patrician"
		Role.PLEBIAN:
			return "Plebian"
		_:
			return "Unknown"
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
	# simple distribution: 1 Caesar, 2 Patricians, 3 Plebians
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
	if yes >= 1:
		state.election_passed = true
		print("Election passed, player %d is co-consul" % nominee)
		state.current_co_consul_index = nominee
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
		state.spending_private_inputs.append({"a": 0, "b": 0})
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

func set_spending_allocation(option_a_amount: int) -> bool:
	if state.game_phase != "spending" or state.spending_stage != "input":
		return false
	var player_id = state.spending_input_player_index
	if player_id < 0 or player_id >= state.players.size():
		return false
	var total_money = state.players[player_id].money
	if option_a_amount < 0 or option_a_amount > total_money:
		return false
	var option_b_amount = total_money - option_a_amount
	state.spending_private_inputs[player_id] = {"a": option_a_amount, "b": option_b_amount}
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
		var split = state.spending_private_inputs[player_id]
		total_a += split.get("a", 0)
		total_b += split.get("b", 0)
		state.players[player_id].money = 0
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
	if state.influence_patrician >= 5:
		state.game_phase = "game_over"
		print("Patricians win! Influence reached %d" % state.influence_patrician)
	elif state.influence_plebian >= 5:
		state.game_phase = "game_over"
		print("Plebians win! Influence reached %d" % state.influence_plebian)

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
				print("Select a co-consul nominee first")
				return
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
