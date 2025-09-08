module onboarding_common shared
require ecs
require ecs.safe
require ecs.common
require game.es.item_equip_common
require game.es.nexus_loadout_common


def is_onboarding(ensure_current_state_exists : bool = true)
  var isOnboarding = false

  find_query() <| $ [es(REQUIRE=onboarding_state_machine)] (state_machine__currentState : EntityId)
    isOnboarding = ((doesEntityExist(state_machine__currentState) || !ensure_current_state_exists) &&
                   !has(state_machine__currentState, "onboarding_phase_finished"))
    return true
  return isOnboarding


def is_onboarding_memory()
  return find_query() <| $ [es(REQUIRE=onboarding_state_machine_memory)] ()
    return true


def give_onboarding_loadout(loadout : Object; hero : EntityId)
  hero_clean_all_equipment_and_gun_slots(hero)

  using() <| $(var loadoutItems : Array)
    find_query() <| $ [es] (var onboarding_item_unique_id_holder__nextUniqueId : int64&)
      onboarding_item_unique_id_holder__nextUniqueId += 1l
      generate_loadout_items(loadout, loadoutItems, onboarding_item_unique_id_holder__nextUniqueId)
      return true
    load_items(loadoutItems, hero)


def check_hero_completed_onboarding_objective()
  return find_query() <| $ [es(REQUIRE=objective__collectedItemsList)] (objective__currentValue : int)
    return objective__currentValue > 0
