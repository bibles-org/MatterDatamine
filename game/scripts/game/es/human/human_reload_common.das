module human_reload_common shared
require ecs
require ecs.common
require inventory
require DaWeaponProps
require WeapHelpers
require game.es.inventory_checks_common


enum ReloadAmmoMode
  CONSUME = 0
  INFINITE = 1


enum GunReloadStyle
  RELOAD_STYLE_SIMPLE
  RELOAD_STYLE_ALT
  RELOAD_STYLE_ALT_JAMMED
  RELOAD_STYLE_JAMMED


struct AmmoData
  itemIndex : int
  availableAmmoCount : int
  maxShells : int
  ammoPropsId : int


def find_magazine_for_gun(magazines_list : StringList;
                          item_container : EidList)
  var bestMagazineEid = INVALID_ENTITY_ID
  var bestAmmoCount = -1

  for itemEid in item_container
    query(itemEid) <| $ [es(REQUIRE_NOT=item__blockInventoryMove)] (gunAttachable__slotName, item__proto : string;
                                                                    item__currentBoxedItemCount : int)
      if gunAttachable__slotName != "magazine"
        return
      if find_index(magazines_list, item__proto) != -1 && item__currentBoxedItemCount > bestAmmoCount
        bestMagazineEid = itemEid
        bestAmmoCount = item__currentBoxedItemCount

  return bestMagazineEid


def find_magazine_for_gun(magazines_list : StringList;
                          inventoryEid : EntityId)
  var bestMagazineEid = INVALID_ENTITY_ID
  query(inventoryEid) <| $ [es] (itemContainer : EidList)
    bestMagazineEid = find_magazine_for_gun(magazines_list, itemContainer)
  return bestMagazineEid


def find_wished_shell_for_gun(wished_ammo_id : int;
                              hero_eid : EntityId)
  var res = INVALID_ENTITY_ID
  if wished_ammo_id == INVALID_ITEM_ID
    return res
  query(hero_eid) <| $ [es] (itemContainer : EidList)
    for itemEid in itemContainer
      query(itemEid) <| $ [es] (item__id : int)
        if item__id == wished_ammo_id
          res = itemEid
      if res != INVALID_ENTITY_ID
        return
    foreach_pocket_slot(hero_eid) <| $ [unused_argument(modIdx, equipment)] (modIdx : int;
                                                                             equipment : tuple<slot : string; eid : EntityId>;
                                                                             mod : tuple<slot : string; eid : EntityId>)
      if res == INVALID_ENTITY_ID
        query(mod.eid) <| $ [es] (item__id : int)
          if item__id == wished_ammo_id
            res = mod.eid
  return res


def find_shell_for_gun(gun__shell_prop_ids : GunShellPropIds;
                       hero_eid : EntityId)
  var res = INVALID_ENTITY_ID
  query(hero_eid) <| $ [es] (itemContainer : EidList)
    for itemEid in itemContainer
      query(itemEid) <| $ [es] (shell_props : ShellPropIds)
        if is_shell_for_gun(shell_props, gun__shell_prop_ids)
          res = itemEid
      if res != INVALID_ENTITY_ID
        return
    foreach_pocket_slot(hero_eid) <| $ [unused_argument(modIdx, equipment)] (modIdx : int;
                                                                             equipment : tuple<slot : string; eid : EntityId>;
                                                                             mod : tuple<slot : string; eid : EntityId>)
      if res == INVALID_ENTITY_ID
        query(mod.eid) <| $ [es] (shell_props : ShellPropIds)
          if is_shell_for_gun(shell_props, gun__shell_prop_ids)
            res = mod.eid
  return res
