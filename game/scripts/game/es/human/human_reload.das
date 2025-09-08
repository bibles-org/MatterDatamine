require ecs
require app
require DngNet
require game.events.events
require game.events.events_game
require game.events.inventory_events
require game.es.status_tip_common
require game.events.events_active_matter
require danetlibs.native_dasevents.main.native_events
require game.es.human_weap_common
require DngHuman
require DngActor
require DagorSystem
require DaWeaponProps
require Gun
require AnimV20
require GeomNodeTree
require game.es.human.human_reload_common
require game.es.boxed_item_common
require game.es.inventory_checks_common
require game.es.boxed_ammo_reload_common
require game.es.inventory_weapon_mod_common
require game.es.inventory_item_mod_common
require game.utils.net_utils
require game.es.inventory_item_common


[es(after=gun_init_es)]
def unload_ammo_es(evt : CmdUnloadAmmo;
                   gun__shell_prop_ids : GunShellPropIds&;
                   var gun_anim__shellsLoaded : int?;
                   var gun__ammo : int&;
                   var gun__curShellId : ShellPropIds&;
                   var gun : Gun&)
  gun__ammo -= evt.unloadAmmoCount
  if gun_anim__shellsLoaded != null
    *gun_anim__shellsLoaded = gun__ammo
  if gun__ammo == 0
    gun__curShellId = gun__shell_prop_ids[0]
    gun.curState.loaded = false


[es]
def load_ammo_es(evt : CmdLoadAmmo;
                 var gun : Gun;
                 var gun_anim__shellsLoaded : int?;
                 var gun__ammo : int&)
  gun__ammo += evt.loadAmmoCount
  if gun_anim__shellsLoaded != null
    *gun_anim__shellsLoaded = gun__ammo
  gun.curState.loaded = (gun__ammo > 0)

[es(tag=server)]
def human_weap_request_reload_es(evt : CmdRequestReload;
                                 eid : ecs::EntityId;
                                 itemContainer : ecs::EidList;
                                 human_weap_anim__reloadAtTime : float)
  let atTime = evt.atTime
  let gunEid = evt.gunEid

  if !has(gunEid, "gun__ammo") || has(gunEid, "grenade_thrower")
    return

  if !human_weap_can_reload(eid, gunEid)
    return

  if human_weap_anim__reloadAtTime > atTime
    return

  query(gunEid) <| $ [es(REQUIRE=gun__magazineReload)] (@shared_comp gun_mods__slots : Object const?;
                                                        gun__ammo : int;
                                                        gun__boxedAmmoHolderTemplate : string = "";
                                                        weapon_mods__delayedMoveState : int = int(ModDelayedMoveState.NONE))
    if weapon_mods__delayedMoveState != int(ModDelayedMoveState.NONE)
      return

    var hasMagazine = false
    if gun_mods__slots != null
      let magazineSlotName = "magazine"
      get_gun_available_magazines(*gun_mods__slots) <| $ [es] (magazines : StringList)
        let magazineForGun = find_magazine_for_gun(magazines, itemContainer)
        query(magazineForGun) <| $ [es(REQUIRE=gunAttachable__slotName)] (item__currentBoxedItemCount : int)
          if item__currentBoxedItemCount >= evt.minReloadAmmoCount
            hasMagazine = true
            if is_on_equip_weapon_mod_prev_can_fit(magazineForGun, magazineSlotName, gunEid, eid)
              send_net_event(eid, CmdEquipWeaponModFromInventory(
                itemEid = magazineForGun, weaponEid = gunEid, fromInventoryEid = eid, slotName = magazineSlotName))
              sendEvent(eid, EventWeapOnReload())
            else
              send_net_event(eid, CmdEquipWeaponModFromInventory(
                itemEid = magazineForGun, weaponEid = gunEid, fromInventoryEid = INVALID_ENTITY_ID, slotName = magazineSlotName))
              sendEvent(eid, EventWeapOnReload())
        if magazineForGun == INVALID_ENTITY_ID && !empty(gun__boxedAmmoHolderTemplate)
          // try load ammo from box
          if gun__ammo == 0
            let itemEid = find_boxed_item_to_draw_from(gun__boxedAmmoHolderTemplate, itemContainer)
            if itemEid != INVALID_ENTITY_ID
              hasMagazine = true
              send_net_event(eid, CmdLoadAmmoFromInventoryToGun(ammoEid = itemEid, gunEid = gunEid))
    if !hasMagazine
      send_net_event(eid, NotifyFailReloadGun(gunEid = gunEid, statusTip = "status_tip_no_magazines"), target_entity_conn(eid))

  query(gunEid) <| $ [es(REQUIRE=gun__boxedAmmoReload)] (gun__ammo : int;
                                                         gun__maxAmmo : int;
                                                         gun_boxed_ammo_reload__reloadState : int = int(BoxedAmmoReloadState.NONE);
                                                         gun__ammoHolders : StringList const?)
    if gun_boxed_ammo_reload__reloadState != int(BoxedAmmoReloadState.NONE)
      return

    // Do not reload full ammo
    if gun__ammo >= gun__maxAmmo && gun__ammo > 0
      send_net_event(eid, NotifyFailReloadGun(gunEid = gunEid, statusTip = "status_tip_full_ammo"), target_entity_conn(eid))
      return

    var itemEid = INVALID_ENTITY_ID
    if gun__ammoHolders != null
      itemEid = find_boxed_item_to_draw_from(*gun__ammoHolders, itemContainer)

    if itemEid == INVALID_ENTITY_ID
      send_net_event(eid, NotifyFailReloadGun(gunEid = gunEid, statusTip = "status_tip_no_ammo"), target_entity_conn(eid))
      return

    send_net_event(eid, CmdLoadAmmoFromInventoryToGun(ammoEid = itemEid, gunEid = gunEid))
    sendEvent(eid, EventWeapOnReload())


