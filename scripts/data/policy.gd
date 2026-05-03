extends Resource
class_name Policy

const Role = preload("res://scripts/data/role.gd").Role

@export var id: int = 0
@export var faction: int = Role.PLEBIAN

@export var option_a_text: String = ""
@export var option_a_beneficiary: int = Role.PLEBIAN
@export var option_a_effect_type: String = ""
@export var option_a_effect_params: Dictionary = {}
@export var option_a_result_text: String = ""

@export var option_b_text: String = ""
@export var option_b_beneficiary: int = Role.PATRICIAN
@export var option_b_effect_type: String = ""
@export var option_b_effect_params: Dictionary = {}
@export var option_b_result_text: String = ""

static func role_from_string(role_str: String) -> int:
    match role_str.to_lower():
        "caesar":
            return Role.CAESAR
        "patrician":
            return Role.PATRICIAN
        "plebeian", "plebian":
            return Role.PLEBIAN
        _:
            return Role.PLEBIAN

static func load_all_policies() -> Array:
    var file = FileAccess.open("res://assets/data/policies.json", FileAccess.READ)
    if not file:
        push_error("Failed to load policies.json")
        return []
    var json_text = file.get_as_text()
    file.close()
    var json = JSON.new()
    var err = json.parse(json_text)
    if err != OK:
        push_error("Failed to parse policies.json: %s" % json.get_error_message())
        return []
    var policies: Array = []
    for entry in json.data:
        policies.append(_from_dict(entry))
    return policies

static func _from_dict(d: Dictionary) -> Policy:
    var p = Policy.new()
    p.id = int(d.get("id", 0))
    p.faction = role_from_string(d.get("faction", "plebeian"))

    var a = d.get("option_a", {})
    p.option_a_text = a.get("text", "")
    p.option_a_beneficiary = role_from_string(a.get("beneficiary", "plebeian"))
    p.option_a_effect_type = a.get("effect_type", "")
    p.option_a_effect_params = a.get("effect_params", {})
    p.option_a_result_text = a.get("result_text", "")

    var b = d.get("option_b", {})
    p.option_b_text = b.get("text", "")
    p.option_b_beneficiary = role_from_string(b.get("beneficiary", "patrician"))
    p.option_b_effect_type = b.get("effect_type", "")
    p.option_b_effect_params = b.get("effect_params", {})
    p.option_b_result_text = b.get("result_text", "")

    return p
