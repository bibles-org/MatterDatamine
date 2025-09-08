module inventory_weapon_mod_common shared
require app
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
require game.es.inventory_item_common
require game.es.inventory_item_mod_common
require game.es.human_weap_common
require game.es.inventory_drop_common


enum ModDelayedMoveState
  NONE = -1
  WAIT
  MOVE


enum ModDelayedMoveType
  UNEQUIP
  EQUIP
  SWAP


def private unequip_weapon_mod_from_slot(weapon_mod_eid : EntityId;
                                         weapon_eid, actor_eid, wish_to_inventory_eid : EntityId;
                                         ignore_item_volume_value = 0f)
  query(weapon_mod_eid) <| $ [es] (item__volume : float;
                                   gunAttachable__slotName : string;
                                   var slot_attach__attachedTo : EntityId&;
                                   var item__recognizedByPlayers : EidList;
                                   var item__lastContainerOwnerEid : EntityId&;
                                   var item__containerOwnerEid : EntityId&;
                                   var item__humanOwnerEid : EntityId&;
                                   weapon_mod_move__fakeModEid : EntityId = INVALID_ENTITY_ID)
    var newInventoryEid = INVALID_ENTITY_ID
    var newHeroOwner = INVALID_ENTITY_ID
    let checkVolumeValue = convert_volume_to_int(max(0f, item__volume - ignore_item_volume_value))
    if ((wish_to_inventory_eid != INVALID_ENTITY_ID
        && (!!weapon_mod_move__fakeModEid || is_inventory_have_free_volume(wish_to_inventory_eid, checkVolumeValue)))
        || is_can_move_to_safepack_with_overflow(wish_to_inventory_eid, weapon_mod_eid))
      newInventoryEid = wish_to_inventory_eid
      query(newInventoryEid) <| $ [es] (var human_inventory__currentVolume : int&;
                                        inventory__humanOwnerEid : EntityId = INVALID_ENTITY_ID)
        newHeroOwner = inventory__humanOwnerEid
        // add volume only if mod doesn't have fake mod in inventory (eg. if item is unequipped immediately) to avoid adding it's volume twice
        if !weapon_mod_move__fakeModEid
          human_inventory__currentVolume += convert_volume_to_int(item__volume)
      query(item__humanOwnerEid) <| $ [es] (possessedByPlr : EntityId)
        if !has_value(item__recognizedByPlayers, possessedByPlr)
          item__recognizedByPlayers |> push(possessedByPlr)
      item__lastContainerOwnerEid = INVALID_ENTITY_ID
      item__containerOwnerEid = newInventoryEid
      item__humanOwnerEid = newHeroOwner

      slot_attach__attachedTo = INVALID_ENTITY_ID
      send_net_event(weapon_mod_eid, EventOnUnequipingToInventory(newInventoryEid = newInventoryEid, lastOwnerEid = weapon_eid))
    else
      newInventoryEid = drop_item(weapon_mod_eid, actor_eid)

    query(weapon_eid) <| $ [es] (weapon_mods__modDelayedEquipEid : EntityId = INVALID_ENTITY_ID;
                                 var gun_mods__curModInSlots : Object&)
      if weapon_mod_eid != weapon_mods__modDelayedEquipEid
        // send event only when it is actual unequip, not abort of equip process
        send_net_event(actor_eid, EventOnWeaponModUnequipped(weaponModEid = weapon_mod_eid, weaponEid = weapon_eid, toInventoryEid = newInventoryEid))
      // remove mod from slot
      if (get_Eid(gun_mods__curModInSlots[gunAttachable__slotName]) ?? INVALID_ENTITY_ID) == weapon_mod_eid
        gun_mods__curModInSlots |> erase(gunAttachable__slotName)
    print("[INVENTORY] Weapon mod {get_entity_info(weapon_mod_eid)} dropped by hero {get_entity_info(actor_eid)} to container {get_entity_info(newInventoryEid)}.")


def unequip_weapon_mod_from_slot(slot_name : string;
                                 weapon_eid, actor_eid : EntityId;
                                 wish_to_inventory_eid = INVALID_ENTITY_ID;
                                 ignore_item_volume_value = 0f)
  query(weapon_eid) <| $ [es] (gun_mods__curModInSlots : Object)
    let weaponModEid = get_Eid(gun_mods__curModInSlots[slot_name]) ?? INVALID_ENTITY_ID
    unequip_weapon_mod_from_slot(weaponModEid, weapon_eid, actor_eid, wish_to_inventory_eid, ignore_item_volume_value)


