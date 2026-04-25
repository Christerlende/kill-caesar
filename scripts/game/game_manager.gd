extends Node

# main orchestrator for the prototype

# preload data classes so enums/types are available
const Role = preload("res://scripts/data/role.gd").Role
const Player = preload("res://scripts/data/player.gd")
const Policy = preload("res://scripts/data/policy.gd")
const GameState = preload("res://scripts/data/game_state.gd")
const AssassinationToken = preload("res://scripts/data/assassination_token.gd")
static var influence_to_win: int = 7
const TAX_FREE_THRESHOLD: int = 32
const TAX_SLOPE_DIVISOR: float = 2.0
static var queued_player_roles: Array = []
static var queued_player_names: Array = []
static var last_winner_text: String = ""
static var last_patrician_influence: int = 0
static var last_plebian_influence: int = 0
static var last_round_number: int = 0
static var last_player_roles: Array = []  # [{player_id, role, role_name}]
## Faction whose 7-influence win was overridden by a simultaneous Caesar victory.
## Empty string when Caesar won without an override, or when a faction won outright.
static var last_caesar_override_faction: String = ""
## Full per-player snapshot for the end-game reveal: player_id, role, role_name, display_name, money,
## available_assassination_tokens, co_consul_count, is_dead.
static var last_player_snapshots: Array = []
const MAX_ASSASSINATION_TOKENS_PER_PLAYER: int = 1
const CAESAR_POLICIES_TO_WIN: int = 3

# Greed punishments (treasury failure)
const GREED_ROME_BURNS: int = 0
const GREED_ASSASSINS_DOOR: int = 1
const GREED_HEAVY_TAXES: int = 2
const GREED_PENDULUM: int = 3
const GREED_CAESAR_STEPS: int = 4
const GREED_KNIVES_OUT: int = 5
## Max total gold on both decrees before Chaos (failure when total_spent <= T). Min spend to avoid = T+1 per row.
const GREED_THRESHOLDS: Array = [0, 1, 2, 5, 7]
## Five treasury failures end the game (collapse before the count would reach 5).
const GREED_CHAOS_SLOT_COUNT: int = 5
const GREED_COLLAPSE_WINNER: String = "collapse"
const GREED_ENTER_DELAY_SEC: float = 2.0

# Deadlock events (equal spending totals, unless Greed triggers)
const DEADLOCK_ASSASSINS_ROOFTOPS: int = 0
const DEADLOCK_SECRET_LOBBY_PAYOUT: int = 1
const DEADLOCK_COSTLY_LOBBYING: int = 2
const DEADLOCK_ASSASSINS_HUNT: int = 3

# Influence awards
const AWARD_NONE: int = -1
const AWARD_PLEBEIAN_2_ROLE_PEEK: int = 0
const AWARD_PLEBEIAN_4_TWO_ROLE_PEEK: int = 1
const AWARD_PLEBEIAN_6_AUTO_ELECTION: int = 2
const AWARD_PATRICIAN_2_DOUBLE_DISCARD: int = 3
const AWARD_PATRICIAN_4_ROLE_PEEK: int = 4
const AWARD_PATRICIAN_6_EXECUTION: int = 5
const AWARD_THRESHOLDS: Array = [2, 4, 6]

@onready var state: GameState = GameState.new()
var pending_policy_choices: Array = []
var _discarded_policy_objects: Array = []
var policy_discard_stage: String = ""
var _game_over_handled: bool = false
var _patrician_double_discard_active: bool = false

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

func get_player_name(player_id: int) -> String:
	if player_id < 0 or player_id >= state.players.size():
		return "Player %d" % (player_id + 1)
	var player = state.players[player_id]
	var chosen_name = str(player.display_name).strip_edges()
	if chosen_name == "":
		return "Player %d" % (player.player_id + 1)
	return chosen_name

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

static func queue_player_roles(roles: Array) -> void:
	queued_player_roles = roles.duplicate()

static func queue_player_names(names: Array) -> void:
	queued_player_names = names.duplicate()

func _required_yes_votes() -> int:
	# Simple majority of living players: floor(n/2) + 1
	var living_players = 0
	for player in state.players:
		if not player.is_dead:
			living_players += 1
	return int(floor(living_players / 2.0)) + 1

func _find_next_living_player(start_index: int) -> int:
	if state.players.is_empty():
		return -1
	for offset in range(state.players.size()):
		var candidate_index = (start_index + offset) % state.players.size()
		if not state.players[candidate_index].is_dead:
			return candidate_index
	return -1

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
	var a_amount = state.policy_enacted.option_a_effect_params.get("amount", 0)
	var b_amount = state.policy_enacted.option_b_effect_params.get("amount", 0)
	if b_score > a_score or (b_score == a_score and b_amount > a_amount):
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
	randomize()
	create_players()
	state.all_policies = Policy.load_all_policies()
	state.all_policies.shuffle()
	state.game_phase = "init"
	start_round()

