require ecs
require ecs.safe
require app
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require DagorSystem
require game.events.inventory_events
require game.es.human.human_reload_common
require game.es.inventory_weapon_mod_common
require DaWeaponProps
require game.es.human_weap_common
require DngHuman


[es(REQUIRE=eid)]
def attach_magazine_to_gun(evt : EventOnWeaponModEquipped)
  query(evt.weaponModEid) <| $ [es] (item_holder__boxedItemTemplate : string = "";
                                     var item__currentBoxedItemCount : int&)
    query(evt.weaponEid) <| $ [es(REQUIRE=gun)] (gun__shell_prop_ids : GunShellPropIds;
                                                 var shell_props : ShellPropIds&;
                                                 var gun__curShellId : ShellPropIds&;
                                                 var gun__boxedAmmoHolderTemplate : das_string&)
      shell_props = length(gun__shell_prop_ids) > 0 ? gun__shell_prop_ids[0] : ShellPropIds()
      gun__curShellId = shell_props
      gun__boxedAmmoHolderTemplate := item_holder__boxedItemTemplate
      let loadAmmoCount = item__currentBoxedItemCount
      item__currentBoxedItemCount = 0
      sendEventImmediate(evt.weaponEid, CmdLoadAmmo(loadAmmoCount = loadAmmoCount))


[es(on_event=EventEntityCreated)]
def attach_magazine_to_gun_on_appear(evt : Event;
                                     item_holder__boxedItemTemplate : string = "";
                                     var item__currentBoxedItemCount : int&;
                                     slot_attach__attachedTo : EntityId)
  query(slot_attach__attachedTo) <| $ [es(REQUIRE=gun)] (gun__shell_prop_ids : GunShellPropIds;
                                                         var shell_props : ShellPropIds&;
                                                         var gun__curShellId : ShellPropIds&;
                                                         var gun__boxedAmmoHolderTemplate : das_string&)
    shell_props = length(gun__shell_prop_ids) > 0 ? gun__shell_prop_ids[0] : ShellPropIds()
    gun__curShellId = shell_props
    gun__boxedAmmoHolderTemplate := item_holder__boxedItemTemplate
    let loadAmmoCount = item__currentBoxedItemCount
    item__currentBoxedItemCount = 0
    sendEventImmediate(slot_attach__attachedTo, CmdLoadAmmo(loadAmmoCount = loadAmmoCount))


[es(REQUIRE=eid)]
def detach_magazine_from_gun(evt : EventOnWeaponModUnequipped)
  query(evt.weaponModEid) <| $ [es] (item_holder__maxItemCount : int;
                                     var item__currentBoxedItemCount : int&)
    query(evt.weaponEid) <| $ [es(REQUIRE=gun)] (gun__ammo : int;
                                                 gun__boxedAmmoHolderTemplate : string = "";
                                                 gun_jamming__isJammed = false)
      let canUnloadAmmoCount = item_holder__maxItemCount
      let bulletInBarrel = gun_jamming__isJammed ? 0 : 1
      let unloadAmmoCount = (gun__boxedAmmoHolderTemplate == "" ?
                             min(gun__ammo, canUnloadAmmoCount) :
                             min(max(gun__ammo - bulletInBarrel, 0), canUnloadAmmoCount))
      item__currentBoxedItemCount = unloadAmmoCount
      sendEventImmediate(evt.weaponEid, CmdUnloadAmmo(unloadAmmoCount = unloadAmmoCount))


// There is a strong suspicion that this ES no longer works
[es(on_appear)]
def init_gun_secondary_ammo_holders(evt : Event; var gun__secondaryAmmoHolderIds : IntList; gun__ammoHolders : StringList)
  for holderName in gun__ammoHolders
    let holderTemplate = getTemplateByName(string(holderName))
    if holderTemplate != null
      let secHolderName = getTemplateComponent(*holderTemplate, "item_holder__boxedItemTemplate") ?? ""
      if secHolderName != ""
        let hash = ecs_hash(string(secHolderName))
        gun__secondaryAmmoHolderIds |> push(int(hash))