[es(tag=server, no_order, track=gun__ammo, on_appear)]
def server_update_is_ammo_loaded_es(evt : ecs::Event;
                                    gun__ammo : int;
                                    var gun__isAmmoLoaded : bool&)
  // gun.ammo is sensitive information that's available only to gun owner, however,
  // everyone needs to know if some gun is at least loaded with something or not. That's in
  // order to display chambered ammo for remotely controlled shadow entities correctly.
  // gun.isAmmoLoaded is used just for that and it's visible to anyone.
  gun__isAmmoLoaded = (gun__ammo > 0)


[es(after=gun_init_es, on_appear)]
def init_gun_cur_shell_id_es(evt : Event;
                             eid : EntityId;
                             gun__shell_prop_ids : GunShellPropIds;
                             shell_props : ShellPropIds;
                             gun__shells : Array const?;
                             var gun__curShellId : ShellPropIds&;
                             gun__emptyShell : Tag const?)
  if int(shell_props.shellId) >= 0
    gun__curShellId = shell_props
  elif length(gun__shell_prop_ids) > 0
    gun__curShellId = gun__shell_prop_ids[0]
  else
    gun__curShellId = ShellPropIds()
    if gun__emptyShell == null
      logerr("{getEntityTemplateName(eid)} has empty gun__shell_prop_ids. gun__shells: {gun__shells}")


[es(tag=gameClient, after=gun_init_es, track=gun__isAmmoLoaded, on_appear)]
def client_track_ammo_holder_es(evt : ecs::Event;
                                gun__owner : ecs::EntityId;
                                gun__ammo : int;
                                gun__isAmmoLoaded : bool;
                                var gun : Gun&)
  var isRemoteShadow = false
  query(gun__owner) <| $ [es] (human_net_phys : HumanActor)
    isRemoteShadow = human_net_phys.role == NetRole.ROLE_REMOTELY_CONTROLLED_SHADOW
  // gun__ammo is updating locally only for controlled player, for others it can came only by replication from the server
  // but we filter gun__ammo replication to not spectated players, because it saves some net traffic
  // gun__isAmmoLoaded is another component, replicated for every player, it only shows that gun is not empty
  // we don't use gun__isAmmoLoaded for local (!isRemoteShadow) player because it's value outdated compared to local ammo counter
  if isRemoteShadow
    gun.curState.loaded = gun__isAmmoLoaded
  else
    // Set loaded on creation
    gun.curState.loaded = (gun__ammo > 0)


