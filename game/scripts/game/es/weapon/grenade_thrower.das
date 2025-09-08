require ecs
require ecs.common
require game.events.events
require game.utils.animchar
require game.events.events_game
require game.events.events_active_matter
require game.es.grenade_thrower_common
require game.es.ecs_common
require DngHuman
require DngWeapon
require DngPhys
require DaWeapons
require DaWeaponProps
require Gun
require HumanPhys
require AnimV20
require math.base
require game.es.human.human_gun_common
require game.es.human.human_reload_common


def is_in_range(val : float; min : float; max : float)
  return val > min && val <= max


[es]
def grenade_thrower_phys_es(evt : CmdWeapPhysUpdate;
                            eid aka thrower_eid : EntityId;
                            human_gun_attached : bool;
                            grenade_throw__drawTime : float;
                            grenade_throw__throwTime : float;
                            grenade_throw__throwProgressTime : float;
                            grenade_throw__fastThrowProgressTime : float;
                            grenade_throw__cookProgressTime : float;
                            grenade_thrower__projectileEntity : EntityId = INVALID_ENTITY_ID;
                            var grenade_thrower : GrenadeThrower)
  let isForReal = evt.isForReal
  if !isForReal
    return

  let ownerEid = evt.owner
  let atTime = evt.atTime
  let dt = evt.dt
  var gctrl = evt.gctrl
  assume gloc = evt.gloc

  if !human_gun_attached
    send_event_if_possible(thrower_eid, CmdWeapAttach(toEid = ownerEid, isAttached = true, slotId = int(HUWeaponSlots.EWS_GRENADE)))

  query(ownerEid) <| $ [es] (human_weap__fastThrowExclusive : bool = true;
                             human_weap__gunEids : EidList;
                             var human_weap__quickThrowLastWeaponSlot : int&;
                             var human_net_phys : HumanActor&;
                             var human_weap__throwMode : bool&)

    // TODO: reformat to simple FSM, so it'll be easier to read/understand
    if grenade_thrower.state == GrenadeThrowState.GTS_READY
      verify(grenade_thrower.throwProgress == 0.0)
      if gctrl.shoot && !!grenade_thrower__projectileEntity
        // Start fetching the grenade
        grenade_thrower.state = GrenadeThrowState.GTS_DRAW
        grenade_thrower.stateStart = atTime
        grenade_thrower.stateEnd = atTime + grenade_throw__drawTime
      // else
      //   Doing nothing
      //   Progress stays at 0
    elif grenade_thrower.state == GrenadeThrowState.GTS_DRAW
      if atTime > grenade_thrower.stateEnd
        // grenade_thrower.throwProgress isn't guaranteed to reach exactly 0.5
        // arTime + dt on frame N can be less, than atTime on frame N + 1
        verify(grenade_thrower.throwProgress <= 0.5)
        if !gctrl.shoot // Trigger is released
          // Starting to throw the grenade
          grenade_thrower.state = GrenadeThrowState.GTS_THROW
          grenade_thrower.stateStart = atTime
          grenade_thrower.stateEnd = atTime + grenade_throw__throwTime
        query(grenade_thrower__projectileEntity) <| $ [es] (shell__explTime : float;
                                                            active : bool)
          // if grenade explode in hande before explode throw it
          // This is to ensure that projectile has time to appear.
          // Projectile will explode almost immediately and create sound and fx effect.
          if shell__explTime - atTime < 0.05f && active
            grenade_thrower.state = GrenadeThrowState.GTS_THROW
        // else
        //   Waiting with the grenade in hand
        //   grenade_thrower.progress stays at 0.5
      else
        // Draw in progress
        // grenade_thrower.progress goes from 0 to 0.5
        // grenade_thrower.progress can be exactly 0 at this point only if app.timeSpeed == 0
        verify(grenade_thrower.throwProgress >= 0.0 && grenade_thrower.throwProgress <= 0.5)
    elif grenade_thrower.state == GrenadeThrowState.GTS_THROW
      if atTime > grenade_thrower.stateEnd
        // Throw is finished
        // grenade_thrower.throwProgress isn't guaranteed to reach exactly 1.0 because of floating point errors
        verify(grenade_thrower.throwProgress <= 1.0)
        assume weapEquipState = human_net_phys.phys.currentState.weapEquipState
        if weapEquipState.curSlot != HUWeaponSlots.EWS_GRENADE || \
          (weapEquipState.curSlot == HUWeaponSlots.EWS_GRENADE && weapEquipState.curState == HUWeaponEquipState.EES_EQUIPING && weapEquipState.progress > 0.0)
          grenade_thrower.state = GrenadeThrowState.GTS_READY
        elif reload_grenade(ownerEid, int(HUWeaponSlots.EWS_GRENADE), ReloadAmmoMode.INFINITE)
          human_weap__throwMode = false
          weapEquipState.progress = 0.0f
          weapEquipState.curState = HUWeaponEquipState.EES_DOWN
          weapEquipState.curSlot = HUWeaponSlots.EWS_UNARMED
          change_grenade(ownerEid, human_weap__gunEids)
        else
          switch_to_first_weap_with_ammo(human_weap__gunEids, human_net_phys.phys)
        if human_weap__quickThrowLastWeaponSlot >= 0
          human_net_phys.phys.producedCT |> set_chosen_weapon(HUWeaponSlots(human_weap__quickThrowLastWeaponSlot))
          if human_net_phys.phys.producedCT.chosenWeapon != HUWeaponSlots.EWS_GRENADE //if fast throwing and grenade is not a selected weapon
            human_weap__throwMode = false
          human_weap__quickThrowLastWeaponSlot = -1
    else
      // Throw in progress
      // grenade_thrower.progress goes from 0.5 to 1.0
      // grenade_thrower.progress can be exactly 0.5 at this point only if app.timeSpeed == 0
      verify(grenade_thrower.throwProgress >= 0.5 && grenade_thrower.throwProgress <= 1.0)

    let prevThrowProgress = grenade_thrower.throwProgress
    grenade_thrower.throwProgress = calc_grenade_throw_progress(grenade_thrower, atTime + dt)

    if grenade_thrower__projectileEntity != INVALID_ENTITY_ID
      if is_in_range(grenade_throw__cookProgressTime, prevThrowProgress, grenade_thrower.throwProgress)
        // activating client-side grenade too, so it have correct explTime
        query(grenade_thrower__projectileEntity) <| $ [es] (shell__shell_id__shell_id : int;
                                                            var shell__explTime : float&;
                                                            var active : bool&)
          if !active
            detonation_get_props(shell__shell_id__shell_id) <| $(detonationProps : DetonationProps)
              shell__explTime = atTime + detonationProps.timer
              active = true

    if !human_gun_attached
      return

    // if throwProgressTime is set < 0.5, the grenade won't be thrown because the GTS_DRAW stage isn't finished
    let throwProgressTime = human_weap__fastThrowExclusive ? grenade_throw__fastThrowProgressTime : grenade_throw__throwProgressTime
    gctrl.shoot = (grenade_thrower.state == GrenadeThrowState.GTS_THROW &&
                  is_in_range(throwProgressTime,
                              prevThrowProgress,
                              grenade_thrower.throwProgress))

    let rndSeed = phys_time_to_seed(atTime)
    sendEventImmediate(thrower_eid, CmdGunUpdate(atTime = atTime, isForReal = isForReal, seed = rndSeed, gctrl = gctrl, gloc = gloc))


