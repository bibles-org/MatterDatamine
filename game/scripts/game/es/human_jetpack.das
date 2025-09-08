require ecs
require game.events.events
require HumanPhys
require DngHuman
require GamePhys
require DagorMath
require math
require math.base


[es(before=before_net_phys_sync)]
def human_jetpack_detect_flight_mode_es(act : UpdateStageInfoAct;
                                        human_jetpack__enabled, isInVehicle : bool;
                                        human_jetpack__eid : EntityId;
                                        human_net_phys : HumanActor;
                                        var human_jetpack__flightMode : bool&;
                                        var human_jetpack__jumpingTime : float&;
                                        human_jetpack__throttleStartThreshold = 0.3;
                                        human_use_object__lockJetpackUse = false)
  if !human_jetpack__enabled || human_use_object__lockJetpackUse
    return

  query(human_jetpack__eid) <| $ [es] (jetpack__fuel, jetpack__fuelUse : float)
    assume curState = human_net_phys.phys.currentState
    let inconsistentStates = StateFlag.ST_CROUCH | StateFlag.ST_CRAWL | StateFlag.ST_DOWNED
    let inconsistentState = (uint(curState.states) & uint(inconsistentStates)) != 0u
    let isJumping = human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_JUMP)
    let isEnoughFuel = jetpack__fuel > 0.0 || jetpack__fuelUse == 0.0
    if isEnoughFuel && isJumping && !inconsistentState && !curState |> human_phys_state_get_isClimbing && !isInVehicle
      human_jetpack__jumpingTime += act.dt
      let fallingSpeedThreshold = -8.0
      if human_jetpack__jumpingTime > human_jetpack__throttleStartThreshold || curState.velocity.y < fallingSpeedThreshold
        human_jetpack__flightMode = true
    else
      human_jetpack__jumpingTime = 0.0
      let isInAir = (uint(curState.isInAirHistory) & 1u) != 0u && !curState |> human_phys_state_get_is_swimming() && !isInVehicle
      if !isInAir
        human_jetpack__flightMode = false


[es]
def human_jetpack_es(evt : CmdPostPhysUpdate;
                     human_jetpack__eid : EntityId;
                     human_jetpack__flightMode : bool;
                     human_jetpack__enabled : bool;
                     human_net_phys__isOnGround : bool;
                     var human_net_phys : HumanActor;
                     human_use_object__lockJetpackUse = false;
                     human_use_object__limitJetpackUse = false)
  if !human_jetpack__enabled || human_use_object__lockJetpackUse
    return

  query(human_jetpack__eid) <| $ [es] (jetpack__vertAccel : float;
                                       jetpack__horzAccel : float;
                                       jetpack__fuelUse : float;
                                       jetpack__smoothLanding : bool;
                                       jetpack__fuel : float;
                                       var jetpack__active : bool&;
                                       var jetpack__isInAir : bool&;
                                       jetpack__allowHeightControl = true;
                                       jetpack__heightCeiling = 350.0;
                                       jetpack__heigthCeilingTau = 0.5;
                                       jetpack__horzVertGravMult = 0.9;
                                       jetpack__forceLimitedMode = false;
                                       jetpack__startFromEarthVelocity = 3.5f;
                                       jetpack__airFriction = 0.0)
    let dt = evt.dt
    assume curState = human_net_phys.phys.currentState
    assume ct = human_net_phys.phys.appliedCT
    jetpack__isInAir = (int(curState.isInAirHistory) & 1) != 0 && !curState |> human_phys_state_get_is_swimming()
    jetpack__active = false
    let isHaveFuel = jetpack__fuel > 0.0
    let isDowned = curState |> human_phys_state_get_is_downed()
    let isLimitToLandingOnly = human_use_object__limitJetpackUse || isDowned || (!isHaveFuel && jetpack__fuelUse > 0.0) || jetpack__forceLimitedMode
    let isActivelyControlled = human_jetpack__flightMode && !isLimitToLandingOnly
    let isHeightIsActivelyControlled = jetpack__allowHeightControl && ct |> is_control_bit_set(HumanPhysControlType.HCT_JUMP)
    let dynAirPressure = length_sq(curState.velocity) * 0.5
    let airFric = jetpack__airFriction * dynAirPressure
    curState.velocity -= normalize(curState.velocity) * airFric * dt
    if human_net_phys__isOnGround && human_jetpack__flightMode
      curState.velocity.y = jetpack__startFromEarthVelocity
    if (isActivelyControlled && isHeightIsActivelyControlled) || jetpack__smoothLanding
      curState.velocity.y += jetpack__vertAccel * dt
      curState.isInAirHistory = uint8(int(curState.isInAirHistory) | 1)
      jetpack__active = true
      if human_phys_state_get_is_swimming(curState) && !human_phys_state_get_is_underwater(curState)
        var waterRiseBonus = .0
        find_query() <| $ [es] (water_level_change__lastActualSpeed : float)
          waterRiseBonus = max(.0, water_level_change__lastActualSpeed * dt)
          curState.velocity.y += max(.0, water_level_change__lastActualSpeed)
          return true
        var deltaFinalPos = curState.velocity * dt
        deltaFinalPos.y = max(deltaFinalPos.y, human_net_phys.phys.swimmingLevelBias) + waterRiseBonus
        curState.location.P = curState.location.P + DPoint3(deltaFinalPos)

    if isActivelyControlled && ct.walkSpeed > 0.0
      let walkDirX0Y = float3(ct.walkDir.x, 0.0, ct.walkDir.y)
      let orient = curState.location.O.quat
      let worldWalkDir = orient * walkDirX0Y
      let vertAcc = float3(0.f, gravity() * jetpack__horzVertGravMult * ct.walkSpeed, 0.f)
      let acc = worldWalkDir * ct.walkSpeed * jetpack__horzAccel + vertAcc
      curState.acceleration += acc
      curState.velocity += acc * dt
      jetpack__active = true

    let curHt = curState.location.P.y
    if float(curHt) > jetpack__heightCeiling && curState.velocity.y > 0.0
      curState.velocity.y = approach(curState.velocity.y, 0.0, dt, jetpack__heigthCeilingTau)