func create_players():
	_game_over_handled = false
	_patrician_double_discard_active = false
	last_winner_text = ""
	last_caesar_override_faction = ""
	last_player_snapshots.clear()
	state.patrician_award_thresholds_triggered.clear()
	state.plebeian_award_thresholds_triggered.clear()
	state.pending_post_result_awards.clear()
	state.pending_patrician_double_discard = false
	state.pending_plebeian_auto_election = false
	state.current_award_id = AWARD_NONE
	state.auto_election_award_active = false
	state.players.clear()
	for i in range(6):
		var p = Player.new()
		p.player_id = i
		p.display_name = "Player %d" % (i + 1)
		p.is_ai = true
		state.players.append(p)
	_apply_queued_player_names()
	assign_roles()

func assign_roles():
	var roles: Array = []
	if _has_valid_queued_roles():
		roles = queued_player_roles.duplicate()
	else:
		# simple distribution: 1 Caesar, 2 Patricians, 3 Plebeians
		roles = [Role.CAESAR] + [Role.PATRICIAN, Role.PATRICIAN] + [Role.PLEBIAN, Role.PLEBIAN, Role.PLEBIAN]
		roles.shuffle()
	for i in range(state.players.size()):
		state.players[i].role = roles[i]
		state.players[i].money = 0
		state.players[i].caesar_plot_marks = 0
	queued_player_roles.clear()

func _has_valid_queued_roles() -> bool:
	if queued_player_roles.size() != state.players.size():
		return false
	var caesar_count = 0
	var patrician_count = 0
	var plebeian_count = 0
	for role in queued_player_roles:
		match role:
			Role.CAESAR:
				caesar_count += 1
			Role.PATRICIAN:
				patrician_count += 1
			Role.PLEBIAN:
				plebeian_count += 1
			_:
				return false
	return caesar_count == 1 and patrician_count == 2 and plebeian_count == 3

func _has_valid_queued_names() -> bool:
	return queued_player_names.size() == state.players.size()

func _apply_queued_player_names() -> void:
	if not _has_valid_queued_names():
		queued_player_names.clear()
		return
	for i in range(state.players.size()):
		var chosen_name = str(queued_player_names[i]).strip_edges()
		state.players[i].display_name = chosen_name if chosen_name != "" else ("Player %d" % (i + 1))
	queued_player_names.clear()

func start_round():
	state.round_number += 1
	print("Starting round %d" % state.round_number)
	distribute_money()
	## Decrement after income so GREED_HEAVY_TAXES "3 rounds" means three distributions at the reduced threshold.
	if state.greed_tax_rounds_remaining > 0:
		state.greed_tax_rounds_remaining -= 1
		if state.greed_tax_rounds_remaining <= 0:
			state.greed_tax_threshold_override = 0
	reset_assassination_token_round_flags()
	# make sure consul index is valid
	state.current_consul_index = state.current_consul_index % state.players.size()
	var living_consul_index = _find_next_living_player(state.current_consul_index)
	if living_consul_index >= 0:
		state.current_consul_index = living_consul_index
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
	state.auto_election_award_active = false
	# Intentionally keep ineligible_co_consul_indices across rounds.
	# It is only refreshed after a successful election.
	state.election_vote_inputs.clear()
	for i in range(state.players.size()):
		state.election_vote_inputs.append(0 if state.players[i].is_dead else -1)
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
	state.game_phase = "round_start"
	print_current_consul()

func _base_income_for_role(role: int) -> int:
	match role:
		Role.CAESAR:
			return 8
		Role.PATRICIAN:
			return 6
		Role.PLEBIAN:
			return 4
		_:
			return 0

func _effective_tax_free_threshold() -> int:
	var t = TAX_FREE_THRESHOLD
	if state.greed_tax_rounds_remaining > 0 and state.greed_tax_threshold_override > 0:
		t = min(t, state.greed_tax_threshold_override)
	return t

func _calculate_income_tax(current_money: int, base_income: int) -> int:
	if base_income <= 0:
		return 0
	var threshold = _effective_tax_free_threshold()
	var excess = max(current_money - threshold, 0)
	if excess <= 0:
		return 0
	var tax_due = int(ceil(float(excess) / TAX_SLOPE_DIVISOR))
	return min(tax_due, base_income)

func get_role_base_income(role: int) -> int:
	return _base_income_for_role(role)

func get_income_tax_for_purse(role: int, current_money: int) -> int:
	var base_income = _base_income_for_role(role)
	return _calculate_income_tax(current_money, base_income)

func get_tax_free_threshold() -> int:
	return _effective_tax_free_threshold()

func get_greed_treasury_threshold() -> int:
	return GREED_THRESHOLDS[clamp(state.greed_events_completed, 0, 4)]

func get_greed_min_collective_spend() -> int:
	return get_greed_treasury_threshold() + 1

func get_greed_chaos_slot_count() -> int:
	return GREED_CHAOS_SLOT_COUNT

func distribute_money():
	for p in state.players:
		# Dead players don't earn gold
		if p.is_dead:
			continue
		var base_income = _base_income_for_role(p.role)
		var tax_due = _calculate_income_tax(p.money, base_income)
		var net_income = max(base_income - tax_due, 0)
		p.money += net_income