[es(before=human_gun_attach_es)]
def grenade_thrower_attach_es(evt : CmdWeapAttach;
                              eid : EntityId;
                              grenade_thrower__projectileEntity : EntityId;
                              gun_attach__mainSlotId : int;
                              var gun : Gun;
                              var slot_attach__slotId : int&;
                              var human_gun_attached : bool&;
                              var grenade_thrower__selectedGrenadeVarId : int&)
  let wasHumanGunAttached = human_gun_attached
  let ownerEid = evt.toEid
  let attachFlag = evt.isAttached
  if !attach_projectile(ownerEid, eid, grenade_thrower__projectileEntity, attachFlag)
    return

  if attachFlag
    anim_attach(slot_attach__slotId, ownerEid, gun_attach__mainSlotId, eid)
  else
    anim_detach(slot_attach__slotId, eid)

  grenade_thrower__selectedGrenadeVarId = -1
  query(grenade_thrower__projectileEntity) <| $ [es] (grenade__selectedWeaponVar : string)
    grenade_thrower__selectedGrenadeVarId = animV20_add_enum_value(grenade__selectedWeaponVar)

  if !wasHumanGunAttached
    query(ownerEid) <| $ [es] (animchar : AnimcharBaseComponent)
      let geomNodeTree = animchar.nodeTree
      if geomNodeTree != null
        gun |> gun_loadShootNode(gun_attach__mainSlotId, *geomNodeTree)

  if !attachFlag
    human_gun_attached = false


[es]
def grenade_thrower_detach_es(evt : CmdWeapDetach;
                              grenade_thrower__projectileEntity : EntityId)
  if grenade_thrower__projectileEntity != INVALID_ENTITY_ID
    sendEvent(grenade_thrower__projectileEntity, CmdWeapDetach())

[es(tag=server, on_disappear, after=human_weap_drop_grenade_es)]  // in the drop_grenade ES the active flag is possibly set to true
def grenade_thrower_destroy_projectile_es(evt : Event;
                                          var grenade_thrower__projectileEntity : EntityId&)
  query(grenade_thrower__projectileEntity) <| $ [es] (active : bool)
    if !active
      destroyEntity(grenade_thrower__projectileEntity)
      grenade_thrower__projectileEntity = INVALID_ENTITY_ID

[es(tag=server, on_disappear, REQUIRE=shell__explTime)]
def grenade_thrower_on_destroy_es(evt : Event;
                                  eid : EntityId)
  find_query() <| $ [es] (var grenade_thrower__projectileEntity : EntityId&)
    if grenade_thrower__projectileEntity != eid
      return false
    grenade_thrower__projectileEntity = INVALID_ENTITY_ID
    return true


[es(tag=gameClient, REQUIRE=item__grenadeType)]
def take_grenade_on_item_usage(evt : TryUseItem;
                               eid : EntityId;
                               item__id : int)
  sendEvent(evt.userEid, CmdSetWishGrenadeType(slot_id = int(HUWeaponSlots.EWS_GRENADE), item_id = item__id, try_take = true, wish_item = eid))