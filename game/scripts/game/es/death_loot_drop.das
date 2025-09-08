require ecs
require ecs.safe
require DngHuman
require DagorSystem
require game.events.events_game
require game.es.inventory_common
require game.es.inventory_item_common
require game.es.inventory_checks_common
require game.es.inventory_weapon_common
require game.es.inventory_equipment_common
require game.es.inventory_death_drop_common
require game.es.inventory_equipment_mod_common
require game.es.inventory_drop_common
require game.es.human_weap_common


[es(tag=server, REQUIRE=human_inventory__deathDrop)]
def human_inventory_death_drop_died(evt : EventEntityDied; eid : EntityId)
  drop_death_drop_loot(eid)


[es(tag=server, on_appear, REQUIRE=(deadEntity, drop_all_items_on_death))]
def drop_all_items_on_death(evt : Event;
                            eid aka human_eid : EntityId;
                            itemContainer : EidList;
                            human_weap__gunEids : EidList;
                            var human_weap__currentGunSlot : int&;
                            var human_weap__previousGunSlot : int&;
                            var human_equipment__slots : Object&)
  // Drop gun
  set_current_gun(human_eid, human_weap__gunEids, int(HUWeaponSlots.EWS_UNARMED),
    human_weap__currentGunSlot, human_weap__previousGunSlot)

  for weaponSlotIdx in range(int(HUWeaponSlots.EWS_NUM))
    unequip_weapon_from_slot(weaponSlotIdx, human_eid)

  // Drop equipment
  for equipmentSlot in human_equipment__slots
    let slotItemEid = get_Eid(equipmentSlot.value) ?? INVALID_ENTITY_ID
    if slotItemEid != INVALID_ENTITY_ID
      if has(slotItemEid, "item__dontUnequipOnDeath")
        unequip_all_equipment_mods(slotItemEid, human_eid)
        continue

      if !doesEntityExist(slotItemEid)
        print("[INVENTORY] Equipment <{slotItemEid}> <{getEntityTemplateName(slotItemEid)}> (slot={equipmentSlot.key}) is already destroyed, and cannot be moved to corpse <{eid}> <{getEntityTemplateName(eid)}>")
        continue

      unequip_equipment_from_slot(equipmentSlot.key, human_eid)


  // Drop items
  for itemEid in itemContainer
    drop_item(itemEid, human_eid)


[es(tag=server, on_appear, after=set_human_inventory_max_volume_from_capacity, REQUIRE=external_inventory_container)]
def init_looting_corpse_container(evt : Event;
                                  eid, ragdoll_phys_obj__attachedTo : EntityId)
  query(ragdoll_phys_obj__attachedTo) <| $ [es] (human_weap__gunEids : EidList;
                                                 human_inventory__dropOnGroundGunSlots : IntList;
                                                 human_inventory__dropOnGroundEquipmentSlots : StringList;
                                                 var human_equipment__slots : Object&;
                                                 var human_weap__currentGunSlot : int&;
                                                 var human_weap__previousGunSlot : int&;
                                                 itemContainer : EidList)
    // Detach current gun
    set_current_gun(ragdoll_phys_obj__attachedTo, human_weap__gunEids, int(HUWeaponSlots.EWS_UNARMED),
      human_weap__currentGunSlot, human_weap__previousGunSlot)

    for weaponSlotIdx in range(int(HUWeaponSlots.EWS_NUM))
      if has_value(human_inventory__dropOnGroundGunSlots, weaponSlotIdx)
        unequip_weapon_from_slot(weaponSlotIdx, ragdoll_phys_obj__attachedTo)
      else
        unequip_weapon_from_slot(weaponSlotIdx, ragdoll_phys_obj__attachedTo, eid)

    for equipmentSlot in human_equipment__slots
      let slotItemEid = get_Eid(equipmentSlot.value) ?? INVALID_ENTITY_ID
      // monsters have eid of itself in chronogen slot, to avoid loggers, the condition below has been added
      if slotItemEid != INVALID_ENTITY_ID && slotItemEid != ragdoll_phys_obj__attachedTo
        if has(slotItemEid, "item__dontUnequipOnDeath")
          unequip_all_equipment_mods(slotItemEid, ragdoll_phys_obj__attachedTo, eid)
          continue

        if !doesEntityExist(slotItemEid)
          print("[INVENTORY] Equipment <{slotItemEid}> <{getEntityTemplateName(slotItemEid)}> (slot={equipmentSlot.key}) is already destroyed, and cannot be moved to corpse <{eid}> <{getEntityTemplateName(eid)}>")
          continue

        if slotItemEid == eid
          logerr("[INVENTORY] Try move equipment <{slotItemEid}> <{getEntityTemplateName(slotItemEid)}> inside itself from slot <{equipmentSlot.key}>.")
          continue
        if !is_inventory_have_volume_for_item(eid, slotItemEid)
          logerr("[INVENTORY] No free volume for moving equipment <{slotItemEid}> <{getEntityTemplateName(slotItemEid)}> (slot={equipmentSlot.key}) to corpse <{eid}> <{getEntityTemplateName(eid)}>")
          continue

        if has_value(human_inventory__dropOnGroundEquipmentSlots, equipmentSlot.key)
          unequip_equipment_from_slot(equipmentSlot.key, ragdoll_phys_obj__attachedTo)
        else
          unequip_equipment_from_slot(equipmentSlot.key, ragdoll_phys_obj__attachedTo, eid)

    var items_to_move : array<EntityId>
    for itemEid in itemContainer
      items_to_move |> push(itemEid)
    for itemEid in items_to_move
      move_item_to_inventory_container(itemEid, eid, ragdoll_phys_obj__attachedTo)
