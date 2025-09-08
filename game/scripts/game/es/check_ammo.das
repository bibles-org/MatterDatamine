require ecs
require app
require game.events.events_game
require active_matter.game.es.check_ammo_common
require game.events.events_active_matter
require game.es.inventory_weapon_mod_common
require game.es.inventory_checks_common
require game.es.inventory_transactions_common
require DagorSystem
require DagorMath
require DngHuman
require DngNet
require HumanPhys
require PhysVars
require AnimV20
require game.es.human.human_gun_common


def is_active_atate(state : int)
  return state != CheckAmmoState.NONE && state != CheckAmmoState.FINISHED


[es(tag=server)]
def request_check_ammo(evt : RqCheckAmmo;
                       eid aka actor_eid : EntityId;
                       human_net_phys : HumanActor;
                       isAlive : bool = true;
                       isDowned : bool = false;
                       human_net_phys__isSwimming : bool = false;
                       human_net_phys__isUnderwater : bool = false;
                       human_attached_gun__isAttached : bool = false;
                       human_ladder__attached : bool = false;
                       human_net_phys__isOnGround : bool = true;
                       human_weap__throwMode : bool = false;
                       human_weap_anim__reloadAtTime : float = 0.0;
                       human_weap__currentGunSlot : int;
                       human_weap__currentGunEid : EntityId;
                       var check_ammo_controller__state : int&;
                       var check_ammo_controller__input : bool&)
  assume phys = human_net_phys.phys
  assume currentState = phys.currentState
  assume weapEquipState = currentState.weapEquipState

  if check_ammo_controller__input == evt.value
    return

  check_ammo_controller__input = evt.value

  if evt.value && !is_active_atate(check_ammo_controller__state)
    // Try to start inspection
    var currentGunAmmoCanBeChecked = false
    var currentGunAmmoHolderMissed = false
    let isMeleeOrUnarmed = human_weap__currentGunSlot == int(HUWeaponSlots.EWS_MELEE) || human_weap__currentGunSlot == int(HUWeaponSlots.EWS_UNARMED)
    if !isMeleeOrUnarmed
      query(human_weap__currentGunEid) <| $ [es] (gun_jamming__fixJammingEndAt = -1.0;
                                                  gun_mods__curModInSlots : Object const?;
                                                  gun_boxed_ammo_reload__reloadState : int const?)
        if gun_jamming__fixJammingEndAt > 0.0
          currentGunAmmoCanBeChecked = false
          return
        if gun_boxed_ammo_reload__reloadState != null
          currentGunAmmoCanBeChecked = true
        else
          currentGunAmmoHolderMissed = true
          if gun_mods__curModInSlots != null
            for gunModInSlot in *gun_mods__curModInSlots
              let gunModEid = get_Eid(gunModInSlot.value) ?? INVALID_ENTITY_ID
              if has(gunModEid, "ammo_holder__id")
                currentGunAmmoCanBeChecked = true
                currentGunAmmoHolderMissed = false
                break
    if currentGunAmmoHolderMissed
      // Just try to load ammo holder
      sendEvent(actor_eid, CmdRequestReload(atTime = get_sync_time(), gunEid = human_weap__currentGunEid, minReloadAmmoCount = 1))
      return


    let isAiming = human_net_phys.phys.currentState.isAiming
    let isInAir = (uint(currentState.isInAirHistory) & 1u) != 0u
    let isReloading = get_sync_time() < human_weap_anim__reloadAtTime
    let isAvailable = (isAlive &&
                       human_net_phys__isOnGround &&
                       weapEquipState.curState == HUWeaponEquipState.EES_EQUIPED &&
                       currentGunAmmoCanBeChecked &&
                       !human_weap__throwMode &&
                       !isAiming &&
                       !isDowned &&
                       !human_net_phys__isSwimming &&
                       !human_net_phys__isUnderwater &&
                       !human_attached_gun__isAttached &&
                       !human_ladder__attached &&
                       !isInAir &&
                       !isReloading)
    if isAvailable
      check_ammo_controller__state = int(CheckAmmoState.IN)
  elif !evt.value && check_ammo_controller__state == CheckAmmoState.IDLE
    // Idle -> Out
    check_ammo_controller__state = int(CheckAmmoState.OUT)
  elif !evt.value && check_ammo_controller__state == CheckAmmoState.IN
    // In -> In Reverse
    check_ammo_controller__state = int(CheckAmmoState.IN_REVERSE)