def unequip_all_weapon_mods(weapon : EntityId; actor_eid : EntityId; wish_to_inventory_eid = INVALID_ENTITY_ID)
  query(weapon) <| $ [es] (gun_mods__curModInSlots : Object)
    for mod in gun_mods__curModInSlots
      let modEid = mod.value ?? INVALID_ENTITY_ID
      if modEid == INVALID_ENTITY_ID
        continue
      unequip_weapon_mod_from_slot(modEid, weapon, actor_eid, wish_to_inventory_eid)


def private remove_weapon_mod_from_ground_or_inventory(weapon_mod_eid, hero_eid : EntityId)
  query(weapon_mod_eid) <| $ [es] (var item__containerOwnerEid, item__humanOwnerEid, item__lastContainerOwnerEid : EntityId&;
                                   var item__isOnGround : bool?)
    if item__isOnGround != null && *item__isOnGround
      *item__isOnGround = false
      item__lastContainerOwnerEid = INVALID_ENTITY_ID
    else
      item__lastContainerOwnerEid = item__containerOwnerEid
    item__containerOwnerEid = INVALID_ENTITY_ID
    item__humanOwnerEid = hero_eid


def equip_weapon_mod_to_slot(weapon_mod_eid : EntityId;
                             slot_name : string;
                             weapon_eid : EntityId;
                             actor_eid : EntityId;
                             drop_prev_to_cont_eid : EntityId = INVALID_ENTITY_ID)
  var oldWeaponModEid = INVALID_ENTITY_ID
  query(weapon_eid) <| $ [es] (var gun_mods__curModInSlots : Object&; item__humanOwnerEid : EntityId)
    query(weapon_mod_eid) <| $ [es] (item__containerOwnerEid : EntityId;
                                     weapon_mod_move__inventoryEid : EntityId const?;
                                     item__volume : float = 0.f)
      oldWeaponModEid = get_Eid(gun_mods__curModInSlots[slot_name]) ?? INVALID_ENTITY_ID
      let isDelayedEquip = weapon_mod_move__inventoryEid != null
      let fromInventoryEid = isDelayedEquip ? *weapon_mod_move__inventoryEid : item__containerOwnerEid
      let ignoreVolume = (fromInventoryEid == drop_prev_to_cont_eid) ? item__volume : 0.f
      if oldWeaponModEid != weapon_mod_eid
        unequip_weapon_mod_from_slot(oldWeaponModEid, weapon_eid, actor_eid, drop_prev_to_cont_eid, ignoreVolume)

      if !isDelayedEquip || item__containerOwnerEid != INVALID_ENTITY_ID
        // if equip is delayed, than mod is already removed from inventory
        // (NOTE! this is no longer guaranteed if it ever was. so check item__containerOwnerEid),
        //no need to do it twice
        remove_weapon_mod_from_ground_or_inventory(weapon_mod_eid, item__humanOwnerEid)
      send_net_event(weapon_mod_eid, EventOnEndDelayedModMove())
      send_net_event(weapon_mod_eid, EventOnEquipingAsWeaponMod(actorEid = actor_eid, weaponEid = weapon_eid, fromInventoryEid = fromInventoryEid, isStartDelayedEquip = false))

      gun_mods__curModInSlots |> set(slot_name, weapon_mod_eid)
      send_net_event(actor_eid, EventOnWeaponModEquipped(weaponModEid = weapon_mod_eid, weaponEid = weapon_eid, slotName = slot_name))
      print("[INVENTORY] Weapon mod {get_entity_info(weapon_mod_eid)} equipped to weapon {get_entity_info(weapon_eid)} by hero {get_entity_info(actor_eid)} to slot <{slot_name}>.")
  send_net_event(actor_eid, EventOnWeaponModChanged(oldWeaponModEid = oldWeaponModEid, newWeaponModEid = weapon_mod_eid, weaponEid = weapon_eid, slotName = slot_name))


def weapon_mod_move_to_slot_and_add_delay_templ(weapon_mod_eid : EntityId;
                                                weapon_eid, actor_eid : EntityId;
                                                inventory_eid = INVALID_ENTITY_ID)
  query(weapon_eid) <| $ [es] (item__humanOwnerEid : EntityId)
    remove_weapon_mod_from_ground_or_inventory(weapon_mod_eid, item__humanOwnerEid)
  send_net_event(weapon_mod_eid, EventOnStartDelayedModMove(modParentEid = weapon_eid, inventoryEid = inventory_eid))
  send_net_event(weapon_mod_eid, EventOnEquipingAsWeaponMod(actorEid = actor_eid, weaponEid = weapon_eid, fromInventoryEid = inventory_eid, isStartDelayedEquip = true))