func print_current_consul():
	var p = state.players[state.current_consul_index]
	print("Consul is player %d (%s)" % [p.player_id + 1, role_name(p.role)])
	print("Current phase: %s" % state.game_phase)

func next_consul():
	var next_index = _find_next_living_player(state.current_consul_index + 1)
	if next_index >= 0:
		state.current_consul_index = next_index
	# update runtime flags
	for p in state.players:
		p.is_consul = false
		p.is_co_consul = false
	state.players[state.current_consul_index].is_consul = true
	state.game_phase = "round_start"
	print_current_consul()

# --- new functionality added below ---

func get_nominee_candidates() -> Array:
	var candidates = []
	for i in range(state.players.size()):
		if i != state.current_consul_index and not state.ineligible_co_consul_indices.has(i) and not state.players[i].is_dead:
			candidates.append(i)
	return candidates

func select_election_nominee(nominee_index: int) -> bool:
	if state.game_phase != "election":
		return false
	if nominee_index < 0 or nominee_index >= state.players.size():
		return false
	if state.players[nominee_index].is_dead:
		return false
	if not get_nominee_candidates().has(nominee_index):
		return false
	state.election_nominee_index = nominee_index
	state.election_votes_yes.clear()
	state.election_votes_no.clear()
	for i in range(state.election_vote_inputs.size()):
		state.election_vote_inputs[i] = 0 if state.players[i].is_dead else -1
	print("Consul selected nominee player %d" % (nominee_index + 1))
	if state.pending_plebeian_auto_election:
		state.pending_plebeian_auto_election = false
		state.auto_election_award_active = true
		state.election_votes_yes.clear()
		state.election_votes_no.clear()
		for i in range(state.election_vote_inputs.size()):
			state.election_vote_inputs[i] = 0 if state.players[i].is_dead else 1
			if not state.players[i].is_dead:
				state.election_votes_yes.append(i)
		_complete_successful_election(nominee_index)
		print("Plebeian influence award: nominee auto-elected as co-consul.")
	return true

func set_election_vote(player_id: int, is_yes: bool) -> bool:
	if state.game_phase != "election":
		return false
	if state.election_nominee_index < 0:
		return false
	if player_id < 0 or player_id >= state.players.size():
		return false
	if state.players[player_id].is_dead:
		print("Dead player %d cannot vote" % (player_id + 1))
		return false
	state.election_vote_inputs[player_id] = 1 if is_yes else 0
	return true

func are_election_votes_complete() -> bool:
	if state.election_vote_inputs.size() != state.players.size():
		return false
	for i in range(state.election_vote_inputs.size()):
		if state.players[i].is_dead:
			continue
		if state.election_vote_inputs[i] == -1:
			return false
	return true

func conduct_election() -> bool:
	if state.election_nominee_index < 0:
		print("No nominee selected yet")
		return false
	if state.election_votes_yes.size() > 0 or state.election_votes_no.size() > 0:
		return state.election_passed
	var nominee = state.election_nominee_index
	print("Consul nominates player %d" % nominee)
	state.election_votes_yes.clear()
	state.election_votes_no.clear()
	if not are_election_votes_complete():
		print("Not all votes are set yet")
		return false
	for player_id in range(state.election_vote_inputs.size()):
		if state.players[player_id].is_dead:
			continue
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
		_complete_successful_election(nominee)
		return true
	else:
		state.election_passed = false
		print("Election failed")
		return false

func _complete_successful_election(nominee: int) -> void:
	state.election_passed = true
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

func start_policy_phase() -> void:
	pending_policy_choices.clear()
	_discarded_policy_objects.clear()
	_patrician_double_discard_active = false
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
		# No discard choices needed — skip straight to spending
		state.game_phase = "spending"
		start_spending_phase()
		return
	if state.pending_patrician_double_discard:
		state.pending_patrician_double_discard = false
		_patrician_double_discard_active = true
	policy_discard_stage = "consul"
	print("Policy phase started. Drawn policy IDs:", state.policy_drawn_ids)

func get_policy_discard_candidates() -> Array:
	var ids = []
	for p in pending_policy_choices:
		ids.append(p.id)
	return ids

func get_policy_discard_stage() -> String:
	return policy_discard_stage

func is_patrician_double_discard_active() -> bool:
	return _patrician_double_discard_active

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
	# Save the discarded policy object so it can be returned to the deck
	_discarded_policy_objects.append(pending_policy_choices[found_index])
	pending_policy_choices.remove_at(found_index)
	if pending_policy_choices.size() <= 1:
		enact_remaining_policy()
		return true
	if policy_discard_stage == "consul":
		if _patrician_double_discard_active:
			print("Patrician influence award: consul discarded policy %d and must discard again." % policy_id)
			return true
		policy_discard_stage = "co_consul"
		print("Consul discarded policy %d. Co-consul must discard next." % policy_id)
	return true

