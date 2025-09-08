require app
require ecs
require net
require DagorInput
require TouchInput
require game.events.events
require game.events.events_active_matter
require game.es.ability_enums_common
require active_matter.game.es.ability_common


[es(tag=input, no_order, REQUIRE=hero)]
def mothman_attack_input(upd : UpdateStageUpdateInput;
                         eid : EntityId;
                         human_input__shoot : int;
                         floating_objects__eids : EidList;
                         hero_ability__abilities : Array;
                         monstrified_mothman_attack__shootAnimTimeEnd : float;
                         var monstrified_mothman_gathering__isChanneling : bool&;
                         var monstrified_mothman_attack__isChanneling : bool&)
  if !is_action_active(uint16(human_input__shoot))
    return

  if monstrified_mothman_attack__shootAnimTimeEnd > get_sync_time()
    return

  let wantToChannel = get_digital_action_state(uint16(human_input__shoot)).bState || is_button_pressed(uint16(human_input__shoot))

  if empty(floating_objects__eids) && wantToChannel
    sendEvent(eid, AbilityUseFailedClient(ability_name = "mothman_throw_stone", reason = int(AbilityUseFailedReason.NOT_ENOUGH_CHARGES)))
    return

  if wantToChannel && monstrified_mothman_gathering__isChanneling
    let abilityIdx = get_ability_index_by_name(hero_ability__abilities, "mothman_gather_stones")
    send_net_event(eid, RqCancelAbility(idx = abilityIdx))
    monstrified_mothman_gathering__isChanneling = false

  monstrified_mothman_attack__isChanneling = wantToChannel
