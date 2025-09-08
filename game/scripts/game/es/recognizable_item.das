require ecs
require net
require math.random
require DagorSystem
require game.events.events_active_matter
require game.es.inventory_common
require game.utils.hero
require ecs.common
require game.es.ecs_common
require DagorMath
require game.events.inventory_events
require game.es.entity_mods_common

let ITEM_PRIORITY_RANGE = 100

def get_local_player()
  var result = INVALID_ENTITY_ID
  find_query() <| $ [es(REQUIRE=watchedByPlr)] (possessedByPlr : EntityId; isAlive : bool)
    if isAlive
      result = possessedByPlr
    return true
  return result


def init_recognition_time(eid : EntityId;
                          item__recognizedByPlayers : EidList;
                          item__containerOwnerEid : EntityId;
                          item__recognizeTimePerVolume : float;
                          item__recognizeTimeDeviation : float;
                          item__recognizeTimeMinMax : float2;
                          item__volume : float;
                          item__customSortingPriority : bool;
                          var item__recognizeTime : float&;
                          var item__recognizeTimeLeft : float&;
                          var item__uiSortingPriority : int&)
  if (item__containerOwnerEid == INVALID_ENTITY_ID ||
    has_value(item__recognizedByPlayers, get_local_player()) ||
    has(item__containerOwnerEid, "human_inventory__alwaysRecognizedItems"))
    item__recognizeTimeLeft = -1.0
    return
  let recognizeTime = clamp(item__recognizeTimePerVolume * item__volume,
                            item__recognizeTimeMinMax.x,
                            item__recognizeTimeMinMax.y)
  let deviation = recognizeTime * rnd_float(-1.0, 1.0) * item__recognizeTimeDeviation
  item__recognizeTime = recognizeTime + deviation
  item__recognizeTimeLeft = item__recognizeTime
  if !item__customSortingPriority
    // eid_frnd is used to make recodnition order the same for all the clients
    item__uiSortingPriority = int(eid_frnd(eid) * float(ITEM_PRIORITY_RANGE)) // -1, 0, INT_MAX values are reserved


[es(tag=gameClient, on_appear, track=item__recognizedByPlayers, before=inventory_items_ui_es, after=add_item_to_owners_container)]
def recognizable_item_appear(evt : Event;
                             item__recognizedByPlayers : EidList;
                             eid : EntityId;
                             item__containerOwnerEid : EntityId;
                             item__recognizeTimePerVolume : float;
                             item__recognizeTimeDeviation : float;
                             item__recognizeTimeMinMax : float2;
                             item__volume : float = 3.0;
                             item__customSortingPriority : Tag const?;
                             var item__recognizeTime : float&;
                             var item__recognizeTimeLeft : float&;
                             var item__uiSortingPriority : int&)
  init_recognition_time(eid,
                        item__recognizedByPlayers,
                        item__containerOwnerEid,
                        item__recognizeTimePerVolume,
                        item__recognizeTimeDeviation,
                        item__recognizeTimeMinMax,
                        item__volume,
                        item__customSortingPriority != null,
                        item__recognizeTime,
                        item__recognizeTimeLeft,
                        item__uiSortingPriority)


 //may act twice with recognizable_item_appear, but that's ok
[es(tag=gameClient, on_appear, REQUIRE=watchedPlayerItem, before=inventory_items_ui_es)]
def recognizable_watched_item_appear(evt : Event;
                                     item__recognizedByPlayers : EidList;
                                     eid : EntityId;
                                     item__containerOwnerEid : EntityId;
                                     item__recognizeTimePerVolume : float;
                                     item__recognizeTimeDeviation : float;
                                     item__recognizeTimeMinMax : float2;
                                     item__volume : float = 3.0;
                                     item__customSortingPriority : Tag const?;
                                     var item__recognizeTime : float&;
                                     var item__recognizeTimeLeft : float&;
                                     var item__uiSortingPriority : int&)
  init_recognition_time(eid,
                        item__recognizedByPlayers,
                        item__containerOwnerEid,
                        item__recognizeTimePerVolume,
                        item__recognizeTimeDeviation,
                        item__recognizeTimeMinMax,
                        item__volume,
                        item__customSortingPriority != null,
                        item__recognizeTime,
                        item__recognizeTimeLeft,
                        item__uiSortingPriority)


