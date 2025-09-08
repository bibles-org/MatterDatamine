require ecs
require app
require HumanPhys
require DngHuman
require game.events.events
require game.utils.team
require math.base
require inventory
require DngNet
require game.es.inventory_common
require game.events.inventory_events
require game.events.events_active_matter
require game.es.use_query_params_common
require game.events.events_active_matter
require game.es.inventory_weapon_mod_common
require game.es.boxed_ammo_reload_common
require game.es.vehicle.vehicle_seats_common
require game.es.interrupt_item_use_common


def human_inventory_interrupt_item_use_base(cur_time : float;
                                            eid : EntityId;
                                            human_inventory__entityToUse : EntityId;
                                            human_weap__currentGunEid : EntityId;
                                            vehicle_eid : EntityId;
                                            human_net_phys : HumanActor;
                                            ct : HumanControlState;
                                            human_weap_anim__reloadAtTime : float;
                                            human_net_phys__isInAir : bool;
                                            isInVehicle : bool;
                                            isDowned : bool)
  let canUseItem = human_inventory_should_interrupt_item_use(cur_time, eid, human_inventory__entityToUse, vehicle_eid, human_weap__currentGunEid, human_net_phys, ct,
                                                             human_weap_anim__reloadAtTime, human_net_phys__isInAir, isInVehicle, isDowned)
  if canUseItem != CanUseItemResponse.Approved
    sendEventImmediate(eid, EventInterruptItemUse())


[es(tag=gameClient, after=(human_input_es, human_phys_es), before=before_human_inventory_use_update, REQUIRE=hero)]
def human_inventory_interrupt_item_use_es(info : ParallelUpdateFrameDelayed;
                                          eid : EntityId;
                                          human_inventory__entityToUse : EntityId;
                                          human_weap__currentGunEid : EntityId;
                                          human_anim__vehicleSelected : EntityId;
                                          human_net_phys : HumanActor;
                                          human_weap_anim__reloadAtTime : float;
                                          human_net_phys__isInAir : bool;
                                          isInVehicle : bool;
                                          isDowned : bool)
  if !!human_inventory__entityToUse
    human_inventory_interrupt_item_use_base(info.curTime, eid, human_inventory__entityToUse, human_weap__currentGunEid, human_anim__vehicleSelected,
                                            human_net_phys, human_net_phys.phys.producedCT, human_weap_anim__reloadAtTime,
                                            human_net_phys__isInAir, isInVehicle, isDowned)


// item use can stop player on the server. Thus we dont want to interrupt item use on client due to movement
// because movement state sync can happen after the client system will interrupt item use
// we cant ran all checks on server only because it feels terrible on high ping
[es(tag=server, before=(human_weap_es, update_weapon_equip_state), REQUIRE_NOT=disableUpdate)]
def human_inventory_interrupt_item_use_on_post_phys_es(evt : CmdPostPhysUpdate;
                                                       eid : EntityId;
                                                       human_inventory__entityToUse : EntityId;
                                                       human_weap__currentGunEid : EntityId;
                                                       human_anim__vehicleSelected : EntityId;
                                                       human_net_phys : HumanActor;
                                                       human_weap_anim__reloadAtTime : float;
                                                       human_net_phys__isInAir : bool;
                                                       isInVehicle : bool;
                                                       isDowned : bool)
  if !!human_inventory__entityToUse
    if is_interrupted_by_moving(human_net_phys, human_inventory__entityToUse)
      sendEventImmediate(eid, EventInterruptItemUse())
      return
    human_inventory_interrupt_item_use_base(get_sync_time(), eid, human_inventory__entityToUse, human_weap__currentGunEid, human_anim__vehicleSelected,
                                            human_net_phys, human_net_phys.phys.appliedCT, human_weap_anim__reloadAtTime,
                                            human_net_phys__isInAir, isInVehicle, isDowned)



[es(tag=netClient)]
def request_interrupt_item_use_es(evt : EventInterruptItemUse;
                                  eid : EntityId)
  send_net_event(eid, RequestInterruptItemUse())

[es(tag=server)]
def interrupt_item_use_request(evt : RequestInterruptItemUse; eid : EntityId)
  sendEvent(eid, EventInterruptItemUse())


