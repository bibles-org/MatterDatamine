module ladder_common shared
require ecs
require net
require math.ang
require math.base
require gameObject
require GamePhys
require DagorMath
require DagorMathUtils
require DngHuman
require DagorSystem
require HumanPhys
require Dacoll
require Grid
require game.events.events_active_matter


def check_door(transform aka marker_transform : float3x4)
  return is_entity_found_in_grid(ecs_hash("doors"), BSphere3(marker_transform[3], 1.0), GridEntCheck.BOUNDING)


def check_trace(transform : float3x4;
                marker_trace_dist : float)
  var pos = transform[3]
  let dir = transform[1]
  pos -= dir * marker_trace_dist / 2.
  return !rayhit_normalized(pos, dir, marker_trace_dist, ETF_DEFAULT, -1)


def check_visible(from_pos : float3;
                  to_pos : float3;
                  look_trace_dist : float = 2.0f;
                  look_offset : float = 0.2f)
  let dir = normalize(to_pos - from_pos)
  let dist = clamp(length(to_pos - from_pos) - look_offset, 0.0, look_trace_dist)
  return !rayhit_normalized(from_pos, dir, dist, ETF_DEFAULT, -1)


def private check_line_intersects_ident_bbox(p1, p2 : float3)
  if ((p1.x > 0.5 && p2.x > 0.5) || (p1.x < -0.5 && p2.x < -0.5) ||
    (p1.y > 0.5 && p2.y > 0.5) || (p1.y < -0.5 && p2.y < -0.5) ||
    (p1.z > 0.5 && p2.z > 0.5) || (p1.z < -0.5 && p2.z < -0.5))
    return false

  if ((p1.x < -0.5 && p2.x > -0.5) || (p1.x > -0.5 && p2.x < -0.5) ||
     (p1.x < 0.5 && p2.x > 0.5) || (p1.x > 0.5 && p2.x < 0.5))
    return true
  if ((p1.y < -0.5 && p2.y > -0.5) || (p1.y > -0.5 && p2.y < -0.5) ||
     (p1.y < 0.5 && p2.y > 0.5) || (p1.y > 0.5 && p2.y < 0.5))
    return true
  if ((p1.z < -0.5 && p2.z > -0.5) || (p1.z > -0.5 && p2.z < -0.5) ||
     (p1.z < 0.5 && p2.z > 0.5) || (p1.z > 0.5 && p2.z < 0.5))
    return true

  return false


def in_front_of_ladder(human_net_phys : HumanActor;
                       ladder_tm : float3x4;
                       close_dist : float;
                       close_angle : float)
  assume heroPos = float3(human_net_phys.phys.currentState.location.P)
  assume velocity = human_net_phys.phys.currentState.velocity
  let lookDir = normalize(human_net_phys.phys.appliedCT.wishLookDir)
  let ladderUp = normalize(ladder_tm[1])
  let ladderForward = normalize(-ladder_tm[0])
  let angle_x = rad_to_deg(angle_xz(lookDir, ladderForward, ladderUp))
  let human2ladder = ladder_tm[3] - heroPos
  let toLadderDir = basis_aware_x0z(human2ladder, ladderUp)
  let horShift = length(ladder_tm[0]) * 2f + human_net_phys.phys.collRad
  let moveToLadder = human_net_phys.phys.appliedCT.walkDir.x * human_net_phys.phys.appliedCT.walkSpeed > 0f
  return (length(toLadderDir) < close_dist + horShift && moveToLadder &&
          abs(angle_x) < close_angle)


def find_gobj_or_entity_ladder(from : float3;
                               to : float3;
                               var out_ladder_tm : float3x4;
                               var out_ladder_steps : int&)
  // Find game object ladder
  if find_ladder(from, to, out_ladder_tm, out_ladder_steps)
    return true

  // Find entity ladder
  let dirDelta = to - from
  let dirLenSq = length_sq(dirDelta)
  if dirLenSq >= square(1e-6)
    let dirLen = sqrt(dirLenSq)
    let dir = dirDelta / dirLen
    let t = dirLen

    let maxLadderBBoxRadius = 20.0

    var ladderFound = false
    for_each_entity_in_grid(ecs_hash("ladders"), from, dir, t, /*radius*/ maxLadderBBoxRadius, GridEntCheck.POS) <| $(eid : EntityId)
      query(eid) <| $ [es] (transform : float3x4;
                            ladder__tm : float3x4;
                            ladder__steps : int)
        let tm = transform * ladder__tm
        let itm = inverse(tm)
        let localFrom = itm * from
        let localTo = itm * to
        if check_line_intersects_ident_bbox(localFrom, localTo)
          out_ladder_tm = tm
          out_ladder_steps = ladder__steps
          ladderFound = true
    if ladderFound
      return true

  return false