[es(tag=gameClient, on_appear, REQUIRE=item_in_world)]
def reinit_recognizable_time(evt : Event;
                             item__recognizedByPlayers : EidList;
                             eid : EntityId;
                             item__recognizeTimePerVolume : float;
                             item__recognizeTimeDeviation : float;
                             item__recognizeTimeMinMax : float2;
                             item__volume : float = 3.0;
                             item__customSortingPriority : Tag const?;
                             var item__recognizeTime : float&;
                             var item__recognizeTimeLeft : float&;
                             var item__uiSortingPriority : int&)
  init_recognition_time(eid,
                        item__recognizedByPlayers,
                        INVALID_ENTITY_ID, //force no owner for items in world (may not always be true for some reason)
                        item__recognizeTimePerVolume,
                        item__recognizeTimeDeviation,
                        item__recognizeTimeMinMax,
                        item__volume,
                        item__customSortingPriority != null,
                        item__recognizeTime,
                        item__recognizeTimeLeft,
                        item__uiSortingPriority)


[es(tag=gameClient, on_appear, REQUIRE=hero)]
def init_items_recognition_time_on_hero_appear(evt : Event; inventories_owner__inventoryEids : EidList)
  for inv_eid in inventories_owner__inventoryEids
    query(inv_eid) <| $ [es] (itemContainer : EidList)
      for item_eid in itemContainer
        query(item_eid) <| $ [es] (item__recognizedByPlayers : EidList;
                                   item__recognizeTimePerVolume : float;
                                   item__recognizeTimeDeviation : float;
                                   item__recognizeTimeMinMax : float2;
                                   item__volume : float = 3.0;
                                   item__customSortingPriority : Tag const?;
                                   var item__recognizeTime : float&;
                                   var item__recognizeTimeLeft : float&;
                                   var item__uiSortingPriority : int&)
          init_recognition_time(item_eid,
                                item__recognizedByPlayers,
                                inv_eid,
                                item__recognizeTimePerVolume,
                                item__recognizeTimeDeviation,
                                item__recognizeTimeMinMax,
                                item__volume,
                                item__customSortingPriority != null,
                                item__recognizeTime,
                                item__recognizeTimeLeft,
                                item__uiSortingPriority)


[es(tag=gameClient)]
def recognize_item_moved_to_always_recognized_container(evt : EventOnMovingBetweenInventories;
                                                        item__recognizedByPlayers : EidList;
                                                        eid : EntityId;
                                                        item__recognizeTimePerVolume : float;
                                                        item__recognizeTimeDeviation : float;
                                                        item__recognizeTimeMinMax : float2;
                                                        item__volume : float = 3.0;
                                                        item__customSortingPriority : Tag const?;
                                                        var item__recognizeTime : float&;
                                                        var item__recognizeTimeLeft : float&;
                                                        var item__uiSortingPriority : int&)
  if has(evt.newInventoryEid, "human_inventory__alwaysRecognizedItems")
    //Could be short-circuited here, by simply setting item__recognizeTimeLeft = -1.0
    //but init_recognition_time call is preserved for consistency
    init_recognition_time(eid,
                          item__recognizedByPlayers,
                          evt.newInventoryEid, // item__containerOwnerEid is probably not updated yet, don't rely on it.
                          item__recognizeTimePerVolume,
                          item__recognizeTimeDeviation,
                          item__recognizeTimeMinMax,
                          item__volume,
                          item__customSortingPriority != null,
                          item__recognizeTime,
                          item__recognizeTimeLeft,
                          item__uiSortingPriority)


