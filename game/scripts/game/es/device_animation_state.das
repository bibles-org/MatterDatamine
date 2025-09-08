require ecs
require app
require PhysVars
require DngHumanAnim
require game.es.device_state_common
require game.events.events_active_matter
require DngHuman
require HumanPhys
require AnimV20
require AnimatedPhys
require game.events.events
require game.es.device_animation_common

[es(track=human_weap__currentGunSlot)]
def device_animation_check_unequipped(evt : Event; human_weap__currentGunSlot : int; human_net_phys : HumanActor; human_weap__gunEids : ecs::EidList)
  let curState = human_net_phys.phys.currentState.weapEquipState.curState
  if curState != HUWeaponEquipState.EES_EQUIPED
    return
  let curSlot = human_weap__currentGunSlot
  for slot, weapEid in iter_range(human_weap__gunEids), human_weap__gunEids
    if slot == curSlot
      continue
    query(weapEid) <| $ [es] (var phys_vars : PhysVars;
                              var device_anim__state : int&;
                              var device_anim__progress : float&;
                              device_anim__stateVarId : int;
                              device_anim__progressVarId : int;
                              device_anim__states : ecs::IntList)
      set_backpack_state(phys_vars, device_anim__state, device_anim__progress, device_anim__stateVarId, device_anim__progressVarId, device_anim__states, 0.0)

[es(no_order)]
def device_animation_equip(info : ParallelUpdateFrameDelayed;
                           human_weap__gunEids : ecs::EidList;
                           human_anim : HumanAnimCtx;
                           human_net_phys : HumanActor;
                           phys_vars : PhysVars)
  let prevState = human_net_phys.phys.previousState.weapEquipState.curState
  let curState = human_net_phys.phys.currentState.weapEquipState.curState
  let curSlot = int(human_net_phys.phys.currentState.weapEquipState.curSlot)
  let nextSlot = int(human_net_phys.phys.currentState.weapEquipState.nextSlot)

  let progress = 1.0 - getVar(phys_vars, human_anim.changeWeaponVarId)

  ecs::query(human_weap__gunEids[nextSlot]) <| $ [es] (var phys_vars : PhysVars;
                                                       var device_anim__state : int&;
                                                       var device_anim__progress : float&;
                                                       device_anim__stateVarId : int;
                                                       device_anim__progressVarId : int;
                                                       device_anim__states : ecs::IntList)
    if curState == HUWeaponEquipState.EES_EQUIPING
      set_backpack_state(phys_vars, device_anim__state, device_anim__progress, device_anim__stateVarId, device_anim__progressVarId, device_anim__states, progress)

  ecs::query(human_weap__gunEids[curSlot]) <| $ [es] (var phys_vars : PhysVars;
                                                      var device_anim__state : int&;
                                                      var device_anim__progress : float&;
                                                      var animchar : AnimcharBaseComponent;
                                                      human_gun_attached : bool;
                                                      device_anim__stateVarId : int;
                                                      device_anim__progressVarId : int;
                                                      device_anim__states : ecs::IntList)
    if curState == HUWeaponEquipState.EES_HOLSTERING
      set_backpack_state(phys_vars, device_anim__state, device_anim__progress, device_anim__stateVarId, device_anim__progressVarId, device_anim__states, progress)
    elif prevState == HUWeaponEquipState.EES_HOLSTERING
      set_backpack_state(phys_vars, device_anim__state, device_anim__progress, device_anim__stateVarId, device_anim__progressVarId, device_anim__states, 0.0)
    elif curState == HUWeaponEquipState.EES_EQUIPED && prevState != HUWeaponEquipState.EES_EQUIPED
      set_backpack_state(phys_vars, device_anim__state, device_anim__progress, device_anim__stateVarId, device_anim__progressVarId, device_anim__states, 1.0)
    if !human_gun_attached
      animchar_act(animchar, 0.0, true)