def get_near_ladder(human_net_phys : HumanActor;
                    var near_ladder_tm : float3x4&;
                    var is_descent : bool&;
                    ladder_trace_pos : float3;
                    swim_ladder_trace_pos : float3;
                    ladder_trace_dist : float;
                    marker_check_dist : float;
                    marker_observe_angle : float)
  var nearToLadder = false
  is_descent = false

  let canClimbLadders = int(StateFlag.ST_CRAWL | StateFlag.ST_DOWNED) & int(human_net_phys.phys.currentState.states)
  if canClimbLadders == 0
    var humanTransform : float3x4
    location_toTM(human_net_phys.phys.currentState.location, humanTransform)
    assume lookDir = human_net_phys.phys.appliedCT.wishLookDir

    var toDir = lookDir
    let up = human_net_phys.phys.currentState.vertDirection
    if dot(toDir, up) < .0
      toDir -= dot(toDir, up) * up
    let isSwimming = human_phys_state_get_is_swimming(human_net_phys.phys.currentState)
    let fromPos = humanTransform * (isSwimming ? swim_ladder_trace_pos : ladder_trace_pos)
    let toPos = fromPos + toDir * ladder_trace_dist

    var outLadderSteps : int
    if find_gobj_or_entity_ladder(fromPos, toPos, near_ladder_tm, outLadderSteps)
      let from2ladder = near_ladder_tm[3] - fromPos
      let horPos = fromPos + basis_aware_x0z(from2ladder, up)
      if dot(basis_aware_x0z(from2ladder, up), normalize(near_ladder_tm[0])) < 0.
        nearToLadder = check_visible(fromPos, horPos)

    // find ladder for descent
    if !nearToLadder
      nearToLadder = find_query() <| $ [es(REQUIRE=human_ladder__marker)] (transform : float3x4;
                                                                           ladder_marker__traceDist : float)
        let isObserving = angle(lookDir, transform[3] - fromPos) <= marker_observe_angle
        let isAbove = dot(fromPos, up) > dot(transform[3], up)
        let isNear = distance_sq(fromPos, transform[3]) <= square(marker_check_dist)
        if isNear && isAbove && isObserving
          if (check_trace(transform, ladder_marker__traceDist) &&
              check_visible(fromPos, transform[3]))
            near_ladder_tm = transform
            is_descent = true
            return true
        return false

  return nearToLadder


def request_attach_to_ladder(is_descent : bool;
                             near_ladder_tm : float3x4;
                             human_net_phys : HumanActor;
                             hero_eid : EntityId;
                             ladderTracePos : float3)
  assume state = human_net_phys.phys.currentState

  let startPos = float3(state.location.P)
  var wishPos = float3(0.0)
  var wishLookDir = float3(0.0)
  var wishGunDir = float3(0.0)
  let ladderUp = normalize(near_ladder_tm[1])

  if !is_descent
    let human2ladder = near_ladder_tm[3] - startPos
    let toLadderDir = basis_aware_x0z(human2ladder, ladderUp)
    let horShift = length(near_ladder_tm[0]) * 2f + human_net_phys.phys.collRad
    let orientDir = normalize(near_ladder_tm[0])
    if dot(human2ladder, ladderUp) > length(near_ladder_tm[1]) / 2.f
      wishPos = near_ladder_tm[3] - near_ladder_tm[1] / 2.f
    else
      wishPos = startPos + toLadderDir
    wishPos += orientDir * horShift
    wishGunDir = -orientDir

    var tm = IDENT_TM
    tm[0] = -orientDir
    tm[1] = ladderUp
    tm[2] = cross(tm[0], tm[1])
    tm[3] = wishPos
    let fromPos = tm * ladderTracePos
    let ladderLeft = dot(near_ladder_tm[2], tm[2]) < 0f ? -near_ladder_tm[2] : near_ladder_tm[2]
    let rbDir = near_ladder_tm[3] - (-near_ladder_tm[0] + near_ladder_tm[1] + ladderLeft) / 2.f - fromPos
    let ltDir = near_ladder_tm[3] + (-near_ladder_tm[0] + near_ladder_tm[1] + ladderLeft) / 2.f - fromPos
    let curDir = dir_and_up_to_quat(state.gunDir, state.vertDirection) |> quat_get_forward()
    let xProj = clamp(dot(curDir, tm[0]), dot(rbDir, tm[0]), dot(ltDir, tm[0])) * tm[0]
    let yProj = clamp(dot(curDir, tm[1]), dot(rbDir, tm[1]), dot(ltDir, tm[1])) * tm[1]
    let zProj = clamp(dot(curDir, tm[2]), dot(rbDir, tm[2]), dot(ltDir, tm[2])) * tm[2]
    wishLookDir = normalize(xProj + yProj + zProj)
  else
    wishPos = near_ladder_tm[3] - ladderUp * human_net_phys.phys.standingHeight
    wishGunDir = near_ladder_tm[0]
    wishLookDir = near_ladder_tm[0]

  send_net_event(hero_eid, ReqAttachToLadder(
    wishPos = wishPos,
    wishLookOrient = float4(dir_and_up_to_quat(wishLookDir, ladderUp)),
    wishGunOrient = float4(dir_and_up_to_quat(wishGunDir, ladderUp)),
    ladderUp = ladderUp))


