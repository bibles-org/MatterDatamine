module door_operations_common shared
require ecs
require app
require math.base
require math.ang
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require DagorMath
require DagorMathUtils


enum DoorState
  CLOSED
  OPENED
  AJAR


enum DoorOperation
  NONE
  PULL
  PUSH


def get_target_angle(transform : float3x4;
                     opener_pos : float3;
                     door_operations__reqState : int;
                     door_operations__omniRotate : bool;
                     door_operations__openedAngle : float;
                     door_operations__closedAngle : float;
                     door_operations__ajarAngleKoef : float)
  let doorPos = transform[3]
  let doorDir = transform[2]
  let dirSign = dot(doorDir, (doorPos - opener_pos)) > 0f ? 1f : -1f
  let angleSign = (door_operations__openedAngle - door_operations__closedAngle) > 0f ? 1f : -1f
  let sign = dirSign * angleSign

  if door_operations__reqState == int(DoorState.OPENED)
    if door_operations__omniRotate
      return door_operations__closedAngle + (door_operations__closedAngle - door_operations__openedAngle) * sign
    else
      return door_operations__openedAngle
  elif door_operations__reqState == int(DoorState.AJAR)
    let ajarKoef = door_operations__ajarAngleKoef
    if door_operations__omniRotate
      return door_operations__closedAngle + (door_operations__closedAngle - door_operations__openedAngle) * ajarKoef * sign
    else
      return door_operations__closedAngle + (door_operations__openedAngle - door_operations__closedAngle) * ajarKoef
  else
    return door_operations__closedAngle


def detect_door_state_by_angle(current_angle : float;
                               opened_angle : float;
                               closed_angle : float;
                               ajar_angle_koef : float)
  let ajarRotationAngle = get_door_ajar_rotation_angle(opened_angle, closed_angle, ajar_angle_koef)
  if abs(angle_diff(current_angle * DEG_TO_RAD, closed_angle * DEG_TO_RAD) * RAD_TO_DEG) + 1e-3 < ajarRotationAngle
    return int(DoorState.CLOSED)
  elif is_equal_float(current_angle, opened_angle)
    return int(DoorState.OPENED)
  else
    return int(DoorState.AJAR)


def get_door_full_rotation_angle(opened_angle : float;
                                 closed_angle : float)
  return abs(angle_diff(opened_angle * DEG_TO_RAD, closed_angle * DEG_TO_RAD) * RAD_TO_DEG)


def get_door_ajar_rotation_angle(opened_angle : float;
                                 closed_angle : float;
                                 ajar_angle_koef : float)
  return get_door_full_rotation_angle(opened_angle, closed_angle) * ajar_angle_koef


def change_door_state(door_eid : EntityId;
                      target_door_state : int;
                      opener_pos : float3;
                      is_server : bool;
                      ignore_lock : bool = false;
                      ignore_cooldown : bool = false)
  query(door_eid) <| $ [es] (var door_operations__reqState : int&;
                             var rendinst_axis_rotation__targetAngle : float&;
                             var door_operations__serverTargetAngle : float&;
                             var door_operations__lastUseTime : float&;
                             var rendinst_axis_rotation__rotSpeedKoef : float&;
                             rendinst_axis_rotation__curAngle : float;
                             door_operations__state : int;
                             locked__isLocked : bool = false;
                             door_operations__openedAngle : float;
                             door_operations__closedAngle : float;
                             door_operations__ajarAngleKoef : float;
                             door_operations__ajarSpeedKoef : float;
                             transform : float3x4;
                             door_operations__omniRotate : bool = false;
                             door_operations__useCooldown : float;
                             rotating_rendinst_simple_phys__processingTemplate : das_string const?)
    let curTime = get_sync_time()
    if curTime - door_operations__lastUseTime < door_operations__useCooldown && !ignore_cooldown
      return
    if locked__isLocked && !ignore_lock
      return

    if is_server
      door_operations__reqState = target_door_state

    sendEvent(door_eid, EventDoorChangeStateRequest(target_door_state = target_door_state))

    let targetAngle = get_target_angle(transform, opener_pos,
                                              target_door_state, door_operations__omniRotate,
                                              door_operations__openedAngle, door_operations__closedAngle,
                                              door_operations__ajarAngleKoef)
    let angleDiff = abs(angle_diff(rendinst_axis_rotation__curAngle * DEG_TO_RAD, targetAngle * DEG_TO_RAD) * RAD_TO_DEG)

    let ajarRotationAngle = get_door_ajar_rotation_angle(door_operations__openedAngle, door_operations__closedAngle, door_operations__ajarAngleKoef)

    if (target_door_state == int(DoorState.AJAR) ||
      (door_operations__state == int(DoorState.AJAR) && (angleDiff - 1e-3) <= ajarRotationAngle))
      rendinst_axis_rotation__rotSpeedKoef = door_operations__ajarSpeedKoef
    else
      rendinst_axis_rotation__rotSpeedKoef = 1.0

    if rotating_rendinst_simple_phys__processingTemplate != null
      removeSubTemplate(door_eid, string(*rotating_rendinst_simple_phys__processingTemplate))

    rendinst_axis_rotation__targetAngle = targetAngle
    door_operations__lastUseTime = curTime

    if is_server
      door_operations__serverTargetAngle = targetAngle // set server angle only on server so client can check against it
    else // not server
      let alreadyPredicting = find_query() <| $ [es] (door_client_prediction__doorEid : EntityId; var door_client_prediction__atTime : float&)
        if door_client_prediction__doorEid == door_eid
          door_client_prediction__atTime = curTime
          return true
        return false

      if !alreadyPredicting
        createEntity("door_client_prediction_tracker") <| $(init)
          init |> set("door_client_prediction__doorEid", door_eid)
          init |> set("door_client_prediction__atTime", curTime)

  // Sliding doors
  query(door_eid) <| $ [es(REQUIRE=sliding_rendinst)] (var door_operations__state : int&;
                                                       var door_operations__reqState : int&)
    sendEvent(door_eid, EventDoorChangeStateRequest(target_door_state = target_door_state))
    door_operations__reqState = target_door_state
    door_operations__state = target_door_state


