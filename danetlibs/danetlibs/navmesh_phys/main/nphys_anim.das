require ecs
require DngNet
require AnimV20
require DagorMath
require DagorSystem


// both on server and client, we need to initialize it on client, to reduce sync state
// we need it on server, so server _could_ use animations there
[es(on_appear)]
def nphys_init_move_anim_states(evt : Event; animchar : AnimcharBaseComponent; anim_state__animChannels : StringList;
                                phys_move_anim__tscaleParamName : string;
                                anim_state__standStateName, anim_state__walkStateName, anim_state__runStateName : StringList;
                                var anim_state__standState, anim_state__walkState, anim_state__runState : IntList;
                                var phys_move_anim__tscaleParamId : int&)
  let animGraph = animchar.animGraph
  if animGraph != null
    for i in iter_range(anim_state__animChannels)
      anim_state__standState |> push(*animGraph |> anim_graph_getStateIdx(string(anim_state__standStateName[i])))
      anim_state__walkState |> push(*animGraph |> anim_graph_getStateIdx(string(anim_state__walkStateName[i])))
      anim_state__runState |> push(*animGraph |> anim_graph_getStateIdx(string(anim_state__runStateName[i])))
  phys_move_anim__tscaleParamId = *animGraph |> anim_graph_getParamId(phys_move_anim__tscaleParamName, int(PT_ScalarParam))


// TODO: move speed thresholds to params
def setup_move_anim(speed : float;
                    navmesh_phys__maxWalkSpeed : float;
                    navmesh_phys__walkSpeedModifier : float;
                    stand, walk, run : IntList;
                    channels : StringList;
                    phys_move_anim__tscaleParamId : int;
                    phys_move_anim__runTimescale : float;
                    phys_move_anim__walkTimescale : float;
                    nPhys__animcharScale : float;
                    var animchar : AnimcharBaseComponent;
                    var animchar__animState : Object;
                    var animchar__animSpeed : float&;
                    var animchar__animStateDirty : bool&)
  let relSpeed = saturate(safediv(speed, navmesh_phys__maxWalkSpeed))
  var timescale = 1.0
  for channel, chIdx in channels, iter_range(channels)
    var state = stand[chIdx]
    if relSpeed > navmesh_phys__walkSpeedModifier * 1.1
      state = run[chIdx]
      timescale = phys_move_anim__runTimescale
    elif relSpeed > FLT_EPSILON
      state = walk[chIdx]
      timescale = phys_move_anim__walkTimescale

    let curSt = get_int(animchar__animState, string(channel)) ?? -1
    if curSt != state
      animchar__animState |> set(string(channel), state)
      animchar__animStateDirty = true

  if phys_move_anim__tscaleParamId != -1
    let animTScale = clamp(safediv(relSpeed, nPhys__animcharScale) * timescale, 0.1, 10.f)
    *animchar.animState |> anim_state_holder_setParam(phys_move_anim__tscaleParamId, animTScale)
  else
    let animTScale = clamp(safediv(speed, nPhys__animcharScale) * timescale, 0.1, 10.f)
    animchar__animSpeed = animTScale


