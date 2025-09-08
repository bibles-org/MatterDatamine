require ecs
require ecs.safe
require game.events.events
require game.es.inventory_weapon_common
require game.es.inventory_checks_common


def rewrite_current_gun_mod_eids(var human_weap__currentGunModEids : EidList&;
                                 gun_mods__curModInSlots : Object;
                                 weapon_mods__modDelayedUnequipEid : EntityId;
                                 weapon_mods__modDelayedEquipEid : EntityId)
  human_weap__currentGunModEids |> clear()

  for gunMod in gun_mods__curModInSlots
    let gunModEid = get_Eid(gunMod.value) ?? INVALID_ENTITY_ID
    if gunModEid != INVALID_ENTITY_ID
      human_weap__currentGunModEids |> push(gunModEid)

  let curMoveModEid = get_current_move_mod_for_weapon(weapon_mods__modDelayedUnequipEid, weapon_mods__modDelayedEquipEid)
  if curMoveModEid != INVALID_ENTITY_ID && curMoveModEid == weapon_mods__modDelayedEquipEid
    human_weap__currentGunModEids |> push(curMoveModEid)


[es(tag=server, track=(human_weap__currentGunSlot, human_weap__gunEids))]
def human_weap_update_current_gun(evt : Event;
                                  human_weap__currentGunSlot : int;
                                  var human_weap__currentGunEid : EntityId&;
                                  var human_weap__currentGunModEids : EidList&;
                                  human_weap__gunEids : EidList)
  let slot = human_weap__currentGunSlot
  human_weap__currentGunEid = slot >= 0 ? human_weap__gunEids[slot] : ecs::INVALID_ENTITY_ID
  clear(human_weap__currentGunModEids)
  query(human_weap__currentGunEid) <| $ [es] (gun_mods__curModInSlots : Object;
                                              weapon_mods__modDelayedUnequipEid : EntityId;
                                              weapon_mods__modDelayedEquipEid : EntityId)
    rewrite_current_gun_mod_eids(human_weap__currentGunModEids, gun_mods__curModInSlots,
                                 weapon_mods__modDelayedUnequipEid, weapon_mods__modDelayedEquipEid)


[es(tag=server, track=(gun_mods__curModInSlots, weapon_mods__modDelayedUnequipEid, weapon_mods__modDelayedEquipEid))]
def human_weap_update_current_gun_mods_changes(evt : Event;
                                               eid, slot_attach__attachedTo : EntityId;
                                               gun_mods__curModInSlots : Object;
                                               weapon_mods__modDelayedUnequipEid : EntityId;
                                               weapon_mods__modDelayedEquipEid : EntityId)
  query(slot_attach__attachedTo) <| $ [es] (human_weap__currentGunEid : EntityId;
                                            var human_weap__currentGunModEids : EidList&)
    if eid == human_weap__currentGunEid
      rewrite_current_gun_mod_eids(human_weap__currentGunModEids, gun_mods__curModInSlots,
                                   weapon_mods__modDelayedUnequipEid, weapon_mods__modDelayedEquipEid)
