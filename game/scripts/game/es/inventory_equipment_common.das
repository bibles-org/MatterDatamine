module inventory_equipment_common shared
require ecs
require DngNet
require ecs.safe
require DagorSystem
require game.es.ecs_common
require game.events.inventory_events
require game.es.inventory_checks_common
require game.es.inventory_item_common
require game.es.inventory_drop_common


def private unequip_equipment_from_slot(equipment_eid : EntityId;
                                        to_inventory_eid : EntityId;
                                        ignore_item_volume_value = 0f)
  query(equipment_eid) <| $ [es] (var item__containerOwnerEid, item__lastContainerOwnerEid, item__humanOwnerEid : EntityId&;
                                  var item__recognizedByPlayers : EidList;
                                  item__volume : float = 0.f;
                                  hammerspace_item : Tag const?;
                                  var equipable_item__curSlot : das_string;
                                  var slot_attach__attachedTo : EntityId?)
    let lastHumanOwner = item__humanOwnerEid
    var newInventoryEid = INVALID_ENTITY_ID
    var toInventoryEid = to_inventory_eid

    if hammerspace_item != null
      toInventoryEid = get_Eid(lastHumanOwner, "hammerspace_inventory_owner__inventoryEid") ?? INVALID_ENTITY_ID

    var checkVolumeValue = item__volume
    checkVolumeValue = max(0.f, checkVolumeValue - ignore_item_volume_value)


    if ((toInventoryEid != INVALID_ENTITY_ID && is_inventory_have_free_volume(toInventoryEid, checkVolumeValue))
        || is_can_move_to_safepack_with_overflow(toInventoryEid, equipment_eid))
      query(item__humanOwnerEid) <| $ [es] (possessedByPlr : EntityId)
        if !has_value(item__recognizedByPlayers, possessedByPlr)
          item__recognizedByPlayers |> push(possessedByPlr)
      newInventoryEid = toInventoryEid
      query(toInventoryEid) <| $ [es] (inventory__humanOwnerEid : EntityId; var human_inventory__currentVolume : int&)
        human_inventory__currentVolume += convert_volume_to_int(item__volume)
        item__containerOwnerEid = toInventoryEid
        item__humanOwnerEid = inventory__humanOwnerEid

      if slot_attach__attachedTo != null
        *slot_attach__attachedTo = INVALID_ENTITY_ID
      send_net_event(equipment_eid, EventOnUnequipingToInventory(newInventoryEid = toInventoryEid, lastOwnerEid = lastHumanOwner))
    else
      newInventoryEid = drop_item(equipment_eid, lastHumanOwner)
    item__lastContainerOwnerEid = lastHumanOwner

    send_net_event(lastHumanOwner, EventOnEquipmentUnequipped(equipmentEid = equipment_eid, toInventoryEid = newInventoryEid, slotName = string(equipable_item__curSlot)))
    query(lastHumanOwner) <| $ [es] (var human_equipment__slots : Object&)
      var slotObjectEid = getRW_Eid(human_equipment__slots[string(equipable_item__curSlot)])
      if slotObjectEid != null && *slotObjectEid == equipment_eid
        *slotObjectEid = INVALID_ENTITY_ID
    equipable_item__curSlot := ""
    print("[INVENTORY] Equipment {get_entity_info(equipment_eid)} dropped from hero {get_entity_info(lastHumanOwner)} to container {get_entity_info(toInventoryEid)}.")


def unequip_equipment_from_slot(slot_name : string;
                                hero_eid : EntityId;
                                to_inventory_eid = INVALID_ENTITY_ID)
  query(hero_eid) <| $ [es] (human_equipment__slots : Object)
    let slotObjectEid = get_Eid(human_equipment__slots[slot_name])
    if slotObjectEid != null
      let previousItemEid = *slotObjectEid
      unequip_equipment_from_slot(*slotObjectEid, to_inventory_eid)
      send_net_event(hero_eid, EventOnEquipmentChanged(oldEquipmentEid = previousItemEid, newEquipmentEid = INVALID_ENTITY_ID, slotName = slot_name))
    else
      logerr("[INVENTORY] Slot <{slot_name}> not found for unequipping item from {get_entity_info(hero_eid)}.")


