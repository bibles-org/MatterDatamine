module inventory_equipment_mod_common shared
require ecs
require DngNet
require ecs.safe
require DagorSystem
require game.es.ecs_common
require game.events.inventory_events
require game.es.inventory_checks_common
require game.es.inventory_item_common
require game.es.inventory_item_mod_common
require game.es.inventory_transactions_common
require game.es.inventory_drop_common


def unequip_equipment_mod_from_slot(equipment_mod_eid : EntityId;
                                    equipment_eid, hero_eid : EntityId;
                                    wish_to_inventory_eid : EntityId)
  query(equipment_mod_eid) <| $ [es] (item__volume : float;
                                      boxed_item__template : string = "";
                                      var item__currentBoxedItemCount : int?;
                                      var slot_attach__attachedTo : EntityId&;
                                      var equipmentAttachable__slotName : das_string;
                                      var item__recognizedByPlayers : EidList;
                                      var item__lastContainerOwnerEid : EntityId&;
                                      var item__containerOwnerEid : EntityId&;
                                      var item__humanOwnerEid : EntityId&)
    var newInventoryEid = INVALID_ENTITY_ID
    if ((wish_to_inventory_eid != INVALID_ENTITY_ID && is_inventory_have_free_volume(wish_to_inventory_eid, item__volume))
        || is_can_move_to_safepack_with_overflow(wish_to_inventory_eid, equipment_mod_eid))
      query(item__humanOwnerEid) <| $ [es] (possessedByPlr : EntityId)
        if !has_value(item__recognizedByPlayers, possessedByPlr)
          item__recognizedByPlayers |> push(possessedByPlr)
      newInventoryEid = wish_to_inventory_eid
      var newHeroOwner = INVALID_ENTITY_ID
      query(newInventoryEid) <| $ [es] (var human_inventory__currentVolume : int&;
                                        inventory__humanOwnerEid : EntityId = INVALID_ENTITY_ID)
        human_inventory__currentVolume += convert_volume_to_int(item__volume)
        newHeroOwner = inventory__humanOwnerEid
      item__lastContainerOwnerEid = INVALID_ENTITY_ID
      item__containerOwnerEid = newInventoryEid
      item__humanOwnerEid = newHeroOwner

      if !empty(boxed_item__template) && try_merge_with_boxed_item_in_inventory(newInventoryEid, boxed_item__template, *item__currentBoxedItemCount)
        (*item__currentBoxedItemCount) = -1 // invalid box will be destroyed
        destroyEntity(equipment_mod_eid)
        pass
      send_net_event(equipment_mod_eid, EventOnUnequipingToInventory(newInventoryEid = newInventoryEid, lastOwnerEid = equipment_eid))
    else
      query(item__humanOwnerEid) <| $ [es] (transform : float3x4;
                                            human_inventory__pickupRadius : float)
        if !empty(boxed_item__template) && try_merge_with_boxed_item_on_ground(transform[3], human_inventory__pickupRadius, boxed_item__template, *item__currentBoxedItemCount)
          (*item__currentBoxedItemCount) = -1 // invalid box will be destroyed
          destroyEntity(equipment_mod_eid)
        else
          newInventoryEid = drop_item(equipment_mod_eid, hero_eid)

    slot_attach__attachedTo = INVALID_ENTITY_ID
    query(equipment_eid) <| $ [es] (var equipment_mods__curModInSlots : Object&)
      if (get_Eid(equipment_mods__curModInSlots[string(equipmentAttachable__slotName)]) ?? INVALID_ENTITY_ID) == equipment_mod_eid
        equipment_mods__curModInSlots |> erase(string(equipmentAttachable__slotName))
    let slotName = string(equipmentAttachable__slotName)
    equipmentAttachable__slotName := ""
    send_net_event(hero_eid, EventOnEquipmentModUnequippedFromEquipment(equipmentModEid = equipment_mod_eid, equipmentEid = equipment_eid, toInventoryEid = newInventoryEid, slotName = slotName))
    send_net_event(hero_eid, EventOnEquipmentModUnequippedFromHero(equipmentModEid = equipment_mod_eid))
    print("[INVENTORY] Equipment mod {get_entity_info(equipment_mod_eid)} dropped from hero {get_entity_info(hero_eid)} to container {get_entity_info(newInventoryEid)}.")


def private remove_equipment_mod_from_ground_or_inventory(equipment_mod_eid : EntityId;
                                                          hero_eid : EntityId)
  query(equipment_mod_eid) <| $ [es] (var item__containerOwnerEid, item__humanOwnerEid, item__lastContainerOwnerEid : EntityId&;
                                      var item__isOnGround : bool?)
    if item__isOnGround != null && *item__isOnGround
      *item__isOnGround = false
      item__lastContainerOwnerEid = INVALID_ENTITY_ID
    else
      item__lastContainerOwnerEid = item__containerOwnerEid
    item__containerOwnerEid = INVALID_ENTITY_ID
    item__humanOwnerEid = hero_eid


