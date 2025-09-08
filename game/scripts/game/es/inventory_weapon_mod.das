require app
require ecs
require ecs.safe
require AnimV20
require DngNet
require DngHuman
require ecs.common
require DagorSystem
require game.es.ecs_common
require game.events.inventory_events
require game.es.inventory_checks_common
require game.es.inventory_weapon_mod_common
require game.events.events_active_matter


[es(tag=gameClient, REQUIRE=weapon_mods__delayedMoveFinishTime, track=weapon_mods__delayedMoveFinishTime)]
def init_weapon_mod_delayed_move(evt : Event;
                                 var weapon_mods__delayedMoveStartTime : float&)
  weapon_mods__delayedMoveStartTime = get_sync_time()


[es(tag=server, track=human_net_phys__weapEquipCurSlot)]
def unpause_move_weapon_mod_on_set_weapon_in_hands(ecs : Event;
                                                   human_weap__gunEids : EidList;
                                                   human_net_phys__weapEquipCurSlot : int)
  query(human_weap__gunEids[human_net_phys__weapEquipCurSlot]) <| $ [es] (weapon_mods__modDelayedUnequipEid : EntityId;
                                                                          weapon_mods__modDelayedEquipEid : EntityId;
                                                                          var weapon_mods__delayedMoveState : int&;
                                                                          var weapon_mods__delayedMoveStartTime : float&;
                                                                          var weapon_mods__delayedMoveFinishTime : float&)
    if weapon_mods__delayedMoveState != int(ModDelayedMoveState.WAIT)
      return

    weapon_mods__delayedMoveState = int(ModDelayedMoveState.MOVE)
    weapon_mods__delayedMoveStartTime = get_sync_time()
    if weapon_mods__modDelayedUnequipEid != INVALID_ENTITY_ID
      query(weapon_mods__modDelayedUnequipEid) <| $ [es] (weapon_mod__delayedUnequipTime : float = 0.f)
        weapon_mods__delayedMoveFinishTime = weapon_mods__delayedMoveStartTime + weapon_mod__delayedUnequipTime
    else
      query(weapon_mods__modDelayedEquipEid) <| $ [es] (weapon_mod__delayedEquipTime : float = 0.f)
        weapon_mods__delayedMoveFinishTime = weapon_mods__delayedMoveStartTime + weapon_mod__delayedEquipTime


