module grenade_thrower_common shared
require app
require ecs
require ecs.safe
require ecs.common
require game.es.ecs_common
require game.events.events
require game.events.events_game
require game.utils.animchar
require game.utils.team
require math.base
require DngWeapon
require DngPhys
require DngNet
require DngWeapon
require DngHuman
require DaWeapons
require DaWeaponProps
require DagorSystem
require Gun
require HumanPhys
require AnimV20
require game.events.inventory_events
require game.es.human.human_gun_common
require game.es.human.human_reload_common
require game.utils.net_utils
require inventory
require WeapHelpers
require app


def attach_projectile(owner_eid : EntityId;
                      gun_eid : EntityId;
                      projectile_entity : EntityId;
                      attach : bool)
  var result = false
  query(projectile_entity) <| $ [es] (gun_attach__mainSlotId : int;
                                      var slot_attach__slotId : int&;
                                      var slot_attach__visible : bool&)
    if attach
      anim_attach(slot_attach__slotId, owner_eid, gun_attach__mainSlotId, projectile_entity)
    else
      anim_detach(slot_attach__slotId, projectile_entity)

    slot_attach__visible = attach && get_bool(owner_eid, "human_weap__throwMode") ?? false
    if attach && gun_eid != INVALID_ENTITY_ID
      set(gun_eid, "human_gun_attached", true)
    result = true
  return result


def obtain_grenade_thrower_projectile_entity(var grenade_thrower__projectileEntity : EntityId&)
  if !doesEntityExist(grenade_thrower__projectileEntity)
    return INVALID_ENTITY_ID
  sendEvent(grenade_thrower__projectileEntity, CmdSlotDetach())
  let ent = grenade_thrower__projectileEntity
  grenade_thrower__projectileEntity = INVALID_ENTITY_ID
  return ent


