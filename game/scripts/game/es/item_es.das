require ecs
require inventory
require DngNet
require DagorSystem
require game.events.events_game
require game.events.events_active_matter

[es(tag=server, on_appear)]
def items_es(evt : Event; eid : EntityId; item__proto : string; var item__id : int&)
  if empty(item__proto)
    logerr("item__proto is empty for entity <{eid}> with template '{getEntityTemplateName(eid)}'")
    return
  if item__id == INVALID_ITEM_ID
    item__id = int(ecs_hash(item__proto))


[es(on_appear, track=item__humanOwnerEid)]
def set_container_items_human_owner(evt : Event;
                                    item__humanOwnerEid aka this_item__humanOwnerEid : EntityId;
                                    itemContainer : EidList)
  for item in itemContainer
    query(item) <| $ [es] (var item__humanOwnerEid aka child_item__humanOwnerEid : EntityId&)
      child_item__humanOwnerEid = this_item__humanOwnerEid


[es(on_appear, track=item__humanOwnerEid)]
def set_equipment_items_human_owner(evt : Event;
                                    item__humanOwnerEid aka this_item__humanOwnerEid : EntityId;
                                    var equipment_mods__curModInSlots : Object)
  for m in equipment_mods__curModInSlots
    let item = get_Eid(m.value) ?? INVALID_ENTITY_ID
    if item != INVALID_ENTITY_ID
      query(item) <| $ [es] (var item__humanOwnerEid aka child_item__humanOwnerEid : EntityId&)
        child_item__humanOwnerEid = this_item__humanOwnerEid


[es(on_appear, track=item__humanOwnerEid)]
def set_weapon_mods_human_owner(evt : Event;
                                item__humanOwnerEid aka this_item__humanOwnerEid : EntityId;
                                gun_mods__curModInSlots : Object)
  for mod in gun_mods__curModInSlots
    let modEid = get_Eid(mod.value) ?? INVALID_ENTITY_ID
    query(modEid) <| $ [es] (var item__humanOwnerEid aka child_item__humanOwnerEid : EntityId&)
      child_item__humanOwnerEid = this_item__humanOwnerEid


[es(tag=server, REQUIRE_NOT=item_heal, on_appear)]
def use_item_on_appear(evt : Event; eid, use_item_on_appear__targetEid : EntityId)
  sendEventImmediate(eid, TryUseItem(userEid = use_item_on_appear__targetEid))


[es(tag=server, on_appear, after=(set_container_items_human_owner, set_weapon_mods_human_owner))]
def set_item_initial_player_owner(evt : Event;
                                  item__humanOwnerEid : EntityId;
                                  var item__initialPlayerOwnerEid : EntityId&)
  if !item__initialPlayerOwnerEid
    query(item__humanOwnerEid) <| $ [es] (possessedByPlr : EntityId)
      item__initialPlayerOwnerEid = possessedByPlr


[es(tag=server, REQUIRE_NOT=boxedItem, on_appear, track=item__humanOwnerEid, after=set_item_initial_player_owner)]
def update_item_is_found_in_raid(evt : Event;
                                 item__humanOwnerEid : EntityId;
                                 item__initialPlayerOwnerEid : EntityId;
                                 var item__isFoundInRaid : bool&)
  if item__initialPlayerOwnerEid == INVALID_ENTITY_ID
    item__isFoundInRaid = true
    return

  query(item__humanOwnerEid) <| $ [es] (possessedByPlr : EntityId)
    item__isFoundInRaid = possessedByPlr != item__initialPlayerOwnerEid


[es(tag=server, REQUIRE_NOT=boxedItem, on_appear, after=set_item_initial_player_owner)]
def init_item_created_by_zone(evt : Event;
                              eid : EntityId;
                              item__initialPlayerOwnerEid : EntityId)
  if item__initialPlayerOwnerEid == INVALID_ENTITY_ID
    remote_add_sub_template(eid, "item_created_by_zone")
    return