def split_item_to_equipment(item_eid : EntityId;
                            slot_name : string;
                            equipment_eid : EntityId;
                            hero_eid : EntityId;
                            count : int;
                            drop_prev_to_cont_eid : EntityId = INVALID_ENTITY_ID)
  var oldEquipmentModEid = INVALID_ENTITY_ID
  query(equipment_eid) <| $ [es] (equipment_mods__curModInSlots : Object)
    oldEquipmentModEid = get_Eid(equipment_mods__curModInSlots[slot_name]) ?? INVALID_ENTITY_ID

  if !!oldEquipmentModEid
    unequip_equipment_mod_from_slot(oldEquipmentModEid, equipment_eid, hero_eid, drop_prev_to_cont_eid)

  if !is_transation_disabled()
    return //This item will be added by the profile server.

  query(item_eid) <| $ [es] (boxed_item__template : string;
                             var item__currentBoxedItemCount : int&)
    create_mod_in_equipment(boxed_item__template, slot_name, equipment_eid, hero_eid, false) <| $(init)
      init |> set("item__currentBoxedItemCount", count)
    print("[INVENTORY] Item {get_entity_info(item_eid)} splitted count = {count} to equipment {get_entity_info(equipment_eid)} on hero {get_entity_info(hero_eid)}
           to slot <{slot_name}>.")
    item__currentBoxedItemCount = item__currentBoxedItemCount - count


def equip_equipment_mod_to_slot(equipment_mod_eid : EntityId;
                                slot_name : string;
                                equipment_eid : EntityId;
                                hero_eid : EntityId;
                                drop_prev_to_cont_eid : EntityId = INVALID_ENTITY_ID)
  query(equipment_eid) <| $ [es] (var equipment_mods__curModInSlots : Object&)
    let oldEquipmentModEid = get_Eid(equipment_mods__curModInSlots[slot_name]) ?? INVALID_ENTITY_ID
    if oldEquipmentModEid == equipment_mod_eid
      return

    // swap
    if equipment_mod_eid |> has("equipmentMod")
      var oldSlot = ""
      var oldEquipmentEid = INVALID_ENTITY_ID
      query(equipment_mod_eid) <| $ [es] (var slot_attach__attachedTo : EntityId&;
                                          var equipmentAttachable__slotName : das_string&)
        oldSlot := equipmentAttachable__slotName
        oldEquipmentEid = slot_attach__attachedTo
        equipmentAttachable__slotName := slot_name
        slot_attach__attachedTo = equipment_eid
      query(oldEquipmentModEid) <| $ [es] (var slot_attach__attachedTo : EntityId&;
                                           var equipmentAttachable__slotName : das_string&)
        equipmentAttachable__slotName := oldSlot
        slot_attach__attachedTo = oldEquipmentEid

      equipment_mods__curModInSlots |> set(slot_name, equipment_mod_eid)
      query(oldEquipmentEid) <| $ [es] (var equipment_mods__curModInSlots : Object&)
        equipment_mods__curModInSlots |> set(oldSlot, oldEquipmentModEid)

      send_net_event(hero_eid, EventOnEquipmentModSwap(
        firstSlotName = oldSlot, secondSlotName = slot_name,
        firstEquipmentModEid = oldEquipmentModEid, secondEquipmentModEid = equipment_mod_eid,
        firstEquipmentEid = oldEquipmentEid, secondEquipmentEid = equipment_eid))
      return

    query(equipment_mod_eid) <| $ [es] (item__containerOwnerEid : EntityId;
                                        item__volume : float = 0.f;
                                        var equipmentAttachable__slotName : das_string&)
      query(item__containerOwnerEid) <| $ [es] (var human_inventory__currentVolume : int&)
        human_inventory__currentVolume -= convert_volume_to_int(item__volume)
      if !!oldEquipmentModEid
        unequip_equipment_mod_from_slot(oldEquipmentModEid, equipment_eid, hero_eid, drop_prev_to_cont_eid)

      let fromInventoryEid = item__containerOwnerEid
      remove_equipment_mod_from_ground_or_inventory(equipment_mod_eid, hero_eid)

      equipmentAttachable__slotName := slot_name
      equipment_mods__curModInSlots |> set(slot_name, equipment_mod_eid)

      send_net_event(equipment_mod_eid, EventOnEquipingAsEquipmentMod(actorEid = hero_eid, equipmentEid = equipment_eid, fromInventoryEid = fromInventoryEid, slotName = slot_name))
      send_net_event(hero_eid, EventOnEquipmentModEquippedToEquipment(equipmentModEid = equipment_mod_eid, equipmentEid = equipment_eid, slotName = slot_name))
      send_net_event(hero_eid, EventOnEquipmentModEquippedToHero(equipmentModEid = equipment_mod_eid, equipmentEid = equipment_eid))
      print("[INVENTORY] Equipment mod {get_entity_info(equipment_mod_eid)} equipped to equipment {get_entity_info(equipment_eid)} on hero {get_entity_info(hero_eid)} to slot <{slot_name}>.")
    send_net_event(hero_eid, EventOnEquipmentModChanged(oldEquipmentModEid = oldEquipmentModEid, newEquipmentModEid = equipment_mod_eid, equipmentEid = equipment_eid, slotName = slot_name))


def unequip_equipment_mod_from_slot(slot_name : string;
                                    equipment_eid : EntityId;
                                    hero_eid : EntityId;
                                    to_inventory_eid = INVALID_ENTITY_ID)
  query(equipment_eid) <| $ [es] (equipment_mods__curModInSlots : Object)
    let equipmentModEid = get_Eid(equipment_mods__curModInSlots[slot_name]) ?? INVALID_ENTITY_ID
    unequip_equipment_mod_from_slot(equipmentModEid, equipment_eid, hero_eid, to_inventory_eid)


def unequip_all_equipment_mods(equipment : EntityId; hero : EntityId; to_inventory_eid = INVALID_ENTITY_ID)
  query(equipment) <| $ [es] (equipment_mods__curModInSlots : Object&)
    var mods_to_unequip : array<EntityId>
    for mod in equipment_mods__curModInSlots
      mods_to_unequip |> push(mod.value ?? INVALID_ENTITY_ID)
    for equipmentModEid in mods_to_unequip
      unequip_equipment_mod_from_slot(equipmentModEid, equipment, hero, to_inventory_eid)


def create_mod_in_equipment(equipment_mod_template : string;
                            slot_name : string;
                            equipment_eid : EntityId;
                            hero_eid : EntityId;
                            unequip_old_equipment : bool;
                            init_block : block<(var init_obj : ComponentsInitializer) : void>)
  if unequip_old_equipment
    unequip_equipment_mod_from_slot(slot_name, equipment_eid, hero_eid)
  var equipmentModEid = INVALID_ENTITY_ID
  query(equipment_eid) <| $ [es] (@shared_comp equipment_mods__slots : Object)
    if !has(equipment_mods__slots, slot_name)
      logerr("[INVENTORY] Equipment mod '{equipment_mod_template}' cannot be created in slot '{slot_name}' - there is no such slot in '{equipment_eid}<{getEntityTemplateName(equipment_eid)}>'!")
      equipmentModEid = create_item_in_inventory_container(equipment_mod_template, hero_eid, init_block)
      return

    let itemTempl = getOrBuildTemplateByName(equipment_mod_template)
    if itemTempl == null
      logerr("[INVENTORY] Can't find template for equipment mod: <{equipment_mod_template}>")
      return

    let modItemProto = getTemplateComponent(*itemTempl, "item__proto") ?? ""
    if !is_mod_available_for_slot(modItemProto, equipment_mods__slots, slot_name)
      logerr("[INVENTORY] Equipment mod '{equipment_mod_template}' cannot be created in slot '{slot_name}' in '{equipment_eid}<{getEntityTemplateName(equipment_eid)}>' - unsuitable item")
      equipmentModEid = create_item_in_inventory_container(equipment_mod_template, hero_eid, init_block)
      return

    let modSubTemplate = getTemplateComponent(*itemTempl, "item__recreateInEquipmentModSlot") ?? ""
    let equipmentModInSlotTemplate = add_sub_template_name(equipment_mod_template, modSubTemplate)
    equipmentModEid = createEntity(equipmentModInSlotTemplate) <| $(var init)
      init |> set("slot_attach__attachedTo", equipment_eid)
      init |> set("item__containerOwnerEid", INVALID_ENTITY_ID)
      init |> set("item__humanOwnerEid", hero_eid)
      init |> set("item__lastContainerOwnerEid", INVALID_ENTITY_ID)
      init |> set("item__isOnGround", false)
      init |> set("equipmentAttachable__slotName", slot_name)
      invoke(init_block, init)

    print("[INVENTORY] Equipment mod <{equipmentModEid}> ({equipmentModInSlotTemplate}) created to equipment {get_entity_info(equipment_eid)} on hero {get_entity_info(hero_eid)} in slot <{slot_name}>.")

  return equipmentModEid


def create_mod_in_equipment(equipment_mod_template : string; slot_name : string; equipment_eid : EntityId; hero_eid : EntityId; unequip_old_equipment : bool = true)
  return create_mod_in_equipment(equipment_mod_template, slot_name, equipment_eid, hero_eid, unequip_old_equipment) <| $ [unused_argument(init)] (init) {}