[es(no_order)]
def device_animation(act : ParallelUpdateFrameDelayed;
                     human_weap__gunEids : ecs::EidList;
                     human_weap__currentGunSlot : int;
                     human_net_phys : HumanActor;
                     device_anim__stateVarId aka human_device_anim__stateVarId : int;
                     device_anim__progressVarId aka human_device_anim__progressVarId : int;
                     device_anim__states aka human_device_anim__states : ecs::IntList;
                     isTpsView : bool = false;
                     var device_anim__state aka human_device_anim__state : int&;
                     var device_anim__progress aka human_device_anim__progress : float&;
                     var phys_vars aka human_phys_vars : PhysVars)

  let curState = human_net_phys.phys.currentState.weapEquipState.curState
  if curState != HUWeaponEquipState.EES_EQUIPED
    return

  if human_weap__currentGunSlot < 0
    return

  let weapEid = human_weap__gunEids[human_weap__currentGunSlot]
  query(weapEid) <| $ [es] (eid : EntityId;
                            device_anim__stateVarId : int;
                            device_anim__progressVarId : int;
                            device_anim__states : ecs::IntList;
                            device_animation__prepareTime : float;
                            device_animation__loopTime : float;
                            device_animation__firePrepareTime : float;
                            device_animation__firePostTime : float;
                            device_animation__postTime : float;
                            device_animation__startAt : float;
                            device_animation__endAt : float;
                            device_anim__isFpvVarId : int = -1;
                            var device_anim__state : int&;
                            var device_anim__progress : float&;
                            var device_animation__fireAt : float&;
                            var device_animation__isActive : bool&;
                            var phys_vars : PhysVars)
    let atTime = get_sync_time()
    var progress = 1.0
    var state = DeviceAnimState.DEVICE_STATE_DISABLED
    if device_animation__isActive
      let loopStart = device_animation__startAt + device_animation__prepareTime
      if device_animation__endAt > device_animation__startAt && atTime > device_animation__endAt
        device_animation__isActive = post_state(atTime, device_animation__postTime, device_animation__endAt, progress, state)
      elif atTime < loopStart
        prepare_state(atTime, loopStart, device_animation__startAt, progress, state)
      elif device_animation__fireAt > device_animation__startAt && atTime > device_animation__fireAt
        if fire_state(atTime, act.dt, device_animation__firePrepareTime, device_animation__firePostTime,
                      device_animation__fireAt, progress, state)
          sendEvent(eid, EventOnDeviceShoot())
      else
        use_state(atTime, loopStart, device_animation__loopTime, progress, state)

    set_device_state(human_phys_vars, human_device_anim__state, human_device_anim__progress, human_device_anim__stateVarId,
                     human_device_anim__progressVarId, human_device_anim__states, state, progress)
    set_device_state(phys_vars, device_anim__state, device_anim__progress, device_anim__stateVarId, device_anim__progressVarId, device_anim__states, state, progress)
    if device_anim__isFpvVarId >= 0
      setVar(phys_vars, device_anim__isFpvVarId, isTpsView ? 0.0 : 1.0)

[es(tag=gameClient, track=human_gun_attached)]
def device_anim_unequipped_animchar_update(evt : Event;
                                           device_anim__stateVarId : int;
                                           device_anim__progressVarId : int;
                                           device_anim__states : IntList;
                                           human_gun_attached : bool;
                                           var device_anim__state : int&;
                                           var device_anim__progress : float&;
                                           var phys_vars : PhysVars;
                                           var animchar : AnimcharBaseComponent;
                                           var anim_phys : AnimatedPhys;
                                           var device_animation__isActive : bool&)
  if !human_gun_attached
    set_backpack_state(phys_vars, device_anim__state, device_anim__progress, device_anim__stateVarId, device_anim__progressVarId, device_anim__states, 0.0)
    device_animation__isActive = false
    anim_phys_update(anim_phys, animchar, phys_vars)
    animchar_act(animchar, 0.01, true)