[es(REQUIRE_NOT=sleeping_monster, no_order)]
def human_weap_reload_es(info : UpdateStageInfoAct;
                         eid : ecs::EntityId;
                         human_weap__currentGunEid : ecs::EntityId;
                         var human_weap_anim__reloadAtTime : float&;
                         var human_weap_anim__reloadStartTime : float&;
                         var human_weap__reloadDelayTime : float&)
  query(human_weap__currentGunEid) <| $ [es] (var gun__reloadFinishTime : float&)
    if gun__reloadFinishTime > info.curTime && !human_weap_can_reload(eid, human_weap__currentGunEid)
      human_weap__reloadDelayTime += info.dt
    elif human_weap__reloadDelayTime > 0.0
      human_weap_anim__reloadAtTime = human_weap_anim__reloadAtTime + human_weap__reloadDelayTime
      human_weap_anim__reloadStartTime = human_weap_anim__reloadStartTime + human_weap__reloadDelayTime
      gun__reloadFinishTime = gun__reloadFinishTime + human_weap__reloadDelayTime
      human_weap__reloadDelayTime = 0.0


[es(tag=gameClient, track=gun_boxed_ammo_reload__reloadState)]
def client_track_reload_gun_with_boxed_ammo_state(evt : Event;
                                                  gun_boxed_ammo_reload__reloadState : int;
                                                  var gun__isReloading : bool&)
  gun__isReloading = (gun_boxed_ammo_reload__reloadState > int(BoxedAmmoReloadState.WAIT))


[es(tag=gameClient, track=(weapon_mods__delayedMoveState, weapon_mods__delayedMoveSlotName))]
def client_track_reload_gun_with_magazine_state(evt : Event;
                                                weapon_mods__delayedMoveState : int;
                                                weapon_mods__delayedMoveSlotName : string;
                                                var gun__isReloading : bool&)
  gun__isReloading = (weapon_mods__delayedMoveState > int(ModDelayedMoveState.WAIT) && weapon_mods__delayedMoveSlotName == "magazine")


[es(tag=gameClient, REQUIRE=hero)]
def show_fail_reload_gun_hint(evt : NotifyFailReloadGun; human_weap__currentGunEid : EntityId)
  if human_weap__currentGunEid != evt.gunEid
    return
  create_status_tip(evt.statusTip)


[es(tag=gameClient, REQUIRE=(hero, human_weap__currentGunEid), track=human_weap__currentGunEid)]
def destroy_fail_reload_gun_hint_on_weapon_changed(evt : Event)
  query() <| $ [es(REQUIRE=status_tip__destroyOnChangeWeapon)] (eid : EntityId)
    destroyEntity(eid)


[es(tag=gameClient, on_appear, REQUIRE=status_tip__text)]
def destroy_tips_on_creating_new(evt : Event; eid aka created_eid : EntityId)
  query() <| $ [es(REQUIRE=status_tip__destroyOnAnotherTipAppears)] (eid : EntityId)
    if (eid != created_eid)
      destroyEntity(eid)


[es(tag=gameClient, REQUIRE=gun__ammo, track=gun__ammo)]
def destroy_full_ammo_hint_on_shoot(evt : Event;
                                    gun__owner : EntityId)
  if !has(gun__owner, "hero")
    return

  query() <| $ [es(REQUIRE=status_tip__destroyOnShoot)] (eid : EntityId)
    destroyEntity(eid)


[es(on_appear, REQUIRE=state__interruptReload)]
def stop_reload_on_state(evt : Event;
                         game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var human_net_phys : HumanActor)
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_RELOAD, false)
    sendEvent(game_effect__attachedTo, CmdInterruptReloadImmediately())
    interrupt_boxed_ammo_guns_reload(game_effect__attachedTo, true)
    interrupt_magazine_ammo_guns_reload(game_effect__attachedTo)