def cmd_use_door(door_eid, opener_eid, pair_door__eid : EntityId;
                 target_state : int;
                 is_server : bool)
  query(opener_eid) <| $ [es] (transform : float3x4)
    let openerPos = transform[3]
    change_door_state(door_eid, target_state, openerPos, is_server)
    change_door_state(pair_door__eid, target_state, openerPos, is_server)


def set_sliding_door_state_immediate(door_eid : EntityId;
                                     state : int)
  query(door_eid) <| $ [es(REQUIRE=sliding_rendinst)] (initialTransform : float3x4;
                                                       sliding_rendinst__axis : float3;
                                                       sliding_rendinst__offset : float;
                                                       sliding_rendinst__movingTemplate : string;
                                                       var transform : float3x4;
                                                       var door_operations__state : int&;
                                                       var door_operations__reqState : int&;
                                                       var sliding_rendinst__slidedState : bool&;
                                                       var sliding_rendinst__progress : float&)
    removeSubTemplate(door_eid, sliding_rendinst__movingTemplate)
    if door_operations__state == state && door_operations__reqState == state
      return

    door_operations__state = state
    door_operations__reqState = state
    sliding_rendinst__slidedState = (state == int(DoorState.OPENED)) ? true : false

    sliding_rendinst__progress = sliding_rendinst__slidedState ? 1.0 : 0.0
    let currentOffset = rotate(initialTransform, sliding_rendinst__axis) * (sliding_rendinst__offset * sliding_rendinst__progress)

    transform = initialTransform
    transform[3] += currentOffset


def get_door_main_action(cur_state : int)
  if cur_state == int(DoorState.OPENED)
    return int(DoorState.CLOSED)
  return int(DoorState.OPENED)


def get_door_alt_action(cur_state : int)
  if cur_state == int(DoorState.CLOSED)
    return int(DoorState.AJAR)
  elif cur_state == int(DoorState.AJAR)
    return int(DoorState.CLOSED)
  return cur_state


def get_window_main_action(cur_state : int)
  if cur_state == int(DoorState.OPENED)
    return int(DoorState.CLOSED)
  return int(DoorState.OPENED)


def detect_door_operation(player_transform : float3x4;
                          door_transform : float3x4;
                          door_operations__reqState : int;
                          door_operations__omniRotate : bool = false;
                          door_operations__openedAngle : float;
                          door_operations__closedAngle : float;
                          door_operations__ajarAngleKoef : float;
                          door_cur_angle : float; // rendinst_axis_rotation__curAngle
                          door_axis : float3; // rendinst_axis_rotation__axis
                          var out_door_operation : DoorOperation&;
                          var out_door_push_orientation : float&)

  out_door_push_orientation = 0.0
  out_door_operation = DoorOperation.NONE

  let playerForward = player_transform[0]
  let playerUp = player_transform[1]
  let playerLeft = player_transform[2]
  let doorForward = door_transform[2] // in doors, z goes out of the door. in hatches, x goes out of the door (not great)

  let fromDoorToPlayer = player_transform[3] - door_transform[3]
  let alongDoor = door_transform[0]

  let angle_to_player = dot(playerUp, cross(fromDoorToPlayer, alongDoor))
  let targetAngle = get_target_angle(door_transform, player_transform[3],
                                                door_operations__reqState == int(DoorState.OPENED) ? int(DoorState.CLOSED) : int(DoorState.OPENED),
                                                door_operations__omniRotate,
                                                door_operations__openedAngle, door_operations__closedAngle,
                                                door_operations__ajarAngleKoef)
  let angle_to_opened = targetAngle - door_cur_angle
  if angle_to_player * angle_to_opened < 0.0
    out_door_operation = DoorOperation.PULL
    out_door_push_orientation = 0.0 // will not be used
  else
    out_door_operation = DoorOperation.PUSH

    let doorAxis = rotate(door_transform, door_axis)
    if dot(doorAxis, playerUp) < 0.5 // doors that are inclined away from the player (hatches for example) can't be opened with push of a hand
      out_door_operation = DoorOperation.NONE
    else
      let intoDoor = dot(door_transform[3] - player_transform[3], doorForward) > 0.0 ? doorForward : -doorForward
      let intoDoorInPlayerPlane = normalize(
        dot(intoDoor, playerForward) * playerForward +
        dot(intoDoor, playerLeft) * playerLeft
      )

      // angle must be signed
      let angle = angle(playerForward, intoDoorInPlayerPlane) * sign(dot(playerUp, cross(playerForward, intoDoorInPlayerPlane)))

      // 1 -> perpendicular to door or door is to the right, push forward
      // 0 -> door is parallel and is to the left, push to the left
      out_door_push_orientation = saturate(angle / HALF_PI + 1.0)