def equip_equipment_to_slot(equipment_eid : EntityId;
                            slot_name : string;
                            hero_eid : EntityId;
                            drop_prev_to_cont_eid : EntityId = INVALID_ENTITY_ID)
  query(hero_eid) <| $ [es] (var human_equipment__slots : Object&)
    var slotObjectEid = getRW_Eid(human_equipment__slots[slot_name])
    if slotObjectEid == null
      return

    let previousItemEid = *slotObjectEid
    if previousItemEid == equipment_eid
      return

    query(equipment_eid) <| $ [es] (var item__containerOwnerEid, item__lastContainerOwnerEid, item__humanOwnerEid : EntityId&;
                                    var item__isOnGround : bool?;
                                    var equipable_item__curSlot : das_string&;
                                    item__volume : float = 0.f;
                                    item__inventoryExtension : float  = 0.f)
      query(item__containerOwnerEid) <| $ [es] (var human_inventory__currentVolume : int&)
        human_inventory__currentVolume -= convert_volume_to_int(item__volume)
      unequip_equipment_from_slot(previousItemEid, drop_prev_to_cont_eid, (drop_prev_to_cont_eid == hero_eid) ? item__inventoryExtension : 0.f)
      equipable_item__curSlot := slot_name
      *slotObjectEid = equipment_eid
      if item__isOnGround != null && *item__isOnGround
        *item__isOnGround = false
        item__lastContainerOwnerEid = INVALID_ENTITY_ID
        item__containerOwnerEid = INVALID_ENTITY_ID
      else
        item__lastContainerOwnerEid = item__containerOwnerEid
        item__containerOwnerEid = INVALID_ENTITY_ID

      item__humanOwnerEid = hero_eid
      send_net_event(equipment_eid, EventOnEquipingAsEquipment(heroEid = hero_eid, fromInventoryEid = item__lastContainerOwnerEid))
      print("[INVENTORY] Equipment {get_entity_info(equipment_eid)} equipped to hero {get_entity_info(hero_eid)} to slot <{slot_name}>.")
      send_net_event(hero_eid, EventOnEquipmentEquipped(equipmentEid = equipment_eid, slotName = slot_name))

    send_net_event(hero_eid, EventOnEquipmentChanged(oldEquipmentEid = previousItemEid, newEquipmentEid = equipment_eid, slotName = slot_name))


def create_item_in_equipment(equipment_template : string; slot_name : string; hero_eid : EntityId;
                             init_block : block<(var init_obj : ComponentsInitializer) : void>)
  unequip_equipment_from_slot(slot_name, hero_eid)
  var equipmentEid = INVALID_ENTITY_ID
  query(hero_eid) <| $ [es] (human_equipment__slots : Object;
                             human_equipment__slotsFlags : Object)
    if !has(human_equipment__slots, slot_name)
      logerr("[INVENTORY] Equipment '{equipment_template}' cannot be created in slot '{slot_name}' - there is no such slot in '{hero_eid}<{getEntityTemplateName(hero_eid)}>'!")
      equipmentEid = create_item_in_inventory_container(equipment_template, hero_eid, init_block)
      return

    if is_equipment_slot_removed(slot_name, human_equipment__slotsFlags)
      logerr("[INVENTORY] Equipment '{equipment_template}' cannot be created in slot '{slot_name}' - slot is removed! hero='{hero_eid}<{getEntityTemplateName(hero_eid)}>'!")
      equipmentEid = create_item_in_inventory_container(equipment_template, hero_eid, init_block)
      return

    let itemTempl = getOrBuildTemplateByName(equipment_template)
    if itemTempl == null
      logerr("[INVENTORY] Can't find template for equipment: <{equipment_template}>")
      return
    let slotSubTemplate = getTemplateComponent(*itemTempl, "item__recreateInEquipment") ?? ""
    let equipmentInSlotTemplate = add_sub_template_name(equipment_template, slotSubTemplate)
    equipmentEid = createEntity(equipmentInSlotTemplate) <| $(var init)
      init |> set("slot_attach__attachedTo", hero_eid)
      init |> set("item__containerOwnerEid", INVALID_ENTITY_ID)
      init |> set("item__humanOwnerEid", hero_eid)
      init |> set("item__lastContainerOwnerEid", INVALID_ENTITY_ID)
      init |> set("item__isOnGround", false)
      init |> set("equipable_item__curSlot", slot_name)
      invoke(init_block, init)

    print("[INVENTORY] Equipment <{equipmentEid}> ({equipmentInSlotTemplate}) created to hero {get_entity_info(hero_eid)} in slot <{slot_name}>.")
  return equipmentEid


def create_item_in_equipment(equipment_template : string; slot_name : string; hero_eid : EntityId)
  return create_item_in_equipment(equipment_template, slot_name, hero_eid) <| $ [unused_argument(init)] (init) {}
