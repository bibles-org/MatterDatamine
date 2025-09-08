require ecs
require net
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require game.es.damage_systems.damage_model_common
require active_matter.game.es.game_end_reasons_common
require DngDm
require daSkies
require level
require game.es.onboarding_common
require app
require math.base
require DagorMath
require AnimV20
require ecs.safe
require ecs.common
require BulletHoles
require JsonUtils
require rapidjson
require DagorSystem
require game.es.item_equip_common


[es(on_appear)]
def init_hero_game_effect(evt : Event;
                          onboarding_hero_game_effect__actualEffectTemplate : string;
                          onboarding_hero_game_effect__additionalTemplate : string;
                          var onboarding_hero_game_effect__effect : EntityId&)
  find_query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid : EntityId)
    onboarding_hero_game_effect__effect = createEntity("{onboarding_hero_game_effect__actualEffectTemplate}+{onboarding_hero_game_effect__additionalTemplate}") <| $(init)
      set(init, "game_effect__attachedTo", hero_eid)
    return true


[es(on_appear, REQUIRE=hero)]
def init_hero_game_effect_on_hero_appear(evt : Event; eid aka hero_eid : EntityId)
  query() <| $ [es] (onboarding_hero_game_effect__actualEffectTemplate : string;
                     var onboarding_hero_game_effect__effect : EntityId&)
    query(onboarding_hero_game_effect__effect) <| $ [es] (game_effect__attachedTo : EntityId)
      // This means that hero has changed, while effect is still active
      if game_effect__attachedTo != hero_eid
        destroyEntity(onboarding_hero_game_effect__effect)
        onboarding_hero_game_effect__effect = INVALID_ENTITY_ID
        return

    onboarding_hero_game_effect__effect = createEntity(onboarding_hero_game_effect__actualEffectTemplate) <| $(init)
      set(init, "game_effect__attachedTo", hero_eid)


[es(on_disappear, on_event=CmdClearStateMachineEffectImmediately)]
def clear_hero_game_effect(evt : Event; onboarding_hero_game_effect__effect : EntityId)
  destroyEntity(onboarding_hero_game_effect__effect)


[es(on_appear, REQUIRE=fake_in_battle_ui_state)]
def fake_in_battle_ui_state_appear(evt : Event)
  broadcastEvent(EventGameSessionStarted())


[es(on_event=CmdClearStateMachineEffectImmediately, REQUIRE=fake_in_battle_ui_state)]
def fake_in_battle_ui_state_disappear(evt : Event)
  broadcastEventImmediate(EventGameSessionFinished())


[es(on_appear)]
def override_respbase_on_appear(evt : Event;
                                override_respawn_base__createAtEntityWithTag : string;
                                override_respawn_base__newBaseTemplate : string;
                                var override_respawn_base__base : EntityId&;
                                var override_respawn_base__oldBases : EidList)
  query() <| $ [es(REQUIRE=respbase)] (eid : EntityId; var active : bool&)
    if !active
      return

    active = false
    push(override_respawn_base__oldBases, eid)

  assume componentName = override_respawn_base__createAtEntityWithTag
  let componentHash = ecs_hash(componentName)
  find_query() <| $ [es] (eid : EntityId; transform : float3x4)
    if !has(eid, componentName, componentHash)
      return false

    override_respawn_base__base = createEntity(override_respawn_base__newBaseTemplate) <| $(init)
      set(init, "transform", transform)

    return true


[es(on_event=CmdClearStateMachineEffectImmediately)]
def override_respbase_restore_on_disappear(evt : Event;
                                           override_respawn_base__base : EntityId;
                                           override_respawn_base__oldBases : EidList)
  query(override_respawn_base__base) <| $ [es] (var active : bool&)
    active = false
  destroyEntity(override_respawn_base__base)
  for eid in override_respawn_base__oldBases
    query(eid) <| $ [es] (var active : bool&)
      active = true


