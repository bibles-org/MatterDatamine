module damage_model_healing_common shared

require ecs
require game.es.status_tip_common
require DngHuman
require DngNet
require game.es.inventory_checks_common
require game.es.inventory_item_common
require game.es.inventory_common
require game.events.events_active_matter
require game.events.events
require game.events.events_game


def get_hot_heal_item(hero_eid : EntityId; item_container : EidList)
  var result = INVALID_ENTITY_ID
  for itemEid in item_container
    if has(itemEid, "item_heal_hot")
      result = itemEid
      break
  if result == INVALID_ENTITY_ID
    foreach_pocket_slot(hero_eid) <| $ [unused_argument(modIdx, equipment)] (modIdx : int;
                                                                             equipment : tuple<slot : string; eid : EntityId>;
                                                                             mod : tuple<slot : string; eid : EntityId>)
      if result == INVALID_ENTITY_ID && has(mod.eid, "item_heal_hot")
        result = mod.eid
  return result


def get_stream_heal_item(hero_eid : EntityId; item_container : EidList)
  var result = INVALID_ENTITY_ID
  for itemEid in item_container
    if has(itemEid, "item_heal_stream")
      result = itemEid
      break
  if result == INVALID_ENTITY_ID
    foreach_pocket_slot(hero_eid) <| $ [unused_argument(modIdx, equipment)] (modIdx : int;
                                                                             equipment : tuple<slot : string; eid : EntityId>;
                                                                             mod : tuple<slot : string; eid : EntityId>)
      if result == INVALID_ENTITY_ID && has(mod.eid, "item_heal_stream")
        result = mod.eid
  return result


def get_heal_item(hero_eid : EntityId; item_container : EidList)
  var result = INVALID_ENTITY_ID
  for itemEid in item_container
    if has(itemEid, "item_heal_ampoule") && !has(itemEid, "item_heal_hot") && !has(itemEid, "item_heal_revive")
      result = itemEid
      break
  if result == INVALID_ENTITY_ID
    var boxAmmoCount = INT_MAX
    for itemEid in item_container
      query(itemEid) <| $ [es(REQUIRE=item_healkit_magazine)] (item__currentBoxedItemCount : int)
        if item__currentBoxedItemCount > 0 && item__currentBoxedItemCount < boxAmmoCount
          result = itemEid
          boxAmmoCount = item__currentBoxedItemCount

  if result == INVALID_ENTITY_ID
    foreach_pocket_slot(hero_eid) <| $ [unused_argument(modIdx, equipment)] (modIdx : int;
                                                                             equipment : tuple<slot : string; eid : EntityId>;
                                                                             mod : tuple<slot : string; eid : EntityId>)
      if result == INVALID_ENTITY_ID && has(mod.eid, "item_heal_ampoule") && !has(mod.eid, "item_heal_hot") && !has(mod.eid, "item_heal_revive")
        result = mod.eid

  if result == INVALID_ENTITY_ID
    foreach_pocket_slot(hero_eid) <| $ [unused_argument(modIdx, equipment)] (modIdx : int;
                                                                             equipment : tuple<slot : string; eid : EntityId>;
                                                                             mod : tuple<slot : string; eid : EntityId>)
      if result == INVALID_ENTITY_ID
        query(mod.eid) <| $ [es(REQUIRE=item_healkit_magazine)] (item__currentBoxedItemCount : int)
          if item__currentBoxedItemCount > 0
            result = mod.eid

  return result


def get_revive_item(hero_eid : EntityId; item_container : EidList)
  var result = INVALID_ENTITY_ID
  for itemEid in item_container
    if has(itemEid, "item_heal_revive")
      result = itemEid
      break
  if result == INVALID_ENTITY_ID
    foreach_pocket_slot(hero_eid) <| $ [unused_argument(modIdx, equipment)] (modIdx : int;
                                                                             equipment : tuple<slot : string; eid : EntityId>;
                                                                             mod : tuple<slot : string; eid : EntityId>)
      if result == INVALID_ENTITY_ID && has(mod.eid, "item_heal_revive")
        result = mod.eid
  return result