[es(tag=gameClient)]
def recognized_item_moved_to_container_set_priority(evt : EventOnMovingBetweenInventories;
                                                    item__recognizedByPlayers : EidList;
                                                    var item__uiSortingPriority : int&)
  if has(evt.newInventoryEid, "human_inventory__alwaysRecognizedItems")
    return
  if (has_value(item__recognizedByPlayers, get_local_player()) &&
      evt.newInventoryEid != INVALID_ENTITY_ID)
    item__uiSortingPriority = 2 * ITEM_PRIORITY_RANGE + 1


[es(tag=gameClient)]
def recognized_item_unequiped_to_container_set_priority(evt : EventOnUnequipingToInventory;
                                                        item__recognizedByPlayers : EidList;
                                                        var item__uiSortingPriority : int&)
  if has(evt.newInventoryEid, "human_inventory__alwaysRecognizedItems")
    return
  if (has_value(item__recognizedByPlayers, get_local_player()) &&
      evt.newInventoryEid != INVALID_ENTITY_ID)
    item__uiSortingPriority = 2 * ITEM_PRIORITY_RANGE + 1


[es(tag=gameClient, on_appear, track=external_inventory_interactor__inventoryEid, REQUIRE=watchedByPlr)]
def reinit_items_in_external_container(evt : Event;
                                       external_inventory_interactor__inventoryEid : EntityId)
  query(external_inventory_interactor__inventoryEid) <| $ [es] (itemContainer : EidList)
    for item_eid in itemContainer
      query(item_eid) <| $ [es] (item__recognizedByPlayers : EidList;
                                 item__recognizeTimePerVolume : float;
                                 item__recognizeTimeDeviation : float;
                                 item__recognizeTimeMinMax : float2;
                                 item__volume : float = 3.0;
                                 item__customSortingPriority : Tag const?;
                                 var item__recognizeTime : float&;
                                 var item__recognizeTimeLeft : float&;
                                 var item__uiSortingPriority : int&)
        init_recognition_time(item_eid,
                              item__recognizedByPlayers,
                              external_inventory_interactor__inventoryEid,
                              item__recognizeTimePerVolume,
                              item__recognizeTimeDeviation,
                              item__recognizeTimeMinMax,
                              item__volume,
                              item__customSortingPriority != null,
                              item__recognizeTime,
                              item__recognizeTimeLeft,
                              item__uiSortingPriority)


[es(tag=gameClient, on_appear, track=militant_extra_inventories__backpackEid,
    before=update_hero_item_container_on_backpack_change, REQUIRE=watchedByPlr)]
def reinit_items_in_backpack(evt : Event;
                             militant_extra_inventories__backpackEid : EntityId)
  query(militant_extra_inventories__backpackEid) <| $ [es] (itemContainer : EidList)
    for item_eid in itemContainer
      query(item_eid) <| $ [es] (item__recognizedByPlayers : EidList;
                                 item__recognizeTimePerVolume : float;
                                 item__recognizeTimeDeviation : float;
                                 item__recognizeTimeMinMax : float2;
                                 item__volume : float = 3.0;
                                 item__customSortingPriority : Tag const?;
                                 var item__recognizeTime : float&;
                                 var item__recognizeTimeLeft : float&;
                                 var item__uiSortingPriority : int&)
        init_recognition_time(item_eid,
                              item__recognizedByPlayers,
                              militant_extra_inventories__backpackEid,
                              item__recognizeTimePerVolume,
                              item__recognizeTimeDeviation,
                              item__recognizeTimeMinMax,
                              item__volume,
                              item__customSortingPriority != null,
                              item__recognizeTime,
                              item__recognizeTimeLeft,
                              item__uiSortingPriority)