[es(before=(anim_state_es, actions_es), REQUIRE_NOT=(animchar__actOnDemand, deadEntity, nphys__disabled))]
def navmesh_move_anim(act : UpdateStageInfoAct; animchar__updatable : bool;
                      navmesh_phys__maxWalkSpeed : float;
                      loc_snapshots__snapshotData : LocSnapshotsList;
                      anim_state__standState, anim_state__walkState, anim_state__runState : IntList;
                      anim_state__animChannels : StringList;
                      phys_move_anim__tscaleParamId : int;
                      phys_move_anim__runTimescale : float;
                      phys_move_anim__walkTimescale : float;
                      var animchar : AnimcharBaseComponent;
                      var animchar__animState : Object;
                      var animchar__animSpeed : float&;
                      var animchar__animStateDirty : bool&;
                      navmesh_phys__walkSpeedModifier = 0.5;
                      nPhys__animcharScale : float = 1.0)
  if !animchar__updatable
    return

  var speed = 0f
  let n = length(loc_snapshots__snapshotData)
  if n >= 2
    let begin = loc_snapshots__snapshotData[0].pos
    let end = loc_snapshots__snapshotData[n - 1].pos
    let time = loc_snapshots__snapshotData[n - 1].atTime - loc_snapshots__snapshotData[0].atTime
    let vel = (end - begin) / time
    speed = length(vel)

  setup_move_anim(speed,
                  navmesh_phys__maxWalkSpeed,
                  navmesh_phys__walkSpeedModifier,
                  anim_state__standState,
                  anim_state__walkState,
                  anim_state__runState,
                  anim_state__animChannels,
                  phys_move_anim__tscaleParamId,
                  phys_move_anim__runTimescale,
                  phys_move_anim__walkTimescale,
                  nPhys__animcharScale,
                  animchar,
                  animchar__animState,
                  animchar__animSpeed,
                  animchar__animStateDirty)


[es(tag=render, before=(anim_state_es, actions_es),
    REQUIRE_NOT=(loc_snapshots__snapshotData, animchar__actOnDemand, deadEntity, animchar__lockAnimStateChange, nphys__disabled))]
def navmesh_move_offline_anim(act : UpdateStageInfoAct; animchar__updatable : bool;
                              navmesh_phys__currentWalkVelocity : float3;
                              anim_state__standState, anim_state__walkState, anim_state__runState : IntList;
                              anim_state__animChannels : StringList;
                              navmesh_phys__maxWalkSpeed : float;
                              phys_move_anim__tscaleParamId : int;
                              phys_move_anim__runTimescale : float;
                              phys_move_anim__walkTimescale : float;
                              var animchar : AnimcharBaseComponent;
                              var animchar__animState : Object;
                              var animchar__animSpeed : float&;
                              var animchar__animStateDirty : bool&;
                              navmesh_phys__walkSpeedModifier = 0.5;
                              nPhys__animcharScale : float = 1.0)
  if animchar__updatable
    let speed = length(navmesh_phys__currentWalkVelocity)
    setup_move_anim(speed,
                    navmesh_phys__maxWalkSpeed,
                    navmesh_phys__walkSpeedModifier,
                    anim_state__standState,
                    anim_state__walkState,
                    anim_state__runState,
                    anim_state__animChannels,
                    phys_move_anim__tscaleParamId,
                    phys_move_anim__runTimescale,
                    phys_move_anim__walkTimescale,
                    nPhys__animcharScale,
                    animchar,
                    animchar__animState,
                    animchar__animSpeed,
                    animchar__animStateDirty)


[es(on_appear)]
def nphys_init_rotate_anim_states(evt : Event; animchar : AnimcharBaseComponent;
                                  anim_state__rotateLeftName, anim_state__rotateRightName : string;
                                  var anim_state__rotateLeftState, anim_state__rotateRightState : int&)
  let animGraph = animchar.animGraph
  if animGraph != null
    anim_state__rotateLeftState = *animGraph |> anim_graph_getStateIdx(anim_state__rotateLeftName)
    anim_state__rotateRightState = *animGraph |> anim_graph_getStateIdx(anim_state__rotateRightName)



def setup_rotate_anim(move_speed : float;
                      move_speed_threshold : float;
                      angular_speed : float;
                      angular_speed_threshold : float;
                      rotate_left, rotate_right : int;
                      channels : StringList;
                      var animchar__animState : Object;
                      var animchar__animStateDirty : bool&)
  if move_speed > move_speed_threshold
    return false
  var state = -1
  if angular_speed > angular_speed_threshold
    state = rotate_right
  elif angular_speed < -angular_speed_threshold
    state = rotate_left
  if state != -1
    for channel in channels
      let curSt = get_int(animchar__animState, string(channel)) ?? -1
      if curSt != state
        animchar__animState |> set(string(channel), state)
        animchar__animStateDirty = true
    return true
  return false


