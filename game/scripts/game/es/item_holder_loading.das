require app
require ecs
require ecs.safe
require math.random
require net
require DngNet
require DngHuman
require game.es.ecs_common
require game.events.events
require game.events.events_game
require DagorSystem
require DagorConsole
require game.utils.net_utils
require game.events.inventory_events
require game.events.events_active_matter
require game.es.boxed_item_common
require game.es.status_tip_common
require game.es.inventory_checks_common
require game.es.item_holder_loading_common
require game.es.inventory_common
require game.es.interrupt_item_use_common
require game.es.human_inventory_postponed_usage_common
require game.es.level_common
require game.es.entity_mods_common


let private PREFIX = "ITEM HOLDER"


enum CanUseHolderItemResponse
  Approved
  Declined
  NoUseTime
  FullHolder
  EmptyHolder
  NoAmmoToLoad
  NoStorageToUnload
  NotOnBase


def create_tip_for_use_holder_decline_reason(item : EntityId;
                                             reason : int;
                                             item_holder__noAmmoToLoadTip : string)
  debug_use_item_decline_reason(item, "{reason}", PREFIX, true)
  if reason == int(CanUseHolderItemResponse.NoAmmoToLoad)
    create_status_tip(item_holder__noAmmoToLoadTip)
  elif reason == int(CanUseHolderItemResponse.NoStorageToUnload)
    create_status_tip("status_tip_item_unloading_failed_by_capacity")


def find_boxed_item_to_draw_from_in_inventories(wish_to_load : bool;
                                                item_holder__searchOtherContainers : bool;
                                                item_holder__boxedItemTemplate : string;
                                                inventories_owner__inventoryEids : EidList;
                                                var item_loading__targetContainer : EntityId&)
  var boxedItemEid = INVALID_ENTITY_ID
  query(item_loading__targetContainer) <| $ [es] (itemContainer aka main_itemContainer : EidList)
    boxedItemEid = find_boxed_item_to_draw_from(item_holder__boxedItemTemplate, main_itemContainer)
    if boxedItemEid == INVALID_ENTITY_ID && wish_to_load && item_holder__searchOtherContainers
      for inventory in inventories_owner__inventoryEids
        query(inventory) <| $ [es] (itemContainer aka other_itemContainer : EidList)
          boxedItemEid = find_boxed_item_to_draw_from(item_holder__boxedItemTemplate, other_itemContainer)
        if boxedItemEid != INVALID_ENTITY_ID
          item_loading__targetContainer = inventory
          break
  return boxedItemEid


def calculate_boxed_item_to_draw_amount_from(wish_boxed_item : string;
                                             item_container : EidList)
  var itemCount = 0
  for item in item_container
    query(item) <| $ [es] (boxed_item__template : string;
                           item__currentBoxedItemCount : int)
      if wish_boxed_item == boxed_item__template
        itemCount += item__currentBoxedItemCount
  return itemCount


def calculate_boxed_item_to_draw_amount_in_inventories(item_holder__searchOtherContainers : bool;
                                                       item_holder__boxedItemTemplate : string;
                                                       inventories_owner__inventoryEids : EidList;
                                                       item_loading__targetContainer : EntityId)
  var itemCount = 0
  if item_holder__searchOtherContainers
    for inventory in inventories_owner__inventoryEids
      query(inventory) <| $ [es] (itemContainer aka other_itemContainer : EidList)
        itemCount += calculate_boxed_item_to_draw_amount_from(item_holder__boxedItemTemplate, other_itemContainer)
  else
    query(item_loading__targetContainer) <| $ [es] (itemContainer aka main_itemContainer : EidList)
      itemCount += calculate_boxed_item_to_draw_amount_from(item_holder__boxedItemTemplate, main_itemContainer)
  return itemCount