func enact_remaining_policy() -> void:
	if pending_policy_choices.size() == 0:
		policy_discard_stage = ""
		return
	state.policy_enacted = pending_policy_choices[0]
	# Intentionally do NOT return the enacted policy to the deck.
	# Enacted policies are removed from the game permanently.
	pending_policy_choices.clear()
	policy_discard_stage = "done"
	_patrician_double_discard_active = false
	# Return discarded policies to the deck and shuffle
	for p in _discarded_policy_objects:
		state.all_policies.append(p)
	_discarded_policy_objects.clear()
	state.all_policies.shuffle()
	print("Final enacted policy %d (returned %d policies to deck)" % [state.policy_enacted.id, state.policy_discarded_ids.size()])

func start_spending_phase() -> void:
	if state.policy_enacted == null:
		return
	state.spending_option_a_total = 0
	state.spending_option_b_total = 0
	state.spending_winner = ""
	state.deadlock_round = false
	state.last_deadlock_effect_id = -1
	state.spending_private_inputs.clear()
	state.spending_confirmed_players.clear()
	for i in range(state.players.size()):
		state.spending_private_inputs.append({"option": "A", "amount": 0})
		# Dead players are auto-confirmed and skipped
		state.spending_confirmed_players.append(state.players[i].is_dead)
	# Find first alive player to input
	state.spending_input_player_index = 0
	while state.spending_input_player_index < state.players.size() and state.spending_confirmed_players[state.spending_input_player_index]:
		state.spending_input_player_index += 1
	if state.spending_input_player_index >= state.players.size():
		resolve_spending_totals()
		return
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
	if state.players[player_id].is_dead:
		return false
	if option_key != "A" and option_key != "B":
		return false
	var total_money = state.players[player_id].money
	if spend_amount < 0 or spend_amount > total_money:
		return false
	state.spending_private_inputs[player_id] = {"option": option_key, "amount": spend_amount}
	state.spending_confirmed_players[player_id] = true
	# Auto-advance to the next player (or resolve totals) to avoid extra handoff clicks.
	var next_player = state.spending_input_player_index + 1
	while next_player < state.players.size() and state.spending_confirmed_players[next_player]:
		next_player += 1
	if next_player >= state.players.size():
		resolve_spending_totals()
	else:
		state.spending_input_player_index = next_player
		state.spending_stage = "input"
	print("Player %d spending captured privately." % player_id)
	return true

func advance_spending_turn() -> bool:
	if state.game_phase != "spending" or state.spending_stage != "handoff":
		return false
	var next_player = state.spending_input_player_index + 1
	# Skip dead players
	while next_player < state.players.size() and (state.spending_confirmed_players[next_player] or state.players[next_player].is_dead):
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
	state.greed_round = false
	state.deadlock_round = false
	state.last_deadlock_effect_id = -1
	var total_spent = total_a + total_b
	var greed_T = GREED_THRESHOLDS[clamp(state.greed_events_completed, 0, 4)]
	if total_spent <= greed_T:
		## Fifth treasury failure: four Chaos rounds already completed; next failure ends Rome.
		if state.greed_events_completed >= 4:
			_trigger_rome_collapse()
			state.spending_winner = ""
			state.spending_stage = "resolved"
			return
		state.greed_round = true
		state.spending_winner = ""
	else:
		if total_a == total_b:
			state.deadlock_round = true
			state.spending_winner = "D"
			state.last_deadlock_effect_id = roll_deadlock_effect_id()
			apply_deadlock_effect(state.last_deadlock_effect_id)
		elif total_a > total_b:
			state.spending_winner = "A"
		else:
			state.spending_winner = "B"
	state.spending_stage = "resolved"
	if state.greed_round:
		_schedule_enter_greed_after_delay()

func _schedule_enter_greed_after_delay() -> void:
	if not is_inside_tree():
		return
	get_tree().create_timer(GREED_ENTER_DELAY_SEC).timeout.connect(_on_greed_enter_delay_timeout)

func _on_greed_enter_delay_timeout() -> void:
	enter_greed_screen()

func _trigger_rome_collapse() -> void:
	state.game_phase = "game_over"
	last_winner_text = GREED_COLLAPSE_WINNER
	last_caesar_override_faction = ""
	last_patrician_influence = state.influence_patrician
	last_plebian_influence = state.influence_plebian
	last_round_number = state.round_number
	_store_player_roles()
	_game_over_handled = true
	print("Rome collapses — fifth treasury failure.")

func enter_greed_screen() -> void:
	if state.game_phase != "spending" or not state.greed_round:
		return
	state.last_greed_punishment_id = roll_greed_punishment_id()
	state.game_phase = "greed"

func finish_greed_sequence() -> void:
	if state.game_phase != "greed":
		return
	state.greed_events_completed += 1
	state.game_phase = "result"
	_record_round_history()
	# Defer so ResultPanel._process runs this frame while phase is still "result" (e.g. GREED_PENDULUM
	# can hit the win threshold; sync check_win would flip to game_over before the fade tween starts).
	call_deferred("check_win_condition")