[es(tag=server, no_order)]
def finish_unequip_weapon_mod_from_slot(info : ParallelUpdateFrameDelayed;
                                        eid : EntityId;
                                        gun__owner : EntityId;
                                        weapon_mods__modDelayedEquipEid : EntityId;
                                        weapon_mods__delayedMoveType : int;
                                        var weapon_mods__delayedMoveState : int&;
                                        var weapon_mods__modDelayedUnequipEid : EntityId&;
                                        var weapon_mods__delayedMoveStartTime : float&;
                                        var weapon_mods__delayedMoveFinishTime : float&;
                                        var weapon_mods__delayedMoveSlotName : das_string&)
  if weapon_mods__delayedMoveState != int(ModDelayedMoveState.MOVE)
    return

  if weapon_mods__modDelayedUnequipEid != INVALID_ENTITY_ID && weapon_mods__delayedMoveFinishTime <= info.curTime
    if (!(weapon_mods__delayedMoveType == int(ModDelayedMoveType.UNEQUIP) && weapon_mods__modDelayedEquipEid == INVALID_ENTITY_ID) &&
        !(weapon_mods__delayedMoveType == int(ModDelayedMoveType.SWAP) && weapon_mods__modDelayedEquipEid != INVALID_ENTITY_ID))
      logerr("[INVENTORY] Failed to finish unequip mod {get_entity_info(weapon_mods__modDelayedUnequipEid)} from weapon <{eid}>. Inconsistent move type <{weapon_mods__delayedMoveType}>, scheduled equip mod {get_entity_info(weapon_mods__modDelayedEquipEid)}")
      return

    query(weapon_mods__modDelayedUnequipEid) <| $ [es] (weapon_mod_move__inventoryEid aka unequip_weapon_mod_move__inventoryEid : EntityId = INVALID_ENTITY_ID)
      let equipInventoryEid = (get_Eid(weapon_mods__modDelayedEquipEid, "weapon_mod_move__inventoryEid") ?? INVALID_ENTITY_ID)
      let ignoreVolume = (equipInventoryEid == unequip_weapon_mod_move__inventoryEid) ? (get_float(weapon_mods__modDelayedEquipEid, "item__volume") ?? 0.f) : 0.f
      unequip_weapon_mod_from_slot(string(weapon_mods__delayedMoveSlotName), eid, gun__owner, unequip_weapon_mod_move__inventoryEid, ignoreVolume)
      weapon_mods__modDelayedUnequipEid = INVALID_ENTITY_ID

      // start equip pending weapon mod
      if weapon_mods__delayedMoveType == int(ModDelayedMoveType.SWAP)
        query(weapon_mods__modDelayedEquipEid) <| $ [es] (weapon_mod_move__inventoryEid aka equip_weapon_mod_move__inventoryEid : EntityId = INVALID_ENTITY_ID;
                                                          weapon_mod__delayedEquipTime : float = 0.f)
          let equipTime = max(weapon_mod__delayedEquipTime, 0.f)
          weapon_mods__delayedMoveStartTime = info.curTime
          weapon_mods__delayedMoveFinishTime = weapon_mods__delayedMoveStartTime + equipTime
          if equipTime > 0.f
            weapon_mod_move_to_slot_and_add_delay_templ(weapon_mods__modDelayedEquipEid, eid, gun__owner, equip_weapon_mod_move__inventoryEid)
      else
        weapon_mods__delayedMoveState = int(ModDelayedMoveState.NONE)
        weapon_mods__delayedMoveSlotName := ""


[es(tag=server, after=finish_unequip_weapon_mod_from_slot)]
def finish_equip_weapon_mod_to_slot(info : ParallelUpdateFrameDelayed;
                                    eid : EntityId;
                                    gun__owner : EntityId;
                                    weapon_mods__delayedMoveFinishTime : float;
                                    weapon_mods__modDelayedUnequipEid : EntityId;
                                    weapon_mods__delayedMoveType : int;
                                    var weapon_mods__delayedMoveState : int&;
                                    var weapon_mods__modDelayedEquipEid : EntityId&;
                                    var weapon_mods__delayedMoveSlotName : das_string&)
  if weapon_mods__delayedMoveState != int(ModDelayedMoveState.MOVE)
    return

  if weapon_mods__modDelayedEquipEid != INVALID_ENTITY_ID && weapon_mods__modDelayedUnequipEid == INVALID_ENTITY_ID && weapon_mods__delayedMoveFinishTime <= info.curTime
    if (weapon_mods__delayedMoveType != int(ModDelayedMoveType.EQUIP) && weapon_mods__delayedMoveType != int(ModDelayedMoveType.SWAP))
      logerr("[INVENTORY] Failed to finish equip mod {get_entity_info(weapon_mods__modDelayedEquipEid)} from weapon <{eid}>. Inconsistent move type <{weapon_mods__delayedMoveType}>")
      return

    query(weapon_mods__modDelayedEquipEid) <| $ [es] (weapon_mod_move__inventoryEid : EntityId = INVALID_ENTITY_ID)
      equip_weapon_mod_to_slot(weapon_mods__modDelayedEquipEid, string(weapon_mods__delayedMoveSlotName), eid, gun__owner, weapon_mod_move__inventoryEid)
      weapon_mods__modDelayedEquipEid = INVALID_ENTITY_ID
      weapon_mods__delayedMoveState = int(ModDelayedMoveState.NONE)
      weapon_mods__delayedMoveSlotName := ""