[es(tag=gameClient, REQUIRE=hero)]
def item_holder_on_use_request_failure(evt : ResponseFailureUseItemHolder)
  let lastCanUseItemResponseCode = int(CanUseItemResponse.End)
  if lastCanUseItemResponseCode <= evt.reason
    query(evt.itemEid) <| $ [es] (item_holder__noAmmoToLoadTip : string)
      create_tip_for_use_holder_decline_reason(evt.itemEid, evt.reason - lastCanUseItemResponseCode, item_holder__noAmmoToLoadTip)
  else
    create_tip_for_use_item_decline_reason(evt.itemEid, evt.reason, PREFIX, true)


[es(tag=server)]
def item_holder_request_interrupt_use(evt : RequestInterruptUseItemHolder;
                                      eid : EntityId;
                                      human_inventory__entityToUse : EntityId)
  if human_inventory__entityToUse != INVALID_ENTITY_ID && has(human_inventory__entityToUse, "item_holder")
    sendEvent(eid, EventInterruptItemUse())


[es(tag=server)]
def item_holder_request_load(evt : RequestLoadItemHolder;
                             eid : EntityId;
                             human_weap__currentGunEid : EntityId;
                             human_anim__vehicleSelected : EntityId;
                             human_inventory__entityToUse : EntityId;
                             inventories_owner__inventoryEids : EidList;
                             isAlive : bool;
                             isDowned : bool;
                             isInVehicle : bool;
                             human_net_phys__isInAir : bool;
                             human_inventory__canUseItems : bool;
                             human_inventory__canHeal : bool;
                             human_inventory__canLoadCharges : bool;
                             human_weap_anim__reloadAtTime : float;
                             entity_mod_values : Object;
                             var human_net_phys : HumanActor&;
                             var human_inventory__entityUseStart : float&;
                             var human_inventory__entityUseEnd : float&;
                             var human_inventory_postponed_usage__state : int&;
                             var human_inventory_postponed_usage__useDuration : float&;
                             human_inventory__itemHolderLoadingMult : float = 1.0)
  item_holder_start_process(eid, evt.targetItemEid, evt.containerEid, human_weap__currentGunEid, human_anim__vehicleSelected,
                            human_inventory__entityToUse, inventories_owner__inventoryEids,
                            true, evt.searchOtherContainers, isAlive, isDowned, isInVehicle, human_net_phys__isInAir, human_inventory__canUseItems, human_inventory__canHeal, human_inventory__canLoadCharges, human_weap_anim__reloadAtTime,
                            entity_mod_values, human_net_phys, human_inventory__entityUseStart, human_inventory__entityUseEnd,
                            human_inventory_postponed_usage__state, human_inventory_postponed_usage__useDuration, human_inventory__itemHolderLoadingMult)


[es(tag=server)]
def item_holder_request_unload(evt : RequestUnloadItemHolder;
                               eid : EntityId;
                               human_weap__currentGunEid : EntityId;
                               human_anim__vehicleSelected : EntityId;
                               human_inventory__entityToUse : EntityId;
                               inventories_owner__inventoryEids : EidList;
                               isAlive : bool;
                               isDowned : bool;
                               isInVehicle : bool;
                               human_net_phys__isInAir : bool;
                               human_inventory__canUseItems : bool;
                               human_inventory__canHeal : bool;
                               human_inventory__canLoadCharges : bool;
                               human_weap_anim__reloadAtTime : float;
                               entity_mod_values : Object;
                               var human_net_phys : HumanActor&;
                               var human_inventory__entityUseStart : float&;
                               var human_inventory__entityUseEnd : float&;
                               var human_inventory_postponed_usage__state : int&;
                               var human_inventory_postponed_usage__useDuration : float&;
                               human_inventory__itemHolderLoadingMult : float = 1.0)
  item_holder_start_process(eid, evt.targetItemEid, evt.containerEid, human_weap__currentGunEid, human_anim__vehicleSelected,
                            human_inventory__entityToUse, inventories_owner__inventoryEids,
                            false, false, isAlive, isDowned, isInVehicle, human_net_phys__isInAir, human_inventory__canUseItems, human_inventory__canHeal, human_inventory__canLoadCharges, human_weap_anim__reloadAtTime,
                            entity_mod_values, human_net_phys, human_inventory__entityUseStart, human_inventory__entityUseEnd,
                            human_inventory_postponed_usage__state, human_inventory_postponed_usage__useDuration, human_inventory__itemHolderLoadingMult)