def check_ladder_availability(human_net_phys : HumanActor;
                              wish_pos : float3;
                              ladder_up : float3;
                              human_ladder__maxUseDistance : float;
                              human_ladder__checkPlaceParams : float3)
  let curPos = float3(human_net_phys.phys.currentState.location.P)
  let close = distance(curPos, wish_pos) <= square(human_ladder__maxUseDistance)
  var out = ShapeQueryOutput()
  let hasPlace = !sphere_cast(wish_pos + ladder_up * (human_ladder__checkPlaceParams.y + human_ladder__checkPlaceParams.x),
                              wish_pos + ladder_up * max(0f, human_ladder__checkPlaceParams.z - human_ladder__checkPlaceParams.x),
                              human_ladder__checkPlaceParams.x, out)
  return close && hasPlace


def get_to_ladder_anim_duration(curPos, wishPos : float3;
                                curOrient, wishOrient : quat;
                                ladderUp : float3; animation_velocity : float)
  let path = abs(dot(wishPos - curPos, ladderUp)) + length(wishPos - curPos - dot(wishPos - curPos, ladderUp) * ladderUp)
  return max(path / animation_velocity,
             angle(quat_get_forward(wishOrient), quat_get_forward(curOrient)) / PI)


def set_ladder_for_attach(eid : EntityId)
  query(eid) <| $ [es] (var human_ladder__ladderTm : float3x4&;
                        var human_ladder__attached : bool&;
                        var human_ladder__numSteps : int&;
                        human_to_ladder_animation__wishPos : float3;
                        human_to_ladder_animation__wishGunOrient : float4;
                        human_to_ladder_animation__ladderUp : float3;
                        human_net_phys__isSwimming : bool;
                        human_net_phys__ladderTracePos : float3 = float3(0, 1.6, 0);
                        human_net_phys__swimLadderTracePos : float3 = float3(0, 0.7, 0))
    let wishFwd = quat(human_to_ladder_animation__wishGunOrient) |> quat_get_forward()
    var humanTransform : float3x4
    humanTransform[0] = normalize(wishFwd)
    humanTransform[1] = normalize(human_to_ladder_animation__ladderUp)
    humanTransform[2] = cross(humanTransform[0], humanTransform[1])
    humanTransform[3] = human_to_ladder_animation__wishPos

    let dir = humanTransform[0]
    let fromPos = humanTransform * (human_net_phys__isSwimming ? human_net_phys__swimLadderTracePos : human_net_phys__ladderTracePos)
    let toPos = fromPos + dir
    human_ladder__attached = find_gobj_or_entity_ladder(fromPos, toPos, human_ladder__ladderTm, human_ladder__numSteps)


def angle_xz(vec1 : float3; vec2 : float3;  up : float3)
  let vec1_proj = vec1 - up * dot(vec1, up)
  let vec2_proj = vec2 - up * dot(vec2, up)
  let dir = dot(cross(vec1_proj, vec2_proj), up) > 0. ? 1. : -1.
  return angle(vec1_proj, vec2_proj) * dir


def get_jump_dir(angle : float;
                 back_jump_angle : float;
                 front_dir : float3;
                 up : float3) : float3
  let frontDirXZ = front_dir - up * dot(front_dir, up)
  if angle < -back_jump_angle
    return normalize(cross(frontDirXZ, up) + up)
  elif angle > back_jump_angle
    return normalize(-cross(frontDirXZ, up) + up)
  else
    return normalize(-frontDirXZ + up)


def jump_from_ladder(var human_net_phys : HumanActor;
                     ladder_tm : float3x4;
                     jump_speed : float;
                     zero_angle_admit : float)
  let lookDir = human_net_phys.phys.appliedCT.wishLookDir
  let prevPosition = float3(human_net_phys.phys.currentState.location.P)
  let toLadderDir = ladder_tm[3] - prevPosition
  let ladderUp = normalize(ladder_tm[1])
  let ang = angle_xz(toLadderDir, lookDir, ladderUp)
  let jumpDir = get_jump_dir(ang, zero_angle_admit, toLadderDir, ladderUp)
  let deltaVel = jumpDir * human_net_phys.phys.currentState.jumpSpeedMult * jump_speed

  if get_DAECS_EXTENSIVE_CHECKS() != 0 && is_nan(deltaVel)
    logerr("[LADDER] Jump delta velocity is NaN!
deltaVel={deltaVel}
jumpDir={jumpDir}
jumpSpeedMult={human_net_phys.phys.currentState.jumpSpeedMult}
jump_speed={jump_speed}")
    return

  human_net_phys.phys.currentState.velocity += deltaVel