[es(before=(anim_state_es, actions_es), after=navmesh_move_anim, REQUIRE_NOT=(animchar__actOnDemand, deadEntity, nphys__disabled))]
def navmesh_rotate_anim(act : UpdateStageInfoAct;
                        animchar__updatable : bool;
                        loc_snapshots__snapshotData : LocSnapshotsList;
                        anim_state__rotateLeftState, anim_state__rotateRightState : int;
                        anim_state__animChannels : StringList;
                        animchar__rotationAnimMoveSpeedThreshold : float;
                        animchar__rotationAnimAngularSpeedThreshold : float;
                        nPhys__animcharScale : float = 1.0;
                        var animchar__animState : Object;
                        var animchar__animSpeed : float&;
                        var animchar__animStateDirty : bool&)
  if !animchar__updatable
    return

  var lookDirAngularSpeed = float3()
  var speed = 0.0
  let n = length(loc_snapshots__snapshotData)
  if n >= 2
    let begin = loc_snapshots__snapshotData[0].pos
    let end = loc_snapshots__snapshotData[n - 1].pos
    let beginRot = loc_snapshots__snapshotData[0].quat
    let endRot = loc_snapshots__snapshotData[n - 1].quat
    let time = loc_snapshots__snapshotData[n - 1].atTime - loc_snapshots__snapshotData[0].atTime

    let lookQuatDelta = endRot * inverse(beginRot)
    var lookDirDelta : float3
    quat_to_euler(lookQuatDelta, lookDirDelta.y, lookDirDelta.z, lookDirDelta.x)
    lookDirAngularSpeed = lookDirDelta / time

    let vel = (end - begin) / time
    speed = length(vel)

  if setup_rotate_anim(speed,
                       animchar__rotationAnimMoveSpeedThreshold,
                       lookDirAngularSpeed.y,
                       animchar__rotationAnimAngularSpeedThreshold,
                       anim_state__rotateLeftState,
                       anim_state__rotateRightState,
                       anim_state__animChannels,
                       animchar__animState,
                       animchar__animStateDirty)
    animchar__animSpeed = clamp(safediv(abs(lookDirAngularSpeed.y), nPhys__animcharScale), 0.5, 10.0)


[es(tag=render, before=(anim_state_es, actions_es), after=navmesh_move_offline_anim,
    REQUIRE_NOT=(loc_snapshots__snapshotData, animchar__actOnDemand, deadEntity, animchar__lockAnimStateChange, nphys__disabled))]
def navmesh_rotate_offline_anim(act : UpdateStageInfoAct;
                                animchar__updatable : bool;
                                anim_state__rotateLeftState, anim_state__rotateRightState : int;
                                anim_state__animChannels : StringList;
                                navmesh_phys__lookDirAngularSpeed : float3;
                                navmesh_phys__currentWalkVelocity : float3;
                                animchar__rotationAnimMoveSpeedThreshold : float;
                                animchar__rotationAnimAngularSpeedThreshold : float;
                                nPhys__animcharScale : float = 1.0;
                                var animchar__animSpeed : float&;
                                var animchar__animState : Object;
                                var animchar__animStateDirty : bool&)
  if animchar__updatable
    let speed = length(navmesh_phys__currentWalkVelocity)
    if setup_rotate_anim(speed,
                         animchar__rotationAnimMoveSpeedThreshold,
                         navmesh_phys__lookDirAngularSpeed.y,
                         animchar__rotationAnimAngularSpeedThreshold,
                         anim_state__rotateLeftState,
                         anim_state__rotateRightState,
                         anim_state__animChannels,
                         animchar__animState,
                         animchar__animStateDirty)
      animchar__animSpeed = clamp(safediv(abs(navmesh_phys__lookDirAngularSpeed.y), nPhys__animcharScale), 0.5, 10.0)
