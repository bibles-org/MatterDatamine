require ecs
require game.events.inventory_events
require game.events.events
require game.events.events_game
require game.es.human_weap_common
require game.es.human.human_gun_common
require game.es.grenade_thrower_common
require inventory
require DngNet
require DngHuman
require DngWeapon
require WeapHelpers


def set_wish_ammo_item_type(gun_eid : ecs::EntityId; item_id : int)
  var changed = false
  query(gun_eid) <| $ [es(REQUIRE=gun)] (var gun__wishAmmoItemType : int&)
    changed = gun__wishAmmoItemType != item_id
    gun__wishAmmoItemType = item_id
  return changed


def set_ammo_type(slot_id : int;
                  item_id : int;
                  human_weap__gunEids : EidList;
                  owner_eid : EntityId)
  if slot_id < 0 || slot_id >= length(human_weap__gunEids)
    return

  if set_wish_ammo_item_type(human_weap__gunEids[slot_id], item_id)
    request_unload_ammo_from_gun(owner_eid, slot_id)

// Why update: because we need check state human_net_phys.phys.currentState.weapEquipState.curState
// and change grenade when first animation is end(when grenade disappear)
[es(tag=server, REQUIRE=grenade_thrower, no_order)]
def update_switch_grenade_es(evt : UpdateStageInfoAct;
                             gun__owner : EntityId;
                             var grenade_thrower__wishProjectileId : int&)
  if grenade_thrower__wishProjectileId == 0
    return

  query(gun__owner) <| $ [es] (var human_net_phys : HumanActor; human_weap__gunEids : EidList)
    if human_net_phys.phys.currentState.weapEquipState.curState == HUWeaponEquipState.EES_EQUIPING
      set_ammo_type(int(HUWeaponSlots.EWS_GRENADE), grenade_thrower__wishProjectileId, human_weap__gunEids, gun__owner)
      take_grenade_in_hand(gun__owner, human_weap__gunEids, human_net_phys.phys)
      grenade_thrower__wishProjectileId = 0

def try_take_grenade_in_hand(eid aka owner_eid : ecs::EntityId;
                             slot_id : int;
                             wish_item_id : int;
                             wish_item_eid : ecs::EntityId;
                             human_weap__fastThrowExclusive : bool;
                             human_weap__throwMode : bool;
                             human_weap__gunEids : EidList;
                             var human_net_phys : HumanActor;
                             is_grenade_slot_current : bool)
  let isGrenade = (slot_id == int(HUWeaponSlots.EWS_GRENADE))
  if !isGrenade || human_weap__fastThrowExclusive || human_weap__throwMode
    return false

  let gunEid = human_weap__gunEids[slot_id]
  let wishAmmoItemType = get_int(gunEid, "gun__wishAmmoItemType") ?? INVALID_ITEM_ID
  let retakeGrenade = !is_grenade_slot_current || (wishAmmoItemType != wish_item_id)


  if is_grenade_slot_current && retakeGrenade
    query(gunEid) <| $ [es(REQUIRE=grenade_thrower)] (var grenade_thrower__wishProjectileId : int?)
      if grenade_thrower__wishProjectileId != null
        *grenade_thrower__wishProjectileId = wish_item_id
      human_net_phys.phys.currentState.weapEquipState.progress = 0f
      human_net_phys.phys.currentState.weapEquipState.curState = HUWeaponEquipState.EES_HOLSTERING
    return false

  set_wish_ammo_item_type(gunEid, wish_item_id)

  if retakeGrenade && !take_grenade_in_hand(eid, human_weap__gunEids, human_net_phys.phys, wish_item_eid)
    return false

  return true


[es(before=human_weap_post_phys_es)]
def human_weap_throw_on_equip(evt : CmdPostPhysUpdate;
                              var human_weap__throwOnEquip : bool&;
                              var human_net_phys : HumanActor)
  assume cs = human_net_phys.phys.currentState
  let equiped = cs.weapEquipState.curState == HUWeaponEquipState.EES_EQUIPED
  let isGrenade = cs.weapEquipState.effectiveCurSlot == HUWeaponSlots.EWS_GRENADE
  if isGrenade && equiped && human_weap__throwOnEquip
    assume ct = is_true_net_server() ? human_net_phys.phys.appliedCT : human_net_phys.phys.producedCT
    ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SHOOT, true)
    human_weap__throwOnEquip = false


