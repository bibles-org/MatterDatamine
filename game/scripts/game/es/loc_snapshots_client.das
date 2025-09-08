require app
require ecs
require ecs.common
require math.base
require BitStream
require DngNet
require DagorMath
require game.events.events_active_matter
require game.es.loc_snapshots_common
require debug.logerr_once


[es(tag=gameClient, REQUIRE=eid)]
def receive_targeted_snapshot(evt : TransformSnapshotsTargeted; hero_awareness__rateStep : float; @shared_comp hero_awareness__rates : IntList const?)
  read_and_add_snapshots(*evt.data, hero_awareness__rateStep, hero_awareness__rates)


[es(tag=gameClient, no_order, REQUIRE_NOT=loc_snaphots__disabled)] //move into receiving snapshots?
def clean_up_loc_snapshots(act : UpdateStageInfoAct;
                           var loc_snapshots__snapshotData : LocSnapshotsList;
                           loc_snapshots__timeOffset : float;
                           loc_snapshots__isInExtrapolation : bool;
                           loc_snapshots__extrapolationCursor : float)
  let cuttOffTime = act.curTime - loc_snapshots__timeOffset
  var idx = length(loc_snapshots__snapshotData) - 2
  var eraseNext = false
  while idx-- > 0
    if (loc_snapshots__snapshotData[idx].atTime >= cuttOffTime ||
        (loc_snapshots__isInExtrapolation && loc_snapshots__snapshotData[idx].atTime >= loc_snapshots__extrapolationCursor))
      continue
    if eraseNext
      erase(loc_snapshots__snapshotData, idx)
    eraseNext = true