def set_ammo_inspection_progress_to_gun(gun_eid : EntityId;
                                        ammo_inspection_progress : float;
                                        ammo_inspection_idle_progress : float)
  query(gun_eid) <| $ [es] (gun_anim__ammoInspectionProgressVarId : int;
                            gun_anim__ammoInspectionIdleProgressVarId : int;
                            var phys_vars aka gun_phys_vars : PhysVars)
    gun_phys_vars |> setVar(gun_anim__ammoInspectionProgressVarId, ammo_inspection_progress)
    gun_phys_vars |> setVar(gun_anim__ammoInspectionIdleProgressVarId, ammo_inspection_idle_progress)

  query(gun_eid) <| $ [es] (gun_anim_v2__operationProgressVarId : int;
                            gun_anim_v2__ammoInspectionIdleProgressVarId : int;
                            var phys_vars : PhysVars;
                            gun_anim_v2__currentOperationState : int)
    if gun_anim_v2__currentOperationState == int(GunOperationState.AMMO_INSPECTION)
      phys_vars |> setVar(gun_anim_v2__operationProgressVarId, ammo_inspection_progress)
      phys_vars |> setVar(gun_anim_v2__ammoInspectionIdleProgressVarId, ammo_inspection_idle_progress)


def reset_ammo_inspection_progress_to_gun(gun_eid : EntityId)
  query(gun_eid) <| $ [es] (gun_anim__ammoInspectionProgressVarId : int;
                            gun_anim__ammoInspectionIdleProgressVarId : int;
                            var animchar : AnimcharBaseComponent;
                            var phys_vars aka gun_phys_vars : PhysVars)
    gun_phys_vars |> setVar(gun_anim__ammoInspectionProgressVarId, 0.0)
    gun_phys_vars |> setVar(gun_anim__ammoInspectionIdleProgressVarId, 0.0)
    animchar |> animchar_reset() // hard reset morphing to start inspection animation from the beginning without any blending


