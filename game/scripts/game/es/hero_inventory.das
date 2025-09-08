require ecs
require ecs.safe
require game.es.ecs_common
require game.events.inventory_events


def add_watched_by_player(item_eid : EntityId)
  addSubTemplate(item_eid, "watched_by_player_item")


def remove_watched_by_player(item_eid : EntityId)
  removeSubTemplate(item_eid, "watched_by_player_item")


[es(tag=gameClient, on_appear, track=item__humanOwnerEid,
    after=(add_item_to_owners_container, set_weapon_slots_on_appear, add_equipment_to_hero_slot_on_appear,
    add_mod_to_gun_mod_slot_on_appear, add_mod_to_equipment_mod_slot_on_appear),
    REQUIRE_NOT=(item_waiting_for_container_appear, weapon_waiting_for_hero_appear, equipment_waiting_for_hero_appear,
    weapon_mod_waiting_for_weapon_appear, equipment_mod_waiting_for_equipment_appear))]
def watched_by_player_on_human_owner_change(evt : Event;
                                            eid, item__humanOwnerEid : EntityId)
  if item__humanOwnerEid |> has("watchedByPlr")
    print("[Watched Items] item {get_entity_info(eid)} change owner to local")
    add_watched_by_player(eid)
  else
    remove_watched_by_player(eid)


[es(tag=gameClient, on_event=EventComponentsDisappear, REQUIRE=watchedPlayerItem)]
def check_tag_was_deleted_by_server(evt : Event;
                                    eid, item__humanOwnerEid : EntityId)
  if item__humanOwnerEid |> has("watchedByPlr")
    print("[Watched Items] item {get_entity_info(eid)} restore tag after server recreation")
    addSubTemplate(eid, "watched_by_player_item")


[es(tag=gameClient, on_appear, REQUIRE=watchedByPlr)]
def add_watched_item_by_player_on_watched_player_appear(evt : Event;
                                                        inventories_owner__inventoryEids : EidList;
                                                        human_equipment__slots : Object;
                                                        human_weap__gunEids : EidList)
  print("[Watched Items] add tags after new local player appear")
  for inventoryEid in inventories_owner__inventoryEids
    query(inventoryEid) <| $ [es] (itemContainer : EidList)
      for itemEid in itemContainer
        add_watched_by_player(itemEid)

  for equipmentSlot in human_equipment__slots
    let equipmentEid = get_Eid(equipmentSlot.value) ?? INVALID_ENTITY_ID
    if doesEntityExist(equipmentEid)
      add_watched_by_player(equipmentEid)
    query(equipmentEid) <| $ [es] (equipment_mods__curModInSlots : Object)
      for equipmentModInSlot in equipment_mods__curModInSlots
        let equipmentModEid = get_Eid(equipmentModInSlot.value) ?? INVALID_ENTITY_ID
        if doesEntityExist(equipmentModEid)
          add_watched_by_player(equipmentModEid)

  for weaponEid in human_weap__gunEids
    query(weaponEid) <| $ [es] (gun_mods__curModInSlots : Object)
      for weaponModInSlot in gun_mods__curModInSlots
        let weaponModEid = get_Eid(weaponModInSlot.value) ?? INVALID_ENTITY_ID
        add_watched_by_player(weaponModEid)
      add_watched_by_player(weaponEid)


[es(tag=gameClient, on_disappear, REQUIRE=watchedByPlr)]
def remove_watched_item_by_player_on_watched_player_disappear(evt : Event;
                                                              inventories_owner__inventoryEids : EidList;
                                                              human_weap__gunEids : EidList;
                                                              human_equipment__slots : Object)
  print("[Watched Items] remove tags after local player disappear")
  for inventoryEid in inventories_owner__inventoryEids
    query(inventoryEid) <| $ [es] (itemContainer : EidList)
      for itemEid in itemContainer
        remove_watched_by_player(itemEid)

  for equipmentSlot in human_equipment__slots
    let equipmentEid = get_Eid(equipmentSlot.value) ?? INVALID_ENTITY_ID
    query(equipmentEid) <| $ [es] (equipment_mods__curModInSlots : Object)
      for equipmentModInSlot in equipment_mods__curModInSlots
        let equipmentModEid = get_Eid(equipmentModInSlot.value) ?? INVALID_ENTITY_ID
        if doesEntityExist(equipmentModEid)
          remove_watched_by_player(equipmentModEid)
      remove_watched_by_player(equipmentEid)

  for weaponEid in human_weap__gunEids
    query(weaponEid) <| $ [es] (gun_mods__curModInSlots : Object)
      for weaponModInSlot in gun_mods__curModInSlots
        let weaponModEid = get_Eid(weaponModInSlot.value) ?? INVALID_ENTITY_ID
        remove_watched_by_player(weaponModEid)
      remove_watched_by_player(weaponEid)