func roll_greed_punishment_id() -> int:
	var pool: Array = []
	for id in range(6):
		if id == GREED_PENDULUM and state.influence_patrician == state.influence_plebian:
			continue
		var w = 0.25 if id == GREED_KNIVES_OUT else 1.0
		pool.append({"id": id, "w": w})
	if pool.is_empty():
		return GREED_ROME_BURNS
	var sum_w = 0.0
	for p in pool:
		sum_w += p.w
	var r = randf() * sum_w
	for p in pool:
		r -= p.w
		if r <= 0.0:
			return p.id
	return pool[pool.size() - 1].id

func apply_greed_punishment(punishment_id: int) -> void:
	match punishment_id:
		GREED_ROME_BURNS:
			for pl in state.players:
				if pl.is_dead:
					continue
				var loss = int(ceil(pl.money / 2.0))
				pl.money = max(pl.money - loss, 0)
			print("Greed: Rome burns — halved purses (rounded up loss).")
		GREED_ASSASSINS_DOOR:
			_greed_grant_two_distinct_random_tokens()
			print("Greed: Assassins at the door.")
		GREED_HEAVY_TAXES:
			state.greed_tax_threshold_override = 20
			state.greed_tax_rounds_remaining = 3
			print("Greed: Heavy taxes for 3 rounds (threshold 20).")
		GREED_PENDULUM:
			if state.influence_patrician < state.influence_plebian:
				var before_patrician = state.influence_patrician
				state.influence_patrician += 2
				_queue_awards_for_influence_gain(Role.PATRICIAN, before_patrician, state.influence_patrician)
			elif state.influence_plebian < state.influence_patrician:
				var before_plebeian = state.influence_plebian
				state.influence_plebian += 2
				_queue_awards_for_influence_gain(Role.PLEBIAN, before_plebeian, state.influence_plebian)
			print("Greed: The pendulum swings.")
		GREED_CAESAR_STEPS:
			for pl in state.players:
				if pl.is_dead:
					continue
				if pl.role == Role.CAESAR:
					if pl.caesar_plot_marks >= 2:
						print("Greed: Caesar steps forth — no effect (already two plot marks).")
					else:
						pl.money += 15
						pl.caesar_plot_marks += 1
						print("Greed: Caesar steps forth.")
					break
		GREED_KNIVES_OUT:
			for pl in state.players:
				if pl.is_dead:
					continue
				if pl.available_assassination_tokens < MAX_ASSASSINATION_TOKENS_PER_PLAYER:
					pl.available_assassination_tokens = min(
						pl.available_assassination_tokens + 1,
						MAX_ASSASSINATION_TOKENS_PER_PLAYER
					)
			print("Greed: Knives out.")
		_:
			push_warning("Unknown greed punishment: %d" % punishment_id)

func roll_deadlock_effect_id() -> int:
	return randi_range(0, 3)

func apply_deadlock_effect(effect_id: int) -> void:
	match effect_id:
		DEADLOCK_ASSASSINS_ROOFTOPS:
			_deadlock_grant_random_assassination_token_if_possible()
			print("Deadlock: Assassins take to the rooftops.")
		DEADLOCK_SECRET_LOBBY_PAYOUT:
			_deadlock_grant_secret_lobby_payout()
			print("Deadlock: A secret lobbying deal changes hands.")
		DEADLOCK_COSTLY_LOBBYING:
			_deadlock_tax_two_random_players()
			print("Deadlock: Costly lobbying drains purses.")
		DEADLOCK_ASSASSINS_HUNT:
			_deadlock_add_hunt_token()
			print("Deadlock: Assassins hunt in the dark.")
		_:
			push_warning("Unknown deadlock effect: %d" % effect_id)

func _deadlock_grant_random_assassination_token_if_possible() -> void:
	var pool: Array = []
	for i in range(state.players.size()):
		var p = state.players[i]
		if not p.is_dead and p.available_assassination_tokens < MAX_ASSASSINATION_TOKENS_PER_PLAYER:
			pool.append(i)
	if pool.is_empty():
		return
	var player_id = pool[randi() % pool.size()]
	_grant_assassination_token_to_player_id(player_id)

func _deadlock_grant_secret_lobby_payout() -> void:
	var alive_ids: Array = []
	for i in range(state.players.size()):
		if not state.players[i].is_dead:
			alive_ids.append(i)
	if alive_ids.is_empty():
		return
	var player_id = alive_ids[randi() % alive_ids.size()]
	state.players[player_id].money += 10

func _deadlock_tax_two_random_players() -> void:
	var alive_ids: Array = []
	for i in range(state.players.size()):
		if not state.players[i].is_dead:
			alive_ids.append(i)
	alive_ids.shuffle()
	var affected = min(2, alive_ids.size())
	for i in range(affected):
		var player_id = alive_ids[i]
		state.players[player_id].money = max(state.players[player_id].money - 5, 0)

func _deadlock_add_hunt_token() -> void:
	var alive_ids: Array = []
	for i in range(state.players.size()):
		if not state.players[i].is_dead:
			alive_ids.append(i)
	if alive_ids.is_empty():
		return
	var target_id = alive_ids[randi() % alive_ids.size()]
	var token = AssassinationToken.new()
	token.attacker_id = -1
	token.target_id = target_id
	token.rounds_left = 3
	token.placed_this_round = true
	state.active_assassination_tokens.append(token)