def item_holder_start_process(human_eid : EntityId;
                              target_item_eid : EntityId;
                              container_eid : EntityId;
                              human_weap__currentGunEid : EntityId;
                              human_anim__vehicleSelected : EntityId;
                              human_inventory__entityToUse : EntityId;
                              inventories_owner__inventoryEids : EidList;
                              load : bool;
                              search_other_containers : bool;
                              isAlive : bool;
                              isDowned : bool;
                              isInVehicle : bool;
                              human_net_phys__isInAir : bool;
                              human_inventory__canUseItems : bool;
                              human_inventory__canHeal : bool;
                              human_inventory__canLoadCharges : bool;
                              human_weap_anim__reloadAtTime : float;
                              entity_mod_values : Object;
                              var human_net_phys : HumanActor&;
                              var human_inventory__entityUseStart : float&;
                              var human_inventory__entityUseEnd : float&;
                              var human_inventory_postponed_usage__state : int&;
                              var human_inventory_postponed_usage__useDuration : float&;
                              human_inventory__itemHolderLoadingMult : float)
  var canUseItem = check_human_can_use_item(isAlive, human_inventory__canUseItems, human_inventory__entityToUse)
  if canUseItem != CanUseItemResponse.Approved
    if canUseItem == CanUseItemResponse.OtherItemInUse
      sendEvent(human_eid, EventInterruptItemUse())
    send_net_event(human_eid, ResponseFailureUseItemHolder(itemEid = target_item_eid, reason = int(canUseItem)), target_entity_conn(human_eid))
    return

  let curTime = get_sync_time()
  canUseItem = check_item_can_be_used(human_eid, target_item_eid, human_weap__currentGunEid, human_anim__vehicleSelected, human_net_phys,
                                      curTime, curTime, human_weap_anim__reloadAtTime, isDowned, human_net_phys__isInAir, isInVehicle,
                                      human_inventory__canHeal, human_inventory__canLoadCharges)
  if canUseItem != CanUseItemResponse.Approved
    send_net_event(human_eid, ResponseFailureUseItemHolder(itemEid = target_item_eid, reason = int(canUseItem)), target_entity_conn(human_eid))
    return

  var canUseHolder = CanUseHolderItemResponse.Declined
  query(target_item_eid) <| $ [es] (item_holder__loadTimePerItem : float;
                                    item_holder__loadInOutTime : float2;
                                    item_holder__unloadTimePerItem : float;
                                    item_holder__unloadInOutTime : float2;
                                    item__currentBoxedItemCount : int;
                                    item_holder__maxItemCount : int;
                                    item_holder__boxedItemTemplate : string;
                                    item_holder__itemLoadingProcess : string;
                                    item__usageSpeedModAffected : Tag const?;
                                    item_holder__canLoadOnlyOnBase : Tag const?;
                                    var item__unarmedUsage : bool?)
    var itemCount = load ? item_holder__maxItemCount - item__currentBoxedItemCount : item__currentBoxedItemCount
    if itemCount == 0
      canUseHolder = load ? CanUseHolderItemResponse.FullHolder : CanUseHolderItemResponse.EmptyHolder
      return

    if item_holder__canLoadOnlyOnBase != null && !is_player_base()
      canUseHolder = CanUseHolderItemResponse.NotOnBase
      return

    if load
      let availableItemCount = calculate_boxed_item_to_draw_amount_in_inventories(search_other_containers, item_holder__boxedItemTemplate, inventories_owner__inventoryEids, container_eid)
      if availableItemCount == 0
        canUseHolder = CanUseHolderItemResponse.NoAmmoToLoad
        return
      elif availableItemCount < itemCount
        itemCount = availableItemCount
    else
      if get_boxed_item_count_to_fit_inventory(container_eid, item_holder__boxedItemTemplate, 1) <= 0 // can put single item
        send_net_event(human_eid, EventCapacityExceeded(containerEid = container_eid), target_entity_conn(human_eid))
        canUseHolder = CanUseHolderItemResponse.NoStorageToUnload
        return

    if human_inventory__itemHolderLoadingMult >= 1e3 && item__unarmedUsage != null
      // Skip unarmed for instant reloads
      *item__unarmedUsage = false

    let invItemHolderLoadingMult = safeinv(human_inventory__itemHolderLoadingMult)
    let inTime = (load ? item_holder__loadInOutTime.x : item_holder__unloadInOutTime.x) * invItemHolderLoadingMult
    let loadingTime = float(itemCount) * (load ? item_holder__loadTimePerItem : item_holder__unloadTimePerItem) * invItemHolderLoadingMult
    let outTime = (load ? item_holder__loadInOutTime.y : item_holder__unloadInOutTime.y) * invItemHolderLoadingMult

    let useTime = inTime + get_item_use_time(loadingTime, item__usageSpeedModAffected != null, entity_mod_values) + outTime
    if useTime <= 0.0
      canUseHolder = CanUseHolderItemResponse.NoUseTime
      return

    inventory_item_prepare_using(human_eid, target_item_eid, human_eid, curTime, useTime)
    let isUnarmedUsage = item__unarmedUsage != null && *item__unarmedUsage
    if isUnarmedUsage && try_postponed_usage_on_unurmed_usage_item(human_eid, human_net_phys, human_inventory__entityUseStart, human_inventory__entityUseEnd,
                                                                   human_inventory_postponed_usage__state, human_inventory_postponed_usage__useDuration)
      target_item_eid |> addSubTemplate("item_holder_postponed") <| $(var init)
        init |> set("item_holder_postponed__load", load)
        init |> set("item_holder_postponed__itemCount", itemCount)
        init |> set("item_holder_postponed__container", container_eid)
        init |> set("item_holder_postponed__searchOtherContainers", search_other_containers)
      return

    item_holder_start_loading(human_eid, target_item_eid, container_eid, itemCount, item__currentBoxedItemCount, load, search_other_containers, item_holder__itemLoadingProcess)
    canUseHolder = CanUseHolderItemResponse.Approved

  if canUseHolder != CanUseHolderItemResponse.Approved
    let reasonInt = int(CanUseItemResponse.End) + int(canUseHolder)
    send_net_event(human_eid, ResponseFailureUseItemHolder(itemEid = target_item_eid, reason = reasonInt), target_entity_conn(human_eid))


