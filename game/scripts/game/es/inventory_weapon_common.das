module inventory_weapon_common shared
require ecs
require DngNet
require ecs.safe
require math.base
require ecs.common
require DagorSystem
require game.events.events_game
require game.es.ecs_common
require game.events.inventory_events
require game.es.inventory_checks_common
require game.es.inventory_common
require game.es.inventory_drop_common
require game.es.equipment_enums_common


def calculate_boxed_item_volume(templ_name : string; num : int)
  let templ = getTemplateByName(templ_name)
  if templ != null
    let boxedAmmorStackVolume = getTemplateComponent(*templ, "item__volumePerStack") ?? 0.0
    let boxedAmmorStackCount = float(getTemplateComponent(*templ, "item__countPerStack") ?? 1)
    return (floor(boxedAmmorStackVolume * float(num) / boxedAmmorStackCount * 10.0) / 10.0)
  return 0.0


def max_boxed_item_count_in_volume(templ_name : string; volume : float)
  let templ = getTemplateByName(templ_name)
  if templ != null
    let boxedAmmorStackVolume = getTemplateComponent(*templ, "item__volumePerStack") ?? 0.0
    let boxedAmmorStackCount = float(getTemplateComponent(*templ, "item__countPerStack") ?? 1)
    return floori(volume * boxedAmmorStackCount / boxedAmmorStackVolume)
  return 0


def calculate_boxed_item_weight(templ_name : string; num : int)
  let templ = getTemplateByName(templ_name)
  if templ != null
    let boxedAmmorStackWeight = getTemplateComponent(*templ, "item__weightPerStack") ?? 0.0
    let boxedAmmorStackCount = float(getTemplateComponent(*templ, "item__countPerStack") ?? 1)
    return (floor(boxedAmmorStackWeight * float(num) / boxedAmmorStackCount * 10.0) / 10.0)
  return 0.0


def private unequip_weapon_from_slot(weapon_eid : EntityId;
                                     slot_id : int;
                                     to_inventory_eid : EntityId;
                                     ignore_item_volume_value = 0f)
  query(weapon_eid) <| $ [es] (item__volume : float;
                               hammerspace_item : Tag const?;
                               var gun__owner, item__lastContainerOwnerEid, item__containerOwnerEid, item__humanOwnerEid, slot_attach__attachedTo : EntityId&;
                               var item__recognizedByPlayers : EidList;
                               var slot_attach__weaponSlotIdx : int&)
    slot_attach__weaponSlotIdx = -1
    query(gun__owner) <| $ [es] (var human_weap__gunEids : EidList&)
      if human_weap__gunEids[slot_id] == weapon_eid
        human_weap__gunEids[slot_id] = INVALID_ENTITY_ID
    let lastWeaponOwner = gun__owner
    var toInventoryEid = to_inventory_eid

    if hammerspace_item != null
      toInventoryEid = get_Eid(lastWeaponOwner, "hammerspace_inventory_owner__inventoryEid") ?? INVALID_ENTITY_ID

    let checkVolumeValue = convert_volume_to_int(max(0f, item__volume - ignore_item_volume_value))
    if ((toInventoryEid != INVALID_ENTITY_ID && is_inventory_have_free_volume(toInventoryEid, checkVolumeValue))
        || is_can_move_to_safepack_with_overflow(toInventoryEid, weapon_eid))
      query(item__humanOwnerEid) <| $ [es] (possessedByPlr : EntityId)
        if !has_value(item__recognizedByPlayers, possessedByPlr)
          item__recognizedByPlayers |> push(possessedByPlr)
      query(toInventoryEid) <| $ [es] (inventory__humanOwnerEid : EntityId;
                                       var human_inventory__currentVolume : int&)
        human_inventory__currentVolume += checkVolumeValue
        item__lastContainerOwnerEid = (!inventory__humanOwnerEid) ? lastWeaponOwner : INVALID_ENTITY_ID
        item__containerOwnerEid = toInventoryEid
        item__humanOwnerEid = inventory__humanOwnerEid
        gun__owner = inventory__humanOwnerEid

      slot_attach__attachedTo = INVALID_ENTITY_ID
      send_net_event(weapon_eid, EventOnUnequipingToInventory(newInventoryEid = toInventoryEid, lastOwnerEid = lastWeaponOwner))
    else
      toInventoryEid = drop_item(weapon_eid, gun__owner)

    send_net_event(lastWeaponOwner, EventOnWeaponUnequipped(weaponEid = weapon_eid, toInventoryEid = toInventoryEid, slotId = slot_id))
    print("[INVENTORY] Weapon {get_entity_info(weapon_eid)} dropped from hero {get_entity_info(lastWeaponOwner)} from slot <{slot_id}> to inventory {get_entity_info(to_inventory_eid)}.")