def build_item_recognition_list(itemContainer : EidList; sort_items : bool = false)
  var list : array<EntityId>
  list |> resize(length(itemContainer))
  for itemEid0, itemEid1 in list, itemContainer
    itemEid0 = itemEid1

  if sort_items
    list |> sort() <| $(lhs, rhs : EntityId)
      var res = false
      query(lhs) <| $ [es] (item__recognizeTime aka lhs_item__recognizeTime : float;
                            item__recognizeTimeLeft  aka lhs_item__recognizeTimeLeft : float;
                            item__uiSortingPriority aka lhs_item__uiSortingPriority : int)
        query(rhs) <| $ [es] (item__recognizeTime aka rhs_item__recognizeTime : float;
                              item__recognizeTimeLeft  aka rhs_item__recognizeTimeLeft : float;
                              item__uiSortingPriority aka rhs_item__uiSortingPriority : int)
          let lshMidwayThrough = lhs_item__recognizeTime != lhs_item__recognizeTimeLeft && lhs_item__recognizeTimeLeft > .0
          let rshMidwayThrough = rhs_item__recognizeTime != rhs_item__recognizeTimeLeft && rhs_item__recognizeTimeLeft > .0
          if lshMidwayThrough ^^ rshMidwayThrough
            res = lshMidwayThrough //Items that are partialy recognized must come first
            return
          if lhs_item__uiSortingPriority != rhs_item__uiSortingPriority
            res = (lhs_item__uiSortingPriority > rhs_item__uiSortingPriority)
          else
            res = uint(lhs) > uint(rhs)
      return res
  return <- list


[es(tag=gameClient, REQUIRE=watchedByPlr, no_order)]
def hero_external_inventory_items_recognizing(act : UpdateStageInfoAct;
                                              entity_mod_values : Object;
                                              external_inventory_interactor__inventoryEid : EntityId;
                                              hero : Tag const?)
  recognize_items_inside(external_inventory_interactor__inventoryEid, act.dt * get_mod_value("itemRecognitionSpeed", entity_mod_values, 1.0), hero != null)


[es(tag=gameClient, REQUIRE=(watchedPlayerItem, itemContainer), no_order)] //backpack. because its an item a&& a container && owned by player
def hero_backpack_items_recognizing(act : UpdateStageInfoAct; eid, inventory__humanOwnerEid : EntityId; inventory__itemRecognitionEnabled : bool = true)
  if inventory__itemRecognitionEnabled
    query(inventory__humanOwnerEid) <| $ [es] (entity_mod_values : Object; hero : Tag const?)
      recognize_items_inside(eid, act.dt * get_mod_value("itemRecognitionSpeed", entity_mod_values, 1.0), hero != null)


def recognize_items_inside(target_inventory_eid : EntityId; dt : float; is_hero : bool)
  query(target_inventory_eid) <| $ [es] (itemContainer : EidList;
                                         itemContainer__uiItemsSortingEnabled : bool = true;
                                         itemContainer__uiItemsOverrideSortingPriority : bool = false;
                                         itemContainer__uiItemsMergeEnabled : bool = true)
    let sortItems = itemContainer__uiItemsSortingEnabled && itemContainer__uiItemsOverrideSortingPriority
    let recognitionList <- build_item_recognition_list(itemContainer, sortItems)
    var currentUiPriority = 2 * ITEM_PRIORITY_RANGE
    for itemEid in recognitionList
      query(itemEid) <| $ [es] (item__uiSortingPriority : int; item__recognizeTimeLeft : float)
        if item__recognizeTimeLeft <= 0.0
          currentUiPriority = min(currentUiPriority, item__uiSortingPriority - 1)

    for itemEid in recognitionList
      var itemProcessed = false
      query(itemEid) <| $ [es] (item__recognizeTime : float;
                                var item__recognizeTimeLeft aka this_item__recognizeTimeLeft : float&;
                                var item__uiSortingPriority : int&)
        if item__recognizeTimeLeft <= 0.0
          return

        if dt > .0 && item__recognizeTimeLeft == item__recognizeTime
          item__uiSortingPriority = currentUiPriority // from 200 to 100
          sendEvent(itemEid, NotifyItemRecognitionStarted()) //to trigger recognition animation

        var recognizingItems : array<EntityId>
        recognizingItems |> push(itemEid)
        if itemContainer__uiItemsMergeEnabled
          // Find all merged (stacked) items
          for recognizingItemEid in recognitionList
            if itemEid != recognizingItemEid && is_items_identical(itemEid, recognizingItemEid)
              recognizingItems |> push(recognizingItemEid)


        item__recognizeTimeLeft -= safediv(dt, float(length(recognizingItems)))
        itemProcessed = true

        if item__recognizeTimeLeft <= 0.0
          if itemContainer__uiItemsMergeEnabled
            for recognizingItemEid in recognizingItems
              query(recognizingItemEid) <| $ [es] (var item__recognizeTimeLeft aka other_item__recognizeTimeLeft : float&)
                other_item__recognizeTimeLeft = -1.0
              if is_hero
                send_net_event(get_controlled_hero(), CmdMarkItemRecognized(itemEid = recognizingItemEid))
          else
            item__recognizeTimeLeft = -1.0
            if is_hero
              send_net_event(get_controlled_hero(), CmdMarkItemRecognized(itemEid = itemEid))

      if itemProcessed
        break