[es(track=(weapon_mods__delayedMoveState))]
def toggle_weapon_state_lock_on_delayed_move_mod(evt : Event;
                                                 eid : EntityId;
                                                 weapon_mods__delayedMoveState : int)
  if weapon_mods__delayedMoveState != int(ModDelayedMoveState.NONE)
    addSubTemplate(eid, "block_item_all_actions")
  else
    removeSubTemplate(eid, "block_item_all_actions")


[es(on_appear, track=item__lastContainerOwnerEid,
    REQUIRE=(weapon_mod_move__fakeModEid, slot_attach__attachedTo, item__lastContainerOwnerEid))]
def create_fake_mod_in_inventory_on_start_move_mod(ecs : Event;
                                                   eid : EntityId;
                                                   item__volume : float;
                                                   var weapon_mod_move__fakeModEid : EntityId&;
                                                   item__humanOwnerEid : EntityId;
                                                   weapon_mod_move__weaponEid : EntityId;
                                                   weapon_mod_move__inventoryEid : EntityId)
  if !is_server() && !has(item__humanOwnerEid, "hero")
    return
  if !weapon_mod_move__inventoryEid || !!weapon_mod_move__fakeModEid
    return

  query(weapon_mod_move__inventoryEid) <| $ [es] (itemContainer : EidList)
    // on start unequip mod 100% is not in inventory, so it's ok to create fake mod
    // but on start equip (on subtemplates appear) mod may still be in inventory, so check if it's still in inventory
    // and create it later on track=item__lastContainerOwnerEid if it is
    // (creating fake mod while real mod is still in inventory will lead to showing both mods in UI for one frame which is ugly)
    if !has_value(itemContainer, eid)
      query(weapon_mod_move__weaponEid) <| $ [es] (weapon_mods__delayedMoveType : int)
        weapon_mod_move__fakeModEid = createEntitySync("fake_weapon_mod") <| $(var init)
          set(init, "fake_weapon_mod__realModEid", eid)
          set(init, "item__containerOwnerEid", weapon_mod_move__inventoryEid)
          set(init, "item__humanOwnerEid", item__humanOwnerEid)
          let isSwap = weapon_mods__delayedMoveType == int(ModDelayedMoveType.SWAP)
          set(init, "item__volume", isSwap ? 0.f : item__volume)


[es(on_disappear, REQUIRE=(weapon_mod_move__fakeModEid, slot_attach__attachedTo))]
def destroy_fake_mod_in_inventory_on_finish_move_mod(ecs : Event;
                                                     weapon_mod_move__fakeModEid : EntityId)
  destroyEntity(weapon_mod_move__fakeModEid)


[es(tag=server, track=human_net_phys__weapEquipNextSlot)]
def abort_delayed_move_weapon_mod_on_change_current_weapon(evt : Event;
                                                           eid : EntityId;
                                                           human_weap__gunEids : EidList;
                                                           human_net_phys__weapEquipCurSlot : int;
                                                           human_net_phys__weapEquipNextSlot : int)
  if human_net_phys__weapEquipNextSlot != human_net_phys__weapEquipCurSlot // changing weapon -> abort move mods for old weapon
    let curWeaponEid = human_weap__gunEids[human_net_phys__weapEquipCurSlot]
    query(curWeaponEid) <| $ [es] (weapon_mods__delayedMoveState : int)
      if weapon_mods__delayedMoveState == int(ModDelayedMoveState.MOVE)
        sendEvent(eid, CmdAbortMoveWeaponMods(weaponEid = curWeaponEid))
  else // was changing weapon, but switched back -> abort scheduled move mods for other weapons
    for weaponEid in human_weap__gunEids
      query(weaponEid) <| $ [es] (weapon_mods__delayedMoveState : int)
        if weapon_mods__delayedMoveState == int(ModDelayedMoveState.WAIT)
          sendEvent(eid, CmdAbortMoveWeaponMods(weaponEid = weaponEid))