[es(tag=gameClient, REQUIRE=watchedByPlr)]
def change_hint_on_holder_load_request(evt : NotifyItemHolderLoadingStart)
  query(evt.holderEid) <| $ [es] (item_holder__loadLongUseHint : string;
                                  item_holder__unloadLongUseHint : string;
                                  var item__setCustomLongUseHint : das_string&)
    if evt.wishToLoad
      item__setCustomLongUseHint := item_holder__loadLongUseHint
    else
      item__setCustomLongUseHint := item_holder__unloadLongUseHint


[es(tag=server, before=human_inventory_server_es)]
def item_holder_loading_update_es(act : UpdateStageInfoAct;
                                  eid : EntityId;
                                  item_loading__itemHumanOwner : EntityId;
                                  item_loading__holderEid : EntityId;
                                  item_loading__wishToLoad : bool;
                                  item_loading__startingItemCount : int;
                                  item_loading__totalItemCountToLoad : int;
                                  item_loading__searchOtherContainers : bool;
                                  var item_loading__targetContainer : EntityId&;
                                  var item_loading__lastUsedBoxedItem : das_string&;
                                  var item_loading__loadedItemCount : int&;
                                  var item_loading__updateAt : float&)
  if act.curTime < item_loading__updateAt
    return

  if (!is_item_in_human_inventory(item_loading__holderEid, item_loading__itemHumanOwner) ||
      !is_human_inventory(item_loading__targetContainer, item_loading__itemHumanOwner))
    sendEvent(item_loading__itemHumanOwner, EventInterruptItemUse())
    destroyEntity(eid)
    return

  var terminateProcess = true
  query(item_loading__holderEid) <| $ [es] (var item__currentBoxedItemCount aka target_item__currentBoxedItemCount : int&;
                                            item_holder__boxedItemTemplate : string;
                                            item_holder__loadInOutTime : float2;
                                            item_holder__unloadInOutTime : float2;
                                            item__humanOwnerEid : EntityId)
    query(item_loading__itemHumanOwner) <| $ [es] (inventories_owner__inventoryEids : EidList;
                                                   human_inventory__entityToUse : EntityId;
                                                   human_inventory__entityUseStart : float;
                                                   human_inventory__entityUseEnd : float;
                                                   human_inventory__itemHolderLoadingMult : float = 1.0)
      let invItemHolderLoadingMult = safeinv(human_inventory__itemHolderLoadingMult)
      let passedTime = act.curTime - human_inventory__entityUseStart
      let inTime = (item_loading__wishToLoad ? item_holder__loadInOutTime.x : item_holder__unloadInOutTime.x) * invItemHolderLoadingMult
      let outTime = (item_loading__wishToLoad ? item_holder__loadInOutTime.y : item_holder__unloadInOutTime.y) * invItemHolderLoadingMult

      // In delay
      if passedTime < inTime
        item_loading__updateAt = human_inventory__entityUseStart + inTime
        terminateProcess = false
        return

      if human_inventory__entityToUse != item_loading__holderEid
        terminateProcess = true
        return

      let loadingPassedTime = passedTime - inTime
      let useTime = human_inventory__entityUseEnd - human_inventory__entityUseStart
      let loadingTime = useTime - (inTime + outTime)

      let timePerItem = loadingTime / float(item_loading__totalItemCountToLoad)
      let loadingStepsPassed = min(item_loading__totalItemCountToLoad, roundi(safediv(loadingPassedTime, timePerItem)))
      item_loading__updateAt = human_inventory__entityUseStart + (float(loadingStepsPassed) + 0.5) * timePerItem
      item_loading__updateAt = min(human_inventory__entityUseEnd, item_loading__updateAt)
      terminateProcess = false
      if item_loading__itemHumanOwner != item__humanOwnerEid
        terminateProcess = true
        sendEvent(item_loading__itemHumanOwner, EventInterruptItemUse())
        return

      var delta = item_loading__startingItemCount - item__currentBoxedItemCount + int(item_loading__wishToLoad ? loadingStepsPassed : -loadingStepsPassed)
      if delta == 0
        //terminateProcess = true //might happen due to the exact time match, not a reason to terminate yet
        return
      let boxedItemEid = find_boxed_item_to_draw_from_in_inventories(item_loading__wishToLoad,
                                                                     item_loading__searchOtherContainers,
                                                                     item_holder__boxedItemTemplate,
                                                                     inventories_owner__inventoryEids,
                                                                     item_loading__targetContainer)
      query(boxedItemEid) <| $ [es] (uniqueId : string)
        item_loading__lastUsedBoxedItem := uniqueId

      let startingDelta = delta
      if item_loading__wishToLoad
        draw_boxed_item_from(boxedItemEid, target_item__currentBoxedItemCount, delta)
        if delta != 0
          sendEvent(item_loading__itemHumanOwner, EventInterruptItemUse())
        elif loadingStepsPassed < item_loading__totalItemCountToLoad
          let nextBoxedAmmoEid = find_boxed_item_to_draw_from_in_inventories(item_loading__wishToLoad,
                                                                             item_loading__searchOtherContainers,
                                                                             item_holder__boxedItemTemplate,
                                                                             inventories_owner__inventoryEids,
                                                                             item_loading__targetContainer)
          if nextBoxedAmmoEid == INVALID_ENTITY_ID
            sendEvent(item_loading__itemHumanOwner, EventInterruptItemUse())
      else
        terminateProcess = push_boxed_item_to_container(boxedItemEid, item_holder__boxedItemTemplate, item_loading__itemHumanOwner,
                                                        item_loading__targetContainer, target_item__currentBoxedItemCount, delta)
      item_loading__loadedItemCount += delta - startingDelta

    if terminateProcess == true
      sendEvent(item_loading__itemHumanOwner,
        EventItemHolderLoadingFinished(holderEid = item_loading__holderEid, loadedItemCount = target_item__currentBoxedItemCount))

  if terminateProcess == true
    destroyEntity(eid)