[es(tag=(gameClient, net), REQUIRE_NOT=(loc_snapshots__dontUpdate, loc_snaphots__disabled), before=before_animchar_update_sync)]
def apply_transform_from_snapshots(act : UpdateStageInfoAct;
                                   eid : EntityId;
                                   loc_snapshots__snapshotData : LocSnapshotsList;
                                   loc_snapshots__compensationSpeed : float2;
                                   loc_snapshots__maxTimeSpeedAdjustment : float = 1.6;
                                   loc_snapshots__hideDelay : float = 3.0;
                                   loc_snapshots__timeOffsetMult : float = 1.1;
                                   loc_snapshots__timeOffsetFlat : float = 0.06;
                                   loc_snapshots__maxExtrapolation : float = 0.5;
                                   var loc_snapshots__isInExtrapolation : bool&;
                                   var loc_snapshots__extrapolationCursor : float&;
                                   var loc_snapshots__extrapolationDiscrepancy : float3&;
                                   var loc_snapshots__targetTimeOffset : float&;
                                   var loc_snapshots__timeOffset : float&;
                                   var loc_snapshots__lastSnapTime : float&;
                                   var transform : float3x4;
                                   var alt_transform : float3x4?)
  assume working_tm = alt_transform != null ? *alt_transform : transform
  if length(loc_snapshots__snapshotData) == 0
    // we don't have any snapshots for this entity - hide it
    transform[3] = get_hidden_pos()
    return

  let snapCount = length(loc_snapshots__snapshotData)
  assume lastSnapshot = loc_snapshots__snapshotData[snapCount - 1]
  let lastSnapTime = lastSnapshot.atTime
  if act.curTime - lastSnapTime - loc_snapshots__hideDelay - loc_snapshots__targetTimeOffset > 0.0
    // the target is probably beyond our range, we no longer receive info about it -> hide it
    transform[3] = get_hidden_pos()
    return

  if snapCount == 1
    // we have only one snapshot - just use it for position
    make_tm(lastSnapshot.quat, lastSnapshot.pos, transform)
    if lastSnapshot.interval > .0
      loc_snapshots__targetTimeOffset = lastSnapshot.interval
      loc_snapshots__timeOffset = loc_snapshots__targetTimeOffset
    return

  if lastSnapshot.interval > .0
    loc_snapshots__targetTimeOffset = lastSnapshot.interval * loc_snapshots__timeOffsetMult + loc_snapshots__timeOffsetFlat

  let timeOffsetDelta = loc_snapshots__targetTimeOffset - loc_snapshots__timeOffset
  if timeOffsetDelta > .0
    loc_snapshots__timeOffset += min(timeOffsetDelta, act.dt / loc_snapshots__maxTimeSpeedAdjustment)
  else
    loc_snapshots__timeOffset -= min(-timeOffsetDelta, act.dt / loc_snapshots__maxTimeSpeedAdjustment)

  let interpTime = act.curTime - loc_snapshots__timeOffset
  var idx = snapCount
  var extrapolate = false
  //we must extrapolate from the latest pos,
  //but we may use earlier snaps for velocity if the last snap is blink
  //hence we have velocitySnap and lastSnap
  var extrapolationSnapIdx = -1
  while idx-- > 0
    if loc_snapshots__snapshotData[idx].atTime > interpTime
      continue
    if (extrapolate || idx == snapCount - 1) && idx > 0 //All snapshots are behind. Extrapolation.
      extrapolate = true
      assume velocitySnap1 = loc_snapshots__snapshotData[idx - 1] //<- before
      assume velocitySnap2 = loc_snapshots__snapshotData[idx] //<- after
      assume lastSnap1 = loc_snapshots__snapshotData[extrapolationSnapIdx - 1]
      assume lastSnap2 = loc_snapshots__snapshotData[extrapolationSnapIdx]
      if velocitySnap2.atTime == velocitySnap1.atTime
        continue
      if extrapolationSnapIdx == -1
        extrapolationSnapIdx = idx //this will be the last snap as the origin for extrapolation
      if velocitySnap2.blink //but we want to find the last non-blink snap
        continue
      let snapDeltaT = velocitySnap2.atTime - velocitySnap1.atTime
      let timeFromSnap1 = min(loc_snapshots__maxExtrapolation + snapDeltaT, interpTime - lastSnap1.atTime)
      let interpK = timeFromSnap1 / snapDeltaT
      let predictedPos = lerp(lastSnap2.pos, lastSnap2.pos + velocitySnap2.pos - velocitySnap1.pos, float3(interpK - 1.0))
      var blinkFromTm : float3x4
      var sendBlinkEvent = false

      var thisVelocity = float3()
      if velocitySnap1.atTime != loc_snapshots__extrapolationCursor && loc_snapshots__isInExtrapolation
        //Rebase onto a new pair of snapshots for extrapolation
        var idxLast = idx
        while idxLast-- > 0
          if loc_snapshots__snapshotData[idxLast].atTime != loc_snapshots__extrapolationCursor
            continue
          thisVelocity = (velocitySnap2.pos - velocitySnap1.pos) / snapDeltaT
          loc_snapshots__extrapolationDiscrepancy = working_tm[3] - predictedPos
          break
      if lastSnap2.blink && loc_snapshots__lastSnapTime < lastSnap2.atTime //Only send one event per snapshot
        blinkFromTm := working_tm
        sendBlinkEvent = true
        loc_snapshots__extrapolationDiscrepancy = float3()
      elif loc_snapshots__extrapolationDiscrepancy != float3()
        compensate_discrepancy(loc_snapshots__extrapolationDiscrepancy, thisVelocity, loc_snapshots__compensationSpeed, act.dt)
      make_tm(slerp(lastSnap1.quat, lastSnap2.quat, interpK), predictedPos + loc_snapshots__extrapolationDiscrepancy, working_tm)
      loc_snapshots__isInExtrapolation = true
      loc_snapshots__extrapolationCursor = velocitySnap1.atTime
      loc_snapshots__lastSnapTime = lastSnap2.atTime
      if sendBlinkEvent
        sendEvent(eid, EventSnapshotBlink(from = blinkFromTm, to = transform, dt = lastSnap2.atTime - lastSnap1.atTime))
      break
    else //Interpolation
      assume curSnap = loc_snapshots__snapshotData[idx] //<- before
      assume nextSnap = loc_snapshots__snapshotData[idx + 1] //<- after
      let interpK = nextSnap.blink ? 1.0 : cvt(interpTime, curSnap.atTime, nextSnap.atTime, 0.f, 1.f)
      let interpPos = lerp(curSnap.pos, nextSnap.pos, float3(interpK))
      if loc_snapshots__isInExtrapolation
        loc_snapshots__extrapolationDiscrepancy = working_tm[3] - interpPos
      if loc_snapshots__extrapolationDiscrepancy != float3()
        let thisVelocity = (nextSnap.pos - curSnap.pos) / (nextSnap.atTime - curSnap.atTime)
        compensate_discrepancy(loc_snapshots__extrapolationDiscrepancy, thisVelocity, loc_snapshots__compensationSpeed, act.dt)
      make_tm(slerp(curSnap.quat, nextSnap.quat, interpK), interpPos + loc_snapshots__extrapolationDiscrepancy, working_tm)
      if nextSnap.blink && loc_snapshots__lastSnapTime < nextSnap.atTime //Only send one event per snapshot
        var tm : float3x4
        make_tm(curSnap.quat, curSnap.pos, tm)
        sendEvent(eid, EventSnapshotBlink(from = tm, to = transform, dt = nextSnap.atTime - curSnap.atTime))
      loc_snapshots__isInExtrapolation = false
      loc_snapshots__lastSnapTime = nextSnap.atTime
      break
  if loc_snapshots__compensationSpeed.x == .0 || loc_snapshots__compensationSpeed.y == .0
    logerr_once("<{eid}>({getEntityTemplateName(eid)}) loc_snapshots__compensationSpeed is 0. This means that it will accumulate network error. Set it to some % of it's maximum speed (i.e. 40% * max_speed and 140% * max_speed)")