def verify_healing_attempt(hero_eid : EntityId; item_eid = INVALID_ENTITY_ID)
  var res = false

  query(hero_eid) <| $ [es] (human_damage_model__sumHpAllBodyParts : float;
                             human_damage_model__sumMaxHpAllBodyParts : float;
                             itemContainer : EidList;
                             isDowned : bool;
                             human_inventory__canHeal : bool)
    if !human_inventory__canHeal
      return

    // painkillers and injectors apply lasting effects, so they can be used even if health is full
    if item_eid != INVALID_ENTITY_ID && (has(item_eid, "item_heal_revive") || has(item_eid, "item_heal_hot"))
      res = true
      return

    if human_damage_model__sumHpAllBodyParts >= human_damage_model__sumMaxHpAllBodyParts
      return

    if item_eid != INVALID_ENTITY_ID
      res = true
      query(item_eid) <| $ [es(REQUIRE=item_healkit_magazine)] (item__currentBoxedItemCount : int)
        res = item__currentBoxedItemCount > 0
    else
      if ((isDowned && !!get_revive_item(hero_eid, itemContainer)) ||
          !!get_hot_heal_item(hero_eid, itemContainer) ||
          !!get_stream_heal_item(hero_eid, itemContainer) ||
          !!get_heal_item(hero_eid, itemContainer))
        res = true
  return res


def get_most_needed_heal_item(hero_eid : EntityId)
  var itemToUse = INVALID_ENTITY_ID
  query(hero_eid) <| $ [es] (itemContainer : EidList;
                             isDowned : bool)
    if isDowned
      itemToUse = get_revive_item(hero_eid, itemContainer)
    if itemToUse == INVALID_ENTITY_ID
      itemToUse = get_heal_item(hero_eid, itemContainer)
    if itemToUse == INVALID_ENTITY_ID
      itemToUse = get_stream_heal_item(hero_eid, itemContainer)
    if itemToUse == INVALID_ENTITY_ID
      itemToUse = get_hot_heal_item(hero_eid, itemContainer)
  return itemToUse


def set_wish_part_to_heal(hero_eid : EntityId;
                          part : string)
  query(hero_eid) <| $ [es] (human_damage_model__parts : Object;
                             var human_damage_model__wishPartIdx : int&)
    human_damage_model__wishPartIdx = find_index_of_part(human_damage_model__parts, part)


def find_index_of_part(human_damage_model__parts : Object;
                       part_to_find : string)
  for part, idx in human_damage_model__parts, iter_range(human_damage_model__parts)
    if part.key == part_to_find
      return idx
  return -1


def show_healing_tip(hero_eid : EntityId; item_eid = INVALID_ENTITY_ID)
  var statusTip = ""
  query(hero_eid) <| $ [es(REQUIRE=hero)] (human_damage_model__sumHpAllBodyParts : float;
                                           human_damage_model__sumMaxHpAllBodyParts : float;
                                           itemContainer : EidList;
                                           isDowned : bool)

    // painkillers and injectors apply lasting effects, so they can be used even if health is full
    if item_eid != INVALID_ENTITY_ID && (has(item_eid, "item_heal_revive") || has(item_eid, "item_heal_hot"))
      return

    if human_damage_model__sumHpAllBodyParts >= human_damage_model__sumMaxHpAllBodyParts
      statusTip = "status_tip_full_health"
      return

    if item_eid != INVALID_ENTITY_ID
      query(item_eid) <| $ [es(REQUIRE=item_healkit_magazine)] (item__currentBoxedItemCount : int)
        if item__currentBoxedItemCount  == 0
          statusTip = "status_tip_medkit_is_empty"
    else
      if (!(isDowned && !!get_revive_item(hero_eid, itemContainer)) &&
          !get_hot_heal_item(hero_eid, itemContainer) &&
          !get_stream_heal_item(hero_eid, itemContainer) &&
          !get_heal_item(hero_eid, itemContainer))
        statusTip = "status_tip_no_healkits_in_inventory"
  if !empty(statusTip)
    create_status_tip(statusTip)

