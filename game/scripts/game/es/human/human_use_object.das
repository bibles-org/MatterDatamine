require ecs
require strings
require game.es.human.human_use_object_common
require game.es.human_attached_gun_common
require game.events.events
require math.base
require game.utils.team
require zones
require AnimV20
require GeomNodeTree
require DngWeapon
require DngHuman
require DagorMath
require Grid
require RendInst
require CollRes
require Dacoll
require GridCollision
require game.es.grenade_thrower_common
require active_matter.game.es.human_use_object_hint_type_common


[es(tag=server, REQUIRE=human_use_object__selectedObject, REQUIRE_NOT=deadEntity)]
def on_human_use_object_request(evt : HumanUseObjectRequest;
                                eid : EntityId;
                                isDowned : bool = false)
  if !isDowned
    human_use_object(eid, evt.objectEid)


[es(tag=server, REQUIRE=human_use_object__selectedObject, REQUIRE_NOT=deadEntity)]
def on_human_use_alt_object_request(evt : HumanUseAltObjectRequest;
                                    eid : EntityId;
                                    isDowned : bool = false)
  if !isDowned
    human_use_alt_object(eid, evt.objectEid)


[es(on_appear)]
def human_use_object_created_es(evt : Event;
                                animchar : AnimcharBaseComponent;
                                human_use_object__lookNodeName : string;
                                var human_use_object__nodeId : int&)
  if !empty(human_use_object__lookNodeName)
    human_use_object__nodeId = *animchar.nodeTree |> geomtree_findNodeIndex(human_use_object__lookNodeName)


[es(REQUIRE=hero)]
def hero_human_pre_use_object_es(info : UpdateStageInfoAct;
                                 var human_use_object__selectedObject : EntityId&;
                                 var human_use_object__selectedObjectDot : float&;
                                 var human_use_object__lastSelectedObject : EntityId&;
                                 var human_use_object__lookAtSelected, human_use_object__useActionAvailable : bool&;
                                 var customUsePrompt, customUseAltPrompt, actionItemName, human_use_object__blockReason : das_string;
                                 var human_use_object__blockReasonStatusTip : das_string;
                                 var human_use_object__useActionHintType : int&;
                                 var customUsePromptParams, customUseAltPromptParams : Object&)
  human_use_object__lastSelectedObject = human_use_object__selectedObject
  human_use_object__selectedObject = INVALID_ENTITY_ID
  human_use_object__selectedObjectDot = -1.0
  human_use_object__lookAtSelected = false
  human_use_object__useActionAvailable = true
  human_use_object__useActionHintType = int(HumanUseObjectHintType.DEFAULT)
  human_use_object__blockReason := ""
  human_use_object__blockReasonStatusTip := ""
  actionItemName := ""

  customUsePrompt := ""
  customUsePromptParams |> clear()

  customUseAltPrompt := ""
  customUseAltPromptParams |> clear()


[es(REQUIRE=hero)]
def hero_human_final_use_object_sync(act : UpdateStageInfoAct;
                                     human_use_object__selectedObject : EntityId;
                                     var human_use_object__useActionAvailable : bool&;
                                     var customUsePrompt, customUseAltPrompt, actionItemName : das_string&;
                                     var human_use_object__useActionHintType : int&;
                                     var customUsePromptParams, customUseAltPromptParams : Object&)
  query(human_use_object__selectedObject) <| $ [es] (item__useActionAvailable : bool const?;
                                                     item__useActionHintType : int const?;
                                                     item__setCustomUsePrompt : das_string const?;
                                                     item__setCustomUsePromptParams : Object const?;
                                                     item__setCustomUseAltPrompt : das_string const?;
                                                     item__setCustomUseAltPromptParams : Object const?;
                                                     item__name : das_string const?)
    if empty(customUsePrompt)
      if item__setCustomUsePrompt != null
        customUsePrompt := *item__setCustomUsePrompt
      if item__setCustomUsePromptParams != null
        customUsePromptParams := *item__setCustomUsePromptParams

    if empty(customUseAltPrompt)
      if item__setCustomUseAltPrompt != null
        customUseAltPrompt := *item__setCustomUseAltPrompt
      if item__setCustomUseAltPromptParams != null
        customUseAltPromptParams := *item__setCustomUseAltPromptParams

    if empty(actionItemName)
      if item__name != null
        actionItemName := *item__name

    if item__useActionAvailable != null
      human_use_object__useActionAvailable = *item__useActionAvailable
    if item__useActionHintType != null
      human_use_object__useActionHintType = *item__useActionHintType


[es(REQUIRE=hero, after=(hero_human_pre_use_object_es), before=hero_human_final_use_object_sync)]
def hero_human_use_current_vehicle_object_es(info : UpdateStageInfoAct;
                                             isInVehicle : bool = false;
                                             human_anim__vehicleSelected : EntityId = INVALID_ENTITY_ID;
                                             var human_use_object__selectedObject : EntityId&;
                                             var human_use_object__lookAtSelected : bool&)
  if !isInVehicle || !human_anim__vehicleSelected
    return
  human_use_object__selectedObject = human_anim__vehicleSelected
  human_use_object__lookAtSelected = true


// TODO: Rethrowing grenade by foot
// [es(REQUIRE=hero, after=hero_human_pre_use_object_es, before=hero_human_final_use_object_sync)]
// def hero_human_use_grenade_rethrow_object_es(info : UpdateStageInfoAct;
//                                              eid : EntityId;
//                                              human_use_object__lockGrenadeRethrowing : bool = false;
//                                              var human_use_object__selectedObject : EntityId&)
//   // We have something better already
//   if human_use_object__selectedObject != INVALID_ENTITY_ID || human_use_object__lockGrenadeRethrowing
//     return

//   human_use_object__selectedObject = find_rethrowable_grenade(eid)


[es(REQUIRE=hero, after=(hero_human_use_current_vehicle_object_es, hero_human_pre_use_object_es), before=hero_human_final_use_object_sync)]
def hero_human_use_stationary_gun_object_es(info : UpdateStageInfoAct;
                                            eid : EntityId;
                                            human_use_object__useMinMaxDist : float2;
                                            human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                                            human_use_object__lockStationaryGunUse : bool = false;
                                            var human_use_object__selectedObject : EntityId&)
  if human_use_object__selectedObject != INVALID_ENTITY_ID
    return

  let gunEid = find_gun_to_attach(eid, human_use_object__useMinMaxDist.x, false)
  if gunEid != INVALID_ENTITY_ID
    if !human_use_object__lockStationaryGunUse
      human_use_object__selectedObject = gunEid
  elif human_attached_gun__attachedGunEid != INVALID_ENTITY_ID
    human_use_object__selectedObject = human_attached_gun__attachedGunEid


[es(tag=gameClient, track=human_use_object__lookAtSelected, REQUIRE=hero)]
def hero_human_stop_using_on_turned_away(evt : Event;
                                         eid, human_inventory__entityToUse : EntityId;
                                         human_use_object__lookAtSelected : bool)
  if !human_use_object__lookAtSelected
    sendEvent(eid, HumanUseObjectRequest(objectEid = human_inventory__entityToUse))
