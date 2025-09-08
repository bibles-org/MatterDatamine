require ecs
require ecs.safe
require ecs.common
require dm
require DngDm
require math.base
require vehicle
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require game.events.inventory_events
require game.events.vehicle_events
require game.es.inventory_common
require game.es.repair_common
require DagorSystem


def find_repair_kit(actor_eid : EntityId)
  return find_item_with_comp(actor_eid, "item__isRepairTool")


def set_repairable_state(inProgress; operatorEid; targetEid; repairTimeMult : float  = 1.f; recoveryRatioAdd : float = 0.f)
  query(targetEid) <| $ [es] (var maintainable__operator : EntityId&;
                              var repairable__repairTime : float&;
                              var repairable__repairTotalTime : float&;
                              var repairable__inProgress : bool&;
                              var repairable__recoveryRatio : float&;
                              repairable__baseRepairTotalTime : float;
                              repairable__baseRecoveryRatio : float)
    maintainable__operator = operatorEid
    repairable__inProgress = inProgress
    repairable__recoveryRatio = repairable__baseRecoveryRatio + recoveryRatioAdd
    if repairable__repairTime < 0.f && inProgress
      repairable__repairTotalTime = repairable__baseRepairTotalTime * repairTimeMult
      repairable__repairTime = repairable__repairTotalTime


def stop_repair(maintenance__target)
  set_repairable_state(false, INVALID_ENTITY_ID, maintenance__target)
  return false


def use_repair_kit(maintainable__operator)
  query(maintainable__operator) <| $ [es] (var repair__active : bool&;
                                           var repair__repairKit : EntityId&;
                                           entity_mods__vehicleRepairUsagesPerKit = -1)
    repair__active = false
    if !is_actor_has_item(maintainable__operator, repair__repairKit)
      logerr("[REPAIR] : Actor <{maintainable__operator}> hasn't repair kit <{repair__repairKit}>")
      return
    var isFullyUsed = false
    query(repair__repairKit) <| $ [es] (var repair_kit__useCounter : int&)
      isFullyUsed = entity_mods__vehicleRepairUsagesPerKit <= ++repair_kit__useCounter
    sendEvent(maintainable__operator, EventOnLootUse(itemEid = repair__repairKit))
    if !isFullyUsed
      return
    destroyEntity(repair__repairKit)
    repair__repairKit = INVALID_ENTITY_ID


[es(on_appear)]
def repair_kit_owner_init_es(evt : Event;
                             eid aka actor_eid : EntityId;
                             var repair__hasRepairKit : bool&;
                             var repair__repairKit : EntityId&)
  repair__repairKit = find_repair_kit(actor_eid)
  repair__hasRepairKit = !!repair__repairKit


[es(on_disappear, after=remove_item_from_owners_container_on_destroy, REQUIRE=item__isRepairTool)]
def update_repair_kit_es(evt : Event;
                         item__humanOwnerEid : EntityId)
  query(item__humanOwnerEid) <| $[es] (var repair__hasRepairKit : bool&;
                                       var repair__repairKit : EntityId&)
    repair__repairKit = find_repair_kit(item__humanOwnerEid)
    repair__hasRepairKit = !!repair__repairKit


[es]
def pickup_repair_kit_on_drop_es(evt : EventOnItemDrop;
                                 eid aka actor_eid : EntityId;
                                 var repair__hasRepairKit : bool&;
                                 var repair__repairKit : EntityId&)
  if evt.itemEid == repair__repairKit
    repair__repairKit = find_repair_kit(actor_eid)
    repair__hasRepairKit = !!repair__repairKit
    if !repair__hasRepairKit
      find_query() <| $[es] (eid aka vehicle_eid : EntityId;
                             maintainable__operator : EntityId)
        if maintainable__operator == actor_eid
          sendEvent(actor_eid, CmdStopRepair(target = vehicle_eid))
          return true
        return false


[es]
def pickup_repair_kit_on_pickup_es(evt : EventOnItemPickup;
                                   var repair__hasRepairKit : bool&;
                                   var repair__repairKit : EntityId&)
  if !repair__hasRepairKit && has(evt.itemEid, "item__isRepairTool")
    repair__hasRepairKit = true
    repair__repairKit = evt.itemEid


