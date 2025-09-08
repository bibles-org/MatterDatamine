require ecs
require game.events.events_active_matter
require game.es.ecs_common

def isStash(inventory_eid, hero_eid : EntityId)
  var res = false
  query(hero_eid) <| $ [es] (player_on_base_components__stashEid : EntityId)
    res = player_on_base_components__stashEid == inventory_eid
  return res

def isInventory(inventory_eid, hero_eid : EntityId)
  return inventory_eid == hero_eid

def isBackpack(inventory_eid, hero_eid : EntityId)
  var res = false
  query(hero_eid) <| $ [es] (militant_extra_inventories__backpackEid : EntityId)
    res = inventory_eid != INVALID_ENTITY_ID && militant_extra_inventories__backpackEid == inventory_eid
  return res

def isSafepack(inventory_eid, hero_eid : EntityId)
  var res = false
  query(hero_eid) <| $ [es] (militant_extra_inventories__safepackEid : EntityId)
    res = inventory_eid != INVALID_ENTITY_ID && militant_extra_inventories__safepackEid == inventory_eid
  return res

[es(tag=gameClient, REQUIRE=watchedPlayerItem, REQUIRE_NOT=(item__hideInInventory, item_waiting_for_container_appear),
    on_appear)]
def set_hero_item_container_on_init(evt : Event;
                                    eid : EntityId;
                                    item__humanOwnerEid : EntityId;
                                    item__containerOwnerEid : EntityId)
  if item__containerOwnerEid == INVALID_ENTITY_ID
    return
  print("[INVENTORY] {get_entity_info(eid)} appears in container {get_entity_info(item__containerOwnerEid)}")
  if isStash(item__containerOwnerEid, item__humanOwnerEid)
    addSubTemplate(eid, "item_in_stash")
  elif isInventory(item__containerOwnerEid, item__humanOwnerEid)
    addSubTemplate(eid, "item_in_inventory")
  elif isBackpack(item__containerOwnerEid, item__humanOwnerEid)
    addSubTemplate(eid, "item_in_backpack")
  elif isSafepack(item__containerOwnerEid, item__humanOwnerEid)
    addSubTemplate(eid, "item_in_safepack")


[es(tag=gameClient, REQUIRE=watchedPlayerItem, on_event=EventComponentsDisappear)]
def remove_hero_item_container_on_disappear(evt : Event;
                                            eid : EntityId)
  print("[INVENTORY] {get_entity_info(eid)} no more watched by player")
  removeSubTemplate(eid, "item_in_stash")
  removeSubTemplate(eid, "item_in_inventory")
  removeSubTemplate(eid, "item_in_backpack")
  removeSubTemplate(eid, "item_in_safepack")


[es(tag=gameClient, REQUIRE=watchedPlayerItem, track=item__containerOwnerEid, REQUIRE_NOT=item__hideInInventory)]
def change_hero_item_container_on_move(evt : Event;
                                       eid : EntityId;
                                       item__humanOwnerEid : EntityId;
                                       item__containerOwnerEid : EntityId)
  print("[INVENTORY] {get_entity_info(eid)} is moved to container {get_entity_info(item__containerOwnerEid)}")
  // invalidate previous container tag
  removeSubTemplate(eid, "item_in_stash")
  removeSubTemplate(eid, "item_in_inventory")
  removeSubTemplate(eid, "item_in_backpack")
  removeSubTemplate(eid, "item_in_safepack")
  // set new container tag
  if item__containerOwnerEid == INVALID_ENTITY_ID
    return
  if isStash(item__containerOwnerEid, item__humanOwnerEid)
    addSubTemplate(eid, "item_in_stash")
  elif isInventory(item__containerOwnerEid, item__humanOwnerEid)
    addSubTemplate(eid, "item_in_inventory")
  elif isBackpack(item__containerOwnerEid, item__humanOwnerEid)
    addSubTemplate(eid, "item_in_backpack")
  elif isSafepack(item__containerOwnerEid, item__humanOwnerEid)
    addSubTemplate(eid, "item_in_safepack")


[es(tag=gameClient, on_appear, track=militant_extra_inventories__backpackEid,
    REQUIRE=watchedByPlr)]
def update_hero_item_container_on_backpack_change(evt : Event;
                                                  militant_extra_inventories__backpackEid : EntityId)
  print("[INVENTORY] current backpack is changed to {get_entity_info(militant_extra_inventories__backpackEid)}")
  query() <| $ [es(REQUIRE=item_in_backpack)] (eid : EntityId; item__containerOwnerEid : EntityId)
    if item__containerOwnerEid != militant_extra_inventories__backpackEid
      removeSubTemplate(eid, "item_in_backpack")
  query(militant_extra_inventories__backpackEid) <| $ [es] (itemContainer : EidList)
    for item in itemContainer
      addSubTemplate(item, "item_in_backpack")


[es(tag=gameClient, on_appear, track=militant_extra_inventories__safepackEid,
    REQUIRE=watchedByPlr)]
def update_hero_item_container_on_safepack_change(evt : Event;
                                                  militant_extra_inventories__safepackEid : EntityId)
  print("[INVENTORY] current safepack is changed to {get_entity_info(militant_extra_inventories__safepackEid)}")
  query() <| $ [es(REQUIRE=item_in_safepack)] (eid : EntityId; item__containerOwnerEid : EntityId)
    if item__containerOwnerEid != militant_extra_inventories__safepackEid
      removeSubTemplate(eid, "item_in_safepack")
  query(militant_extra_inventories__safepackEid) <| $ [es] (itemContainer : EidList)
    for item in itemContainer
      addSubTemplate(item, "item_in_safepack")


[es(tag=gameClient, on_appear, track=player_on_base_components__stashEid,
    after=set_player_stash_inventory_state_ui, REQUIRE=watchedByPlr)]
def update_hero_item_container_on_stash_change(evt : Event;
                                               player_on_base_components__stashEid : EntityId)
  print("[INVENTORY] current stash is changed to {get_entity_info(player_on_base_components__stashEid)}")
  query() <| $ [es(REQUIRE=item_in_stash)] (eid : EntityId; item__containerOwnerEid : EntityId)
    if item__containerOwnerEid != player_on_base_components__stashEid
      removeSubTemplate(eid, "item_in_stash")
  query(player_on_base_components__stashEid) <| $ [es] (itemContainer : EidList)
    for item in itemContainer
      addSubTemplate(item, "item_in_stash")
