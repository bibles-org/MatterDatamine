require ecs
require ecs.common
require game.es.inventory_weapon_common
require game.events.inventory_events
require game.events.events_game
require game.es.ecs_common
require DagorSystem


def set_salt_and_attach_gun(gun_eid, hero_eid : EntityId; slot_id : int)
  query(hero_eid) <| $ [es] (human_weap__currentGunSlot : int)
    send_event_if_possible(gun_eid, CmdWeapAttach(toEid = hero_eid, isAttached = slot_id == human_weap__currentGunSlot, slotId = slot_id))


[es(on_appear)]
def set_weapon_slots_on_appear(evt : Event;
                               eid, item__humanOwnerEid : EntityId;
                               slot_attach__weaponSlotIdx : int)
  if slot_attach__weaponSlotIdx == -1
    return

  var updated = false
  query(item__humanOwnerEid) <| $ [es] (var human_weap__gunEids : EidList&)
    updated = true
    for gunIdx in iter_range(human_weap__gunEids)
      if human_weap__gunEids[gunIdx] == eid && gunIdx != slot_attach__weaponSlotIdx
        human_weap__gunEids[gunIdx] = INVALID_ENTITY_ID
      elif gunIdx == slot_attach__weaponSlotIdx
        human_weap__gunEids[gunIdx] = eid
        set_salt_and_attach_gun(eid, item__humanOwnerEid, slot_attach__weaponSlotIdx)
  if !updated
    addSubTemplate(eid, "weapon_waiting_for_hero_appear") <| $(var init)
      init |> set("weapon_waiting_for_hero_appear", item__humanOwnerEid)
      init |> set("weapon_waiting_for_hero_appear_slot", slot_attach__weaponSlotIdx)
  else
    removeSubTemplate(eid, "weapon_waiting_for_hero_appear")


[es(tag=netClient)]
def set_weapon_slots_on_equip(evt : EventOnWeaponEquipped;
                              eid : EntityId;
                              var human_weap__gunEids : EidList&)
  for gunIdx in iter_range(human_weap__gunEids)
    if human_weap__gunEids[gunIdx] == evt.weaponEid && gunIdx != evt.slotId
      human_weap__gunEids[gunIdx] = INVALID_ENTITY_ID
    elif gunIdx == evt.slotId
      human_weap__gunEids[gunIdx] = evt.weaponEid
      set_salt_and_attach_gun(evt.weaponEid, eid, evt.slotId)

  remove_sub_template_if_possible(evt.weaponEid, "weapon_waiting_for_hero_appear")


[es(tag=netClient)]
def set_weapon_slots_on_swap(evt : EventOnWeaponSwap;
                             eid : EntityId;
                             var human_weap__gunEids : EidList&)
  // first
  for gunIdx in iter_range(human_weap__gunEids)
    if human_weap__gunEids[gunIdx] == evt.firstWeaponEid && gunIdx != evt.firstSlotId
      human_weap__gunEids[gunIdx] = INVALID_ENTITY_ID
    elif gunIdx == evt.firstSlotId
      human_weap__gunEids[gunIdx] = evt.firstWeaponEid
      set_salt_and_attach_gun(evt.firstWeaponEid, eid, evt.firstSlotId)
  remove_sub_template_if_possible(evt.firstWeaponEid, "weapon_waiting_for_hero_appear")

  // second
  for gunIdx in iter_range(human_weap__gunEids)
    if human_weap__gunEids[gunIdx] == evt.secondWeaponEid && gunIdx != evt.secondSlotId
      human_weap__gunEids[gunIdx] = INVALID_ENTITY_ID
    elif gunIdx == evt.secondSlotId
      human_weap__gunEids[gunIdx] = evt.secondWeaponEid
      set_salt_and_attach_gun(evt.secondWeaponEid, eid, evt.secondSlotId)
  remove_sub_template_if_possible(evt.secondWeaponEid, "weapon_waiting_for_hero_appear")


[es(on_appear)]
def try_set_slot_on_waiting_appear(evt : Event; eid, weapon_waiting_for_hero_appear : EntityId; weapon_waiting_for_hero_appear_slot : int)
  query(weapon_waiting_for_hero_appear) <| $ [es] (var human_weap__gunEids : EidList&)
    if weapon_waiting_for_hero_appear_slot != -1
      human_weap__gunEids[weapon_waiting_for_hero_appear_slot] = eid
      set_salt_and_attach_gun(eid, weapon_waiting_for_hero_appear, weapon_waiting_for_hero_appear_slot)
    remove_sub_template_if_possible(eid, "weapon_waiting_for_hero_appear")


[es(on_appear)]
def set_slots_on_hero_appear(evt : Event; eid aka hero_eid : EntityId; var human_weap__gunEids : EidList&)
  query() <| $ [es] (eid aka weapon_eid, weapon_waiting_for_hero_appear : EntityId; weapon_waiting_for_hero_appear_slot : int)
    if hero_eid == weapon_waiting_for_hero_appear
      if weapon_waiting_for_hero_appear_slot != -1
        human_weap__gunEids[weapon_waiting_for_hero_appear_slot] = weapon_eid
        set_salt_and_attach_gun(weapon_eid, hero_eid, weapon_waiting_for_hero_appear_slot)
      remove_sub_template_if_possible(weapon_eid, "weapon_waiting_for_hero_appear")


[es(tag=netClient)]
def reset_slot_on_weapon_unequip(evt : EventOnWeaponUnequipped;
                                 var human_weap__gunEids : EidList&)
  remove_sub_template_if_possible(evt.weaponEid, "weapon_waiting_for_hero_appear")

  for gunIdx in iter_range(human_weap__gunEids)
    if human_weap__gunEids[gunIdx] == evt.weaponEid
      human_weap__gunEids[gunIdx] = INVALID_ENTITY_ID


[es(on_disappear)]
def reset_slot_on_weapon_disappear(evt : Event; eid, item__humanOwnerEid : EntityId; slot_attach__weaponSlotIdx : int)
  remove_sub_template_if_possible(eid, "weapon_waiting_for_hero_appear")
  query(item__humanOwnerEid) <| $ [es] (var human_weap__gunEids : EidList&)
    if slot_attach__weaponSlotIdx != -1 && human_weap__gunEids[slot_attach__weaponSlotIdx] == eid
      human_weap__gunEids[slot_attach__weaponSlotIdx] = INVALID_ENTITY_ID
