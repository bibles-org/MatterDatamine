require ecs
require math.base
require game.events.events_active_matter
require game.es.item_equip_common
require game.es.damage_systems.damage_model_common
require game.events.events_game
require DagorMath


def enter_shooting_range(hero_eid : EntityId;
                         var instant_reload : bool&;
                         var grenade_locker_counter : int&;
                         var base_disable_game_effect : EntityId&)
  instant_reload = false
  grenade_locker_counter -= 1
  createEntity("player_base_enable_shooting") <| $(var init)
    init |> set("game_effect__attachedTo", hero_eid)
  createEntity("shooting_range_fade") <| $(var init)
    init |> set("game_effect__attachedTo", hero_eid)
  destroyEntity(base_disable_game_effect)
  base_disable_game_effect = INVALID_ENTITY_ID
  find_query() <| $ [es] (var player_profile__disableTransaction : bool&)
    player_profile__disableTransaction = true
    return true


[es(REQUIRE=shooting_allowed_zone)]
def shooting_range_enter_zone(evt : EventZoneEnter)
  query(evt.visitorEid) <| $ [es(REQUIRE_NOT=initial_loadout_creation)] (var player_on_base_components__onBaseDisableGameEffect : EntityId&;
                                                                         var human_inventory__instantReload : bool&;
                                                                         var human_weap__lockedGrenadeThrowingCounter : int&)
    enter_shooting_range(evt.visitorEid, human_inventory__instantReload,
                         human_weap__lockedGrenadeThrowingCounter,
                         player_on_base_components__onBaseDisableGameEffect)


[es(on_disappear, REQUIRE=initial_loadout_creation)]
def hero_enter_shooting_on_profile_load_end(evt : Event;
                                            eid aka hero_eid : EntityId;
                                            zones_visitor__zonesIn : EidList;
                                            var player_on_base_components__onBaseDisableGameEffect : EntityId&;
                                            var human_inventory__instantReload : bool&;
                                            var human_weap__lockedGrenadeThrowingCounter : int&)
  find_query() <| $ [es(REQUIRE=shooting_allowed_zone)] (eid aka zone_eid : EntityId)
    if zones_visitor__zonesIn |> has_value(zone_eid)
      enter_shooting_range(hero_eid, human_inventory__instantReload,
                           human_weap__lockedGrenadeThrowingCounter,
                           player_on_base_components__onBaseDisableGameEffect)
    return true


[es(REQUIRE=shooting_allowed_zone)]
def shooting_range_leave_zone(evt : EventZoneLeave)
  query(evt.visitorEid) <| $ [es(REQUIRE_NOT=initial_loadout_creation)] (player_on_base_components__onBaseDisableGameEffectTemplate : string;
                                                                         var player_on_base_components__onBaseDisableGameEffect : EntityId&;
                                                                         var human_inventory__instantReload : bool&;
                                                                         var human_weap__lockedGrenadeThrowingCounter : int&)
    human_weap__lockedGrenadeThrowingCounter += 1
    let enablerEid = getSingletonEntity("player_base_enable_shooting")
    hero_clean_all_equipment_and_gun_slots(evt.visitorEid)
    human_damage_model_set_hp_in_percent(evt.visitorEid, 1f)
    human_inventory__instantReload = true
    destroyEntity(enablerEid)
    broadcastEvent(EventProfileLoaded())
    player_on_base_components__onBaseDisableGameEffect = createEntity(player_on_base_components__onBaseDisableGameEffectTemplate) <| $(var init)
      init |> set("game_effect__attachedTo", evt.visitorEid)
    createEntity("shooting_range_fade") <| $(var init)
      init |> set("game_effect__attachedTo", evt.visitorEid)


def place_mannequins(templates : StringList; current_idx : int)
  query() <| $ [es(REQUIRE=shooting_range_mannequin_position)] (transform : float3x4)
    createEntity(string(templates[current_idx])) <| $(var init)
      init |> set("transform", transform)


def place_mannequins(templates : array<string>; current_idx : int)
  query() <| $ [es(REQUIRE=shooting_range_mannequin_position)] (transform : float3x4)
    createEntity(string(templates[current_idx])) <| $(var init)
      init |> set("transform", transform)


[es(tag=gameClient, on_appear, REQUIRE=shooting_allowed_zone)]
def shooting_range_init_mannequins(evt : Event;
                                   shooting_allowed_zone__mannequinsList : StringList;
                                   var shooting_allowed_zone__curMannequin : int&)
  if length(shooting_allowed_zone__mannequinsList) > 0 && shooting_allowed_zone__curMannequin >= 0
    shooting_allowed_zone__curMannequin = shooting_allowed_zone__curMannequin % length(shooting_allowed_zone__mannequinsList)
    place_mannequins(shooting_allowed_zone__mannequinsList, shooting_allowed_zone__curMannequin)


def player_has_unlock(unlockName : string)
  var res = false
  find_query() <| $ [es] (active_matter_player__unlockedNotes : StringList)
    res = active_matter_player__unlockedNotes |> has_value(unlockName)
    return true
  return res


[es(tag=gameClient, on_event=CmdUse, REQUIRE=shooting_range_change_mannequins_panel)]
def shooting_range_change_mannequins(evt : Event)
  query() <| $ [es] (shooting_allowed_zone__mannequinsList : StringList;
                     shooting_allowed_zone__mannequinsUnlockList : StringList;
                     var shooting_allowed_zone__curMannequin : int&)
    var availableMannequins : array<string>
    for i in iter_range(shooting_allowed_zone__mannequinsUnlockList)
      if (shooting_allowed_zone__mannequinsUnlockList[i] == "none"
        || player_has_unlock(string(shooting_allowed_zone__mannequinsUnlockList[i])))
        availableMannequins |> push(string(shooting_allowed_zone__mannequinsList[i]))
    if length(availableMannequins) > 0
      query() <| $ [es(REQUIRE=shooting_range_mannequin)] (eid : EntityId)
        destroyEntity(eid)
      query() <| $ [es(REQUIRE=resurrect_timer__resurrectAt)] (eid : EntityId)
        destroyEntity(eid)

      shooting_allowed_zone__curMannequin = (shooting_allowed_zone__curMannequin + 1) % length(availableMannequins)
      place_mannequins(availableMannequins, shooting_allowed_zone__curMannequin)
