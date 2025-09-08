require ecs
require ecs.safe
require ecs.common
require game.es.item_equip_common
require game.events.events_active_matter
require game.es.inventory_item_common


[es(on_appear, on_event=EventProfileLoaded)]
def create_player_base_stash_inventory(evt : Event;
                                       eid : EntityId;
                                       player_on_base_components__stashTemplate : string;
                                       var inventories_owner__inventoryEids : EidList;
                                       var player_on_base_components__stashEid : EntityId&)
  if player_on_base_components__stashEid != INVALID_ENTITY_ID
    return
  player_on_base_components__stashEid = createEntity(player_on_base_components__stashTemplate) <| $(init)
    init |> set("inventory__humanOwnerEid", eid)
  inventories_owner__inventoryEids |> push(player_on_base_components__stashEid)


[es(on_appear, track=(uniqueId, player_on_base_components__stashEid), REQUIRE=hero)]
def init_stash_unique_id_from_hero(evt : Event; player_on_base_components__stashEid : EntityId; uniqueId aka hero_uniqueId : string)
  query(player_on_base_components__stashEid) <| $ [es] (var uniqueId aka stash_uniqueId : das_string&)
    stash_uniqueId := hero_uniqueId


[es(on_appear, REQUIRE=hero, on_event=EventProfileLoaded)]
def trigger_items_init_on_hero_created(evt : Event; eid : EntityId)
  query() <| $ [es] (player_profile__allItems : Array)
    load_items(player_profile__allItems, eid, false)


[es(tag=gameClient, track=player_profile__itemDeletionQueue)]
def player_base_profile_track_items_del(evt : Event; var player_profile__itemDeletionQueue : Array)
  if length(player_profile__itemDeletionQueue) == 0
    return
  var deletions : array<string>
  for it in player_profile__itemDeletionQueue
    let itemId = get_string(it, "0")
    if itemId != "0"
      deletions |> push(itemId)
  query() <| $ [es] (uniqueId : string; eid : EntityId)
    if has_value(deletions, uniqueId)
      destroyEntity(eid)
  clear(player_profile__itemDeletionQueue)
  //will not delete queued items and items that are being created. Hopefully this will never happen.


[es(tag=gameClient, track=player_profile__itemAdditionQueue)]
def player_base_profile_track_items_add(evt : Event; var player_profile__itemAdditionQueue, player_profile__allItems : Array)
  if length(player_profile__itemAdditionQueue) == 0
    return
  for newItem in player_profile__itemAdditionQueue
    player_profile__allItems |> push(newItem)
  query() <| $ [es(REQUIRE=hero, REQUIRE_NOT=initial_loadout_creation)] (eid : EntityId)
    load_items(player_profile__itemAdditionQueue, eid)
    clear(player_profile__itemAdditionQueue)


[es(tag=gameClient, on_disappear, REQUIRE=initial_loadout_creation)]
def try_add_items_when_loadout_creation_completed(evt : Event; eid : EntityId)
  query() <| $ [es] (var player_profile__itemAdditionQueue : Array)
    load_items(player_profile__itemAdditionQueue, eid)
    clear(player_profile__itemAdditionQueue)


[es(tag=gameClient, track=player_profile__itemUpdateQueue)]
def player_base_profile_track_items_update(evt : Event; var player_profile__itemUpdateQueue, player_profile__allItems : Array)
  if length(player_profile__itemUpdateQueue) == 0
    return
  query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid : EntityId;
                                   militant_extra_inventories__backpackEid : EntityId;
                                   player_on_base_components__stashEid : EntityId const)
    var updates : array<tuple<id : string; charges : int; isCorrupted : bool; isReplica : bool; parentItemId : string; slotName : string>>
    for it in player_profile__itemUpdateQueue
      let obj = get_ecs_object(it)
      if obj != null
        let itemId = get_string(*obj, "itemId", "-1")
        let charges = get_int(obj, "charges") ?? -1
        let isCorrupted = get_bool(obj, "isCorrupted") ?? false
        let isReplica = get_bool(obj, "isReplica") ?? false
        let parentItemId = get_string(obj, "parentItemId", "-1")
        let slotName = get_string(obj, "slotName", "")
        updates |> push((itemId, charges, isCorrupted, isReplica, parentItemId, slotName))
    for itemToUpdate in updates
      for item in player_profile__allItems
        var itemObj = getRW_ecs_object(item)
        if itemObj != null && ((*itemObj)["itemId"] ?? "-1") == "{itemToUpdate.id}"
          if itemToUpdate.parentItemId == (*itemObj)["parentItemId"] ?? "-1" && itemToUpdate.slotName == (*itemObj)["slotName"] ?? ""
            itemToUpdate.parentItemId = "-1"
          break
    query() <| $ [es] (eid : EntityId;
                       uniqueId : string;
                       var item__currentBoxedItemCount : int?;
                       var item__hp : float?;
                       var item__amount : int?;
                       var item__wantToBeCorrupted, item__wantToBeReplica : bool?;
                       item__cantBeCorrupted, item__cantBeReplica : Tag const?)
      for updtInfo in updates
        if updtInfo.id == uniqueId
          if updtInfo.parentItemId != "-1"
            var parentItemEid = INVALID_ENTITY_ID
            if updtInfo.slotName == "stash"
              parentItemEid = player_on_base_components__stashEid
            if updtInfo.slotName == "inventory"
              if updtInfo.parentItemId == "0"
                parentItemEid = hero_eid
              elif updtInfo.parentItemId == get_ecs_string(militant_extra_inventories__backpackEid, "uniqueId") ?? ""
                parentItemEid = militant_extra_inventories__backpackEid
            if parentItemEid != INVALID_ENTITY_ID
              move_item_to_inventory_container(eid, parentItemEid, hero_eid)
          if item__currentBoxedItemCount != null
            *item__currentBoxedItemCount = updtInfo.charges
          elif item__hp != null
            *item__hp = float(updtInfo.charges)
          elif item__amount != null
            *item__amount = updtInfo.charges
          if item__cantBeCorrupted == null
            if item__wantToBeCorrupted != null
              *item__wantToBeCorrupted = updtInfo.isCorrupted
              if updtInfo.isCorrupted
                eid |> addSubTemplate("item_enriched")
              else
                eid |> removeSubTemplate("item_enriched")
          if item__cantBeReplica == null
            if item__wantToBeReplica != null
              *item__wantToBeReplica = updtInfo.isReplica
              if updtInfo.isReplica
                eid |> addSubTemplate("item_replica")
              else
                eid |> removeSubTemplate("item_replica")
          break

    clear(player_profile__itemUpdateQueue)