[es(track=check_ammo_controller__state)]
def check_ammo_controller_track_state(evt : Event;
                                      eid aka actor_eid : EntityId;
                                      check_ammo_controller__ammoInspectionProgressIdleStart : float;
                                      check_ammo_controller__ammoInspectionProgressIdleEnd : float;
                                      check_ammo_controller__ammoInspectionProgressEnd : float;
                                      human_weap__currentGunEid : EntityId;
                                      check_ammo_controller__state : int;
                                      check_ammo_controller__ammoInspectionIdleProgress : float;
                                      var check_ammo_controller__ammoInspectionProgress : float&;
                                      var check_ammo_controller__ammoInspectionProgressInMarkStart : float&;
                                      var check_ammo_controller__ammoInspectionProgressRemovedAmmoMarkers : float2&;
                                      var check_ammo_controller__ammoInspectionInOutSpeed : float2&;
                                      var check_ammo_controller__ammoInspectionIdleSpeed : float&;
                                      var check_ammo_controller__gunEid : EntityId&)
  assume progressIdleStart = check_ammo_controller__ammoInspectionProgressIdleStart
  assume progressIdleEnd = check_ammo_controller__ammoInspectionProgressIdleEnd
  assume ammoInspectionProgress = check_ammo_controller__ammoInspectionProgress
  assume ammoInspectionProgressRemovedAmmoMarkers = check_ammo_controller__ammoInspectionProgressRemovedAmmoMarkers

  let prevAmmoInspectionProgress = ammoInspectionProgress

  if check_ammo_controller__state == CheckAmmoState.NONE
    ammoInspectionProgress = 0.0
  elif check_ammo_controller__state == CheckAmmoState.IN
    set_weapon_operation_state(int(GunOperationState.AMMO_INSPECTION), human_weap__currentGunEid)
    if ammoInspectionProgress >= check_ammo_controller__ammoInspectionProgressIdleStart
      ammoInspectionProgress = 0.0

    query(human_weap__currentGunEid) <| $ [es] (gun__ammoInspectionInOutDuration : float2 = float2(2.0);
                                                gun__ammoInspectionIdleLoopDuration : float = 10.0;
                                                gun__ammoInspectionInMarkStart : float = 0.6;
                                                gun__ammoInspectionProgressRemovedAmmoMarkers : float2 = float2(0.125, 2.5))
      check_ammo_controller__gunEid = human_weap__currentGunEid
      check_ammo_controller__ammoInspectionProgressInMarkStart = gun__ammoInspectionInMarkStart
      check_ammo_controller__ammoInspectionProgressRemovedAmmoMarkers = gun__ammoInspectionProgressRemovedAmmoMarkers
      check_ammo_controller__ammoInspectionInOutSpeed = float2(safeinv(gun__ammoInspectionInOutDuration.x),
                                                               safeinv(gun__ammoInspectionInOutDuration.y))
      check_ammo_controller__ammoInspectionIdleSpeed = safeinv(gun__ammoInspectionIdleLoopDuration)
  elif check_ammo_controller__state == CheckAmmoState.IDLE
    ammoInspectionProgress = (progressIdleStart + progressIdleEnd) * 0.5
  elif check_ammo_controller__state == CheckAmmoState.OUT
    if ammoInspectionProgress >= check_ammo_controller__ammoInspectionProgressIdleStart
      ammoInspectionProgress = progressIdleEnd
    else
      // In -> Out transition
      let inProgress = ammoInspectionProgress / check_ammo_controller__ammoInspectionProgressIdleStart
      let outProgress = 1.0 - inProgress
      let outLen = check_ammo_controller__ammoInspectionProgressEnd - check_ammo_controller__ammoInspectionProgressIdleEnd
      ammoInspectionProgress = check_ammo_controller__ammoInspectionProgressIdleEnd + outLen * outProgress
  elif (check_ammo_controller__state == CheckAmmoState.FINISHED ||
       check_ammo_controller__state == CheckAmmoState.INTERRUPTION)
    ammoInspectionProgress = check_ammo_controller__ammoInspectionProgressEnd
    reset_ammo_inspection_progress_to_gun(check_ammo_controller__gunEid)
    set_weapon_operation_state(int(GunOperationState.BOLTACTION), check_ammo_controller__gunEid)
    check_ammo_controller__gunEid = INVALID_ENTITY_ID

  check_removed_ammo_markers(actor_eid, prevAmmoInspectionProgress, ammoInspectionProgress, ammoInspectionProgressRemovedAmmoMarkers)

  set_ammo_inspection_progress_to_gun(check_ammo_controller__gunEid, ammoInspectionProgress, check_ammo_controller__ammoInspectionIdleProgress)


[es(tag=server, track=check_ammo_controller__state, after=check_ammo_controller_track_state)]
def check_ammo_controller_track_state_server(evt : Event;
                                             eid aka actor_eid : EntityId;
                                             check_ammo_controller__commonAffectTemplate : string;
                                             check_ammo_controller__input : bool;
                                             var check_ammo_controller__state : int&;
                                             var check_ammo_controller__commonAffectEid : EntityId&)
  let affectRequired = is_active_atate(check_ammo_controller__state)
  if affectRequired && check_ammo_controller__commonAffectEid == INVALID_ENTITY_ID
    check_ammo_controller__commonAffectEid = createEntity(check_ammo_controller__commonAffectTemplate) <| $(var init : ComponentsInitializer)
      init |> set("game_effect__attachedTo", actor_eid)
  elif !affectRequired && check_ammo_controller__commonAffectEid != INVALID_ENTITY_ID
    destroyEntity(check_ammo_controller__commonAffectEid)
    check_ammo_controller__commonAffectEid = INVALID_ENTITY_ID

  if check_ammo_controller__state == CheckAmmoState.IDLE && !check_ammo_controller__input
    check_ammo_controller__state = int(CheckAmmoState.OUT)
  elif check_ammo_controller__state == CheckAmmoState.INTERRUPTION
    check_ammo_controller__state = int(CheckAmmoState.FINISHED)