[es(on_appear)]
def override_weather_preset(evt : Event;
                            override_weather_preset__newPreset : string;
                            override_weather_preset__newSkiesTime : float;
                            override_weather_preset__newCloudHoleTargetDensity : float;
                            var override_weather_preset__oldPreset : das_string&;
                            var override_weather_preset__oldSkiesTime : float&;
                            var override_weather_preset__oldCloudHoleTargetDensity : float&)
  if override_weather_preset__newSkiesTime >= 0.0
    override_weather_preset__oldSkiesTime = get_daskies_time()
    set_daskies_time(override_weather_preset__newSkiesTime)
  if !empty(override_weather_preset__newPreset)
    query(get_current_level_eid()) <| $ [es] (var level__weatherChoice : Object)
      if has(level__weatherChoice, override_weather_preset__newPreset)
        return
      set(level__weatherChoice, override_weather_preset__newPreset, 0.0f)
    override_weather_preset__oldPreset := get_current_weather_preset_name()
    select_weather_preset_delayed(override_weather_preset__newPreset)
  if override_weather_preset__newCloudHoleTargetDensity >= 0.0
    // clouds hole is a singleton
    find_query() <| $ [es(REQUIRE=clouds_hole_tag)] (var density : float&)
      override_weather_preset__oldCloudHoleTargetDensity = density
      density = override_weather_preset__newCloudHoleTargetDensity
      return true


[es(on_disappear)]
def restore_weather_preset(evt : Event;
                           override_weather_preset__oldSkiesTime : float;
                           override_weather_preset__oldPreset : string;
                           override_weather_preset__oldCloudHoleTargetDensity : float)
  if override_weather_preset__oldSkiesTime >= 0.0
    set_daskies_time(override_weather_preset__oldSkiesTime)
  if !empty(override_weather_preset__oldPreset)
    select_weather_preset_delayed(override_weather_preset__oldPreset)
  if override_weather_preset__oldCloudHoleTargetDensity >= 0.0
    // clouds hole is a singleton
    find_query() <| $ [es(REQUIRE=clouds_hole_tag)] (var density : float&)
      density = override_weather_preset__oldCloudHoleTargetDensity
      return true


[es(on_appear, REQUIRE=clear_hero_inventory)]
def onboarding_clear_hero_inventory(evt : Event)
  find_query() <| $ [es(REQUIRE=hero)] (itemContainer : EidList;
                                        human_equipment__slots : Object;
                                        human_weap__gunEids : EidList)
    for item in itemContainer
      destroyEntity(item)
    for weapon in human_weap__gunEids
      destroyEntity(weapon)
    for eqipmentInSlot in human_equipment__slots
      let equipmentEid = get_Eid(eqipmentInSlot.value) ?? INVALID_ENTITY_ID
      destroyEntity(equipmentEid)
    return true


def give_hero_onboarding_loadout(loadout_file : string; loadout_name : string; hero_eid : EntityId)
  load_json_from_file(loadout_file) <| $(jsonDocument)
    jsonDocument |> GetArray() <| $(jsonLoadouts)
      for jsonLoadout in jsonLoadouts
        let name = jsonLoadout |> json_get_or("name", "")
        if name != loadout_name
          continue

        using() <| $(var loadout : Object)
          using() <| $(var itemsArray : Array)
            jsonLoadout |> FindMember("loadoutItems", JsonType.kArrayType) <| $(loadoutItems : JsonValue)
              loadoutItems |> GetArray() <| $(loadoutItemsArray : JsonConstArray)
                for loadoutItem in loadoutItemsArray
                  if !parse_item_from_jwt(loadoutItem, itemsArray)
                    continue

            if !ensure_items_has_suit(itemsArray)
              logwarn("[ONBOARDING] There is no suit in loadout \"{name}\".")
              return
            set(loadout, "items", itemsArray)
            give_onboarding_loadout(loadout, hero_eid)