func _grant_assassination_token_to_player_id(player_id: int) -> bool:
	if player_id < 0 or player_id >= state.players.size():
		return false
	var p = state.players[player_id]
	if p.is_dead or p.available_assassination_tokens >= MAX_ASSASSINATION_TOKENS_PER_PLAYER:
		return false
	p.available_assassination_tokens = min(
		p.available_assassination_tokens + 1,
		MAX_ASSASSINATION_TOKENS_PER_PLAYER
	)
	return true

func _greed_grant_two_distinct_random_tokens() -> void:
	var pool: Array = []
	for i in range(state.players.size()):
		if not state.players[i].is_dead and state.players[i].available_assassination_tokens < MAX_ASSASSINATION_TOKENS_PER_PLAYER:
			pool.append(i)
	pool.shuffle()
	if pool.size() >= 1:
		_grant_assassination_token_to_player_id(pool[0])
	if pool.size() >= 2:
		_grant_assassination_token_to_player_id(pool[1])

func _get_living_caesar():
	for p in state.players:
		if p.role == Role.CAESAR and not p.is_dead:
			return p
	return null

func check_win_condition() -> void:
	if _game_over_handled:
		return
	var pat_won: bool = state.influence_patrician >= influence_to_win
	var pleb_won: bool = state.influence_plebian >= influence_to_win
	var caesar = _get_living_caesar()
	var caesar_count: int = caesar.co_consul_count if caesar != null else -1
	var caesar_wins: bool = caesar != null and caesar_count >= CAESAR_POLICIES_TO_WIN

	if caesar_wins:
		state.game_phase = "game_over"
		last_winner_text = "Caesar"
		last_caesar_override_faction = ""
		if pat_won and pleb_won:
			## Tie-break: whichever faction had the higher influence total "claimed" victory first.
			if state.influence_patrician >= state.influence_plebian:
				last_caesar_override_faction = "Patricians"
			else:
				last_caesar_override_faction = "Plebeians"
		elif pat_won:
			last_caesar_override_faction = "Patricians"
		elif pleb_won:
			last_caesar_override_faction = "Plebeians"
		last_patrician_influence = state.influence_patrician
		last_plebian_influence = state.influence_plebian
		last_round_number = state.round_number
		_store_player_roles()
		_game_over_handled = true
		if last_caesar_override_faction != "":
			print("Caesar seizes power at the eleventh hour — overriding %s victory." % last_caesar_override_faction)
		else:
			print("Caesar wins! Three policies enacted under his co-consulship.")
	elif pat_won:
		state.game_phase = "game_over"
		last_winner_text = "Patricians"
		last_caesar_override_faction = ""
		last_patrician_influence = state.influence_patrician
		last_plebian_influence = state.influence_plebian
		last_round_number = state.round_number
		_store_player_roles()
		_game_over_handled = true
		print("Patricians win! Influence reached %d" % state.influence_patrician)
	elif pleb_won:
		state.game_phase = "game_over"
		last_winner_text = "Plebeians"
		last_caesar_override_faction = ""
		last_patrician_influence = state.influence_patrician
		last_plebian_influence = state.influence_plebian
		last_round_number = state.round_number
		_store_player_roles()
		_game_over_handled = true
		print("Plebeians win! Influence reached %d" % state.influence_plebian)

func _store_player_roles() -> void:
	last_player_roles.clear()
	last_player_snapshots.clear()
	for p in state.players:
		last_player_roles.append({
			"player_id": p.player_id,
			"role": p.role,
			"role_name": role_name(p.role),
		})
		last_player_snapshots.append({
			"player_id": p.player_id,
			"role": p.role,
			"role_name": role_name(p.role),
			"display_name": get_player_name(p.player_id),
			"money": p.money,
			"available_assassination_tokens": p.available_assassination_tokens,
			"co_consul_count": p.co_consul_count,
			"is_dead": p.is_dead,
		})

func apply_enacted_decree_effect(policy: Policy, option_key: String) -> void:
	if policy == null:
		return
	var effect_type: String
	var params: Dictionary
	if option_key == "A":
		effect_type = policy.option_a_effect_type
		params = policy.option_a_effect_params
	else:
		effect_type = policy.option_b_effect_type
		params = policy.option_b_effect_params
	_apply_effect(effect_type, params)

func _apply_effect(effect_type: String, params: Dictionary) -> void:
	match effect_type:
		"gold_by_role":
			var role = Policy.role_from_string(str(params.get("role", "plebeian")))
			apply_benefit(role, int(params.get("amount", 0)))
		"grant_assassination_token":
			var target_role = Policy.role_from_string(str(params.get("target_role", "plebeian")))
			_grant_random_assassination_token(target_role)
		"tax_all":
			collect_public_repair_contribution(int(params.get("amount", 0)))
		"multi":
			for sub_effect in params.get("effects", []):
				_apply_effect(sub_effect.get("effect_type", ""), sub_effect.get("params", {}))
		_:
			push_warning("Unknown effect type: %s" % effect_type)