[es(tag=server, on_appear)]
def notify_item_holder_loaded_on_loading_process_start(evt : Event;
                                                       eid aka item_loading_eid : EntityId;
                                                       item_loading__wishToLoad : bool;
                                                       item_loading__itemHumanOwner : EntityId;
                                                       item_loading__holderEid : EntityId;
                                                       item_loading__targetContainer : EntityId;
                                                       item_loading__lastUsedBoxedItem : string)
  send_net_event(item_loading__itemHumanOwner,
                NotifyItemHolderLoadingStart(processEid = item_loading_eid,
                                               wishToLoad = item_loading__wishToLoad,
                                               holderEid = item_loading__holderEid,
                                               inventoryEid = item_loading__targetContainer,
                                               boxedId = item_loading__lastUsedBoxedItem))


[es(tag=server, on_disappear)]
def notify_item_holder_loaded_on_loading_process_end(evt : Event;
                                                     eid aka item_loading_eid : EntityId;
                                                     item_loading__wishToLoad : bool;
                                                     item_loading__itemHumanOwner : EntityId;
                                                     item_loading__holderEid : EntityId;
                                                     item_loading__targetContainer : EntityId;
                                                     item_loading__lastUsedBoxedItem : string;
                                                     item_loading__loadedItemCount : int)
  send_net_event(item_loading__itemHumanOwner,
                NotifyItemHolderLoadingEnd(processEid = item_loading_eid,
                                             wishToLoad = item_loading__wishToLoad,
                                             holderEid = item_loading__holderEid,
                                             inventoryEid = item_loading__targetContainer,
                                             boxedId = item_loading__lastUsedBoxedItem,
                                             count = item_loading__loadedItemCount))