[es(on_event=(EventEnterVehicle, EventEntityDowned, EventEntityDied, EventEntityRevived))]
def interrupt_item_use_on_events(evt : Event; eid : EntityId)
  sendEvent(eid, EventInterruptItemUse())


[es]
def interrupt_item_use_es(evt : EventInterruptItemUse;
                          eid : EntityId;
                          var human_inventory__entityToUse : ecs::EntityId&;
                          var human_inventory__targetToUse : ecs::EntityId&;
                          var human_inventory__entityUseStart : float&;
                          var human_inventory__entityUseEnd : float&;
                          var human_inventory__progressBarEnd : float&;
                          var human_inventory__noInterruptPoint : float&;
                          var human_inventory__entityManualUse : bool&;
                          var human_inventory__savedUseProgress : float&;
                          var human_inventory__usePausedUntilTime : float&)
  if !evt.forced && 0.0 < human_inventory__noInterruptPoint && human_inventory__noInterruptPoint < get_sync_time()
    return

  ecs::query(human_inventory__entityToUse) <| $ [es] (var item__ownerOnUseEffectEid : EntityId&)
    destroyEntity(item__ownerOnUseEffectEid)
    item__ownerOnUseEffectEid = INVALID_ENTITY_ID

  let item = human_inventory__entityToUse
  let startTime = human_inventory__entityUseStart
  human_inventory__entityToUse = INVALID_ENTITY_ID
  human_inventory__targetToUse = INVALID_ENTITY_ID
  human_inventory__entityUseStart = -1.0
  human_inventory__entityUseEnd = -1.0
  human_inventory__progressBarEnd = -1.0
  human_inventory__noInterruptPoint = -1.0
  human_inventory__entityManualUse = false
  human_inventory__savedUseProgress = -1.0
  human_inventory__usePausedUntilTime = -1.0
  sendEvent(item, EventItemUseInterrupted(userEid = eid, startTime = startTime))


[es(tag=server, before=before_human_inventory_use_update)]
def human_interrupt_self_reviving_es(info : ParallelUpdateFrameDelayed;
                                     eid : EntityId;
                                     human_net_phys : HumanActor;
                                     human_inventory__entityUseEnd : float;
                                     isDowned : bool)
  if !isDowned
    return

  let stopRevive = human_net_phys.phys.appliedCT.isMoving
  if stopRevive
    if human_inventory__entityUseEnd > info.curTime
      sendEvent(eid, EventInterruptItemUse())


[es(tag=server, before=before_human_inventory_use_update)]
def human_interrupt_revive_es(info : ParallelUpdateFrameDelayed;
                              eid : EntityId;
                              human_inventory__targetToUse : EntityId;
                              human_reviver__maxDistance : float2;
                              human__aimTm : float3x4)
  if !human_inventory__targetToUse || human_inventory__targetToUse == eid
    return
  query(human_inventory__targetToUse) <| $ [es(REQUIRE=human)] (isAlive, isDowned : bool;
                                                                transform : float3x4)
    let distSq = length_sq(human__aimTm[3] - transform[3])
    if !isAlive || !isDowned || distSq > square(human_reviver__maxDistance.y)
      sendEvent(eid, EventInterruptItemUse())


[es(tag=server, before=before_human_inventory_use_update)]
def human_interrupt_use_entity_to_target_es(info : ParallelUpdateFrameDelayed;
                                            eid : EntityId;
                                            human_inventory__targetToUse : EntityId)
  if !human_inventory__targetToUse || human_inventory__targetToUse == eid
    return

  query(human_inventory__targetToUse) <| $ [es(REQUIRE_NOT=human)] (transform : float3x4)
    let params = get_use_query_params(eid)
    let distSq = length_sq(params.pos - transform[3])
    if distSq > square(params.dist.y)
      sendEvent(eid, EventInterruptItemUse())


[es(tag=server)]
def human_inventory_interrupt_item_use_on_drop_es(evt : EventOnItemDrop;
                                                  eid : EntityId;
                                                  human_inventory__entityToUse : EntityId)
  let droppedItemEid = evt.itemEid
  if droppedItemEid == human_inventory__entityToUse
    sendEventImmediate(eid, EventInterruptItemUse())
