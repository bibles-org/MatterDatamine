require ecs
require ecs.common
require ecs.safe
require math.base
require math.random
require math.color
require HumanPhys
require DagorSystem
require DagorMath
require AnimV20
require GeomNodeTree
require game.es.ecs_common
require game.events.events_active_matter
require game.events.events
require game.utils.spawn
require game.es.inventory_item_common
require game.es.inventory_weapon_common
require game.es.inventory_equipment_common
require game.es.inventory_equipment_mod_common
require game.es.equipment_generator_common
require game.es.item_equip_common
require game.es.ability_common
require DngNet

let LOG_TAG = "[MONSTRIFY]"

def wake_me_up_when_monstrify_controller_prereq_are_loaded(eid : EntityId)
  var prereqLoaded = false
  find_query() <| $ [es] (level__levelLoaded : bool;
                          level__movingZoneAppeared : bool;
                          level__movingZoneInited : bool;
                          level__gameObjectsEntitiesCreated : bool;
                          var level__retriggerEids : EidList)
    prereqLoaded = level__levelLoaded && level__gameObjectsEntitiesCreated && (level__movingZoneInited || !level__movingZoneAppeared)
    if !prereqLoaded
      level__retriggerEids |> push(eid)
    return true
  return !prereqLoaded


[es(tag=server, on_appear, on_event=EventRetriggerEntity)]
def activate_monstrify_trap_controlle(evt : Event;
                                      eid : EntityId;
                                      monstrify_trap_controller__group : string;
                                      monstrify_trap_controller__activeCount : int)
  if wake_me_up_when_monstrify_controller_prereq_are_loaded(eid)
    return

  var traps : array<EntityId>
  query() <| $ [es] (monstrify_trap__group : string; eid : EntityId)
    if monstrify_trap_controller__group == monstrify_trap__group
      traps |> push(eid)
  //if length(traps) < monstrify_trap_controller__activeCount
  //  logerr("{LOG_TAG} Not enough monstrify traps: {length(traps)} / {monstrify_trap_controller__activeCount}. {getEntityTemplateName(eid)} group: '{monstrify_trap_controller__group}'")
  if length(traps) > monstrify_trap_controller__activeCount
    shuffle(traps)
    for idx in range(0, length(traps) - monstrify_trap_controller__activeCount)
      destroyEntity(traps[idx])
  print("{LOG_TAG} {getEntityTemplateName(eid)} finished processing group '{monstrify_trap_controller__group}'")


[es(tag=server)]
def activate_monstrify_trap_controller(evt : EventTrapIsTriggered;
                                       eid : EntityId;
                                       monstrify_trap_controller__group : string;
                                       monstrify_trap_controller__maxTriggerCount : int;
                                       var monstrify_trap_controller__triggerCount : int&)
  query(evt.trapEid) <| $ [es] (monstrify_trap__group : string)
    if monstrify_trap__group == monstrify_trap_controller__group
      monstrify_trap_controller__triggerCount++
      if monstrify_trap_controller__maxTriggerCount <= monstrify_trap_controller__triggerCount
        print("{LOG_TAG} {getEntityTemplateName(eid)} max triggeres reached for group '{monstrify_trap_controller__group}'")
        query() <| $ [es] (monstrify_trap__group aka monstrify_trap__group2 : string; eid aka trap_eid : EntityId)
          if monstrify_trap__group2 == monstrify_trap_controller__group
            destroyEntity(trap_eid)


[es(tag=server)]
def monstrify_trap_trigger(evt : EventTrapTrigger;
                           monstrify_trap__sequenceTemplate : string)
  createEntity(monstrify_trap__sequenceTemplate) <| $(var init : ComponentsInitializer)
    init |> set("game_effect__attachedTo", evt.activatorEid)