// gun__ammo is sensetive information so it is not replicated to all clients (+ saves traffic as it is changed often)
// but all clients need to know what animation to reload the gun with, so precompute and replicate if from the server
[es(tag=server, after=delayed_sync_ammo_with_server_es)]
def update_gun_reload_style(info : ParallelUpdateFrameDelayed;
                            eid : EntityId;
                            gun__ammo : int;
                            gun_anim__reloadStyle : int)
  let newGunReloadStyle = (gun__ammo > 0) ? int(GunReloadStyle.RELOAD_STYLE_ALT) : int(GunReloadStyle.RELOAD_STYLE_SIMPLE)
  if gun_anim__reloadStyle != newGunReloadStyle
    // Setting component through set to avoid unnecessary changes tracking. Most of the time this value does not change.
    set(eid, "gun_anim__reloadStyle", newGunReloadStyle)


[es(tag=server, track=weapon_mods__delayedMoveState)]
def init_magazine_delayed_move_params_on_start_move(evt : Event;
                                                    gun__owner : EntityId;
                                                    gun_anim__reloadStyle : int;
                                                    weapon_mods__delayedMoveState : int;
                                                    weapon_mods__delayedMoveType : int;
                                                    gun_reload__unequipMagazineTime : FloatList;
                                                    gun_reload__equipMagazineTime : FloatList;
                                                    gun_reload__swapUnequipMagazineTime : FloatList;
                                                    var weapon_mods__delayedMoveFinishTime : float&)
  if weapon_mods__delayedMoveState != int(ModDelayedMoveState.MOVE)
    return

  var moveDuration = 0.f
  if weapon_mods__delayedMoveType == int(ModDelayedMoveType.UNEQUIP)
    moveDuration = gun_reload__unequipMagazineTime[gun_anim__reloadStyle]
  elif weapon_mods__delayedMoveType == int(ModDelayedMoveType.EQUIP)
    moveDuration = gun_reload__equipMagazineTime[gun_anim__reloadStyle]
  elif weapon_mods__delayedMoveType == int(ModDelayedMoveType.SWAP)
    moveDuration = gun_reload__swapUnequipMagazineTime[gun_anim__reloadStyle]
  else
    logerr("[INVENTORY] Can't recognize mod move type <{weapon_mods__delayedMoveType}>")
    return

  var reloadMult = 1.f
  query(gun__owner) <| $ [es] (entity_mods__reloadMult : float)
    reloadMult = entity_mods__reloadMult
  weapon_mods__delayedMoveFinishTime = get_sync_time() + (moveDuration * reloadMult)


[es(tag=server, track=weapon_mods__modDelayedUnequipEid)]
def init_magazine_delayed_move_time_on_continue_swap(evt : Event;
                                                     gun__owner : EntityId;
                                                     gun_anim__reloadStyle : int;
                                                     weapon_mods__delayedMoveState : int;
                                                     weapon_mods__delayedMoveType : int;
                                                     weapon_mods__modDelayedUnequipEid : EntityId;
                                                     weapon_mods__modDelayedEquipEid : EntityId;
                                                     gun_reload__swapEquipMagazineTime : FloatList;
                                                     var weapon_mods__delayedMoveFinishTime : float&)
  if weapon_mods__delayedMoveState != int(ModDelayedMoveState.MOVE)
    return

  if weapon_mods__delayedMoveType == int(ModDelayedMoveType.SWAP) && weapon_mods__modDelayedUnequipEid == INVALID_ENTITY_ID
    if weapon_mods__modDelayedEquipEid == INVALID_ENTITY_ID
      logerr("[INVENTORY] Invalid equip mod eid <{weapon_mods__modDelayedEquipEid}> for ModDelayedMoveType SWAP")
      return

    var reloadMult = 1.f
    query(gun__owner) <| $ [es] (entity_mods__reloadMult : float)
      reloadMult = entity_mods__reloadMult
    weapon_mods__delayedMoveFinishTime = get_sync_time() + (gun_reload__swapEquipMagazineTime[gun_anim__reloadStyle] * reloadMult)


[es(tag=server, no_order)]
def abort_delayed_move_magazine_on_stop_aim_in_vehicle(evt : UpdateStageInfoAct;
                                                       eid : EntityId;
                                                       gun__owner : EntityId;
                                                       weapon_mods__delayedMoveState : int;
                                                       weapon_mods__delayedMoveSlotName : string)
  if weapon_mods__delayedMoveState == int(ModDelayedMoveState.NONE) || weapon_mods__delayedMoveSlotName != "magazine"
    return

  query(gun__owner) <| $ [es] (isInVehicle : bool; human_net_phys : HumanActor)
    if isInVehicle && !is_human_aiming(gun__owner, eid, human_net_phys)
      sendEvent(gun__owner, CmdAbortMoveWeaponMods(weaponEid = eid))