[es(tag=server)]
def abort_delayed_move_weapon_mod_on_drop_weapon(evt : EventOnDropItem;
                                                 eid : EntityId)
  sendEvent(evt.actorEid, CmdAbortMoveWeaponMods(weaponEid = eid))


[es(tag=server, REQUIRE_NOT=player_on_base_components__stashEid)]
def abort_delayed_move_weapon_mods(evt : CmdAbortMoveWeaponMods;
                                   eid : EntityId)
  abort_delayed_move_weapon_mod(evt.weaponEid, eid)


[es(tag=server, REQUIRE=(player_on_base_components__stashEid))]
def immediately_finish_delayed_move_weapon_mods(evt : CmdAbortMoveWeaponMods;
                                                eid : EntityId)
  immediately_finish_delayed_move_weapon_mod(evt.weaponEid, eid)


[es(tag=server, REQUIRE_NOT=player_on_base_components__stashEid)]
def abort_delayed_move_weapon_mod_on_container_close(evt : CmdCloseExternalInventoryRequest;
                                                     eid : EntityId;
                                                     human_weap__gunEids : EidList)
  for gun in human_weap__gunEids
    query(gun) <| $ [es] (weapon_mods__modDelayedEquipEid : EntityId;
                          weapon_mods__modDelayedUnequipEid : EntityId)
      query(weapon_mods__modDelayedEquipEid) <| $ [es] (weapon_mod_move__inventoryEid : EntityId)
        if weapon_mod_move__inventoryEid == evt.inventoryEid
          abort_scheduled_delayed_equip_weapon_mod(gun, eid)
      query(weapon_mods__modDelayedUnequipEid) <| $ [es] (var weapon_mod_move__inventoryEid : EntityId&)
        if weapon_mod_move__inventoryEid == evt.inventoryEid
          weapon_mod_move__inventoryEid = INVALID_ENTITY_ID


[es(tag=server, REQUIRE=item_in_world, no_order)]
def abort_delayed_move_weapon_mod_on_mod_far(info : ParallelUpdateFrameDelayed;
                                             transform aka mod_transform : float3x4;
                                             weapon_mod_move__weaponEid : EntityId)
  query(weapon_mod_move__weaponEid) <| $ [es] (gun__owner : EntityId)
    query(gun__owner) <| $ [es] (transform aka hero_transform : float3x4;
                                 human_inventory__lookNodeId : int;
                                 animchar : AnimcharBaseComponent;
                                 human_inventory__pickupRemoveRadius : float;
                                 human_inventory__pickupRemoveHeight : float)
      if !is_item_accessible_by_distance(human_inventory__lookNodeId, animchar, hero_transform,
          human_inventory__pickupRemoveRadius, human_inventory__pickupRemoveHeight, mod_transform)
        abort_scheduled_delayed_equip_weapon_mod(weapon_mod_move__weaponEid, gun__owner)


def remove_mod_from_other_weapons(mod_eid, hero_eid, cur_weapon_eid : EntityId; slot_name : string)
  query(hero_eid) <| $ [es] (human_weap__gunEids : EidList)
    for gunEid in human_weap__gunEids
      if gunEid == cur_weapon_eid
        continue
      query(gunEid) <| $ [es] (var gun_mods__curModInSlots : Object&)
        if (get_Eid(gun_mods__curModInSlots[slot_name]) ?? INVALID_ENTITY_ID) == mod_eid
          gun_mods__curModInSlots |> erase(slot_name)


[es(on_appear)]
def add_mod_to_gun_mod_slot_on_appear(evt : Event;
                                      eid : EntityId;
                                      gunAttachable__slotName : string;
                                      item__humanOwnerEid : EntityId;
                                      slot_attach__attachedTo : EntityId)
  if slot_attach__attachedTo == INVALID_ENTITY_ID
    return

  var added = false
  query(slot_attach__attachedTo) <| $ [es] (var gun_mods__curModInSlots : Object&)
    gun_mods__curModInSlots |> set(gunAttachable__slotName, eid)
    added = true
  if !added
    addSubTemplate(eid, "weapon_mod_waiting_for_weapon_appear") <| $(var init)
      init |> set("weapon_mod_waiting_for_weapon_appear", slot_attach__attachedTo)
      init |> set("weapon_mod_waiting_for_weapon_appear_slot", gunAttachable__slotName)
  else
    removeSubTemplate(eid, "weapon_mod_waiting_for_weapon_appear")
  remove_mod_from_other_weapons(eid, item__humanOwnerEid, slot_attach__attachedTo, gunAttachable__slotName)