[es(tag=server, on_appear)]
def monstrify_effect(evt : Event;
                     game_effect__attachedTo : EntityId;
                     monstrify_effect__template : string)
  query(game_effect__attachedTo) <| $ [es] (transform : float3x4;
                                            possessedByPlr : EntityId;
                                            am_storage__value : int)
    query(possessedByPlr) <| $ [es] (var initialHeroItems : Array)
      for entity in initialHeroItems
        var entityObj = getRW_ecs_object(entity)
        if entityObj != null
          let slotName = *entityObj |> get_string("slotName", "")
          if slotName == "equipment_chronogene_primary_1"
            let initialHeroSuit := *entityObj |> get_string("templateName", "")
            *entityObj |> set("initialTemplateName", initialHeroSuit)
            *entityObj |> set("templateName", monstrify_effect__template)
            break

    spawn_monster_soldier(possessedByPlr, monstrify_effect__template, transform, am_storage__value)
    destroy_included_quest_items(possessedByPlr)
    sendEventImmediate(game_effect__attachedTo, CmdTriggerSafepackDrop())
    undress_soldier(game_effect__attachedTo)
    destroyEntity(game_effect__attachedTo)


[es(tag=server, REQUIRE=player_controlled_monster, track=isAlive)]
def change_initial_suit_on_monster_death(evt : Event;
                                         isAlive : bool;
                                         possessedByPlr : EntityId)
  if isAlive
    return
  query(possessedByPlr) <| $ [es] (var initialHeroItems : Array)
    for entity in initialHeroItems
      var entityObj = getRW_ecs_object(entity)
      if entityObj != null
        let slotName = *entityObj |> get_string("slotName", "")
        if slotName == "equipment_chronogene_primary_1"
          let initialHeroSuit := *entityObj |> get_string("initialTemplateName", "")
          *entityObj |> set("templateName", initialHeroSuit)
          break


def destroy_included_quest_items(possessedByPlr)
  query() <| $ [es(REQUIRE=includedQuestItem)] (eid aka item_eid, quest_item__playerEid : EntityId)
    if quest_item__playerEid == possessedByPlr
      query(item_eid) <| $ [es] (var quest_item__playerEid : EntityId&)
        quest_item__playerEid = INVALID_ENTITY_ID // Entity removal is not instantaneous. That's why we unbind it from the player
        destroyEntity(item_eid)


def undress_soldier(soldier_eid : EntityId)
  query(soldier_eid) <| $ [es] (var human_equipment__slots : Object&; var itemContainer : EidList)
    for weaponSlotIdx in range(int(HUWeaponSlots.EWS_NUM))
      unequip_weapon_from_slot(weaponSlotIdx, soldier_eid)

    for equipmentSlot in human_equipment__slots
      let slotItemEid = get_Eid(equipmentSlot.value) ?? INVALID_ENTITY_ID
      query(slotItemEid) <| $ [es] (equipment_mods__curModInSlots : Object const?;
                                    item__dontUnequipOnDeath : Tag const?;
                                    cortical_vault : Tag const?)
        if cortical_vault != null
          destroyEntity(slotItemEid)
          return

        if equipment_mods__curModInSlots != null
          var items_to_move : array<EntityId>
          for subMod in *equipment_mods__curModInSlots
            let modItem = get_Eid(subMod.value) ?? INVALID_ENTITY_ID
            if modItem != INVALID_ENTITY_ID
              items_to_move |> push(modItem)
          for modItem in items_to_move
            unequip_equipment_mod_from_slot(modItem, slotItemEid, soldier_eid, INVALID_ENTITY_ID)
        if item__dontUnequipOnDeath != null
          return

        unequip_equipment_from_slot(equipmentSlot.key, soldier_eid)

    var items_to_move : array<EntityId>
    for itemEid in itemContainer
      if !has(itemEid, "includedQuestItem")
        items_to_move |> push(itemEid)
    for itemEid in items_to_move
      drop_item_from_inventory_container(itemEid, soldier_eid)

    itemContainer |> clear()