def private start_unequip_weapon_mod_from_slot(slot_name : string;
                                               weapon_eid, actor_eid : EntityId;
                                               to_inventory_eid : EntityId;
                                               need_pause : bool;
                                               ignore_item_volume_value = 0f)
  var unequipTime = -1.f
  query(weapon_eid) <| $ [es] (var weapon_mods__delayedMoveState : int&;
                               var weapon_mods__delayedMoveType : int&;
                               gun_mods__curModInSlots : Object;
                               var weapon_mods__modDelayedUnequipEid : EntityId&;
                               var weapon_mods__delayedMoveStartTime : float&;
                               var weapon_mods__delayedMoveFinishTime : float&;
                               var weapon_mods__delayedMoveSlotName : das_string&)
    let weaponModEid = get_Eid(gun_mods__curModInSlots[slot_name]) ?? INVALID_ENTITY_ID

    if weapon_mods__delayedMoveState != int(ModDelayedMoveState.NONE)
      return

    query(weaponModEid) <| $ [es] (weapon_mod__delayedUnequipTime : float = 0.f)
      unequipTime = max(weapon_mod__delayedUnequipTime, 0.f)
      if unequipTime > 0.f || need_pause
        weapon_mods__delayedMoveState = need_pause ? int(ModDelayedMoveState.WAIT) : int(ModDelayedMoveState.MOVE)
        weapon_mods__delayedMoveType = int(ModDelayedMoveType.UNEQUIP)
        weapon_mods__modDelayedUnequipEid = weaponModEid
        if !need_pause
          weapon_mods__delayedMoveStartTime = get_sync_time()
          weapon_mods__delayedMoveFinishTime = weapon_mods__delayedMoveStartTime + unequipTime
        weapon_mods__delayedMoveSlotName := slot_name
        send_net_event(weaponModEid, EventOnStartDelayedModMove(modParentEid = weapon_eid, inventoryEid = to_inventory_eid))
        print("[INVENTORY] Weapon mod {get_entity_info(weaponModEid)} will be unequipped from weapon {get_entity_info(weapon_eid)} in {unequipTime} sec.")
      else
        unequip_weapon_mod_from_slot(weaponModEid, weapon_eid, actor_eid, to_inventory_eid, ignore_item_volume_value)
  return unequipTime


def start_unequip_weapon_mod_from_slot(slot_name : string;
                                       weapon_eid, actor_eid : EntityId;
                                       to_inventory_eid = INVALID_ENTITY_ID;
                                       ignore_item_volume_value = 0f)
  var instantReload = false
  query(actor_eid) <| $ [es] (human_inventory__instantReload : bool)
    instantReload = human_inventory__instantReload
  if instantReload
    unequip_weapon_mod_from_slot(slot_name, weapon_eid, actor_eid, to_inventory_eid, ignore_item_volume_value)
  else
    let needPause = set_current_hero_weapon(weapon_eid, actor_eid)
    start_unequip_weapon_mod_from_slot(slot_name, weapon_eid, actor_eid, to_inventory_eid, needPause, ignore_item_volume_value)


