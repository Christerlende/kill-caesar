extends Resource
class_name Policy

# bring Role enum into scope
const Role = preload("res://scripts/data/role.gd").Role

@export var id: int = 0
@export var faction: int = Role.PLEBIAN # determines which team gets influence

@export var option_a_text: String = ""
@export var option_b_text: String = ""

@export var option_a_beneficiary: int = Role.PLEBIAN
@export var option_b_beneficiary: int = Role.PATRICIAN
@export var option_a_gold_amount: int = 0
@export var option_b_gold_amount: int = 0
@export var option_a_result_text: String = ""
@export var option_b_result_text: String = ""

static func example_policies() -> Array:
    var deck: Array = [
        _build_placeholder_policy(2, Role.PATRICIAN),
        _build_placeholder_policy(3, Role.PLEBIAN),
        _build_placeholder_policy(4, Role.PATRICIAN),
        _build_placeholder_policy(5, Role.PLEBIAN),
        _build_placeholder_policy(6, Role.PATRICIAN),
        _build_placeholder_policy(7, Role.PLEBIAN),
        _build_placeholder_policy(8, Role.PATRICIAN),
        _build_placeholder_policy(9, Role.PLEBIAN),
        _build_placeholder_policy(10, Role.PATRICIAN),
        _build_policy_1(),
    ]
    return deck

static func _build_policy_1() -> Policy:
    var policy := Policy.new()
    policy.id = 1
    policy.faction = Role.PLEBIAN
    policy.option_a_text = "Each Plebeian gains 2 gold"
    policy.option_b_text = "Each Patrician (except Caesar) gains 4 gold"
    policy.option_a_beneficiary = Role.PLEBIAN
    policy.option_b_beneficiary = Role.PATRICIAN
    policy.option_a_gold_amount = 2
    policy.option_b_gold_amount = 4
    policy.option_a_result_text = "Each Plebeian has gained 2 gold."
    policy.option_b_result_text = "Each Patrician has gained 4 gold, but none for Caesar."
    return policy

static func _build_placeholder_policy(policy_id: int, faction_alignment: int) -> Policy:
    var policy := Policy.new()
    policy.id = policy_id
    policy.faction = faction_alignment
    policy.option_a_text = "Placeholder decree text"
    policy.option_b_text = "Placeholder decree text"
    policy.option_a_beneficiary = Role.PLEBIAN
    policy.option_b_beneficiary = Role.PATRICIAN
    policy.option_a_gold_amount = 2
    policy.option_b_gold_amount = 2
    policy.option_a_result_text = "Placeholder decree effect."
    policy.option_b_result_text = "Placeholder decree effect."
    return policy