[es(tag=server)]
def check_ammo_controller_removed_ammo_marker(evt : EventCheckAmmoRemovedAmmoMarker;
                                              eid aka actor_eid : EntityId;
                                              check_ammo_controller__removedAmmoAffectTemplate : string;
                                              check_ammo_controller__ammoInspectionProgress : float;
                                              check_ammo_controller__ammoInspectionProgressRemovedAmmoMarkers : float2;
                                              var check_ammo_controller__removedAmmoAffectEid : EntityId&)
  assume ammoInspectionProgress = check_ammo_controller__ammoInspectionProgress
  assume ammoInspectionProgressRemovedAmmoMarkers = check_ammo_controller__ammoInspectionProgressRemovedAmmoMarkers

  let affectRequired = (ammoInspectionProgress >= ammoInspectionProgressRemovedAmmoMarkers.x &&
                       ammoInspectionProgress < ammoInspectionProgressRemovedAmmoMarkers.y)
  if affectRequired && check_ammo_controller__removedAmmoAffectEid == INVALID_ENTITY_ID
    check_ammo_controller__removedAmmoAffectEid = createEntity(check_ammo_controller__removedAmmoAffectTemplate) <| $(var init : ComponentsInitializer)
      init |> set("game_effect__attachedTo", actor_eid)
  elif !affectRequired && check_ammo_controller__removedAmmoAffectEid != INVALID_ENTITY_ID
    destroyEntity(check_ammo_controller__removedAmmoAffectEid)
    check_ammo_controller__removedAmmoAffectEid = INVALID_ENTITY_ID


def check_removed_ammo_markers(actor_eid : EntityId;
                               prev_ammo_inspection_progress : float;
                               ammo_inspection_progress : float;
                               ammo_inspection_progress_removed_ammo_markers : float2)
  if ((prev_ammo_inspection_progress < ammo_inspection_progress_removed_ammo_markers.x && ammo_inspection_progress >= ammo_inspection_progress_removed_ammo_markers.x) ||
      (prev_ammo_inspection_progress >= ammo_inspection_progress_removed_ammo_markers.x && ammo_inspection_progress < ammo_inspection_progress_removed_ammo_markers.x) ||
      (prev_ammo_inspection_progress < ammo_inspection_progress_removed_ammo_markers.y && ammo_inspection_progress >= ammo_inspection_progress_removed_ammo_markers.y) ||
      (prev_ammo_inspection_progress >= ammo_inspection_progress_removed_ammo_markers.y && ammo_inspection_progress < ammo_inspection_progress_removed_ammo_markers.y))
    sendEvent(actor_eid, EventCheckAmmoRemovedAmmoMarker())