def private start_equip_weapon_mod_to_slot(weapon_mod_eid : EntityId;
                                           slot_name : string;
                                           weapon_eid, actor_eid : EntityId;
                                           drop_prev_to_cont_eid : EntityId;
                                           need_pause : bool)
  query(weapon_eid) <| $ [es] (gun_mods__curModInSlots : Object;
                               var weapon_mods__delayedMoveState : int&;
                               var weapon_mods__delayedMoveType : int&;
                               var weapon_mods__modDelayedEquipEid : EntityId&;
                               var weapon_mods__delayedMoveStartTime : float&;
                               var weapon_mods__delayedMoveFinishTime : float&;
                               var weapon_mods__delayedMoveSlotName : das_string&)
    if weapon_mods__delayedMoveState != int(ModDelayedMoveState.NONE)
      return

    query(weapon_mod_eid) <| $ [es] (item__volume : float = 0.f;
                                     weapon_mod__delayedEquipTime : float = 0.f;
                                     item__containerOwnerEid : EntityId = INVALID_ENTITY_ID)
      let ignoreVolume = (item__containerOwnerEid == drop_prev_to_cont_eid) ? item__volume : 0.f
      let oldWeaponModEid = get_Eid(gun_mods__curModInSlots[slot_name]) ?? INVALID_ENTITY_ID
      var unequipTime = -1.f
      if oldWeaponModEid != INVALID_ENTITY_ID
        unequipTime = start_unequip_weapon_mod_from_slot(slot_name, weapon_eid, actor_eid, drop_prev_to_cont_eid, need_pause, ignoreVolume)
        if unequipTime < 0.f
          return

      let equipTime = max(weapon_mod__delayedEquipTime, 0.f)
      if unequipTime > 0.f || equipTime > 0.f || need_pause
        weapon_mods__delayedMoveState = need_pause ? int(ModDelayedMoveState.WAIT) : int(ModDelayedMoveState.MOVE)
        weapon_mods__delayedMoveSlotName := slot_name
        if unequipTime > 0.f || (unequipTime != -1.f && need_pause)
          // schedule equip mod (equip will automatically start after previous mod is unequipped)
          weapon_mods__delayedMoveType = int(ModDelayedMoveType.SWAP)
          weapon_mods__modDelayedEquipEid = weapon_mod_eid
          send_net_event(weapon_mod_eid, EventOnStartDelayedModMove(modParentEid = weapon_eid, inventoryEid = item__containerOwnerEid))
          print("[INVENTORY] Weapon mod {get_entity_info(weapon_mod_eid)} will be equipped to weapon {get_entity_info(weapon_eid)} in ({unequipTime} + {equipTime}) sec.")
        else
          weapon_mods__delayedMoveType = int(ModDelayedMoveType.EQUIP)
          weapon_mods__modDelayedEquipEid = weapon_mod_eid
          if !need_pause
            weapon_mods__delayedMoveStartTime = get_sync_time()
            weapon_mods__delayedMoveFinishTime = weapon_mods__delayedMoveStartTime + equipTime
          weapon_mod_move_to_slot_and_add_delay_templ(weapon_mod_eid, weapon_eid, actor_eid, item__containerOwnerEid)
          print("[INVENTORY] Weapon mod {get_entity_info(weapon_mod_eid)} will be equipped to weapon {get_entity_info(weapon_eid)} in ({equipTime}) sec.")
      else
        weapon_mods__delayedMoveState = int(ModDelayedMoveState.NONE)
        equip_weapon_mod_to_slot(weapon_mod_eid, slot_name, weapon_eid, actor_eid, drop_prev_to_cont_eid)


def start_equip_weapon_mod_to_slot(weapon_mod_eid : EntityId;
                                   slot_name : string;
                                   weapon_eid, actor_eid : EntityId;
                                   drop_prev_to_cont_eid = INVALID_ENTITY_ID)
  var instantReload = false
  query(actor_eid) <| $ [es] (human_inventory__instantReload : bool)
    instantReload = human_inventory__instantReload
  if instantReload
    equip_weapon_mod_to_slot(weapon_mod_eid, slot_name, weapon_eid, actor_eid, drop_prev_to_cont_eid)
  else
    let needPause = set_current_hero_weapon(weapon_eid, actor_eid)
    start_equip_weapon_mod_to_slot(weapon_mod_eid, slot_name, weapon_eid, actor_eid, drop_prev_to_cont_eid, needPause)
    sendEvent(actor_eid, CmdWeaponModEquipStarted(weaponEid = weapon_eid, weaponModEid = weapon_mod_eid, slotName = slot_name))