def throw_grenade_away(eid : EntityId;
                       grenade_eid : EntityId;
                       human_weap__gunEids : EidList)
  var res = false
  query(grenade_eid) <| $ [es] (shell__shell_id__shell_id : int;
                                shell__shell_id__damage_id : int;
                                shell__shell_id__ballistics_id : int;
                                shell__gun_props_id : int;
                                shell__explTime : float;
                                transform : float3x4;
                                shell__owner : EntityId = INVALID_ENTITY_ID;
                                shell__rethrower : EntityId = INVALID_ENTITY_ID;
                                var active : bool&;
                                var slot_attach__visible : bool?)
    shell_entity_get_props(shell__shell_id__shell_id) <| $(entProps : ShellEntityTypeProps)
      let templName = entProps.templName
      if templName == ""
        return
      res = true
      using() <| $(var new_shell_props : ShellPropIds#)
        new_shell_props.shellId = int16(shell__shell_id__shell_id)
        new_shell_props.damageId = int16(shell__shell_id__damage_id)
        new_shell_props.ballisticsId = int16(shell__shell_id__ballistics_id)

        let gunEid = human_weap__gunEids[int(HUWeaponSlots.EWS_GRENADE)]
        query(gunEid) <| $ [es] (var shell_props : ShellPropIds;
                                 var gun__ammo : int&;
                                 var gun__curShellId : ShellPropIds;
                                 var gun : Gun;
                                 var human_gun_attached : bool&;
                                 var grenade_thrower__projectileEntity : EntityId&)
          // shell__owner is always someone, who throwed the grenade first, or rethrowed an unowned grenade
          // shell__rethrower (if valid) is always from the team, hostile to the shell owner
          // If the grenade already has a rethrower, it's (for simplicity) overwritten, which is a very rare case anyway

          var newShellOwner = shell__owner
          var newShellRethrower = shell__rethrower

          if shell__owner == INVALID_ENTITY_ID
            newShellOwner = eid
          else
            let team = get_int(eid, "team") ?? TEAM_UNASSIGNED
            let shellOwnerTeam = get_int(shell__owner, "team") ?? TEAM_UNASSIGNED
            if !is_teams_friendly(team, shellOwnerTeam)
              // rethrower is remembered, so he will be rewarded if the rethrow is "successfull" (kills rethrower's foes)
              newShellRethrower = eid

          human_gun_attached = false
          shell_props := new_shell_props
          gun__ammo = gun__ammo + 1
          gun__curShellId := new_shell_props

          gun.curState.loaded = (gun__ammo != 0)

          if is_server()
            destroyEntity(grenade_eid)
            destroyEntity(grenade_thrower__projectileEntity)
            grenade_thrower__projectileEntity = INVALID_ENTITY_ID
          else
            if slot_attach__visible != null
              *slot_attach__visible = false
            active = false

          let startVel = float3()
          // "transform" for a grenade in hand used as a fallback, if the grenade explodes before it gets attached to the player hand
          // it's possible if either grenade explosion or player death occurs in few frames after the rethrow is initiated
          grenade_thrower__projectileEntity = create_shell_entity(templName, transform, startVel,
                                                                  newShellOwner, new_shell_props,
                                                                  shell__gun_props_id, /*launch_time*/ get_sync_time(),
                                                                  shell__explTime, /*in_active*/ true, /*visible*/ true,
                                                                  /*clientSide*/ !is_server(),  newShellRethrower)

          if !is_server()
            query(eid) <| $ [es] (var human_weap__localProjectileEid : EntityId&)
              destroyEntity(human_weap__localProjectileEid)
              human_weap__localProjectileEid = grenade_thrower__projectileEntity
  return res

def find_rethrowable_grenade(to_whom : EntityId)
  var res = INVALID_ENTITY_ID
  query(to_whom) <| $ [es] (transform aka human_transform : float3x4; human_use_object__rethrowDist : float = 2.5f)
    let humanPos = human_transform[3]
    let humanDir = human_transform[0].xz
    query() <| $ [es(REQUIRE_NOT=shell__blockRethrow)] (eid : EntityId;
                                                        active : bool;
                                                        transform : float3x4;
                                                        slot_attach__attachedTo : EntityId;
                                                        shell__explTime : float;
                                                        shell__shell_id__shell_id : int;
                                                        shell__launchAtTime : float;
                                                        shell__rethrowTime : float = 4.0f;
                                                        grenade_rethrow__lockRethrowDuration = 0f)
      if slot_attach__attachedTo != INVALID_ENTITY_ID || !active
        return

      if get_sync_time() < shell__launchAtTime + grenade_rethrow__lockRethrowDuration
        return

      var adjustedRethrowTime = shell__rethrowTime
      // In online game server allows to rethrow a grenade for a little more time
      // So if the controls packet arrives a bit late (due to net lag), rethrow still happens
      // This fixes the situation, when the client rethrows the grenade close to the end of rethrowTime
      if is_true_net_server()
        adjustedRethrowTime += PHYS_MAX_CONTROLS_TICKS_DELTA_SEC

      var timer = 0.0f
      detonation_get_props(shell__shell_id__shell_id) <| $(detonationProps : DetonationProps)
        timer = detonationProps.timer

      let restTime = timer - min(adjustedRethrowTime, timer)
      if get_sync_time() > shell__explTime - restTime
        return

      let shellPos = transform[3]
      if length_sq(humanPos - shellPos) > square(human_use_object__rethrowDist)
        return

      if dot(humanDir, shellPos.xz - humanPos.xz) > 0.0
        res = eid
  return res


def private human_weap_switch_to_slot(eid : EntityId;
                                      gun_eid : EntityId)
  query(gun_eid) <| $ [es] (gun_attach__mainSlotId : int;
                            var slot_attach__slotId : int&)
    anim_attach(slot_attach__slotId, eid, gun_attach__mainSlotId, gun_eid)


def obtain_owned_projectile_entity(eid : EntityId;
                                   slot : HUWeaponSlots)
  var projectileEid = INVALID_ENTITY_ID
  query(eid) <| $ [es] (human_weap__throwMode : bool;
                        human_weap__currentGunSlot : int = -1;
                        human_weap__gunEids : EidList)
    let currentGunSlot = int(slot) < int(HUWeaponSlots.EWS_NUM) ? int(slot) : human_weap__currentGunSlot
    let gunEidsCount = length(human_weap__gunEids)
    if human_weap__throwMode && int(HUWeaponSlots.EWS_GRENADE) >= gunEidsCount
      return
    if !human_weap__throwMode && uint(currentGunSlot) >= uint(gunEidsCount)
      return

    let gunEid = human_weap__gunEids[human_weap__throwMode ? int(HUWeaponSlots.EWS_GRENADE) : currentGunSlot]
    query(gunEid) <| $ [es] (var grenade_thrower__projectileEntity : EntityId&)
      projectileEid = obtain_grenade_thrower_projectile_entity(grenade_thrower__projectileEntity)

  return projectileEid


def reload_grenade(eid : EntityId; slot_id : int; mode : ReloadAmmoMode; wish_grenade_eid = INVALID_ENTITY_ID)
  var isSuccess = false
  query(eid) <| $ [es] (human_weap__gunEids : EidList)
    let gunEid = human_weap__gunEids[slot_id]
    query(gunEid) <| $ [es] (gun__shell_prop_ids : GunShellPropIds;
                             gun__ammo : int;
                             var shell_props aka gun_shell_props : ShellPropIds&;
                             var gun__curShellId : ShellPropIds&;
                             var grenade_thrower__grenadeItemEntity : EntityId&;
                             gun__wishAmmoItemType : int = 0)
      let wishedItemEid = wish_grenade_eid != INVALID_ENTITY_ID ? wish_grenade_eid : find_wished_shell_for_gun(gun__wishAmmoItemType, eid)
      let grenadeEid = wishedItemEid != INVALID_ENTITY_ID ? wishedItemEid : find_shell_for_gun(gun__shell_prop_ids, eid)
      if !grenadeEid
        return

      grenade_thrower__grenadeItemEntity = grenadeEid
      gun_shell_props = length(gun__shell_prop_ids) > 0 ? gun__shell_prop_ids[0] : ShellPropIds()
      query(grenade_thrower__grenadeItemEntity) <| $ [es] (shell_props aka item_shell_props : ShellPropIds)
        gun_shell_props = item_shell_props
      gun__curShellId = shell_props

      if mode == ReloadAmmoMode.CONSUME
        if is_server()
          destroyEntity(grenade_thrower__grenadeItemEntity)
        grenade_thrower__grenadeItemEntity = INVALID_ENTITY_ID

      if gun__ammo == 0
        sendEventImmediate(gunEid, CmdLoadAmmo(loadAmmoCount = 1))

      isSuccess = true
  return isSuccess


def clear_projectile_entity_impl(eid : EntityId;
                                 gun_eid : EntityId;
                                 human_weap__gunEids : EidList;
                                 var human_weap__throwMode : bool?;
                                 var grenade_thrower__projectileEntity : EntityId&;
                                 var grenade_thrower : GrenadeThrower)
  let projEid = obtain_grenade_thrower_projectile_entity(grenade_thrower__projectileEntity)
  if projEid != INVALID_ENTITY_ID
    destroyEntity(projEid)
    grenade_thrower.state = GrenadeThrowState.GTS_READY
    grenade_thrower.throwProgress = 0.0
    query(eid) <| $ [es] (var human_net_phys : HumanActor)
      if human_weap__throwMode != null
        clear_throw_mode(eid, gun_eid, human_weap__gunEids,
                         *human_weap__throwMode, human_net_phys.phys)


def clear_projectile_entity(eid : EntityId;
                            proj_eid : EntityId)
  query(eid) <| $ [es] (human_weap__gunEids : EidList;
                        var human_weap__throwMode : bool?)
    let gunEidsCount = length(human_weap__gunEids)
    for i in range(gunEidsCount)
      query(human_weap__gunEids[i]) <| $ [es] (var grenade_thrower__projectileEntity : EntityId&;
                                               var grenade_thrower : GrenadeThrower)
        if (grenade_thrower__projectileEntity == proj_eid)
          clear_projectile_entity_impl(eid, human_weap__gunEids[i], human_weap__gunEids,
                                       human_weap__throwMode, grenade_thrower__projectileEntity,
                                       grenade_thrower)


def change_grenade(eid : EntityId;
                   human_weap__gunEids : EidList)
  let obtainOwnedProjectileEntity = obtain_owned_projectile_entity(eid, HUWeaponSlots.EWS_GRENADE)
  if is_server()
    destroyEntity(obtainOwnedProjectileEntity)
  // Creating the projectile both on the server and the client so that the client will see the projectile in hand immediately
  let newProjectileEid = reload_projectile(eid, human_weap__gunEids[int(HUWeaponSlots.EWS_GRENADE)])

  if !is_server()
    // Storing the projectile eid so that the projectile can be destroyed later when the server's projectile arrive
    query(eid) <| $ [es] (var human_weap__localProjectileEid : EntityId&)
      destroyEntity(human_weap__localProjectileEid)
      human_weap__localProjectileEid = newProjectileEid


def change_grenade_in_hand(eid : EntityId;
                           human_weap__gunEids : EidList)
  let grenadeSlotEid = human_weap__gunEids[int(HUWeaponSlots.EWS_GRENADE)]
  var hasGrenade = true
  query(grenadeSlotEid) <| $ [es] (gun__wishAmmoItemType : int;
                                   grenade_thrower__projectileEntity : EntityId)
    if gun__wishAmmoItemType == 0
      clear_projectile_entity(eid, grenade_thrower__projectileEntity)
      hasGrenade = false
  if !hasGrenade
    return false
  let slot_id = HUWeaponSlots.EWS_GRENADE
  if reload_grenade(eid, int(slot_id), ReloadAmmoMode.INFINITE) // do not consume ammo, just setup shellID
    change_grenade(eid, human_weap__gunEids)
    if is_server()
      send_net_event(eid, EventOnWeaponChanged(oldWeaponEid = grenadeSlotEid, newWeaponEid = grenadeSlotEid, slotId = int(HUWeaponSlots.EWS_GRENADE)))
    return true
  else
    query(grenadeSlotEid) <| $ [es] (grenade_thrower__projectileEntity : EntityId)
      clear_projectile_entity(eid, grenade_thrower__projectileEntity)
  return false


def take_grenade_in_hand(eid : EntityId;
                         human_weap__gunEids : EidList;
                         var phys : HumanPhys;
                         grenade_eid = INVALID_ENTITY_ID)
  let grenadeSlotEid = human_weap__gunEids[int(HUWeaponSlots.EWS_GRENADE)]
  var hasGrenade = false
  query(grenadeSlotEid) <| $ [es] (gun__totalAmmo : int;
                                   gun__ammo : int)
    hasGrenade = gun__totalAmmo > 0 || gun__ammo > 0
  query(grenade_eid) <| $ [es] (item__humanOwnerEid : EntityId)
    hasGrenade = item__humanOwnerEid == eid

  if !hasGrenade
    return false
  let slot_id = HUWeaponSlots.EWS_GRENADE
  if reload_grenade(eid, int(slot_id), ReloadAmmoMode.INFINITE, grenade_eid) // do not consume ammo, just setup shellID
    change_grenade(eid, human_weap__gunEids)

    phys.producedCT |> set_chosen_weapon(HUWeaponSlots.EWS_GRENADE)
    return true
  return false


def try_rethrow_grenade(eid : EntityId;
                        human_weap__gunEids : EidList;
                        var phys : HumanPhys;
                        human_use_object__selectedObject : EntityId const?)
  var res = false
  var grenadeEid = INVALID_ENTITY_ID
  if is_server()
    grenadeEid = find_rethrowable_grenade(eid)
  elif human_use_object__selectedObject != null
    grenadeEid = *human_use_object__selectedObject
  if grenadeEid != INVALID_ENTITY_ID
    res = throw_grenade_away(eid, grenadeEid, human_weap__gunEids)
    if res
      phys.producedCT |> set_chosen_weapon(HUWeaponSlots.EWS_GRENADE)
    elif is_server()
      send_net_event(eid, HumanWeapThrowBackAbort(), target_entity_conn(eid))
  return res


def try_reload_grenade(human_eid : EntityId;
                       cur_weap_slot : HUWeaponSlots;
                       grenade_slot_eid : EntityId;
                       human_weap__gunEids : EidList;
                       is_downed : bool;
                       ct : HumanControlState)
  var reloadGrenade = false
  let isThrowReq = ct |> is_control_bit_set(HumanPhysControlType.HCT_THROW)
  let isShoot = is_control_bit_set(ct, HumanPhysControlType.HCT_SHOOT)
  if (grenade_slot_eid != INVALID_ENTITY_ID &&
      cur_weap_slot == HUWeaponSlots.EWS_GRENADE &&
      (isShoot || isThrowReq) && !is_downed)
    reloadGrenade = true

  if reloadGrenade
    reload_grenade(human_eid, human_weap__gunEids, reloadGrenade)

  return reloadGrenade


def private reload_grenade(eid : EntityId;
                           human_weap__gunEids : EidList;
                           var isSuccess : bool&)
  var currentGrenade = INVALID_ENTITY_ID
  query(human_weap__gunEids[int(HUWeaponSlots.EWS_GRENADE)]) <| $ [es] (grenade_thrower__grenadeItemEntity : EntityId)
    currentGrenade = grenade_thrower__grenadeItemEntity
  if reload_grenade(eid, int(HUWeaponSlots.EWS_GRENADE), ReloadAmmoMode.CONSUME, currentGrenade)
    // Creating the projectile both on the server and the client so that the client will see the projectile in hand immediately
    let projectileEid = reload_projectile(eid, human_weap__gunEids[int(HUWeaponSlots.EWS_GRENADE)])

    if !is_server()
      // Storing the projectile eid so that the projectile can be destroyed later when the server's projectile arrive
      query(eid) <| $ [es] (var human_weap__localProjectileEid : EntityId&)
        destroyEntity(human_weap__localProjectileEid)
        human_weap__localProjectileEid = projectileEid
    isSuccess = true
  else
    isSuccess = false



def clear_throw_mode(eid : EntityId;
                     gun_eid : EntityId;
                     human_weap__gunEids : EidList;
                     var human_weap__throwMode : bool&;
                     var phys : HumanPhys)
  human_weap__throwMode = false
  let curGun = phys.currentState.weapEquipState.curSlot
  if curGun != HUWeaponSlots.EWS_GRENADE // Fast throw
    send_event_if_possible(gun_eid, CmdWeapAttach(toEid = eid, isAttached = false, slotId = int(curGun)))
    if int(curGun) < length(human_weap__gunEids)
      human_weap_switch_to_slot(eid, human_weap__gunEids[int(curGun)])
    phys.currentState.weapEquipState.curState = HUWeaponEquipState.EES_EQUIPED
    if reload_grenade(eid, int(HUWeaponSlots.EWS_GRENADE), ReloadAmmoMode.INFINITE)
      change_grenade(eid, human_weap__gunEids)
    else
      query(gun_eid) <| $ [es] (var gun__curShellId : ShellPropIds;
                                var gun__ammo : int&)
        if gun__ammo > 0
          gun__ammo = 0
          gun__curShellId = ShellPropIds()
  elif !take_grenade_in_hand(eid, human_weap__gunEids, phys)
    switch_to_first_weap_with_ammo(human_weap__gunEids, phys)