[es(tag=server)]
def abort_item_holder_load_on_inventory_move(evt : EventOnItemMovedBetweenInventory;
                                             human_inventory__entityToUse : EntityId)
  if !has(evt.itemEid, "item_holder__boxedItemTemplate") || evt.itemEid != human_inventory__entityToUse
    return
  find_query() <| $ [es] (eid, item_loading__holderEid, item_loading__itemHumanOwner : EntityId)
    if item_loading__holderEid == evt.itemEid
      sendEvent(item_loading__itemHumanOwner, EventInterruptItemUse())
      destroyEntity(eid)
      return true
    return false


[es(tag=server, on_appear)]
def init_item_holder_item_count(evt : Event; eid : EntityId;
                                var item__currentBoxedItemCount : int&;
                                item_holder__maxItemCount : int = -1;
                                item__countPerStack : int = -1;
                                item_holder__rndItemCount : int2 = int2(-1, -1))
  if item__currentBoxedItemCount != -1
    return

  if item_holder__rndItemCount.x != -1
    item__currentBoxedItemCount = rnd_int(item_holder__rndItemCount)
    return

  if item_holder__maxItemCount != -1
    item__currentBoxedItemCount = item_holder__maxItemCount
  elif item__countPerStack != -1
    item__currentBoxedItemCount = item__countPerStack
  else
    logerr("[INVENTORY] Can't determine item count for item holder {get_entity_info(eid)}")
    item__currentBoxedItemCount = 0
