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

static func example_policies() -> Array:
    # return a small hardcoded deck for testing
    var deck: Array = []
    for i in range(10):
        var p = Policy.new()
        p.id = i
        p.faction = Role.PATRICIAN if i % 2 == 0 else Role.PLEBIAN
        p.option_a_text = "Decree 1 $i"
        p.option_b_text = "Decree 2 $i"
        p.option_a_beneficiary = Role.PLEBIAN
        p.option_b_beneficiary = Role.PATRICIAN
        p.option_a_gold_amount = 2
        p.option_b_gold_amount = 2
        deck.append(p)
    return deck