[es(tag=gameClient, no_order, REQUIRE=watchedByPlr)]
def update_hunter_vision(act : ParallelUpdateFrameDelayed;
                         eid  : EntityId;
                         transform aka origin_transform : float3x4;
                         hunter_vision__effectTemplate : string;
                         hunter_vision__interval : float;
                         var hunter_vision__updateAt : float&)
  if act.curTime > hunter_vision__updateAt
    hunter_vision__updateAt = act.curTime + hunter_vision__interval

    let key = "{eid}"
    query() <| $ [es(REQUIRE_NOT=(watchedByPlr, player_controlled_monster, deadEntity))] (transform aka t_transform : float3x4;
                                                                                          hunter_vision_target__radius : float;
                                                                                          hunter_vision_target__keepFxUntil : Object;
                                                                                          hunter_vision_target__destroyTemplate : string;
                                                                                          var hunter_vision_target__fxEid : EntityId&)
      let dst = distance(t_transform[3], origin_transform[3])
      let fxUntil = get_float(hunter_vision_target__keepFxUntil, key) ?? 0.0
      if dst > hunter_vision_target__radius && fxUntil < act.curTime
        if hunter_vision_target__fxEid != INVALID_ENTITY_ID
          addSubTemplate(hunter_vision_target__fxEid, hunter_vision_target__destroyTemplate)
          hunter_vision_target__fxEid = INVALID_ENTITY_ID
        return
      if hunter_vision_target__fxEid == INVALID_ENTITY_ID
        hunter_vision_target__fxEid = createEntity(hunter_vision__effectTemplate) <| $(init)
          var tm = IDENT_TM
          tm[3] = t_transform[3]
          init |> set("transform", tm)


[es(on_disappear, REQUIRE=(hunter_vision__effectTemplate, watchedByPlr))]
def remove_hunter_vision_fx(evt : Event)
  query() <| $ [es] (var hunter_vision_target__fxEid : EntityId&)
    if hunter_vision_target__fxEid != INVALID_ENTITY_ID
      destroyEntity(hunter_vision_target__fxEid)
      hunter_vision_target__fxEid = INVALID_ENTITY_ID


[es(tag=gameClient, on_disappear)]
def remove_hunter_vision_fx_on_target_destroyed(evt : Event; hunter_vision_target__fxEid : EntityId)
  if hunter_vision_target__fxEid != INVALID_ENTITY_ID
    destroyEntity(hunter_vision_target__fxEid)


[es(tag=gameClient, on_appear)]
def hunter_vision_fx_node_init(evt : Event;
                               animchar : AnimcharBaseComponent;
                               hunter_vision_target__fxNodeName : string;
                               var hunter_vision_target__fxNodeId : int&)
  hunter_vision_target__fxNodeId = geomtree_findNodeIndex(*animchar.nodeTree, hunter_vision_target__fxNodeName)


[es(tag=gameClient)]
def update_hunter_vision_fx_pos(act : ParallelUpdateFrameDelayed;
                                animchar : AnimcharBaseComponent;
                                hunter_vision_target__fxEid : EntityId;
                                hunter_vision_target__fxNodeId : int)
  query(hunter_vision_target__fxEid) <| $ [es] (var transform : float3x4)
    var rootTm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, hunter_vision_target__fxNodeId, rootTm)
    transform[3] = rootTm[3]


[es(tag=gameClient, on_appear, REQUIRE=deadEntity)]
def destroy_hunter_visin_fx_on_death(evt : Event;
                                     var hunter_vision_target__fxEid : EntityId&;
                                     var hunter_vision_target__keepFxUntil : Object;
                                     hunter_vision_target__destroyTemplate : string)
  if hunter_vision_target__fxEid != INVALID_ENTITY_ID
    addSubTemplate(hunter_vision_target__fxEid, hunter_vision_target__destroyTemplate)
    hunter_vision_target__fxEid = INVALID_ENTITY_ID
  clear(hunter_vision_target__keepFxUntil)


[es(tag=server)]
def on_monstrify_artifact_used(evt : EventOnLootItemUsed; monstrify_artifact__sequenceTemplate : string)
  createEntity(monstrify_artifact__sequenceTemplate) <| $(var init : ComponentsInitializer)
    init |> set("game_effect__attachedTo", evt.target)


[es(tag=server, REQUIRE=monstrify_artifact__sequenceTemplate)]
def on_monstrify_artifact_use_alt(evt : CmdUseAlt; eid : EntityId; monstrify_artifact__sequenceTemplate : string)
  if !has(evt.requesterEid, "player_controlled_monster", ecs_hash("player_controlled_monster"))
    createEntity(monstrify_artifact__sequenceTemplate) <| $(var init : ComponentsInitializer)
      init |> set("game_effect__attachedTo", evt.requesterEid)
    destroyEntity(eid)