[es]
def human_weap_grenade_quick_throw(evt : RequestQuickThrowGrenade;
                                   eid aka owner_eid : EntityId;
                                   human_weap__gunEids : EidList;
                                   human_weap__fastThrowExclusive : bool;
                                   human_weap__throwMode : bool;
                                   var human_weap__quickThrowLastWeaponSlot : int&;
                                   var human_weap__throwOnEquip : bool&;
                                   var human_net_phys : HumanActor)
  let grenadeAmmoId = evt.grenade_ammo_id

  assume phys = human_net_phys.phys
  assume weapEquipState = phys.currentState.weapEquipState
  let effectiveCurSlot = weapEquipState.effectiveCurSlot
  let isGrenadeSlotCurrent = (effectiveCurSlot == HUWeaponSlots.EWS_GRENADE)
  let slotId = int(HUWeaponSlots.EWS_GRENADE)

  if !try_take_grenade_in_hand(eid, slotId, grenadeAmmoId, evt.grenade_ammo_eid,
                               human_weap__fastThrowExclusive,
                               human_weap__throwMode,
                               human_weap__gunEids,
                               human_net_phys,
                               isGrenadeSlotCurrent)
    set_ammo_type(slotId, grenadeAmmoId, human_weap__gunEids, owner_eid)

  // queue grenade throw when it's equipped and ready to throw
  human_weap__throwOnEquip = true
  // save current weapon slow to switch to it back after grenade throw
  human_weap__quickThrowLastWeaponSlot = int(effectiveCurSlot)


[es]
def human_weap_wish_ammo_es(evt : CmdSetWishGrenadeType;
                            eid aka owner_eid : ecs::EntityId;
                            human_weap__gunEids : ecs::EidList;
                            human_weap__fastThrowExclusive : bool;
                            human_weap__throwMode : bool;
                            var human_net_phys : HumanActor)
  let slotId = evt.slot_id
  let itemId = evt.item_id
  let itemEid = evt.wish_item

  assume phys = human_net_phys.phys
  assume weapEquipState = phys.currentState.weapEquipState
  let effectiveCurSlot = weapEquipState.effectiveCurSlot
  let isGrenadeSlotCurrent = (effectiveCurSlot == HUWeaponSlots.EWS_GRENADE)

  if !is_server()
    send_net_event(eid, RequestSetWishGrenadeType(slot_id = slotId, item_id = itemId, is_grenade_slot_current = isGrenadeSlotCurrent, try_take = evt.try_take, wish_item = evt.wish_item))
    return // Do nothing, it's all should be server driven

  if (!evt.try_take && !isGrenadeSlotCurrent)
    set_wish_ammo_item_type(human_weap__gunEids[int(HUWeaponSlots.EWS_GRENADE)], itemId)
    change_grenade_in_hand(owner_eid, human_weap__gunEids)
  elif !try_take_grenade_in_hand(eid, slotId, itemId, itemEid,
                                human_weap__fastThrowExclusive,
                                human_weap__throwMode,
                                human_weap__gunEids,
                                human_net_phys,
                                isGrenadeSlotCurrent)
    set_ammo_type(slotId, itemId, human_weap__gunEids, owner_eid)


[es]
def human_weap_req_wish_ammo_es(evt : RequestSetWishGrenadeType;
                                eid aka owner_eid : ecs::EntityId;
                                human_weap__gunEids : ecs::EidList;
                                human_weap__fastThrowExclusive : bool;
                                human_weap__throwMode : bool;
                                var human_net_phys : HumanActor)
  let slotId = evt.slot_id
  let itemId = evt.item_id
  let itemEid = evt.wish_item

  assume phys = human_net_phys.phys
  assume weapEquipState = phys.currentState.weapEquipState
  let effectiveCurSlot = weapEquipState.effectiveCurSlot
  let isGrenadeSlotCurrent = (effectiveCurSlot == HUWeaponSlots.EWS_GRENADE)

  if (!evt.try_take && !isGrenadeSlotCurrent)
    set_wish_ammo_item_type(human_weap__gunEids[int(HUWeaponSlots.EWS_GRENADE)], itemId)
    change_grenade_in_hand(owner_eid, human_weap__gunEids)
  elif !try_take_grenade_in_hand(eid, slotId, itemId, itemEid,
                                human_weap__fastThrowExclusive,
                                human_weap__throwMode,
                                human_weap__gunEids,
                                human_net_phys,
                                evt.is_grenade_slot_current)
    set_ammo_type(slotId, itemId, human_weap__gunEids, owner_eid)