//No compensation for orientation. It seems to be unnoticable anyway.
def compensate_discrepancy(var discrepancy : float3&; velocity : float3; co_speed : float2; dt : float)
  let discrepancyLen = length(discrepancy)
  if discrepancyLen > 8.0 //below 9 which is server-side hit tolerance, this should be a constant somewhere...
    // discrepancyLen > 8.0 most often this is because the creature was in the hidden pos
    discrepancy = float3()
    return

  var compensationMult : float
  // Calculate copmensation so that length(velocity + copmensation) = co_speed.y
  let compensationV = -discrepancy / discrepancyLen
  let a = length_sq(discrepancy)
  let b = 2.0 * (velocity.x * compensationV.x + velocity.y * compensationV.y + velocity.z * compensationV.z)
  let c = length_sq(velocity) - square(co_speed.y)
  let d = square(b) - 4.0 * a * c
  if d < .0 || a < FLT_EPSILON
    compensationMult = co_speed.x
  else
    compensationMult = (-b + sqrt(d)) / 2.0 / a
  compensationMult = clamp(compensationMult, co_speed.x, co_speed.y)
  let compansatedDelta = dt * compensationMult
  discrepancy = discrepancyLen <= compansatedDelta ? float3() : discrepancy + compensationV * compansatedDelta


//TODO: same thing ust be done if the snapshots are too old
[es(tag=(gameClient, net), on_disappear, REQUIRE=loc_snaphots__disabled)]
def ensure_initial_snapshots_for_enabled_agents(evt : Event; transform : float3x4; var loc_snapshots__snapshotData : LocSnapshotsList)
  if length(loc_snapshots__snapshotData) < 2
    using() <| $(var snap : LocSnapshot#)
      snap.pos = transform[3]
      snap.atTime = get_sync_time() - 0.1
      snap.quat = DagorMath::quat(transform)
      loc_snapshots__snapshotData |> push(clone_to_move(snap))
    if length(loc_snapshots__snapshotData) < 2
      using() <| $(var snap : LocSnapshot#)
        snap.pos = transform[3]
        snap.atTime = get_sync_time() - 0.01
        snap.quat = DagorMath::quat(transform)
        loc_snapshots__snapshotData |> push(clone_to_move(snap))


[es(tag=gameClient, on_appear)]
def init_min_compensation_speed_for_navmesh_creature(evt : Event;
                                                     navmesh_phys__maxWalkSpeed : float;
                                                     loc_snapshots__compensationSpeedMult = float2(0.4, 1.4);  //min, max
                                                     var loc_snapshots__compensationSpeed : float2&)
  loc_snapshots__compensationSpeed = loc_snapshots__compensationSpeedMult * navmesh_phys__maxWalkSpeed