[es(on_appear)]
def onboarding_set_hero_loadout(evt : Event;
                                onboarding_set_hero_loadout__file : string;
                                onboarding_set_hero_loadout__loadoutName : string)
  find_query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid, possessedByPlr : EntityId)
    var loadedFromProfile = false
    query(possessedByPlr) <| $ [es] (player__unlocks : StringList)
      query() <| $ [es] (player_profile__loadout : Array)
        if -1 != player__unlocks |> find_index("onboarding_base_first_time") // we are not new player
          loadedFromProfile = true
          using() <| $(var loadout : Object)
            set(loadout, "items", player_profile__loadout)
            give_onboarding_loadout(loadout, hero_eid)
    if !loadedFromProfile
      give_hero_onboarding_loadout(onboarding_set_hero_loadout__file, onboarding_set_hero_loadout__loadoutName, hero_eid)
    return true


[es(on_appear, REQUIRE=hero)]
def onboarding_set_hero_loadout_on_respawn(evt : Event; eid aka hero_eid, possessedByPlr : EntityId)
  find_query() <| $ [es] (onboarding_set_hero_loadout__file : string; onboarding_set_hero_loadout__loadoutName : string)
    var loadedFromProfile = false
    query(possessedByPlr) <| $ [es] (player__unlocks : StringList)
      query() <| $ [es] (player_profile__loadout : Array)
        if -1 != player__unlocks |> find_index("onboarding_base_first_time") // we are not new player
          loadedFromProfile = true
          using() <| $(var loadout : Object)
            set(loadout, "items", player_profile__loadout)
            give_onboarding_loadout(loadout, hero_eid)
    if !loadedFromProfile
      give_hero_onboarding_loadout(onboarding_set_hero_loadout__file, onboarding_set_hero_loadout__loadoutName, hero_eid)
    return true


[es(on_appear, REQUIRE=onboarding_heal_hero)]
def onboarding_heal_hero(evt : Event)
  find_query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid : EntityId)
    human_damage_model_set_hp_in_percent(hero_eid, 1.0)
    return true


[es(on_appear)]
def onboarding_set_anim_state_progress_var_game_effect(evt : Event;
                                                       game_effect__attachedTo : EntityId;
                                                       game_effect__setAnimStateProgressVarName : string;
                                                       game_effect__setAnimStateProgressVarValue : float)
  query(game_effect__attachedTo) <| $ [es] (var animchar : AnimcharBaseComponent)
    let varId = *animchar.animGraph |> anim_graph_getParamId(game_effect__setAnimStateProgressVarName, int(PT_ScalarParam))
    *animchar.animState |> anim_state_holder_setParam(varId, game_effect__setAnimStateProgressVarValue)