def review_weap_gun_wish_ammo_item_type(itemContainer : ecs::EidList;
                                        human_weap__gunEids : ecs::EidList)
  for gunEid in human_weap__gunEids
    if gunEid == INVALID_ENTITY_ID
      continue

    query(gunEid) <| $ [es(REQUIRE=gun)] (gun__ammoHolderIds : IntList&;
                                          gun__owner : EntityId;
                                          gun__shell_prop_ids : GunShellPropIds&;
                                          gun__wishAmmoItemType : int = INVALID_ITEM_ID;
                                          grenade_thrower__grenadeItemEntity : EntityId = INVALID_ENTITY_ID;
                                          grenade_thrower : GrenadeThrower const?)
      var needChange = true
      query(grenade_thrower__grenadeItemEntity) <| $ [es] (item__humanOwnerEid : EntityId)
        needChange = item__humanOwnerEid != gun__owner
      if !needChange
        return
      gather_ammo_for_gun(gun__ammoHolderIds, gun__shell_prop_ids, itemContainer) <| $(ammoItems)
        let ammoItemsCount = length(ammoItems)
        let slotIdx = ammoItems |> find_index(gun__wishAmmoItemType)
        if slotIdx == -1
          let wishAmmoItemTypeChanged = set_wish_ammo_item_type(gunEid,
                                                                (ammoItemsCount == 0)
                                                                ? INVALID_ITEM_ID
                                                                : ammoItems[0])
          if grenade_thrower != null && wishAmmoItemTypeChanged && (*grenade_thrower).state == GrenadeThrowState.GTS_READY
            change_grenade_in_hand(gun__owner, human_weap__gunEids)


[es(tag=gameClient, track=gun__wishAmmoItemType)]
def gun_thrower_changed_wish_ammo_on_client(evt : Event;
                                            gun__owner : EntityId;
                                            gun__wishAmmoItemType : int;
                                            grenade_thrower : GrenadeThrower)
  if grenade_thrower.state != GrenadeThrowState.GTS_READY || gun__wishAmmoItemType != 0
    return
  query(gun__owner)  <| $ [es] (human_weap__gunEids : EidList; var human_net_phys : HumanActor)
    let curGun = human_net_phys.phys.currentState.weapEquipState.curSlot
    if curGun != HUWeaponSlots.EWS_GRENADE
      return
    switch_to_first_weap_with_ammo(human_weap__gunEids, human_net_phys.phys)


[es(tag=server, after=gun_init_es, track=(itemContainer, human_weap__gunEids))]
def human_weap_gun_wish_ammo_item_type_es(evt : Event;
                                          itemContainer : ecs::EidList;
                                          human_weap__gunEids : ecs::EidList)
  review_weap_gun_wish_ammo_item_type(itemContainer, human_weap__gunEids)


[es(tag=server, on_appear, REQUIRE=(gun, item__needUpdateWishAmmo))]
def late_set_weap_gun_wish_ammo_es(evt : Event;
                                   gun__wishAmmoItemType : int;
                                   gun__owner : ecs::EntityId)
  if gun__owner != INVALID_ENTITY_ID && gun__wishAmmoItemType == 0
    query(gun__owner) <| $ [es(REQUIRE=human)] (itemContainer : ecs::EidList;
                                                human_weap__gunEids : ecs::EidList)
      review_weap_gun_wish_ammo_item_type(itemContainer, human_weap__gunEids)


[es(tag=server, on_appear, after=(shell_item_es, items_es), REQUIRE=(shell__gun_props_id, item__needUpdateWishAmmo))]
def late_set_ammo_as_wish_ammo_es(evt : Event;
                                  item__containerOwnerEid : ecs::EntityId)
  if item__containerOwnerEid != INVALID_ENTITY_ID
    query(item__containerOwnerEid) <| $ [es(REQUIRE=human)] (itemContainer : ecs::EidList;
                                                             human_weap__gunEids : ecs::EidList)
      review_weap_gun_wish_ammo_item_type(itemContainer, human_weap__gunEids)


[es(tag=server)]
def review_grenade_on_unequiping(evt : EventOnEquipmentModUnequippedFromHero;
                                 itemContainer : ecs::EidList;
                                 human_weap__gunEids : ecs::EidList)
  review_weap_gun_wish_ammo_item_type(itemContainer, human_weap__gunEids)


[es(track=human_weap__lockedWeaponSlot)]
def human_lock_weap_slot_es(evt : Event;
                            eid : ecs::EntityId;
                            human_weap__gunEids : ecs::EidList;
                            human_weap__lockedWeaponSlot : int;
                            var human_net_phys : HumanActor)
  human_net_phys.phys.canSwitchWeapon = (human_weap__lockedWeaponSlot < 0 ||
                                        int(human_weap__lockedWeaponSlot) >= int(HUWeaponSlots.EWS_NUM))
  if !human_net_phys.phys.canSwitchWeapon
    forcibly_lock_weap_slot(eid, human_weap__lockedWeaponSlot, human_weap__gunEids, human_net_phys)


[es]
def human_weap_req_take_grenade(evt : HumanRequestTakeGrenade;
                                eid : ecs::EntityId;
                                human_weap__gunEids : ecs::EidList;
                                var human_net_phys : HumanActor)
  assume phys = human_net_phys.phys
  assume weapEquipState = phys.currentState.weapEquipState
  let effectiveCurSlot = weapEquipState.effectiveCurSlot
  let isGrenadeSlotCurrent = (effectiveCurSlot == HUWeaponSlots.EWS_GRENADE)

  if !isGrenadeSlotCurrent
    take_grenade_in_hand(eid, human_weap__gunEids, phys)