[es(tag=server, after=init_item_created_by_zone, on_appear, REQUIRE=item_created_by_zone)]
def monstrify_artifact_usability(evt : Event;
                                 eid : EntityId;
                                 monstrify_artifact__usableSubTemplate : string)
  remote_add_sub_template(eid, monstrify_artifact__usableSubTemplate)


[es(tag=gameClient, on_appear, track=isAlive, REQUIRE=(player_controlled_monster, hero))]
def monstrify_artifact_usability_on_client(evt : Event;
                                           isAlive : bool)
  query() <| $[es] (eid aka artifact_eid : EntityId;
                    monstrify_artifact__usableSubTemplate : string)
    if !isAlive
      addSubTemplate(artifact_eid, monstrify_artifact__usableSubTemplate)
    else
      removeSubTemplate(artifact_eid, monstrify_artifact__usableSubTemplate)


[es(tag=gameClient, no_order)]
def update_monstrify_artifact_position(upd : UpdateStageInfoAct;
                                       eid : EntityId;
                                       monstrify_artifact__updateInterval : float2;
                                       monstrify_artifact__updatePositionAllowed : bool;
                                       var monstrify_artifact__updatePositionAt : float&)
  if upd.curTime < monstrify_artifact__updatePositionAt || !monstrify_artifact__updatePositionAllowed
    return

  monstrify_artifact__updatePositionAt = upd.curTime + rnd_float(monstrify_artifact__updateInterval)
  sendEvent(eid, EventUpdateMonstrifyPosition())


[es(tag=server, no_order)]
def monstrify_artifact_wait_delay(upd : UpdateStageInfoAct;
                                  eid : EntityId;
                                  monstrify_artifact_manager__startDelayUpdatePos : float)
  if monstrify_artifact_manager__startDelayUpdatePos > upd.curTime
    return
  query() <| $[es] (var monstrify_artifact__updatePositionAllowed : bool&)
    monstrify_artifact__updatePositionAllowed = true
  destroyEntity(eid)


[es(tag=gameClient, on_disappear)]
def assistant_phrase_monstrify_artifact_appear_on_map(evt : Event;
                                                      monstrify_artifact_manager__scriptName : string)
  if monstrify_artifact_manager__scriptName == ""
    return
  find_query() <| $[es(REQUIRE_NOT=player_controlled_monster, REQUIRE=watchedByPlr)] (possessedByPlr : EntityId)
    sendEvent(possessedByPlr, CmdStartAssistantSpeak(scriptName = monstrify_artifact_manager__scriptName, skipBeepSound = true))
    return true


[es(tag=server, on_appear)]
def monstrify_suit_effect_on_appear(evt : Event;
                                    game_effect__attachedTo : EntityId;
                                    monstrify_suit_effect__suits : Array;
                                    monstrify_suit_effect__affectTemplate : string)
  if length(monstrify_suit_effect__suits) == 0
    logerr("{get_entity_info(game_effect__attachedTo)}: monstrify_suit_effect__suits is empty!")
    return

  var totalWeight = 0.0
  for data in monstrify_suit_effect__suits
    totalWeight += (data as Object)?.weight ?? 0.0

  if totalWeight > 0.0
    let rnd = gfrnd() * totalWeight

    var weight = 0.0
    for data in monstrify_suit_effect__suits
      let suitData = data as Object
      weight += suitData?.weight ?? 0.0
      if weight >= rnd

        let suitItemTemplate = suitData?.suitItem ?? ""

        // Destroy previous suit
        find_query() <| $ [es(REQUIRE=item__chronogene)] (eid aka suit_eid : EntityId;
                                                          slot_attach__slotName : string;
                                                          item__humanOwnerEid : EntityId)
          if item__humanOwnerEid != game_effect__attachedTo || slot_attach__slotName != "suit"
            return false
          destroyEntity(suit_eid)
          return true

        // Create new suit
        create_item_in_equipment(suitItemTemplate, "chronogene_primary_1", game_effect__attachedTo) <| $(var init : ComponentsInitializer)
          init |> set("slotName", "suit")
          init |> set("item__humanOwnerEid", game_effect__attachedTo)

        if monstrify_suit_effect__affectTemplate != ""
          createEntity(monstrify_suit_effect__affectTemplate) <| $(var init : ComponentsInitializer)
            init |> set("game_effect__attachedTo", game_effect__attachedTo)

        break