[es(on_appear, track=item__containerOwnerEid, REQUIRE=item__isRepairTool, tag=server)]
def repair_kit_init_es(evt : Event; eid : EntityId; item__containerOwnerEid : EntityId)
  query(item__containerOwnerEid) <| $ [es] (var repair__hasRepairKit : bool&; var repair__repairKit : EntityId&)
    repair__hasRepairKit = true
    repair__repairKit = eid


[es(tag=server)]
def need_repair_check_on_part_damaged_es(evt : EventOnPartDamaged; var repairable__repairRequired : bool&)
  if int(evt.hpFixed) == 0
    repairable__repairRequired = true


[es(tag=server)]
def need_repair_check_on_volumetric_damaged_es(evt : EventOnVolumetricDamage; var repairable__repairRequired : bool&)
  for part in evt.damagedParts
    if (part as Object)?.hpFixed ?? -1 == 0
      repairable__repairRequired = true
      break


[es(tag=server)]
def need_repair_check_on_meta_part_damage_es(evt : EventOnMetaPartDamage; var repairable__repairRequired : bool&)
  if evt.damage > 0.f
    repairable__repairRequired = true


[es(tag=server)]
def repair_es(evt : CmdStartRepair;
              eid : EntityId;
              burning__isBurning : bool;
              var repair__active : bool&;
              entity_mods__vehicleRepairTimeMult : float = 1.f;
              entity_mods__vehicleRepairRecoveryRatioAdd : float = 0.f)
  if !burning__isBurning
    repair__active = true
    set_repairable_state(true, eid, evt.target, entity_mods__vehicleRepairTimeMult, entity_mods__vehicleRepairRecoveryRatioAdd)


[es(REQUIRE=maintenance__target)]
def repair_stop_es(evt : CmdStopRepair; var repair__active : bool&)
  repair__active = stop_repair(evt.target)


[es(tag=server, no_order)]
def check_repairing_distance_es(info : ParallelUpdateFrameDelayed;
                                maintenance__target : EntityId;
                                var repair__active : bool&;
                                transform : float3x4;
                                repair__effectiveDistance : float)
  if !repair__active
    return
  var targetPosition : float3
  query(maintenance__target) <| $ [es] (transform : float3x4)
    targetPosition = transform[3]
  if length_sq(targetPosition - transform[3]) > square(repair__effectiveDistance)
    repair__active = stop_repair(maintenance__target)


[es(tag=server, before=find_maintainable_object_event)]
def stop_repairing_on_enter_vehicle_es(evt : EventEnterVehicle;
                                       maintenance__target : EntityId;
                                       var maintenance__hasTarget : bool&;
                                       var repair__active : bool&;
                                       isInVehicle = false)
  if !isInVehicle || !repair__active
    return
  repair__active = stop_repair(maintenance__target)
  maintenance__hasTarget = false


[es(tag=server, no_order)]
def repair_external_es(info : ParallelUpdateFrameDelayed;
                       eid : EntityId;
                       var damage_model : DamageModel&;
                       var meta_parts_state : MetaPartsState&;
                       var fire_protection : FireProtection&;
                       repairable__recoveryRatio : float;
                       maintainable__operator : EntityId;
                       var repairable__repairTime : float&;
                       var repairable__inProgress : bool&;
                       var repairable__repairRequired : bool&)
  if !maintainable__operator || repairable__repairTime < 0.f
    return
  repairable__repairTime = repairable__repairTime - info.dt
  if repairable__repairTime > 0.f
    return
  repairable__inProgress = false
  repairable__repairRequired = false
  repair_vehicle(repairable__recoveryRatio, meta_parts_state, damage_model, fire_protection)
  use_repair_kit(maintainable__operator)
  sendEvent(maintainable__operator, CmdStopRepair(target = eid))
  sendEvent(eid, CmdStopBurn())
  sendEvent(eid, EventOnRepaired(eid = maintainable__operator))


[es(on_event=EventOnRepaired)]
def on_repair_phys_wakeup_es(evt : Event; var vehicle_net_phys : VehiclePhysActor)
  vehicle_net_phys.phys |> wakeUp()


[es(track=repair__active)]
def forbid_allow_use_item_whiile_repair_es(evt : Event;
                                           repair__active : bool;
                                           var human_inventory__canUseItems : bool&)
  human_inventory__canUseItems = !repair__active