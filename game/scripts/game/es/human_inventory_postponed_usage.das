require ecs
require app
require DngNet
require DngHuman
require game.events.events_game
require game.events.events_active_matter
require game.events.events
require game.es.human_inventory_postponed_usage_common
require game.es.item_holder_loading_common
require game.es.human_weap_common
require game.es.inventory_common


def is_unarmed_state_locked(eid : EntityId)
  var result = false

  result ||= find_query() <| $ [es] (game_effect__switchToWeaponSlot : int; game_effect__attachedTo : EntityId)
    return game_effect__attachedTo == eid && game_effect__switchToWeaponSlot == int(HUWeaponSlots.EWS_UNARMED)

  return result


def end_postponed_usage(human_eid : EntityId;
                        item_eid : EntityId;
                        human_net_phys : HumanActor;
                        human_weap__previousGunSlot : int;
                        var human_inventory_postponed_usage__state : int&)
  if item_eid != INVALID_ENTITY_ID || human_inventory_postponed_usage__state == int(PostponedUsageState.None)
    return
  human_inventory_postponed_usage__state = int(PostponedUsageState.Ended)
  if is_unarmed_state_locked(human_eid)
    return

  human_inventory_postponed_usage__state = int(PostponedUsageState.None)
  deselect_slot_and_try_switch_to_previous_slot(human_eid, int(HUWeaponSlots.EWS_UNARMED), human_weap__previousGunSlot, human_net_phys)


[es(tag=server)]
def human_inventory_postponed_usage_on_weapon_changed(evt : HumanEquipStateWeaponEquipped;
                                                      eid : EntityId;
                                                      human_inventory__entityToUse : EntityId;
                                                      human_inventory_postponed_usage__useDuration : float;
                                                      var human_net_phys : HumanActor&;
                                                      var human_inventory_postponed_usage__state : int&)

  if int(evt.slot) != int(HUWeaponSlots.EWS_UNARMED) || human_inventory_postponed_usage__state != int(PostponedUsageState.WaitForSwapToUnarmed)
    return

  query(human_inventory__entityToUse) <| $ [es(REQUIRE=item_holder_postponed)] (item_holder_postponed__container : EntityId;
                                                                                item__currentBoxedItemCount : int;
                                                                                item_holder_postponed__itemCount : int;
                                                                                item_holder_postponed__load : bool;
                                                                                item_holder_postponed__searchOtherContainers : bool;
                                                                                item_holder__itemLoadingProcess : string;
                                                                                item__unarmedUsageNoReturnToPreviousSlot : Tag const?;
                                                                                item__unarmedUsage : bool = false)
    if !item__unarmedUsage
      return

    assume weapEquipState = human_net_phys.phys.currentState.weapEquipState
    weapEquipState.progress = 0.0
    weapEquipState.curState = HUWeaponEquipState.EES_EQUIPED
    human_inventory_postponed_usage__state = item__unarmedUsageNoReturnToPreviousSlot == null ? int(PostponedUsageState.WaitForEndOfUsage) : int(PostponedUsageState.None)

    let targetItemEid = human_inventory__entityToUse
    let startTime = get_sync_time()
    inventory_item_prepare_using(eid, targetItemEid, eid, startTime, human_inventory_postponed_usage__useDuration)
    item_holder_start_loading(eid, targetItemEid, item_holder_postponed__container, item_holder_postponed__itemCount,
                              item__currentBoxedItemCount, item_holder_postponed__load, item_holder_postponed__searchOtherContainers, item_holder__itemLoadingProcess)
    targetItemEid |> removeSubTemplate("item_holder_postponed")


[es(tag=gameClient, REQUIRE=hero)]
def human_inventory_postponed_usage_on_weapon_changed_client(evt : HumanEquipStateWeaponEquipped;
                                                             eid : EntityId;
                                                             var human_net_phys : HumanActor&;
                                                             var human_inventory__entityToUse : EntityId&;
                                                             var human_inventory__targetToUse : EntityId&;
                                                             var human_inventory_postponed_usage__state : int&)
  if int(evt.slot) != int(HUWeaponSlots.EWS_UNARMED) || human_inventory_postponed_usage__state != int(PostponedUsageState.WaitForSwapToUnarmed)
    return

  let item = human_inventory__entityToUse
  let target = human_inventory__targetToUse
  assume weapEquipState = human_net_phys.phys.currentState.weapEquipState
  human_inventory__entityToUse = INVALID_ENTITY_ID
  human_inventory__targetToUse = INVALID_ENTITY_ID
  query(item) <| $ [es] (item__unarmedUsageNoReturnToPreviousSlot : Tag const?)
    human_inventory_postponed_usage__state = item__unarmedUsageNoReturnToPreviousSlot == null ? int(PostponedUsageState.WaitForEndOfUsage) : int(PostponedUsageState.None)

  weapEquipState.progress = 0.0
  weapEquipState.curState = HUWeaponEquipState.EES_EQUIPED
  sendEventImmediate(item, TryUseItem(userEid = eid, targetEid = target))


[es(tag=netClient)]
def human_inventory_postponed_usage_on_entity_to_use_changed_net_client(evt : EventItemUseInterrupted;
                                                                        eid : EntityId)
  query(evt.userEid) <| $ [es] (human_net_phys : HumanActor;
                                human_weap__previousGunSlot : int;
                                var human_inventory_postponed_usage__state : int&)
    end_postponed_usage(evt.userEid, eid, human_net_phys, human_weap__previousGunSlot, human_inventory_postponed_usage__state)


[es(tag=server, track=human_inventory__entityToUse)]
def human_inventory_postponed_usage_on_entity_to_use_changed_server(evt : Event;
                                                                    eid : EntityId;
                                                                    human_inventory__entityToUse : EntityId;
                                                                    human_net_phys : HumanActor;
                                                                    human_weap__previousGunSlot : int;
                                                                    var human_inventory_postponed_usage__state : int&)
  end_postponed_usage(eid, human_inventory__entityToUse, human_net_phys, human_weap__previousGunSlot, human_inventory_postponed_usage__state)


[es(tag=gameClient, REQUIRE=hero, track=human_inventory__entityToUse)]
def human_inventory_postponed_usage_on_entity_to_use_changed_client(evt : Event;
                                                                    eid : EntityId;
                                                                    human_inventory__entityToUse : EntityId;
                                                                    human_net_phys : HumanActor;
                                                                    human_weap__previousGunSlot : int;
                                                                    var human_inventory_postponed_usage__state : int&)
  end_postponed_usage(eid, human_inventory__entityToUse, human_net_phys, human_weap__previousGunSlot, human_inventory_postponed_usage__state)
