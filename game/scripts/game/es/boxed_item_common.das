module boxed_item_common shared
require ecs
require ecs.safe
require net
require strings
require math.base
require game.events.events
require game.events.events_active_matter
require game.es.inventory_checks_common
require game.utils.net_utils
require game.es.inventory_item_common
require game.es.inventory_drop_common
require game.es.inventory_transactions_common
require game.es.ecs_common


def find_boxed_item_to_draw_from(possible_templates : StringList; item_container : EidList)
  var res = INVALID_ENTITY_ID
  for item in item_container
    query(item) <| $ [es] (boxed_item__template : string; item__currentBoxedItemCount : int)
      if has_value(possible_templates, boxed_item__template) && item__currentBoxedItemCount > 0
        res = item
    if res != INVALID_ENTITY_ID
      break
  return res


def find_boxed_item_to_draw_from(boxed_item_template : string; item_container : EidList)
  var res = INVALID_ENTITY_ID
  for item in item_container
    query(item) <| $ [es] (boxed_item__template : string; item__currentBoxedItemCount : int)
      if boxed_item_template == boxed_item__template && item__currentBoxedItemCount > 0
        res = item
    if res != INVALID_ENTITY_ID
      break
  return res


def find_boxed_item_to_draw_from(boxed_item_template : string; inventoryEid : EntityId)
  var res = INVALID_ENTITY_ID
  query(inventoryEid) <| $ [es] (itemContainer : EidList)
    res = find_boxed_item_to_draw_from(boxed_item_template, itemContainer)
  return res


def draw_boxed_item_from(boxed_item_eid : EntityId; var target_boxed_item_count : int&; var left_over_delta : int&)
  var itemBoxEmptied = false
  query(boxed_item_eid) <| $ [es] (var item__currentBoxedItemCount : int&)
    let thisDelta = min(left_over_delta, item__currentBoxedItemCount)
    item__currentBoxedItemCount -= thisDelta
    target_boxed_item_count += thisDelta
    left_over_delta -= thisDelta
    if item__currentBoxedItemCount <= 0
      item__currentBoxedItemCount = -1 // invalid box will be destroyed
      if is_server()
        destroyEntity(boxed_item_eid)
      itemBoxEmptied = true
  return itemBoxEmptied


def push_boxed_item_to_container(boxed_item_eid : EntityId;
                                 boxed_item_template : string;
                                 human_owner : EntityId;
                                 var container_eid : EntityId;
                                 var target_boxed_item_count : int&;
                                 var left_over_delta : int&)
  var terminated = false
  query(boxed_item_eid) <| $ [es] (var item__currentBoxedItemCount aka boxed_item__currentBoxedItemCount : int&;
                                   item__countPerStack : int;
                                   item__volumePerStack : float)
    let wantsToFit = -left_over_delta
    let willFit = get_boxed_item_count_to_fit_inventory(container_eid, boxed_item_eid, wantsToFit)

    let volumeBefore = calc_stacked_item_volume(item__countPerStack, boxed_item__currentBoxedItemCount, item__volumePerStack)
    let volumeAfter = calc_stacked_item_volume(item__countPerStack, boxed_item__currentBoxedItemCount + willFit, item__volumePerStack)
    let volumeDelta = volumeAfter - volumeBefore
    boxed_item__currentBoxedItemCount += willFit
    target_boxed_item_count -= willFit
    left_over_delta += willFit

    query(container_eid) <| $ [es] (var human_inventory__currentVolume : int&)
      human_inventory__currentVolume += volumeDelta

    if willFit < wantsToFit
      sendEventImmediate(human_owner, EventInterruptItemUse())
      send_net_event(human_owner, EventCapacityExceeded(containerEid = container_eid), target_entity_conn(human_owner))
      terminated = true
  if left_over_delta != 0 && !terminated
    let newHolderTemplate = getTemplateByName(boxed_item_template)
    if newHolderTemplate != null
      let newHolderStackVolume = getTemplateComponent(*newHolderTemplate, "item__volumePerStack") ?? 0.0
      let newHolderStackCount = getTemplateComponent(*newHolderTemplate, "item__countPerStack") ?? 1
      let wantsToFit = -left_over_delta
      let willFit = get_boxed_item_count_to_fit_inventory(container_eid, newHolderStackCount, newHolderStackVolume,
                                                               boxed_item_template, wantsToFit)

      if willFit > 0
        target_boxed_item_count -= willFit
        left_over_delta += willFit
        if is_server() && is_transation_disabled()
          // on player base item will be created by profile server
          // item can be created only by server
          create_item_in_inventory_container(boxed_item_template, container_eid) <| $(init)
            init |> set("item__currentBoxedItemCount", willFit)
            init |> set("item__humanOwnerEid", human_owner)
          let volumeDelta = calc_stacked_item_volume(newHolderStackCount, willFit, newHolderStackVolume)
          query(container_eid) <| $ [es] (var human_inventory__currentVolume : int&)
            human_inventory__currentVolume += volumeDelta

      if willFit < wantsToFit
        sendEventImmediate(human_owner, EventInterruptItemUse())
        send_net_event(human_owner, EventCapacityExceeded(containerEid = container_eid), target_entity_conn(human_owner))
        terminated = true
  return left_over_delta != 0 || terminated