[es(tag=netClient)]
def add_mod_to_gun_mod_slot_on_equip(evt : EventOnWeaponModEquipped;
                                     eid : EntityId)
  var added = false
  query(evt.weaponEid) <| $ [es] (var gun_mods__curModInSlots : Object&)
    gun_mods__curModInSlots |> set(evt.slotName, evt.weaponModEid)
    added = true
  if !added
    addSubTemplate(evt.weaponModEid, "weapon_mod_waiting_for_weapon_appear") <| $(var init)
      init |> set("weapon_mod_waiting_for_weapon_appear", evt.weaponEid)
      init |> set("weapon_mod_waiting_for_weapon_appear_slot", evt.slotName)
  else
    removeSubTemplate(evt.weaponModEid, "weapon_mod_waiting_for_weapon_appear")
  remove_mod_from_other_weapons(evt.weaponModEid, eid, evt.weaponEid, evt.slotName)


[es(on_appear)]
def try_add_mod_to_gun_on_waiting_appear(evt : Event;
                                         eid, weapon_mod_waiting_for_weapon_appear : EntityId;
                                         weapon_mod_waiting_for_weapon_appear_slot : string)
  query(weapon_mod_waiting_for_weapon_appear) <| $ [es] (var gun_mods__curModInSlots : Object&)
    gun_mods__curModInSlots |> set(weapon_mod_waiting_for_weapon_appear_slot, eid)
    removeSubTemplate(eid, "weapon_mod_waiting_for_weapon_appear")


[es(on_appear)]
def add_mods_on_weapon_appear(evt : Event;
                              eid aka weapon_eid : EntityId;
                              var gun_mods__curModInSlots : Object&)
  query() <| $ [es] (eid aka mod_eid, weapon_mod_waiting_for_weapon_appear : EntityId; weapon_mod_waiting_for_weapon_appear_slot : string)
    if weapon_mod_waiting_for_weapon_appear == weapon_eid
      gun_mods__curModInSlots |> set(weapon_mod_waiting_for_weapon_appear_slot, mod_eid)
      removeSubTemplate(mod_eid, "weapon_mod_waiting_for_weapon_appear")


[es(tag=netClient, REQUIRE=eid)]
def reset_weapon_mod_on_unequip(evt : EventOnWeaponModUnequipped)
  removeSubTemplate(evt.weaponModEid, "weapon_mod_waiting_for_weapon_appear")
  query(evt.weaponModEid) <| $ [es] (gunAttachable__slotName : string)
    query(evt.weaponEid) <| $ [es] (var gun_mods__curModInSlots : Object&)
      if (get_Eid(gun_mods__curModInSlots[gunAttachable__slotName]) ?? INVALID_ENTITY_ID) == evt.weaponModEid
        gun_mods__curModInSlots |> erase(gunAttachable__slotName)


[es(on_disappear)]
def reset_weapon_mod_on_disappear(evt : Event; eid, slot_attach__attachedTo : EntityId; gunAttachable__slotName : string)
  removeSubTemplate(eid, "weapon_mod_waiting_for_weapon_appear")
  query(slot_attach__attachedTo) <| $ [es] (var gun_mods__curModInSlots : Object&)
    if (get_Eid(gun_mods__curModInSlots[gunAttachable__slotName]) ?? INVALID_ENTITY_ID) == eid
      gun_mods__curModInSlots |> erase(gunAttachable__slotName)