func apply_benefit(faction: int, amount: int) -> void:
	for pl in state.players:
		if pl.role == faction and not pl.is_dead:
			pl.money += amount
	print("Applied benefit %d gold to members of faction %d" % [amount, faction])

func _grant_random_assassination_token(target_role: int) -> void:
	var candidates: Array = []
	for i in range(state.players.size()):
		var player = state.players[i]
		if player.role == target_role and not player.is_dead and player.available_assassination_tokens < MAX_ASSASSINATION_TOKENS_PER_PLAYER:
			candidates.append(i)
	if candidates.is_empty():
		print("No eligible player of role %d can receive an assassination token" % target_role)
		return
	var target_player_id = candidates[randi() % candidates.size()]
	state.players[target_player_id].available_assassination_tokens = min(
		state.players[target_player_id].available_assassination_tokens + 1,
		MAX_ASSASSINATION_TOKENS_PER_PLAYER
	)
	print("Granted assassination token to Player %d" % (target_player_id + 1))

func collect_public_repair_contribution(amount: int) -> void:
	for player in state.players:
		if player.is_dead:
			continue
		player.money = max(player.money - amount, 0)
	print("Collected %d gold from each player for public contribution" % amount)

func apply_policy_influence(policy: Policy) -> void:
	if policy == null:
		return
	if policy.faction == Role.PATRICIAN:
		var before_patrician = state.influence_patrician
		state.influence_patrician += 1
		_queue_awards_for_influence_gain(Role.PATRICIAN, before_patrician, state.influence_patrician)
	else:
		var before_plebeian = state.influence_plebian
		state.influence_plebian += 1
		_queue_awards_for_influence_gain(Role.PLEBIAN, before_plebeian, state.influence_plebian)
	print("Applied influence for policy %d (faction %d)" % [policy.id, policy.faction])

func _queue_awards_for_influence_gain(faction: int, previous_value: int, current_value: int) -> void:
	var triggered = state.patrician_award_thresholds_triggered if faction == Role.PATRICIAN else state.plebeian_award_thresholds_triggered
	var highest_new_threshold = -1
	for threshold in AWARD_THRESHOLDS:
		if threshold > previous_value and threshold <= current_value and not triggered.has(threshold):
			highest_new_threshold = max(highest_new_threshold, threshold)
	if highest_new_threshold < 0:
		return
	for threshold in AWARD_THRESHOLDS:
		if threshold <= current_value and not triggered.has(threshold):
			triggered.append(threshold)
	_queue_influence_award(faction, highest_new_threshold)

func _queue_influence_award(faction: int, threshold: int) -> void:
	if faction == Role.PLEBIAN:
		match threshold:
			2:
				state.pending_post_result_awards.append(AWARD_PLEBEIAN_2_ROLE_PEEK)
			4:
				state.pending_post_result_awards.append(AWARD_PLEBEIAN_4_TWO_ROLE_PEEK)
			6:
				state.pending_plebeian_auto_election = true
	else:
		match threshold:
			2:
				state.pending_patrician_double_discard = true
			4:
				state.pending_post_result_awards.append(AWARD_PATRICIAN_4_ROLE_PEEK)
			6:
				state.pending_post_result_awards.append(AWARD_PATRICIAN_6_EXECUTION)
	print("Queued influence award for faction %d at %d influence." % [faction, threshold])

func _record_round_history() -> void:
	var consul_name = get_player_name(state.current_consul_index)
	var co_consul_name = get_player_name(state.current_co_consul_index) if state.current_co_consul_index >= 0 else "None"
	var chaos = state.greed_round
	var deadlock = state.deadlock_round
	var faction = "Draw" if deadlock else ("Chaos" if chaos else ("Plebeian" if state.policy_enacted != null and state.policy_enacted.faction == Role.PLEBIAN else "Patrician"))
	var entry = {
		"round_number": state.round_number,
		"faction": faction,
		"chaos": chaos,
		"deadlock": deadlock,
		"consul_name": consul_name,
		"co_consul_name": co_consul_name,
	}
	state.round_history.push_front(entry)

func progress():
	# Global guard: never advance if game is already over
	if _game_over_handled:
		return
	match state.game_phase:
		"init":
			start_round()
		"round_start":
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
			var election_passed = state.election_passed if (state.election_votes_yes.size() > 0 or state.election_votes_no.size() > 0) else conduct_election()
			if election_passed:
				state.auto_election_award_active = false
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
			if state.greed_round:
				return
			state.game_phase = "result"
			_record_round_history()
		"greed":
			return
		"result":
			# Effects are now applied by the result panel during fade-in animations.
			# Apply assassination tokens (check for deaths), then advance.
			apply_assassination_tokens()
			check_win_condition()
			if state.game_phase != "game_over":
				state.greed_round = false
				state.deadlock_round = false
				if state.pending_post_result_awards.size() > 0:
					state.current_award_id = state.pending_post_result_awards.pop_front()
					state.game_phase = "award"
				else:
					state.game_phase = "round_end"
		"award":
			return
		"round_end":
			process_assassination_tokens_end_of_round()
			next_consul()
			start_round()
		"game_over":
			print("Game is over!")
		_:
			print("Unknown phase: %s" % state.game_phase)

