require app
require ecs
require math.base
require game.events.events_active_matter
require DagorSystem
require fx
require game.utils.hero
require game.utils.net_utils
require player
require game.es.am_encounter_workbench_enums_common
require game.es.inventory_common


def update_encounter_workbench_corruption_usage(encounter_workbench_corruption__amPerNode : int;
                                                composit_holder__childrenEids : EidList;
                                                workbench_eid : EntityId)
  let corruptedNodesCount = length(composit_holder__childrenEids)
  let cleanPrice = encounter_workbench_corruption__amPerNode * corruptedNodesCount

  query(workbench_eid) <| $ [es] (var item__useActionAvailable : bool&;
                                  var item__setCustomUsePrompt : das_string&;
                                  var item__setCustomUsePromptParams : Object&)
    query(get_watched_entity()) <| $ [es(REQUIRE_NOT=deadEntity)] (am_storage__value : int)
      item__setCustomUsePromptParams |> clear()
      if cleanPrice > 0
        item__setCustomUsePromptParams |> set("cleanPrice", cleanPrice)
        item__useActionAvailable = (am_storage__value > 0)
        if !item__useActionAvailable
          item__setCustomUsePrompt := "hud/workbench_price"
        else
          item__setCustomUsePrompt := "hud/workbench_clear"
      else
        item__useActionAvailable = true
        item__setCustomUsePrompt := ""


[es(tag=gameClient, on_appear, track=composit_holder__childrenEids)]
def encounter_workbench_corruption_usage_client(evt : Event;
                                                encounter_workbench_corruption__amPerNode : int;
                                                composit_holder__childrenEids : EidList;
                                                ownerEid : EntityId)
  update_encounter_workbench_corruption_usage(encounter_workbench_corruption__amPerNode,
                                              composit_holder__childrenEids,
                                              ownerEid)


[es(tag=gameClient, on_appear, track=am_storage__value,  REQUIRE=(hero, am_storage__value))]
def encounter_workbench_corruption_hero_usage_client(evt : Event)
  query() <| $ [es] (encounter_workbench_corruption__amPerNode : int;
                     composit_holder__childrenEids : EidList;
                     ownerEid : EntityId)
    update_encounter_workbench_corruption_usage(encounter_workbench_corruption__amPerNode,
                                                composit_holder__childrenEids,
                                                ownerEid)


[es(tag=gameClient, on_appear, REQUIRE=watchedByPlr)]
def encounter_workbench_corruption_watched_usage_client(evt : Event)
  query() <| $ [es] (encounter_workbench_corruption__amPerNode : int;
                     composit_holder__childrenEids : EidList;
                     ownerEid : EntityId)
    update_encounter_workbench_corruption_usage(encounter_workbench_corruption__amPerNode,
                                                composit_holder__childrenEids,
                                                ownerEid)



[es(tag=gameClient)]
def encounter_workbench_item_created_client(evt : EventWorkbenchItemsCreated;
                                            transform : float3x4;
                                            encounter_workbench__itemCreatedFxLocalTm : float3x4;
                                            encounter_workbench__itemCreatedFx : string;
                                            encounter_workbench__itemCreatedFxScale : float)
  let wtm = transform * encounter_workbench__itemCreatedFxLocalTm
  var tm = IDENT_TM
  tm[3] = wtm[3]
  let fxType = get_type_by_name(encounter_workbench__itemCreatedFx)
  start_effect(fxType,
               tm,
               IDENT_TM,
               false) <| $(var fx : AcesEffect)
    fx |> setFxScale(encounter_workbench__itemCreatedFxScale)


[es(tag=gameClient)]
def encounter_workbench_result_event_client(evt : EventWorkbenchResultEvent;
                                            transform : float3x4;
                                            encounter_workbench__batteryInsertedFxLocalTm : float3x4;
                                            encounter_workbench__batteryInsertedFx : string;
                                            encounter_workbench__batteryInsertedFxScale : float)
  if evt.name == "battery"
    let wtm = transform * encounter_workbench__batteryInsertedFxLocalTm
    var tm = IDENT_TM
    tm[3] = wtm[3]
    let fxType = get_type_by_name(encounter_workbench__batteryInsertedFx)
    start_effect(fxType,
                tm,
                IDENT_TM,
                false) <| $(var fx : AcesEffect)
      fx |> setFxScale(encounter_workbench__batteryInsertedFxScale)


[es(tag=gameClient, track=encounter_workbench__charges, REQUIRE=encounter_workbench__charges)]
def encounter_workbench_track_encounter_workbench_charges_client(evt : Event;
                                                                 eid : EntityId)
  // Update UI marker
  sendEvent(eid, EventActionMarkerStateChanged())


[es(tag=gameClient)]
def encounter_corrupted_workbench_corruption_block_removed_client(evt : EventWorkbenchCorruptionBlockRemoved;
                                                                  encounter_corrupted_workbench__corruptionBlockRemovedFx : string;
                                                                  encounter_corrupted_workbench__corruptionBlockRemovedFxScale : float)
  var tm = IDENT_TM
  tm[3] = evt.pos
  let fxType = get_type_by_name(encounter_corrupted_workbench__corruptionBlockRemovedFx)
  start_effect(fxType,
               tm,
               IDENT_TM,
               false) <| $(var fx : AcesEffect)
    fx |> setFxScale(encounter_corrupted_workbench__corruptionBlockRemovedFxScale)