def equip_weapon_to_slot(weapon_eid : EntityId;
                         slot_id : int;
                         hero_eid : EntityId;
                         drop_prev_to_cont_eid : EntityId = INVALID_ENTITY_ID)
  query(hero_eid) <| $ [es] (human_weap__gunSlotFlags : IntList const?;
                             var human_weap__gunEids : EidList&)
    let slotFlags = (human_weap__gunSlotFlags != null && slot_id < length(*human_weap__gunSlotFlags)) ? (*human_weap__gunSlotFlags)[slot_id] : 0
    if weapon_eid != INVALID_ENTITY_ID && (slotFlags & int(GunSlotFlags REMOVED)) != 0
      logerr("[INVENTORY] {get_entity_info(hero_eid)}: Can't equip weapon {get_entity_info(weapon_eid)} to slot <{slot_id}> - slot is removed!")
      return

    let oldGunEid = human_weap__gunEids[slot_id]
    let newWeaponFromSlot = weapon_eid == INVALID_ENTITY_ID ? -1 : human_weap__gunEids |> find_index(weapon_eid)
    if newWeaponFromSlot != -1
      query(weapon_eid) <| $ [es] (var slot_attach__weaponSlotIdx : int&)
        slot_attach__weaponSlotIdx = slot_id
      query(oldGunEid) <| $ [es] (var slot_attach__weaponSlotIdx : int&)
        slot_attach__weaponSlotIdx = newWeaponFromSlot
      human_weap__gunEids[newWeaponFromSlot] = oldGunEid
      human_weap__gunEids[slot_id] = weapon_eid
      send_net_event(hero_eid, EventOnWeaponSwap(
        firstSlotId = newWeaponFromSlot, secondSlotId = slot_id,
        firstWeaponEid = oldGunEid, secondWeaponEid = weapon_eid))
      return
    else
      let weaponForEquipVolume = get_float(weapon_eid, "item__volume") ?? 0f
      unequip_weapon_from_slot(human_weap__gunEids[slot_id], slot_id, drop_prev_to_cont_eid, weaponForEquipVolume)

      query(weapon_eid) <| $ [es] (var item__containerOwnerEid, item__humanOwnerEid, item__lastContainerOwnerEid : EntityId&;
                                   var item__isOnGround : bool?;
                                   var slot_attach__weaponSlotIdx : int&)
        slot_attach__weaponSlotIdx = slot_id
        human_weap__gunEids[slot_id] = weapon_eid
        if item__isOnGround != null && *item__isOnGround
          *item__isOnGround = false
          item__lastContainerOwnerEid = INVALID_ENTITY_ID
        else
          item__lastContainerOwnerEid = item__containerOwnerEid
        item__containerOwnerEid = INVALID_ENTITY_ID
        item__humanOwnerEid = hero_eid

        send_net_event(weapon_eid, EventOnEquipingAsWeapon(heroEid = hero_eid, slotId = slot_id, fromInventoryEid = item__lastContainerOwnerEid))
        send_net_event(hero_eid, EventOnWeaponEquipped(weaponEid = weapon_eid, slotId = slot_id))
        print("[INVENTORY] Weapon {get_entity_info(weapon_eid)} equipped to hero {get_entity_info(hero_eid)} to slot <{slot_id}>.")
      if oldGunEid != INVALID_ENTITY_ID || weapon_eid != INVALID_ENTITY_ID
        send_net_event(hero_eid, EventOnWeaponChanged(oldWeaponEid = oldGunEid, newWeaponEid = weapon_eid, slotId = slot_id))


def unequip_weapon_from_slot(slot_id : int;
                             hero_eid : EntityId;
                             to_inventory_eid = INVALID_ENTITY_ID)
  equip_weapon_to_slot(INVALID_ENTITY_ID, slot_id, hero_eid, to_inventory_eid)


def pickup_gun(hero_eid, item_eid : EntityId; slot_id : int)

  if !is_weapon_slot_available_for_equip(hero_eid, slot_id)
    return

  query(hero_eid) <| $ [es] (human_weap__currentGunSlot : int = -1)
    var slotId = slot_id
    if slotId < 0
      var haveGun = false
      slotId = find_gunslot_to_change_weapon(hero_eid, item_eid, haveGun)
      if !haveGun
        if slotId >= 0
          equip_weapon_to_slot(item_eid, slotId, hero_eid)
          return
        // otherwise find first best
        slotId = find_best_weap_slot_id(hero_eid, item_eid, slotId, human_weap__currentGunSlot)

    if slotId >= 0
      equip_weapon_to_slot(item_eid, slotId, hero_eid)


def create_weapon_in_slot(weapon_template : string; slot_id : int; hero_eid : EntityId;
                          init_block : block<(var init_obj : ComponentsInitializer) : void>)
  unequip_weapon_from_slot(slot_id, hero_eid)
  let itemTempl = getOrBuildTemplateByName(weapon_template)
  if itemTempl == null
    logerr("[INVENTORY] Can't find template for weapon: <{weapon_template}>")
    return INVALID_ENTITY_ID
  let slotSubTemplate = getTemplateComponent(*itemTempl, "item__recreateInEquipment") ?? ""
  let weaponInSlotTemplate = add_sub_template_name(weapon_template, slotSubTemplate)
  let weaponEid = createEntity(weaponInSlotTemplate) <| $(var init)
    init |> set("slot_attach__weaponSlotIdx", slot_id)
    init |> set("gun__owner", hero_eid)
    init |> set("item__containerOwnerEid", INVALID_ENTITY_ID)
    init |> set("item__humanOwnerEid", hero_eid)
    init |> set("item__lastContainerOwnerEid", INVALID_ENTITY_ID)
    init |> set("item__isOnGround", false)
    invoke(init_block, init)

  print("[INVENTORY] Weapon <{weaponEid}> ({weaponInSlotTemplate}) created to hero {get_entity_info(hero_eid)} in slot <{slot_id}>.")
  return weaponEid


def create_weapon_in_slot(weapon_template : string; slot_id : int; hero_eid : EntityId)
  return create_weapon_in_slot(weapon_template, slot_id, hero_eid) <| $ [unused_argument(init)] (init) {}