[es(tag=server)]
def server_mark_item_recognized(evt : CmdMarkItemRecognized; eid, possessedByPlr, external_inventory_interactor__inventoryEid : EntityId)
  query(evt.itemEid) <| $ [es] (item__containerOwnerEid, item__lastContainerOwnerEid, item__humanOwnerEid : EntityId; var item__recognizedByPlayers : EidList)
    if (item__humanOwnerEid == eid
        || item__containerOwnerEid == external_inventory_interactor__inventoryEid
        || item__humanOwnerEid == (get_Eid(item__containerOwnerEid, "item__humanOwnerEid") ?? INVALID_ENTITY_ID))
      if !has_value(item__recognizedByPlayers, possessedByPlr)
        item__recognizedByPlayers |> push(possessedByPlr)
      else
        print("[Recognizable Items] Player {get_entity_info(possessedByPlr)} already recognized item {get_entity_info(evt.itemEid)}")
    elif item__lastContainerOwnerEid != external_inventory_interactor__inventoryEid
      logerr("[Recognizable Items] Player {get_entity_info(possessedByPlr)} tried to recognize item {get_entity_info(evt.itemEid)}
which he shouldn't have access to (item__humanOwnerEid={get_entity_info(item__humanOwnerEid)},
                                   item__containerOwnerEid={get_entity_info(item__containerOwnerEid)},
                                   owner of item__containerOwnerEid={get_entity_info(get_Eid(item__containerOwnerEid, "item__humanOwnerEid") ?? INVALID_ENTITY_ID)},
                                   external_inventory_interactor__inventoryEid={get_entity_info(external_inventory_interactor__inventoryEid)})")


[es(tag=gameClient, on_appear, REQUIRE=human_inventory__alwaysRecognizedItems, after=process_items_that_waited_container)]
def always_recognized_container_appear(evt : Event; itemContainer : EidList)
  for eid in itemContainer
    query(eid) <| $ [es] (var item__recognizeTimeLeft : float&)
      item__recognizeTimeLeft = -1.0


[es(tag=server)]
def update_recognized_by_players_list(evt : EventOnMovingBetweenInventories;
                                      var item__recognizedByPlayers : EidList)
  clear(item__recognizedByPlayers)
  query(evt.actorEid) <| $ [es] (possessedByPlr : EntityId)
    item__recognizedByPlayers |> push(possessedByPlr)


[es(tag=server, on_appear)]
def update_recognized_by_players_on_appear(evt : Event;
                                           item__humanOwnerEid : EntityId;
                                           var item__recognizedByPlayers : EidList)
  query(item__humanOwnerEid) <| $ [es] (possessedByPlr : EntityId)
    if possessedByPlr == INVALID_ENTITY_ID
      return

    if !has_value(item__recognizedByPlayers, possessedByPlr)
      item__recognizedByPlayers |> push(possessedByPlr)


[es(tag=server, track=possessedByPlr)]
def update_recognized_by_players_items_on_possessed(evt : Event;
                                                    possessedByPlr : EntityId;
                                                    itemContainer : EidList)
  if possessedByPlr == INVALID_ENTITY_ID
    return

  for itemEid in itemContainer
    query(itemEid) <| $ [es] (var item__recognizedByPlayers : EidList&)
      if !has_value(item__recognizedByPlayers, possessedByPlr)
        item__recognizedByPlayers |> push(possessedByPlr)