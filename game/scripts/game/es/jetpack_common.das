module jetpack_common shared
require ecs
require ecs.safe
require DagorSystem
require game.es.inventory_common
require game.es.inventory_equipment_common


def get_equipped_jetpacks_count(hero_eid : EntityId)
  let jetpacksArray = hero_eid |> get_ecs_array("human_jetpack__jetpacksList")
  return jetpacksArray != null ? *jetpacksArray |> length() : 0


def withdraw_jetpack(jetpack_eid, owner_eid : EntityId)
  query(owner_eid) <| $ [es] (human_equipment__slots : Object)
    var thisSlot = ""
    for it in human_equipment__slots
      let itemEid = get_Eid(it.value) ?? INVALID_ENTITY_ID
      if itemEid == jetpack_eid
        thisSlot = it.key
    if thisSlot == ""
      logerr("jetpack_common: Error withdrawning jetpack. It has owner. But it isn't equipped in any slot.")
      return
    unequip_equipment_from_slot(thisSlot, owner_eid)