def push_boxed_item_to_container_or_ground(hero_eid : EntityId;
                                           wish_push_count : int;
                                           boxed_item_template : string;
                                           wish_to_inventory_eid : EntityId = INVALID_ENTITY_ID) : int
  var realPushCount = 0

  if wish_to_inventory_eid != INVALID_ENTITY_ID
    query(wish_to_inventory_eid) <| $ [es] (itemContainer : EidList)
      let boxedItemEid = find_boxed_item_to_draw_from(boxed_item_template, itemContainer)

      var leftoverCount = wish_push_count
      var delta = -wish_push_count
      push_boxed_item_to_container(boxedItemEid, boxed_item_template, hero_eid,
                                   wish_to_inventory_eid, leftoverCount, delta)
      realPushCount = wish_push_count - leftoverCount
  else
    realPushCount = wish_push_count

    query(hero_eid) <| $ [es] (transform : float3x4;
                               human_inventory__pickupRadius : float;
                               human_inventory__dropLootOffset = float3(0))
      var tm = IDENT_TM
      tm[3] = transform * human_inventory__dropLootOffset
      drop_item_on_ground(tm)

      if !try_merge_with_boxed_item_on_ground(tm[3], human_inventory__pickupRadius, boxed_item_template, realPushCount)
        create_item_on_ground(boxed_item_template, tm) <| $(init)
          init |> set("item__currentBoxedItemCount", realPushCount)

  return realPushCount


def merge_boxed_items_in_container(itemContainer : EidList)
  var mergedEntitites : table<uint; EntityId>
  for i in iter_range(itemContainer)
    query(itemContainer[i]) <| $ [es(REQUIRE=boxedItem)] (eid : EntityId;
                                                          boxed_item__template : string;
                                                          var item__currentBoxedItemCount aka my_item__currentBoxedItemCount : int&;
                                                          var item__recognizedByPlayers aka my_item__recognizedByPlayers : EidList)
      if item__currentBoxedItemCount > 0
        var alreadyInTable = false
        let boxId = ecs_hash(boxed_item__template)
        mergedEntitites |> get(boxId) <| $(entity_eid)
          alreadyInTable = true
          query(entity_eid) <| $ [es] (var item__currentBoxedItemCount : int&; item__recognizedByPlayers : EidList)
            item__currentBoxedItemCount += my_item__currentBoxedItemCount
            my_item__currentBoxedItemCount = -1 // invalid box will be destroyed
            for playerEid in item__recognizedByPlayers
              if !has_value(my_item__recognizedByPlayers, playerEid)
                my_item__recognizedByPlayers |> push(playerEid)
            print("[INVENTORY] Boxed item {get_entity_info(eid)} merged to {get_entity_info(entity_eid)}.")
            destroyEntity(eid)
        if !alreadyInTable
          mergedEntitites.insert(boxId, eid)