[es(no_order)]
def check_ammo_controller_update(act : UpdateStageInfoAct;
                                 eid aka actor_eid : EntityId;
                                 check_ammo_controller__ammoInspectionInReverseMult : float = 1.25;
                                 check_ammo_controller__ammoInspectionInOutSpeed : float2;
                                 check_ammo_controller__ammoInspectionIdleSpeed : float;
                                 check_ammo_controller__ammoInspectionProgressIdleStart : float;
                                 check_ammo_controller__ammoInspectionProgressEnd : float;
                                 check_ammo_controller__ammoInspectionProgressIdleEnd : float;
                                 check_ammo_controller__ammoInspectionProgressInMarkStart : float;
                                 check_ammo_controller__ammoInspectionProgressRemovedAmmoMarkers : float2;
                                 check_ammo_controller__gunEid : EntityId;
                                 var check_ammo_controller__ammoInspectionProgress : float&;
                                 var check_ammo_controller__ammoInspectionIdleProgress : float&;
                                 var check_ammo_controller__state : int&)
  assume state = check_ammo_controller__state
  assume ammoInspectionProgress = check_ammo_controller__ammoInspectionProgress
  assume ammoInspectionIdleProgress = check_ammo_controller__ammoInspectionIdleProgress
  assume ammoInspectionInReverseMult = check_ammo_controller__ammoInspectionInReverseMult
  assume ammoInspectionInOutSpeed = check_ammo_controller__ammoInspectionInOutSpeed
  assume ammoInspectionProgressIdleStart = check_ammo_controller__ammoInspectionProgressIdleStart
  assume ammoInspectionProgressEnd = check_ammo_controller__ammoInspectionProgressEnd
  assume ammoInspectionProgressIdleEnd = check_ammo_controller__ammoInspectionProgressIdleEnd
  assume ammoInspectionProgressInMarkStart = check_ammo_controller__ammoInspectionProgressInMarkStart
  assume ammoInspectionProgressRemovedAmmoMarkers = check_ammo_controller__ammoInspectionProgressRemovedAmmoMarkers

  if !is_active_atate(state)
    return

  let prevAmmoInspectionProgress = ammoInspectionProgress

  if state == CheckAmmoState.IN
    if ammoInspectionProgress >= ammoInspectionProgressIdleEnd
      // Out -> In transition
      let outLen = ammoInspectionProgressEnd - ammoInspectionProgressIdleEnd
      var outProgress = ammoInspectionProgress - ammoInspectionProgressIdleEnd
      outProgress = outProgress / outLen
      let inProgress = 1.0 - outProgress
      ammoInspectionProgress = ammoInspectionProgressIdleStart * inProgress

    let ammoInspectionInSpeed = ammoInspectionInOutSpeed.x
    ammoInspectionProgress += act.dt * ammoInspectionInSpeed
    if ammoInspectionProgress >= ammoInspectionProgressIdleStart
      ammoInspectionProgress = ammoInspectionProgressIdleStart
      ammoInspectionIdleProgress = 0.0
      state = int(CheckAmmoState.IDLE)
    elif prevAmmoInspectionProgress < ammoInspectionProgressInMarkStart && ammoInspectionProgress >= ammoInspectionProgressInMarkStart
      sendEvent(eid, EventCheckAmmoInMark())

  elif state == CheckAmmoState.IN_REVERSE
    let speed = ammoInspectionInOutSpeed.x * check_ammo_controller__ammoInspectionInReverseMult
    ammoInspectionProgress -= act.dt * speed
    if ammoInspectionProgress <= 0.0
      ammoInspectionProgress = 0.0
      state = int(CheckAmmoState.NONE)
      set_weapon_operation_state(int(GunOperationState.BOLTACTION), check_ammo_controller__gunEid)
  elif state == CheckAmmoState.IDLE
    ammoInspectionIdleProgress += act.dt * check_ammo_controller__ammoInspectionIdleSpeed
  elif state == CheckAmmoState.OUT
    let ammoInspectionOutSpeed = ammoInspectionInOutSpeed.y
    ammoInspectionProgress += act.dt * ammoInspectionOutSpeed
    if ammoInspectionProgress >= ammoInspectionProgressEnd
      ammoInspectionProgress = ammoInspectionProgressEnd
      state = int(CheckAmmoState.FINISHED)

  check_removed_ammo_markers(actor_eid, prevAmmoInspectionProgress, ammoInspectionProgress, ammoInspectionProgressRemovedAmmoMarkers)

  set_ammo_inspection_progress_to_gun(check_ammo_controller__gunEid, ammoInspectionProgress, ammoInspectionIdleProgress)


