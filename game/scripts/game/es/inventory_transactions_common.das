module inventory_transactions_common shared
require ecs
require ecs.safe
require DagorSystem
require game.es.ecs_common
require game.es.inventory_slots_common


let
  WEAPON_PREFIX = "weapon_"
  EQUIPMENT_PREFIX = "equipment_"


enum TransactionAction
  INVALID = 0
  MOVE = 1
  SPLIT = 2
  MAGAZINE_TRANSFER_CHARGES = 3
  GUN_TRANSFER_CHARGES = 4
  POCKET_MOVE = 5


def is_transation_disabled()
  var res = true // by default we don't have profile server
  find_query() <| $ [es] (player_profile__disableTransaction : bool)
    res = player_profile__disableTransaction
    return true
  return res


def try_update_all_items_on_item_remove_transaction(var player_profile__allItems : Array;
                                                    item_uniqueId : string;
                                                    item_eid : EntityId)
  if is_transation_disabled()
    return
  var result = false
  var index = 0
  for item in player_profile__allItems
    var itemObj = get_ecs_object(item)
    if itemObj != null && ((*itemObj)["itemId"] ?? "-1") == item_uniqueId
      result = true
      break
    ++index

  if result
    erase(player_profile__allItems, index)
    print("[ALL ITEMS] Item '{item_uniqueId}' ({get_entity_info(item_eid)}) manually removed from allItems")
  else
    print("[ALL ITEMS] Item '{item_uniqueId}' ({get_entity_info(item_eid)}) not found in allItems for manual remove")


def update_all_items_on_item_move_transaction(var player_profile__allItems : Array;
                                              item_uniqueId : string;
                                              item_eid : EntityId;
                                              parent_id : string = "";
                                              slot : string = "";
                                              charges : int = -1)
  if is_transation_disabled()
    return
  var result = false
  for item in player_profile__allItems
    var itemObj = getRW_ecs_object(item)
    if itemObj == null || ((*itemObj)["itemId"] ?? "-1") != item_uniqueId
      continue

    result = true
    if !empty(slot)
      var itemSlot = getRW_ecs_string(itemObj, "slotName")
      if itemSlot != null
        *itemSlot := slot
    if !empty(parent_id)
      var parentItemId = getRW_ecs_string(itemObj, "parentItemId")
      if parentItemId != null
        *parentItemId := parent_id
    if charges >= 0
      if (*itemObj)["charges"] != null
        *itemObj |> set("charges", charges)
    break

  if result
    let parentString = empty(parent_id) ? "none" : parent_id
    let slotString = empty(slot) ? "none" : slot
    let chargesString = charges < 0 ? "none" : "{charges}"
    print("[ALL ITEMS] Item '{item_uniqueId}' ({get_entity_info(item_eid)}) manually updated in allItems with [parent='{parentString}' slot='{slotString}' charges='{chargesString}']")
  else
    logerr("[ALL ITEMS] Item '{item_uniqueId}' ({get_entity_info(item_eid)}) not found in allItems for manual update")


def try_update_all_items_on_item_remove_transaction(item_uniqueId : string;
                                                    item_eid : EntityId)
  find_query() <| $ [es] (var player_profile__allItems : Array)
    try_update_all_items_on_item_remove_transaction(player_profile__allItems, item_uniqueId, item_eid)
    return true


def update_all_items_on_item_move_transaction(item_uniqueId : string;
                                              item_eid : EntityId;
                                              parent_id : string = "";
                                              slot : string = "";
                                              charges : int = -1)
  find_query() <| $ [es] (var player_profile__allItems : Array)
    update_all_items_on_item_move_transaction(player_profile__allItems, item_uniqueId, item_eid, parent_id, slot, charges)
    return true


def report_item_move_transaction(item_eid : EntityId; target_id : string; slot : string)
  if is_transation_disabled()
    return

  find_query() <| $ [es] (var player_profile__queuedTransactions : Array)
    query(item_eid) <| $ [es] (uniqueId aka item_uniqueId : string)
      if item_uniqueId == "-1"
        logerr("[ITEM MOVE TRANSACTION] can't move item ({get_entity_info(item_eid)}) because it contain unassigned uniqueId")
        return
      print("[ITEM MOVE TRANSACTION] Item '{item_uniqueId}' ({get_entity_info(item_eid)}) moved to '{target_id}' slot='{slot}'")
      using <| $ [es] (var obj : Object)
        obj |> set("action", int(TransactionAction.MOVE))
        obj |> set("item", item_uniqueId)
        obj |> set("to", target_id)
        obj |> set("slot", slot)
        obj |> set("count", 0)
        player_profile__queuedTransactions |> push(obj)
    return true