[es(tag=gameClient, REQUIRE=encounter_workbench)]
def encounter_workbench_on_result_event_client(evt : EventWorkbenchResultEvent;
                                               var encounter_workbench__clientMode : int&)
  query(evt.heroEid) <| $ [es(REQUIRE=hero)] ()
    if evt.name == "repair_menu"
      encounter_workbench__clientMode = int(EncounterWorkbenchClientMode.REPAIR)


[es(tag=gameClient, REQUIRE=encounter_workbench, track=encounter_workbench__clientMode)]
def encounter_workbench_track_client_mode(evt : Event;
                                          encounter_workbench__clientMode : int;
                                          var interaction_menu_available : bool&;
                                          var item__useActionAvailable : bool&;
                                          var item__setCustomUsePrompt : das_string)
  let workbenchUsable = (encounter_workbench__clientMode != int(EncounterWorkbenchClientMode.REPAIR))
  item__useActionAvailable = workbenchUsable
  interaction_menu_available = workbenchUsable
  item__setCustomUsePrompt := workbenchUsable ? "" : " "

  let controllerFound = find_query() <| $ [es] (var encounter_workbench_menu_controller__state : int&)
    if encounter_workbench__clientMode == int(EncounterWorkbenchClientMode.REPAIR)
      encounter_workbench_menu_controller__state = int(EncounterWorkbenchMenuState.REPAIR)
    else
      encounter_workbench_menu_controller__state = int(EncounterWorkbenchMenuState.NONE)
    return true

  if !controllerFound
    logerr("encounter_workbench_menu_controller is not found!")



[es(tag=gameClient, REQUIRE=hero, track=human_use_object__selectedObject)]
def track_hero_leave_encounter_workbench(evt : Event;
                                         human_use_object__lastSelectedObject : EntityId;
                                         human_use_object__selectedObject : EntityId)
  if human_use_object__selectedObject == INVALID_ENTITY_ID
    query(human_use_object__lastSelectedObject) <| $ [es(REQUIRE=encounter_workbench)] ()
      find_query() <| $ [es] (var encounter_workbench_menu_controller__state : int&;
                              var encounter_workbench_menu_controller__workbenchEid : EntityId&)
        encounter_workbench_menu_controller__state = int(EncounterWorkbenchMenuState.NONE)
        encounter_workbench_menu_controller__workbenchEid = INVALID_ENTITY_ID
        return true
  else
    query(human_use_object__selectedObject) <| $ [es(REQUIRE=encounter_workbench)] ()
      find_query() <| $ [es] (var encounter_workbench_menu_controller__state : int&;
                              var encounter_workbench_menu_controller__workbenchEid : EntityId&)
        encounter_workbench_menu_controller__state = int(EncounterWorkbenchMenuState.NONE)
        encounter_workbench_menu_controller__workbenchEid = human_use_object__selectedObject
        return true


def update_encounter_workbench_items_to_repair()
  find_query() <| $ [es] (eid aka menu_controller_eid : EntityId;
                          encounter_workbench_menu_controller__state : int;
                          var encounter_workbench_menu_controller__itemsToRepair : EidList)
    if encounter_workbench_menu_controller__state != int(EncounterWorkbenchMenuState.REPAIR)
      return true

    encounter_workbench_menu_controller__itemsToRepair |> clear()

    find_query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid : EntityId)
      find_item_in_actor(hero_eid) <| $(item_eid : EntityId)
        query(item_eid) <| $ [es] (item__hp : float;
                                   item__maxHp : float)
          if ceili(item__hp) < ceili(item__maxHp)
            encounter_workbench_menu_controller__itemsToRepair |> push(item_eid)
        return false
      return true

    sendEvent(menu_controller_eid, EventEncounterWorkbenchItemsToRepairChanged())

    return true


[es(tag=gameClient, track=encounter_workbench_menu_controller__state)]
def encounter_workbench_menu_controller_track_state(evt : Event;
                                                    encounter_workbench_menu_controller__state : int)
  if encounter_workbench_menu_controller__state == int(EncounterWorkbenchMenuState.NONE)
    query() <| $ [es] (var encounter_workbench__clientMode : int&)
      encounter_workbench__clientMode = int(EncounterWorkbenchClientMode.DEFAULT)
  elif encounter_workbench_menu_controller__state == int(EncounterWorkbenchMenuState.REPAIR)
    update_encounter_workbench_items_to_repair()


[es(tag=gameClient)]
def encounter_workbench_menu_request(evt : CmdEncounterWorkbenchMenuRequest;
                                     var encounter_workbench_menu_controller__state : int&)
  encounter_workbench_menu_controller__state = evt.state


[es(tag=gameClient, track=item__hp, on_appear, on_disappear, REQUIRE=(item__hp, item__maxHp, watchedPlayerItem))]
def encounter_workbench_track_hero_item_hp_changed(evt : Event;
                                                   item__humanOwnerEid : EntityId)
  query(item__humanOwnerEid) <| $ [es(REQUIRE=hero)] ()
    update_encounter_workbench_items_to_repair()