func get_current_award_id() -> int:
	return state.current_award_id

func award_peek_role(player_id: int) -> int:
	if state.game_phase != "award":
		return -1
	if player_id < 0 or player_id >= state.players.size():
		return -1
	if state.players[player_id].is_dead:
		return -1
	return state.players[player_id].role

func award_peek_two_roles(first_player_id: int, second_player_id: int) -> Array:
	if first_player_id == second_player_id:
		return []
	var first_role = award_peek_role(first_player_id)
	var second_role = award_peek_role(second_player_id)
	if first_role < 0 or second_role < 0:
		return []
	var roles = [first_role, second_role]
	roles.shuffle()
	return roles

func award_execute_player(player_id: int) -> bool:
	if state.game_phase != "award":
		return false
	if state.current_award_id != AWARD_PATRICIAN_6_EXECUTION:
		return false
	if player_id < 0 or player_id >= state.players.size():
		return false
	if player_id == state.current_consul_index:
		return false
	var target = state.players[player_id]
	if target.is_dead:
		return false
	target.is_dead = true
	print("Influence award: Consul executed Player %d." % (player_id + 1))
	check_win_condition()
	return true

func finish_current_award() -> void:
	if state.game_phase != "award":
		return
	if state.pending_post_result_awards.size() > 0:
		state.current_award_id = state.pending_post_result_awards.pop_front()
	else:
		state.current_award_id = AWARD_NONE
		state.game_phase = "round_end"

# ─── Assassination Token System ───

func place_assassination_token(attacker_id: int, target_id: int) -> bool:
	if attacker_id < 0 or attacker_id >= state.players.size():
		return false
	if target_id < 0 or target_id >= state.players.size():
		return false
	if attacker_id == target_id:
		return false
	if state.players[attacker_id].is_dead or state.players[target_id].is_dead:
		return false
	if state.players[attacker_id].available_assassination_tokens < 1:
		return false
	
	# Create and place the token
	var token = AssassinationToken.new()
	token.attacker_id = attacker_id
	token.target_id = target_id
	token.rounds_left = 3
	token.placed_this_round = true
	
	state.active_assassination_tokens.append(token)
	state.players[attacker_id].available_assassination_tokens -= 1
	
	print("Player %d placed assassination token on Player %d" % [attacker_id + 1, target_id + 1])
	return true

func get_tokens_on_player(target_id: int) -> Array:
	var tokens = []
	for token in state.active_assassination_tokens:
		if token.target_id == target_id:
			tokens.append(token)
	return tokens

func is_player_dead(player_id: int) -> bool:
	if player_id < 0 or player_id >= state.players.size():
		return false
	return state.players[player_id].is_dead

func count_tokens_placed_this_round(target_id: int) -> int:
	var count = 0
	for token in state.active_assassination_tokens:
		if token.target_id == target_id and token.placed_this_round:
			count += 1
	return count

func apply_assassination_tokens() -> void:
	# For each token placed this round, check if target dies
	for token in state.active_assassination_tokens:
		if token.placed_this_round:
			var target = state.players[token.target_id]
			if target.is_dead:
				continue
			var total_tokens = get_tokens_on_player(token.target_id).size()
			if total_tokens >= 3:
				target.is_dead = true
				print("Player %d has been eliminated by assassination!" % (token.target_id + 1))

func process_assassination_tokens_end_of_round() -> void:
	# Mark all tokens as "not placed this round" for next round
	for token in state.active_assassination_tokens:
		token.placed_this_round = false
	
	# Decrement timers and remove expired tokens
	var expired = []
	for i in range(state.active_assassination_tokens.size() - 1, -1, -1):
		var token = state.active_assassination_tokens[i]
		token.rounds_left -= 1
		if token.rounds_left <= 0:
			expired.append(i)
	
	# Remove expired tokens (in reverse order to maintain indices)
	for i in expired:
		print("Assassination token on Player %d has expired" % (state.active_assassination_tokens[i].target_id + 1))
		state.active_assassination_tokens.remove_at(i)

func reset_assassination_token_round_flags() -> void:
	for token in state.active_assassination_tokens:
		token.placed_this_round = false

# Testing/admin methods
func grant_assassination_token_testing(player_id: int) -> bool:
	if player_id < 0 or player_id >= state.players.size():
		return false
	if state.players[player_id].available_assassination_tokens >= MAX_ASSASSINATION_TOKENS_PER_PLAYER:
		print("Player %d already has the maximum assassination tokens" % (player_id + 1))
		return false
	state.players[player_id].available_assassination_tokens = min(
		state.players[player_id].available_assassination_tokens + 1,
		MAX_ASSASSINATION_TOKENS_PER_PLAYER
	)
	print("Granted assassination token to Player %d (test)" % (player_id + 1))
	return true