[es(tag=server, after=human_jetpack_es)]
def human_jetpack_es_fuel_consumption(evt : CmdPostPhysUpdate;
                                      human_jetpack__eid : EntityId;
                                      human_jetpack__enabled : bool;
                                      human_use_object__lockJetpackUse = false)
  if !human_jetpack__enabled || human_use_object__lockJetpackUse
    return

  query(human_jetpack__eid) <| $ [es] (jetpack__active : bool;
                                       jetpack__fuelUse : float;
                                       var jetpack__fuel : float&)
    if jetpack__active && jetpack__fuelUse > 0.0
      jetpack__fuel = max(jetpack__fuel - jetpack__fuelUse * evt.dt, 0.0)


[es(after=human_locomotion_es)]
def human_jetpack_locomotion_es(act : UpdateStageInfoAct;
                                human_net_phys : HumanActor;
                                human_jetpack__eid : EntityId;
                                human_jetpack__enabled : bool;
                                var prevLocoQuat : float4&;
                                var transform : float3x4&;
                                human_use_object__lockJetpackUse = false)
  if !human_jetpack__enabled || human_use_object__lockJetpackUse
    return

  let interpK = get_phys_interpk_clamped(human_net_phys.phys, act.curTime)
  let interpKV = float3(interpK, interpK, interpK)
  var acc = lerp(human_net_phys.phys.previousState.acceleration, human_net_phys.phys.currentState.acceleration, interpKV)
  query(human_jetpack__eid) <| $ [es] (jetpack__active : bool;
                                       jetpack__horzAccel : float;
                                       jetpack__locomotionFactor : float;
                                       jetpack__locomotionTau : float;
                                       jetpack__locomotionQuatTau : float;
                                       var jetpack__locoAcc : float3&;
                                       var jetpack__locoQuat : float4&)
    if !jetpack__active
      acc = float3()
    if acc |> length_sq() > square(jetpack__horzAccel)
      acc = acc |> normalize() * jetpack__horzAccel // renormalize
    acc = approach(jetpack__locoAcc, float3(acc.x, 0.0, acc.z), act.dt, jetpack__locomotionTau)
    let axis = float3(dot(transform[2], acc), 0.0, dot(-transform[0], acc)) // it's cross-product with 0, 1, 0
    let lenAxis = length(axis)
    var qDefl = quat(axis * safediv(1.0, lenAxis), lenAxis * jetpack__locomotionFactor)
    let f4Deft = float4(qDefl)
    qDefl = quat(normalize(approach(jetpack__locoQuat, f4Deft, act.dt, jetpack__locomotionQuatTau)))
    if (abs(f4Deft.w) < 1.0)
      var quatTm : float3x4
      make_tm(qDefl, quatTm)
      transform = transform * quatTm
    jetpack__locoAcc = acc
    jetpack__locoQuat = f4Deft
    prevLocoQuat += jetpack__locoQuat