def abort_delayed_move_weapon_mod(weapon_eid, actor_eid : EntityId)
  query(weapon_eid) <| $ [es] (gun__owner : EntityId; weapon_mods__delayedMoveType : int;
                               var weapon_mods__delayedMoveState : int&;
                               var weapon_mods__modDelayedUnequipEid : EntityId&;
                               var weapon_mods__modDelayedEquipEid : EntityId&;
                               var weapon_mods__delayedMoveFinishTime : float&;
                               var weapon_mods__delayedMoveSlotName : das_string&)
    if weapon_mods__delayedMoveState == int(ModDelayedMoveState.NONE)
      return

    let unequipModEid = weapon_mods__modDelayedUnequipEid
    let equipModEid = weapon_mods__modDelayedEquipEid

    let curModEid = get_current_move_mod_for_weapon(weapon_eid)

    var curModInventory = INVALID_ENTITY_ID
    query(curModEid) <| $ [es] (weapon_mod_move__inventoryEid : EntityId)
      curModInventory = weapon_mod_move__inventoryEid
    let toInventoryEid = (curModInventory == gun__owner && weapon_mods__delayedMoveType != int(ModDelayedMoveType.SWAP) ?
                          curModInventory : get_inventory_for_item_by_volume(gun__owner, curModEid))

    if curModEid == unequipModEid
      if weapon_mods__delayedMoveState == int(ModDelayedMoveState.WAIT)
        send_net_event(curModEid, EventOnEndDelayedModMove())
      else
        unequip_weapon_mod_from_slot(string(weapon_mods__delayedMoveSlotName), weapon_eid, actor_eid, toInventoryEid)
      if !!equipModEid
        send_net_event(equipModEid, EventOnEndDelayedModMove())
    elif !!curModEid
      if weapon_mods__delayedMoveState == int(ModDelayedMoveState.WAIT)
        unequip_weapon_mod_from_slot(curModEid, weapon_eid, actor_eid, curModInventory)
      else
        unequip_weapon_mod_from_slot(curModEid, weapon_eid, actor_eid, toInventoryEid)

    weapon_mods__delayedMoveState = int(ModDelayedMoveState.NONE)
    weapon_mods__modDelayedUnequipEid = INVALID_ENTITY_ID
    weapon_mods__modDelayedEquipEid = INVALID_ENTITY_ID
    weapon_mods__delayedMoveFinishTime = -1.f
    weapon_mods__delayedMoveSlotName := ""


def abort_scheduled_delayed_equip_weapon_mod(weapon_eid, actor_eid : EntityId)
  query(weapon_eid) <| $ [es] (gun__owner : EntityId;
                               var weapon_mods__delayedMoveState : int&;
                               var weapon_mods__modDelayedEquipEid : EntityId&;
                               var weapon_mods__delayedMoveType : int&;
                               var weapon_mods__delayedMoveFinishTime : float&;
                               var weapon_mods__delayedMoveSlotName : das_string&)
    let curModEid = get_current_move_mod_for_weapon(weapon_eid)
    if curModEid == weapon_mods__modDelayedEquipEid && weapon_mods__delayedMoveState == int(ModDelayedMoveState.MOVE)
      return
    if curModEid != weapon_mods__modDelayedEquipEid
      send_net_event(weapon_mods__modDelayedEquipEid, EventOnEndDelayedModMove())
      weapon_mods__delayedMoveType = int(ModDelayedMoveType.UNEQUIP)
    else
      var curModInventory = INVALID_ENTITY_ID
      query(curModEid) <| $ [es] (weapon_mod_move__inventoryEid : EntityId)
        curModInventory = weapon_mod_move__inventoryEid
      if weapon_mods__delayedMoveState == int(ModDelayedMoveState.WAIT)
        unequip_weapon_mod_from_slot(curModEid, weapon_eid, actor_eid, curModInventory)
      elif weapon_mods__delayedMoveState == int(ModDelayedMoveState.MOVE)
        let toInventoryEid = (curModInventory == gun__owner && weapon_mods__delayedMoveType != int(ModDelayedMoveType.SWAP) ?
                              curModInventory : get_inventory_for_item_by_volume(gun__owner, curModEid))
        unequip_weapon_mod_from_slot(curModEid, weapon_eid, actor_eid, toInventoryEid)
      weapon_mods__delayedMoveState = int(ModDelayedMoveState.NONE)
      weapon_mods__delayedMoveFinishTime = -1.f
      weapon_mods__delayedMoveSlotName := ""
    weapon_mods__modDelayedEquipEid = INVALID_ENTITY_ID