def report_item_move_to_pocket_transaction(item_eid : EntityId; target_id : string; slot : string; shouldBeSplited : bool = false)
  if is_transation_disabled()
    return

  find_query() <| $ [es] (var player_profile__queuedTransactions : Array)
    query(item_eid) <| $ [es] (uniqueId aka item_uniqueId : string)
      if item_uniqueId == "-1"
        logerr("[ITEM MOVE TRANSACTION] can't move to pocket item ({get_entity_info(item_eid)}) because it contain unassigned uniqueId")
        return
      print("[ITEM MOVE TRANSACTION] Item '{item_uniqueId}' ({get_entity_info(item_eid)}) moved to pocket {target_id} slot='{slot}'")
      using <| $ [es] (var obj : Object)
        obj |> set("action", int(TransactionAction.POCKET_MOVE))
        obj |> set("item", item_uniqueId)
        obj |> set("to", target_id)
        obj |> set("slot", slot)
        player_profile__queuedTransactions |> push(obj)
    return true


def report_item_split_transaction(item_eid : EntityId; count : int; target_id : string; slot : string)
  if is_transation_disabled()
    return

  find_query() <| $ [es] (var player_profile__queuedTransactions : Array)
    query(item_eid) <| $ [es] (uniqueId aka item_uniqueId : string)
      if item_uniqueId == "-1"
        logerr("[ITEM MOVE TRANSACTION] can't split item ({get_entity_info(item_eid)}) because it contain unassigned uniqueId")
        return
      print("[ITEM MOVE TRANSACTION] Item '{item_uniqueId}' ({get_entity_info(item_eid)}) splited (count={count}) and moved to {target_id} slot='{slot}'")
      using <| $ [es] (var obj : Object)
        obj |> set("action", int(TransactionAction.SPLIT))
        obj |> set("item", item_uniqueId)
        obj |> set("to", target_id)
        obj |> set("slot", slot)
        obj |> set("count", count)
        player_profile__queuedTransactions |> push(obj)
    return true


def report_item_ammo_loading_transaction(boxed_id : string; item_eid : EntityId; count : int)
  if is_transation_disabled()
    return

  find_query() <| $ [es] (var player_profile__queuedTransactions : Array)
    if boxed_id == "-1"
      logerr("[ITEM MOVE TRANSACTION] can't ammo_load from boxed without uniqueId")
      return true
    query(item_eid) <| $ [es] (uniqueId : string;
                               gun__blk : das_string const?)
      if uniqueId == "-1"
        logerr("[ITEM MOVE TRANSACTION] can't ammo_load item ({get_entity_info(item_eid)}) because it contain unassigned uniqueId")
        return
      print("[ITEM MOVE TRANSACTION] Item '{uniqueId}' ({get_entity_info(item_eid)}) ammo loading (count={count}) from {boxed_id})")
      using <| $ [es] (var obj : Object)
        obj |> set("action", gun__blk != null ? int(TransactionAction.GUN_TRANSFER_CHARGES) : int(TransactionAction.MAGAZINE_TRANSFER_CHARGES))
        let from = boxed_id
        let to = uniqueId
        obj |> set("item", from)
        obj |> set("to", to)
        obj |> set("slot", "")
        obj |> set("count", count)
        player_profile__queuedTransactions |> push(obj)
    return true


def report_item_ammo_unloading_transaction(item_eid : EntityId; target_id : string; slot : string; count : int)
  if is_transation_disabled()
    return

  find_query() <| $ [es] (var player_profile__queuedTransactions : Array)
    if target_id == "-1"
      logerr("[ITEM MOVE TRANSACTION] can't ammo_unload to target without uniqueId")
      return true
    query(item_eid) <| $ [es] (uniqueId : string;
                               gun__blk : das_string const?)
      if uniqueId == "-1"
        logerr("[ITEM MOVE TRANSACTION] can't ammo_unload item ({get_entity_info(item_eid)}) because it contain unassigned uniqueId")
        return
      print("[ITEM MOVE TRANSACTION] Item '{uniqueId}' ({get_entity_info(item_eid)}) ammo unloading (count={count}) to {target_id} slot='{slot}'")
      using <| $ [es] (var obj : Object)
        obj |> set("action", gun__blk != null ? int(TransactionAction.GUN_TRANSFER_CHARGES) : int(TransactionAction.MAGAZINE_TRANSFER_CHARGES))
        let from = uniqueId
        let to = target_id
        obj |> set("item", from)
        obj |> set("to", to)
        obj |> set("slot", slot)
        obj |> set("count", count)
        player_profile__queuedTransactions |> push(obj)
    return true