[es(on_appear, after=onboarding_extraction_sequence_final_stage, REQUIRE=onboarding_miniraid_extraction_sequence_final_stage)]
def onboarding_miniraid_extraction_sequence_final_stage(evt : Event;
                                                        game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (possessedByPlr : EntityId; team : int)
    let completedContract = check_hero_completed_onboarding_objective()
    let reason = int(completedContract ? GameEndReasons.YOU_EXTRACTED : GameEndReasons.ONBOARDING_FAILED_CONTRACT)
    send_net_event(
      possessedByPlr,
      EventEndgamePlayerResult(allowSpectate = false, reason = reason, team = team, autoExit = true)
    )


[es(on_appear)]
def onboarding_setup_knife_animation(evt : Event;
                                     onboarding_monolith_setup_knife_animation__forProto : string;
                                     onboarding_monolith_setup_knife_animation__setupTemplate : string)
  find_query() <| $ [es(REQUIRE=watchedPlayerItem)] (eid : EntityId; item__proto : string; var animchar__updatable : bool&)
    if item__proto != onboarding_monolith_setup_knife_animation__forProto
      return false
    addSubTemplate(eid, onboarding_monolith_setup_knife_animation__setupTemplate)
    animchar__updatable = true
    return true

[es(on_appear, REQUIRE=watchedPlayerItem)]
def onboarding_setup_knife_animation_late(evt : Event;
                                          eid : EntityId;
                                          item__proto : string;
                                          var animchar__updatable : bool&)
  find_query() <| $ [es] (onboarding_monolith_setup_knife_animation__forProto : string;
                          onboarding_monolith_setup_knife_animation__setupTemplate : string)
    if item__proto != onboarding_monolith_setup_knife_animation__forProto
      return false
    addSubTemplate(eid, onboarding_monolith_setup_knife_animation__setupTemplate)
    animchar__updatable = true
    return true


[es(on_event=CmdClearStateMachineEffectImmediately)]
def onboarding_remove_knife_animation(evt : Event;
                                      onboarding_monolith_setup_knife_animation__forProto : string;
                                      onboarding_monolith_setup_knife_animation__setupTemplate : string)
  find_query() <| $ [es(REQUIRE=watchedPlayerItem)] (eid : EntityId; item__proto : string; var animchar__updatable : bool&)
    if item__proto != onboarding_monolith_setup_knife_animation__forProto
      return false
    removeSubTemplate(eid, onboarding_monolith_setup_knife_animation__setupTemplate)
    animchar__updatable = false
    return true


[es(on_appear)]
def onboarding_init_knife_animation(evt : Event;
                                    onboarding_knife_animation__animParamName : string;
                                    var animchar : AnimcharBaseComponent;
                                    var onboarding_knife_animation__animParamId : int&)
  assume animGraph = animchar.animGraph
  onboarding_knife_animation__animParamId = *animGraph |> anim_graph_getParamId(onboarding_knife_animation__animParamName, int(PT_ScalarParam))


[es(no_order)]
def onboarding_update_knife_animation(update : UpdateStageInfoAct;
                                      onboarding_knife_animation__startedAt : float;
                                      onboarding_knife_animation__animParamChangeTime : float;
                                      onboarding_knife_animation__animParamStartValue : float;
                                      onboarding_knife_animation__animParamEndValue : float;
                                      onboarding_knife_animation__animParamId : int;
                                      var animchar : AnimcharBaseComponent&)
  assume startTime = onboarding_knife_animation__startedAt
  assume endTime = startTime + onboarding_knife_animation__animParamChangeTime
  let curTime = get_sync_time()

  let currentValue = (startTime < 0.0
    ? onboarding_knife_animation__animParamStartValue
    : cvt(curTime, float2(startTime, endTime), float2(onboarding_knife_animation__animParamStartValue, onboarding_knife_animation__animParamEndValue)))

  *animchar.animState |> anim_state_holder_setParam(onboarding_knife_animation__animParamId, currentValue)
  animchar_act(animchar, update.dt, true)


[es(on_event=EventDesiredHeroIrqHappened)]
def onboarding_start_knife_animation(evt : Event; var onboarding_knife_animation__startedAt : float&)
  onboarding_knife_animation__startedAt = get_sync_time()


[es(on_event=EventDesiredHeroIrqHappened)]
def onboarding_destroy_on_hero_irq(evt : Event; onboarding_create_entity_on_hero_irq__template : string; transform : float3x4 const?)
  if transform != null
    createEntity(onboarding_create_entity_on_hero_irq__template) <| $(init)
      set(init, "transform", *transform)
  else
    createEntity(onboarding_create_entity_on_hero_irq__template)


[es(REQUIRE=hero)]
def onboarding_hero_irq_reactor(evt : EventAnimIrq; anim_irq__eventNames : Object)
  query() <| $ [es] (eid : EntityId; onboarding_hero_irq_reactor__irqName : string)
    let irqEventObj = anim_irq__eventNames[onboarding_hero_irq_reactor__irqName] ?as Object
    let irqId = irqEventObj?.irqId ?? 0
    if irqId == evt.irqType
      sendEvent(eid, EventDesiredHeroIrqHappened())


[es(REQUIRE=onboarding_erase_all_bullet_holes, on_appear)]
def onboarding_erase_all_bullet_holes(evt : Event)
  erase_all_bullet_holes()


[es(REQUIRE=onboarding_erase_bullet_holes_in_sphere, on_appear)]
def onboarding_erase_bullet_holes_in_sphere(evt : Event; transform : float3x4; sphere_zone__radius : float)
  erase_bullet_holes(transform[3], sphere_zone__radius)


[es(REQUIRE=monolith_bullet_catcher)]
def monolith_bullet_catcher(evt : ProjectileOnHitEntityWithHp; eid aka catcher_eid : EntityId)
  if catcher_eid != evt.victim
    return

  query(evt.projectile_eid) <| $ [es] (var projectile__stopped : bool&)
    projectile__stopped = true
    destroyEntity(evt.projectile_eid)


[es(REQUIRE=hero, no_order)]
def onboarding_interference_source(info : UpdateStageInfoAct; transform aka player_transform : float3x4)
  var closestInterferenceSourceDistanceSq = VERY_BIG_NUMBER
  var closestInterferenceSourceValue = 0.0

  query() <| $ [es] (transform aka interference_transform : float3x4; interference_source__maxDistance : float; interference_source__active : bool)
    if !interference_source__active
      return

    let distanceToCenterSq = distance_sq(player_transform[3], interference_transform[3])
    let maxDistanceSq = square(interference_source__maxDistance)

    if distanceToCenterSq < maxDistanceSq && distanceToCenterSq < closestInterferenceSourceDistanceSq
      closestInterferenceSourceDistanceSq = distanceToCenterSq
      closestInterferenceSourceValue = 1.0 - distanceToCenterSq / maxDistanceSq

  find_query() <| $ [es] (var smartwatchInterference : float&)
    smartwatchInterference = float(int(closestInterferenceSourceValue * 10.0)) / 10.0
    return true


[es(no_order)]
def onboarding_smartwatch_turning_on_source(info : UpdateStageInfoAct; transform aka turning_point_transform : float3x4;
                                            smartwatch_turning_on_source__maxDistance : float)
  find_query() <| $ [es(REQUIRE=hero)] (transform aka player_transform : float3x4)
    find_query() <| $ [es] (var smartwatchScreenOpacity : float&)
      let maxDistSq = square(smartwatch_turning_on_source__maxDistance)
      let distSq = distance_sq(turning_point_transform[3], player_transform[3])

      if distSq < maxDistSq
        smartwatchScreenOpacity = 1.0 - float(int(distSq / maxDistSq * 10.0)) / 10.0
        return true
      smartwatchScreenOpacity = 0.0
      return false
    return true


[es(REQUIRE=smartwatchInterference)]
def disable_interference_source_points_on_cutscene(evt : EventDesiredHeroIrqHappened)
  query() <| $ [es] (var interference_source__active : bool&)
    interference_source__active = false


[es(REQUIRE=onboarding_miniraid_clear_am_piles_in_world, on_appear)]
def onboarding_miniraid_clear_am_piles_in_world(evt : Event)
  query() <| $ [es(REQUIRE=(item__am, item_in_world))] (eid : EntityId)
    destroyEntity(eid)


[es(tag=gameClient, no_order)]
def onboarding_effect_change_fov(act : UpdateStageInfoAct;
                                 onboarding_change_fov_effect__from : float;
                                 onboarding_change_fov_effect__to : float;
                                 game_effect__attachedTo : EntityId;
                                 game_effect__clientDestroyAt : float;
                                 game_effect__timeToDestroy : float)
  query(game_effect__attachedTo) <| $ [es] (var human__cameraMagnificationMult : float&)
    let t = 1.0 - clamp((game_effect__clientDestroyAt - act.curTime) / game_effect__timeToDestroy, 0.0, 1.0)

    human__cameraMagnificationMult = lerp(onboarding_change_fov_effect__from, onboarding_change_fov_effect__to, t)


[es(tag=gameClient, on_disappear)]
def onboarding_effect_change_fov_on_disappear(evt : Event;
                                              onboarding_change_fov_effect__from : float;
                                              game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var human__cameraMagnificationMult : float&)
    human__cameraMagnificationMult = onboarding_change_fov_effect__from
