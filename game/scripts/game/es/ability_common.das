module ability_common shared
require ecs
require ecs.safe
require ecs.common
require game.events.events_active_matter
require game.es.ability_enums_common
require DngHuman


let SCREAM_ABILITY_NAME = "scream"


def get_ability_index(hero_ability__abilities : Array; cond : block<(it : Object const?) : bool>) : int
  for i, it in iter_range(hero_ability__abilities), hero_ability__abilities
    let data = get_ecs_object(it)
    if invoke(cond, data)
      return i
  return -1


def get_ability_index_by_name(hero_ability__abilities : Array; ability_name : string) : int
  return get_ability_index(hero_ability__abilities) <| $(data)
    return ability_name == get_string(data, "name", "")


def get_reduced_cooldown(base_value : float; ability_reduction : float) : float
  return base_value * (1. - ability_reduction)


def has_ability_state_by_name(abilities : Array; ability_name : string) : bool
  for it in abilities
    if get_ecs_object(it) |> get_string("name", "") == ability_name
      return true
  return false


def is_ability_prereqs_valid(agent_eid : EntityId; ability_idx : int; ability_obj : Object const?)
  var canUseAbilityNow = true
  query(agent_eid) <| $ [es] (isInVehicle : bool = false;
                              human_net_phys__isSwimming : bool = false;
                              human_attached_gun__isAttached : bool = false;
                              human_net_phys : HumanActor const?)
    canUseAbilityNow &&= !isInVehicle || !(get_bool(ability_obj, "lockInVehicle") ?? false)
    canUseAbilityNow &&= !human_net_phys__isSwimming || !(get_bool(ability_obj, "lockWhileSwimming") ?? false)
    canUseAbilityNow &&= !human_attached_gun__isAttached || !(get_bool(ability_obj, "lockInStationaryGun") ?? false)
    let lockWithLowJumpMult = get_float(ability_obj, "lockWithLowJumpMult")
    if canUseAbilityNow && lockWithLowJumpMult != null && human_net_phys != null
      if human_net_phys.phys.currentState.jumpSpeedMult < *lockWithLowJumpMult
        canUseAbilityNow = false
        return

  if canUseAbilityNow
    var validateAbilityPrereqs = ValidateAbilityPrereqs(abilityIdx = ability_idx, canUseAbility = true)
    sendEventImmediate(agent_eid, validateAbilityPrereqs)

    if !validateAbilityPrereqs.canUseAbility
      canUseAbilityNow = false

  return canUseAbilityNow