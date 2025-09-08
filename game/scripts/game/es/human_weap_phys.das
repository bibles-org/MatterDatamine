require ecs
require ecs.common
require DngHuman
require DagorMath
require HumanPhys
require player
require math.base
require game.events.events
require game.events.events_active_matter

def reset_human_aim_zoom(var human_net_phys : HumanActor; var camera__magnification : float&)
  human_net_phys.phys.currentState.aimPosition = 0.f
  human_net_phys.phys.currentState.zoomPosition = 0.f
  human_net_phys.phys.previousState.aimPosition = 0.f
  human_net_phys.phys.previousState.zoomPosition = 0.f
  camera__magnification = 1.f

[es(before=after_net_phys_sync, after=before_net_phys_sync, REQUIRE_NOT=sleeping_monster)]
def human_weap_phys_es(info : UpdateStageInfoAct;
                       human_weap__blockAiming : bool;
                       boltActionProgress : float;
                       isGunManualLoadMode : bool;
                       var human_net_phys : HumanActor;
                       human_phys__jumpEndTime : float;
                       human_phys__afterJumpDelay : float = -1.;
                       human_phys__isInAirLong : bool = false;
                       human_weap__currentGunEid : EntityId = INVALID_ENTITY_ID;
                       human_anim__crawlThreshold : float = -1.0;
                       human__lockZoom = false;
                       human_attached_gun__isAttached = false;
                       isDowned = false;
                       action__running = false)
  assume ct = human_net_phys.phys.currentState
  let standState = ct.standState
  let isCrawling = ct.moveState != HUMoveState.EMS_STAND && ct.isCrawl
  let isShootingStandState = standState == HUStandState.ESS_STAND || standState == HUStandState.ESS_CROUCH || standState == HUStandState.ESS_CRAWL
  let isBoltActionInProgress = isGunManualLoadMode ? boltActionProgress > 0.f && boltActionProgress < 1.f : false
  let isChangingWeapon = ct.weapEquipState.curState == HUWeaponEquipState.EES_EQUIPING || ct.weapEquipState.curState == HUWeaponEquipState.EES_HOLSTERING
  let isCrawlTransition = !is_equal_float(human_anim__crawlThreshold, -1.f) && ct.height < human_anim__crawlThreshold && !is_equal_float(ct.height, -1.f)
  let isJumpState = (human_phys__isInAirLong
    || (uint(ct.states) & uint(StateFlag.ST_JUMP)) != 0u
    || ct.jumpStartTime > 0.
    || info.curTime - human_phys__jumpEndTime < human_phys__afterJumpDelay)

  var canZoomInBoltAction = false
  var isMeleeGun = false
  var gunDisableAim = false
  var reloadingOrEquippingMod = false
  query(human_weap__currentGunEid) <| $ [es] (gun__melee = false;
                                              gun__disableAim = false;
                                              gun__canZoomInBoltAction : Tag const? = null;
                                              gun_boxed_ammo_reload__reloadState : int = -1;
                                              weapon_mods__delayedMoveState : int = -1)
    canZoomInBoltAction = gun__canZoomInBoltAction != null
    isMeleeGun = gun__melee
    gunDisableAim = gun__disableAim
    reloadingOrEquippingMod = gun_boxed_ammo_reload__reloadState != -1 || weapon_mods__delayedMoveState != -1

  human_phys_state_set_can_aim(ct,
    (!reloadingOrEquippingMod || human_attached_gun__isAttached) &&
    (ct.weapEquipState.curState == HUWeaponEquipState.EES_EQUIPED) &&
    !isBoltActionInProgress &&
    !isDowned && !human_weap__blockAiming && !human__lockZoom && !isCrawling && isShootingStandState && !isMeleeGun && !gunDisableAim && !isCrawlTransition)

  human_phys_state_set_can_zoom(ct,
    (!reloadingOrEquippingMod || human_attached_gun__isAttached) &&
    !isDowned && !human_weap__blockAiming && !human__lockZoom &&
    (!isBoltActionInProgress || canZoomInBoltAction)
    && !action__running && isShootingStandState && !isChangingWeapon && !isJumpState)

[es(track=human_anim__vehicleSelected, REQUIRE=human_anim__vehicleSelected)]
def human_weap_zoom_reset_es(evt : Event; var human_net_phys : HumanActor; var camera__magnification : float&)
  reset_human_aim_zoom(human_net_phys, camera__magnification)

[es(track=human__lockZoom, REQUIRE=human__lockZoom)]
def human_weap_lock_zoom_reset_es(evt : Event; var human_net_phys : HumanActor; var camera__magnification : float&)
  reset_human_aim_zoom(human_net_phys, camera__magnification)

[es(on_event=EventEntityDowned)]
def downed_human_reset_zoom_es(evt : Event; var human_net_phys : HumanActor; var camera__magnification : float&)
  reset_human_aim_zoom(human_net_phys, camera__magnification)

[es(on_appear, REQUIRE=attachedToParent, track=gun__length)]
def init_human_weapon_len_on_gun_appear_es(evt : Event;
                                           eid : EntityId;
                                           gun__owner : EntityId;
                                           gun__length : float = 0f)
  query(gun__owner) <| $ [es] (human_weap__gunEids : EidList; var human_net_phys : HumanActor&)
    var slotId = -1
    for i in iter_range(human_weap__gunEids)
      if human_weap__gunEids[i] == eid
        slotId = i
        break

    if slotId < 0
      return

    human_net_phys.phys |> human_phys_setWeaponLen(gun__length, slotId)

[es(on_appear, track=human_weap__gunEids)]
def init_human_weapon_len_on_soldier_gun_list_change_es(evt : Event;
                                                        human_weap__gunEids : EidList;
                                                        var human_net_phys : HumanActor&)
  for eid, i in human_weap__gunEids, iter_range(human_weap__gunEids)
    query(eid) <| $ [es] (gun__length : float = 0f)
      human_net_phys.phys |> human_phys_setWeaponLen(gun__length, i)


[es]
def human_weap_update_backoff_gun_dynamic_offset(evt : ParallelUpdateFrameDelayed;
                                                 human_weap__currentGunEid : EntityId;
                                                 human_weap__gunMaxBackoff : float;
                                                 human_net_phys : HumanActor)
  assume currentState = human_net_phys.phys.currentState
  if currentState.weapEquipState.curState != HUWeaponEquipState.EES_EQUIPED
    return

  query(human_weap__currentGunEid) <| $ [es] (gun_dynamic_position__maxOffset : float3;
                                              var gun_dynamic_position__offset : float3&)
    let backoffProgress = cvt(currentState.gunBackoffAmount, 0.0, human_weap__gunMaxBackoff, 0.0, 1.0)
    gun_dynamic_position__offset = gun_dynamic_position__maxOffset * backoffProgress
