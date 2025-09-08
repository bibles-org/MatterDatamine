require ecs
require app
require DngNet
require DngHuman
require game.utils.net_utils
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require game.es.inventory_common
require game.es.interrupt_item_use_common
require game.es.status_tip_common
require game.es.entity_mods_common


let private PREFIX = "TEAMMATE RAISER"


enum CanUseTeammateRaiserResponse
  Approved
  Declined
  NoUseTime
  TargetIsEnemy
  TargetBroken
  TargetNotDowned


def teammate_raiser_use(human_eid : EntityId;
                        item_eid : EntityId;
                        target_eid : EntityId;
                        start_time : float;
                        duration : float;
                        var human_net_phys : HumanActor&)
  inventory_item_prepare_using(human_eid, item_eid, target_eid, start_time, duration)
  human_net_phys.phys.currentState |> human_phys_state_set_stoppedSprint(true)
  sendEventImmediate(item_eid, EventOnItemStartUse(userEid = human_eid, targetEid = target_eid))


def check_teammate_raiser_can_be_used(target_eid : EntityId;
                                      use_time : float;
                                      hero_team : int)
  if use_time <= 0.0f
    return CanUseTeammateRaiserResponse.NoUseTime

  if !doesEntityExist(target_eid)
    return CanUseTeammateRaiserResponse.TargetBroken

  var canUseTeammateRaiser = CanUseTeammateRaiserResponse.Declined
  query(target_eid) <| $ [es(REQUIRE=hitpoints__revivingCount)] (isDowned : bool;
                                                                 team : int)
    canUseTeammateRaiser = CanUseTeammateRaiserResponse.Approved
    if !isDowned
      canUseTeammateRaiser = CanUseTeammateRaiserResponse.TargetNotDowned
    if hero_team != team
      canUseTeammateRaiser = CanUseTeammateRaiserResponse.TargetIsEnemy
  return canUseTeammateRaiser


def create_tip_for_use_teammate_raiser_decline_reason(item : EntityId;
                                                      reason : int;
                                                      declined_from_server : bool = false)
  debug_use_item_decline_reason(item, "{reason}", PREFIX, declined_from_server) // watch in CanUseTeammateRaiserResponse


[es(tag=server)]
def human_raise_teammate_es(evt : CmdUse;
                            eid : EntityId;
                            isDowned : bool)
  if !isDowned
    return
  let reviver = evt.requesterEid
  sendEvent(reviver, RequestUseTeammateRaiser(targetEid = eid))


[es(tag=server, REQUIRE=teammate_raiser)]
def try_teammate_raiser_use_server(evt : RequestUseTeammateRaiser;
                                   eid aka human_eid : EntityId;
                                   human_weap__currentGunEid : EntityId;
                                   human_anim__vehicleSelected : EntityId;
                                   human_inventory__entityToUse : EntityId;
                                   isAlive : bool;
                                   isDowned : bool;
                                   isInVehicle : bool;
                                   human_net_phys__isInAir : bool;
                                   human_inventory__canUseItems : bool;
                                   human_inventory__canHeal : bool;
                                   human_inventory__canLoadCharges : bool;
                                   human_weap_anim__reloadAtTime : float;
                                   item__useTime : float;
                                   team : int;
                                   entity_mod_values : Object;
                                   var human_net_phys : HumanActor&;
                                   item__usageSpeedModAffected : Tag const?)
  var canUseItem = check_human_can_use_item(isAlive, human_inventory__canUseItems, human_inventory__entityToUse)
  if canUseItem != CanUseItemResponse.Approved
    if canUseItem == CanUseItemResponse.OtherItemInUse
      sendEventImmediate(human_eid, EventInterruptItemUse())
    send_net_event(human_eid, ResponseFailureUseTeammateRaiser(reason = int(canUseItem)), target_entity_conn(human_eid))
    return

  let curTime = get_sync_time()
  canUseItem = check_item_can_be_used(human_eid, human_eid, human_weap__currentGunEid, human_anim__vehicleSelected, human_net_phys,
                                      curTime, curTime, human_weap_anim__reloadAtTime, isDowned, human_net_phys__isInAir, isInVehicle,
                                      human_inventory__canHeal, human_inventory__canLoadCharges)
  if canUseItem != CanUseItemResponse.Approved
    send_net_event(human_eid, ResponseFailureUseTeammateRaiser(reason = int(canUseItem)), target_entity_conn(human_eid))
    return

  let canUseTeammateRaiser = check_teammate_raiser_can_be_used(evt.targetEid, item__useTime, team)
  if canUseTeammateRaiser != CanUseTeammateRaiserResponse.Approved
    send_net_event(human_eid, ResponseFailureUseTeammateRaiser(reason = int(CanUseItemResponse.End) + int(canUseTeammateRaiser)), target_entity_conn(human_eid))
    return

  let useTime = get_item_use_time(item__useTime, item__usageSpeedModAffected != null, entity_mod_values)
  teammate_raiser_use(human_eid, human_eid, evt.targetEid, curTime, useTime, human_net_phys)


[es(tag=netClient, REQUIRE=hero)]
def teammate_raiser_on_use_failure(evt : ResponseFailureUseTeammateRaiser;
                                   eid aka human_eid : EntityId)
  inventory_item_reset_using(human_eid)
  let lastCanUseItemResponseCode = int(CanUseItemResponse.End)
  if lastCanUseItemResponseCode <= evt.reason
    create_tip_for_use_teammate_raiser_decline_reason(human_eid, evt.reason - lastCanUseItemResponseCode, true)
  else
    create_tip_for_use_item_decline_reason(human_eid, evt.reason, PREFIX, true)


[es(tag=server, REQUIRE=teammate_raiser)]
def teammate_raiser_used_es(evt : EventOnLootItemUsed)
  query(evt.target) <| $ [es] (var human_breath__timer : float&;
                               var hitpoints__revivingCount : int&;
                               var isDowned : bool&)

    if !isDowned
      return

    isDowned = false
    hitpoints__revivingCount = max(0, hitpoints__revivingCount) + 1
    human_breath__timer = 0f
    send_net_event(evt.target, EventEntityRevived(reviveByTimer = false))