def drop_gun_magazine_to_ground(actor_eid : EntityId;
                                weapon_eid : EntityId)
  var droppedMagazine = INVALID_ENTITY_ID
  var droppedTo = INVALID_ENTITY_ID
  query(weapon_eid) <| $ [es] (gun_mods__curModInSlots : Object; gun__owner : EntityId)
    for gunModInSlot in gun_mods__curModInSlots
      let gunModEid = get_Eid(gunModInSlot.value) ?? INVALID_ENTITY_ID
      if has(gunModEid, "ammo_holder__id")
        droppedMagazine = gunModEid
        droppedTo = get_inventory_for_item_by_volume(gun__owner, droppedMagazine)
        unequip_weapon_mod_from_slot(gunModInSlot.key, weapon_eid, actor_eid, droppedTo)
        break
  if !is_true_net_server() && has(actor_eid, "hero") && has(actor_eid, "uniqueId")
    query(droppedTo) <| $ [es] (uniqueId : string; profile_server__slotName : string)
      report_item_move_transaction(droppedMagazine, uniqueId, profile_server__slotName)


def process_brute_force_ammo_checking_interrupt(actor_eid : EntityId;
                                                check_ammo_controller__ammoInspectionProgress : float;
                                                check_ammo_controller__ammoInspectionProgressRemovedAmmoMarkers : float2;
                                                human_weap__currentGunEid : EntityId;
                                                var check_ammo_controller__state : int&)
  assume state = check_ammo_controller__state
  assume ammoInspectionProgress = check_ammo_controller__ammoInspectionProgress
  assume ammoInspectionProgressRemovedAmmoMarkers = check_ammo_controller__ammoInspectionProgressRemovedAmmoMarkers

  if !is_active_atate(state) || state == CheckAmmoState.INTERRUPTION
    return

  state = int(CheckAmmoState.INTERRUPTION)



  let isRemovedAmmo = (ammoInspectionProgress >= ammoInspectionProgressRemovedAmmoMarkers.x &&
                       ammoInspectionProgress < ammoInspectionProgressRemovedAmmoMarkers.y)

  if isRemovedAmmo && human_weap__currentGunEid != INVALID_ENTITY_ID
    drop_gun_magazine_to_ground(actor_eid, human_weap__currentGunEid)


[es(tag=server, track=isDowned)]
def check_ammo_controller_track_is_downed(evt : Event;
                                          eid aka actor_eid : EntityId;
                                          check_ammo_controller__ammoInspectionProgress : float;
                                          check_ammo_controller__ammoInspectionProgressRemovedAmmoMarkers : float2;
                                          human_weap__currentGunEid : EntityId;
                                          isDowned : bool;
                                          var check_ammo_controller__state : int&)
  if isDowned
    process_brute_force_ammo_checking_interrupt(actor_eid,
                                                check_ammo_controller__ammoInspectionProgress,
                                                check_ammo_controller__ammoInspectionProgressRemovedAmmoMarkers,
                                                human_weap__currentGunEid,
                                                check_ammo_controller__state)


[es(tag=server, track=fallen_state__isAlreadyFell)]
def check_ammo_controller_track_is_fallen(evt : Event;
                                          eid aka actor_eid : EntityId;
                                          check_ammo_controller__ammoInspectionProgress : float;
                                          check_ammo_controller__ammoInspectionProgressRemovedAmmoMarkers : float2;
                                          human_weap__currentGunEid : EntityId;
                                          fallen_state__isAlreadyFell : bool;
                                          var check_ammo_controller__state : int&)
  if fallen_state__isAlreadyFell
    process_brute_force_ammo_checking_interrupt(actor_eid,
                                                check_ammo_controller__ammoInspectionProgress,
                                                check_ammo_controller__ammoInspectionProgressRemovedAmmoMarkers,
                                                human_weap__currentGunEid,
                                                check_ammo_controller__state)


[es(tag=server)]
def check_ammo_controller_switch_weapon_started(evt : HumanSwitchWeaponStarted;
                                                eid aka actor_eid : EntityId;
                                                check_ammo_controller__ammoInspectionProgress : float;
                                                check_ammo_controller__ammoInspectionProgressRemovedAmmoMarkers : float2;
                                                human_weap__currentGunEid : EntityId;
                                                var check_ammo_controller__state : int&)
  process_brute_force_ammo_checking_interrupt(actor_eid,
                                              check_ammo_controller__ammoInspectionProgress,
                                              check_ammo_controller__ammoInspectionProgressRemovedAmmoMarkers,
                                              human_weap__currentGunEid,
                                              check_ammo_controller__state)