def immediately_finish_delayed_move_weapon_mod(weapon_eid, actor_eid : EntityId)
  query(weapon_eid) <| $ [es] (var weapon_mods__delayedMoveState : int&;
                               var weapon_mods__modDelayedUnequipEid : EntityId&;
                               var weapon_mods__modDelayedEquipEid : EntityId&;
                               var weapon_mods__delayedMoveFinishTime : float&;
                               var weapon_mods__delayedMoveSlotName : das_string&)
    let unequipModEid = weapon_mods__modDelayedUnequipEid
    let equipModEid = weapon_mods__modDelayedEquipEid

    query(unequipModEid) <| $ [es] (weapon_mod_move__inventoryEid : EntityId = INVALID_ENTITY_ID)
      unequip_weapon_mod_from_slot(string(weapon_mods__delayedMoveSlotName), weapon_eid, actor_eid, weapon_mod_move__inventoryEid)
    query(equipModEid) <| $ [es] (weapon_mod_move__inventoryEid : EntityId = INVALID_ENTITY_ID)
      equip_weapon_mod_to_slot(equipModEid, string(weapon_mods__delayedMoveSlotName), weapon_eid, actor_eid, weapon_mod_move__inventoryEid)

    weapon_mods__delayedMoveState = int(ModDelayedMoveState.NONE)
    weapon_mods__modDelayedUnequipEid = INVALID_ENTITY_ID
    weapon_mods__modDelayedEquipEid = INVALID_ENTITY_ID
    weapon_mods__delayedMoveFinishTime = -1.f
    weapon_mods__delayedMoveSlotName := ""


def create_mod_in_weapon(weapon_mod_template : string; slot_name : string; weapon_eid : EntityId; hero_eid : EntityId;
                         init_block : block<(var init_obj : ComponentsInitializer) : void>)
  unequip_weapon_mod_from_slot(slot_name, weapon_eid, hero_eid)
  var weaponModEid = INVALID_ENTITY_ID
  query(weapon_eid) <| $ [es] (@shared_comp gun_mods__slots : Object)
    if !has(gun_mods__slots, slot_name)
      logerr("[INVENTORY] Weapon mod '{weapon_mod_template}' cannot be created in slot '{slot_name}' - there is no such slot in '{weapon_eid}<{getEntityTemplateName(weapon_eid)}>'!")
      weaponModEid = create_item_in_inventory_container(weapon_mod_template, hero_eid, init_block)
      return

    let itemTempl = getOrBuildTemplateByName(weapon_mod_template)
    if itemTempl == null
      logerr("[INVENTORY] Can't find template for weapon mod: <{weapon_mod_template}>")
      return

    let modItemProto = getTemplateComponent(*itemTempl, "item__proto") ?? ""
    if !is_mod_available_for_slot(modItemProto, gun_mods__slots, slot_name)
      logerr("[INVENTORY] Weapon mod '{weapon_mod_template}' cannot be created in slot '{slot_name}' in '{weapon_eid}<{getEntityTemplateName(weapon_eid)}>' - unsuitable item")
      weaponModEid = create_item_in_inventory_container(weapon_mod_template, hero_eid, init_block)
      return

    let modSubTemplate = getTemplateComponent(*itemTempl, "item__recreateInGunModSlot") ?? ""
    let weaponModInSlotTemplate = add_sub_template_name(weapon_mod_template, modSubTemplate)
    weaponModEid = createEntity(weaponModInSlotTemplate) <| $(var init)
      init |> set("slot_attach__attachedTo", weapon_eid)
      init |> set("item__containerOwnerEid", INVALID_ENTITY_ID)
      init |> set("item__humanOwnerEid", hero_eid)
      init |> set("item__lastContainerOwnerEid", INVALID_ENTITY_ID)
      init |> set("item__isOnGround", false)
      invoke(init_block, init)

    print("[INVENTORY] Weapon mod <{weaponModEid}> ({weaponModInSlotTemplate}) created to weapon {get_entity_info(weapon_eid)} on hero {get_entity_info(hero_eid)} in slot <{slot_name}>.")

  return weaponModEid


def create_mod_in_weapon(weapon_mod_template : string; slot_name : string; weapon_eid : EntityId; hero_eid : EntityId)
  return create_mod_in_weapon(weapon_mod_template, slot_name, weapon_eid, hero_eid) <| $ [unused_argument(init)] (init) {}


def get_gun_available_magazines(@shared_comp gun_mods__slots : Object;
                                cb : block<(magazines : StringList) : void>)
  return get_item_slot_available_mods(gun_mods__slots, "magazine", cb)


def interrupt_magazine_ammo_guns_reload(actor_eid : EntityId)
  query(actor_eid) <| $ [es] (human_weap__gunEids : EidList)
    for weaponEid in human_weap__gunEids
      query(weaponEid) <| $ [es] (weapon_mods__delayedMoveState : int)
        if weapon_mods__delayedMoveState != int(ModDelayedMoveState.NONE)
          sendEvent(actor_eid, CmdAbortMoveWeaponMods(weaponEid = weaponEid))